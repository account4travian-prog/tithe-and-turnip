extends Node

## E5 (ADR-036): a pure query surface over festivals.json - given the
## current day/season/hour, which festival (if any) is active right now.
## Holds no state of its own and serializes nothing - "is a festival active"
## is always recomputed from TimeManager + static data, never persisted.
## Three call sites share this lookup: main.gd's attendance check (mirrors
## the existing mass-attendance pattern), npc.gd's schedule anchor override,
## and DialogueManager's is_festival/festival_id context fields.
##
## Festival contests (world_bible.md Section V, festivals.json v2) live here
## too: entry eligibility, the timed 3-beat press-race state machine
## (Furrow Race / Lifting Contest), cheer/bet resolution and payout, all
## gated one-shot per festival occurrence through PlayerState.event_flags
## ("festival.contest_entered_<id>" / "festival.contest_cheered_<id>") -
## the same persistence-free pattern the attendance grant uses, so nothing
## here needs a SAVE_VERSION bump.
##
## The race machine is deliberately testable without real frames: the state
## is just (elapsed accumulator, next beat index, press latched for the
## current beat), windows are absolute elapsed-time bounds from data, and
## race_step() is a pure function - feed it synthetic elapsed/delta/pressed
## values and it returns the next state plus hit/miss events. The live game
## drives it from _physics_process (CLAUDE.md section 4); no Timer node is
## ever involved. Design reviewed by deepseek-v4-pro via the DeepSeek API
## before implementation (same shape: elapsed + beat_idx + press_used).
##
## DESKTOP: needs Project Settings -> Autoload registration (ADR-036) before
## a bare `FestivalManager.` reference resolves in the live game - callers
## reach it via get_node_or_null, same as DialogueManager's own pending
## registration in Phase 2.

signal race_started(festival_id: String, contest_mode: String)
signal race_finished(successes: int, payout: int)
signal cheer_resolved(festival_id: String, entrant_id: String, win: bool, payout: int, bet: int)

const RACE_STATE_IDLE := 0
const RACE_STATE_ACTIVE := 1

var _game_data_ref: Node = null
var _time_manager_ref: Node = null
var _player_state_ref: Node = null
var _reputation_ref: Node = null
var _skill_ref: Node = null

## Race session state. Only meaningful while _race_state is ACTIVE; the pure
## scoring functions take their inputs explicitly so tests never touch these.
var _race_state := RACE_STATE_IDLE
var _race_festival_id := ""
var _race_elapsed := 0.0
var _race_beat_index := 0
var _race_press_used := false
var _race_successes := 0
var _race_level := 0
var _race_cfg: Dictionary = {}
var _race_result: Dictionary = {}


func configure_for_test(game_data: Node, time_manager: Node,
		player_state: Node = null, reputation_manager: Node = null,
		skill_manager: Node = null) -> void:
	_game_data_ref = game_data
	_time_manager_ref = time_manager
	_player_state_ref = player_state
	_reputation_ref = reputation_manager
	_skill_ref = skill_manager


## Returns the active festival's full data dict, or {} if none is active
## (wrong day/season, or the right day but outside the hour window).
func get_active_festival() -> Dictionary:
	var gd := _game_data()
	var tm := _time_manager()
	if gd == null or tm == null:
		return {}
	var day := int(tm.get("day"))
	var season := str(tm.get("season"))
	var hour := int(tm.get("hour"))
	for entry: Variant in gd.get_all_festivals():
		var festival := entry as Dictionary
		if str(festival.get("season", "")) != season:
			continue
		if int(festival.get("day", -1)) != day:
			continue
		if hour >= int(festival.get("start_hour", 0)) and hour < int(festival.get("end_hour", 0)):
			return festival
	return {}


## Empty Dictionary = no override; npc.gd falls back to normal work/home.
func get_active_festival_anchor() -> Dictionary:
	var festival := get_active_festival()
	if festival.is_empty():
		return {}
	return festival.get("location", {})


## The per-festival contest block from festivals.json, or {} when the
## festival has none. Pure data lookup - season gating is applied by the
## callers that check active-festival state.
func get_contest(festival_id: String) -> Dictionary:
	var gd := _game_data()
	if gd == null:
		return {}
	var festival: Dictionary = gd.get_festival(festival_id)
	var contest: Dictionary = festival.get("contest", {})
	return contest


