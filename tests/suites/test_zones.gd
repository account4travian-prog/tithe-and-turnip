extends RefCounted
## Sprint 15a/house interior data coverage: zones.json v2 +
## farm_map.json v5 must implement the Stage 1 adjacency graph plus the
## player's interior doorway -
## all 14 pairs as 28 directed exits, both deliberate non-adjacencies
## absent, every arrive_at/range inside bounds, features zone-exclusive,
## the spawn point on Fallowfield, and the 3270-tile area checksum.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const EXPECTED_ZONE_IDS: Array[String] = [
	"fallowfield", "north_strip", "ediths_plot", "nettleford", "manor",
	"upland_commons", "cottersward", "nettle_brook", "south_fields",
	"player_home_interior",
]


func suite_name() -> String:
	return "zones"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	_test_zone_list(t, gd)
	_test_positive_dims(t, gd)
	_test_bidirectional_exits(t, gd)
	_test_non_adjacencies(t, gd)
	_test_feature_exclusivity(t, gd)
	_test_spawn(t, gd)
	_test_home_orientation(t, gd)
	_test_coverage_checksum(t, gd)
	_test_zone_aware_accessors(t, gd)
	t.completed(100)


func _test_zone_list(t: Object, gd) -> void:
	t.eq(gd.get_zone_ids().size(), 10, "all ten registered zones are present")
	for zone_id: String in EXPECTED_ZONE_IDS:
		t.ok(gd.get_zone_ids().has(zone_id), "%s is in the zone list" % zone_id)
	t.section_done("zone list")


func _test_positive_dims(t: Object, gd) -> void:
	for zone_id: String in gd.get_zone_ids():
		var zone: Dictionary = gd.get_zone(zone_id)
		t.ok(int(zone.get("width", 0)) > 0 and int(zone.get("height", 0)) > 0,
			"zone %s has positive dims" % zone_id)
	t.section_done("positive dims")


func _test_bidirectional_exits(t: Object, gd) -> void:
	for zone_id: String in gd.get_zone_ids():
		var source: Dictionary = gd.get_zone(zone_id)
		for exit: Dictionary in gd.get_zone_exits(zone_id):
			var to_id := str(exit.get("to", ""))
			t.ok(_has_exit_to(gd, to_id, zone_id) or _has_door_to(gd, to_id, zone_id),
				"%s->%s has a return exit or door" % [zone_id, to_id])
			var arrive: Dictionary = exit.get("arrive_at", {})
			var dest: Dictionary = gd.get_zone(to_id)
			t.ok(not dest.is_empty(), "%s->%s destination exists" % [zone_id, to_id])
			if dest.is_empty():
				continue
			var ax := int(arrive.get("x", -1))
			var ay := int(arrive.get("y", -1))
			t.ok(ax >= 0 and ax < int(dest.get("width", 0)) \
				and ay >= 0 and ay < int(dest.get("height", 0)),
				"%s->%s arrive_at is inside the destination bounds" % [zone_id, to_id])
			var edge := str(exit.get("edge", ""))
			var in_bounds := true
			if edge == "north" or edge == "south":
				in_bounds = int(exit.get("x_min", 0)) >= 0 \
					and int(exit.get("x_max", -1)) < int(source.get("width", 0))
			elif edge == "east" or edge == "west":
				in_bounds = int(exit.get("y_min", 0)) >= 0 \
					and int(exit.get("y_max", -1)) < int(source.get("height", 0))
			t.ok(in_bounds, "%s->%s exit range is inside the source bounds" % [zone_id, to_id])
	t.section_done("bidirectional exits")


func _test_non_adjacencies(t: Object, gd) -> void:
	t.not_ok(_has_exit_to(gd, "manor", "cottersward"),
		"manor and cottersward are separated by the road")
	t.not_ok(_has_exit_to(gd, "cottersward", "manor"),
		"cottersward and manor are separated by the road")
	t.not_ok(_has_exit_to(gd, "nettleford", "cottersward"),
		"nettleford and cottersward are separated by the brook corridor")
	t.not_ok(_has_exit_to(gd, "cottersward", "nettleford"),
		"cottersward and nettleford are separated by the brook corridor")
	t.section_done("non-adjacencies")


