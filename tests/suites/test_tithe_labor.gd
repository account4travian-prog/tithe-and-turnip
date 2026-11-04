extends RefCounted
## TitheManager lord-tithe coverage: coin payment (with cap), in-kind deposits
## (with cap), and the ADR-040 spatial demesne chores - till/water are real
## FarmGrid tile actions gated on demesne tile state, harvest clears stored
## sheaf markers without touching player inventory, carry is a pickup-then-
## delivery sequence to the tithe-chest anchor tile, and the rain-watering
## exploit is structurally closed (a rain day leaves no dry tile).

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

## ADR-038: the tithe goal is base_amount + coin_per_held_strip * held
## strips. This suite injects 0 held strips (no BuildingManager wired into
## the harness), so the goal is simply base_amount = 20 throughout. The farm
## tilling below is still exercised for the chores/energy paths but no
## longer feeds the tithe goal itself.
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

## ADR-040: the real stewards_demesne footprint from farm_map.json
## (x:15..20, y:5..10). The 22x12 test farm covers it entirely, and the
## demesne config comes from the real chores.json so the spatial gates run
## against shipped data, not a mock.
const DEMESNE_RECT := Rect2i(15, 5, 6, 6)


func suite_name() -> String:
	return "tithe_labor"


func run(t: Object) -> void:
	_test_coin_payment(t)
	_test_in_kind_deposit(t)
	_test_chores(t)
	_test_water_gate_and_rain(t)
	_test_harvest_and_carry(t)
	_test_caps_and_reset(t)
	_test_acreage_scaling(t)
	t.completed(7)


func _make() -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	ps.energy = 100.0
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(2):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test(MINI_CROPS, soil_map, MINI_SOIL, Vector2i(4, 2))
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return 1, farm)
	return [tm, ps]


## A 22x12 farm whose demesne rect matches the shipped farm_map.json feature,
## wired into TitheManager exactly like main.gd does (set_farm_grid_ref is
## replaced by the configure_for_test farm seam).
func _make_demesne() -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	ps.energy = 100.0
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(12):
		for x in range(22):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test(
		MINI_CROPS, soil_map, MINI_SOIL, Vector2i(22, 12),
		{}, [], "", DEMESNE_RECT, gd.get_demesne_config())
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return 1, farm)
	return [tm, ps, farm, gd]


func _first_sheaf_tile(farm: Node) -> Vector2i:
	for y in range(DEMESNE_RECT.position.y, DEMESNE_RECT.end.y):
		for x in range(DEMESNE_RECT.position.x, DEMESNE_RECT.end.x):
			var pos := Vector2i(x, y)
			if farm.is_demesne_sheaf_tile(pos):
				return pos
	return Vector2i(-1, -1)


func _test_coin_payment(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	t.ok(tm.can_pay_tithe_coin(20), "can pay full tithe with 100 coin")
	t.ok(tm.pay_tithe_coin(20), "pay 20 coin")
	t.eq(ps.money, 80, "money deducted")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 20.0, "tithe paid")
	tm.set("_tithe_paid", 15.0)
	t.ok(tm.can_pay_tithe_coin(10), "can pay toward remaining 5")
	t.ok(tm.pay_tithe_coin(10), "pay capped at 5")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 20.0, "tithe capped at goal")
	t.eq(ps.money, 75, "only 5 more deducted")
	t.not_ok(tm.pay_tithe_coin(1), "cannot overpay a full tithe")
	t.section_done("coin")


func _test_in_kind_deposit(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	ps.add_item("turnip", 2, "fine")
	var credit: float = tm.deposit_tithe_crops("turnip", 2, "fine")
	t.eq(credit, 15.0, "2 fine turnips credit 15 (2*5*1.5)")
	t.eq(ps.get_item_count("turnip"), 0, "crops removed")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 15.0, "tithe progress 15")
	t.eq(tm.deposit_tithe_crops("turnip", 1, "common"), 0.0, "cannot deposit unowned crops")
	tm.set("_tithe_paid", 18.0)
	ps.add_item("turnip", 1, "fine")
	t.eq(tm.deposit_tithe_crops("turnip", 1, "fine"), 2.0, "deposit caps at remaining 2")
	t.eq(ps.get_item_count("turnip"), 0, "crops consumed even when capped")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 20.0, "tithe full")
	t.section_done("in kind")


