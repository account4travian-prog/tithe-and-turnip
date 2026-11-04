extends RefCounted
## E4 (ADR-035) coverage: ConditionEvaluator's full vocabulary as pure unit
## tests (synthetic context dicts, no autoloads needed), then DialogueManager
## integration against real GameData/PlayerState/TimeManager/WeatherManager/
## ReputationManager/SkillManager fixtures - priority selection, frequency
## gating, set_flag, save round-trip, and (the whole point of ADR-035) that
## the backfilled priorities on the existing 36 lines reproduce the exact
## same line the old lines[0]-of-first-match bug happened to return, for
## every standing value, not just the common ones.

const CONDITION_EVALUATOR_SCRIPT := preload("res://scripts/world/condition_evaluator.gd")
const DIALOGUE_MANAGER_SCRIPT := preload("res://scripts/autoloads/dialogue_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")
const WEATHER_MANAGER_SCRIPT := preload("res://scripts/autoloads/weather_manager.gd")
const REPUTATION_MANAGER_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const SKILL_MANAGER_SCRIPT := preload("res://scripts/autoloads/skill_manager.gd")

const TM_CFG := {
	"real_seconds_per_game_minute": 0.5, "minutes_per_hour": 60,
	"days_per_season": 28, "seasons": ["spring", "summer", "autumn", "winter"],
	"wake_hour": 6, "sleep_hour": 24,
}


func suite_name() -> String:
	return "dialogue_engine"


func run(t: Object) -> void:
	_test_condition_time(t)
	_test_condition_season_weather(t)
	_test_condition_market_mass(t)
	_test_condition_festival(t)
	_test_condition_has_item(t)
	_test_condition_skill_level(t)
	_test_condition_player_stats(t)
	_test_condition_standing_opinion(t)
	_test_condition_event_flag(t)
	_test_condition_not(t)
	_test_condition_and_semantics(t)
	_test_condition_reputation_backward_compat(t)
	_test_condition_unknown_key_fails_open(t)
	_test_backward_compat_neutral_standing(t)
	_test_backward_compat_high_standing(t)
	_test_backward_compat_low_standing(t)
	_test_event_flag_gated_line(t)
	_test_priority_tie_break(t)
	_test_frequency_once_per_day(t)
	_test_set_flag(t)
	_test_save_roundtrip(t)
	t.completed(36)


# --- ConditionEvaluator: pure unit tests ---------------------------------

func _test_condition_time(t: Object) -> void:
	var ctx := {"time_hour": 12}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"time": {"min": 6, "max": 18}}, ctx),
		"hour 12 is within [6,18]")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"time": {"min": 12, "max": 12}}, ctx),
		"hour exactly at both min and max passes (inclusive)")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"time": {"min": 13, "max": 18}}, ctx),
		"hour below min fails")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"time": {"min": 6, "max": 11}}, ctx),
		"hour above max fails")
	t.section_done("condition: time")


func _test_condition_season_weather(t: Object) -> void:
	var ctx := {"season": "spring", "weather": "rain"}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"season": "spring"}, ctx), "season exact match")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"season": "summer"}, ctx), "season mismatch")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"weather": "rain"}, ctx), "weather exact match")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"weather": "snow"}, ctx), "weather mismatch")
	t.section_done("condition: season/weather")


func _test_condition_market_mass(t: Object) -> void:
	var ctx := {"is_market_day": true, "is_mass_day": false}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_market_day": true}, ctx), "market day matches true")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_mass_day": true}, ctx), "mass day matches false")
	t.section_done("condition: market/mass")


func _test_condition_festival(t: Object) -> void:
	var ctx_none := {"is_festival": false, "festival_id": ""}
	var ctx_named := {"is_festival": true, "festival_id": "springturn_blessing"}
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_festival": true}, ctx_none),
		"bool form: no festival active fails a 'true' check")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_festival": true}, ctx_named),
		"bool form: a festival active passes a 'true' check")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_festival": "springturn_blessing"}, ctx_named),
		"string form: matches the specific festival id")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"is_festival": "harvest_home"}, ctx_named),
		"string form: a different festival id fails")
	t.section_done("condition: festival")


func _test_condition_has_item(t: Object) -> void:
	var ctx := {"item_counts": {"turnip": 3}}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"has_item": {"id": "turnip", "min": 3}}, ctx),
		"exactly enough of the item passes")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"has_item": {"id": "turnip", "min": 4}}, ctx),
		"not enough of the item fails")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"has_item": {"id": "barley", "min": 1}}, ctx),
		"an item not in inventory at all fails")
	t.section_done("condition: has_item")


