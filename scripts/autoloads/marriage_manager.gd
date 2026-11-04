extends Node

## MarriageManager autoload - proposal, merchet, ceremony, and spouse-life
## state (ADR-031, realized). Courtship itself stays in ReputationManager's
## existing opinion axis; this manager only owns the marriage state machine
## and spouse effects (schedule anchor, waking greeting, farm chore, gift-cap
## bypass, reputation transfer). AUTOLOAD - no class_name (Godot 4.7 rejects
## a class_name that shadows the autoload singleton name).
##
## Banns are not a hard three-market-day timer - a deliberate simplification
## (design/decisions.md ADR-031's implementation record): the proposal and
## ceremony dialogue carry that flavour instead of a new state machine.
## Reached elsewhere via get_node_or_null("/root/MarriageManager") until
## docs/register_autoloads.gd is re-run, same as DialogueManager/
## FestivalManager before their own registration landed.

signal proposal_made(candidate_id: String)
signal merchet_paid(candidate_id: String)
signal ceremony_completed(spouse_id: String)
signal spouse_chore_done(chore_id: String)
signal marriage_state_changed

var _spouse_id := ""
var _pending_candidate := ""
var _merchet_paid := false
var _last_greeting_day := -1

var _farm_grid_ref: Node = null
var _test_player: Node = null
var _test_game_data: Node = null
var _test_reputation: Node = null
var _test_get_day: Callable = Callable()


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


## Test-injection seam, mirrors TitheManager.configure_for_test - including
## the get_day Callable, since get_waking_greeting() needs "today" without a
## live TimeManager under /root (the headless harness runs suites in
## SceneTree._initialize(), where /root lookups cannot resolve).
func configure_for_test(
	game_data: Node, player_state: Node, farm_grid: Node = null, reputation: Node = null,
	get_day: Callable = Callable()
) -> void:
	_test_game_data = game_data
	_test_player = player_state
	_farm_grid_ref = farm_grid
	_test_reputation = reputation
	_test_get_day = get_day


## Live FarmGrid reference, injected by main.gd the same way SaveManager and
## TitheManager receive theirs (FarmGrid is not an autoload).
func set_farm_grid_ref(farm_grid: Node) -> void:
	_farm_grid_ref = farm_grid


func get_spouse_id() -> String:
	return _spouse_id


func is_married() -> bool:
	return not _spouse_id.is_empty()


func is_spouse(npc_id: String) -> bool:
	return not npc_id.is_empty() and npc_id == _spouse_id


func is_candidate(npc_id: String) -> bool:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_candidates"):
		return false
	return (gd.get_marriage_candidates() as Array).has(npc_id)


func get_pending_candidate() -> String:
	return _pending_candidate


func is_merchet_paid() -> bool:
	return _merchet_paid


## The fee is owned by tithe.json's merchet_fee; MarriageManager reads it
## rather than duplicating it as a second number to keep in sync.
func get_merchet_fee() -> int:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_tithe_data"):
		return 0
	return int(gd.get_tithe_data().get("merchet_fee", 0))


func can_propose(npc_id: String) -> bool:
	if not _spouse_id.is_empty() or not _pending_candidate.is_empty():
		return false
	if not is_candidate(npc_id):
		return false
	var player := _player()
	if player == null or not player.has_item("betrothal_ring", 1):
		return false
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_config"):
		return false
	var threshold := int(gd.get_marriage_config().get("proposal_opinion_threshold", 0))
	var rep := _reputation()
	return rep != null and rep.has_method("get_opinion") \
		and float(rep.get_opinion(npc_id)) >= threshold


## Consumes the braided ring and records the accepted proposal. There is no
## rejection roll - at the threshold the candidate accepts; the locked
## design does not describe a rejection outcome, so none is invented here.
func propose(npc_id: String) -> bool:
	if not can_propose(npc_id):
		return false
	var player := _player()
	if player == null or not player.remove_item("betrothal_ring", 1):
		return false
	_pending_candidate = npc_id
	_merchet_paid = false
	proposal_made.emit(npc_id)
	marriage_state_changed.emit()
	return true


