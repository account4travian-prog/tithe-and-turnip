extends RefCounted
## FarmGrid v2 basics: till/plant rules, watering-gated growth, rain, harvest,
## and season restriction. Uses configure_for_test so the suite is independent
## of GameData; TimeManager autoload provides the season (spring in tests).

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

const CROP_DB := {
	"turnip": {
		"id": "turnip", "name": "Turnip", "growth_days": 4,
		"seasons": ["spring"], "moisture_min": 20, "moisture_max": 80,
		"seed_item_id": "turnip_seed", "yield_item_id": "turnip",
		"yield_min": 1, "yield_max": 2,
		"seed_recovery_min": 1, "seed_recovery_max": 2,
		"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	},
	"cabbage": {
		"id": "cabbage", "name": "Cabbage", "growth_days": 5,
		"seasons": ["summer"], "moisture_min": 40, "moisture_max": 60,
		"seed_item_id": "cabbage_seed", "yield_item_id": "cabbage",
		"yield_min": 1, "yield_max": 1,
		"seed_recovery_min": 1, "seed_recovery_max": 1,
		"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	},
}

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}


func suite_name() -> String:
	return "crop_growth"


func run(t: Object) -> void:
	_test_till_and_plant_rules(t)
	_test_growth_requires_moisture_range(t)
	_test_rain_grows_crop(t)
	_test_harvest_after_growth(t)
	_test_wrong_season_rejected(t)
	t.completed(5)


func _make_grid() -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(2):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	grid.configure_for_test(CROP_DB, soil_map, SOIL_PROPS, Vector2i(4, 2))
	return grid


func _test_till_and_plant_rules(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(0, 0)
	t.eq(grid.plant(pos, "turnip"), 1, "cannot plant on untilled soil")
	t.ok(grid.till_tile(pos), "till succeeds")
	t.not_ok(grid.till_tile(pos), "cannot till twice")
	t.eq(grid.plant(pos, "turnip"), 0, "plant succeeds on tilled soil")
	t.eq(grid.plant(pos, "turnip"), 2, "cannot plant on planted tile")
	var other := Vector2i(1, 0)
	grid.till_tile(other)
	t.eq(grid.plant(other, "unknown"), 4, "unknown crop rejected")
	t.section_done("till/plant")


func _test_growth_requires_moisture_range(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(1, 0)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.water_tile(pos, 10.0)
	grid.advance_day(false)
	t.eq(grid.get_cell_moisture(pos), 9.0, "moisture decays below min")
	t.eq(grid.get_cell(pos).get("growth_progress", -1.0), 0.0, "no growth when too dry")
	grid.water_tile(pos, 50.0)
	grid.advance_day(false)
	t.ok(float(grid.get_cell(pos).get("growth_progress", 0.0)) > 0.0,
		"growth advances when moisture in range")
	t.section_done("growth")


func _test_rain_grows_crop(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(2, 0)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.advance_day(true)
	t.eq(grid.get_cell_moisture(pos), 80.0, "rain fills planted cell to crop moisture max")
	t.ok(float(grid.get_cell(pos).get("growth_progress", 0.0)) > 0.0,
		"rain day counts as a watered growth day")
	t.section_done("rain")


func _test_harvest_after_growth(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(3, 0)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.water_tile(pos, 50.0)
	for _i in range(4):
		grid.advance_day(false)
	t.ok(grid.is_harvestable(pos), "crop mature after 4 in-range days")
	var results: Array = grid.harvest(pos)
	t.eq(results.size(), 2, "harvest yields crop + seeds")
	t.eq(results[0].get("item_id", ""), "turnip", "yield item id")
	t.eq(results[1].get("item_id", ""), "turnip_seed", "seed item id")
	t.eq(grid.planted_count(), 0, "harvested tile has no crop")
	t.section_done("harvest")


func _test_wrong_season_rejected(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(0, 1)
	grid.till_tile(pos)
	t.eq(grid.plant(pos, "cabbage"), 3, "summer crop rejected in spring")
	t.section_done("season")
