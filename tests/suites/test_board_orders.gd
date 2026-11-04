extends RefCounted
## E6/ADR-037 coverage: the supply-pressure curve (sale accrual, price
## locked at market open, the 0.5x-1.5x band, nightly decay) and the town
## board (market-day generation, in-season filter, 3-order cap, fulfillment
## across any quality mix, deadline expiry, save round-trip). Uses real
## GameData + a PlayerState mock and a mutable day holder, the same pattern
## as test_market.gd; deterministic via seed() where randomness is involved.

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")


func suite_name() -> String:
	return "board_orders"


func run(t: Object) -> void:
	_test_sale_builds_pressure_and_drops_next_price(t)
	_test_price_bounds(t)
	_test_pressure_decays(t)
	_test_orders_generate_on_market_days(t)
	_test_in_season_only(t)
	_test_orders_capped_at_three(t)
	_test_fulfill_order(t)
	_test_fulfill_accepts_any_quality(t)
	_test_order_expires_no_penalty(t)
	_test_save_roundtrip(t)
	_test_produce_count_formatting(t)
	t.completed(81)


func _make(reputation: Node = null) -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 200
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var day_holder := [1]
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], null, reputation)
	return [tm, ps, gd, day_holder]


func _advance_days(tm: Object, day_holder: Array, days: Array) -> void:
	for d: Variant in days:
		day_holder[0] = int(d)
		tm._on_day_passed(int(d), "spring", 1)


