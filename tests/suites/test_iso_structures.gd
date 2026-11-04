


extends RefCounted
## Coverage for WS-B's dimetric structure split (IsometricConversion.md WS-B):
## every fixed manor fixture and every placed building produces exactly one
## StructureVisual parented directly under world_visuals (never under its own
## collision body, never duplicated across a rebuild), collision bodies stay
## unchanged in logical space, the market stall recolours on status change,
## and the placement ghost tracks footprint/placeability correctly.
##
## Uses the REAL shipped data (GameData + farm_map.json/buildings.json),
## mirroring test_buildings.gd's pattern. None of these nodes are added to a
## live SceneTree - configure() is called directly, exactly like
## test_buildings.gd calls BuildingManager methods directly - so _ready()
## never fires (no TitheManager autoload to resolve via absolute path) and
## _tithe_manager stays null unless a test stubs it in directly. GDScript's
## leading-underscore fields are convention, not enforcement, so tests can
## and do reach into that private state the same way test_buildings.gd calls
## BuildingManager's private _on_day_passed directly.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")

## Stands in for the TitheManager autoload so _stall_color() has something to
## query without a live scene tree - real TitheManager instantiation drags in
## FarmGrid/PlayerState wiring this suite has no need for.
class _StubTitheManager extends Node:
	var open := false
	func is_market_open() -> bool:
		return open
	func is_black_market_open() -> bool:
		return false


## The market stall lives in Nettleford under farm_map.json v5, so this
## test configures the renderer with a mock whose feature list is exactly
## nettleford's - the same four features, no other zone's.
class _MockNettlefordGameData extends Node:
	## Sprint 15b: FeatureRenderer now collects per-zone features
	## (set_active_zone passes the zone id). The mock ignores it and returns
	## the fixed nettleford list - the market-stall test only cares that a
	## market fixture exists.
	func get_all_features(_zone_id: String = "") -> Array[Dictionary]:
		return [
			{"x": 10, "y": 10, "feature": "chapel"},
			{"x": 12, "y": 8, "feature": "market_zone"},
			{"x": 11, "y": 8, "feature": "town_board"},
			{"x": 20, "y": 9, "feature": "well"},
		]


func suite_name() -> String:
	return "iso_structures"


func run(t: Object) -> void:
	_test_fixed_fixtures_produce_one_visual_each(t)
	_test_collision_unchanged_and_logical(t)
	_test_per_zone_feature_anchors(t)
	_test_market_stall_recolors(t)
	_test_placed_building_produces_visual(t)
	_test_rebuild_does_not_duplicate(t)
	_test_building_completion_clears_in_progress(t)
	_test_ghost_tracks_and_reflects_placeability(t)
	_test_ghost_hides_for_unknown_building(t)
	t.completed(73)


func _make_game_data() -> Object:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	return gd


func _make_feature_renderer(gd: Object) -> Dictionary:
	var world_visuals := WorldVisuals.new()
	var renderer := FeatureRenderer.new()
	renderer.configure(gd, world_visuals)
	return {"renderer": renderer, "world_visuals": world_visuals}


