extends RefCounted
## Coverage for the ADR-032 terrain renderer (scripts/world/farm_renderer.gd):
## cull-set correctness at map corners/edges (IsoProjection.visible_cells as
## farm_renderer actually calls it, including the no-camera fallback) and the
## redraw-on-camera-move trigger. Does not invoke _draw() itself - that needs
## a live CanvasItem draw context a headless SceneTree script does not have -
## so this suite drives the same public surface _draw() uses
## (get_visible_cull_rect()) and observes redraws via the test-only
## redraw_request_count counter instead of the drawing calls themselves.

const FARM_RENDERER_SCRIPT := preload("res://scripts/world/farm_renderer.gd")
const ISO_CAMERA_SCRIPT := preload("res://scripts/world/iso_camera.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

## A camera stand-in that overrides get_visible_screen_rect() with a fixed
## value instead of deriving it from get_viewport_rect()/zoom, which require
## a live Viewport this off-tree suite does not have. global_position is a
## plain Node2D property and works fine off-tree.
class _MockCamera extends IsoCamera:
	var fake_rect: Rect2 = Rect2(Vector2(-100, -75), Vector2(200, 150))

	func get_visible_screen_rect() -> Rect2:
		return fake_rect


class _MockGameData extends Node:
	var map_w: int = 30
	var map_h: int = 20

	func get_map_width() -> int:
		return map_w

	func get_map_height() -> int:
		return map_h

	func get_soil_properties(_soil: String) -> Dictionary:
		return {"color": "#8B7355"}


class _MockFarmGrid extends Node:
	signal tile_changed(pos: Vector2i)


func suite_name() -> String:
	return "iso_terrain"


func run(t: Object) -> void:
	_test_no_camera_falls_back_to_full_map(t)
	_test_cull_matches_iso_projection_directly(t)
	_test_cull_at_top_left_corner(t)
	_test_cull_at_bottom_right_corner(t)
	_test_cull_clamps_on_oversized_map(t)
	_test_per_zone_cull_rect(t)
	_test_redraw_on_tile_changed(t)
	_test_no_redraw_when_cull_rect_is_unchanged(t)
	_test_redraw_when_cull_rect_changes(t)
	_test_no_redraw_when_small_map_cull_stays_full(t)
	_test_forage_glyph_category_completeness(t)
	_test_exit_line_grid_points(t)
	t.completed(11)


func _make_renderer() -> Object:
	return FARM_RENDERER_SCRIPT.new()


## With no camera configured (the pre-ADR-032 behaviour, and what any
## camera-less caller gets), the renderer must cover the whole map unculled -
## never a literal-30/20 stand-in, always GameData's reported dimensions.
func _test_no_camera_falls_back_to_full_map(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 60
	gd.map_h = 40
	var grid = _MockFarmGrid.new()
	fr.configure(grid, gd, null)

	var cull: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.eq(cull, Rect2i(0, 0, 60, 40), "no camera -> full (60x40) map is the cull rect")

	fr.free()
	gd.free()
	grid.free()


## The cull rect the renderer computes for a configured camera must be
## exactly what IsoProjection.visible_cells returns for that camera's screen
## rect - i.e. farm_renderer is a thin, correct pass-through, not a
## reimplementation (which the ADR-032 invariant-guard suite would also flag
## if it used the forbidden token names, but this confirms the values agree
## too).
func _test_cull_matches_iso_projection_directly(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 30
	gd.map_h = 20
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.fake_rect = Rect2(Vector2(-64, -48), Vector2(256, 192))
	fr.configure(grid, gd, cam)

	var expected := IsoProjection.visible_cells(cam.fake_rect, gd.map_w, gd.map_h)
	var actual: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.eq(actual, expected, "farm_renderer's cull rect matches IsoProjection.visible_cells directly")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## A camera parked over the map's top-left corner (grid (0,0)) must clamp the
## cull rect's origin at (0,0), never negative - the corner is exactly where
## an off-by-one clamp bug would show up.
func _test_cull_at_top_left_corner(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 30
	gd.map_h = 20
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	# Camera centred on grid (0,0), screen rect large enough to poke well off
	# the map's top-left edge.
	cam.global_position = IsoProjection.grid_to_screen(Vector2(0, 0))
	cam.fake_rect = Rect2(cam.global_position - Vector2(300, 300), Vector2(600, 600))
	fr.configure(grid, gd, cam)

	var cull: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.eq(cull.position, Vector2i(0, 0), "cull rect clamps to the map's top-left corner, never negative")
	t.ok(cull.position.x + cull.size.x <= gd.map_w, "cull rect never exceeds map width at the top-left corner")
	t.ok(cull.position.y + cull.size.y <= gd.map_h, "cull rect never exceeds map height at the top-left corner")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## Symmetric check at the opposite corner (grid (map_w, map_h)): the cull
## rect's far edge must clamp at the map bounds, never overshoot.
func _test_cull_at_bottom_right_corner(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 30
	gd.map_h = 20
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.global_position = IsoProjection.grid_to_screen(Vector2(gd.map_w, gd.map_h))
	cam.fake_rect = Rect2(cam.global_position - Vector2(300, 300), Vector2(600, 600))
	fr.configure(grid, gd, cam)

	var cull: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.eq(cull.position.x + cull.size.x, gd.map_w, "cull rect's right edge clamps exactly to map width")
	t.eq(cull.position.y + cull.size.y, gd.map_h, "cull rect's bottom edge clamps exactly to map height")
	t.ok(cull.position.x >= 0 and cull.position.y >= 0, "cull rect origin stays non-negative at the far corner")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## A view far off the map entirely (well past its bottom-right in screen
## space) must clamp to an empty (zero-size) rect, never a negative size -
## this is the scenario the plan singles out for the 60x40 map: a camera
## whose padded cull rect would otherwise overshoot into undefined cells.
## IsoProjection.visible_cells only guarantees a non-negative size here (its
## own suite asserts the same, not a bounded position) - an out-of-range
## position paired with zero size still yields an empty range() in _draw()'s
## loops, so no cell is ever visited regardless of how far off-map the
## position number is.
func _test_cull_clamps_on_oversized_map(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 60
	gd.map_h = 40
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.global_position = Vector2(1000000, 1000000)
	cam.fake_rect = Rect2(cam.global_position, Vector2(10, 10))
	fr.configure(grid, gd, cam)

	var cull: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.ok(cull.size.x >= 0 and cull.size.y >= 0, "an off-map camera view never yields a negative cull size")
	t.eq(cull.size.x, 0, "a view entirely off the map's far edge yields zero cull width")
	t.eq(cull.size.y, 0, "a view entirely off the map's far edge yields zero cull height")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## Sprint 15a (ADR-034): the renderer's cull seam already takes explicit
## map dims, so per-zone culling is a data-feeding change (15b wires the
## active zone's dims in). These cases prove the pass-through holds for a
## small zone (north_strip) and a tall one (nettle_brook) using the REAL
## per-zone dims from GameData.
func _test_per_zone_cull_rect(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var fr = _make_renderer()
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.fake_rect = Rect2(Vector2(-64, -48), Vector2(256, 192))
	fr.configure(grid, gd, cam)
	var brook_cull: Rect2i = fr.get_visible_cull_rect(
		gd.get_map_width("nettle_brook"), gd.get_map_height("nettle_brook"))
	t.eq(brook_cull, IsoProjection.visible_cells(cam.fake_rect, 16, 32),
		"nettle_brook's per-zone cull rect matches IsoProjection with its own dims")
	t.ok(brook_cull.position.x >= 0 and brook_cull.position.y >= 0,
		"per-zone cull stays non-negative")
	var fr2 = _make_renderer()
	fr2.configure(grid, gd, null)
	t.eq(fr2.get_visible_cull_rect(
		gd.get_map_width("north_strip"), gd.get_map_height("north_strip")),
		Rect2i(0, 0, 24, 8), "no-camera fallback covers the whole north_strip map")
	fr.free()
	fr2.free()
	gd.free()
	grid.free()
	cam.free()
	t.section_done("per-zone cull rect")


## The pre-existing dirty-flag discipline: a tile_changed signal must request
## exactly one redraw, still working after the ADR-032 rewrite.
func _test_redraw_on_tile_changed(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	var grid = _MockFarmGrid.new()
	fr.configure(grid, gd, null)

	var baseline: int = fr.redraw_request_count
	grid.tile_changed.emit(Vector2i(1, 1))
	t.eq(fr.redraw_request_count, baseline + 1, "tile_changed requests exactly one redraw")

	fr.free()
	gd.free()
	grid.free()


## The renderer should not redraw when the actual visible cull rectangle is
## unchanged. The camera stand-in keeps its screen rect fixed so this pins the
## new trigger directly instead of relying on a grid-cell approximation.
func _test_no_redraw_when_cull_rect_is_unchanged(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.global_position = IsoProjection.grid_to_screen(Vector2(10.1, 10.1))
	fr.configure(grid, gd, cam)
	fr._process(0.016)  # primes _has_visible_cull_rect - always redraws once
	var baseline: int = fr.redraw_request_count

	# The camera moves, but its reported screen rectangle is unchanged.
	cam.global_position = IsoProjection.grid_to_screen(Vector2(10.4, 10.6))
	fr._process(0.016)
	fr._process(0.016)
	t.eq(fr.redraw_request_count, baseline, "an unchanged cull rect requests no extra redraw")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## The core of the redraw-on-scroll requirement: when the screen rectangle
## moves enough for visible_cells() to return a different cell rectangle, the
## renderer must request a redraw.
func _test_redraw_when_cull_rect_changes(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 60
	gd.map_h = 40
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.global_position = IsoProjection.grid_to_screen(Vector2(10.1, 10.1))
	cam.fake_rect = Rect2(cam.global_position - Vector2(100, 75), Vector2(200, 150))
	fr.configure(grid, gd, cam)
	fr._process(0.016)  # primes _has_visible_cull_rect
	var baseline: int = fr.redraw_request_count

	# Move the camera one grid cell and update the reported screen rectangle.
	cam.global_position = IsoProjection.grid_to_screen(Vector2(11.2, 10.1))
	cam.fake_rect = Rect2(cam.global_position - Vector2(100, 75), Vector2(200, 150))
	fr._process(0.016)
	t.ok(fr.redraw_request_count > baseline, "a changed cull rect requests a redraw")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## Regression for the reported spawn-map performance shape: a camera can cross
## many cells while a small map remains entirely inside the padded visible
## rectangle. That must not redraw all map terrain on every crossing.
func _test_no_redraw_when_small_map_cull_stays_full(t: Object) -> void:
	var fr = _make_renderer()
	var gd = _MockGameData.new()
	gd.map_w = 24
	gd.map_h = 16
	var grid = _MockFarmGrid.new()
	var cam = _MockCamera.new()
	cam.global_position = IsoProjection.grid_to_screen(Vector2(12.1, 8.1))
	cam.fake_rect = Rect2(cam.global_position - Vector2(1000, 1000), Vector2(2000, 2000))
	fr.configure(grid, gd, cam)
	fr._process(0.016)
	var baseline: int = fr.redraw_request_count
	var initial_cull: Rect2i = fr.get_visible_cull_rect(gd.map_w, gd.map_h)
	t.eq(initial_cull, Rect2i(0, 0, 24, 16), "the small-map test view covers the full spawn map")

	cam.global_position = IsoProjection.grid_to_screen(Vector2(18.2, 12.4))
	cam.fake_rect = Rect2(cam.global_position - Vector2(1000, 1000), Vector2(2000, 2000))
	fr._process(0.016)
	t.eq(fr.redraw_request_count, baseline,
		"moving across a fully visible small map requests no extra terrain redraw")

	fr.free()
	gd.free()
	grid.free()
	cam.free()


## Playtest fix: every forage_item_id data/forage.json's spawn tables can
## actually place on a tile - dig_loot items (morel, truffle, wild_carrot,
## wild_turnip) never touch tile state; FarmGrid.dig_cell is a pure
## roll-and-return, confirmed by reading it - must have a
## FORAGE_GLYPH_CATEGORY entry, plus the hardcoded "spoiled_crop" rot pickup
## (ADR-018). Guards against exactly the bug this fix closes: a forage item
## added to data without a matching renderer entry going invisible again.
func _test_forage_glyph_category_completeness(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var spawns: Dictionary = gd.get_forage_config().get("spawns", {})
	var seen: Dictionary = {}
	for soil: Variant in spawns:
		var entries: Array = spawns[soil]
		for entry: Variant in entries:
			var item_id := str((entry as Dictionary).get("item_id", ""))
			if not item_id.is_empty():
				seen[item_id] = true
	seen["spoiled_crop"] = true
	for item_id: String in seen:
		t.ok(FARM_RENDERER_SCRIPT.FORAGE_GLYPH_CATEGORY.has(item_id),
			"FORAGE_GLYPH_CATEGORY has a glyph entry for real forage item '%s'" % item_id)

	gd.free()


## Playtest fix: exit_line_grid_points() is the geometry _draw_exit_paths()
## projects via IsoProjection.grid_to_screen - tested directly here rather
## than through _draw() itself (no live CanvasItem context headless, same
## limitation this suite's other tests document).
func _test_exit_line_grid_points(t: Object) -> void:
	var fr = _make_renderer()
	var north := {"edge": "north", "x_min": 2, "x_max": 5}
	t.eq(fr.exit_line_grid_points(north, 10, 8), [Vector2(2.0, 0.0), Vector2(6.0, 0.0)],
		"north exit spans x_min to x_max+1 at grid y=0")

	var south := {"edge": "south", "x_min": 1, "x_max": 3}
	t.eq(fr.exit_line_grid_points(south, 10, 8), [Vector2(1.0, 8.0), Vector2(4.0, 8.0)],
		"south exit spans x_min to x_max+1 at grid y=map_height")

	var west := {"edge": "west", "y_min": 0, "y_max": 2}
	t.eq(fr.exit_line_grid_points(west, 10, 8), [Vector2(0.0, 0.0), Vector2(0.0, 3.0)],
		"west exit spans y_min to y_max+1 at grid x=0")

	var east := {"edge": "east", "y_min": 4, "y_max": 6}
	t.eq(fr.exit_line_grid_points(east, 10, 8), [Vector2(10.0, 4.0), Vector2(10.0, 7.0)],
		"east exit spans y_min to y_max+1 at grid x=map_width")

	var unknown := {"edge": "up"}
	t.eq(fr.exit_line_grid_points(unknown, 10, 8), [],
		"an unrecognised edge string returns no points rather than guessing")

	# Cross-check against a real zones.json entry, not just synthetic data.
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var real_north := {}
	for e: Dictionary in gd.get_zone_exits("fallowfield"):
		if str(e.get("edge", "")) == "north":
			real_north = e
			break
	t.not_ok(real_north.is_empty(), "fallowfield has a real north exit in zones.json to check against")
	var real_points: Array[Vector2] = fr.exit_line_grid_points(
		real_north, gd.get_map_width("fallowfield"), gd.get_map_height("fallowfield"))
	t.eq(real_points.size(), 2, "the real fallowfield north exit resolves to exactly two grid points")
	t.eq(real_points[0].y, 0.0, "the real north exit's line sits at grid y=0")

	fr.free()
	gd.free()
	t.section_done("exit line grid points")
