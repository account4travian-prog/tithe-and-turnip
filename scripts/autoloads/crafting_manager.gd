extends Node

## CraftingManager autoload - executes recipes from data/recipes.json:
## skill-gated by SkillManager levels, station-gated by completed
## BuildingManager buildings (existence-anywhere; proximity is enforced one
## layer up at the panel, which only opens for the station tile the player
## stands next to - so this manager never needs a live Player reference).
## Crafting consumes/produces "common"-quality stacks only (Sprint 13 guide
## ruling: no quality propagation). AUTOLOAD - no class_name.

signal crafting_started(recipe_id: String)
signal item_crafted(recipe_id: String, output_item_id: String, count: int)

var _pending: Array[Dictionary] = []  # {recipe_id, days_remaining}

var _test_player: Node = null
var _test_game_data: Node = null
var _test_skill: Node = null
var _test_building: Node = null
var _test_mode := false


func _ready() -> void:
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null and not tm.day_passed.is_connected(_on_day_passed):
		tm.day_passed.connect(_on_day_passed)


func configure_for_test(player_state: Node, game_data: Node, skill_manager: Node = null, building_manager: Node = null) -> void:
	_test_player = player_state
	_test_game_data = game_data
	_test_skill = skill_manager
	_test_building = building_manager
	_test_mode = true


func can_craft(recipe_id: String) -> bool:
	var gd := _game_data()
	if gd == null:
		return false
	var recipe: Dictionary = gd.get_recipe(recipe_id)
	if recipe.is_empty():
		return false
	if not _station_available(str(recipe.get("station", ""))):
		return false
	var skill_id := str(recipe.get("skill_id", ""))
	if not skill_id.is_empty():
		var skill := _skill_manager()
		if skill != null and skill.get_level(skill_id) < int(recipe.get("skill_level_required", 0)):
			return false
	var player := _player()
	if player == null:
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id: Variant in inputs:
		if not player.has_item(str(item_id), int(inputs[item_id]), "common"):
			return false
	return player.energy >= float(recipe.get("energy_cost", 0))


func craft(recipe_id: String) -> bool:
	if not can_craft(recipe_id):
		return false
	var gd := _game_data()
	var recipe: Dictionary = gd.get_recipe(recipe_id)
	var player := _player()
	if not player.consume_energy(float(recipe.get("energy_cost", 0))):
		return false
	var inputs: Dictionary = recipe.get("inputs", {})
	for item_id: Variant in inputs:
		player.remove_item(str(item_id), int(inputs[item_id]), "common")
	var craft_days := int(recipe.get("craft_days", 0))
	if craft_days <= 0:
		_finish_craft(recipe)
	else:
		_pending.append({"recipe_id": recipe_id, "days_remaining": craft_days})
		crafting_started.emit(recipe_id)
	return true


## Debug-only lever (Ctrl+K cheat panel): finish every pending craft
## immediately instead of waiting for day_passed to tick it down.
func force_finish_all() -> void:
	var gd := _game_data()
	if gd == null:
		return
	for entry: Variant in _pending:
		var p := entry as Dictionary
		_finish_craft(gd.get_recipe(str(p.get("recipe_id", ""))))
	_pending.clear()


func get_pending() -> Array[Dictionary]:
	return _pending.duplicate(true)


func to_dict() -> Dictionary:
	return {"pending": _pending.duplicate(true)}


func from_dict(data: Dictionary) -> void:
	_pending = []
	for entry: Variant in data.get("pending", []):
		_pending.append((entry as Dictionary).duplicate())


func _finish_craft(recipe: Dictionary) -> void:
	var player := _player()
	var count := int(recipe.get("output_count", 1))
	player.add_item(str(recipe.get("output_item_id", "")), count)
	item_crafted.emit(str(recipe.get("id", "")), str(recipe.get("output_item_id", "")), count)


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	var still: Array[Dictionary] = []
	for entry: Variant in _pending:
		var p := entry as Dictionary
		p["days_remaining"] = int(p.get("days_remaining", 0)) - 1
		if int(p["days_remaining"]) <= 0:
			var gd := _game_data()
			if gd != null:
				_finish_craft(gd.get_recipe(str(p.get("recipe_id", ""))))
		else:
			still.append(p)
	_pending = still


func _station_available(station_id: String) -> bool:
	if station_id.is_empty():
		return true
	var bm := _building_manager()
	if bm == null:
		return true  # BuildingManager not present (older save / Sprint 9 not applied) - don't hard-block
	for b: Dictionary in bm.get_completed_buildings():
		if str(b.get("building_id", "")) == station_id:
			return true
	return false


func _player() -> Node:
	if _test_player != null:
		return _test_player
	return get_node_or_null("/root/PlayerState")


func _game_data() -> Node:
	if _test_game_data != null:
		return _test_game_data
	return get_node_or_null("/root/GameData")


func _skill_manager() -> Node:
	if _test_skill != null:
		return _test_skill
	return get_node_or_null("/root/SkillManager")


func _building_manager() -> Node:
	if _test_building != null:
		return _test_building
	return get_node_or_null("/root/BuildingManager")
