extends RefCounted
## E5 (ADR-036) coverage: FestivalManager's day/season/hour window query
## logic (the only stateful decision in the whole feature - everything else
## is a lookup against it), its anchor accessor, real festivals.json data
## completeness, and DialogueManager's is_festival/festival_id context
## wiring.
##
## What this suite does NOT cover, and why: main.gd's
## _check_festival_attendance() (the actual standing-grant + event_flag
## gate) and npc.gd's _festival_anchor_position() both resolve
## FestivalManager via get_node_or_null("/root/FestivalManager") with no
## test-injection seam - off-tree, that always returns null, so a headless
## unit test of either would just be asserting "null is null", not
## exercising the real behavior. Same class of gap already flagged for
## ToolManager's dig-energy/EventBus wiring (Phase 1) and DialogueManager's
## pending autoload registration (Phase 2) - exercised by the manual
## playtest, not headless suites.

const FESTIVAL_MANAGER_SCRIPT := preload("res://scripts/autoloads/festival_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")
const DIALOGUE_MANAGER_SCRIPT := preload("res://scripts/autoloads/dialogue_manager.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const WEATHER_MANAGER_SCRIPT := preload("res://scripts/autoloads/weather_manager.gd")
const REPUTATION_MANAGER_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const SKILL_MANAGER_SCRIPT := preload("res://scripts/autoloads/skill_manager.gd")

const TM_CFG := {
	"real_seconds_per_game_minute": 0.5, "minutes_per_hour": 60,
	"days_per_season": 28, "seasons": ["spring", "summer", "autumn", "winter"],
	"wake_hour": 6, "sleep_hour": 24,
}


func suite_name() -> String:
	return "festivals"


func run(t: Object) -> void:
	_test_all_seasons_defined(t)
	_test_no_festival_wrong_day(t)
	_test_no_festival_wrong_season_same_day(t)
	_test_festival_active_in_window(t)
	_test_festival_boundary_hours(t)
	_test_active_festival_anchor(t)
	_test_dialogue_context_reflects_festival(t)
	t.completed(15)


func _make_fm(day: int, hour: int, season: String) -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.configure(TM_CFG)
	tm.day = day
	tm.hour = hour
	tm.season = season
	var fm = FESTIVAL_MANAGER_SCRIPT.new()
	fm.configure_for_test(gd, tm)
	return {"gd": gd, "tm": tm, "fm": fm}


func _test_all_seasons_defined(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var expected := {
		"springturn_blessing": "spring", "midsummer_fair": "summer",
		"harvest_home": "autumn", "winter_feast": "winter",
	}
	for festival_id: String in expected:
		var festival: Dictionary = gd.get_festival(festival_id)
		t.ok(not festival.is_empty(), "%s is defined in festivals.json" % festival_id)
		t.eq(str(festival.get("season", "")), expected[festival_id],
			"%s is assigned to %s" % [festival_id, expected[festival_id]])
	t.eq(gd.get_all_festivals().size(), 4, "all four seasonal festivals are present")
	var all_village := true
	for festival: Dictionary in gd.get_all_festivals():
		if str(festival.get("location", {}).get("zone", "")) != "nettleford":
			all_village = false
	t.ok(all_village, "every festival location is zone-qualified to Nettleford")
	t.section_done("all seasons defined")


func _test_no_festival_wrong_day(t: Object) -> void:
	var env := _make_fm(17, 12, "spring")
	t.ok((env["fm"] as Object).get_active_festival().is_empty(),
		"day 17 (one day before springturn_blessing) has no active festival")
	t.section_done("no festival wrong day")


func _test_no_festival_wrong_season_same_day(t: Object) -> void:
	# Day 18 also matches nothing in summer/autumn/winter - proves the
	# season check, not just the day check, gates the match.
	var env := _make_fm(18, 12, "summer")
	t.ok((env["fm"] as Object).get_active_festival().is_empty(),
		"day 18 in summer (springturn_blessing's day, wrong season) has no active festival")
	t.section_done("no festival wrong season")


func _test_festival_active_in_window(t: Object) -> void:
	var env := _make_fm(18, 12, "spring")
	var festival: Dictionary = (env["fm"] as Object).get_active_festival()
	t.eq(str(festival.get("id", "")), "springturn_blessing",
		"day 18 hour 12 spring is inside the festival window")
	t.eq(int(festival.get("standing_effects", {}).get("village", -1)), 10,
		"village standing effect matches data")
	t.eq(int(festival.get("standing_effects", {}).get("church", -1)), 8,
		"church standing effect matches data")
	t.section_done("festival active in window")


func _test_festival_boundary_hours(t: Object) -> void:
	var before := _make_fm(18, 9, "spring")
	t.ok((before["fm"] as Object).get_active_festival().is_empty(),
		"hour 9 (one before start_hour 10) is not active")
	var at_start := _make_fm(18, 10, "spring")
	t.not_ok((at_start["fm"] as Object).get_active_festival().is_empty(),
		"hour 10 (exactly start_hour) is active - inclusive start")
	var last_active := _make_fm(18, 13, "spring")
	t.not_ok((last_active["fm"] as Object).get_active_festival().is_empty(),
		"hour 13 (one before end_hour 14) is still active")
	var at_end := _make_fm(18, 14, "spring")
	t.ok((at_end["fm"] as Object).get_active_festival().is_empty(),
		"hour 14 (exactly end_hour) is no longer active - exclusive end")
	t.section_done("festival boundary hours")


func _test_active_festival_anchor(t: Object) -> void:
	var active := _make_fm(18, 12, "spring")
	var anchor: Dictionary = (active["fm"] as Object).get_active_festival_anchor()
	t.eq(int(anchor.get("x", -1)), 10, "active festival anchor x matches the Nettleford chapel tile")
	t.eq(int(anchor.get("y", -1)), 10, "active festival anchor y matches the Nettleford chapel tile")
	t.eq(str(anchor.get("zone", "")), "nettleford", "active festival anchor carries its zone")
	var inactive := _make_fm(17, 12, "spring")
	t.ok((inactive["fm"] as Object).get_active_festival_anchor().is_empty(),
		"no active festival means an empty anchor (no override)")
	t.section_done("active festival anchor")


func _test_dialogue_context_reflects_festival(t: Object) -> void:
	var env := _make_fm(18, 12, "spring")
	var gd: Object = env["gd"]
	var tm: Object = env["tm"]
	var fm: Object = env["fm"]
	var ps = PLAYER_STATE_SCRIPT.new()
	var wm = WEATHER_MANAGER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "sunny")
	var rm = REPUTATION_MANAGER_SCRIPT.new()
	rm.configure_for_test(gd, ps)
	var sm = SKILL_MANAGER_SCRIPT.new()
	sm.configure_for_test(gd)
	var dm = DIALOGUE_MANAGER_SCRIPT.new()
	dm.configure_for_test(gd, ps, tm, wm, rm, sm, fm)
	var context: Dictionary = dm.build_context("priest")
	t.ok(bool(context.get("is_festival", false)), "dialogue context reports a festival is active")
	t.eq(str(context.get("festival_id", "")), "springturn_blessing",
		"dialogue context carries the correct festival id")

	var off_env := _make_fm(17, 12, "spring")
	var dm2 = DIALOGUE_MANAGER_SCRIPT.new()
	dm2.configure_for_test(off_env["gd"], ps, off_env["tm"], wm, rm, sm, off_env["fm"])
	var off_context: Dictionary = dm2.build_context("priest")
	t.not_ok(bool(off_context.get("is_festival", false)),
		"dialogue context reports no festival active outside the window")
	t.eq(str(off_context.get("festival_id", "")), "",
		"festival_id is empty when no festival is active")
	t.section_done("dialogue context reflects festival")
