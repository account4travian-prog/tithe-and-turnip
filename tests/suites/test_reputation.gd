extends RefCounted
## ReputationManager coverage: standings, clamping, labels, action effects,
## opinion deltas, save roundtrip, and reputation-aware dialogue selection.

const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "reputation"


func run(t: Object) -> void:
	_test_basics_and_clamping(t)
	_test_actions(t)
	_test_labels(t)
	_test_save_roundtrip(t)
	_test_dialogue(t)
	t.completed(5)


func _make() -> Object:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var rm = REPUTATION_SCRIPT.new()
	rm.configure_for_test(gd)
	rm.reset_all()
	return rm


func _test_basics_and_clamping(t: Object) -> void:
	var rm = _make()
	t.eq(rm.get_standing("manor"), 0.0, "standings start at 0")
	t.eq(rm.get_standing("village"), 0.0, "village starts at 0")
	t.eq(rm.get_standing("church"), 0.0, "church starts at 0")
	rm.modify_standing("village", 30.0)
	t.eq(rm.get_standing("village"), 30.0, "standing modifies")
	rm.modify_standing("manor", 150.0)
	t.eq(rm.get_standing("manor"), 100.0, "standing clamps to +100")
	rm.modify_standing("church", -200.0)
	t.eq(rm.get_standing("church"), -100.0, "standing clamps to -100")
	rm.modify_opinion("steward", -20.0)
	t.eq(rm.get_opinion("steward"), -20.0, "opinion modifies")
	t.eq(rm.get_opinion("ghost"), 0.0, "unknown npc opinion defaults to 0")
	t.section_done("basics")


func _test_actions(t: Object) -> void:
	var rm = _make()
	rm.apply_action("pay_tithe_fully")
	t.eq(rm.get_standing("manor"), 2.0, "pay_tithe_fully raises manor")
	t.eq(rm.get_standing("church"), 1.0, "pay_tithe_fully raises church")
	rm.reset_all()
	rm.apply_action("attack_villager", "villager_1")
	t.eq(rm.get_standing("manor"), -5.0, "attack hits manor")
	t.eq(rm.get_standing("village"), -10.0, "attack hits village")
	t.eq(rm.get_opinion("villager_1"), -30.0, "attack drops victim opinion")
	rm.reset_all()
	rm.apply_action("complete_labor_day")
	rm.apply_action("complete_labor_day")
	t.eq(rm.get_standing("manor"), 4.0, "labor days stack")
	t.eq(rm.get_standing("village"), 2.0, "labor days raise village")
	rm.reset_all()
	rm.apply_action("church_donation_large")
	t.eq(rm.get_standing("church"), 5.0, "large donation raises church")
	t.eq(rm.get_standing("village"), 1.0, "large donation raises village slightly")
	rm.reset_all()
	rm.apply_action("market_trade")
	t.eq(rm.get_standing("manor"), 1.0, "market trade raises manor")
	t.section_done("actions")


func _test_labels(t: Object) -> void:
	var rm = _make()
	t.eq(rm.get_standing_label("village"), "neutral", "0 is neutral")
	rm.modify_standing("village", -10.0)
	t.eq(rm.get_standing_label("village"), "cold", "-10 is cold")
	rm.reset_all()
	rm.modify_standing("village", -9.0)
	t.eq(rm.get_standing_label("village"), "neutral", "-9 is neutral")
	rm.reset_all()
	rm.modify_standing("village", 50.0)
	t.eq(rm.get_standing_label("village"), "friendly", "50 is friendly")
	t.section_done("labels")


func _test_save_roundtrip(t: Object) -> void:
	var rm = _make()
	rm.modify_standing("manor", 7.0)
	rm.modify_opinion("steward", 12.0)
	var saved: Dictionary = rm.get_save_data()
	rm.reset_all()
	rm.load_save_data(saved)
	t.eq(rm.get_standing("manor"), 7.0, "standing restored")
	t.eq(rm.get_opinion("steward"), 12.0, "opinion restored")
	t.section_done("save")


func _test_dialogue(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var neutral_lines: Array = gd.get_dialogue_for("steward", {"manor": 0.0, "village": 0.0, "church": 0.0})
	t.eq(neutral_lines.size(), 4, "neutral manor matches neutral/cold/hostile bands + fallback (4)")
	t.eq(str(neutral_lines[0]), "Work hard and you may eat.", "neutral manor picks the neutral band line first")
	var warm_lines: Array = gd.get_dialogue_for("steward", {"manor": 70.0, "village": 0.0, "church": 0.0})
	t.eq(warm_lines.size(), 6, "high manor matches all six band + fallback lines")
	t.eq(str(warm_lines[0]), "The lord himself has heard your name spoken well.", "high manor picks the friendly line first")
	t.section_done("dialogue")