func _test_fixed_fixtures_produce_one_visual_each(t: Object) -> void:
	var gd := _make_game_data()
	var env := _make_feature_renderer(gd)
	var renderer: Object = env["renderer"]
	var world_visuals: WorldVisuals = env["world_visuals"]

	var visuals := world_visuals.get_children()
	# farm_map.json v5 (Sprint 15a): the default zone is fallowfield, which
	# carries 1 player_house + 1 starter well - two fixed fixtures, two
	# StructureVisuals. The other zones' features are not built until 15b
	# wires per-zone renderer rebuilds (tested data-side below).
	t.eq(visuals.size(), 2, "fallowfield's two fixed fixtures produce two StructureVisual children")
	for child: Node in visuals:
		t.ok(child is StructureVisual, "every world_visuals child from FeatureRenderer is a StructureVisual")
		t.ok(child.get_parent() == world_visuals, "each StructureVisual's parent is world_visuals directly")

	# None of the fixture visuals are parented under the renderer itself or
	# under a collision StaticBody2D - the renderer's own children must be
	# collision bodies only (CLAUDE.md trap 10 / the plan's "never under its
	# own collision body" requirement).
	for child: Node in renderer.get_children():
		t.ok(child is StaticBody2D, "FeatureRenderer's own children are collision bodies, never a StructureVisual")

	# House footprint is the 4x3 rect expanded north of the bed anchor
	# (11,11) -> (9,9,4,3); its StructureVisual position is the screen
	# point of the footprint's south corner (13,12 in grid space per the
	# class's "feet" convention), matching IsoProjection.grid_to_screen.
	var house: StructureVisual = visuals[0]
	t.eq(house.footprint, Rect2i(9, 9, 4, 3), "house footprint gains the intended North-South depth")
	t.ok(house.position.distance_to(IsoProjection.grid_to_screen(Vector2(13, 12))) < 0.01,
		"house StructureVisual is positioned at its footprint's projected south corner")

	# The starter well is a single-tile footprint at its raw anchor.
	var well_footprints: Array[Rect2i] = []
	for child: Node in visuals:
		if child == house:
			continue
		well_footprints.append((child as StructureVisual).footprint)
	t.ok(well_footprints.has(Rect2i(13, 9, 1, 1)), "the starter well sits at fallowfield's (13,9) anchor")


func _test_collision_unchanged_and_logical(t: Object) -> void:
	var gd := _make_game_data()
	var env := _make_feature_renderer(gd)
	var renderer: Object = env["renderer"]

	var bodies: Array = renderer.get_children()
	# Fallowfield default zone: 5 house-wall bodies + 1 starter well = 6,
	# exactly what _build_collision produces from the v4 data.
	t.eq(bodies.size(), 6, "collision body count matches fallowfield's fixtures (5 house walls + 1 well)")
	for body: Node in bodies:
		t.ok(body is StaticBody2D, "every collision fixture is a StaticBody2D")
		t.ok(body.get_collision_layer_value(PhysicsLayers.INTERACTABLE),
			"every collision fixture is on PhysicsLayers.INTERACTABLE")

	# The house's north wall: fx=9, fy=9, 4 tiles wide, 6px thick, centred
	# at logical (352,291) = the wall's origin plus (64,3), still proving
	# the house's logical position, confirming collision never picked up a
	# projected coordinate.
	var north_wall: StaticBody2D = bodies[0]
	var shape: CollisionShape2D = north_wall.get_child(0)
	var rect: RectangleShape2D = shape.shape
	t.ok(rect.size.is_equal_approx(Vector2(128.0, 6.0)), "north wall collision size is 4 logical tiles wide, 6px thick")
	t.ok(shape.position.is_equal_approx(Vector2(352.0, 291.0)),
		"north wall collision centre sits at logical (352,291), not any projected screen coordinate")