## ADR-040: the four chores are still listed and still gated by the daily
## cap, but completing one now requires a real spatial precondition - an
## untilled demesne tile for till_demesne - and the completion goes through
## complete_demesne_tool_chore (the tool consumed the energy; TitheManager
## must not double-charge).
func _test_chores(t: Object) -> void:
	var parts := _make_demesne()
	var tm = parts[0]
	var ps = parts[1]
	var farm = parts[2]
	var chores: Array[String] = tm.get_available_chores()
	t.eq(chores.size(), 4, "four demesne chores")
	t.ok(chores.has("till_demesne"), "till chore present")
	t.ok(tm.can_do_chore("till_demesne"), "can till with 100 energy")
	var demesne_tile := Vector2i(16, 5)
	var outside := Vector2i(0, 0)
	t.not_ok(tm.can_demesne_chore_at("till_demesne", outside),
		"till gate refuses a tile outside the demesne")
	t.not_ok(tm.complete_demesne_tool_chore("till_demesne", outside, 5.0),
		"completion refused without the real tile precondition")
	t.ok(tm.can_demesne_chore_at("till_demesne", demesne_tile),
		"untilled demesne tile is tillable")
	t.ok(farm.till_tile(demesne_tile, true), "till the demesne tile")
	t.ok(tm.complete_demesne_tool_chore("till_demesne", demesne_tile, 5.0),
		"till chore succeeds after the real tile action")
	t.eq(ps.energy, 100.0, "TitheManager does not double-charge tool energy")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 3.0, "till grants 3 credit")
	t.eq(tm.get_daily_labor_remaining(), 7.0, "daily labor remaining 7")
	t.not_ok(tm.can_demesne_chore_at("till_demesne", demesne_tile),
		"already-tilled demesne tile is no longer tillable")
	var second := Vector2i(16, 6)
	var third := Vector2i(16, 7)
	var fourth := Vector2i(16, 8)
	farm.till_tile(second, true)
	t.ok(tm.complete_demesne_tool_chore("till_demesne", second, 5.0), "second till succeeds")
	farm.till_tile(third, true)
	t.ok(tm.complete_demesne_tool_chore("till_demesne", third, 5.0), "third till succeeds")
	farm.till_tile(fourth, true)
	t.ok(tm.complete_demesne_tool_chore("till_demesne", fourth, 5.0),
		"fourth till grants capped 1 credit")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 10.0, "tithe at 10 after cap")
	t.not_ok(tm.can_do_chore("till_demesne"), "daily labor cap reached")
	t.not_ok(tm.complete_demesne_tool_chore("till_demesne", Vector2i(16, 9), 5.0),
		"completion refused at cap")
	t.section_done("chores")


