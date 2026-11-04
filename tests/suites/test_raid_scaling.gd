extends RefCounted
## ADR-026 dynamic raid coverage: effective deterrence sums raw value + the
## Sprint 9 fence bonus + owned defense items (presence, not quantity); the
## dynamic trigger respects the earliest day and the deterrence floor; the
## weighted enemy pick is deterministic on zero/full-weight edges; the day-19
## theft resolves the thief from villagers.json traits, not a hardcoded id;
## and the mercy-path event flag suppresses the day-19 theft like the
## marriage guard does.

const RAID_SCRIPT := preload("res://scripts/autoloads/raid_manager.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


class _FakeBuildingManager:
	extends Node

	var bonus := 0

	func get_deterrence_bonus() -> int:
		return bonus


## A GameData stand-in with no thief anywhere - _find_thief_id must return ""
## gracefully instead of erroring.
class _NoThiefGameData:
	extends Node

	func get_all_villager_ids() -> Array:
		return []

	func get_villager(_villager_id: String) -> Dictionary:
		return {}


func suite_name() -> String:
	return "raid_scaling"


func run(t: Object) -> void:
	_test_effective_deterrence(t)
	_test_dynamic_trigger_gates(t)
	_test_weighted_pick(t)
	_test_theft_finds_thief(t)
	_test_mercy_flag_suppresses_theft(t)
	t.completed(5)


func _test_effective_deterrence(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.raid_deterrence = 5
	var rm = RAID_SCRIPT.new()
	rm.configure_for_test(ps, gd)
	t.eq(rm.get_effective_deterrence(), 5, "raw deterrence alone")
	var bm := _FakeBuildingManager.new()
	bm.bonus = 3
	rm.configure_for_test(ps, gd, bm)
	t.eq(rm.get_effective_deterrence(), 8, "raw + fence bonus")
	rm.configure_for_test(ps, gd)
	ps.add_item("guard_dog", 1)
	ps.add_item("hired_guard", 1)
	t.eq(rm.get_effective_deterrence(), 20, "raw + owned defense items")
	rm.configure_for_test(ps, gd, bm)
	t.eq(rm.get_effective_deterrence(), 23, "raw + fence + defense items combined")
	ps.add_item("guard_dog", 1)
	t.eq(rm.get_effective_deterrence(), 23, "second guard dog does not stack")
	t.section_done("effective deterrence")


func _test_dynamic_trigger_gates(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	gd.raids_cfg["dynamic_raid_chance_per_day"] = 1.0  # force the roll
	var ps = PLAYER_SCRIPT.new()
	ps.raid_deterrence = 0
	var rm = RAID_SCRIPT.new()
	rm.configure_for_test(ps, gd)
	var triggered := [0]
	rm.dynamic_raid_triggered.connect(func(_enemy_count: int) -> void:
		triggered[0] += 1)
	rm._maybe_trigger_dynamic_raid(15)
	t.eq(triggered[0], 0, "never triggers before dynamic_raid_earliest_day")
	ps.raid_deterrence = 30
	rm._maybe_trigger_dynamic_raid(16)
	t.eq(triggered[0], 0, "never triggers at or above min_deterrence_no_raid")
	ps.raid_deterrence = 0
	rm._maybe_trigger_dynamic_raid(16)
	t.eq(triggered[0], 1, "forced chance triggers once past the earliest day")
	# The harness has no scene tree, so _spawn_raid returns before setting
	# _raid_active - set it directly to simulate an in-progress raid.
	rm.set("_raid_active", true)
	rm._maybe_trigger_dynamic_raid(17)
	t.eq(triggered[0], 1, "no second raid while a raid is active")
	t.section_done("dynamic trigger gates")


func _test_weighted_pick(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	var rm = RAID_SCRIPT.new()
	rm.configure_for_test(ps, gd)
	var pool := [
		{"type": "bandit_melee", "weight": 0},
		{"type": "raid_leader", "weight": 1},
	]
	t.eq(rm._weighted_pick_enemy(pool), "raid_leader",
		"zero-weight entry never wins against a full-weight entry")
	t.eq(rm._weighted_pick_enemy([]), "", "empty pool picks nothing")
	t.eq(rm._weighted_pick_enemy([
		{"type": "bandit_melee", "weight": 0},
		{"type": "bandit_archer", "weight": 0},
	]), "", "all-zero pool picks nothing")
	t.section_done("weighted pick")


func _test_theft_finds_thief(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	var rm = RAID_SCRIPT.new()
	rm.configure_for_test(ps, gd)
	rm.execute_theft()
	var event: Dictionary = (ps.theft_events as Array)[0]
	t.eq(str(event.get("villager_id", "")), "villager_3",
		"thief resolved from villagers.json traits, not a hardcoded id")
	t.eq(ps.money, 70, "theft removes 30 coin")
	t.eq(int(event.get("coin_stolen", -1)), 30, "theft event records the loss")
	var poor_ps = PLAYER_SCRIPT.new()
	poor_ps.money = 0
	var rm2 = RAID_SCRIPT.new()
	rm2.configure_for_test(poor_ps, gd)
	rm2.execute_theft()
	t.eq(poor_ps.money, 0, "theft never takes the player below zero")
	var fake := _NoThiefGameData.new()
	var rm3 = RAID_SCRIPT.new()
	rm3.configure_for_test(ps, fake)
	rm3.execute_theft()
	var no_thief_event: Dictionary = (ps.theft_events as Array)[1]
	t.eq(str(no_thief_event.get("villager_id", "x")), "",
		"no thief in data resolves to an empty id without erroring")
	t.section_done("theft thief lookup")


func _test_mercy_flag_suppresses_theft(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	var rm = RAID_SCRIPT.new()
	rm.configure_for_test(ps, gd)
	ps.set_event_flag("investigation.showed_mercy_villager_3")
	rm._on_day_passed(19, "spring", 1)
	t.eq((ps.theft_events as Array).size(), 0,
		"day-19 theft is suppressed once the mercy flag is set")
	t.eq(ps.money, 100, "no coin is lost when the mercy flag suppresses the theft")
	# The normal flow cannot revisit day 19 after the theft, so prove the
	# flag is the gate by rolling the same day on a fresh manager without it.
	var ps2 = PLAYER_SCRIPT.new()
	ps2.money = 100
	var rm2 = RAID_SCRIPT.new()
	rm2.configure_for_test(ps2, gd)
	rm2._on_day_passed(19, "spring", 1)
	t.eq((ps2.theft_events as Array).size(), 1,
		"without the mercy flag the day-19 theft still fires")
	t.section_done("mercy flag theft guard")
