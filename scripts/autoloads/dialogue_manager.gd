extends Node

## E4 (ADR-035): selects one dialogue line per NPC interaction from
## GameData's raw (unfiltered) line list, using ConditionEvaluator against a
## context built from live world/player state. Replaces main.gd's old
## `lines[0]`-of-first-match with priority-based selection (random among
## exact ties) and frequency gating (`once_per_day` tracked in
## player.dialogue_history, cleared on day_passed).
## DESKTOP: needs Project Settings -> Autoload registration (ADR-035) before
## `DialogueManager.get_next_line()` resolves as a bare global in the live
## game. Logic here is headless-testable via configure_for_test regardless.

const MASS_DAY := 21  # duplicates main.gd's hardcoded constants (ADR-035) -
const MASS_HOUR := 9  # no data-driven source exists for these; not this
                       # record's problem to fix.
const MAX_HISTORY_PER_NPC := 50

var _game_data_ref: Node = null
var _player_state_ref: Node = null
var _time_manager_ref: Node = null
var _weather_manager_ref: Node = null
var _reputation_manager_ref: Node = null
var _skill_manager_ref: Node = null
var _festival_manager_ref: Node = null

## npc_id -> Array[int] of dialogue.json line indices spoken today
## (once_per_day tracking only - see ADR-035 on why once_per_conversation
## needs no separate tracking in this engine's current single-line-per-
## interaction shape).
var _dialogue_history: Dictionary = {}


func _ready() -> void:
	var tm := _time_manager()
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


## Test-injection seam (mirrors CraftingManager's multi-dependency pattern).
## festival_manager defaults null - existing callers that predate E5 (ADR-036)
## keep working unchanged, with is_festival/festival_id simply staying at
## their Phase 2 placeholder values (false/"") when omitted.
func configure_for_test(
	game_data: Node, player_state: Node, time_manager: Node,
	weather_manager: Node, reputation_manager: Node, skill_manager: Node,
	festival_manager: Node = null
) -> void:
	_game_data_ref = game_data
	_player_state_ref = player_state
	_time_manager_ref = time_manager
	_weather_manager_ref = weather_manager
	_reputation_manager_ref = reputation_manager
	_skill_manager_ref = skill_manager
	_festival_manager_ref = festival_manager


## Returns the selected line's text, or "" if the NPC has no lines at all
## (GameData's load-time validation means every real NPC has at least a
## fallback - "" only happens for an unknown npc_id).
func get_next_line(npc_id: String) -> String:
	var gd := _game_data()
	if gd == null:
		return ""
	var lines: Array[Dictionary] = gd.get_dialogue_lines_for(npc_id)
	if lines.is_empty():
		return ""
	var context := build_context(npc_id)
	var best_index := -1
	var best_priority := -INF
	var ties: Array[int] = []
	for i in range(lines.size()):
		var line := lines[i]
		if not ConditionEvaluator.evaluate(line.get("conditions", {}), context):
			continue
		if not _frequency_allows(npc_id, i, str(line.get("frequency", "always"))):
			continue
		var priority := float(line.get("priority", 0))
		if priority > best_priority:
			best_priority = priority
			best_index = i
			ties = [i]
		elif priority == best_priority:
			ties.append(i)
	if ties.is_empty():
		return ""
	best_index = ties[randi() % ties.size()]
	var chosen := lines[best_index]
	_record_spoken(npc_id, best_index, str(chosen.get("frequency", "always")))
	var flag := str(chosen.get("set_flag", ""))
	if not flag.is_empty():
		var ps := _player_state()
		if ps != null:
			ps.set_event_flag(flag)
	return str(chosen.get("text", ""))


