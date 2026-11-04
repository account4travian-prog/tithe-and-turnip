extends RefCounted
## Sprint 15a (ADR-034) model coverage for the ZoneManager autoload: the
## registry, change_zone/zone_changed, exit resolution, region-wide
## advance_day, per-zone save round-trip, and the get_npc_zone hour query.
## Ten real FarmGrids over real GameData (the data files ARE the fixture).

const ZONE_MANAGER_SCRIPT := preload("res://scripts/autoloads/zone_manager.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
	"sandy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
	"rocky": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}


func suite_name() -> String:
	return "zone_manager"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var grids := _make_grids(gd)
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, grids, "fallowfield")
	_test_defaults(t, zm, grids)
	_test_change_zone(t, zm)
	_test_rejects_unknown_zone(t, zm)
	_test_resolve_exits(t, zm)
	_test_advance_day_waters_every_zone(t, zm, gd)
	_test_save_roundtrip(t, gd)
	_test_npc_zone_by_hour(t, gd)
	_test_registry(t, zm, grids)
	t.completed(60)


func _make_grids(gd) -> Dictionary:
	var grids := {}
	for zone_id: String in gd.get_zone_ids():
		var grid = FARM_GRID_SCRIPT.new()
		var soil_map := {}
		for y in range(gd.get_map_height(zone_id)):
			for x in range(gd.get_map_width(zone_id)):
				soil_map[Vector2i(x, y)] = gd.get_soil_at(x, y, zone_id)
		grid.configure_for_test({}, soil_map, SOIL_PROPS,
			Vector2i(gd.get_map_width(zone_id), gd.get_map_height(zone_id)), {}, [], zone_id)
		grids[zone_id] = grid
	return grids


func _test_defaults(t: Object, zm, grids: Dictionary) -> void:
	t.eq(zm.get_active_zone_id(), "fallowfield", "defaults to the player's plot")
	t.eq(zm.get_player_tile(), Vector2i(12, 10), "player tile defaults to the fallowfield spawn")
	t.ok(zm.get_active_farm_grid() == grids["fallowfield"],
		"active grid is the fallowfield grid")
	t.eq(zm.get_all_farm_grids().size(), 10, "all ten grids are registered")
	t.section_done("defaults")


func _test_change_zone(t: Object, zm) -> void:
	var fired := [0]
	zm.zone_changed.connect(func(_zone_id: String) -> void: fired[0] += 1)
	t.eq(zm.change_zone("nettleford", Vector2i(12, 15)), true,
		"change_zone accepts a valid zone")
	t.eq(zm.get_active_zone_id(), "nettleford", "active zone updates after change_zone")
	t.eq(zm.get_player_tile(), Vector2i(12, 15), "player tile is the arrival tile")
	t.eq(fired[0], 1, "zone_changed fired exactly once")
	t.section_done("change zone")


func _test_rejects_unknown_zone(t: Object, zm) -> void:
	t.eq(zm.change_zone("not_a_zone", Vector2i.ZERO), false,
		"unknown zone is rejected with no state change")
	t.eq(zm.get_active_zone_id(), "nettleford", "active zone unchanged after rejection")
	t.section_done("unknown zone")


func _test_resolve_exits(t: Object, zm) -> void:
	t.eq(str(zm.resolve_exit("fallowfield", "north", 12).get("to", "")), "north_strip",
		"north-edge crossing resolves to the North Strip")
	t.eq(str(zm.resolve_exit("fallowfield", "south", 12).get("to", "")), "south_fields",
		"south-edge crossing resolves to the South Fields")
	t.eq(str(zm.resolve_exit("fallowfield", "east", 8).get("to", "")), "ediths_plot",
		"east-edge crossing resolves to Edith's Plot")
	t.ok(zm.resolve_exit("fallowfield", "west", 5).is_empty(),
		"a boundary tile with no exit returns an empty dict")
	# Bug fix (2026-08-10): these five assertions were written for an
	# east-facing cottage door that was never actually shipped. Commit
	# b9f02c0 ("Sprint 16 continuation... interior sprites...") added BOTH
	# these assertions AND data/zones.json's real door/exit in the same
	# commit, but the two disagreed - the door it actually added is
	# south-facing ({"x": 11, "y": 12, ...}, matching
	# interior_player_home_door_south in the interior_visual fixture list),
	# while these assertions expected an east door at (13, 11). That
	# mismatch was never caught because the same commit also introduced an
	# unrelated compile bug (untyped `:=` inference, fixed earlier this
	# session) that silently hung the entire suite - so these assertions
	# had never actually run until now. Recalculated against the real,
	# live-verified door/exit (this exact door was walked through during
	# this session's isometric-conversion live capture).
	t.eq(str(zm.resolve_door("fallowfield", Vector2i(11, 12)).get("to", "")),
		"player_home_interior", "the cottage south door resolves to the interior zone")
	t.eq(zm.resolve_door("fallowfield", Vector2i(11, 12)).get("arrive_at", {}).get("x", -1), 5,
		"entering the south-facing cottage door lands at the interior's arrival tile")
	t.eq(zm.resolve_door("player_home_interior", Vector2i(5, 3)), {},
		"the interior defines no doors of its own - it uses its south edge exit instead")
	var interior_exit: Dictionary = zm.resolve_exit("player_home_interior", "south", 5)
	t.eq(str(interior_exit.get("to", "")), "fallowfield",
		"the interior south doorway returns to Fallowfield")
	t.eq(interior_exit.get("arrive_at", {}).get("x", -1), 11,
		"returning from inside lands back at the cottage door's fallowfield tile")
	t.ok(zm.resolve_exit("fallowfield", "north", 5).is_empty(),
		"an index outside an exit's range returns an empty dict")
	t.ok(zm.find_exit("fallowfield", "north", 17).has("to"),
		"find_exit matches the top of the north range")
	t.eq(zm.get_exits("fallowfield").size(), 3, "fallowfield carries its three exits")
	t.section_done("exit resolution")