func _test_condition_skill_level(t: Object) -> void:
	var ctx := {"skill_levels": {"farming": 3}}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"skill_level": {"id": "farming", "min": 3}}, ctx),
		"skill level exactly at min passes")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"skill_level": {"id": "farming", "min": 4}}, ctx),
		"skill level below min fails")
	t.section_done("condition: skill_level")


func _test_condition_player_stats(t: Object) -> void:
	var ctx := {"money": 50, "energy": 20.0, "health": 30}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"player_money": {"min": 50}}, ctx), "money threshold")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"player_money": {"min": 51}}, ctx), "money below threshold")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"player_energy": {"min": 20}}, ctx), "energy threshold")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"player_health": {"min": 30}}, ctx), "health threshold")
	t.section_done("condition: player stats")


func _test_condition_standing_opinion(t: Object) -> void:
	var ctx := {"standings": {"village": 20.0}, "opinions": {"steward": 10.0}}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"standing": {"axis": "village", "min": 20}}, ctx),
		"standing axis threshold")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"standing": {"axis": "village", "min": 21}}, ctx),
		"standing below threshold fails")
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"opinion": {"npc": "steward", "min": 10}}, ctx),
		"opinion toward a specific (possibly different) npc")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"opinion": {"npc": "priest", "min": 1}}, ctx),
		"opinion toward an npc with no recorded opinion defaults to 0 and fails")
	t.section_done("condition: standing/opinion")


func _test_condition_event_flag(t: Object) -> void:
	var ctx := {"event_flags": ["forage.gathered_morel"]}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"event_flag": "forage.gathered_morel"}, ctx),
		"flag present passes")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"event_flag": "raid.survived_day15"}, ctx),
		"flag absent fails")
	t.section_done("condition: event_flag")


func _test_condition_not(t: Object) -> void:
	var ctx := {"season": "spring"}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"not": {"season": "summer"}}, ctx),
		"not inverts a failing condition to pass")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"not": {"season": "spring"}}, ctx),
		"not inverts a passing condition to fail")
	t.section_done("condition: not")


func _test_condition_and_semantics(t: Object) -> void:
	var ctx := {"season": "spring", "time_hour": 12, "money": 10}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate(
		{"season": "spring", "time": {"min": 6, "max": 18}, "player_money": {"min": 10}}, ctx),
		"all conditions passing -> true")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate(
		{"season": "spring", "player_money": {"min": 11}}, ctx),
		"one failing condition among several -> false (AND, not OR)")
	t.section_done("condition: AND semantics")


func _test_condition_reputation_backward_compat(t: Object) -> void:
	var ctx := {"standings": {"manor": 15.0}}
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"reputation.manor": {"min": 10}}, ctx),
		"dialogue.json v3's dot-notation reputation key still works")
	t.not_ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"reputation.manor": {"min": 20}}, ctx),
		"dot-notation key still respects the threshold")
	t.section_done("condition: reputation.X backward compat")


func _test_condition_unknown_key_fails_open(t: Object) -> void:
	# GameData validation is the real enforcement point (push_error at load);
	# the evaluator's own fallback is defense in depth and must not crash.
	t.ok(CONDITION_EVALUATOR_SCRIPT.evaluate({"some_made_up_key": "whatever"}, {}),
		"an unrecognized key does not crash the evaluator")
	t.section_done("condition: unknown key")


# --- DialogueManager: integration against real data ----------------------

func _make_env() -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.money = 20
	ps.energy = 100.0
	ps.health = 50
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.configure(TM_CFG)
	tm.day = 5
	tm.hour = 12
	tm.season = "spring"
	var wm = WEATHER_MANAGER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "sunny")
	var rm = REPUTATION_MANAGER_SCRIPT.new()
	rm.configure_for_test(gd, ps)
	var sm = SKILL_MANAGER_SCRIPT.new()
	sm.configure_for_test(gd)
	var dm = DIALOGUE_MANAGER_SCRIPT.new()
	dm.configure_for_test(gd, ps, tm, wm, rm, sm)
	return {"gd": gd, "ps": ps, "tm": tm, "wm": wm, "rm": rm, "sm": sm, "dm": dm}


func _test_backward_compat_neutral_standing(t: Object) -> void:
	var env := _make_env()
	var rm: Object = env["rm"]
	rm.standings["manor"] = 0.0
	var line: String = (env["dm"] as Object).get_next_line("steward")
	t.eq(line, "Work hard and you may eat.",
		"neutral manor standing (0) picks the same line the old lines[0] bug happened to pick")
	t.section_done("backward compat: neutral standing")


func _test_backward_compat_high_standing(t: Object) -> void:
	var env := _make_env()
	var rm: Object = env["rm"]
	rm.standings["manor"] = 70.0
	var line: String = (env["dm"] as Object).get_next_line("steward")
	t.eq(line, "The lord himself has heard your name spoken well.",
		"high manor standing (70) picks the friendliest line, not a random tie among all 5 matches")
	t.section_done("backward compat: high standing")


