extends RefCounted
## CraftingManager coverage (Sprint 13): station gate, skill gate,
## ingredient/energy gates, instant craft, overnight fermentation, and
## pending-craft save round-trip. Uses the REAL shipped data
## (GameData + recipes.json/items.json) with a seeded PlayerState and real
## SkillManager/BuildingManager configured for tests.

const CRAFTING_MANAGER_SCRIPT := preload("res://scripts/autoloads/crafting_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const SKILL_MANAGER_SCRIPT := preload("res://scripts/autoloads/skill_manager.gd")
const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")


func suite_name() -> String:
	return "crafting"


func run(t: Object) -> void:
	_test_station_gate(t)
	_test_skill_gate(t)
	_test_ingredient_gate(t)
	_test_energy_gate(t)
	_test_instant_craft(t)
	_test_overnight_craft(t)
	_test_save_roundtrip(t)
	t.completed(29)


func _make_env() -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = 1000
	player.add_item("flint", 100)
	var skill = SKILL_MANAGER_SCRIPT.new()
	skill.configure_for_test(gd)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	var cm = CRAFTING_MANAGER_SCRIPT.new()
	cm.configure_for_test(player, gd, skill, bm)
	return {"cm": cm, "player": player, "gd": gd, "skill": skill, "bm": bm}


func _build_station(bm: Object, building_id: String, pos: Vector2i, build_days: int) -> void:
	bm.start_building(building_id, pos)
	for i in range(build_days):
		bm._on_day_passed(i + 1, "spring", 1)


func _test_station_gate(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	(env["skill"] as Object).add_xp("farming", 80.0)
	player.add_item("turnip", 3)
	t.not_ok(cm.can_craft("dried_turnip"),
		"can_craft false with no station built")
	_build_station(env["bm"], "drying_shed", Vector2i(8, 8), 2)
	t.ok(cm.can_craft("dried_turnip"),
		"can_craft true once the drying shed is completed")
	t.section_done("station gate")


func _test_skill_gate(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	player.add_item("turnip", 3)
	_build_station(env["bm"], "drying_shed", Vector2i(8, 8), 2)
	t.not_ok(cm.can_craft("dried_turnip"),
		"farming level 0 below required 1 blocks the recipe")
	(env["skill"] as Object).add_xp("farming", 80.0)
	t.ok(cm.can_craft("dried_turnip"),
		"farming level 1 meets the gate")
	player.add_item("barley", 4)
	_build_station(env["bm"], "hearth", Vector2i(10, 10), 1)
	t.not_ok(cm.can_craft("barley_ale"),
		"farming level 1 below required 2 blocks the ale")
	(env["skill"] as Object).add_xp("farming", 120.0)
	t.ok(cm.can_craft("barley_ale"),
		"farming level 2 meets the ale gate")
	t.section_done("skill gate")


func _test_ingredient_gate(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	_build_station(env["bm"], "drying_shed", Vector2i(8, 8), 2)
	(env["skill"] as Object).add_xp("farming", 80.0)
	t.not_ok(cm.can_craft("dried_turnip"),
		"missing ingredients block the recipe")
	player.add_item("turnip", 2)
	t.not_ok(cm.can_craft("dried_turnip"),
		"2 turnips below the 3 required still block")
	player.add_item("turnip", 1)
	t.ok(cm.can_craft("dried_turnip"),
		"exactly 3 turnips pass the ingredient gate")
	t.section_done("ingredient gate")


func _test_energy_gate(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	_build_station(env["bm"], "drying_shed", Vector2i(8, 8), 2)
	(env["skill"] as Object).add_xp("farming", 80.0)
	player.add_item("turnip", 3)
	player.energy = 2.0
	t.not_ok(cm.can_craft("dried_turnip"),
		"energy below the 3 cost blocks the recipe")
	player.energy = 3.0
	t.ok(cm.can_craft("dried_turnip"),
		"energy exactly at the cost passes")
	t.section_done("energy gate")


func _test_instant_craft(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	_build_station(env["bm"], "drying_shed", Vector2i(8, 8), 2)
	(env["skill"] as Object).add_xp("farming", 80.0)
	player.add_item("turnip", 3)
	player.energy = 100.0
	t.ok(cm.craft("dried_turnip"), "instant craft succeeds")
	t.eq(player.get_item_count("turnip"), 0, "3 turnips consumed immediately")
	t.eq(player.energy, 97.0, "3 energy consumed immediately")
	t.eq(player.get_item_count("dried_turnip"), 1, "1 dried turnip produced immediately")
	t.eq(cm.get_pending().size(), 0, "no pending entry for an instant craft")
	t.section_done("instant craft")


func _test_overnight_craft(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	_build_station(env["bm"], "hearth", Vector2i(10, 10), 1)
	(env["skill"] as Object).add_xp("farming", 200.0)
	player.add_item("barley", 4)
	player.energy = 100.0
	var started: Array = []
	cm.crafting_started.connect(func(recipe_id: String) -> void:
		started.append(recipe_id))
	t.ok(cm.craft("barley_ale"), "ale craft starts")
	t.eq(player.get_item_count("barley"), 0, "4 barley consumed immediately")
	t.eq(player.energy, 96.0, "4 energy consumed immediately")
	t.eq(player.get_item_count("barley_ale"), 0,
		"ale not produced until a day passes")
	var pending: Array = cm.get_pending()
	t.eq(pending.size(), 1, "one pending entry right after craft")
	t.eq(int((pending[0] as Dictionary).get("days_remaining", -1)), 1,
		"pending entry carries days_remaining 1")
	t.eq(started.size(), 1, "crafting_started fired exactly once")
	var crafted: Array = []
	cm.item_crafted.connect(func(recipe_id: String, output_item_id: String, count: int) -> void:
		crafted.append([recipe_id, output_item_id, count]))
	cm._on_day_passed(2, "spring", 1)
	t.eq(player.get_item_count("barley_ale"), 1, "ale appears after one day passes")
	t.eq(cm.get_pending().size(), 0, "pending is empty after the day passes")
	t.eq(crafted.size(), 1, "item_crafted fired exactly once")
	t.eq(crafted[0], ["barley_ale", "barley_ale", 1],
		"item_crafted carried recipe/output/count")
	t.section_done("overnight craft")


func _test_save_roundtrip(t: Object) -> void:
	var env := _make_env()
	var cm: Object = env["cm"]
	var player: Object = env["player"]
	_build_station(env["bm"], "hearth", Vector2i(10, 10), 1)
	(env["skill"] as Object).add_xp("farming", 200.0)
	player.add_item("barley", 4)
	t.ok(cm.craft("barley_ale"), "precondition: start an overnight craft")
	var dumped: Dictionary = cm.to_dict()
	t.eq((dumped.get("pending", []) as Array).size(), 1,
		"to_dict carries the pending craft")
	var restored = CRAFTING_MANAGER_SCRIPT.new()
	restored.configure_for_test(player, env["gd"], env["skill"], env["bm"])
	restored.from_dict(dumped)
	var pending: Array = restored.get_pending()
	t.eq(pending.size(), 1, "from_dict restores one pending craft")
	t.eq(str((pending[0] as Dictionary).get("recipe_id", "")), "barley_ale",
		"recipe id round-trips")
	t.eq(int((pending[0] as Dictionary).get("days_remaining", -1)), 1,
		"days_remaining round-trips")
	t.section_done("save roundtrip")
