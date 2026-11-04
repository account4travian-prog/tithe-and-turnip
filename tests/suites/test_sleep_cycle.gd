extends RefCounted
## PlayerState exhaustion ladder + TimeManager forced-collapse coverage
## (ADR-016). Constructs the two scripts directly and hands the TimeManager
## to PlayerState through the set_time_manager_ref injection seam - in the
## --script harness no node is inside the active tree during _initialize, so
## /root/ lookups cannot resolve and the seam is the only live-path mirror.
## Signal connections are wired by hand exactly as PlayerState._ready() would.

const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")

const TM_CFG := {
	"real_seconds_per_game_minute": 0.5,
	"minutes_per_hour": 60,
	"days_per_season": 28,
	"seasons": ["spring", "summer", "autumn", "winter"],
	"wake_hour": 6,
	"sleep_hour": 24,
}

var _collapse_count := 0
var _day_pass_count := 0


func suite_name() -> String:
	return "sleep_cycle"


func run(t: Object) -> void:
	_test_first_exhaustion_penalty(t)
	_test_second_exhaustion_forces_sleep(t)
	_test_sleep_restore_clamps(t)
	_test_advance_hours_no_collapse(t)
	_test_advance_hours_collapse(t)
	_test_advance_hours_day_passed_math(t)
	t.completed(6)


func _make_pair() -> Array:
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.configure(TM_CFG)
	tm.day = 3
	tm.hour = 6
	tm.minute = 0
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.max_energy = 100.0
	ps.energy = 100.0
	ps.max_health = 50
	ps.health = 50
	ps.money = 100
	ps.set_time_manager_ref(tm)
	if not tm.day_passed.is_connected(ps._on_day_passed):
		tm.day_passed.connect(ps._on_day_passed)
	if not tm.forced_collapse.is_connected(ps._on_forced_collapse):
		tm.forced_collapse.connect(ps._on_forced_collapse)
	return [ps, tm]


func _free_pair(ps: Node, tm: Node) -> void:
	ps.free()
	tm.free()


func _make_tm() -> Object:
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.configure(TM_CFG)
	return tm


func _test_first_exhaustion_penalty(t: Object) -> void:
	var parts := _make_pair()
	var ps: Node = parts[0]
	var tm: Node = parts[1]
	ps.energy = 0.0
	t.not_ok(ps.consume_energy(5.0), "consume_energy fails with no energy")
	t.eq(ps.pass_out_count, 1, "first exhaustion records a pass-out")
	t.eq(ps.health, 10, "pass-out sets health to the data floor (10)")
	t.eq(ps.money, 80, "pass-out loses 20% of coin (floor)")
	t.eq(ps.energy, 20.0, "exhaustion recovers to the data-driven 20 energy")
	t.eq(tm.hour, 8, "first exhaustion skips two hours (6 -> 8)")
	_free_pair(ps, tm)
	t.section_done("first exhaustion")


func _test_second_exhaustion_forces_sleep(t: Object) -> void:
	var parts := _make_pair()
	var ps: Node = parts[0]
	var tm: Node = parts[1]
	var start_day: int = tm.day
	ps.trigger_exhaustion()
	ps.trigger_exhaustion()
	t.eq(ps.energy, 20.0, "second exhaustion still recovers to 20 energy")
	t.eq(tm.day, start_day + 1, "second same-day exhaustion forces a full day rollover")
	t.eq(tm.hour, 6, "forced sleep lands on the wake hour")
	_free_pair(ps, tm)
	t.section_done("second exhaustion")


func _test_sleep_restore_clamps(t: Object) -> void:
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.max_energy = 100.0
	ps.energy = 40.0
	ps.max_health = 50
	ps.health = 20
	ps.sleep_restore()
	t.eq(ps.energy, 100.0, "40 + 60% of max clamps to max")
	t.eq(ps.health, 35, "sleep regenerates 15 health")
	var ps2 = PLAYER_STATE_SCRIPT.new()
	ps2.max_energy = 100.0
	ps2.energy = 90.0
	ps2.sleep_restore()
	t.eq(ps2.energy, 100.0, "90 + 60 would overflow; clampf caps at max")
	t.section_done("sleep restore")


func _test_advance_hours_no_collapse(t: Object) -> void:
	var tm := _make_tm()
	tm.day = 5
	tm.hour = 23
	tm.minute = 0
	_collapse_count = 0
	tm.forced_collapse.connect(_on_collapse)
	tm.advance_hours(2, false)
	t.eq(_collapse_count, 0, "advance_hours(..., false) never emits forced_collapse")
	t.eq(tm.day, 6, "crossing midnight still advances the day")
	t.eq(tm.hour, 1, "two hours past 23:00 lands on 01:00")
	t.section_done("no collapse")


func _test_advance_hours_collapse(t: Object) -> void:
	var tm := _make_tm()
	tm.day = 7
	tm.hour = 22
	tm.minute = 0
	_collapse_count = 0
	tm.forced_collapse.connect(_on_collapse)
	tm.advance_hours(2)
	t.eq(_collapse_count, 1, "reaching hour 24 emits forced_collapse exactly once")
	t.eq(tm.day, 8, "the day still rolls over")
	t.section_done("collapse")


func _test_advance_hours_day_passed_math(t: Object) -> void:
	var tm := _make_tm()
	tm.day = 3
	tm.hour = 10
	tm.minute = 0
	_day_pass_count = 0
	tm.day_passed.connect(_on_day_passed)
	tm.advance_hours(2)
	tm.advance_hours(2)
	t.eq(_day_pass_count, 0, "two short skips before midnight fire no day_passed")
	t.eq(tm.day, 3, "day unchanged at 14:00")
	tm.advance_hours(6)
	tm.advance_hours(6)
	t.eq(_day_pass_count, 1, "crossing midnight once fires day_passed exactly once")
	t.eq(tm.day, 4, "day advanced by one after midnight")
	t.section_done("day math")


func _on_collapse() -> void:
	_collapse_count += 1


func _on_day_passed(_day: int, _season: String, _year: int) -> void:
	_day_pass_count += 1