## The contest attached to the currently active festival, or {} when no
## festival is active or it has no contest. This is the season gate: a
## Summer contest is simply not reachable while Spring is active.
func get_active_contest() -> Dictionary:
	var festival := get_active_festival()
	if festival.is_empty():
		return {}
	return get_contest(str(festival.get("id", "")))


## Direct-entry eligibility: the festival must be active (season gate), the
## contest must offer direct entry, no race may already be running, and the
## player must not have entered this festival's contest before.
func can_enter_contest(festival_id: String) -> bool:
	if not _is_active_festival_id(festival_id):
		return false
	if is_race_active():
		return false
	var contest := get_contest(festival_id)
	if contest.is_empty() or not bool(contest.get("has_direct_entry", false)):
		return false
	var player := _player_state()
	if player == null:
		return false
	return not player.has_event_flag(_enter_flag(festival_id))


## Starts the contest's direct-entry mode: sets the one-shot flag, applies
## the data-driven entry standing, and begins the timed race session.
func start_contest(festival_id: String) -> Dictionary:
	if not can_enter_contest(festival_id):
		return {"ok": false, "reason": "not_enterable"}
	var contest := get_contest(festival_id)
	var player := _player_state()
	if player == null:
		return {"ok": false, "reason": "no_player_state"}
	player.set_event_flag(_enter_flag(festival_id))
	_apply_standing(contest.get("enter_standing", {}))
	_begin_race(festival_id, contest)
	race_started.emit(festival_id, str(contest.get("mode", "")))
	return {"ok": true, "contest": contest}


func is_race_active() -> bool:
	return _race_state == RACE_STATE_ACTIVE


## Player-facing press: evaluates a press against the current race time
## without advancing it (a zero-delta step). Returns true when the press
## scored a beat.
func press_race() -> bool:
	if _race_state != RACE_STATE_ACTIVE:
		return false
	var before := _race_successes
	advance_race(0.0, true)
	return _race_successes > before


## Advances the active race by delta seconds and resolves any press arriving
## during that step. Called from _physics_process with pressed=false; the
## panel calls it with pressed=true (zero delta) from its Press button.
func advance_race(delta: float, pressed: bool) -> void:
	if _race_state != RACE_STATE_ACTIVE:
		return
	var result := race_step(
		_race_elapsed, _race_beat_index, _race_press_used, delta, pressed,
		_race_level, _race_cfg)
	_race_elapsed = float(result.get("elapsed", _race_elapsed))
	_race_beat_index = int(result.get("beat_index", _race_beat_index))
	_race_press_used = bool(result.get("press_used", _race_press_used))
	var events: Array = result.get("events", [])
	for event: Variant in events:
		if str(event) == "hit":
			_race_successes += 1
	var beats: Array = _race_cfg.get("beats", [])
	if _race_beat_index >= beats.size():
		_finish_race()


## Abandons an in-progress race (e.g. the panel was closed mid-race). The
## one-shot entry flag stays set, so this is an abandoned entry, never a
## free replay.
func cancel_race() -> void:
	if _race_state != RACE_STATE_ACTIVE:
		return
	_race_state = RACE_STATE_IDLE
	_race_festival_id = ""
	_race_result = {}


## Snapshot for UI polling (rendering only - the panel never mutates
## gameplay state from _process). Returns the active flag, the next beat to
## resolve, which beat's window (if any) is open right now, the window
## fraction for a progress bar, and the finished result when inactive.
func get_race_state() -> Dictionary:
	if _race_state != RACE_STATE_ACTIVE:
		return {"active": false, "result": _race_result.duplicate()}
	var beats: Array = _race_cfg.get("beats", [])
	var active_beat := -1
	var fraction := 0.0
	for i in range(beats.size()):
		var window := beat_window(i, _race_level, _race_cfg)
		var start := float(window.get("start", 0.0))
		var end := float(window.get("end", 0.0))
		if _race_elapsed >= start and _race_elapsed <= end:
			active_beat = i
			fraction = 0.5 if end <= start else clampf(
				(_race_elapsed - start) / (end - start), 0.0, 1.0)
			break
	return {
		"active": true,
		"festival_id": _race_festival_id,
		"elapsed": _race_elapsed,
		"beat_index": _race_beat_index,
		"press_used": _race_press_used,
		"successes": _race_successes,
		"beat_count": beats.size(),
		"active_beat": active_beat,
		"window_fraction": fraction,
		"result": {},
	}


