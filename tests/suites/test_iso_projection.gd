extends RefCounted
## Coverage for the ADR-032 projection seam (scripts/globals/iso_projection.gd):
## the forward formula, round-trip correctness, the plan's two sanity
## identities, diamond corner/dimension math, the input-rotation convention,
## and cull-rect correctness including clamping at map edges. Pure math - no
## autoloads, no scene tree, so this suite can never be flaky on timing.

const EPS := 0.001


func suite_name() -> String:
	return "iso_projection"


func run(t: Object) -> void:
	_test_forward_formula(t)
	_test_round_trip(t)
	_test_sanity_identities(t)
	_test_diamond_dimensions(t)
	_test_world_round_trip(t)
	_test_input_rotation(t)
	_test_visible_cells_basic(t)
	_test_visible_cells_clamps_at_edges(t)
	t.completed(8)


func _approx(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < EPS


func _test_forward_formula(t: Object) -> void:
	t.ok(_approx(IsoProjection.grid_to_screen(Vector2(0, 0)), Vector2(0, 0)), "grid origin maps to screen origin")
	t.ok(_approx(IsoProjection.grid_to_screen(Vector2(1, 0)), Vector2(32, 16)), "grid (1,0) -> screen (32,16)")
	t.ok(_approx(IsoProjection.grid_to_screen(Vector2(0, 1)), Vector2(-32, 16)), "grid (0,1) -> screen (-32,16)")
	t.ok(_approx(IsoProjection.grid_to_screen(Vector2(1, 1)), Vector2(0, 32)), "grid (1,1) -> screen (0,32)")
	t.section_done("forward formula")


func _test_round_trip(t: Object) -> void:
	var samples: Array[Vector2] = [
		Vector2(0, 0), Vector2(5, 3), Vector2(-4, 7), Vector2(29, 19),
		Vector2(0.5, 0.5), Vector2(-12.25, 8.75),
	]
	for g: Vector2 in samples:
		var round_tripped := IsoProjection.screen_to_grid(IsoProjection.grid_to_screen(g))
		t.ok(_approx(round_tripped, g), "grid->screen->grid round-trips for %s" % g)
	t.section_done("round trip")


## The two identities IsometricConversion.md states explicitly as the
## definition of "in sync with the formula".
func _test_sanity_identities(t: Object) -> void:
	var g := Vector2(7, 2)
	var s := IsoProjection.grid_to_screen(g)
	t.ok(absf((g.x - g.y) - s.x / (IsoProjection.TILE_W / 2.0)) < EPS, "gx - gy == sx / (TILE_W/2)")
	t.ok(absf((g.x + g.y) - s.y / (IsoProjection.TILE_H / 2.0)) < EPS, "gx + gy == sy / (TILE_H/2)")
	t.section_done("sanity identities")


func _test_diamond_dimensions(t: Object) -> void:
	var corners := IsoProjection.cell_diamond(Vector2i(0, 0))
	t.eq(corners.size(), 4, "diamond has 4 corners")
	t.ok(_approx(corners[0], Vector2(0, 0)), "top corner at origin")
	t.ok(_approx(corners[1], Vector2(32, 16)), "right corner")
	t.ok(_approx(corners[2], Vector2(0, 32)), "bottom corner")
	t.ok(_approx(corners[3], Vector2(-32, 16)), "left corner")
	var width: float = corners[1].x - corners[3].x
	var height: float = corners[2].y - corners[0].y
	t.ok(absf(width - IsoProjection.TILE_W) < EPS, "diamond width matches TILE_W")
	t.ok(absf(height - IsoProjection.TILE_H) < EPS, "diamond height matches TILE_H")
	var centre := IsoProjection.cell_centre_screen(Vector2i(0, 0))
	var expected_centre: Vector2 = (corners[0] + corners[1] + corners[2] + corners[3]) / 4.0
	t.ok(_approx(centre, expected_centre), "cell_centre_screen matches the average of the four corners")
	t.section_done("diamond dimensions")


func _test_world_round_trip(t: Object) -> void:
	var w := Vector2(320.0, 96.0)
	var round_tripped := IsoProjection.screen_to_world(IsoProjection.world_to_screen(w))
	t.ok(_approx(round_tripped, w), "world->screen->world round-trips")
	t.ok(_approx(IsoProjection.world_to_screen(Vector2(IsoProjection.LOGICAL_CELL, 0.0)), Vector2(32, 16)),
		"one logical cell of world-space x maps like one grid cell of x")
	t.section_done("world round trip")


## input_to_world_dir is the Stardew-convention rotation: pressing screen-up
## must NOT be the identity in grid space (that would be the un-rotated,
## "diagonal WASD" behaviour ADR-032 rejected), and rotating it into world
## space and projecting back must point visibly up on screen again -
## confirming apparent screen speed is preserved (plan section 2.1).
func _test_input_rotation(t: Object) -> void:
	var screen_up := Vector2(0, -1)
	var world_dir := IsoProjection.input_to_world_dir(screen_up)
	t.not_ok(_approx(world_dir, screen_up), "screen-up is not the identity in grid space")
	var back_to_screen := IsoProjection.world_to_screen(world_dir)
	t.ok(_approx(back_to_screen.normalized(), screen_up.normalized()),
		"rotating screen-up into world space and projecting back still points up")
	t.section_done("input rotation")


func _test_visible_cells_basic(t: Object) -> void:
	# A screen rect centred on the origin, on an oversized map so clamping
	# never engages - isolates the un-clamped bounding-box math.
	var rect := Rect2(Vector2(-200, -150), Vector2(400, 300))
	var cells := IsoProjection.visible_cells(rect, 1000, 1000)
	t.ok(cells.size.x > 0 and cells.size.y > 0, "visible_cells returns a non-empty rect for a centred view")
	t.ok(cells.position.x >= 0 and cells.position.y >= 0, "visible_cells never returns a negative origin")
	t.section_done("visible cells basic")


func _test_visible_cells_clamps_at_edges(t: Object) -> void:
	# A tiny map: an oversized screen rect must clamp fully into it.
	var rect := Rect2(Vector2(-500, -500), Vector2(1000, 1000))
	var cells := IsoProjection.visible_cells(rect, 5, 5)
	t.eq(cells.position, Vector2i(0, 0), "cull rect clamps to the map's top-left corner")
	t.ok(cells.position.x + cells.size.x <= 5, "cull rect never exceeds map width")
	t.ok(cells.position.y + cells.size.y <= 5, "cull rect never exceeds map height")
	# A view entirely off the map (far past its bottom-right) clamps to an
	# empty rect, not a negative size.
	var far_rect := Rect2(Vector2(100000, 100000), Vector2(10, 10))
	var far_cells := IsoProjection.visible_cells(far_rect, 5, 5)
	t.ok(far_cells.size.x >= 0 and far_cells.size.y >= 0, "an off-map view never returns a negative size")
	t.section_done("visible cells clamping")