## Sprint 15a (ADR-034): the guide's per-zone anchors, asserted data-side
## (renderer rebuilds by zone are Sprint 15b): wells at (13,9) fallowfield,
## (20,9) nettleford, (18,12) manor; chapel/market/town_board in nettleford;
## the demesne rect in manor; the house only on the holding.
func _test_per_zone_feature_anchors(t: Object) -> void:
	var gd := _make_game_data()
	t.eq(gd.get_feature_tile("player_house", "fallowfield"), Vector2i(11, 11),
		"player_house anchors fallowfield (11,11)")
	t.eq(gd.get_feature_tile("player_house", "nettleford"), Vector2i(-1, -1),
		"player_house is not in nettleford")
	t.eq(gd.get_feature_tile("well", "fallowfield"), Vector2i(13, 9),
		"starter well anchors fallowfield (13,9)")
	t.eq(gd.get_feature_tile("well", "nettleford"), Vector2i(20, 9),
		"village well anchors nettleford (20,9)")
	t.eq(gd.get_feature_tile("well", "manor"), Vector2i(18, 12),
		"manor well anchors manor (18,12)")
	t.eq(gd.get_feature_tile("chapel", "nettleford"), Vector2i(10, 10),
		"chapel anchors nettleford (10,10)")
	t.eq(gd.get_feature_tile("market_zone", "nettleford"), Vector2i(12, 8),
		"market stall anchors nettleford (12,8)")
	t.eq(gd.get_feature_tile("town_board", "nettleford"), Vector2i(11, 8),
		"town board anchors nettleford (11,8)")
	var manor_features: Array[Dictionary] = gd.get_all_features("manor")
	var demesne_ok := false
	for entry: Dictionary in manor_features:
		if str(entry.get("feature", "")) == "stewards_demesne" \
				and int(entry.get("x", -1)) == 4 and int(entry.get("y", -1)) == 6 \
				and int(entry.get("width", -1)) == 8 and int(entry.get("height", -1)) == 6:
			demesne_ok = true
	t.ok(demesne_ok, "stewards_demesne rect (4,6,8,6) lives in manor")
	gd.free()
	t.section_done("per-zone feature anchors")


func _test_market_stall_recolors(t: Object) -> void:
	var gd := _MockNettlefordGameData.new()
	var env := _make_feature_renderer(gd)
	var renderer: Object = env["renderer"]

	var market: StructureVisual = renderer._market_visual
	t.ok(market != null, "FeatureRenderer keeps a reference to the market stall's StructureVisual")
	t.eq(market.top_color, FeatureRenderer.COLOR_STALL_SHUT,
		"stall defaults to shut colour when no TitheManager is wired (never added to a live tree)")

	var stub := _StubTitheManager.new()
	stub.open = true
	renderer._tithe_manager = stub
	renderer._on_market_status_changed(true)
	t.eq(market.top_color, FeatureRenderer.COLOR_STALL_OPEN, "market status change recolors the stall StructureVisual to open")

	stub.open = false
	renderer._on_market_status_changed(false)
	t.eq(market.top_color, FeatureRenderer.COLOR_STALL_SHUT, "market status change recolors the stall StructureVisual back to shut")


func _make_building_env(money: int, flint: int, wood: int = 0) -> Dictionary:
	var gd := _make_game_data()
	var player = PLAYER_STATE_SCRIPT.new()
	player.money = money
	if flint > 0:
		player.add_item("flint", flint)
	if wood > 0:
		player.add_item("wood", wood)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(player, gd)
	var world_visuals := WorldVisuals.new()
	var renderer := BuildingRenderer.new()
	renderer.configure(bm, gd, world_visuals)
	return {"bm": bm, "renderer": renderer, "world_visuals": world_visuals}


func _structure_children(world_visuals: WorldVisuals) -> Array[StructureVisual]:
	var out: Array[StructureVisual] = []
	for child: Node in world_visuals.get_children():
		if child is StructureVisual:
			out.append(child)
	return out


func _test_placed_building_produces_visual(t: Object) -> void:
	var env := _make_building_env(1000, 100)
	var bm: Object = env["bm"]
	var world_visuals: WorldVisuals = env["world_visuals"]

	# configure() alone (no building placed yet) still parents exactly the
	# ghost - hidden, but present as a single reusable instance.
	t.eq(_structure_children(world_visuals).size(), 1, "only the hidden ghost exists before any building is placed")

	bm.start_building("storage_chest", Vector2i(5, 5))
	var visuals := _structure_children(world_visuals)
	t.eq(visuals.size(), 2, "placing one building adds exactly one more StructureVisual alongside the ghost")

	var building_visual: StructureVisual
	for v: StructureVisual in visuals:
		if v.footprint == Rect2i(5, 5, 1, 1):
			building_visual = v
	t.ok(building_visual != null, "the placed building's StructureVisual has the expected 1x1 footprint at (5,5)")
	t.eq(building_visual.top_color, BuildingRenderer.BUILDING_COLORS["storage_chest"],
		"placed building's colour matches BUILDING_COLORS for its id")
	t.ok(building_visual.in_progress, "a 1-build-day storage chest is in progress immediately after start_building")
	t.ok(building_visual.get_parent() == world_visuals, "the placed building's StructureVisual is parented under world_visuals directly")