func _test_sale_builds_pressure_and_drops_next_price(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var day_holder: Array = parts[3]
	seed(100)
	day_holder[0] = 3
	tm._on_day_passed(3, "spring", 1)
	var price_before: int = tm.get_sell_price("turnip", 1, "common")
	ps.add_item("turnip", 60)
	var net: int = tm.sell_crop("turnip", 60, "common")
	t.ok(net > 0, "sale succeeded on the market day")
	t.eq(tm.get_crop_pressure("turnip"), 60.0, "selling 60 turnips adds 60 pressure")
	t.eq(tm.get_sell_price("turnip", 1, "common"), price_before,
		"price is fixed at market open - mid-day sales do not move it")
	_advance_days(tm, day_holder, [4, 5, 6, 7])
	t.ok(tm.get_supply_multiplier("turnip") < 1.0,
		"next market day's multiplier drops below base after the glut")
	var unpressured := int(50.0 * float(tm.get("_todays_price_drift")) * 0.95)
	t.ok(tm.get_sell_price("turnip", 10, "common") < unpressured,
		"next market day's sell price sits below the no-pressure price")
	t.section_done("supply pressure")


func _test_price_bounds(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var day_holder: Array = parts[3]
	day_holder[0] = 3
	tm.set("_crop_pressure", {"turnip": 100000.0})
	seed(5)
	tm._on_day_passed(3, "spring", 1)
	t.eq(tm.get_supply_multiplier("turnip"), 0.5,
		"extreme oversupply floors the multiplier at 0.5x")
	tm.set("_crop_pressure", {"turnip": -100000.0})
	seed(5)
	tm._on_day_passed(3, "spring", 1)
	t.eq(tm.get_supply_multiplier("turnip"), 1.5,
		"extreme undersupply caps the multiplier at 1.5x")
	var drift: float = tm.get("_todays_price_drift")
	t.eq(tm.get_sell_price("turnip", 10, "common"),
		int(10.0 * 5.0 * 1.5 * drift * 0.95),
		"sell price composes base x quality x supply multiplier x drift x toll")
	t.section_done("price bounds")


func _test_pressure_decays(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var day_holder: Array = parts[3]
	tm.set("_crop_pressure", {"turnip": 100.0})
	day_holder[0] = 1
	tm._on_day_passed(1, "spring", 1)
	t.eq(tm.get_crop_pressure("turnip"), 80.0,
		"pressure decays by the configured 0.2 fraction each night")
	_advance_days(tm, day_holder, [2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12])
	t.ok(tm.get_crop_pressure("turnip") < 10.0,
		"pressure keeps decaying toward zero with no further sales")
	t.section_done("decay")


func _test_orders_generate_on_market_days(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var gd = parts[2]
	var day_holder: Array = parts[3]
	seed(2026)
	day_holder[0] = 3
	tm._on_day_passed(3, "spring", 1)
	var orders: Array[Dictionary] = tm.get_active_orders()
	t.ok(orders.size() >= 1 and orders.size() <= 3,
		"1-3 orders generate on a market day (got %d)" % orders.size())
	for order: Dictionary in orders:
		var crop_id := str(order.get("crop_id", ""))
		var seasons: Array = gd.get_crop(crop_id).get("seasons", [])
		t.ok(seasons.has("spring"), "order for %s is in-season" % crop_id)
		t.ok(int(order.get("quantity", 0)) >= 1, "order quantity is positive")
		t.ok(int(order.get("deadline_day", 0)) >= 3, "order deadline is in the future")
	t.section_done("generation")


## The in-season filter is only observable when the template pool contains
## an out-of-season crop, so the test injects a summer-only cabbage template
## into the real loaded config, then checks Spring never posts it and Summer
## only posts summer-eligible crops.
func _test_in_season_only(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var gd = parts[2]
	var day_holder: Array = parts[3]
	var templates: Array = gd.board_orders_cfg.get("orders", [])
	templates.append({
		"crop_id": "cabbage", "min_quantity": 2, "max_quantity": 4,
		"base_reward_money": 30, "reward_standing": "", "standing_amount": 0,
		"deadline_days": 3, "weight": 100,
	})
	seed(77)
	day_holder[0] = 3
	tm._on_day_passed(3, "spring", 1)
	for order: Dictionary in tm.get_active_orders():
		t.not_ok(str(order.get("crop_id", "")) == "cabbage",
			"summer-only cabbage is never posted during Spring")
	# Drop the Spring orders before the Summer phase - orders persist until
	# their deadline by design, so old spring-only orders would otherwise
	# legitimately still be on the board and trip the in-season check.
	var empty_orders: Array[Dictionary] = []
	tm.set("_active_orders", empty_orders)
	seed(78)
	day_holder[0] = 7
	tm._on_day_passed(7, "summer", 1)
	var summer_orders: Array[Dictionary] = tm.get_active_orders()
	t.ok(not summer_orders.is_empty(), "summer market day still posts orders")
	for order: Dictionary in summer_orders:
		var crop_id := str(order.get("crop_id", ""))
		var seasons: Array = gd.get_crop(crop_id).get("seasons", [])
		t.ok(seasons.has("summer"), "order for %s is summer-eligible" % crop_id)
		t.not_ok(crop_id == "pea", "spring-only pea is never posted in summer")
	t.section_done("in season")


func _test_orders_capped_at_three(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var day_holder: Array = parts[3]
	seed(4242)
	for day: int in [3, 7, 10, 14, 17, 21, 24, 28]:
		day_holder[0] = day
		tm._on_day_passed(day, "spring", 1)
		# Explicit int, not := - tm is an untyped test reference, and
		# GDScript cannot infer through a generic Variant call target.
		var count: int = tm.get_active_orders().size()
		t.ok(count >= 1, "board never empties on a market day (day %d, got %d)" % [day, count])
		t.ok(count <= 3, "active orders capped at 3 (day %d, got %d)" % [day, count])
	t.section_done("cap")


func _test_fulfill_order(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.money = 200
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return 1, null, rep)
	ps.add_item("turnip", 3)
	var order := {
		"id": "test_order_1", "crop_id": "turnip", "quantity": 3,
		"reward_money": 50, "reward_standing": "village", "standing_amount": 5,
		"deadline_day": 10,
	}
	# Typed local, not a bare array literal - assigning an untyped Array to a
	# typed Array[Dictionary] property via set() silently stores nothing.
	var orders: Array[Dictionary] = [order]
	tm.set("_active_orders", orders)
	var fulfilled: Array = []
	tm.order_fulfilled.connect(func(order_id: String, reward: int) -> void:
		fulfilled.append([order_id, reward]))
	t.ok(tm.can_fulfill_order("test_order_1"), "order is fulfillable with goods on hand")
	t.ok(tm.fulfill_order("test_order_1"), "fulfillment succeeds")
	t.eq(ps.get_item_count("turnip"), 0, "order quantity deducted from inventory")
	t.eq(ps.money, 250, "reward coin granted")
	t.eq(rep.get_standing("village"), 5.0, "reward standing applied to the axis")
	t.eq(tm.get_active_orders().size(), 0, "fulfilled order removed")
	t.eq(fulfilled.size(), 1, "order_fulfilled fired exactly once")
	t.eq(int(fulfilled[0][1]), 50, "order_fulfilled carried the reward")
	t.not_ok(tm.can_fulfill_order("test_order_1"), "a removed order cannot be fulfilled twice")
	t.section_done("fulfill")


func _test_fulfill_accepts_any_quality(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	ps.add_item("carrot", 2, "common")
	ps.add_item("carrot", 2, "fine")
	var order := {
		"id": "test_order_2", "crop_id": "carrot", "quantity": 3,
		"reward_money": 40, "reward_standing": "", "standing_amount": 0,
		"deadline_day": 10,
	}
	var orders: Array[Dictionary] = [order]
	tm.set("_active_orders", orders)
	t.ok(tm.can_fulfill_order("test_order_2"),
		"mixed-quality stock satisfies a quality-agnostic order")
	t.ok(tm.fulfill_order("test_order_2"), "fulfillment deducts across quality stacks")
	t.eq(ps.get_item_count("carrot"), 1, "3 carrots deducted across stacks (1 left)")
	t.eq(ps.get_quality_count("carrot", "fine"), 1, "deduction drained common first")
	t.section_done("any quality")


func _test_order_expires_no_penalty(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var day_holder: Array = parts[3]
	var order := {
		"id": "test_order_3", "crop_id": "onion", "quantity": 2,
		"reward_money": 40, "reward_standing": "", "standing_amount": 0,
		"deadline_day": 5,
	}
	var orders: Array[Dictionary] = [order]
	tm.set("_active_orders", orders)
	ps.add_item("onion", 2)
	day_holder[0] = 6
	tm._on_day_passed(6, "spring", 1)
	t.eq(tm.get_active_orders().size(), 0, "order past its deadline expired")
	t.eq(ps.get_item_count("onion"), 2, "expiry consumes no inventory")
	t.eq(ps.money, 200, "expiry pays no reward")
	t.not_ok(tm.can_fulfill_order("test_order_3"), "expired order cannot be fulfilled")
	t.section_done("expiry")


func _test_save_roundtrip(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	var gd = parts[2]
	var order := {
		"id": "test_order_4", "crop_id": "leek", "quantity": 4,
		"reward_money": 78, "reward_standing": "church", "standing_amount": 4,
		"deadline_day": 8,
	}
	tm.set("_crop_pressure", {"turnip": 42.0})
	var orders: Array[Dictionary] = [order]
	tm.set("_active_orders", orders)
	var dumped: Dictionary = tm.serialize()
	t.eq((dumped.get("crop_pressure", {}) as Dictionary).get("turnip", -1.0), 42.0,
		"serialize carries crop_pressure")
	t.eq((dumped.get("active_orders", []) as Array).size(), 1,
		"serialize carries active_orders")
	var restored = TITHE_SCRIPT.new()
	restored.configure_for_test(ps, gd, func() -> int: return 1)
	restored.deserialize(dumped)
	t.eq(restored.get_crop_pressure("turnip"), 42.0, "crop_pressure round-trips")
	t.ok(restored.get_supply_multiplier("turnip") < 1.0,
		"today's multiplier rebuilds from restored pressure on load")
	var restored_orders: Array[Dictionary] = restored.get_active_orders()
	t.eq(restored_orders.size(), 1, "active_orders round-trips")
	t.eq(str(restored_orders[0].get("id", "")), "test_order_4", "order id round-trips")
	t.eq(int(restored_orders[0].get("quantity", 0)), 4, "order quantity round-trips")
	t.eq(int(restored_orders[0].get("deadline_day", 0)), 8, "order deadline round-trips")
	t.eq(str(restored_orders[0].get("reward_standing", "")), "church",
		"order standing reward round-trips")
	t.section_done("save roundtrip")


## E6/ADR-037 display fix: GameData.format_produce_count() produces count-
## aware, unit-bearing strings for the board panel ("a bushel of peas" /
## "4 bushels of peas") instead of the old bare "4 Pea". Covers singular vs
## plural, irregular measure plurals, mass-noun crops, and unknown ids.
func _test_produce_count_formatting(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.eq(gd.format_produce_count("pea", 4), "4 bushels of peas",
		"plural measure + plural crop (pea)")
	t.eq(gd.format_produce_count("pea", 1), "a bushel of peas",
		"singular measure with article (pea)")
	t.eq(gd.format_produce_count("turnip", 5), "5 baskets of turnips",
		"basket pluralizes plainly")
	t.eq(gd.format_produce_count("turnip", 1), "a basket of turnips",
		"singular basket reads naturally")
	t.eq(gd.format_produce_count("barley", 3), "3 sheaves of barley",
		"sheaf pluralizes to sheaves")
	t.eq(gd.format_produce_count("barley", 1), "a sheaf of barley",
		"mass-noun crop name stays singular")
	t.eq(gd.format_produce_count("carrot", 2), "2 bunches of carrots",
		"bunch pluralizes to bunches")
	t.eq(gd.format_produce_count("leek", 4), "4 hands of leeks",
		"hand stays a plain plural")
	t.eq(gd.format_produce_count("oat", 6), "6 sacks of oats",
		"already-plural crop name stays oats")
	t.eq(gd.format_produce_count("flax", 1), "a bundle of flax",
		"mass-noun flax stays flax")
	t.eq(gd.format_produce_count("onion", 1), "a bag of onions",
		"bag reads naturally")
	t.eq(gd.format_produce_count("cabbage", 1), "a head of cabbage",
		"summer-locked cabbage still formats")
	t.eq(gd.format_produce_count("not_a_crop", 3), "",
		"unknown crop degrades to empty string")
	var missing: Array[String] = []
	for crop_id: String in gd.get_all_crop_ids():
		if str(gd.get_crop(crop_id).get("measure", "")).is_empty():
			missing.append(crop_id)
	t.ok(missing.is_empty(), "every crop defines a measure (%s)" % ", ".join(missing))
	t.section_done("produce count formatting")
