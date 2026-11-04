extends RefCounted
## Marriage system coverage (ADR-031, realized): proposal gating, merchet
## payment, ceremony, the spouse gift-cap bypass, reputation transfer, the
## waking greeting, the farm chore, save roundtrip, and the marriage-stops-
## Marta's-scripted-theft guard (world_bible.md Block 8.4).

const MARRIAGE_SCRIPT := preload("res://scripts/autoloads/marriage_manager.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const RAID_SCRIPT := preload("res://scripts/autoloads/raid_manager.gd")
const TIME_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}


func suite_name() -> String:
	return "marriage"


func run(t: Object) -> void:
	_test_propose_gating(t)
	_test_propose_consumes_ring(t)
	_test_merchet(t)
	_test_ceremony(t)
	_test_waking_greeting(t)
	_test_chore(t)
	_test_spouse_gift_cap(t)
	_test_reputation_transfer(t)
	_test_serialize_roundtrip(t)
	_test_marta_theft_suppressed(t)
	t.completed(10)


func _make() -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.money = 100
	var rm = REPUTATION_SCRIPT.new()
	var mm = MARRIAGE_SCRIPT.new()
	# Both managers reach across to each other (rm needs mm for the spouse
	# gift-cap bypass; mm needs rm for the reputation-transfer call), so both
	# are constructed first and wired afterward rather than configured in a
	# single pass.
	rm.configure_for_test(gd, ps, mm)
	mm.configure_for_test(gd, ps, null, rm, func() -> int: return 1)
	rm.reset_all()
	return {"mm": mm, "rm": rm, "ps": ps, "gd": gd}


