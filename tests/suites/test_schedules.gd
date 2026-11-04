extends RefCounted
## NPC schedule coverage: villagers.json v4 home/work anchors switch on the
## hour with start-inclusive / end-exclusive boundaries, tested through the
## real NPC._update_anchor comparison, plus data completeness for all six
## villagers. The live node's movement (which needs a scene tree) is not
## exercised - only the anchor decision, as the Sprint 10 guide specifies.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const NPC_SCRIPT := preload("res://scripts/npc/npc.gd")
const ZONE_MANAGER_SCRIPT := preload("res://scripts/autoloads/zone_manager.gd")


func suite_name() -> String:
	return "schedules"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	_test_steward_day(t, gd)
	_test_priest_edges(t, gd)
	_test_schedule_completeness(t, gd)
	_test_zone_anchors(t, gd)
	_test_npc_zone_by_hour(t, gd)
	t.completed(27)


func _make_npc(gd, villager_id: String) -> Node:
	var npc = NPC_SCRIPT.new()
	var schedule: Dictionary = gd.get_villager_schedule(villager_id)
	npc._home_pos = Vector2(100.0, 100.0)
	npc._work_pos = Vector2(200.0, 200.0)
	npc._work_start_hour = int(schedule.get("work_start_hour", 8))
	npc._work_end_hour = int(schedule.get("work_end_hour", 18))
	npc._anchor = npc._home_pos
	npc._start_pos = npc._anchor
	return npc


func _test_steward_day(t: Object, gd) -> void:
	var npc := _make_npc(gd, "steward")
	npc._update_anchor(6)
	t.eq(npc._anchor, npc._home_pos, "steward hour 6 is home (before work start)")
	npc._update_anchor(7)
	t.eq(npc._anchor, npc._work_pos, "steward hour 7 is work (start inclusive)")
	npc._update_anchor(19)
	t.eq(npc._anchor, npc._work_pos, "steward hour 19 is still work")
	npc._update_anchor(20)
	t.eq(npc._anchor, npc._home_pos, "steward hour 20 is home (end exclusive)")
	t.section_done("steward day")


func _test_priest_edges(t: Object, gd) -> void:
	var npc := _make_npc(gd, "priest")
	npc._update_anchor(5)
	t.eq(npc._anchor, npc._home_pos, "priest hour 5 is home")
	npc._update_anchor(6)
	t.eq(npc._anchor, npc._work_pos, "priest hour 6 is work (early start)")
	npc._update_anchor(21)
	t.eq(npc._anchor, npc._home_pos, "priest hour 21 is home (late end exclusive)")
	t.section_done("priest edges")


func _test_schedule_completeness(t: Object, gd) -> void:
	for villager_id: String in gd.get_all_villager_ids():
		var schedule: Dictionary = gd.get_villager_schedule(villager_id)
		var home: Dictionary = schedule.get("home", {})
		var work: Dictionary = schedule.get("work", {})
		t.ok(not home.is_empty() and not work.is_empty(),
			"%s has home and work tiles" % villager_id)
		t.ok(int(schedule.get("work_start_hour", -1)) < int(schedule.get("work_end_hour", -1)),
			"%s work window is non-empty" % villager_id)
	t.section_done("completeness")


## villagers.json v6: every anchor is zone-qualified and sits on a valid
## tile inside its own zone (the guide's NPC-data-migration guard - a
## zone-local anchor that fell outside the zone would strand or misplace
## the villager once 15b spawns per-zone).
func _test_zone_anchors(t: Object, gd) -> void:
	for villager_id: String in gd.get_all_villager_ids():
		var villager: Dictionary = gd.get_villager(villager_id)
		var anchors: Array[Dictionary] = [
			villager.get("spawn", {}),
			villager.get("schedule", {}).get("home", {}),
			villager.get("schedule", {}).get("work", {}),
		]
		var all_zoned := true
		var all_in_bounds := true
		for anchor: Dictionary in anchors:
			var zone_id := str(anchor.get("zone", ""))
			if not gd.get_zone_ids().has(zone_id):
				all_zoned = false
				continue
			var zone: Dictionary = gd.get_zone(zone_id)
			var ax := int(anchor.get("x", -1))
			var ay := int(anchor.get("y", -1))
			if ax < 0 or ax >= int(zone.get("width", 0)) \
					or ay < 0 or ay >= int(zone.get("height", 0)):
				all_in_bounds = false
		t.ok(all_zoned, "%s anchors all name a real zone" % villager_id)
		t.ok(all_in_bounds, "%s anchors all sit inside their zone's bounds" % villager_id)
	t.section_done("zone anchors")


## The schedule's zone switch at the hour boundary, through ZoneManager's
## get_npc_zone (the same data 15b's world presence will consume): Marta
## (villager_3) works in Nettleford by day and is home by the brook at
## night.
func _test_npc_zone_by_hour(t: Object, gd) -> void:
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, {}, "fallowfield")
	zm._test_hour = 10
	t.eq(zm.get_npc_zone("villager_3"), "nettleford", "Marta works in Nettleford at hour 10")
	zm._test_hour = 20
	t.eq(zm.get_npc_zone("villager_3"), "nettle_brook", "Marta is home by the brook at hour 20")
	zm._test_hour = 10
	t.eq(zm.get_npc_zone("villager_5"), "ediths_plot", "Edith never leaves her plot")
	t.eq(zm.get_npc_zone("steward"), "nettleford", "the steward stays in Nettleford")
	t.section_done("npc zone by hour")
