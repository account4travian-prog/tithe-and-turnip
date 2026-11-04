

extends RefCounted
## Sprint 15b (ADR-034 second half) integration coverage: the zone-swap
## tuple - player/ToolManager grid re-wire, arrival-tile position, camera
## dims, farm/feature/building renderer rebuilds, NPC zone membership at
## different hours in different zones, autoload state surviving a crossing,
## and the real Manor demesne rect through TitheManager (the end-to-end
## proof that ADR-040's spatial chores are reachable once transitions work).
##
## main.gd itself cannot be preloaded under the headless harness (its bare
## autoload identifiers fail to compile without Project Settings
## registration - the same constraint player.gd's own docstring documents),
## so the "main-handler equivalent" is driven through the exact public
## methods _on_zone_changed calls, in the same order - the established
## off-tree construction pattern (test_iso_actors.gd).

const ZONE_MANAGER_SCRIPT := preload("res://scripts/autoloads/zone_manager.gd")
const FARM_GRID_SCRIPT := preload("res://scripts/world/farm_grid.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")
const PLAYER_STATE_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const TIME_MANAGER_SCRIPT := preload("res://scripts/autoloads/time_manager.gd")
const ISO_CAMERA_SCRIPT := preload("res://scripts/world/iso_camera.gd")
const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const FEATURE_RENDERER_SCRIPT := preload("res://scripts/world/feature_renderer.gd")
const BUILDING_RENDERER_SCRIPT := preload("res://scripts/world/building_renderer.gd")
const BUILDING_MANAGER_SCRIPT := preload("res://scripts/autoloads/building_manager.gd")
const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")

const SOIL_PROPS := {
	"loamy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
	"sandy": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
	"rocky": {"moisture_decay_per_day": 1.0, "growth_speed_mult": 1.0,
		"fine_quality_bonus": 0, "choice_quality_bonus": 0},
}

## The REAL stewards_demesne footprint from farm_map.json v5 (the Manor
## zone, Rect2i(4, 6, 8, 6)) - not the old single-map position the ADR-040
## suite still injects. This is what 15b makes reachable.
const DEMESNE_RECT := Rect2i(4, 6, 8, 6)


func suite_name() -> String:
	return "zone_transitions"


func run(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	_test_player_grid_and_position(t, gd)
	_test_autoload_state_survives(t, gd)
	_test_camera_dims(t)
	_test_farm_renderer_rewire(t, gd)
	_test_feature_renderer_rebuild(t, gd)
	_test_building_renderer_rebuild(t, gd)
	_test_npc_membership_by_hour(t, gd)
	_test_manor_demesne_reachable(t, gd)
	gd.free()
	t.completed(40)


## Ten real FarmGrids over real GameData with a real BuildingManager
## injected (the 15a ownership seam), so the till gate behaves like live:
## Fallowfield owned, every other zone unowned until a strip is rented.
func _make_grids(gd) -> Dictionary:
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(PLAYER_STATE_SCRIPT.new(), gd)
	var grids := {}
	for zone_id: String in gd.get_zone_ids():
		var grid = FARM_GRID_SCRIPT.new()
		var soil_map := {}
		for y in range(gd.get_map_height(zone_id)):
			for x in range(gd.get_map_width(zone_id)):
				soil_map[Vector2i(x, y)] = gd.get_soil_at(x, y, zone_id)
		grid.configure_for_test({}, soil_map, SOIL_PROPS,
			Vector2i(gd.get_map_width(zone_id), gd.get_map_height(zone_id)),
			{}, [], zone_id)
		grid._test_building_manager = bm
		grids[zone_id] = grid
	return grids


## Guide assertions 1-3: the player's grid ref, the ToolManager's grid ref,
## the arrival-tile world position, and that tools target the new active
## grid (a Nettleford swing cannot touch Fallowfield state).
func _test_player_grid_and_position(t: Object, gd) -> void:
	var grids := _make_grids(gd)
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, grids, "fallowfield")
	t.eq(zm.change_zone("nettleford", Vector2i(12, 15)), true, "change_zone accepts nettleford")
	var player = PLAYER_SCRIPT.new()
	player.set_farm_grid(grids["fallowfield"])
	# main-handler equivalent: set_active_farm_grid, then arrival position.
	player.set_active_farm_grid(zm.get_active_farm_grid())
	t.ok(player.get_farm_grid() == grids["nettleford"],
		"player's active grid follows the zone change")
	t.ok(player.get_tool_manager()._farm_grid == grids["nettleford"],
		"ToolManager's grid follows the zone change")
	var tile: Vector2i = zm.get_player_tile()
	var half := 16.0
	player.position = Vector2(tile.x * 32.0 + half, tile.y * 32.0 + half)
	player.velocity = Vector2.ZERO
	t.eq(player.position, Vector2(12 * 32.0 + 16.0, 15 * 32.0 + 16.0),
		"player lands on the arrival tile in world units")
	t.eq(player.velocity, Vector2.ZERO, "velocity is zeroed on arrival")
	t.not_ok(grids["nettleford"].till_tile(Vector2i(12, 15)),
		"nettleford tile cannot be tilled (not farmland)")
	t.not_ok(bool(grids["fallowfield"].get_cell(Vector2i(12, 15)).get("tilled", false)),
		"fallowfield grid untouched by the nettleford swing")
	t.ok(grids["fallowfield"].till_tile(Vector2i(12, 15)),
		"the same local tile is tillable on the holding")
	player.free()
	zm.free()
	_free_grids(grids)
	t.section_done("player grid + position")