func _test_backward_compat_low_standing(t: Object) -> void:
	var env := _make_env()
	var rm: Object = env["rm"]
	rm.standings["manor"] = -60.0
	var line: String = (env["dm"] as Object).get_next_line("steward")
	t.eq(line, "You're a stain on this manor. Watch yourself.",
		"low manor standing (-60) still resolves to the -100-threshold line, not the fallback")
	t.section_done("backward compat: low standing")


func _test_event_flag_gated_line(t: Object) -> void:
	var env := _make_env()
	var ps: Object = env["ps"]
	var rm: Object = env["rm"]
	rm.standings["church"] = 0.0
	var before: String = (env["dm"] as Object).get_next_line("priest")
	t.eq(before, "A donation to the church is never forgotten.",
		"precondition: without the flag, the priest gives the ordinary neutral-standing line")
	ps.set_event_flag("forage.gathered_morel")
	var after: String = (env["dm"] as Object).get_next_line("priest")
	t.eq(after, "A rare find, they tell me - blessed be a lucky forager.",
		"with the flag set, the higher-priority event_flag-gated line wins")
	t.section_done("event flag gated line")


func _test_priority_tie_break(t: Object) -> void:
	var env := _make_env()
	var gd: Object = env["gd"]
	# Overwrite GameData's loaded dialogue with a synthetic two-line tie to
	# test DialogueManager's own selection logic in isolation from the real
	# shipped content (gd.dialogues is a public var - a deliberate seam).
	gd.dialogues = [
		{"npc_id": "tester", "text": "A", "priority": 5},
		{"npc_id": "tester", "text": "B", "priority": 5},
		{"npc_id": "tester", "text": "fallback", "priority": -999},
	]
	var dm: Object = env["dm"]
	var saw_a := false
	var saw_b := false
	for _i in range(30):
		var line: String = dm.get_next_line("tester")
		if line == "A":
			saw_a = true
		elif line == "B":
			saw_b = true
		else:
			t.fail("tie-break returned an unexpected line: %s" % line)
	t.ok(saw_a and saw_b, "both exact-priority-tied lines are reachable across repeated picks")
	t.section_done("priority tie-break")


func _test_frequency_once_per_day(t: Object) -> void:
	var env := _make_env()
	var gd: Object = env["gd"]
	gd.dialogues = [
		{"npc_id": "tester", "text": "special", "priority": 5, "frequency": "once_per_day"},
		{"npc_id": "tester", "text": "fallback", "priority": -999},
	]
	var dm: Object = env["dm"]
	t.eq(dm.get_next_line("tester"), "special", "once_per_day line is available the first time")
	t.eq(dm.get_next_line("tester"), "fallback",
		"the same once_per_day line is unavailable on a second call the same day")
	dm._on_day_passed(6, "spring", 1)
	t.eq(dm.get_next_line("tester"), "special",
		"once_per_day availability resets after a day_passed rollover")
	t.section_done("frequency: once_per_day")


func _test_set_flag(t: Object) -> void:
	var env := _make_env()
	var gd: Object = env["gd"]
	var ps: Object = env["ps"]
	gd.dialogues = [
		{"npc_id": "tester", "text": "flagged", "priority": 5, "set_flag": "tester.spoke"},
	]
	t.not_ok(ps.has_event_flag("tester.spoke"), "precondition: flag not yet set")
	(env["dm"] as Object).get_next_line("tester")
	t.ok(ps.has_event_flag("tester.spoke"), "selecting a line with set_flag sets it on PlayerState")
	t.section_done("set_flag")


func _test_save_roundtrip(t: Object) -> void:
	var env := _make_env()
	var gd: Object = env["gd"]
	gd.dialogues = [
		{"npc_id": "tester", "text": "special", "priority": 5, "frequency": "once_per_day"},
		{"npc_id": "tester", "text": "fallback", "priority": -999},
	]
	var dm: Object = env["dm"]
	dm.get_next_line("tester")  # spend the once_per_day line
	var dumped: Dictionary = dm.to_dict()
	t.eq((dumped.get("tester", []) as Array).size(), 1, "to_dict carries the spoken line index")
	var restored := DIALOGUE_MANAGER_SCRIPT.new()
	restored.configure_for_test(env["gd"], env["ps"], env["tm"], env["wm"], env["rm"], env["sm"])
	restored.from_dict(dumped)
	t.eq(restored.get_next_line("tester"), "fallback",
		"once_per_day history round-trips: the restored manager still withholds the spent line")
	t.section_done("save roundtrip")
