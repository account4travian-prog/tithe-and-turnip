extends Node

## Life skills (farming / foraging / combat / labor). XP -> level from
## skills.json's per-skill xp_thresholds; get_effect looks up the CURRENT
## level's absolute effect table (not a running sum - level_effects[i] is
## the value AT level i). AUTOLOAD - no class_name. ADR-021/ADR-022.
##
## DESKTOP: this script must be registered as an autoload (Project Settings
## -> Autoload, Node Name "SkillManager") before anything that calls
## get_node_or_null("/root/SkillManager") will find it.

signal xp_gained(skill_id: String, amount: float, total: float)
signal leveled_up(skill_id: String, new_level: int)

const SKILL_IDS: Array[String] = ["farming", "foraging", "combat", "labor"]

var _xp: Dictionary = {"farming": 0.0, "foraging": 0.0, "combat": 0.0, "labor": 0.0}
var _test_game_data: Node = null


func configure_for_test(game_data: Node) -> void:
	_test_game_data = game_data


func add_xp(skill_id: String, amount: float) -> void:
	if amount <= 0.0 or not _xp.has(skill_id):
		return
	var before := get_level(skill_id)
	_xp[skill_id] = float(_xp.get(skill_id, 0.0)) + amount
	xp_gained.emit(skill_id, amount, _xp[skill_id])
	var after := get_level(skill_id)
	if after > before:
		leveled_up.emit(skill_id, after)


func add_xp_for(skill_id: String, source_id: String) -> void:
	var gd := _game_data()
	if gd == null:
		return
	add_xp(skill_id, gd.get_skill_xp_source(skill_id, source_id))


func get_xp(skill_id: String) -> float:
	return float(_xp.get(skill_id, 0.0))


func get_level(skill_id: String) -> int:
	var gd := _game_data()
	if gd == null:
		return 0
	var thresholds: Array = gd.get_skill_xp_thresholds(skill_id)
	var xp := get_xp(skill_id)
	var level := 0
	for i in range(thresholds.size()):
		if xp >= float(thresholds[i]):
			level = i
	return level


func get_xp_to_next(skill_id: String) -> float:
	var gd := _game_data()
	if gd == null:
		return -1.0
	var thresholds: Array = gd.get_skill_xp_thresholds(skill_id)
	var level := get_level(skill_id)
	if level + 1 >= thresholds.size():
		return -1.0
	return float(thresholds[level + 1]) - get_xp(skill_id)


func get_effect(skill_id: String, key: String, default: Variant = 0) -> Variant:
	var gd := _game_data()
	if gd == null:
		return default
	return gd.get_skill_level_effects(skill_id, get_level(skill_id)).get(key, default)


func to_dict() -> Dictionary:
	return {"xp": _xp.duplicate()}


func from_dict(data: Dictionary) -> void:
	var xp: Dictionary = data.get("xp", {})
	for skill_id: String in _xp.keys():
		_xp[skill_id] = float(xp.get(skill_id, 0.0))


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")
