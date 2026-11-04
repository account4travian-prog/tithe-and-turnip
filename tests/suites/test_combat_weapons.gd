extends RefCounted
## Sprint 12 combat additions: the raid_leader enemy loads from data; a combat
## pass-out wounds while exhaustion does not; wounds tick down once per day and
## floor at zero; a wound taxes tool energy until it clears.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TOOL_SCRIPT := preload("res://scripts/world/tool_manager.gd")


class _FakeFarmGrid:
	extends Node

	func till_tile(_pos: Vector2i) -> bool:
		return true


func suite_name() -> String:
	return "combat_weapons"


func run(t: Object) -> void:
	_test_raid_leader_data(t)
	_test_wound_on_combat_pass_out(t)
	_test_wound_decay(t)
	_test_wound_tool_penalty(t)
	t.completed(4)


func _test_raid_leader_data(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var leader: Dictionary = gd.get_enemy("raid_leader")
	t.eq(int(leader.get("health", -1)), 35, "raid leader health")
	t.eq(int(leader.get("damage", -1)), 10, "raid leader damage")
	t.eq(int(leader.get("speed", -1)), 90, "raid leader speed")
	t.eq(int(leader.get("reach", -1)), 60, "raid leader reach")
	t.section_done("raid leader data")


func _test_wound_on_combat_pass_out(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var combat_ps = PLAYER_SCRIPT.new()
	combat_ps.apply_pass_out_penalty("combat")
	t.eq(combat_ps.wound_days_remaining, int(gd.player_cfg.get("wound_recovery_days", 1)),
		"combat pass-out sets wound_recovery_days")
	var exhaustion_ps = PLAYER_SCRIPT.new()
	exhaustion_ps.apply_pass_out_penalty("exhaustion")
	t.eq(exhaustion_ps.wound_days_remaining, 0, "exhaustion pass-out does not wound")
	t.section_done("wound causes")


func _test_wound_decay(t: Object) -> void:
	var ps = PLAYER_SCRIPT.new()
	ps.wound_days_remaining = 2
	ps._on_day_passed(1, "spring", 1)
	t.eq(ps.wound_days_remaining, 1, "wound decrements once per day")
	ps._on_day_passed(2, "spring", 1)
	t.eq(ps.wound_days_remaining, 0, "wound clears at zero")
	ps._on_day_passed(3, "spring", 1)
	t.eq(ps.wound_days_remaining, 0, "wound never goes negative")
	t.section_done("wound decay")


func _test_wound_tool_penalty(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.energy = 100.0
	var grid := _FakeFarmGrid.new()
	var tm = TOOL_SCRIPT.new()
	tm.init(ps, grid)
	var hoe := {"tool_category": "hoe", "energy_cost": 4}
	tm._use_tool_item(hoe, Vector2i.ZERO)
	t.ok(is_equal_approx(ps.energy, 96.0), "healthy tool use costs base energy")
	ps.wound_days_remaining = 1
	ps.energy = 100.0
	tm._use_tool_item(hoe, Vector2i.ZERO)
	t.ok(is_equal_approx(ps.energy, 95.2), "wounded tool use costs 1.2x energy")
	ps.wound_days_remaining = 0
	ps.energy = 100.0
	tm._use_tool_item(hoe, Vector2i.ZERO)
	t.ok(is_equal_approx(ps.energy, 96.0), "healed tool use is back to base cost")
	t.section_done("wound tool penalty")
