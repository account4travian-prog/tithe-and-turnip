extends RefCounted
## Land tenure coverage: default ownership, renting (a one-time, uncosted
## claim - see building_manager.gd's docstring for why the old recurring
## rent/eviction mechanic was retired), and the FarmGrid till gate (the
## actual integration point). Real tenure.json data throughout.

const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}


func suite_name() -> String:
	return "tenure"


func run(t: Object) -> void:
	var env := _make_manager(100)
	_test_ownership_defaults(t, env)
	_test_rent_and_other_strip(t, env)
	_test_rent_unknown_and_idempotent(t, env)
	_test_strip_rects_partition(t, env)
	_test_farm_till_gate(t)
	t.completed(27)


func _make_manager(money: int) -> Dictionary:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = money
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	return {"bm": bm, "player": player, "gd": gd}


func _test_ownership_defaults(t: Object, env: Dictionary) -> void:
	var bm: Object = env["bm"]
	t.ok(bm.is_land_owned(Vector2i(3, 3)),
		"a fallowfield tile is owned (default zone alias)")
	t.ok(bm.is_land_owned(Vector2i(20, 10)),
		"every fallowfield tile is owned, not just a default rect")
	t.not_ok(bm.is_land_owned_in_zone("north_strip", Vector2i(12, 4)),
		"tile inside unrented strip_north is not owned in its zone")
	t.not_ok(bm.is_land_owned_in_zone("south_fields", Vector2i(2, 4)),
		"tile inside unrented strip_southwest is not owned in its zone")
	t.not_ok(bm.is_land_owned_in_zone("ediths_plot", Vector2i(5, 5)),
		"another tenant's plot is never owned")
	t.section_done("ownership defaults")


func _test_rent_and_other_strip(t: Object, env: Dictionary) -> void:
	var bm: Object = env["bm"]
	t.ok(bm.rent_strip("strip_north"), "rent_strip succeeds for strip_north")
	t.ok(bm.is_strip_rented("strip_north"), "strip_north is flagged rented")
	t.ok(bm.is_land_owned_in_zone("north_strip", Vector2i(12, 4)),
		"strip_north tile is owned in its zone after renting it")
	t.not_ok(bm.is_land_owned_in_zone("south_fields", Vector2i(2, 4)),
		"a different unrented strip stays unowned")
	t.ok(bm.is_land_owned_in_zone("fallowfield", Vector2i(0, 0)),
		"the holding stays fully owned regardless of rentals")
	t.section_done("rent")


func _test_rent_unknown_and_idempotent(t: Object, env: Dictionary) -> void:
	var fresh := _make_manager(100)
	var bm: Object = fresh["bm"]
	t.not_ok(bm.rent_strip("strip_nope"),
		"rent_strip on an unknown id returns false")
	t.ok(bm.rent_strip("strip_north"), "precondition: rent strip_north")
	t.not_ok(bm.rent_strip("strip_north"),
		"rent_strip on an already-rented strip returns false")
	t.section_done("rent guards")


func _test_strip_rects_partition(t: Object, env: Dictionary) -> void:
	var gd: Object = env["gd"]
	var tenure: Dictionary = gd.get_tenure_data()
	t.eq(str(tenure.get("default_owned_zone", "")), "fallowfield",
		"default ownership is the whole Fallowfield zone")
	var fallow: Dictionary = gd.get_zone("fallowfield")
	t.eq(int(fallow.get("width", 0)) * int(fallow.get("height", 0)), 384,
		"the holding is the whole 24x16 fallowfield grid")
	var total := 0
	for strip: Variant in tenure.get("strips", []):
		var s := strip as Dictionary
		var strip_zone := str(s.get("zone", ""))
		t.ok(gd.get_zone_ids().has(strip_zone), "strip %s names a real zone" % str(s.get("id", "")))
		var r := s.get("rect", {}) as Dictionary
		var x := int(r.get("x", 0))
		var y := int(r.get("y", 0))
		var w := int(r.get("width", 0))
		var h := int(r.get("height", 0))
		total += w * h
		t.ok(x >= 0 and y >= 0 and x + w <= gd.get_map_width(strip_zone) \
			and y + h <= gd.get_map_height(strip_zone),
			"strip %s rect stays inside its zone" % str(s.get("id", "")))
	t.eq(total, 500, "the three rentable strips total 500 tiles")
	t.eq((tenure.get("strips", []) as Array).size(), 3, "strip ids are unchanged")
	t.section_done("partition checksum")


