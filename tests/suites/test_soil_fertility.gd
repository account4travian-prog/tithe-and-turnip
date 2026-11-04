extends RefCounted
## E2 (Soil Fertility) coverage: per-soil fertility_init, harvest depletion
## and cover-crop restoration, clamping at [0, 100], fertility_min blocking
## planting, fallow-only recovery, compost application, the high-fertility
## quality bonus, and save round-trip. Synthetic fixture (mirrors
## test_crop_growth.gd's shape) with zeroed quality weights where needed so
## quality outcomes are deterministic, not statistical.

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

## Depletes 20 fertility per harvest; fertility_min 0 so it's always
## plantable regardless of current fertility (used to test depletion/clamp).
const CROP_DEPLETER := {
	"id": "depleter", "name": "Depleter", "growth_days": 1,
	"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
	"seed_item_id": "depleter_seed", "yield_item_id": "depleter",
	"yield_min": 1, "yield_max": 1,
	"seed_recovery_min": 0, "seed_recovery_max": 0,
	"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	"fertility_depletion": 20, "fertility_min": 0,
}

## Restores (negative depletion) 15 fertility per harvest - the pea/cover-
## crop case.
const CROP_RESTORER := {
	"id": "restorer", "name": "Restorer", "growth_days": 1,
	"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
	"seed_item_id": "restorer_seed", "yield_item_id": "restorer",
	"yield_min": 1, "yield_max": 1,
	"seed_recovery_min": 0, "seed_recovery_max": 0,
	"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	"fertility_depletion": -15, "fertility_min": 0,
}

## Requires fertility >= 50 to plant at all.
const CROP_PICKY := {
	"id": "picky", "name": "Picky", "growth_days": 1,
	"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
	"seed_item_id": "picky_seed", "yield_item_id": "picky",
	"yield_min": 1, "yield_max": 1,
	"seed_recovery_min": 0, "seed_recovery_max": 0,
	"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	"fertility_depletion": 0, "fertility_min": 50,
}

## All quality weights zeroed (including soil bonuses) so quality is decided
## entirely by whether the high-fertility bonus fires: below threshold,
## _roll_quality's total is 0 and it falls back to "common"; at/above
## threshold, high_fertility_quality_bonus is the only positive weight, so
## every roll lands in "choice".
const CROP_QUALITY_PROBE := {
	"id": "probe", "name": "Probe", "growth_days": 1,
	"seasons": ["spring"], "moisture_min": 0, "moisture_max": 100,
	"seed_item_id": "probe_seed", "yield_item_id": "probe",
	"yield_min": 1, "yield_max": 1,
	"seed_recovery_min": 0, "seed_recovery_max": 0,
	"quality_weights": {"common": 0, "fine": 0, "choice": 0},
	"fertility_depletion": 0, "fertility_min": 0,
}

const CROP_DB := {
	"depleter": CROP_DEPLETER, "restorer": CROP_RESTORER,
	"picky": CROP_PICKY, "probe": CROP_QUALITY_PROBE,
}

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 0.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0,
		"fertility_init": 70, "fertility_recovery_per_day": 5.0,
		"high_fertility_quality_bonus": 10, "high_fertility_threshold": 60},
	"sandy": {"moisture_decay_per_day": 0.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0,
		"fertility_init": 50, "fertility_recovery_per_day": 3.0,
		"high_fertility_quality_bonus": 10, "high_fertility_threshold": 60},
	"rocky": {"moisture_decay_per_day": 0.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0,
		"fertility_init": 30, "fertility_recovery_per_day": 2.0,
		"high_fertility_quality_bonus": 10, "high_fertility_threshold": 60},
}


func suite_name() -> String:
	return "soil_fertility"


func run(t: Object) -> void:
	_test_default_fertility_per_soil(t)
	_test_harvest_depletes(t)
	_test_harvest_restores(t)
	_test_fertility_clamped_low(t)
	_test_fertility_clamped_high(t)
	_test_plant_blocked_below_fertility_min(t)
	_test_fallow_recovers_untilled_and_growing_do_not(t)
	_test_apply_compost(t)
	_test_compost_blocked_on_untilled(t)
	_test_high_fertility_quality_bonus(t)
	_test_save_roundtrip(t)
	t.completed(21)


func _make_grid() -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {
		Vector2i(0, 0): "loamy", Vector2i(1, 0): "sandy", Vector2i(2, 0): "rocky",
	}
	grid.configure_for_test(CROP_DB, soil_map, SOIL_PROPS, Vector2i(3, 1))
	return grid


func _grow_to_harvest(grid: Object, pos: Vector2i, crop: Dictionary) -> void:
	grid.water_tile(pos, float(crop.get("moisture_max", 100)))
	for _i in range(int(crop.get("growth_days", 1))):
		grid.advance_day(false)


func _test_default_fertility_per_soil(t: Object) -> void:
	var grid := _make_grid()
	t.eq(grid.get_cell_fertility(Vector2i(0, 0)), 70.0, "loamy cell starts at fertility_init 70")
	t.eq(grid.get_cell_fertility(Vector2i(1, 0)), 50.0, "sandy cell starts at fertility_init 50")
	t.eq(grid.get_cell_fertility(Vector2i(2, 0)), 30.0, "rocky cell starts at fertility_init 30")
	t.section_done("default fertility")


