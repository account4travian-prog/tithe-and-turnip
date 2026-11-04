extends RefCounted
## BuildingManager coverage: footprint validation, coin/material deduction,
## multi-day construction, instant fences, and save-shape roundtrip. Uses the
## REAL shipped data (GameData + buildings.json) with a seeded PlayerState.

const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")


func suite_name() -> String:
	return "buildings"


func run(t: Object) -> void:
	_test_can_place_bounds(t)
	_test_can_place_zone_gate(t)
	_test_overlap(t)
	_test_start_deducts(t)
	_test_insufficient_funds(t)
	_test_insufficient_materials(t)
	_test_failed_placement_deducts_nothing(t)
	_test_multi_day_construction(t)
	_test_instant_fence(t)
	_test_save_roundtrip(t)
	t.completed(16)


func _make_manager(money: int, flint: int, wood: int = 0) -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = money
	if flint > 0:
		player.add_item("flint", flint)
	if wood > 0:
		player.add_item("wood", wood)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	return {"bm": bm, "player": player, "gd": gd}


func _test_can_place_bounds(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	t.ok(bm.can_place_building("storage_chest", Vector2i(5, 5)),
		"can_place true on empty, in-bounds ground")
	t.ok(bm.can_place_building("storage_chest", Vector2i(23, 15)),
		"can_place true at fallowfield's last tile (24x16)")
	t.not_ok(bm.can_place_building("storage_chest", Vector2i(24, 0)),
		"can_place false when the footprint origin is outside the holding")
	t.not_ok(bm.can_place_building("storage_chest", Vector2i(30, 0)),
		"can_place false for the old 30x20 out-of-bounds tile")
	t.not_ok(bm.can_place_building("drying_shed", Vector2i(23, 15)),
		"2x2 footprint at the fallowfield corner exceeds the farm bounds")
	t.not_ok(bm.can_place_building("no_such_building", Vector2i(5, 5)),
		"unknown building id is rejected")
	t.section_done("can_place bounds")


## ADR-034: building placement is gated to zones whose allow_buildings is
## true - only Fallowfield - regardless of tile or funds.
func _test_can_place_zone_gate(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	t.not_ok(bm.can_place_building("storage_chest", Vector2i(5, 5), "nettleford"),
		"can_place false in nettleford (no buildings outside the holding)")
	t.not_ok(bm.can_place_building("storage_chest", Vector2i(5, 5), "north_strip"),
		"can_place false on a rented strip (arable-only)")
	t.not_ok(bm.can_place_building("storage_chest", Vector2i(5, 5), "not_a_zone"),
		"can_place false for an unknown zone")
	t.ok(bm.can_place_building("storage_chest", Vector2i(5, 5), "fallowfield"),
		"can_place true on the holding with an explicit zone id")
	t.section_done("can_place zone gate")


func _test_overlap(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	t.ok(bm.start_building("drying_shed", Vector2i(8, 8)),
		"precondition: 2x2 building places")
	t.not_ok(bm.can_place_building("drying_shed", Vector2i(8, 8)),
		"identical tile is blocked by the placed building (even while in-progress)")
	t.not_ok(bm.can_place_building("drying_shed", Vector2i(9, 8)),
		"footprint sharing a column with the placed 2x2 is blocked")
	t.not_ok(bm.can_place_building("drying_shed", Vector2i(8, 9)),
		"footprint sharing a row with the placed 2x2 is blocked")
	t.ok(bm.can_place_building("drying_shed", Vector2i(10, 10)),
		"non-overlapping 2x2 position is free")
	t.section_done("overlap")


func _test_start_deducts(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	var player: Object = env["player"]
	t.ok(bm.start_building("storage_chest", Vector2i(2, 2)),
		"storage chest starts building with funds + materials")
	t.eq(int(player.money), 960, "cost_coin 40 deducted from 1000")
	t.eq(int(player.get_item_count("flint")), 95, "flint x5 deducted from 100")
	t.section_done("deduction")


func _test_insufficient_funds(t: Object) -> void:
	var env := _make_manager(10, 100)
	var bm: Object = env["bm"]
	var player: Object = env["player"]
	t.not_ok(bm.start_building("storage_chest", Vector2i(2, 2)),
		"start fails with 10 coin vs 40 required")
	t.eq(int(player.money), 10, "money unchanged on failure")
	t.eq(int(player.get_item_count("flint")), 100, "flint unchanged on failure")
	t.section_done("insufficient funds")


func _test_insufficient_materials(t: Object) -> void:
	var env := _make_manager(1000, 1)
	var bm: Object = env["bm"]
	var player: Object = env["player"]
	t.not_ok(bm.start_building("storage_chest", Vector2i(2, 2)),
		"start fails with 1 flint vs 5 required")
	t.eq(int(player.money), 1000, "money unchanged when materials are short")
	t.eq(int(player.get_item_count("flint")), 1, "flint unchanged when materials are short")
	t.section_done("insufficient materials")


func _test_failed_placement_deducts_nothing(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	var player: Object = env["player"]
	bm.start_building("storage_chest", Vector2i(5, 5))
	t.not_ok(bm.start_building("storage_chest", Vector2i(5, 5)),
		"overlapping placement is refused")
	t.eq(int(player.money), 960, "no second deduction on refused overlap")
	t.eq(int(player.get_item_count("flint")), 95, "no second material deduction")
	t.section_done("failed placement")


func _test_multi_day_construction(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	t.ok(bm.start_building("drying_shed", Vector2i(8, 8)),
		"drying shed (2 build days) starts")
	t.eq(bm.get_completed_buildings().size(), 0,
		"2-day building is not complete immediately")
	bm._on_day_passed(1, "spring", 1)
	t.eq(bm.get_completed_buildings().size(), 0,
		"2-day building still not complete after 1 day")
	bm._on_day_passed(2, "spring", 1)
	t.eq(bm.get_completed_buildings().size(), 1,
		"2-day building completes after 2 day_passed calls")
	t.section_done("construction timer")


func _test_instant_fence(t: Object) -> void:
	var env := _make_manager(1000, 100, 100)
	var bm: Object = env["bm"]
	var player: Object = env["player"]
	t.ok(bm.start_building("fence", Vector2i(0, 10)),
		"fence (build_days 0) places")
	var completed: Array = bm.get_completed_buildings()
	t.eq(completed.size(), 1, "fence is complete immediately")
	t.eq(str((completed[0] as Dictionary).get("building_id", "")), "fence",
		"completed entry is the fence")
	t.eq(int(player.get_item_count("wood")), 98, "fence deducts 2 wood")
	t.section_done("instant build")


func _test_save_roundtrip(t: Object) -> void:
	var env := _make_manager(1000, 100)
	var bm: Object = env["bm"]
	bm.start_building("storage_chest", Vector2i(3, 3))
	bm.start_building("drying_shed", Vector2i(10, 10))
	bm._on_day_passed(1, "spring", 1)
	var dumped: Dictionary = bm.to_dict()
	t.eq((dumped.get("placed", []) as Array).size(), 2,
		"to_dict carries both buildings")
	var restored = BUILDING_MANAGER_SCRIPT.new()
	restored.configure_for_test(env["player"], env["gd"])
	restored.from_dict(dumped)
	var placed: Array = restored.get_placed_buildings()
	t.eq(placed.size(), 2, "from_dict restores both buildings")
	var chest_zone := placed[0] as Dictionary
	t.eq(str(chest_zone.get("zone_id", "")), "fallowfield",
		"placed entries carry their zone id")
	t.eq(restored.get_placed_buildings("fallowfield").size(), 2,
		"zone-filtered listing returns the holding's buildings")
	t.eq(restored.get_placed_buildings("nettleford").size(), 0,
		"zone-filtered listing is empty for another zone")
	var shed := placed[1] as Dictionary
	t.eq(int(shed.get("days_remaining", -1)), 1,
		"in-progress days_remaining round-trips exactly")
	t.eq(bool(shed.get("complete", true)), false,
		"in-progress complete flag round-trips as false")
	var chest := placed[0] as Dictionary
	t.eq(bool(chest.get("complete", false)), true,
		"finished 1-day building round-trips as complete")
	t.section_done("save roundtrip")