## PURE: one step of the race state machine. Inputs are the previous state,
## a delta (0 for a pure press), whether the player pressed during the step,
## the skill level, and the timing config. Returns the next state plus
## hit/miss events. No nodes, no RNG, no Timer - a headless test can drive
## any sequence with synthetic elapsed values.
func race_step(elapsed: float, beat_index: int, press_used: bool, delta: float,
		pressed: bool, level: int, timing: Dictionary) -> Dictionary:
	var beats: Array = timing.get("beats", [])
	var next_elapsed := elapsed + delta
	var next_index := beat_index
	var next_used := press_used
	var events: Array[String] = []
	# Advance past every beat whose window has fully closed. An unscored
	# closed window is a miss; a scored one advances silently. This is what
	# lets a press in beat 2's window still score after beat 1 was missed.
	while next_index < beats.size():
		var window := beat_window(next_index, level, timing)
		if next_elapsed < float(window.get("end", INF)):
			break
		if not next_used:
			events.append("miss")
		next_index += 1
		next_used = false
	# A press inside the next unresolved beat's window scores exactly once
	# (press_used latches until the window closes). Early/late presses are
	# simply ignored - no penalty, no double-dip.
	if pressed and next_index < beats.size() and not next_used:
		var window := beat_window(next_index, level, timing)
		if next_elapsed >= float(window.get("start", -INF)) \
				and next_elapsed <= float(window.get("end", INF)):
			events.append("hit")
			next_used = true
	return {
		"elapsed": next_elapsed,
		"beat_index": next_index,
		"press_used": next_used,
		"events": events,
	}


## PURE: the forgiveness-widened absolute window [start, end] for a beat.
## The base half-window comes from the beat entry; the farming/labor level
## adds forgiveness_per_level_seconds on each side (the data-driven
## "skill widens the timing window" ruling).
func beat_window(beat_index: int, level: int, timing: Dictionary) -> Dictionary:
	var beats: Array = timing.get("beats", [])
	if beat_index < 0 or beat_index >= beats.size():
		return {"start": 0.0, "end": 0.0}
	var beat: Dictionary = beats[beat_index]
	var target := float(beat.get("target_seconds", 0.0))
	var half := float(beat.get("half_window_seconds", 0.0))
	half += float(timing.get("forgiveness_per_level_seconds", 0.0)) * float(level)
	return {"start": target - half, "end": target + half}


## PURE: would a press at exactly `elapsed` score beat_index at this level?
func press_scores_at(elapsed: float, beat_index: int, level: int, timing: Dictionary) -> bool:
	var window := beat_window(beat_index, level, timing)
	return elapsed >= float(window.get("start", 0.0)) \
		and elapsed <= float(window.get("end", 0.0))


## PURE: score a run of presses, one per beat (press_times[i] is the press
## for beat i), against the forgiveness-widened windows.
func score_presses(press_times: Array, level: int, timing: Dictionary) -> int:
	var beats: Array = timing.get("beats", [])
	var score := 0
	var attempts := mini(press_times.size(), beats.size())
	for i in range(attempts):
		if press_scores_at(float(press_times[i]), i, level, timing):
			score += 1
	return score


## Cheer eligibility: active festival, contest offers cheer mode, the
## entrant is on the contest's roster, and the player has not cheered at
## this festival before.
func can_cheer(festival_id: String, entrant_id: String) -> bool:
	if not _is_active_festival_id(festival_id):
		return false
	var contest := get_contest(festival_id)
	if contest.is_empty() or not bool(contest.get("has_cheer", false)):
		return false
	var entrants: Array = contest.get("entrants", [])
	if not entrants.has(entrant_id):
		return false
	var player := _player_state()
	if player == null:
		return false
	return not player.has_event_flag(_cheer_flag(festival_id))


