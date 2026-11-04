extends RefCounted
## FarmGrid foraging coverage: untilled-only spawns, gather/clear, the
## max_concurrent_spawns cap, and save-shape round-trip. Synthetic fixture
## (mirrors test_farm_moisture.gd's shape) with forced probabilities so
## spawn outcomes are deterministic, not statistical.

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

const CROP_DB := {}

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}

const FORAGE_CFG_ALWAYS := {
	"gather_energy_cost": 2,
	"spawn_chance_per_tile_per_day": 1.0,
	"max_concurrent_spawns": 40,
	"spawns": {
		"loamy": [
			{"item_id": "wild_berry", "weight": 100, "yield_min": 2, "yield_max": 2},
		],
	},
}

const FORAGE_CFG_NEVER := {
	"gather_energy_cost": 2,
	"spawn_chance_per_tile_per_day": 0.0,
	"max_concurrent_spawns": 40,
	"spawns": {
		"loamy": [
			{"item_id": "wild_berry", "weight": 100, "yield_min": 1, "yield_max": 1},
		],
	},
}


func suite_name() -> String:
	return "forage"


func run(t: Object) -> void:
	_test_spawn_on_untilled(t)
	_test_no_spawn_on_tilled(t)
	_test_gather_clears_cell(t)
	_test_gather_empty_cell_returns_empty(t)
	_test_max_concurrent_spawns_cap(t)
	_test_save_roundtrip(t)
	t.completed(6)


func _make_grid(forage_cfg: Dictionary) -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(2):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	grid.configure_for_test(CROP_DB, soil_map, SOIL_PROPS, Vector2i(4, 2), forage_cfg)
	return grid


func _test_spawn_on_untilled(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_ALWAYS)
	grid.advance_day(false)
	var pos := Vector2i(0, 0)
	t.ok(grid.has_forage(pos), "chance 1.0 spawns forage on an untilled cell after one advance_day")
	var cell: Dictionary = grid.get_cell(pos)
	t.eq(str(cell.get("forage_item_id", "")), "wild_berry", "spawned item matches the fixture's only entry")
	t.section_done("spawn on untilled")


func _test_no_spawn_on_tilled(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_ALWAYS)
	var pos := Vector2i(1, 0)
	grid.till_tile(pos)
	grid.advance_day(false)
	t.not_ok(grid.has_forage(pos), "a tilled cell never spawns forage, even at chance 1.0")
	t.section_done("no spawn on tilled")


func _test_gather_clears_cell(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_ALWAYS)
	var pos := Vector2i(0, 1)
	grid.advance_day(false)
	t.ok(grid.has_forage(pos), "precondition: cell has forage before gathering")
	var result: Dictionary = grid.gather_forage(pos)
	t.eq(str(result.get("item_id", "")), "wild_berry", "gather_forage returns the spawned item id")
	t.eq(int(result.get("count", 0)), 2, "gather_forage returns a count within [yield_min, yield_max] (fixed at 2)")
	t.not_ok(grid.has_forage(pos), "has_forage is false immediately after gathering")
	t.section_done("gather clears cell")


func _test_gather_empty_cell_returns_empty(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_NEVER)
	var result: Dictionary = grid.gather_forage(Vector2i(2, 0))
	t.ok(result.is_empty(), "gather_forage on a cell with no forage returns an empty dictionary")
	t.section_done("gather empty cell")


func _test_max_concurrent_spawns_cap(t: Object) -> void:
	var cfg := FORAGE_CFG_ALWAYS.duplicate(true)
	cfg["max_concurrent_spawns"] = 0
	var grid := _make_grid(cfg)
	grid.advance_day(false)
	var any_spawned := false
	for x in range(4):
		for y in range(2):
			if grid.has_forage(Vector2i(x, y)):
				any_spawned = true
	t.not_ok(any_spawned, "max_concurrent_spawns=0 blocks every spawn even at chance 1.0")
	t.section_done("max concurrent cap")


func _test_save_roundtrip(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_ALWAYS)
	grid.advance_day(false)
	var dumped: Dictionary = grid.to_dict()
	var restored := _make_grid(FORAGE_CFG_NEVER)
	restored.from_dict(dumped)
	for x in range(4):
		for y in range(2):
			var pos := Vector2i(x, y)
			t.eq(restored.has_forage(pos), grid.has_forage(pos),
				"forage presence at (%d,%d) round-trips through to_dict/from_dict" % [x, y])
	t.section_done("save roundtrip")