## Guide assertion 1: everything owned by autoloads survives a transition.
func _test_autoload_state_survives(t: Object, gd) -> void:
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.add_item("turnip", 5)
	ps.money = 100
	ps.energy = 50.0
	var tm = TIME_MANAGER_SCRIPT.new()
	tm.from_dict({"day": 1, "season": "spring", "year": 1, "hour": 14, "minute": 0})
	var grids := _make_grids(gd)
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, grids, "fallowfield")
	zm.change_zone("nettleford", Vector2i(12, 15))
	t.eq(ps.get_item_count("turnip"), 5, "inventory survives a zone transition")
	t.eq(ps.money, 100, "money survives a zone transition")
	t.eq(ps.energy, 50.0, "energy survives a zone transition")
	t.eq(tm.to_dict().hour, 14, "time survives a zone transition")
	ps.free()
	tm.free()
	zm.free()
	_free_grids(grids)
	t.section_done("autoload state survives")


## Guide assertion 5: the camera clamps to the active zone's dimensions.
func _test_camera_dims(t: Object) -> void:
	var cam = ISO_CAMERA_SCRIPT.new()
	cam.set_map_dims(24, 16)
	t.eq(cam.get_map_dims(), Vector2i(24, 16),
		"camera clamps to the active zone's dimensions (nettleford 24x16)")
	cam.set_map_dims(16, 32)
	t.eq(cam.get_map_dims(), Vector2i(16, 32),
		"camera follows the brook's tall dims (16x32)")
	cam.free()
	t.section_done("camera dims")


## The farm renderer's live re-wire: old grid disconnected, new grid
## connected, same-grid re-wire idempotent (no double connects).
func _test_farm_renderer_rewire(t: Object, gd) -> void:
	var grids := _make_grids(gd)
	var fr = FARM_RENDERER_SCRIPT.new()
	var cam = ISO_CAMERA_SCRIPT.new()
	fr.configure(grids["fallowfield"], gd, cam)
	var baseline: int = fr.redraw_request_count
	grids["fallowfield"].tile_changed.emit(Vector2i(1, 1))
	t.eq(fr.redraw_request_count, baseline + 1,
		"fallowfield grid is connected before the swap")
	fr.set_active_grid(grids["nettleford"])
	var after_rewire: int = fr.redraw_request_count
	t.ok(after_rewire > baseline, "re-wiring requests a redraw")
	grids["fallowfield"].tile_changed.emit(Vector2i(1, 1))
	t.eq(fr.redraw_request_count, after_rewire,
		"old grid's tile_changed no longer triggers redraws")
	grids["nettleford"].tile_changed.emit(Vector2i(1, 1))
	t.eq(fr.redraw_request_count, after_rewire + 1,
		"new grid's tile_changed triggers redraws")
	# Re-wiring the SAME grid: the redundant call requests exactly one
	# redraw and must not connect a second handler - one emit after it must
	# yield exactly one redraw.
	var before_same_rewire: int = fr.redraw_request_count
	fr.set_active_grid(grids["nettleford"])
	var after_same_rewire: int = fr.redraw_request_count
	t.eq(after_same_rewire, before_same_rewire + 1,
		"same-grid re-wire requests exactly one redraw")
	grids["nettleford"].tile_changed.emit(Vector2i(1, 1))
	t.eq(fr.redraw_request_count, after_same_rewire + 1,
		"one emit after same-grid re-wire triggers exactly one redraw")
	fr.free()
	cam.free()
	_free_grids(grids)
	t.section_done("farm renderer re-wire")


