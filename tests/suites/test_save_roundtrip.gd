extends RefCounted
## SaveManager coverage: JSON roundtrip (quality inventory, tithe +
## reputation blocks incl. active requests), version guard, v1..v8 -> v9
## migrations, the FarmGrid live-path injection bug (section 0 of the
## Sprint 6 guide), missing file. v18 (ADR-040) adds the tithe block's
## carrying_sheaves and each farm cell's demesne_sheaf to the defaulted
## fields.

const SAVE_MANAGER_SCRIPT := preload("res://scripts/autoloads/save_manager.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const ZONE_MANAGER_SCRIPT := preload("res://scripts/autoloads/zone_manager.gd")

const MINI_CROPS := {
	"turnip": {
		"id": "turnip", "name": "Turnip", "growth_days": 3,
		"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
		"seed_item_id": "turnip_seed", "yield_item_id": "turnip",
		"yield_min": 1, "yield_max": 1,
		"seed_recovery_min": 0, "seed_recovery_max": 0,
		"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	},
}

const MINI_SOIL := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}

## Bug fix (2026-08-10): missing "player_home_interior" - data/zones.json
## added that zone in commit b9f02c0 ("Sprint 16 continuation... interior
## sprites...") but this hardcoded list was never updated to match, so
## _make_zone_manager() below only ever registered nine grids instead of
## the real ten. That fed a stale "expected 10, got 9" failure in
## _test_migrates_v17's zone-manager round-trip assertion - a genuine test
## fixture bug, not a ZoneManager defect (test_zone_manager.gd's own suite,
## which builds its zone list dynamically via GameData.get_zone_ids()
## instead of hardcoding it, never had this problem).
const ZONE_IDS: Array[String] = [
	"fallowfield", "north_strip", "ediths_plot", "nettleford", "manor",
	"upland_commons", "cottersward", "nettle_brook", "south_fields",
	"player_home_interior",
]

const SAMPLE_V5 := {
	"version": 5,
	"time": {"day": 7, "season": "spring", "year": 1, "hour": 14, "minute": 30},
	"player": {
		"energy": 62.5,
		"max_energy": 100.0,
		"health": 50,
		"max_health": 50,
		"money": 12,
		"equipped_tool_id": "hoe_wood",
		"equipped_weapon_id": "spear",
		"arrow_count": 3,
		"pass_out_count": 0,
		"raid_deterrence": 15,
		"wound_days_remaining": 2,
		"total_crops_harvested": 12,
		"total_coins_earned": 80,
		"theft_events": [],
		"inventory": [
			{"item_id": "turnip", "quality": "common", "count": 3},
			{"item_id": "turnip_seed", "quality": "common", "count": 1},
		],
	},
	"farm": {
		"cells": [
			{"x": 0, "y": 0, "tilled": true, "crop_id": "turnip", "growth_progress": 0.5, "moisture": 40.0},
		],
		"storage": [],
	},
	"tithe": {
		"tithe_paid": 5.0,
		"daily_labor_credit": 3.0,
		"church_donations": 2.0,
		"pending_offenses": ["witnessed_violence"],
		"corvee_day": 8,
		"corvee_active": true,
		"corvee_chore_done": false,
		"price_drift": 1.04,
	},
	"reputation": {
		"standings": {"manor": 7.0, "village": -3.0, "church": 2.0},
		"opinions": {"steward": 12.0},
		"active_requests": [
			{"id": "req_1", "npc_id": "steward", "item_id": "barley", "quality": "fine", "quantity": 3, "days_left": 2},
		],
	},
	"investigation": {
		"true_suspect_id": "villager_3",
		"clues": [
			{"suspect_id": "villager_3", "true": true, "text": "A neighbor recalls Marta was not seen at home that night."},
			{"suspect_id": "villager_1", "true": false, "text": "Some say Hilda was acting strangely that day."},
		],
		"revealed": [0],
		"open": true,
		"resolved": false,
	},
}

const SAMPLE_V1 := {
	"version": 1,
	"time": {"day": 3, "season": "spring", "year": 1, "hour": 10, "minute": 0},
	"player": {"energy": 80.0, "max_energy": 100.0, "money": 8, "inventory": {"turnip_seed": 2}},
	"farm": {"tiles": [{"x": 0, "y": 0, "tilled": true, "watered": false, "crop_id": "turnip", "stage": 2}]},
}

const SAMPLE_V2 := {
	"version": 2,
	"time": {"day": 5, "season": "spring", "year": 1, "hour": 9, "minute": 0},
	"player": {"energy": 90.0, "max_energy": 100.0, "money": 20, "inventory": {"turnip": 4}},
	"farm": {"cells": [], "storage": []},
}

const SAMPLE_V3 := {
	"version": 3,
	"time": {"day": 6, "season": "spring", "year": 1, "hour": 8, "minute": 0},
	"player": {
		"energy": 50.0, "max_energy": 100.0, "health": 50, "max_health": 50,
		"money": 9, "equipped_tool_id": "",
		"inventory": [{"item_id": "turnip", "quality": "common", "count": 2}],
	},
	"farm": {"cells": [], "storage": []},
	"tithe": {"tithe_paid": 1.0, "daily_labor_credit": 0.0, "church_donations": 0.0},
}

const SAMPLE_V4 := {
	"version": 4,
	"time": {"day": 7, "season": "spring", "year": 1, "hour": 10, "minute": 0},
	"player": {
		"energy": 60.0, "max_energy": 100.0, "health": 50, "max_health": 50,
		"money": 30, "equipped_tool_id": "hoe_wood",
		"inventory": [{"item_id": "turnip", "quality": "common", "count": 2}],
	},
	"farm": {"cells": [], "storage": []},
	"tithe": {"tithe_paid": 0.0, "daily_labor_credit": 0.0, "church_donations": 0.0},
	"reputation": {"standings": {"manor": 0.0, "village": 0.0, "church": 0.0}, "opinions": {}},
}


func suite_name() -> String:
	return "save_roundtrip"


func run(t: Object) -> void:
	_test_write_read_roundtrip(t)
	_test_rejects_newer_version(t)
	_test_farm_payload_injected(t)
	_test_migrates_v1(t)
	_test_migrates_v2(t)
	_test_migrates_v3(t)
	_test_migrates_v4(t)
	_test_migrates_v5(t)
	_test_migrates_v17(t)
	_test_missing_file_returns_empty(t)
	t.completed(9)


func _test_write_read_roundtrip(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_roundtrip.json"
	t.ok(saver.write_payload(SAMPLE_V5, path), "write_payload succeeds")
	var loaded: Dictionary = saver.read_payload(path)
	t.ok(not loaded.is_empty(), "read_payload returns data")
	t.eq(loaded.get("version", -1), 19, "version survives roundtrip")
	var player: Dictionary = loaded.get("player", {})
	var inventory: Array = player.get("inventory", [])
	t.eq(inventory.size(), 2, "quality inventory survives")
	t.eq(inventory[0].get("quality", ""), "common", "item quality survives")
	var tithe: Dictionary = loaded.get("tithe", {})
	t.eq(float(tithe.get("tithe_paid", -1.0)), 5.0, "tithe state survives")
	t.eq((tithe.get("pending_offenses", []) as Array).size(), 1,
		"pending offenses survive the roundtrip")
	t.eq(int(tithe.get("corvee_day", -1)), 8, "corvee day survives the roundtrip")
	t.eq(float(tithe.get("price_drift", -1.0)), 1.04, "price drift survives the roundtrip")
	var reputation: Dictionary = loaded.get("reputation", {})
	t.eq(float(reputation.get("standings", {}).get("manor", -99.0)), 7.0, "reputation survives")
	t.eq((reputation.get("active_requests", []) as Array).size(), 1,
		"active requests survive the roundtrip")
	t.eq(int(loaded.get("player", {}).get("raid_deterrence", -1)), 15, "combat state survives")
	t.eq(int(loaded.get("player", {}).get("wound_days_remaining", -1)), 2,
		"wound state survives the roundtrip")
	var investigation: Dictionary = loaded.get("investigation", {})
	t.eq(str(investigation.get("true_suspect_id", "")), "villager_3",
		"investigation survives the roundtrip")
	t.eq((investigation.get("revealed", []) as Array).size(), 1,
		"partially revealed clues survive the roundtrip")
	var buildings: Dictionary = loaded.get("buildings", {})
	t.eq((buildings.get("placed", []) as Array).size(), 0,
		"buildings block defaulted by the v8 migration")
	t.eq((buildings.get("rented", {}) as Dictionary).size(), 0,
		"rented strips defaulted empty by the v8 migration")
	var animals: Dictionary = loaded.get("animals", {})
	t.eq((animals.get("animals", {}) as Dictionary).size(), 0,
		"animals block defaulted empty by the v13 migration")
	t.eq(int(animals.get("next_id", -1)), 1, "animal id sequence defaulted by the v13 migration")
	var v14_farm: Dictionary = loaded.get("farm", {})
	var v14_zone: Dictionary = v14_farm.get("zones", {}).get("fallowfield", {})
	var v14_cells: Array = v14_zone.get("cells", [])
	t.eq(float((v14_cells[0] as Dictionary).get("fertility", -1.0)), 100.0,
		"cell fertility defaulted to 100 by the v14 migration")
	t.eq(int(v14_zone.get("daily_dig_count", -1)), 0,
		"daily_dig_count defaulted to 0 by the v14 migration")
	t.eq(str(v14_farm.get("current_zone", "")), "fallowfield",
		"current_zone defaulted to fallowfield by the v19 migration")
	t.eq(int(v14_farm.get("player_tile", {}).get("x", -1)), 12,
		"player_tile x defaulted to the fallowfield spawn by the v19 migration")
	t.eq(int(v14_farm.get("player_tile", {}).get("y", -1)), 10,
		"player_tile y defaulted to the fallowfield spawn by the v19 migration")
	t.eq((loaded.get("player", {}).get("event_flags", []) as Array).size(), 0,
		"player event_flags defaulted empty by the v14 migration")
	t.eq((loaded.get("dialogue", {}) as Dictionary).size(), 0,
		"dialogue history block defaulted empty by the v15 migration")
	t.eq((tithe.get("crop_pressure", {}) as Dictionary).size(), 0,
		"crop_pressure defaulted empty by the v16 migration")
	t.eq((tithe.get("active_orders", []) as Array).size(), 0,
		"active_orders defaulted empty by the v16 migration")
	t.eq(str(loaded.get("marriage", {}).get("spouse_id", "?")), "",
		"marriage block defaulted unmarried by the v17 migration")
	t.eq((reputation.get("pairwise_opinions", {}) as Dictionary).size(), 0,
		"pairwise_opinions defaulted empty by the v17 migration")
	t.eq(int(reputation.get("spouse_gift_count", -1)), 0,
		"spouse_gift_count defaulted by the v17 migration")
	t.eq(int(tithe.get("carrying_sheaves", -1)), 0,
		"carrying_sheaves defaulted by the v18 migration")
	t.not_ok(bool((v14_cells[0] as Dictionary).get("demesne_sheaf", true)),
		"cell demesne_sheaf defaulted false by the v18 migration")
	DirAccess.remove_absolute(path)
	t.section_done("roundtrip")


func _test_rejects_newer_version(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_newer.json"
	t.ok(saver.write_payload({"version": 99}, path), "write newer payload")
	t.ok(saver.read_payload(path).is_empty(), "newer version is refused")
	DirAccess.remove_absolute(path)
	t.section_done("version guard")


func _test_farm_payload_injected(t: Object) -> void:
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(2):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test(MINI_CROPS, soil_map, MINI_SOIL, Vector2i(4, 2))
	var pos := Vector2i(0, 0)
	farm.till_tile(pos)
	farm.plant(pos, "turnip")
	var saver = SAVE_MANAGER_SCRIPT.new()
	saver.set_farm_grid_ref(farm)
	var payload: Dictionary = saver.build_payload()
	t.ok(payload.has("farm"), "farm block present when FarmGrid injected")
	t.ok((payload.get("farm", {}).get("cells", []) as Array).size() > 0,
		"farm cells serialized through the injected reference")
	t.section_done("farm injection")


func _test_migrates_v1(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v1.json"
	t.ok(saver.write_payload(SAMPLE_V1, path), "write v1 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(migrated.get("version", -1), 19, "v1 migrates to version 19")
	var inventory: Array = migrated.get("player", {}).get("inventory", [])
	t.eq(inventory.size(), 1, "dict inventory becomes array")
	t.eq(inventory[0].get("quality", ""), "common", "migrated items are common")
	t.eq((migrated.get("farm", {}).get("zones", {}).get("fallowfield", {}).get("cells", []) as Array).size(), 1,
		"tiles converted to cells under the fallowfield zone")
	t.ok(migrated.has("tithe"), "tithe block added")
	t.ok(migrated.has("reputation"), "reputation block added")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v1")


func _test_migrates_v2(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v2.json"
	t.ok(saver.write_payload(SAMPLE_V2, path), "write v2 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(migrated.get("version", -1), 19, "v2 migrates to version 19")
	var inventory: Array = migrated.get("player", {}).get("inventory", [])
	t.eq(int(inventory[0].get("count", 0)), 4, "count preserved")
	t.ok(migrated.has("reputation"), "reputation block added")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v2")


func _test_migrates_v3(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v3.json"
	t.ok(saver.write_payload(SAMPLE_V3, path), "write v3 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(migrated.get("version", -1), 19, "v3 migrates to version 19")
	var reputation: Dictionary = migrated.get("reputation", {})
	t.eq(float(reputation.get("standings", {}).get("manor", -99.0)), 0.0, "reputation defaults")
	t.eq(float(migrated.get("tithe", {}).get("tithe_paid", -1.0)), 1.0, "tithe preserved")
	t.eq(int(migrated.get("tithe", {}).get("carrying_sheaves", -1)), 0,
		"carrying_sheaves defaulted by the v18 migration")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v3")


func _test_migrates_v4(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v4.json"
	t.ok(saver.write_payload(SAMPLE_V4, path), "write v4 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(migrated.get("version", -1), 19, "v4 migrates to version 19")
	var player: Dictionary = migrated.get("player", {})
	t.eq(str(player.get("equipped_weapon_id", "")), "", "weapon default")
	t.eq(int(player.get("raid_deterrence", -1)), 0, "deterrence default")
	t.eq((player.get("theft_events", []) as Array).size(), 0, "theft events default")
	var tithe: Dictionary = migrated.get("tithe", {})
	t.eq((tithe.get("pending_offenses", []) as Array).size(), 0,
		"pending offenses defaulted by the v10 migration")
	t.eq(int(tithe.get("corvee_day", -99)), -1, "corvee day defaulted")
	t.eq(float(tithe.get("price_drift", -99.0)), 1.0, "price drift defaulted")
	t.eq(int(player.get("wound_days_remaining", -1)), 0,
		"wound defaulted by the v11 migration")
	t.eq(bool(migrated.get("investigation", {}).get("open", true)), false,
		"investigation block defaulted closed by the v11 migration")
	var animals: Dictionary = migrated.get("animals", {})
	t.eq((animals.get("animals", {}) as Dictionary).size(), 0,
		"animals block defaulted empty by the v13 migration")
	t.eq(int(animals.get("next_id", -1)), 1, "animal id sequence defaulted by the v13 migration")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v4")


func _test_migrates_v5(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v5.json"
	t.ok(saver.write_payload(SAMPLE_V5, path), "write v5 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(migrated.get("version", -1), 19, "v5 migrates to version 19")
	var cells: Array = migrated.get("farm", {}).get("zones", {}).get("fallowfield", {}).get("cells", [])
	var cell0 := cells[0] as Dictionary
	t.eq(int(cell0.get("days_mature", -1)), 0, "days_mature defaulted on v5 cells")
	t.not_ok(bool(cell0.get("demesne_sheaf", true)),
		"cell demesne_sheaf defaulted false by the v18 migration")
	t.ok(migrated.has("buildings"), "buildings block added by the v8 migration")
	var crafting: Dictionary = migrated.get("crafting", {})
	t.ok(migrated.has("crafting"), "crafting block added by the v12 migration")
	t.eq((crafting.get("pending", []) as Array).size(), 0,
		"crafting pending defaults to an empty array")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v5")


const SAMPLE_V17 := {
	"version": 17,
	"farm": {
		"cells": [
			{"x": 0, "y": 0, "tilled": true, "crop_id": "turnip",
				"growth_progress": 1.0, "moisture": 60.0, "days_mature": 2,
				"forage_item_id": "wild_berry", "forage_yield": 2, "fertility": 100.0},
		],
		"daily_dig_count": 3,
		"storage": [],
	},
	"buildings": {
		"placed": [
			{"building_id": "storage_chest", "x": 3, "y": 3, "w": 1, "h": 1,
				"days_remaining": 0, "complete": true},
		],
		"rented": {},
	},
}


func _make_zone_manager() -> Object:
	var grids := {}
	for zone_id: String in ZONE_IDS:
		var grid = FARM_GRID_SCRIPT.new()
		var soil_map := {}
		for y in range(2):
			for x in range(4):
				soil_map[Vector2i(x, y)] = "loamy"
		grid.configure_for_test(MINI_CROPS, soil_map, MINI_SOIL, Vector2i(4, 2), {}, [], zone_id)
		grids[zone_id] = grid
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(null, grids, "fallowfield")
	return zm


## Sprint 15a (ADR-034): the zone-wrap migration (renumbered to v19 - ADR-040
## independently claimed v18 the same day, see save_manager.gd's header)
## wraps every existing farm cell under fallowfield without rewriting it,
## defaults the player to the fallowfield spawn, stamps every existing
## building with fallowfield, and consumes the flat farm.cells shape. The
## guide's required assertions are the migration's non-destructive-wrap
## property: cell fields (fertility, days_mature, forage) must survive
## byte-for-byte.
func _test_migrates_v17(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	var path := "user://test_save_v17.json"
	t.ok(saver.write_payload(SAMPLE_V17, path), "write v17 payload")
	var migrated: Dictionary = saver.read_payload(path)
	t.eq(int(migrated.get("version", -1)), 19, "v17 migrates to version 19")
	var farm: Dictionary = migrated.get("farm", {})
	var fallow: Dictionary = farm.get("zones", {}).get("fallowfield", {})
	var cells: Array = fallow.get("cells", [])
	t.eq(cells.size(), 1, "v17 cells wrap under fallowfield")
	var cell := cells[0] as Dictionary
	t.eq(float(cell.get("fertility", -1.0)), 100.0, "cell fertility survives the wrap untouched")
	t.eq(int(cell.get("days_mature", -1)), 2, "cell days_mature survives the wrap untouched")
	t.eq(str(cell.get("forage_item_id", "")), "wild_berry", "cell forage survives the wrap untouched")
	t.eq(int(cell.get("growth_progress", -1)), 1, "cell growth_progress survives the wrap untouched")
	t.eq(str(farm.get("current_zone", "")), "fallowfield", "no-zone saves default to the player's plot")
	t.eq(int(farm.get("player_tile", {}).get("x", -1)), 12, "player defaults to the fallowfield spawn tile")
	t.eq(int(farm.get("player_tile", {}).get("y", -1)), 10, "player default y is the fallowfield spawn tile")
	t.eq(str((migrated.get("buildings", {}).get("placed", [])[0] as Dictionary).get("zone_id", "")),
		"fallowfield", "existing buildings default to the holding")
	t.ok(not farm.has("cells"), "flat farm.cells is consumed by the v19 migration")
	t.eq(int(fallow.get("daily_dig_count", -1)), 3, "daily_dig_count moves under the fallowfield zone")

	var zm := _make_zone_manager()
	zm.from_dict(farm)
	var dumped: Dictionary = zm.to_dict()
	t.eq((dumped.get("zones", {}) as Dictionary).size(), 10,
		"zone-manager round-trip keeps all ten zone keys")
	t.eq(str(dumped.get("current_zone", "")), "fallowfield", "current_zone restores exactly")
	t.eq(int(dumped.get("player_tile", {}).get("x", -1)), 12, "player_tile restores exactly")
	var restored_cells: Array = dumped.get("zones", {}).get("fallowfield", {}).get("cells", [])
	var restored_tilled := false
	for entry: Variant in restored_cells:
		if bool((entry as Dictionary).get("tilled", false)):
			restored_tilled = true
	t.ok(restored_tilled, "fallowfield cell state restores through the zone manager")
	DirAccess.remove_absolute(path)
	t.section_done("migrate v17")


func _test_missing_file_returns_empty(t: Object) -> void:
	var saver = SAVE_MANAGER_SCRIPT.new()
	t.ok(saver.read_payload("user://does_not_exist.json").is_empty(),
		"missing file yields empty dict")
	t.section_done("missing file")
