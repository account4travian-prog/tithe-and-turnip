extends RefCounted
## TitheManager church-donation coverage: coin/crop donations, guards, and
## independence from the lord tithe.

const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

var _donations: Array = []


func suite_name() -> String:
	return "church"


func run(t: Object) -> void:
	_test_coin_donation(t)
	_test_crop_donation(t)
	_test_guards(t)
	t.completed(3)


func _make() -> Array:
	var ps = PLAYER_SCRIPT.new()
	ps.money = 50
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return 1)
	_donations = []
	tm.donation_made.connect(_on_donation)
	return [tm, ps]


func _test_coin_donation(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	t.ok(tm.can_donate_coin(10), "can donate 10 coin")
	t.ok(tm.donate_coin(10), "donation succeeds")
	t.eq(ps.money, 40, "money deducted")
	t.eq(_donations.size(), 1, "donation signal emitted")
	t.eq(_donations[0], ["coin", 10.0], "signal carries type and value")
	t.section_done("coin")


func _test_crop_donation(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	ps.add_item("turnip", 3)
	t.ok(tm.can_donate_crops("turnip", 3, "common"), "can donate 3 turnips")
	t.ok(tm.donate_crops("turnip", 3, "common"), "crop donation succeeds")
	t.eq(ps.get_item_count("turnip"), 0, "crops removed")
	t.eq(_donations.size(), 1, "crop donation signal emitted")
	t.eq(_donations[0], ["crops", 15.0], "value is 3*5")
	t.section_done("crops")


func _test_guards(t: Object) -> void:
	var parts := _make()
	var tm = parts[0]
	var ps = parts[1]
	ps.money = 0
	t.not_ok(tm.can_donate_coin(1), "cannot donate without money")
	t.not_ok(tm.donate_coin(1), "donation fails without money")
	t.not_ok(tm.can_donate_crops("turnip", 1, "common"), "cannot donate unowned crops")
	t.not_ok(tm.donate_crops("turnip", 1, "common"), "crop donation fails without crops")
	t.eq(float(tm.get_tithe_progress().get("paid", 0.0)), 0.0, "donations never touch tithe")
	t.section_done("guards")


func _on_donation(type: String, value: float) -> void:
	_donations.append([type, value])
