extends RefCounted
## Deterministic coverage of the TimeManager clock: minute/hour rollover,
## day/season/year rollover, and sleep-to-next-day. Drives the clock's core
## method directly (off-tree), so the suite never depends on _process timing.

const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")


func suite_name() -> String:
	return "time_math"


func run(t: Object) -> void:
	_test_minute_hour_rollover(t)
	_test_day_season_year_rollover(t)
	_test_sleep_to_next_day(t)
	t.completed(3)


func _make_clock():
	var clock = TIME_MANAGER_SCRIPT.new()
	clock.configure({
		"real_seconds_per_game_minute": 1.0,
		"minutes_per_hour": 60,
		"days_per_season": 3,
		"seasons": ["spring", "summer", "autumn", "winter"],
		"wake_hour": 6,
		"sleep_hour": 24,
	})
	return clock


func _test_minute_hour_rollover(t: Object) -> void:
	var clock = _make_clock()
	clock.hour = 6
	clock.minute = 59
	var day_before: int = clock.day
	clock.advance_real_seconds(1.0)
	t.eq(clock.minute, 0, "minute rolls to 0")
	t.eq(clock.hour, 7, "hour advances to 7")
	t.eq(clock.day, day_before, "day unchanged on hour rollover")
	t.section_done("minute/hour")


func _test_day_season_year_rollover(t: Object) -> void:
	var clock = _make_clock()
	clock.day = 3
	clock.season = "spring"
	clock.hour = 23
	clock.minute = 59
	var season_changes: Array[String] = []
	clock.season_changed.connect(func(new_season: String) -> void:
		season_changes.append(new_season))
	clock.advance_real_seconds(1.0)
	t.eq(clock.day, 1, "day resets after season end")
	t.eq(clock.season, "summer", "season advances")
	t.eq(clock.year, 1, "year unchanged mid-cycle")
	t.eq(season_changes, ["summer"], "season_changed emitted once")

	clock.day = 3
	clock.season = "winter"
	clock.hour = 23
	clock.minute = 59
	var year_changes: Array[int] = []
	clock.year_passed.connect(func(new_year: int) -> void:
		year_changes.append(new_year))
	clock.advance_real_seconds(1.0)
	t.eq(clock.year, 2, "year advances after winter")
	t.eq(clock.season, "spring", "season wraps to spring")
	t.eq(year_changes, [2], "year_passed emitted once")
	t.section_done("day/season/year")


func _test_sleep_to_next_day(t: Object) -> void:
	var clock = _make_clock()
	clock.day = 2
	clock.hour = 19
	clock.minute = 41
	clock.sleep_to_next_day()
	t.eq(clock.hour, 6, "wakes at configured hour")
	t.eq(clock.minute, 0, "wakes at minute 0")
	t.eq(clock.day, 3, "day advances")
	t.section_done("sleep")