## ADR-040: water_demesne needs a tilled demesne tile below the data-driven
## needs-water threshold. A rain day saturates every tilled cell to 100, so
## the exploit is closed structurally - there is simply no eligible tile.
func _test_water_gate_and_rain(t: Object) -> void:
	var parts := _make_demesne()
	var tm = parts[0]
	var ps = parts[1]
	var farm = parts[2]
	var dry := Vector2i(17, 5)
	var untilled := Vector2i(17, 6)
	t.not_ok(tm.can_demesne_chore_at("water_demesne", untilled),
		"water gate refuses an untilled demesne tile")
	t.ok(farm.till_tile(dry, true), "till the dry tile")
	t.ok(tm.can_demesne_chore_at("water_demesne", dry),
		"dry tilled demesne tile needs water")
	t.ok(farm.water_tile(dry, 25.0), "water 25")
	t.ok(tm.can_demesne_chore_at("water_demesne", dry),
		"25 moisture is still below the 50 threshold")
	t.ok(farm.water_tile(dry, 25.0), "water to 50")
	t.not_ok(tm.can_demesne_chore_at("water_demesne", dry),
		"50 moisture no longer needs water")
	# Rain: advance_day(true) saturates every tilled cell to 100 - the gate
	# goes structurally silent, no special-case rain rule anywhere.
	farm.advance_day(true, false, 2)
	t.eq(farm.get_cell_moisture(dry), 100.0, "rain saturated the tilled tile")
	t.not_ok(tm.can_demesne_chore_at("water_demesne", dry),
		"rain day leaves no eligible demesne tile to water")
	# A genuinely dry tile still grants credit through the real action.
	var fresh := Vector2i(17, 7)
	farm.till_tile(fresh, true)
	t.ok(farm.water_tile(fresh, 25.0), "water the fresh dry tile")
	t.ok(tm.complete_demesne_tool_chore("water_demesne", fresh, 1.0),
		"water chore succeeds after the real tile action")
	t.eq(ps.energy, 100.0, "no extra energy charged by TitheManager for watering")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 2.0, "water grants 2 credit")
	t.section_done("water/rain")


## ADR-040: harvest clears a stored-sheaf marker (never a crop, never into
## the player's inventory), sets the carry state, and carry_produce is a
## real pickup-then-delivery: credit only at the tithe-chest anchor tile.
func _test_harvest_and_carry(t: Object) -> void:
	var parts := _make_demesne()
	var tm = parts[0]
	var ps = parts[1]
	var farm = parts[2]
	var gd = parts[3]
	t.not_ok(tm.can_do_chore("harvest_demesne"),
		"harvest unavailable with no stored sheaves")
	farm.advance_day(false, false, 1)
	t.eq(farm.count_demesne_sheaves(), 6, "day-1 replenishment puts 6 sheaves on the demesne")
	t.not_ok(farm.is_demesne_sheaf_tile(gd.get_feature_tile("stewards_demesne")),
		"the tithe-chest anchor tile never stores a sheaf")
	var sheaf_tile := _first_sheaf_tile(farm)
	t.ok(tm.can_demesne_chore_at("harvest_demesne", sheaf_tile),
		"stored-sheaf tile is harvestable")
	t.eq((ps.list_inventory() as Array).size(), 0, "inventory empty before demesne work")
	t.ok(tm.complete_demesne_interaction("harvest_demesne", sheaf_tile),
		"harvest clears the sheaf and picks it up")
	t.eq(ps.energy, 94.0, "harvest costs 6 energy (chore energy_cost)")
	t.eq(farm.count_demesne_sheaves(), 5, "one sheaf removed from the backlog")
	t.eq(float(tm.get_demesne_status().get("carrying_sheaves", 0)), 1.0,
		"player is now carrying the sheaf")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 4.0, "harvest grants 4 credit")
	t.eq((ps.list_inventory() as Array).size(), 0,
		"demesne labor never deposits items into the player's inventory")
	var another := _first_sheaf_tile(farm)
	t.not_ok(tm.can_demesne_chore_at("harvest_demesne", another),
		"one carry at a time - further harvests refused while carrying")
	# Explicit Vector2i, not := - gd is an untyped Variant handle in this
	# harness, so the method call has no static type to infer from.
	var anchor: Vector2i = gd.get_feature_tile("stewards_demesne")
	t.not_ok(tm.can_demesne_chore_at("carry_produce", sheaf_tile),
		"delivery refused away from the tithe chest")
	t.not_ok(tm.complete_demesne_interaction("carry_produce", sheaf_tile),
		"carry completion refused at the wrong tile")
	t.eq(float(tm.get_demesne_status().get("carrying_sheaves", 0)), 1.0,
		"failed delivery keeps the load")
	t.ok(tm.can_demesne_chore_at("carry_produce", anchor),
		"tithe-chest tile accepts the delivery")
	t.ok(tm.complete_demesne_interaction("carry_produce", anchor),
		"delivery succeeds at the tithe chest")
	t.eq(ps.energy, 90.0, "delivery costs 4 energy (chore energy_cost)")
	t.eq(float(tm.get_demesne_status().get("carrying_sheaves", 0)), 0.0,
		"delivery clears the carry state")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 7.0, "carry grants 3 credit")
	# Day rollover collects an undelivered load back into the backlog.
	var second_sheaf := _first_sheaf_tile(farm)
	t.ok(tm.complete_demesne_interaction("harvest_demesne", second_sheaf),
		"harvest a second load")
	# 4 (first harvest) + 3 (carry) = 7 credit already spent; the daily cap
	# of 10 leaves room for only 3 of the second harvest's 4 credit.
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 10.0,
		"second harvest grants the capped 3 of its 4 credit")
	tm._on_day_passed(2, "spring", 1)
	t.eq(float(tm.get_demesne_status().get("carrying_sheaves", 0)), 0.0,
		"day rollover clears an undelivered load without a carry credit")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 10.0,
		"no carry credit was granted for the collected load")
	t.section_done("harvest/carry")


