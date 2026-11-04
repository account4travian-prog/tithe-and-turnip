extends RefCounted
## E12 (Foraging 2.0) coverage: the spade's dig_loot table is separate from
## the passive spawns table, blocked on tilled cells, throttled by
## max_digs_per_day (misses count against the cap too - the anti-exploit
## design from the owner's dig-mechanic ruling), season-filtered, and
## carries an is_rare flag through to the caller. Also checks the real
## shipped data for market/item registration.
##
## What this suite does NOT cover: ToolManager's energy-cost/EventBus/
## event_flag wiring around a rare dig. ToolManager has no GameData test
## seam (unlike FarmGrid's configure_for_test or PlayerState's
## set_game_data_ref) - _item() silently returns {} off-tree, so a headless
## unit test of that glue would be testing a fake rather than the real
## dispatch. That wiring is exercised by the Phase 1 gate's manual playtest
## ("a spade dig, a morel find"), the same class of gap ADR-032's postmortem
## already flagged for glue code no headless suite can see.

const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 0.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0, "fertility_init": 70,
		"fertility_recovery_per_day": 0.0, "high_fertility_quality_bonus": 0,
		"high_fertility_threshold": 60},
}

const FORAGE_CFG_HIT := {
	"gather_energy_cost": 2, "max_digs_per_day": 3,
	"spawn_chance_per_tile_per_day": 0.0, "max_concurrent_spawns": 40,
	"spawns": {},
	"dig_loot": {"loamy": [
		{"item_id": "wild_turnip", "weight": 100, "yield_min": 2, "yield_max": 2},
	]},
}

const FORAGE_CFG_MISS := {
	"gather_energy_cost": 2, "max_digs_per_day": 3,
	"spawn_chance_per_tile_per_day": 0.0, "max_concurrent_spawns": 40,
	"spawns": {},
	"dig_loot": {"loamy": [
		{"item_id": "", "weight": 100, "yield_min": 0, "yield_max": 0},
	]},
}

const FORAGE_CFG_SEASON := {
	"gather_energy_cost": 2, "max_digs_per_day": 20,
	"spawn_chance_per_tile_per_day": 0.0, "max_concurrent_spawns": 40,
	"spawns": {},
	"dig_loot": {"loamy": [
		{"item_id": "autumn_only", "weight": 100, "yield_min": 1, "yield_max": 1, "season": ["autumn"]},
		{"item_id": "spring_only", "weight": 1, "yield_min": 1, "yield_max": 1, "season": ["spring"]},
	]},
}

const FORAGE_CFG_RARE := {
	"gather_energy_cost": 2, "max_digs_per_day": 3,
	"spawn_chance_per_tile_per_day": 0.0, "max_concurrent_spawns": 40,
	"spawns": {},
	"dig_loot": {"loamy": [
		{"item_id": "morel", "weight": 100, "yield_min": 1, "yield_max": 1, "is_rare": true},
	]},
}

const FORAGE_CFG_YIELD_RANGE := {
	"gather_energy_cost": 2, "max_digs_per_day": 20,
	"spawn_chance_per_tile_per_day": 0.0, "max_concurrent_spawns": 40,
	"spawns": {},
	"dig_loot": {"loamy": [
		{"item_id": "wild_carrot", "weight": 100, "yield_min": 2, "yield_max": 4},
	]},
}


func suite_name() -> String:
	return "foraging_expansion"


func run(t: Object) -> void:
	_test_dig_blocked_on_tilled(t)
	_test_dig_untilled_succeeds(t)
	_test_daily_cap(t)
	_test_miss_counts_against_cap(t)
	_test_season_filter(t)
	_test_rare_flag_present(t)
	_test_yield_range(t)
	_test_save_roundtrip(t)
	_test_market_and_item_registration(t)
	t.completed(16)


func _make_grid(forage_cfg: Dictionary) -> Object:
	var grid = FARM_GRID_SCRIPT.new()
	var soil_map := {Vector2i(0, 0): "loamy"}
	grid.configure_for_test({}, soil_map, SOIL_PROPS, Vector2i(1, 1), forage_cfg)
	return grid


func _test_dig_blocked_on_tilled(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_HIT)
	var pos := Vector2i(0, 0)
	grid.till_tile(pos)
	t.not_ok(grid.can_dig(pos), "can_dig is false on a tilled cell")
	t.ok(grid.dig_cell(pos).is_empty(), "dig_cell returns {} on a tilled cell - no attempt spent")
	t.section_done("dig blocked on tilled")


func _test_dig_untilled_succeeds(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_HIT)
	var pos := Vector2i(0, 0)
	t.ok(grid.can_dig(pos), "can_dig is true on a fresh untilled cell")
	var result: Dictionary = grid.dig_cell(pos)
	t.eq(str(result.get("item_id", "")), "wild_turnip", "dig_cell returns the fixture's only dig_loot entry")
	t.eq(int(result.get("count", 0)), 2, "yield count matches the fixed yield_min=yield_max=2")
	t.not_ok(bool(result.get("is_rare", true)), "wild_turnip is not flagged rare")
	t.section_done("dig untilled succeeds")