## Flattened facts for ConditionEvaluator - not live object references, so
## the evaluator stays a pure function of (conditions, context).
func build_context(npc_id: String) -> Dictionary:
	var tm := _time_manager()
	var wm := _weather_manager()
	var rm := _reputation_manager()
	var sm := _skill_manager()
	var ps := _player_state()
	var gd := _game_data()

	var hour := int(tm.hour) if tm != null else 12
	var day := int(tm.day) if tm != null else 1
	var season := str(tm.season) if tm != null else "spring"
	var weather := str(wm.get_today_weather()) if wm != null else "sunny"
	var is_market := bool(gd.is_market_day(day)) if gd != null else false
	# E5 (ADR-036): FestivalManager is a pending-DESKTOP autoload - resolved
	# defensively, same as every other dependency here.
	var fm := _festival_manager()
	var active_festival: Dictionary = fm.get_active_festival() if fm != null else {}

	var standings := {}
	var opinions := {}
	if rm != null:
		for axis: String in ["manor", "village", "church"]:
			standings[axis] = rm.get_standing(axis)
		opinions = (rm.get("opinions") as Dictionary).duplicate()

	var skill_levels := {}
	if sm != null:
		for skill_id: String in ["farming", "foraging", "combat", "labor"]:
			skill_levels[skill_id] = sm.get_level(skill_id)

	var money := 0
	var energy := 0.0
	var health := 0
	var item_counts := {}
	var event_flags: Array = []
	if ps != null:
		money = int(ps.get("money"))
		energy = float(ps.get("energy"))
		health = int(ps.get("health"))
		var inventory: Dictionary = ps.get("inventory")
		for item_id: Variant in inventory.keys():
			item_counts[item_id] = ps.get_item_count(str(item_id))
		event_flags = (ps.get("event_flags") as Array).duplicate()

	return {
		"npc_id": npc_id,
		"time_hour": hour,
		"season": season,
		"weather": weather,
		"is_market_day": is_market,
		"is_mass_day": day == MASS_DAY and hour == MASS_HOUR,
		"is_festival": not active_festival.is_empty(),
		"festival_id": str(active_festival.get("id", "")),
		"money": money,
		"energy": energy,
		"health": health,
		"standings": standings,
		"opinions": opinions,
		"skill_levels": skill_levels,
		"item_counts": item_counts,
		"event_flags": event_flags,
	}


func to_dict() -> Dictionary:
	var out := {}
	for npc_id: Variant in _dialogue_history:
		out[npc_id] = (_dialogue_history[npc_id] as Array).duplicate()
	return out


func from_dict(data: Dictionary) -> void:
	_dialogue_history.clear()
	for npc_id: Variant in data:
		var indices: Array = []
		for entry: Variant in (data[npc_id] as Array):
			indices.append(int(entry))
		_dialogue_history[str(npc_id)] = indices


func _frequency_allows(npc_id: String, line_index: int, frequency: String) -> bool:
	if frequency != "once_per_day":
		return true
	var spoken: Array = _dialogue_history.get(npc_id, [])
	return not spoken.has(line_index)


func _record_spoken(npc_id: String, line_index: int, frequency: String) -> void:
	if frequency != "once_per_day":
		return
	var spoken: Array = _dialogue_history.get(npc_id, [])
	if spoken.has(line_index):
		return
	spoken.append(line_index)
	if spoken.size() > MAX_HISTORY_PER_NPC:
		spoken = spoken.slice(spoken.size() - MAX_HISTORY_PER_NPC)
	_dialogue_history[npc_id] = spoken


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_dialogue_history.clear()


func _game_data() -> Node:
	if _game_data_ref != null:
		return _game_data_ref
	return get_node_or_null("/root/GameData")


func _player_state() -> Node:
	if _player_state_ref != null:
		return _player_state_ref
	return get_node_or_null("/root/PlayerState")


func _time_manager() -> Node:
	if _time_manager_ref != null:
		return _time_manager_ref
	return get_node_or_null("/root/TimeManager")


func _weather_manager() -> Node:
	if _weather_manager_ref != null:
		return _weather_manager_ref
	return get_node_or_null("/root/WeatherManager")


func _reputation_manager() -> Node:
	if _reputation_manager_ref != null:
		return _reputation_manager_ref
	return get_node_or_null("/root/ReputationManager")


func _skill_manager() -> Node:
	if _skill_manager_ref != null:
		return _skill_manager_ref
	return get_node_or_null("/root/SkillManager")


func _festival_manager() -> Node:
	if _festival_manager_ref != null:
		return _festival_manager_ref
	return get_node_or_null("/root/FestivalManager")