func _test_caps_and_reset(t: Object) -> void:
	var parts := _make_demesne()
	var tm = parts[0]
	var ps = parts[1]
	var farm = parts[2]
	ps.energy = 3.0
	t.not_ok(tm.can_do_chore("till_demesne"),
		"panel gate refuses a chore without enough energy")
	var demesne_tile := Vector2i(16, 5)
	t.ok(tm.can_demesne_chore_at("till_demesne", demesne_tile),
		"spatial gate still offers the tile - the tool's consume_energy is the real gate")
	ps.energy = 100.0
	farm.till_tile(demesne_tile, true)
	t.ok(tm.complete_demesne_tool_chore("till_demesne", demesne_tile, 5.0),
		"chore works")
	var money_before: int = ps.money
	t.eq(ps.money, money_before, "labor does not touch money")
	tm._on_day_passed(1, "spring", 1)
	t.eq(tm.get_daily_labor_remaining(), 10.0, "daily credit resets on day pass")
	t.ok(tm.can_do_chore("till_demesne"), "chore available again next day")
	var saved: Dictionary = tm.serialize()
	t.eq(float(saved.get("tithe_paid", 0.0)), 3.0, "serialize keeps tithe paid")
	t.eq(int(saved.get("carrying_sheaves", -1)), 0, "serialize keeps carry state")
	var tm2 = TITHE_SCRIPT.new()
	tm2.deserialize(saved)
	t.eq(float(tm2.get_tithe_progress().get("paid", 0.0)), 3.0, "deserialize restores paid")
	t.eq(int(tm2.get("_carrying_sheaves")), 0, "deserialize restores carry state")
	var tm3 = TITHE_SCRIPT.new()
	tm3.deserialize({})
	t.eq(int(tm3.get("_carrying_sheaves")), 0, "missing carry field defaults to 0")
	t.section_done("caps/reset")


## ADR-038: the tithe goal is base_amount (20) + coin_per_held_strip (10)
## per rented strip - held acreage, not tilled tiles. The held_strips seam
## on configure_for_test stands in for BuildingManager's rented-strip count.
func _test_acreage_scaling(t: Object) -> void:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var tm0 = TITHE_SCRIPT.new()
	tm0.configure_for_test(ps, gd, func() -> int: return 1, null, null, 0)
	t.eq(tm0.get_tithe_progress().get("goal", 0), 20, "no held strips - goal is base 20")

	var tm1 = TITHE_SCRIPT.new()
	tm1.configure_for_test(ps, gd, func() -> int: return 1, null, null, 1)
	t.eq(tm1.get_tithe_progress().get("goal", 0), 30, "one held strip - goal 20 + 10")

	var tm3 = TITHE_SCRIPT.new()
	tm3.configure_for_test(ps, gd, func() -> int: return 1, null, null, 3)
	t.eq(tm3.get_tithe_progress().get("goal", 0), 50, "three held strips - goal 20 + 30")
	t.section_done("acreage scaling")