func _test_feature_exclusivity(t: Object, gd) -> void:
	t.eq(gd.get_all_features("fallowfield").size(), 2,
		"fallowfield carries house + starter well only")
	var feature_zones := {}
	var wells := 0
	for zone_id: String in gd.get_zone_ids():
		for entry: Dictionary in gd.get_all_features(zone_id):
			var feature_id := str(entry.get("feature", ""))
			if not feature_zones.has(feature_id):
				feature_zones[feature_id] = []
			feature_zones[feature_id].append(zone_id)
			if feature_id == "well":
				wells += 1
	# "well" is deliberately a three-of: the starter well, the village well,
	# and the manor well each live in a different zone. Every other feature
	# id must appear in exactly one zone.
	for feature_id: Variant in feature_zones:
		var expected_zones := 1
		if str(feature_id) == "well":
			expected_zones = 3
		t.eq((feature_zones[feature_id] as Array).size(), expected_zones,
			"feature %s appears in %d zone(s)" % [str(feature_id), expected_zones])
	t.eq(str(gd.get_feature_tile("player_house", "fallowfield")), "(11, 11)",
		"player_house only in fallowfield at its anchor")
	t.eq(str(gd.get_feature_tile("player_house", "nettleford")), "(-1, -1)",
		"player_house is absent from nettleford")
	t.eq(str(gd.get_feature_tile("chapel", "nettleford")), "(10, 10)",
		"chapel only in nettleford")
	t.eq(str(gd.get_feature_tile("market_zone", "nettleford")), "(12, 8)",
		"market_zone only in nettleford")
	t.eq(str(gd.get_feature_tile("town_board", "nettleford")), "(11, 8)",
		"town_board only in nettleford")
	t.eq(str(gd.get_feature_tile("alehouse", "nettleford")), "(15, 10)",
		"alehouse occupies the village proper, clear of the market and chapel")
	t.eq(str(gd.get_feature_tile("stewards_demesne", "manor")), "(4, 6)",
		"stewards_demesne only in manor")
	t.eq(wells, 3, "three wells total across fallowfield/nettleford/manor")
	t.section_done("feature exclusivity")


func _test_spawn(t: Object, gd) -> void:
	var spawn: Dictionary = gd.get_spawn_point()
	t.eq(str(spawn.get("zone", "")), "fallowfield", "new games boot in the player's plot")
	var tile_x := int(spawn.get("x", -1))
	var tile_y := int(spawn.get("y", -1))
	t.ok(tile_x >= 0 and tile_x < gd.get_map_width("fallowfield") \
		and tile_y >= 0 and tile_y < gd.get_map_height("fallowfield"),
		"spawn tile is inside fallowfield's bounds")
	t.eq(gd.get_default_zone(), "fallowfield", "default zone is fallowfield")
	t.section_done("spawn")


func _test_home_orientation(t: Object, gd) -> void:
	var doors: Array[Dictionary] = gd.get_zone_doors("fallowfield")
	t.eq(doors.size(), 1, "fallowfield has one home door")
	t.eq(Vector2i(int(doors[0].get("x", -1)), int(doors[0].get("y", -1))), Vector2i(11, 12),
		"the exterior door sits at the farmhouse's south face")
	t.eq(doors[0].get("arrive_at", {}).get("y", -1), 5,
		"the exterior south door arrives one tile inside the interior south wall")
	var exits: Array[Dictionary] = gd.get_zone_exits("player_home_interior")
	t.eq(exits.size(), 1, "home interior has one exit")
	t.eq(str(exits[0].get("edge", "")), "south",
		"the interior exit preserves the farmhouse's south-facing orientation")
	t.section_done("home orientation")


func _test_coverage_checksum(t: Object, gd) -> void:
	var total := 0
	for zone_id: String in gd.get_zone_ids():
		var zone: Dictionary = gd.get_zone(zone_id)
		total += int(zone.get("width", 0)) * int(zone.get("height", 0))
		if bool(zone.get("is_tillable", false)):
			var rows: Array = zone.get("grid", [])
			t.eq(rows.size(), int(zone.get("height", 0)),
				"%s grid rows match its declared height" % zone_id)
	t.eq(total, 3270, "sum of zone areas is 3270 tiles including the home interior")
	t.section_done("coverage checksum")


func _test_zone_aware_accessors(t: Object, gd) -> void:
	t.eq(gd.get_map_width(), 24, "default-zone map width is fallowfield's 24")
	t.eq(gd.get_map_height(), 16, "default-zone map height is fallowfield's 16")
	t.eq(gd.get_soil_at(17, 13), "sandy", "fallowfield sandy pocket reads through the default alias")
	t.eq(gd.get_soil_at(0, 0), "loamy", "fallowfield loam reads through the default alias")
	t.eq(gd.get_soil_at(23, 5, "nettleford"), "sandy", "nettleford ford lip is sandy")
	t.eq(gd.get_soil_at(0, 0, "manor"), "rocky", "manor north fringe is rocky")
	t.eq(gd.get_soil_at(4, 4, "nettle_brook"), "sandy", "brook banks are sandy")
	t.eq(gd.get_soil_at(0, 4, "nettle_brook"), "loamy", "brook meadow is loamy")
	t.eq(gd.get_soil_at(12, 4, "south_fields"), "loamy", "south gully column stays loamy (untillable via tenure)")
	t.ok(gd.is_within_farm(23, 15), "fallowfield corner is within the default zone")
	t.not_ok(gd.is_within_farm(24, 15), "fallowfield x=24 is out of bounds")
	t.not_ok(gd.is_within_farm(5, 8, "north_strip"), "north_strip y=8 is out of bounds")
	t.section_done("zone-aware accessors")


func _has_exit_to(gd, from_zone: String, to_zone: String) -> bool:
	for exit: Dictionary in gd.get_zone_exits(from_zone):
		if str(exit.get("to", "")) == to_zone:
			return true
	return false


func _has_door_to(gd, from_zone: String, to_zone: String) -> bool:
	for door: Dictionary in gd.get_zone_doors(from_zone):
		if str(door.get("to", "")) == to_zone:
			return true
	return false