func _test_rebuild_does_not_duplicate(t: Object) -> void:
	var env := _make_building_env(1000, 100, 100)
	var bm: Object = env["bm"]
	var world_visuals: WorldVisuals = env["world_visuals"]

	bm.start_building("storage_chest", Vector2i(5, 5))
	# The fence is build_days: 0, so start_building fires BOTH
	# building_started and building_completed - two _on_buildings_changed
	# calls for one placement. A leaking rebuild would double the count.
	bm.start_building("fence", Vector2i(0, 10))
	var visuals := _structure_children(world_visuals)
	t.eq(visuals.size(), 3, "two placed buildings plus the ghost, with no duplicate from the fence's double signal")

	var footprints: Array[Rect2i] = []
	for v: StructureVisual in visuals:
		footprints.append(v.footprint)
	t.ok(footprints.has(Rect2i(5, 5, 1, 1)), "storage chest footprint still present after the second placement's rebuild")
	t.ok(footprints.has(Rect2i(0, 10, 1, 1)), "fence footprint present after its own rebuild")


func _test_building_completion_clears_in_progress(t: Object) -> void:
	var env := _make_building_env(1000, 100)
	var bm: Object = env["bm"]
	var world_visuals: WorldVisuals = env["world_visuals"]

	bm.start_building("storage_chest", Vector2i(5, 5))
	bm._on_day_passed(1, "spring", 1)
	var completed_visual: StructureVisual
	for v: StructureVisual in _structure_children(world_visuals):
		if v.footprint == Rect2i(5, 5, 1, 1):
			completed_visual = v
	t.ok(completed_visual != null, "storage chest's StructureVisual still exists after completion's rebuild")
	t.not_ok(completed_visual.in_progress, "storage chest's StructureVisual clears in_progress once construction completes")


func _test_ghost_tracks_and_reflects_placeability(t: Object) -> void:
	var env := _make_building_env(1000, 100)
	var bm: Object = env["bm"]
	var renderer: Object = env["renderer"]

	bm.start_building("storage_chest", Vector2i(5, 5))
	renderer.show_ghost("storage_chest", Vector2i(5, 5))
	var ghost: StructureVisual = renderer._ghost_visual
	t.ok(ghost.visible, "ghost becomes visible once show_ghost is called")
	t.eq(ghost.footprint, Rect2i(5, 5, 1, 1), "ghost footprint matches the requested position and building's size")
	t.eq(ghost.top_color, BuildingRenderer.GHOST_BLOCKED, "ghost is coloured blocked over the already-occupied tile")

	renderer.show_ghost("storage_chest", Vector2i(20, 15))
	t.eq(ghost.footprint, Rect2i(20, 15, 1, 1), "moving the ghost updates its footprint to the new faced tile")
	t.eq(ghost.top_color, BuildingRenderer.GHOST_PLACEABLE, "ghost is coloured placeable over free, in-bounds ground")
	t.ok(ghost.position.distance_to(IsoProjection.grid_to_screen(Vector2(21, 16))) < 0.01,
		"ghost StructureVisual position tracks its footprint's projected south corner")

	renderer.hide_ghost()
	t.not_ok(ghost.visible, "hide_ghost hides the persistent ghost StructureVisual rather than freeing it")


func _test_ghost_hides_for_unknown_building(t: Object) -> void:
	var env := _make_building_env(1000, 100)
	var renderer: Object = env["renderer"]
	renderer.show_ghost("no_such_building", Vector2i(3, 3))
	var ghost: StructureVisual = renderer._ghost_visual
	t.not_ok(ghost.visible, "an unknown building id leaves the ghost hidden instead of drawing garbage")