func _test_farm_till_gate(t: Object) -> void:
	var env := _make_manager(100)
	var bm: Object = env["bm"]
	var gd: Object = env["gd"]
	# Fallowfield: every tile of the holding is tillable (test mode, no
	# injected BuildingManager - owned_rects empty means unrestricted, which
	# keeps every pre-15a suite passing unchanged).
	var farm = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(gd.get_map_height()):
		for x in range(gd.get_map_width()):
			soil_map[Vector2i(x, y)] = "loamy"
	farm.configure_for_test({}, soil_map, SOIL_PROPS,
		Vector2i(gd.get_map_width(), gd.get_map_height()), {}, [], "fallowfield")
	t.ok(farm.till_tile(Vector2i(3, 3)),
		"till succeeds on a fallowfield tile")
	t.ok(farm.is_owned(Vector2i(20, 10)), "is_owned wrapper true for any holding tile")

	# Rented strips gate through the REAL BuildingManager: an unrented
	# strip tile cannot be tilled; renting the strip makes it tillable.
	var farm_north = FARM_GRID_SCRIPT.new()
	var north_soil := {}
	for y in range(gd.get_map_height("north_strip")):
		for x in range(gd.get_map_width("north_strip")):
			north_soil[Vector2i(x, y)] = "loamy"
	farm_north.configure_for_test({}, north_soil, SOIL_PROPS,
		Vector2i(gd.get_map_width("north_strip"), gd.get_map_height("north_strip")),
		{}, [], "north_strip")
	farm_north._test_building_manager = bm
	t.not_ok(farm_north.till_tile(Vector2i(12, 4)),
		"unrented strip tile cannot be tilled")
	t.ok(bm.rent_strip("strip_north"), "precondition: strip_north rents")
	t.ok(farm_north.till_tile(Vector2i(12, 4)),
		"rented strip tile becomes tillable")

	# The South Fields' gully column sits between the two parcels and is in
	# no strip - it stays untillable even after renting the SW parcel.
	var farm_south = FARM_GRID_SCRIPT.new()
	var south_soil := {}
	for y in range(gd.get_map_height("south_fields")):
		for x in range(gd.get_map_width("south_fields")):
			south_soil[Vector2i(x, y)] = "loamy"
	farm_south.configure_for_test({}, south_soil, SOIL_PROPS,
		Vector2i(gd.get_map_width("south_fields"), gd.get_map_height("south_fields")),
		{}, [], "south_fields")
	farm_south._test_building_manager = bm
	t.not_ok(farm_south.till_tile(Vector2i(2, 4)),
		"unrented south-west parcel cannot be tilled")
	t.ok(bm.rent_strip("strip_southwest"), "precondition: strip_southwest rents")
	t.ok(farm_south.till_tile(Vector2i(2, 4)),
		"rented south-west parcel becomes tillable")
	t.not_ok(farm_south.till_tile(Vector2i(12, 4)),
		"the gully column is in no strip and stays untillable")
	t.section_done("farm till gate")


func _find_strip(tenure: Dictionary, strip_id: String) -> Dictionary:
	for entry: Variant in tenure.get("strips", []):
		var s := entry as Dictionary
		if str(s.get("id", "")) == strip_id:
			return s
	return {}


func _rect_from(r: Dictionary) -> Rect2i:
	return Rect2i(int(r.get("x", 0)), int(r.get("y", 0)), int(r.get("width", 0)), int(r.get("height", 0)))