func _test_advance_day_waters_every_zone(t: Object, zm, gd) -> void:
	zm.advance_day(true, false)
	for zone_id: String in gd.get_zone_ids():
		var grid: Object = zm.get_farm_grid(zone_id)
		var probe := Vector2i(4, 4)
		if probe.x >= gd.get_map_width(zone_id) or probe.y >= gd.get_map_height(zone_id):
			continue
		if str(grid.get_soil(probe)).is_empty():
			continue
		t.eq(float(grid.get_cell(probe).get("moisture", 0.0)), 100.0,
			"rain waters a %s-zone cell while the player is elsewhere" % zone_id)
	t.eq(float(zm.get_farm_grid("nettle_brook").get_cell(Vector2i(4, 4)).get("moisture", 0.0)), 100.0,
		"rain waters a brook-zone cell while the player is elsewhere")
	t.section_done("advance day")


func _test_save_roundtrip(t: Object, gd) -> void:
	var grids := _make_grids(gd)
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, grids, "fallowfield")
	var farm = zm.get_farm_grid("fallowfield")
	farm.till_tile(Vector2i(12, 10))
	zm.change_zone("manor", Vector2i(3, 3))
	var dumped: Dictionary = zm.to_dict()
	t.eq((dumped.get("zones", {}) as Dictionary).size(), 10,
		"to_dict carries all ten zone keys")
	t.ok((dumped.get("zones", {}).get("fallowfield", {}).get("cells", []) as Array).size() > 0,
		"fallowfield cells are non-empty")
	t.eq(str(dumped.get("current_zone", "")), "manor", "current_zone serializes")
	t.eq(int(dumped.get("player_tile", {}).get("x", -1)), 3, "player_tile x serializes")

	var fresh_grids := _make_grids(gd)
	var fresh = ZONE_MANAGER_SCRIPT.new()
	fresh.configure_for_test(gd, fresh_grids, "fallowfield")
	fresh.from_dict(dumped)
	t.eq(fresh.get_active_zone_id(), "manor", "current_zone restores exactly")
	t.eq(fresh.get_player_tile(), Vector2i(3, 3), "player_tile restores exactly")
	t.eq(fresh.to_dict().get("zones", {}).size(), 10, "round-trip keeps ten zone keys")
	var restored_cells: Array = fresh.to_dict().get("zones", {}).get("fallowfield", {}).get("cells", [])
	var restored_tilled := false
	for entry: Variant in restored_cells:
		var cell := entry as Dictionary
		if int(cell.get("x", -1)) == 12 and int(cell.get("y", -1)) == 10 \
				and bool(cell.get("tilled", false)):
			restored_tilled = true
	t.ok(restored_tilled, "fallowfield cell state restores through from_dict")
	t.section_done("save roundtrip")


func _test_npc_zone_by_hour(t: Object, gd) -> void:
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, {}, "fallowfield")
	zm._test_hour = 10
	t.eq(zm.get_npc_zone("villager_3"), "nettleford", "Marta works in Nettleford by day")
	t.eq(zm.get_npc_zone("villager_5"), "ediths_plot", "Edith anchors on her own plot")
	t.eq(zm.get_npc_zone("villager_6"), "nettle_brook", "Osric works the mill by day")
	zm._test_hour = 20
	t.eq(zm.get_npc_zone("villager_3"), "nettle_brook", "Marta is home by night")
	zm._test_hour = 5
	t.eq(zm.get_npc_zone("steward"), "nettleford", "the steward's home is in Nettleford")
	t.section_done("npc zone by hour")


func _test_registry(t: Object, zm, grids: Dictionary) -> void:
	var extra = FARM_GRID_SCRIPT.new()
	extra.configure_for_test({}, {}, SOIL_PROPS, Vector2i(2, 2), {}, [], "")
	zm.register_farm_grid("fallowfield", extra)
	t.eq(extra.get_zone_id(), "fallowfield", "register_farm_grid sets the grid's zone id")
	t.ok(zm.get_farm_grid("fallowfield") == extra, "register_farm_grid replaces by zone id")
	t.eq(zm.get_farm_grid("nettle_brook"), grids["nettle_brook"],
		"get_farm_grid returns the registered grid for a zone")
	t.section_done("registry")
