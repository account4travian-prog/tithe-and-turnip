extends RefCounted
## Gifting coverage: liked/disliked/neutral opinion deltas, item consumption,
## the DAILY_GIFT_CAP with day-passed reset, no-op on missing inventory, and
## the gift_given signal.

const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")


func suite_name() -> String:
	return "gifting"


func run(t: Object) -> void:
	_test_liked(t)
	_test_disliked(t)
	_test_neutral(t)
	_test_daily_cap_and_reset(t)
	_test_missing_item(t)
	_test_signal(t)
	t.completed(6)


func _make() -> Array:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_STATE_SCRIPT.new()
	var rm = REPUTATION_SCRIPT.new()
	rm.configure_for_test(gd, ps)
	rm.reset_all()
	return [rm, ps]


func _test_liked(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	ps.add_item("wild_berry", 1)
	t.ok(rm.gift_item("villager_1", "wild_berry"), "liked gift succeeds")
	t.eq(rm.get_opinion("villager_1"), 10.0, "liked gift raises opinion by 10")
	t.not_ok(ps.has_item("wild_berry", 1), "gifted item is consumed")
	t.section_done("liked")


func _test_disliked(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	ps.add_item("flint", 1)
	t.ok(rm.gift_item("villager_1", "flint"), "disliked gift succeeds")
	t.eq(rm.get_opinion("villager_1"), -6.0, "disliked gift drops opinion by 6")
	t.section_done("disliked")


func _test_neutral(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	ps.add_item("arrow", 1)
	t.ok(rm.gift_item("villager_1", "arrow"), "neutral gift succeeds")
	t.eq(rm.get_opinion("villager_1"), 2.0, "neutral gift uses the +2 default")
	t.section_done("neutral")


func _test_daily_cap_and_reset(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	ps.add_item("turnip", 3)
	t.ok(rm.gift_item("steward", "turnip"), "first gift succeeds")
	t.not_ok(rm.gift_item("steward", "turnip"), "second gift same day hits the cap")
	rm._on_day_passed_village(1, "spring", 1)
	t.ok(rm.gift_item("steward", "turnip"), "gift cap resets on day passed")
	t.section_done("cap")


func _test_missing_item(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	t.not_ok(rm.gift_item("steward", "barley"), "gift with no item fails")
	t.eq(rm.get_opinion("steward"), 0.0, "failed gift changes no opinion")
	t.section_done("missing")


func _test_signal(t: Object) -> void:
	var parts := _make()
	var rm = parts[0]
	var ps = parts[1]
	ps.add_item("wild_berry", 1)
	var seen: Array = []
	rm.gift_given.connect(func(npc_id: String, item_id: String, delta: float) -> void:
		seen.append([npc_id, item_id, delta]))
	rm.gift_item("villager_1", "wild_berry")
	t.eq(seen.size(), 1, "gift_given emitted")
	t.eq(seen[0][2], 10.0, "gift_given carries the delta")
	t.section_done("signal")
