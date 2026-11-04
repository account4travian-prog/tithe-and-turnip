extends RefCounted
## Manor court coverage: offenses queue on reputation actions and are fined on
## scheduled court days, summed across offenses, never charged off-day, and a
## shortfall pays everything held then fires fail_court_fine through a real
## ReputationManager injected via the configure_for_test seam (the headless
## harness runs in SceneTree._initialize, where /root lookups cannot resolve).

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")


func suite_name() -> String:
	return "court"


func run(t: Object) -> void:
	_test_single_offense_fined(t)
	_test_multiple_offenses_sum(t)
	_test_non_court_day_never_charges(t)
	_test_shortfall_triggers_fail_court_fine(t)
	_test_attack_villager_queues_offense(t)
	t.completed(5)


func _make(reputation: Node = null) -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	ps.energy = 100.0
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var day_holder := [1]
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], null, reputation)
	return [tm, ps, gd, day_holder]


func _test_single_offense_fined(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var held: Array = []
	tm.court_held.connect(func(total_fine: int, offenses: Array) -> void:
		held.append([total_fine, offenses]))
	tm.record_offense("witnessed_violence")
	tm._on_day_passed(12, "spring", 1)
	t.eq(ps.money, 85, "day-12 court charges the 15-coin violence fine")
	t.eq((tm.get("_pending_offenses") as Array).size(), 0, "offenses cleared at court")
	t.eq(held.size(), 1, "court_held fired once")
	t.eq(int((held[0] as Array)[0]), 15, "court reports the correct total")
	# A second court day with no new offenses charges nothing.
	var held2: Array = []
	tm.court_held.connect(func(total_fine: int, _offenses: Array) -> void:
		held2.append(total_fine))
	tm._on_day_passed(26, "spring", 1)
	t.eq(ps.money, 85, "empty court charges nothing")
	t.eq(int(held2[0]), 0, "empty court reports zero")
	t.section_done("single offense")


func _test_multiple_offenses_sum(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	tm.record_offense("witnessed_violence")
	tm.record_offense("illegal_sale")
	tm.record_offense("witnessed_violence")
	tm._on_day_passed(12, "spring", 1)
	t.eq(ps.money, 50, "three offenses fine 15+20+15=50")
	t.eq((tm.get("_pending_offenses") as Array).size(), 0, "cleared after summing")
	t.section_done("summing")


func _test_non_court_day_never_charges(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	tm.record_offense("illegal_sale")
	tm.record_offense("witnessed_violence")
	tm._on_day_passed(13, "spring", 1)
	t.eq(ps.money, 100, "day 13 is not a court day - no fine")
	t.eq((tm.get("_pending_offenses") as Array).size(), 2, "offenses still pending")
	t.section_done("off day")


func _test_shortfall_triggers_fail_court_fine(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var gd = parts[2]
	ps.money = 10
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	tm.set("_test_rep", rep)
	tm.record_offense("witnessed_violence")  # 15-coin fine against 10 held
	tm._on_day_passed(12, "spring", 1)
	t.eq(ps.money, 0, "shortfall pays everything held")
	t.eq(rep.get_standing("manor"), -6.0, "fail_court_fine drops manor by 6")
	t.section_done("shortfall")


func _test_attack_villager_queues_offense(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var gd = parts[2]
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	# The live wiring connects action_applied in TitheManager._ready; the
	# harness cannot run _ready against /root, so the test wires the real
	# signal directly and still exercises the real cross-manager path.
	rep.action_applied.connect(tm._on_reputation_action)
	rep.apply_action("attack_villager")
	var pending: Array = tm.get("_pending_offenses") as Array
	t.eq(pending.size(), 1, "attack queues exactly one offense")
	t.eq(str(pending[0]), "witnessed_violence", "offense kind is witnessed_violence")
	rep.apply_action("attack_villager")
	t.eq((tm.get("_pending_offenses") as Array).size(), 2, "second attack queues again")
	t.section_done("integration")