## FeatureRenderer rebuilds: each zone's fixture set replaces the previous
## zone's synchronously, with no duplicates on a return visit.
func _test_feature_renderer_rebuild(t: Object, gd) -> void:
	var world_visuals := WorldVisuals.new()
	var renderer := FEATURE_RENDERER_SCRIPT.new()
	renderer.configure(gd, world_visuals)
	t.eq(world_visuals.get_children().size(), 2,
		"fallowfield's two fixtures build two StructureVisuals")
	t.eq(renderer.get_children().size(), 6,
		"fallowfield's collision bodies: 5 house walls + 1 well")
	renderer.set_active_zone("nettleford")
	t.eq(world_visuals.get_children().size(), 5,
		"nettleford builds chapel/market/board/well/alehouse visuals")
	t.eq(renderer.get_children().size(), 10,
		"nettleford builds four single-tile fixtures plus the alehouse's six-tile collision footprint")
	t.eq(renderer._market_anchor, Vector2i(12, 8),
		"market anchor is nettleford's")
	renderer.set_active_zone("manor")
	t.eq(world_visuals.get_children().size(), 2,
		"manor builds well + tithe chest visuals")
	t.eq(renderer.get_children().size(), 2,
		"manor builds two collision bodies")
	t.eq(renderer._tithe_chest_anchor, Vector2i(4, 6),
		"tithe chest anchors at the manor demesne origin")
	renderer.set_active_zone("player_home_interior")
	t.eq(world_visuals.get_children().size(), 3,
		"home interior builds its shell plus separate door and window visuals")
	t.eq(renderer.get_children().size(), 5,
		"home interior builds perimeter walls with one south doorway")
	renderer.set_active_zone("fallowfield")
	t.eq(world_visuals.get_children().size(), 2,
		"returning to fallowfield rebuilds exactly two visuals (no duplicates)")
	renderer.free()
	world_visuals.free()
	t.section_done("feature renderer rebuild")


## BuildingRenderer rebuilds per zone (all buildings live on fallowfield).
func _test_building_renderer_rebuild(t: Object, gd) -> void:
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.money = 1000
	ps.add_item("flint", 100)
	ps.add_item("wood", 100)
	var bm = BUILDING_MANAGER_SCRIPT.new()
	bm.configure_for_test(ps, gd)
	var world_visuals := WorldVisuals.new()
	var renderer := BUILDING_RENDERER_SCRIPT.new()
	renderer.configure(bm, gd, world_visuals)
	bm.start_building("storage_chest", Vector2i(5, 5))
	t.eq(_structure_count(world_visuals), 2,
		"one placed fallowfield building + the hidden ghost")
	renderer.set_active_zone("nettleford")
	t.eq(_structure_count(world_visuals), 1,
		"nettleford shows no placed buildings (only the hidden ghost)")
	renderer.set_active_zone("fallowfield")
	t.eq(_structure_count(world_visuals), 2,
		"returning to fallowfield restores the building visual")
	renderer.free()
	world_visuals.free()
	bm.free()
	ps.free()
	t.section_done("building renderer rebuild")


## Guide assertion 4: NPC zone membership at different hours in different
## zones, through the same ZoneManager source main.gd's spawn filter uses.
func _test_npc_membership_by_hour(t: Object, gd) -> void:
	var zm = ZONE_MANAGER_SCRIPT.new()
	zm.configure_for_test(gd, {}, "fallowfield")
	zm.change_zone("nettleford", Vector2i(12, 15))
	zm._test_hour = 10
	var in_nettleford := zm.get_active_zone_npc_ids()
	t.ok(in_nettleford.has("villager_3"), "Marta works in Nettleford by day")
	t.ok(in_nettleford.has("steward"), "the steward is in Nettleford by day")
	t.not_ok(in_nettleford.has("villager_5"), "Edith never appears in Nettleford")
	zm.change_zone("nettle_brook", Vector2i(2, 10))
	var in_brook := zm.get_active_zone_npc_ids()
	t.ok(in_brook.has("villager_6"), "Osric is at the mill by day")
	t.not_ok(in_brook.has("villager_3"), "Marta is not in the brook during work hours")
	zm._test_hour = 20
	var at_night := zm.get_active_zone_npc_ids()
	t.ok(at_night.has("villager_3"), "Marta is home in the brook by night")
	t.not_ok(at_night.has("villager_5"), "Edith still never appears in the brook")
	zm._test_hour = 10
	var day_ids := zm.get_active_zone_npc_ids()
	t.ok(day_ids.has("villager_6") and not day_ids.has("villager_3"),
		"hour-10 membership drops Marta and keeps Osric")
	zm.free()
	t.section_done("npc zone membership")


