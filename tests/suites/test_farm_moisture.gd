extends RefCounted
## FarmGrid v2 moisture/quality/seed/serialization coverage: soil decay, rain
## saturation, quality roll distribution, seed recovery bounds, and the save
## shape roundtrip. Deterministic via seed() where randomness is involved.

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

const FAST_CROP := {
	"fast": {
		"id": "fast", "name": "Fast Crop", "growth_days": 1,
		"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
		"seed_item_id": "fast_seed", "yield_item_id": "fast_crop",
		"yield_min": 1, "yield_max": 1,
		"seed_recovery_min": 1, "seed_recovery_max": 2,
		"quality_weights": {"common": 50, "fine": 30, "choice": 20},
	},
	"turnip": {
		"id": "turnip", "name": "Turnip", "growth_days": 4,
		"seasons": ["spring"], "moisture_min": 20, "moisture_max": 80,
		"seed_item_id": "turnip_seed", "yield_item_id": "turnip",
		"yield_min": 1, "yield_max": 2,
		"seed_recovery_min": 1, "seed_recovery_max": 2,
		"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	},
}

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
	"sandy": {"moisture_decay_per_day": 3.0, "growth_speed_mult": 0.8,
		"fine_quality_bonus": -5, "choice_quality_bonus": -5},
}


func suite_name() -> String:
	return "farm_moisture"


func run(t: Object) -> void:
	_test_moisture_decay(t)
	_test_rain_saturates_bare_soil(t)
	_test_dry_soil_blocks_growth(t)
	_test_plant_clamps_rain_soaked_moisture(t)
	_test_overwater_halves_growth(t)
	_test_overcast_halves_decay(t)
	_test_quality_distribution(t)
	_test_seed_recovery_bounds(t)
	_test_serialization_roundtrip(t)
	t.completed(9)


func _make_grid() -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(2):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	soil_map[Vector2i(0, 1)] = "sandy"
	grid.configure_for_test(FAST_CROP, soil_map, SOIL_PROPS, Vector2i(4, 2))
	return grid


func _test_moisture_decay(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	grid.water_tile(pos, 50.0)
	grid.advance_day(false)
	t.eq(grid.get_cell_moisture(pos), 49.0, "loamy moisture decays by 1.0/day")
	t.section_done("decay")


func _test_rain_saturates_bare_soil(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(1, 0)
	grid.till_tile(pos)
	grid.advance_day(true)
	t.eq(grid.get_cell_moisture(pos), 100.0, "rain saturates bare tilled soil")
	t.section_done("rain")


func _test_dry_soil_blocks_growth(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(0, 1)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.water_tile(pos, 20.0)
	grid.advance_day(false)
	t.eq(grid.get_cell_moisture(pos), 17.0, "sandy decay drops moisture below min")
	t.eq(grid.get_cell(pos).get("growth_progress", -1.0), 0.0, "no growth when out of range")
	t.section_done("dry")


func _test_plant_clamps_rain_soaked_moisture(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	grid.water_tile(pos, 100.0)
	t.eq(grid.get_cell_moisture(pos), 100.0, "bare tilled cell saturates to 100")
	grid.plant(pos, "turnip")
	t.ok(grid.get_cell_moisture(pos) <= 80.0,
		"plant clamps moisture to crop max (got %s)" % str(grid.get_cell_moisture(pos)))
	t.section_done("plant clamp")


func _test_overwater_halves_growth(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(1, 0)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.water_tile(pos, 100.0)
	grid.advance_day(false)
	t.eq(float(grid.get_cell(pos).get("growth_progress", -1.0)), 0.125,
		"overwatered crop grows at half speed (0.125, not 0.25)")
	t.section_done("overwater")


func _test_overcast_halves_decay(t: Object) -> void:
	var sunny = _make_grid()
	var pos := Vector2i(2, 0)
	sunny.till_tile(pos)
	sunny.water_tile(pos, 50.0)
	sunny.advance_day(false)
	var sunny_moisture: float = sunny.get_cell_moisture(pos)
	var overcast = _make_grid()
	var pos2 := Vector2i(2, 0)
	overcast.till_tile(pos2)
	overcast.water_tile(pos2, 50.0)
	overcast.advance_day(false, true)
	t.eq(overcast.get_cell_moisture(pos2), sunny_moisture + 0.5,
		"overcast halves daily moisture decay")
	t.section_done("overcast")


func _test_quality_distribution(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(2, 0)
	grid.till_tile(pos)
	seed(7)
	var fine_or_choice := 0
	for _i in range(60):
		grid.plant(pos, "fast")
		grid.water_tile(pos, 50.0)
		grid.advance_day(false)
		var results: Array = grid.harvest(pos)
		if str(results[0].get("quality", "common")) != "common":
			fine_or_choice += 1
	t.ok(fine_or_choice > 0, "quality roll produces fine/choice with seeded rng")
	t.section_done("quality")


func _test_seed_recovery_bounds(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(3, 0)
	grid.till_tile(pos)
	seed(11)
	for _i in range(30):
		grid.plant(pos, "fast")
		grid.water_tile(pos, 50.0)
		grid.advance_day(false)
		var results: Array = grid.harvest(pos)
		var seeds := int(results[1].get("count", 0))
		t.ok(seeds >= 1 and seeds <= 2, "seed recovery inside crop range (got %d)" % seeds)
	t.section_done("seeds")


func _test_serialization_roundtrip(t: Object) -> void:
	var grid = _make_grid()
	var pos := Vector2i(1, 1)
	grid.till_tile(pos)
	grid.plant(pos, "turnip")
	grid.water_tile(pos, 60.0)
	var saved: Dictionary = grid.to_dict()
	var grid2 = FARM_GRID_SCRIPT.new()
	grid2.configure_for_test(FAST_CROP, {}, SOIL_PROPS, Vector2i(4, 2))
	grid2.from_dict(saved)
	t.eq(grid2.get_cell(pos).get("crop_id", ""), "turnip", "crop survives roundtrip")
	t.eq(grid2.get_cell_moisture(pos), 60.0, "moisture survives roundtrip")
	t.eq(grid2.tile_count(), 1, "tile count survives roundtrip")
	t.section_done("serialization")
