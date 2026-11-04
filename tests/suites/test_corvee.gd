extends RefCounted
## Corvee coverage: weekly announcement with notice, activation on the
## announced day, the 1.5x credit multiplier, the penalty for skipping, and
## the deterministic zero-chance negative case. Penalty/credit assertions
## run with a real ReputationManager injected via the configure_for_test
## seam (the headless harness cannot resolve /root lookups).
## ADR-040: the chore used to earn corvee credit is a real spatial till of a
## demesne tile (FarmGrid.till_tile(pos, true) + complete_demesne_tool_chore)
## rather than the old abstract do_chore button - the corvee bookkeeping
## itself is unchanged.

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

const MINI_CROPS := {
	"turnip": {
		"id": "turnip", "growth_days": 3, "seasons": ["spring"],
		"moisture_min": 0, "moisture_max": 100,
		"yield_item_id": "turnip", "seed_item_id": "turnip_seed",
		"yield_min": 1, "yield_max": 1,
		"seed_recovery_min": 0, "seed_recovery_max": 0,
		"quality_weights": {"common": 100, "fine": 0, "choice": 0},
	},
}

const MINI_SOIL := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}

## The shipped stewards_demesne footprint (farm_map.json), mirrored into the
## test FarmGrid so the spatial chore gates run against real coordinates.
const DEMESNE_RECT := Rect2i(15, 5, 6, 6)


func suite_name() -> String:
	return "corvee"


func run(t: Object) -> void:
	_test_announced_with_notice(t)
	_test_credit_multiplied_on_corvee_day(t)
	_test_work_avoids_penalty(t)
	_test_skip_triggers_fail_corvee(t)
	_test_zero_chance_never_announces(t)
	t.completed(5)


func _make(reputation: Node = null) -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 1000  # upkeep (8 coin/week) must never starve these tests
	ps.energy = 100.0
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	gd.manor_cfg["corvee"]["chance_per_week"] = 1.0
	var day_holder := [1]
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(12):
		for x in range(22):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test(
		MINI_CROPS, soil_map, MINI_SOIL, Vector2i(22, 12),
		{}, [], "", DEMESNE_RECT, gd.get_demesne_config())
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], farm, reputation)
	return [tm, ps, gd, day_holder, farm]


func _test_announced_with_notice(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var announced: Array = []
	tm.corvee_announced.connect(func(day: int) -> void:
		announced.append(day))
	tm._on_day_passed(7, "spring", 1)
	t.eq(announced.size(), 1, "corvee announced once on a week boundary")
	t.eq(int(announced[0]), 8, "announced one day ahead (notice_days 1)")
	t.eq(int(tm.get("_corvee_day")), 8, "corvee day stored")
	t.section_done("announce")


func _test_credit_multiplied_on_corvee_day(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var farm = parts[4]
	var started: Array = []
	tm.corvee_started.connect(func() -> void:
		started.append(true))
	tm._on_day_passed(7, "spring", 1)
	tm._on_day_passed(8, "spring", 1)
	t.ok(tm.is_corvee_active(), "corvee active on the announced day")
	t.eq(started.size(), 1, "corvee_started fired once")
	var credits: Array = []
	tm.chore_completed.connect(func(_chore_id: String, credit: float, _energy_cost: float) -> void:
		credits.append(credit))
	var till_pos := Vector2i(16, 5)
	t.ok(tm.can_demesne_chore_at("till_demesne", till_pos),
		"demesne tile tillable on corvee day")
	t.ok(farm.till_tile(till_pos, true), "till the demesne tile")
	t.ok(tm.complete_demesne_tool_chore("till_demesne", till_pos, 5.0),
		"spatial till chore succeeds on corvee day")
	t.eq(float(credits[0]), 4.5, "till credit 3 x 1.5 multiplier")
	t.ok(bool(tm.get("_corvee_chore_done")), "chore marks the day done")
	t.section_done("multiplier")


func _test_work_avoids_penalty(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var gd = parts[2]
	var farm = parts[4]
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, parts[1])
	tm.set("_test_rep", rep)
	tm._on_day_passed(7, "spring", 1)
	tm._on_day_passed(8, "spring", 1)
	t.ok(tm.is_corvee_active(), "corvee day active")
	var till_pos := Vector2i(16, 5)
	t.ok(farm.till_tile(till_pos, true), "till the demesne tile")
	t.ok(tm.complete_demesne_tool_chore("till_demesne", till_pos, 5.0),
		"chore done on the corvee day")
	t.eq(rep.get_standing("manor"), 2.0, "chore granted complete_labor_day standing")
	tm._on_day_passed(9, "spring", 1)
	t.eq(rep.get_standing("manor"), 2.0, "no fail_corvee after working the corvee")
	t.not_ok(tm.is_corvee_active(), "corvee over the next day")
	t.section_done("worked")


func _test_skip_triggers_fail_corvee(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var gd = parts[2]
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, parts[1])
	tm.set("_test_rep", rep)
	tm._on_day_passed(7, "spring", 1)
	tm._on_day_passed(8, "spring", 1)
	t.ok(tm.is_corvee_active(), "corvee day active")
	tm._on_day_passed(9, "spring", 1)
	t.eq(rep.get_standing("manor"), -4.0, "skipping corvee drops manor by 4")
	t.section_done("skipped")


func _test_zero_chance_never_announces(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var gd = parts[2]
	gd.manor_cfg["corvee"]["chance_per_week"] = 0.0
	var announced: Array = []
	tm.corvee_announced.connect(func(day: int) -> void:
		announced.append(day))
	for day: int in [7, 14, 21, 28]:
		tm._on_day_passed(day, "spring", 1)
	t.eq(announced.size(), 0, "zero chance never announces across the season")
	t.eq(int(tm.get("_corvee_day")), -1, "no corvee day ever stored")
	t.section_done("zero chance")