func can_pay_merchet() -> bool:
	if _pending_candidate.is_empty() or _merchet_paid:
		return false
	var player := _player()
	return player != null and int(player.money) >= get_merchet_fee()


func pay_merchet() -> bool:
	if not can_pay_merchet():
		return false
	var fee := get_merchet_fee()
	var player := _player()
	if player == null or not player.spend_money(fee):
		return false
	_merchet_paid = true
	merchet_paid.emit(_pending_candidate)
	marriage_state_changed.emit()
	return true


func can_ceremonize() -> bool:
	return not _pending_candidate.is_empty() and _merchet_paid and _spouse_id.is_empty()


## Runs once: sets the spouse, clears the pending proposal, and hands the
## reputation-transfer math to ReputationManager.
func ceremonize() -> bool:
	if not can_ceremonize():
		return false
	_spouse_id = _pending_candidate
	_pending_candidate = ""
	_merchet_paid = false
	_last_greeting_day = -1
	_apply_reputation_transfer()
	ceremony_completed.emit(_spouse_id)
	marriage_state_changed.emit()
	return true


## One waking greeting per calendar day, drawn from marriage.json's
## per-candidate greetings list. Empty data means no greeting, not an error.
func get_waking_greeting() -> String:
	if _spouse_id.is_empty():
		return ""
	var day := _current_day()
	if day == _last_greeting_day:
		return ""
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_config"):
		return ""
	var greetings: Array = (gd.get_marriage_config().get("greetings", {}) as Dictionary).get(_spouse_id, [])
	if greetings.is_empty():
		return ""
	_last_greeting_day = day
	return str(greetings[randi() % greetings.size()])


## The mechanical spouse chore for this slice: water up to
## marriage.json's chore_water_cells tilled-but-thirsty cells. Egg
## gathering, compost turning, and weeding have no generic existing API to
## hang off safely, so they stay data-shaped but unimplemented for now
## rather than a half-built guess at a new AnimalManager/FarmGrid surface.
func complete_chore() -> bool:
	var grid := _farm_grid()
	if _spouse_id.is_empty() or grid == null:
		return false
	var gd := _game_data()
	if gd == null:
		return false
	var cfg: Dictionary = gd.get_marriage_config()
	var count := int(cfg.get("chore_water_cells", 0))
	if count <= 0:
		return false
	var amount := float(cfg.get("chore_water_amount", 0.0))
	var candidates: Array[Vector2i] = []
	for y in range(gd.get_map_height()):
		for x in range(gd.get_map_width()):
			var pos := Vector2i(x, y)
			if grid.is_tilled(pos) and grid.get_cell_moisture(pos) < 100.0:
				candidates.append(pos)
	candidates.shuffle()
	var done := 0
	for i in range(mini(count, candidates.size())):
		if grid.water_tile(candidates[i], amount):
			done += 1
	if done > 0:
		spouse_chore_done.emit("water_tiles")
		return true
	return false


func serialize() -> Dictionary:
	return {
		"spouse_id": _spouse_id,
		"pending_candidate": _pending_candidate,
		"merchet_paid": _merchet_paid,
		"last_greeting_day": _last_greeting_day,
	}


func deserialize(data: Dictionary) -> void:
	_spouse_id = str(data.get("spouse_id", ""))
	_pending_candidate = str(data.get("pending_candidate", ""))
	_merchet_paid = bool(data.get("merchet_paid", false))
	_last_greeting_day = int(data.get("last_greeting_day", -1))


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	if _spouse_id.is_empty():
		return
	var gd := _game_data()
	if gd == null or not gd.has_method("get_marriage_config"):
		return
	if randf() < float(gd.get_marriage_config().get("chore_chance_per_day", 0.0)):
		complete_chore()


func _apply_reputation_transfer() -> void:
	var rep := _reputation()
	if rep != null and rep.has_method("apply_marriage_transfer"):
		rep.apply_marriage_transfer(_spouse_id)


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _farm_grid() -> Node:
	return _farm_grid_ref


func _reputation() -> Node:
	if _test_reputation != null:
		return _test_reputation
	return get_node_or_null("/root/ReputationManager")


func _current_day() -> int:
	if _test_get_day.is_valid():
		return _test_get_day.call()
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		return int(tm.get("day"))
	return 1