func _test_daily_cap(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_HIT)  # max_digs_per_day: 3
	var pos := Vector2i(0, 0)
	for i in range(3):
		t.ok(grid.can_dig(pos), "dig %d of 3 is allowed" % (i + 1))
		t.not_ok(grid.dig_cell(pos).is_empty(), "dig %d of 3 returns a result" % (i + 1))
	t.not_ok(grid.can_dig(pos), "the 4th dig is blocked by max_digs_per_day")
	t.ok(grid.dig_cell(pos).is_empty(), "dig_cell returns {} once the daily cap is reached")
	t.section_done("daily cap")


func _test_miss_counts_against_cap(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_MISS)  # every roll is a miss
	var pos := Vector2i(0, 0)
	for i in range(3):
		var result: Dictionary = grid.dig_cell(pos)
		t.not_ok(result.is_empty(), "a miss (dig %d) still returns a result dict, not {}" % (i + 1))
		t.eq(str(result.get("item_id", "x")), "", "a miss carries an empty item_id")
	t.not_ok(grid.can_dig(pos), "3 misses still exhaust the daily cap - a miss is a real attempt")
	t.section_done("miss counts against cap")


func _test_season_filter(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_SEASON)
	var pos := Vector2i(0, 0)
	var saw_only_spring := true
	for _i in range(15):
		var result: Dictionary = grid.dig_cell(pos)
		var item_id := str(result.get("item_id", ""))
		if not item_id.is_empty() and item_id != "spring_only":
			saw_only_spring = false
	t.ok(saw_only_spring,
		"despite autumn_only's 100x weight, only spring_only is ever picked - test mode is always spring")
	t.section_done("season filter")


func _test_rare_flag_present(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_RARE)
	var result: Dictionary = grid.dig_cell(Vector2i(0, 0))
	t.eq(str(result.get("item_id", "")), "morel", "the rare fixture entry is picked")
	t.ok(bool(result.get("is_rare", false)), "is_rare is carried through to the caller")
	t.section_done("rare flag")


func _test_yield_range(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_YIELD_RANGE)
	var pos := Vector2i(0, 0)
	var all_in_range := true
	for _i in range(15):
		var count := int(grid.dig_cell(pos).get("count", -1))
		if count < 2 or count > 4:
			all_in_range = false
	t.ok(all_in_range, "every dig's yield count stayed within the fixture's [2, 4]")
	t.section_done("yield range")


func _test_save_roundtrip(t: Object) -> void:
	var grid := _make_grid(FORAGE_CFG_HIT)
	var pos := Vector2i(0, 0)
	grid.dig_cell(pos)
	grid.dig_cell(pos)
	var dumped: Dictionary = grid.to_dict()
	t.eq(int(dumped.get("daily_dig_count", -1)), 2, "to_dict carries the daily dig count")
	var restored := FARM_GRID_SCRIPT.new()
	restored.configure_for_test({}, {Vector2i(0, 0): "loamy"}, SOIL_PROPS, Vector2i(1, 1), FORAGE_CFG_HIT)
	restored.from_dict(dumped)
	t.ok(restored.can_dig(pos), "one dig remains after restoring a daily_dig_count of 2 (cap is 3)")
	t.not_ok(restored.dig_cell(pos).is_empty(), "the one remaining dig succeeds")
	t.not_ok(restored.can_dig(pos),
		"the cap is now exhausted - proves daily_dig_count round-tripped to 2, not reset to 0")
	t.section_done("save roundtrip")


func _test_market_and_item_registration(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	for item_id: String in ["spade", "wild_carrot", "wild_turnip", "morel", "truffle", "compost", "spoiled_crop"]:
		t.ok(not gd.get_item(item_id).is_empty(), "%s is defined in items.json" % item_id)
	var prices: Dictionary = gd.get_market_buy_prices()
	t.ok(prices.has("morel") and prices.has("truffle"), "morel and truffle have market buy prices")
	var stall_ids: Array = []
	for entry: Variant in gd.get_stall_inventory():
		stall_ids.append(str((entry as Dictionary).get("item_id", "")))
	t.ok(stall_ids.has("spade"), "the spade is purchasable at the market stall")
	var forage_cfg: Dictionary = gd.get_forage_config()
	var loamy_dig: Array = forage_cfg.get("dig_loot", {}).get("loamy", [])
	var truffle_entry := {}
	for entry: Variant in loamy_dig:
		if str((entry as Dictionary).get("item_id", "")) == "truffle":
			truffle_entry = entry as Dictionary
	t.ok((truffle_entry.get("season", []) as Array) == ["autumn"],
		"truffle is season-gated to autumn - defined in data but unreachable this Spring slice")
	t.section_done("market and item registration")
