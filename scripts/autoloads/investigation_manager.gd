extends Node

## InvestigationManager autoload (ADR-026) - the day-19 theft's accusation
## flow. RaidManager starts an investigation with the true suspect (the
## villager whose traits list contains "thief"); talking to villagers reveals
## clues in shuffled order ("any villager might have heard something", not a
## per-NPC assignment); accusing whoever you are talking to resolves it.
## A correct accusation rewards standing and drops the thief's opinion; a
## false one hits village standing, drops the innocent's opinion, and queues
## a false_accusation offense for the Sprint 11 manor court.
##
## X6 mercy path (world_bible.md Section VII): once the true clue is among
## the revealed set, the player can show mercy to the true suspect instead -
## a third terminal resolution with no standing change, a data-driven
## private opinion gain, and the "investigation.showed_mercy_<id>" event
## flag RaidManager reads so future thefts taper off. AUTOLOAD - no
## class_name. State serializes for save v11.

signal clues_revealed(clues: Array)
signal accusation_resolved(suspect_id: String, correct: bool)
signal mercy_shown(suspect_id: String)

var _true_suspect_id := ""
var _clues: Array[Dictionary] = []
var _revealed_clue_indices: Array[int] = []
var _investigation_open := false
var _resolved := false

var _test_game_data: Node = null
var _test_reputation: Node = null
var _test_player: Node = null
var _test_mode := false


## The reputation seam drives the live side-effect path in tests (the headless
## harness runs in SceneTree._initialize, where /root cannot resolve). Side
## effects fire whenever the ref resolves - null is a no-op. The court offense
## is NOT queued here: TitheManager._ready wires ReputationManager's
## action_applied into _on_reputation_action, which is the single place a
## false accusation becomes a fine (mirrors the attack_villager path).
func configure_for_test(game_data: Node, reputation: Node = null, player_state: Node = null) -> void:
	_test_game_data = game_data
	_test_reputation = reputation
	_test_player = player_state
	_test_mode = true


func start_investigation(true_suspect_id: String) -> void:
	_true_suspect_id = true_suspect_id
	_clues = _generate_clues(true_suspect_id)
	_revealed_clue_indices = []
	_investigation_open = true
	_resolved = false


func reveal_clue_for(_npc_id: String) -> Dictionary:
	if not _investigation_open:
		return {}
	for i in range(_clues.size()):
		if not _revealed_clue_indices.has(i):
			_revealed_clue_indices.append(i)
			clues_revealed.emit(get_revealed_clues())
			return _clues[i]
	return {}


func get_revealed_clues() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for i: int in _revealed_clue_indices:
		out.append(_clues[i])
	return out


func can_accuse() -> bool:
	return _investigation_open and not _resolved


## Mercy-path gate (world_bible.md Section VII): the player must know it is
## the true suspect - the true clue ("true": true, the alibi recollection)
## must actually be among the revealed clues, not just N arbitrary clues
## (decoys alone tell the player nothing) - and must be talking to that
## suspect. Terminal, exactly like accusation.
func can_show_mercy(npc_id: String) -> bool:
	if not can_accuse():
		return false
	if npc_id != _true_suspect_id:
		return false
	return _true_clue_revealed()


## Resolves the investigation mercifully: no manor/village/church standing
## change and no court offense (deliberately NOT via apply_action - the
## "show_mercy" reputation action carries only an opinion_delta, read here
## and applied through modify_opinion), a private opinion gain for the true
## suspect, and the "investigation.showed_mercy_<suspect_id>" event flag
## that lets RaidManager taper the thefts off.
func show_mercy(npc_id: String) -> bool:
	if not can_show_mercy(npc_id):
		return false
	_resolved = true
	_investigation_open = false
	mercy_shown.emit(_true_suspect_id)
	var rep := _reputation()
	if rep != null:
		var amount := _mercy_opinion_gain()
		if amount != 0.0:
			rep.modify_opinion(_true_suspect_id, amount)
	var player := _player()
	if player != null and player.has_method("set_event_flag"):
		player.set_event_flag("investigation.showed_mercy_%s" % _true_suspect_id)
	return true


func accuse(suspect_id: String) -> bool:
	if not can_accuse():
		return false
	_resolved = true
	_investigation_open = false
	var correct := suspect_id == _true_suspect_id
	accusation_resolved.emit(suspect_id, correct)
	var rep := _reputation()
	if rep != null:
		rep.apply_action("accuse_correctly" if correct else "accuse_falsely", suspect_id)
	return correct


func to_dict() -> Dictionary:
	return {
		"true_suspect_id": _true_suspect_id,
		"clues": _clues.duplicate(true),
		"revealed": _revealed_clue_indices.duplicate(),
		"open": _investigation_open,
		"resolved": _resolved,
	}


func from_dict(data: Dictionary) -> void:
	_true_suspect_id = str(data.get("true_suspect_id", ""))
	_clues = []
	for entry: Variant in data.get("clues", []):
		_clues.append((entry as Dictionary).duplicate())
	_revealed_clue_indices = []
	for i: Variant in data.get("revealed", []):
		_revealed_clue_indices.append(int(i))
	_investigation_open = bool(data.get("open", false))
	_resolved = bool(data.get("resolved", false))


## Exactly one true clue (a neighbor's alibi for the real thief) plus shuffled
## decoy lines, so the player must actually investigate rather than pattern
## match the data file.
func _generate_clues(true_suspect_id: String) -> Array[Dictionary]:
	var gd := _game_data()
	if gd == null:
		return []
	var decoys: Array = []
	for id: String in gd.get_all_villager_ids():
		if id != true_suspect_id:
			decoys.append(id)
	decoys.shuffle()
	var clue_count := int(gd.get_clues_config().get("clue_count", 3))
	var clues: Array[Dictionary] = []
	clues.append({
		"suspect_id": true_suspect_id,
		"true": true,
		"text": "A neighbor recalls %s was not seen at home that night." \
			% str(gd.get_villager(true_suspect_id).get("name", true_suspect_id)),
	})
	for i in range(mini(clue_count - 1, decoys.size())):
		var suspect: String = decoys[i]
		clues.append({
			"suspect_id": suspect,
			"true": false,
			"text": "Some say %s was acting strangely that day." \
				% str(gd.get_villager(suspect).get("name", suspect)),
		})
	clues.shuffle()
	return clues


## The true clue is the decisive piece: the alibi recollection naming the
## real suspect, versus the decoys' vague "some say" gossip.
func _true_clue_revealed() -> bool:
	for clue: Dictionary in get_revealed_clues():
		if bool(clue.get("true", false)):
			return true
	return false


## data/reputation.json "show_mercy" action - opinion_delta only; the
## manor/village/church keys are deliberately 0 so no standing change can
## sneak in through a shared path.
func _mercy_opinion_gain() -> float:
	var gd := _game_data()
	if gd == null:
		return 0.0
	var effect: Dictionary = gd.get_reputation_effect("show_mercy")
	return float(effect.get("opinion_delta", 0))


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _reputation() -> Node:
	if _test_reputation != null:
		return _test_reputation
	return get_node_or_null("/root/ReputationManager")


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")
