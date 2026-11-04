extends RefCounted
## TitheManager market coverage: open days, buy/sell math with toll and
## quality multipliers, and info queries. Uses real GameData + a PlayerState
## mock and a mutable day holder (lambdas capture arrays by reference).

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "market"


func run(t: Object) -> void:
	_test_open_days(t)
	_test_buy(t)
	_test_sell_math(t)
	_test_sell_guard(t)
	_test_market_info(t)
	t.completed(5)


func _make(t: Object) -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 200
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var day_holder := [1]
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0])
	return [tm, ps, day_holder]


func _test_open_days(t: Object) -> void:
	var parts := _make(t)
	var tm = parts[0]
	var day_holder: Array = parts[2]
	t.not_ok(tm.is_market_open(), "market closed on day 1")
	day_holder[0] = 3
	t.ok(tm.is_market_open(), "market open on day 3")
	t.section_done("open days")


func _test_buy(t: Object) -> void:
	var parts := _make(t)
	var tm = parts[0]
	var ps = parts[1]
	day_holder_set(parts[2], 3)
	t.ok(tm.can_buy("spear", 1), "can buy spear with 200 coin")
	t.ok(tm.buy_item("spear", 1), "buy spear succeeds")
	t.eq(ps.money, 42, "spear costs 158 with toll")
	t.eq(ps.get_item_count("spear"), 1, "spear added to inventory")
	ps.money = 0
	t.not_ok(tm.can_buy("spear", 1), "cannot buy with no money")
	t.not_ok(tm.buy_item("spear", 1), "buy fails without money")
	ps.money = 200
	t.ok(tm.buy_item("turnip_seed", 3), "buy 3 seeds")
	t.eq(ps.money, 193, "3 seeds cost 7 with toll")
	t.eq(ps.get_item_count("turnip_seed"), 3, "3 seeds in inventory")
	t.section_done("buy")


func _test_sell_math(t: Object) -> void:
	var parts := _make(t)
	var tm = parts[0]
	var ps = parts[1]
	day_holder_set(parts[2], 3)
	ps.add_item("turnip", 5)
	t.ok(tm.can_sell("turnip", 5, "common"), "can sell 5 common turnips")
	var net: int = tm.sell_crop("turnip", 5, "common")
	t.eq(net, 23, "5 common turnips net 23 (floor of 23.75)")
	t.eq(ps.get_item_count("turnip"), 0, "turnips removed")
	ps.add_item("turnip", 3, "fine")
	t.eq(tm.sell_crop("turnip", 3, "fine"), 21, "3 fine turnips net 21")
	ps.add_item("turnip", 1, "choice")
	t.eq(tm.sell_crop("turnip", 1, "choice"), 9, "1 choice turnip nets 9")
	ps.add_item("turnip", 1)
	t.eq(tm.sell_crop("turnip", 1, "common"), 4, "1 common turnip nets 4")
	t.section_done("sell math")


func _test_sell_guard(t: Object) -> void:
	var parts := _make(t)
	var tm = parts[0]
	var ps = parts[1]
	day_holder_set(parts[2], 1)
	ps.add_item("turnip", 2)
	t.not_ok(tm.can_sell("turnip", 2, "common"), "cannot sell when market closed")
	t.eq(tm.sell_crop("turnip", 2, "common"), 0, "sell returns 0 when closed")
	t.eq(ps.get_item_count("turnip"), 2, "no inventory change when closed")
	day_holder_set(parts[2], 3)
	t.eq(tm.sell_crop("turnip", 5, "common"), 0, "cannot sell more than owned")
	t.section_done("sell guard")


func _test_market_info(t: Object) -> void:
	var parts := _make(t)
	var tm = parts[0]
	var info: Dictionary = tm.get_market_info()
	t.not_ok(bool(info.get("open", true)), "day 1 market info reports closed")
	t.eq(int(info.get("next_day", -1)), 3, "next market day is 3")
	t.section_done("info")


func day_holder_set(holder: Array, day: int) -> void:
	holder[0] = day