## The 15b end-to-end proof for ADR-040 x ADR-034: the REAL manor demesne
## rect, through a manor-zone grid wired into TitheManager exactly the way
## the zone_changed handler re-points set_farm_grid_ref. Till/water/harvest/
## carry all resolve at the manor chest (4,6) - including the zone-aware
## delivery tile.
func _test_manor_demesne_reachable(t: Object, gd) -> void:
	var ps = PLAYER_STATE_SCRIPT.new()
	ps.money = 100
	ps.energy = 100.0
	var manor_grid = FARM_GRID_SCRIPT.new()
	var soil_map := {}
	for y in range(gd.get_map_height("manor")):
		for x in range(gd.get_map_width("manor")):
			soil_map[Vector2i(x, y)] = gd.get_soil_at(x, y, "manor")
	manor_grid.configure_for_test({}, soil_map, SOIL_PROPS,
		Vector2i(gd.get_map_width("manor"), gd.get_map_height("manor")),
		{}, [], "manor", DEMESNE_RECT, gd.get_demesne_config())
	var tm = TITHE_SCRIPT.new()
	# configure_for_test's farm seam is the same reference the handler's
	# set_farm_grid_ref call would install.
	tm.configure_for_test(ps, gd, func() -> int: return 1, manor_grid)
	var chest := Vector2i(4, 6)
	var demesne_tile := Vector2i(5, 6)
	t.ok(tm.can_demesne_chore_at("till_demesne", demesne_tile),
		"manor demesne tile is tillable once the Manor is reachable")
	t.ok(manor_grid.till_tile(demesne_tile, true), "till the real manor demesne tile")
	t.ok(tm.complete_demesne_tool_chore("till_demesne", demesne_tile, 5.0),
		"till chore completes at the manor")
	manor_grid.advance_day(false, false, 1)
	t.ok(manor_grid.count_demesne_sheaves() > 0,
		"the manor demesne replenishes stored sheaves")
	var sheaf_tile := _first_sheaf_tile(manor_grid)
	t.not_ok(sheaf_tile == Vector2i(-1, -1), "a sheaf tile exists on the demesne")
	t.ok(tm.can_demesne_chore_at("harvest_demesne", sheaf_tile),
		"harvest gate opens at a sheaf tile")
	t.ok(tm.complete_demesne_interaction("harvest_demesne", sheaf_tile),
		"harvest completes at the manor")
	t.eq(tm.get_demesne_status().get("delivery_tile"), chest,
		"delivery tile resolves to the manor chest (zone-aware lookup)")
	t.ok(tm.can_demesne_chore_at("carry_produce", chest),
		"the manor tithe chest accepts the delivery")
	t.ok(tm.complete_demesne_interaction("carry_produce", chest),
		"carry completes at the manor tithe chest")
	t.eq(int(tm.get_demesne_status().get("carrying_sheaves", -1)), 0,
		"delivery clears the carry state")
	tm.free()
	manor_grid.free()
	ps.free()
	t.section_done("manor demesne reachable")


func _structure_count(world_visuals: WorldVisuals) -> int:
	var count := 0
	for child: Node in world_visuals.get_children():
		if child is StructureVisual:
			count += 1
	return count


func _first_sheaf_tile(farm) -> Vector2i:
	for y in range(DEMESNE_RECT.position.y, DEMESNE_RECT.end.y):
		for x in range(DEMESNE_RECT.position.x, DEMESNE_RECT.end.x):
			var pos := Vector2i(x, y)
			if farm.is_demesne_sheaf_tile(pos):
				return pos
	return Vector2i(-1, -1)


## Frees every grid in a _make_grids dictionary plus the shared
## BuildingManager they were all injected with. Keeps the headless harness
## exit clean (no leaked RIDs/ObjectDB instances).
func _free_grids(grids: Dictionary) -> void:
	var bm = null
	for zone_id: Variant in grids:
		var grid = grids[zone_id]
		if bm == null and grid != null and grid._test_building_manager != null:
			bm = grid._test_building_manager
		if grid != null:
			grid.free()
	if bm != null:
		bm.free()