func _test_harvest_depletes(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	grid.plant(pos, "depleter")
	_grow_to_harvest(grid, pos, CROP_DEPLETER)
	grid.harvest(pos)
	t.eq(grid.get_cell_fertility(pos), 50.0, "harvesting a depleting crop subtracts fertility_depletion (70-20=50)")
	t.section_done("harvest depletes")


func _test_harvest_restores(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	grid.plant(pos, "restorer")
	_grow_to_harvest(grid, pos, CROP_RESTORER)
	grid.harvest(pos)
	t.eq(grid.get_cell_fertility(pos), 85.0,
		"harvesting a cover crop (negative depletion) restores fertility (70+15=85)")
	t.section_done("harvest restores")


func _test_fertility_clamped_low(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	for _i in range(4):
		grid.plant(pos, "depleter")
		_grow_to_harvest(grid, pos, CROP_DEPLETER)
		grid.harvest(pos)
	# 70 - 20*4 = -10 raw, clamped to 0.
	t.eq(grid.get_cell_fertility(pos), 0.0, "repeated depletion clamps fertility at 0, never negative")
	t.section_done("clamp low")


func _test_fertility_clamped_high(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	for _i in range(3):
		grid.plant(pos, "restorer")
		_grow_to_harvest(grid, pos, CROP_RESTORER)
		grid.harvest(pos)
	# 70 + 15*3 = 115 raw, clamped to 100.
	t.eq(grid.get_cell_fertility(pos), 100.0, "repeated restoration clamps fertility at 100, never above")
	t.section_done("clamp high")


func _test_plant_blocked_below_fertility_min(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(2, 0)  # rocky, fertility_init 30
	grid.till_tile(pos)
	t.eq(grid.plant(pos, "picky"), 5, "planting fertility_min=50 on 30-fertility soil is blocked (code 5)")
	# Fallow-recover past the threshold (rocky recovers 2.0/day; 10 days -> 50).
	for _i in range(10):
		grid.advance_day(false)
	t.eq(grid.get_cell_fertility(pos), 50.0, "precondition: fallow recovery reached exactly 50")
	t.eq(grid.plant(pos, "picky"), 0, "planting succeeds once fertility meets fertility_min")
	t.section_done("fertility_min blocks planting")


func _test_fallow_recovers_untilled_and_growing_do_not(t: Object) -> void:
	var grid := _make_grid()
	var fallow_pos := Vector2i(0, 0)
	grid.till_tile(fallow_pos)
	grid.advance_day(false)
	t.eq(grid.get_cell_fertility(fallow_pos), 75.0,
		"a tilled, unplanted (fallow) cell recovers fertility_recovery_per_day (70+5=75)")

	var untilled_pos := Vector2i(1, 0)
	grid.advance_day(false)
	t.eq(grid.get_cell_fertility(untilled_pos), 50.0,
		"an untilled cell's fertility never changes via the fallow mechanism")

	var growing_pos := Vector2i(2, 0)
	grid.till_tile(growing_pos)
	grid.plant(growing_pos, "depleter")
	var before: float = grid.get_cell_fertility(growing_pos)
	grid.advance_day(false)
	t.eq(grid.get_cell_fertility(growing_pos), before,
		"a planted (non-fallow) cell's fertility is untouched by advance_day - only harvest changes it")
	t.section_done("fallow vs untilled vs growing")


func _test_apply_compost(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	t.ok(grid.apply_compost(pos, 20.0), "apply_compost succeeds on a tilled cell")
	t.eq(grid.get_cell_fertility(pos), 90.0, "compost adds its amount (70+20=90)")
	t.ok(grid.apply_compost(pos, 20.0), "a second application also succeeds")
	t.eq(grid.get_cell_fertility(pos), 100.0, "compost is clamped at 100 (90+20=110 -> 100)")
	t.section_done("apply compost")


func _test_compost_blocked_on_untilled(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(1, 0)
	t.not_ok(grid.apply_compost(pos, 20.0), "apply_compost fails on an untilled cell")
	t.eq(grid.get_cell_fertility(pos), 50.0, "fertility is unchanged after a blocked application")
	t.section_done("compost blocked untilled")


func _test_high_fertility_quality_bonus(t: Object) -> void:
	var grid := _make_grid()
	var high_pos := Vector2i(0, 0)  # loamy, fertility 70 >= threshold 60
	grid.till_tile(high_pos)
	grid.plant(high_pos, "probe")
	_grow_to_harvest(grid, high_pos, CROP_QUALITY_PROBE)
	var high_results: Array = grid.harvest(high_pos)
	t.eq(str((high_results[0] as Dictionary).get("quality", "")), "choice",
		"at/above the high-fertility threshold, the zeroed-weight probe crop always rolls choice")

	var low_pos := Vector2i(2, 0)  # rocky, fertility 30 < threshold 60
	grid.till_tile(low_pos)
	grid.plant(low_pos, "probe")
	_grow_to_harvest(grid, low_pos, CROP_QUALITY_PROBE)
	var low_results: Array = grid.harvest(low_pos)
	t.eq(str((low_results[0] as Dictionary).get("quality", "")), "common",
		"below the high-fertility threshold, the zeroed-weight probe crop falls back to common")
	t.section_done("high fertility quality bonus")


func _test_save_roundtrip(t: Object) -> void:
	var grid := _make_grid()
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	grid.apply_compost(pos, 20.0)
	var dumped: Dictionary = grid.to_dict()
	var restored := FARM_GRID_SCRIPT.new()
	restored.configure_for_test(CROP_DB, {Vector2i(0, 0): "loamy"}, SOIL_PROPS, Vector2i(1, 1))
	restored.from_dict(dumped)
	t.eq(restored.get_cell_fertility(pos), grid.get_cell_fertility(pos),
		"cell fertility round-trips through to_dict/from_dict")
	t.section_done("save roundtrip")
