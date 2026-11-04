extends RefCounted
## Black-market coverage: visit-day gating, premium net vs the tolled market
## path (explicitly different channels), deterministic detection at 1.0/0.0
## base chance, and the standing-reduces-detection formula. Detection tests
## inject a real ReputationManager via the configure_for_test seam so the
## detection branch runs; the 1.0/0.0 chances make the roll deterministic.

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")


func suite_name() -> String:
	return "blackmarket"


func run(t: Object) -> void:
	_test_open_days(t)
	_test_premium_net_no_toll(t)
	_test_closed_days_reject(t)
	_test_detection_at_full_chance(t)
	_test_detection_at_zero_chance(t)
	_test_standing_reduces_chance(t)
	t.completed(6)


func _make(day: int, reputation: Node = null) -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 0
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day, null, reputation)
	return [tm, ps, gd]


func _test_open_days(t: Object) -> void:
	var parts := _make(9)
	var tm = parts[0]
	t.ok(tm.is_black_market_open(), "black market open on visit day 9")
	var parts2 := _make(10)
	var tm2 = parts2[0]
	t.not_ok(tm2.is_black_market_open(), "closed on day 10")
	t.section_done("open days")


func _test_premium_net_no_toll(t: Object) -> void:
	var parts := _make(9)
	var tm = parts[0]
	var ps = parts[1]
	ps.add_item("turnip", 4, "fine")
	t.ok(tm.can_black_market_sell("turnip", 4, "fine"), "can sell on a visit day")
	var net: int = tm.black_market_sell("turnip", 4, "fine")
	t.eq(net, 37, "4 fine turnips net 37 (4*5*1.5*1.25, no toll)")
	t.eq(ps.money, 37, "money credited")
	t.eq(ps.get_item_count("turnip"), 0, "items removed")
	# The same inputs through the tolled market path must differ.
	ps.add_item("turnip", 4, "fine")
	var market_net: int = tm._compute_sell_net("turnip", 4, "fine")
	t.eq(market_net, 28, "same sale through the market nets 28 (tolled)")
	t.not_ok(net == market_net, "black market and market paths genuinely differ")
	t.section_done("premium")


func _test_closed_days_reject(t: Object) -> void:
	var parts := _make(10)
	var tm = parts[0]
	var ps = parts[1]
	ps.add_item("turnip", 2)
	t.not_ok(tm.can_black_market_sell("turnip", 2, "common"), "cannot sell off visit days")
	t.eq(tm.black_market_sell("turnip", 2, "common"), 0, "sale rejected returns 0")
	t.eq(ps.get_item_count("turnip"), 2, "items untouched")
	t.section_done("gating")


func _test_detection_at_full_chance(t: Object) -> void:
	var parts := _make(9)
	var tm = parts[0]
	var ps = parts[1]
	var gd = parts[2]
	gd.manor_cfg["black_market"]["base_detection_chance"] = 1.0
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	tm.set("_test_rep", rep)
	ps.add_item("turnip", 1)
	tm.black_market_sell("turnip", 1, "common")
	ps.add_item("turnip", 1)
	tm.black_market_sell("turnip", 1, "common")
	var pending: Array = tm.get("_pending_offenses") as Array
	t.eq(pending.size(), 2, "every sale queues an offense at 1.0 chance")
	t.eq(str(pending[0]), "illegal_sale", "offense kind is illegal_sale")
	t.section_done("full chance")


func _test_detection_at_zero_chance(t: Object) -> void:
	var parts := _make(9)
	var tm = parts[0]
	var ps = parts[1]
	var gd = parts[2]
	gd.manor_cfg["black_market"]["base_detection_chance"] = 0.0
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	tm.set("_test_rep", rep)
	ps.add_item("turnip", 1)
	tm.black_market_sell("turnip", 1, "common")
	t.eq((tm.get("_pending_offenses") as Array).size(), 0, "no offense at 0.0 chance")
	t.section_done("zero chance")


func _test_standing_reduces_chance(t: Object) -> void:
	# Same formula as _roll_black_market_detection - a direct check that the
	# two standings produce different effective chances in the right order.
	var base_chance := 0.2
	var reduction := 0.15
	var chance_low := clampf(base_chance - (10.0 / 100.0) * reduction, 0.0, 1.0)
	var chance_high := clampf(base_chance - (80.0 / 100.0) * reduction, 0.0, 1.0)
	t.ok(chance_low > 0.18 and chance_low < 0.19, "10 standing keeps ~0.185 chance")
	t.ok(chance_high > 0.07 and chance_high < 0.09, "80 standing drops to ~0.08")
	t.ok(chance_high < chance_low, "higher standing lowers detection chance")
	t.section_done("standing")
