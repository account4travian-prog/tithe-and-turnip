extends RefCounted
## Festival contest engine coverage (world_bible.md Section V, festivals.json
## v2): the Furrow Race's forgiveness-widened timing windows at Farming
## level 0 vs 5, the pure race-step state machine driven by synthetic
## elapsed values (no real frames, no Timer nodes), direct-entry payout,
## cheer/bet payout math for both entrants at both bet extremes, the
## one-shot-per-occurrence gates, and season gating (a Summer-only contest
## is not enterable in Spring). Haysel/Harvest Home/Long Night are covered
## as data-complete, non-crashing paths - only Spring is reachable in the
## vertical slice.

const FESTIVAL_MANAGER_SCRIPT := preload("res://scripts/autoloads/festival_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const REPUTATION_MANAGER_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const SKILL_MANAGER_SCRIPT := preload("res://scripts/autoloads/skill_manager.gd")

const TM_CFG := {
	"real_seconds_per_game_minute": 0.5, "minutes_per_hour": 60,
	"days_per_season": 28, "seasons": ["spring", "summer", "autumn", "winter"],
	"wake_hour": 6, "sleep_hour": 24,
}


func suite_name() -> String:
	return "festival_contests"


func run(t: Object) -> void:
	_test_contest_data_present(t)
	_test_furrow_forgiveness_widens_with_level(t)
	_test_race_step_machine(t)
	_test_direct_entry_and_payout(t)
	_test_cheer_bet_payouts(t)
	_test_one_shot_gates(t)
	_test_season_gating(t)
	_test_stub_contests_are_closed(t)
	t.completed(102)


func _make_env(day: int, hour: int, season: String) -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.configure(TM_CFG)
	tm.day = day
	tm.hour = hour
	tm.season = season
	var ps = PLAYER_STATE_SCRIPT.new()
	var rm = REPUTATION_MANAGER_SCRIPT.new()
	rm.configure_for_test(gd, ps)
	var sm = SKILL_MANAGER_SCRIPT.new()
	sm.configure_for_test(gd)
	var fm = FESTIVAL_MANAGER_SCRIPT.new()
	fm.configure_for_test(gd, tm, ps, rm, sm)
	return {"gd": gd, "tm": tm, "ps": ps, "rm": rm, "sm": sm, "fm": fm}


func _timing(env: Dictionary, festival_id: String) -> Dictionary:
	var contest: Dictionary = (env["fm"] as Object).get_contest(festival_id)
	var timing: Dictionary = contest.get("timing", {})
	return timing


func _test_contest_data_present(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var spring: Dictionary = gd.get_festival("springturn_blessing")
	var contest: Dictionary = spring.get("contest", {})
	t.not_ok(contest.is_empty(), "spring festival carries a contest block")
	t.eq(str(contest.get("mode", "")), "furrow_race", "spring contest is the Furrow Race")
	t.eq(str(contest.get("skill_id", "")), "farming", "Furrow Race tests farming")
	var timing: Dictionary = contest.get("timing", {})
	t.eq((timing.get("beats", []) as Array).size(), 3, "Furrow Race has exactly three beats")
	t.eq(int(contest.get("bet", {}).get("min", -1)), 1, "Furrow Race bet min is 1")
	t.eq(int(contest.get("bet", {}).get("max", -1)), 5, "Furrow Race bet max is 5")
	var entrants: Array = contest.get("entrants", [])
	t.ok(entrants.has("villager_2") and entrants.has("villager_4"),
		"Furrow Race entrants are Cedric and Bram")
	t.eq(float(contest.get("odds", {}).get("villager_2", -1.0)), 0.55,
		"odds weighted slightly toward Cedric")
	t.eq(float(contest.get("odds", {}).get("villager_4", -1.0)), 0.45,
		"Bram carries the remaining weight")
	for festival_id: String in ["midsummer_fair", "harvest_home", "winter_feast"]:
		var other: Dictionary = gd.get_festival(festival_id)
		var other_contest: Dictionary = other.get("contest", {})
		t.not_ok(other_contest.is_empty(), "%s carries a contest block" % festival_id)
	var haysel: Dictionary = gd.get_festival("midsummer_fair")
	var haysel_contest: Dictionary = haysel.get("contest", {})
	t.eq(str(haysel_contest.get("skill_id", "")), "labor",
		"Haysel tests labor instead of farming")
	t.section_done("contest data present")


func _test_furrow_forgiveness_widens_with_level(t: Object) -> void:
	var env := _make_env(18, 12, "spring")
	var fm: Object = env["fm"]
	var timing := _timing(env, "springturn_blessing")
	t.ok(fm.press_scores_at(2.0, 0, 0, timing), "level 0 scores dead-center on beat 1")
	t.not_ok(fm.press_scores_at(2.56, 0, 0, timing), "level 0 misses just outside its window")
	t.ok(fm.press_scores_at(2.56, 0, 5, timing), "level 5 lands the same press inside its wider window")
	t.ok(fm.press_scores_at(2.90, 0, 5, timing), "level 5 still lands at the widened edge")
	t.not_ok(fm.press_scores_at(2.91, 0, 5, timing), "level 5 misses just past the widened edge")
	var at_level_0: int = fm.score_presses([2.0, 4.4, 8.0], 0, timing)
	var at_level_5: int = fm.score_presses([2.0, 4.4, 8.0], 5, timing)
	t.eq(at_level_0, 2, "level 0 scores 2 of 3 on a borderline run")
	t.eq(at_level_5, 3, "level 5 scores all 3 on the same borderline run")
	t.eq(at_level_5 - at_level_0, 1, "the level gap is exactly one more straight furrow")
	# Integration: the level that widens the RUNTIME window is read from
	# SkillManager when the race starts, not just available to pure calls.
	var env2 := _make_env(18, 12, "spring")
	var fm2: Object = env2["fm"]
	var sm2: Object = env2["sm"]
	sm2.add_xp("farming", 1200.0)
	var entered: Dictionary = fm2.start_contest("springturn_blessing")
	t.ok(bool(entered.get("ok", false)), "level-5 entry starts a race")
	fm2.advance_race(2.8, false)
	t.eq(fm2.press_race(), true, "the runtime window reflects farming level 5")
	fm2.cancel_race()
	t.section_done("furrow forgiveness widens with level")


func _test_race_step_machine(t: Object) -> void:
	var env := _make_env(18, 12, "spring")
	var fm: Object = env["fm"]
	var timing := _timing(env, "springturn_blessing")
	var open: Dictionary = fm.race_step(0.0, 0, false, 2.2, false, 0, timing)
	t.eq(float(open.get("elapsed", -1.0)), 2.2, "step accumulates elapsed time")
	t.eq(int(open.get("beat_index", -1)), 0, "beat 1 window is still open at 2.2s")
	t.ok((open.get("events", []) as Array).is_empty(), "no events before a window closes")
	var hit: Dictionary = fm.race_step(2.2, 0, false, 0.0, true, 0, timing)
	t.eq((hit.get("events", []) as Array), ["hit"], "press inside the window scores a hit")
	t.ok(bool(hit.get("press_used", false)), "press_used latches after a hit")
	var miss: Dictionary = fm.race_step(0.0, 0, false, 4.6, false, 0, timing)
	t.eq((miss.get("events", []) as Array), ["miss"], "an unpressed window reports a miss")
	t.eq(int(miss.get("beat_index", -1)), 1, "the state advances to beat 2 after the miss")
	var catch_up: Dictionary = fm.race_step(4.6, 1, false, 0.0, true, 0, timing)
	t.eq((catch_up.get("events", []) as Array), ["hit"],
		"a press in beat 2's window still scores after beat 1 was missed")
	var quiet: Dictionary = fm.race_step(4.6, 1, false, 0.0, false, 0, timing)
	t.eq((quiet.get("events", []) as Array), [], "no event for a beatless step")
	var double_dip: Dictionary = fm.race_step(2.2, 0, true, 0.0, true, 0, timing)
	t.ok((double_dip.get("events", []) as Array).is_empty(),
		"a second press cannot double-dip the same beat")
	t.section_done("race step machine")


func _test_direct_entry_and_payout(t: Object) -> void:
	var env := _make_env(18, 12, "spring")
	var fm: Object = env["fm"]
	var ps: Object = env["ps"]
	var rm: Object = env["rm"]
	t.ok(fm.can_enter_contest("springturn_blessing"), "contest is enterable before participation")
	ps.add_money(50)
	var entered: Dictionary = fm.start_contest("springturn_blessing")
	t.ok(bool(entered.get("ok", false)), "starting the contest succeeds")
	t.ok(ps.has_event_flag("festival.contest_entered_springturn_blessing"),
		"entry sets the one-shot flag")
	t.ok(fm.is_race_active(), "a race is active after entry")
	t.eq(float(rm.get_standing("village")), 2.0, "entry applies the data-driven village standing")
	fm.advance_race(2.8, false)
	t.eq(fm.press_race(), false, "a press outside any window scores nothing")
	fm.advance_race(2.2, false)
	t.eq(fm.press_race(), true, "a press inside the window scores")
	fm.advance_race(3.0, false)
	t.eq(fm.press_race(), true, "the third prompt scores too")
	fm.advance_race(1.0, false)
	t.not_ok(fm.is_race_active(), "the race resolves when the last window closes")
	var state: Dictionary = fm.get_race_state()
	var result: Dictionary = state.get("result", {})
	t.eq(int(result.get("successes", -1)), 2, "two straight furrows scored")
	t.eq(int(result.get("payout", -1)), 5, "payout_by_score[2] is paid")
	t.eq(int(ps.money), 55, "payout lands in the player's purse")
	t.section_done("direct entry and payout")


func _test_cheer_bet_payouts(t: Object) -> void:
	var env := _make_env(18, 12, "spring")
	var fm: Object = env["fm"]
	var ps: Object = env["ps"]
	var rm: Object = env["rm"]
	ps.add_money(100)
	var cedric := "villager_2"
	var bram := "villager_4"
	t.ok(fm.can_cheer("springturn_blessing", cedric), "Cedric is cheerable")
	t.ok(fm.can_cheer("springturn_blessing", bram), "Bram is cheerable")
	t.not_ok(fm.can_cheer("springturn_blessing", "steward"), "non-entrants are not cheerable")
	var cedric_min: Dictionary = fm.cheer("springturn_blessing", cedric, 1, 0.0)
	t.ok(bool(cedric_min.get("ok", false)), "minimum-bet Cedric cheer resolves")
	t.eq(bool(cedric_min.get("win", false)), true, "roll 0.0 wins for Cedric")
	t.eq(int(cedric_min.get("payout", -1)), 2, "Cedric min bet pays round(1 * 1.8)")
	t.eq(float(rm.get_opinion(cedric)), 2.0, "cheering raises the backed entrant's opinion")
	var env2 := _make_env(18, 12, "spring")
	var fm2: Object = env2["fm"]
	var ps2: Object = env2["ps"]
	ps2.add_money(100)
	var bram_max: Dictionary = fm2.cheer("springturn_blessing", bram, 5, 0.0)
	t.ok(bool(bram_max.get("ok", false)), "maximum-bet Bram cheer resolves")
	t.eq(bool(bram_max.get("win", false)), true, "roll 0.0 wins for Bram too")
	t.eq(int(bram_max.get("payout", -1)), 11, "Bram max bet pays round(5 * 2.2)")
	t.eq(int(ps2.money), 106, "Bram win money math: 100 - 5 stake + 11 payout")
	var env3 := _make_env(18, 12, "spring")
	var fm3: Object = env3["fm"]
	var ps3: Object = env3["ps"]
	ps3.add_money(100)
	var cedric_mid: Dictionary = fm3.cheer("springturn_blessing", cedric, 5, 0.5)
	t.eq(bool(cedric_mid.get("win", false)), true, "Cedric wins on a 0.5 roll")
	t.eq(int(cedric_mid.get("payout", -1)), 9, "Cedric max bet pays round(5 * 1.8)")
	t.eq(int(ps3.money), 104, "Cedric win money math: 100 - 5 stake + 9 payout")
	var env4 := _make_env(18, 12, "spring")
	var fm4: Object = env4["fm"]
	var ps4: Object = env4["ps"]
	ps4.add_money(100)
	var bram_mid: Dictionary = fm4.cheer("springturn_blessing", bram, 1, 0.5)
	t.eq(bool(bram_mid.get("win", false)), false, "Bram loses on a 0.5 roll")
	t.eq(int(bram_mid.get("payout", -1)), 0, "a losing bet pays nothing")
	t.eq(int(ps4.money), 99, "the losing stake is gone")
	var env5 := _make_env(18, 12, "spring")
	var fm5: Object = env5["fm"]
	var cedric_lose: Dictionary = fm5.cheer("springturn_blessing", cedric, 1, 0.9)
	t.eq(bool(cedric_lose.get("win", false)), false, "Cedric loses on a 0.9 roll")
	var env6 := _make_env(18, 12, "spring")
	var fm6: Object = env6["fm"]
	var bram_lose: Dictionary = fm6.cheer("springturn_blessing", bram, 1, 0.9)
	t.eq(bool(bram_lose.get("win", false)), false, "Bram loses on a 0.9 roll")
	t.section_done("cheer/bet payouts")


func _test_one_shot_gates(t: Object) -> void:
	var env := _make_env(18, 12, "spring")
	var fm: Object = env["fm"]
	var ps: Object = env["ps"]
	ps.add_money(50)
	t.ok(fm.can_enter_contest("springturn_blessing"), "first entry is allowed")
	var first: Dictionary = fm.start_contest("springturn_blessing")
	t.ok(bool(first.get("ok", false)), "first entry succeeds")
	t.not_ok(fm.can_enter_contest("springturn_blessing"),
		"entry is one-shot per festival occurrence")
	var second: Dictionary = fm.start_contest("springturn_blessing")
	t.not_ok(bool(second.get("ok", false)), "second entry is refused")
	t.ok(ps.has_event_flag("festival.contest_entered_springturn_blessing"),
		"entry flag persists")
	t.ok(fm.is_race_active(), "the refused second entry leaves the first race intact")
	fm.cancel_race()
	t.not_ok(fm.is_race_active(), "cancel_race clears an active race")
	var env2 := _make_env(18, 12, "spring")
	var fm2: Object = env2["fm"]
	var ps2: Object = env2["ps"]
	ps2.add_money(50)
	t.ok(fm2.can_cheer("springturn_blessing", "villager_2"), "first cheer is allowed")
	var cheer_first: Dictionary = fm2.cheer("springturn_blessing", "villager_2", 1, 0.0)
	t.ok(bool(cheer_first.get("ok", false)), "first cheer succeeds")
	t.not_ok(fm2.can_cheer("springturn_blessing", "villager_2"),
		"cheer is one-shot per festival occurrence")
	t.not_ok(fm2.can_cheer("springturn_blessing", "villager_4"),
		"the other entrant is also blocked once cheered")
	var cheer_second: Dictionary = fm2.cheer("springturn_blessing", "villager_4", 1, 0.0)
	t.not_ok(bool(cheer_second.get("ok", false)), "second cheer is refused")
	t.ok(ps2.has_event_flag("festival.contest_cheered_springturn_blessing"),
		"cheer flag persists")
	t.section_done("one-shot gates")


func _test_season_gating(t: Object) -> void:
	var spring_env := _make_env(18, 12, "spring")
	var spring_fm: Object = spring_env["fm"]
	var summer_env := _make_env(15, 16, "summer")
	var summer_fm: Object = summer_env["fm"]
	t.eq(str(spring_fm.get_active_festival().get("id", "")), "springturn_blessing",
		"spring env has the spring festival active")
	t.eq(str(summer_fm.get_active_festival().get("id", "")), "midsummer_fair",
		"summer env has the summer festival active")
	t.not_ok(spring_fm.can_enter_contest("midsummer_fair"),
		"the Summer contest is not enterable while Spring is active")
	t.not_ok(spring_fm.can_cheer("midsummer_fair", "villager_5"),
		"the Summer contest is not cheerable while Spring is active")
	var refused: Dictionary = spring_fm.start_contest("midsummer_fair")
	t.not_ok(bool(refused.get("ok", false)), "starting a non-active festival's contest is refused")
	t.ok(summer_fm.can_enter_contest("midsummer_fair"),
		"the Summer contest is enterable when Summer is active")
	t.ok(summer_fm.can_cheer("midsummer_fair", "villager_5"),
		"the Summer contest is cheerable when Summer is active")
	var autumn_env := _make_env(10, 14, "autumn")
	var autumn_fm: Object = autumn_env["fm"]
	t.eq(str(autumn_fm.get_active_festival().get("id", "")), "harvest_home",
		"autumn env has harvest home active")
	var winter_env := _make_env(1, 20, "winter")
	var winter_fm: Object = winter_env["fm"]
	t.eq(str(winter_fm.get_active_festival().get("id", "")), "winter_feast",
		"winter env has the winter feast active")
	t.section_done("season gating")


func _test_stub_contests_are_closed(t: Object) -> void:
	var autumn_env := _make_env(10, 14, "autumn")
	var autumn_fm: Object = autumn_env["fm"]
	var harvest: Dictionary = autumn_fm.get_contest("harvest_home")
	t.eq(str(harvest.get("mode", "")), "sheaf_tying", "Harvest Home mode is sheaf_tying")
	t.not_ok(bool(harvest.get("has_direct_entry", false)), "Harvest Home direct entry is closed")
	t.not_ok(bool(harvest.get("has_cheer", false)), "Harvest Home cheering is closed")
	t.not_ok(autumn_fm.can_enter_contest("harvest_home"), "Harvest Home cannot be entered")
	t.not_ok(autumn_fm.can_cheer("harvest_home", "steward"), "Harvest Home cannot be cheered")
	var refused: Dictionary = autumn_fm.start_contest("harvest_home")
	t.not_ok(bool(refused.get("ok", false)), "starting Harvest Home is refused")
	var winter_env := _make_env(1, 20, "winter")
	var winter_fm: Object = winter_env["fm"]
	var winter_ps: Object = winter_env["ps"]
	var winter_rm: Object = winter_env["rm"]
	var story: Dictionary = winter_fm.get_contest("winter_feast")
	t.eq(str(story.get("mode", "")), "storytelling", "Winter mode is storytelling")
	t.not_ok(bool(story.get("has_direct_entry", false)), "storytelling has no direct entry")
	t.ok(bool(story.get("has_cheer", false)), "storytelling keeps cheer mode")
	var storytellers: Array = story.get("entrants", [])
	t.not_ok(storytellers.is_empty(), "storytellers are drawn from existing principals")
	var favourite := str(storytellers[0])
	winter_ps.add_money(50)
	var story_cheer: Dictionary = winter_fm.cheer("winter_feast", favourite, 0, 0.5)
	t.ok(bool(story_cheer.get("ok", false)), "cheering a storyteller without a bet resolves")
	t.eq(bool(story_cheer.get("win", false)), false, "no bet means no win/payout branch")
	t.eq(float(winter_rm.get_opinion(favourite)), 2.0,
		"cheering the storyteller raises their opinion")
	var winter_env2 := _make_env(1, 20, "winter")
	var winter_fm2: Object = winter_env2["fm"]
	var winter_ps2: Object = winter_env2["ps"]
	var story2: Dictionary = winter_fm2.get_contest("winter_feast")
	var storytellers2: Array = story2.get("entrants", [])
	winter_ps2.add_money(50)
	var bet_refused: Dictionary = winter_fm2.cheer("winter_feast", str(storytellers2[0]), 1, 0.5)
	t.not_ok(bool(bet_refused.get("ok", false)), "bets are not offered at the storytelling contest")
	t.eq(str(bet_refused.get("reason", "")), "bets_not_offered",
		"refusal reason names the missing bet mode")
	t.eq(int(winter_ps2.money), 50, "no coin moves when betting is refused")
	t.section_done("stub contests are closed")