## Cheer for one entrant, optionally with a data-bounded coin bet. bet 0 is
## a pure cheer (storytelling contest); bets only resolve where the contest
## has has_bet. `roll` is a deterministic [0,1) test seam; the live game
## passes -1 and uses randf(). The result carries win/payout/bet so the UI
## can announce the outcome.
func cheer(festival_id: String, entrant_id: String, bet_amount: int,
		roll := -1.0) -> Dictionary:
	if not can_cheer(festival_id, entrant_id):
		return {"ok": false, "reason": "not_cheerable"}
	var contest := get_contest(festival_id)
	var has_bet := bool(contest.get("has_bet", false))
	if has_bet:
		var bet_cfg: Dictionary = contest.get("bet", {})
		var min_bet := int(bet_cfg.get("min", 1))
		var max_bet := int(bet_cfg.get("max", 5))
		if bet_amount < min_bet or bet_amount > max_bet:
			return {"ok": false, "reason": "bet_out_of_range"}
	elif bet_amount != 0:
		return {"ok": false, "reason": "bets_not_offered"}
	var player := _player_state()
	if player == null:
		return {"ok": false, "reason": "no_player_state"}
	if bet_amount > 0 and not player.spend_money(bet_amount):
		return {"ok": false, "reason": "insufficient_coin"}
	player.set_event_flag(_cheer_flag(festival_id))
	_apply_standing(contest.get("cheer_standing", {}))
	var reputation := _reputation_manager()
	if reputation != null:
		var opinion_delta := float(contest.get("cheer_opinion_delta", 0.0))
		if opinion_delta != 0.0:
			reputation.modify_opinion(entrant_id, opinion_delta)
	var odds: Dictionary = contest.get("odds", {})
	var weight := float(odds.get(entrant_id, 0.5))
	var roll_value := randf() if roll < 0.0 else roll
	var win := roll_value < weight
	var payout := 0
	if win:
		var multipliers: Dictionary = contest.get("payout_multiplier", {})
		var multiplier := float(multipliers.get(entrant_id, 1.0))
		payout = int(round(float(bet_amount) * multiplier))
		if payout > 0:
			player.add_money(payout)
	cheer_resolved.emit(festival_id, entrant_id, win, payout, bet_amount)
	return {
		"ok": true, "win": win, "payout": payout, "bet": bet_amount,
		"entrant_id": entrant_id,
	}


func _physics_process(delta: float) -> void:
	advance_race(delta, false)


func _begin_race(festival_id: String, contest: Dictionary) -> void:
	_race_state = RACE_STATE_ACTIVE
	_race_festival_id = festival_id
	_race_elapsed = 0.0
	_race_beat_index = 0
	_race_press_used = false
	_race_successes = 0
	_race_result = {}
	_race_cfg = contest.get("timing", {})
	var skill_manager := _skill_manager()
	var skill_id := str(contest.get("skill_id", "farming"))
	_race_level = int(skill_manager.get_level(skill_id)) if skill_manager != null else 0


func _finish_race() -> void:
	var successes := _race_successes
	var payout := 0
	var contest := get_contest(_race_festival_id)
	var payouts: Array = contest.get("payout_by_score", [])
	if successes < payouts.size():
		payout = int(payouts[successes])
	var player := _player_state()
	if player != null and payout > 0:
		player.add_money(payout)
	_race_state = RACE_STATE_IDLE
	_race_result = {"successes": successes, "payout": payout}
	_race_festival_id = ""
	race_finished.emit(successes, payout)


func _is_active_festival_id(festival_id: String) -> bool:
	var active := get_active_festival()
	if active.is_empty():
		return false
	return str(active.get("id", "")) == festival_id


func _enter_flag(festival_id: String) -> String:
	return "festival.contest_entered_%s" % festival_id


func _cheer_flag(festival_id: String) -> String:
	return "festival.contest_cheered_%s" % festival_id


func _apply_standing(deltas: Dictionary) -> void:
	var reputation := _reputation_manager()
	if reputation == null:
		return
	for axis: Variant in deltas:
		reputation.modify_standing(str(axis), float(deltas[axis]))


func _game_data() -> Node:
	if _game_data_ref != null:
		return _game_data_ref
	return get_node_or_null("/root/GameData")


func _time_manager() -> Node:
	if _time_manager_ref != null:
		return _time_manager_ref
	return get_node_or_null("/root/TimeManager")


func _player_state() -> Node:
	if _player_state_ref != null:
		return _player_state_ref
	return get_node_or_null("/root/PlayerState")


func _reputation_manager() -> Node:
	if _reputation_ref != null:
		return _reputation_ref
	return get_node_or_null("/root/ReputationManager")


func _skill_manager() -> Node:
	if _skill_ref != null:
		return _skill_ref
	return get_node_or_null("/root/SkillManager")