func _test_propose_gating(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	t.not_ok(mm.can_propose("villager_1"), "cannot propose without the ring")
	ps.add_item("betrothal_ring", 1)
	t.not_ok(mm.can_propose("villager_1"), "cannot propose below the opinion threshold")
	rm.modify_opinion("villager_1", 50.0)
	t.ok(mm.can_propose("villager_1"), "can propose at threshold with the ring")
	t.not_ok(mm.can_propose("steward"), "the steward is not a marriage candidate")
	t.not_ok(mm.can_propose("villager_6"), "the miller (villager_6) is not a marriage candidate")
	t.section_done("propose gating")


func _test_propose_consumes_ring(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	t.ok(mm.propose("villager_1"), "propose succeeds")
	t.not_ok(ps.has_item("betrothal_ring", 1), "the ring is consumed")
	t.eq(mm.get_pending_candidate(), "villager_1", "pending candidate recorded")
	t.not_ok(mm.can_propose("villager_2"), "cannot propose to a second candidate while one is pending")
	t.section_done("propose consumes ring")


func _test_merchet(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	t.not_ok(mm.can_pay_merchet(), "cannot pay merchet before a proposal is pending")
	mm.propose("villager_1")
	t.eq(mm.get_merchet_fee(), 25, "merchet fee reads from tithe.json")
	t.ok(mm.can_pay_merchet(), "can pay merchet with 100 coin")
	t.ok(mm.pay_merchet(), "merchet paid")
	t.eq(ps.money, 75, "exactly the fee was deducted")
	t.not_ok(mm.can_pay_merchet(), "cannot pay the merchet twice")
	t.section_done("merchet")


func _test_ceremony(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	t.not_ok(mm.can_ceremonize(), "cannot ceremonize with no pending proposal")
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	mm.propose("villager_1")
	t.not_ok(mm.can_ceremonize(), "cannot ceremonize before the merchet is paid")
	mm.pay_merchet()
	t.ok(mm.can_ceremonize(), "can ceremonize once proposed and merchet-paid")
	t.ok(mm.ceremonize(), "ceremony succeeds")
	t.eq(mm.get_spouse_id(), "villager_1", "spouse recorded")
	t.ok(mm.is_spouse("villager_1"), "is_spouse true for the new spouse")
	t.not_ok(mm.is_spouse("villager_2"), "is_spouse false for anyone else")
	t.eq(mm.get_pending_candidate(), "", "pending candidate cleared")
	t.not_ok(mm.can_ceremonize(), "cannot ceremonize a second time")
	t.section_done("ceremony")


func _test_waking_greeting(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	t.eq(mm.get_waking_greeting(), "", "no greeting while unmarried")
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	mm.propose("villager_1")
	mm.pay_merchet()
	mm.ceremonize()
	var first: String = mm.get_waking_greeting()
	t.ok(not first.is_empty(), "a greeting is returned once married")
	t.eq(mm.get_waking_greeting(), "", "no second greeting the same day")
	t.section_done("waking greeting")


func _test_chore(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	var gd = env["gd"]
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(4):
		for x in range(4):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test(gd.crops, soil_map, SOIL_PROPS, Vector2i(4, 4))
	farm.till_tile(Vector2i(0, 0))
	farm.till_tile(Vector2i(1, 0))
	mm.set_farm_grid_ref(farm)
	t.not_ok(mm.complete_chore(), "no chore while unmarried")
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	mm.propose("villager_1")
	mm.pay_merchet()
	mm.ceremonize()
	t.ok(mm.complete_chore(), "chore succeeds once married with tilled cells present")
	t.section_done("chore")


func _test_spouse_gift_cap(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_1", 50.0)
	mm.propose("villager_1")
	mm.pay_merchet()
	mm.ceremonize()
	ps.add_item("wild_berry", 4)
	# marriage.json's spouse_daily_gift_cap is 1 - the spouse draws from a
	# separate one-a-day pool, not an unlimited one. "Outside the normal
	# cap" means that pool doesn't touch the shared daily cap everyone else
	# draws from, not that the spouse can be gifted twice.
	t.ok(rm.gift_item("villager_1", "wild_berry"), "gift to the spouse succeeds")
	t.ok(rm.gift_item("villager_2", "wild_berry"),
		"an ordinary villager's gift also succeeds the same day - the shared cap was untouched by the spouse gift")
	t.not_ok(rm.gift_item("villager_4", "wild_berry"), "a second ordinary villager hits the now-spent shared cap")
	t.not_ok(rm.gift_item("villager_1", "wild_berry"), "the spouse's own cap (1/day) also limits to one gift")
	t.section_done("spouse gift cap")


func _test_reputation_transfer(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	# Hilda's (villager_1) recorded opinion of the player, and the priest's
	# opinion of Hilda as spouse (marriage.json seeds "priest->villager_1": 60,
	# well above priest's opinion of the player, which stays untouched here).
	rm.modify_opinion("villager_1", 50.0)
	rm.modify_opinion("priest", -20.0)
	ps.add_item("betrothal_ring", 1)
	mm.propose("villager_1")
	mm.pay_merchet()
	mm.ceremonize()
	t.eq(rm.get_opinion("priest"), 5.0, "priest's opinion of the player softened 25 toward his opinion of the new spouse")
	t.section_done("reputation transfer")


func _test_serialize_roundtrip(t: Object) -> void:
	var env := _make()
	var mm = env["mm"]
	var rm = env["rm"]
	var ps = env["ps"]
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_2", 50.0)
	mm.propose("villager_2")
	mm.pay_merchet()
	mm.ceremonize()
	var saved: Dictionary = mm.serialize()
	t.eq(str(saved.get("spouse_id", "")), "villager_2", "serialize keeps spouse_id")
	var mm2 = MARRIAGE_SCRIPT.new()
	mm2.deserialize(saved)
	t.eq(mm2.get_spouse_id(), "villager_2", "deserialize restores spouse_id")
	t.ok(mm2.is_married(), "deserialize restores married state")
	t.section_done("serialize roundtrip")


func _test_marta_theft_suppressed(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.money = 50
	var rm = REPUTATION_SCRIPT.new()
	var mm = MARRIAGE_SCRIPT.new()
	rm.configure_for_test(gd, ps, mm)
	mm.configure_for_test(gd, ps, null, rm, func() -> int: return 1)
	rm.reset_all()
	ps.add_item("betrothal_ring", 1)
	rm.modify_opinion("villager_3", 50.0)
	mm.propose("villager_3")
	mm.pay_merchet()
	mm.ceremonize()
	t.ok(mm.is_spouse("villager_3"), "precondition: Marta is the spouse")

	var raid = RAID_SCRIPT.new()
	raid.configure_for_test(ps, gd, null, mm)
	var money_before: int = ps.money
	raid._on_day_passed(19, "spring", 1)
	t.eq(ps.money, money_before, "no coin lost - the scripted theft did not fire")
	t.eq(ps.theft_events.size(), 0, "no theft event recorded")
	t.section_done("Marta theft suppressed by marriage")
