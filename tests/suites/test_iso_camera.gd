extends RefCounted
## Coverage for IsoCamera (scripts/world/iso_camera.gd), IsometricConversion.md
## section 4's WS-D. IsoCamera extends Camera2D, and most of its interesting
## behaviour (get_viewport_rect(), make_current()) needs a live Viewport,
## which a headless SceneTree --script run does not have inside
## `_initialize()` (nodes added to `root` are not yet is_inside_tree() at
## that point - confirmed empirically against this exact 4.7.1 binary before
## writing this suite). So instead of exercising _process()/
## get_visible_screen_rect() end-to-end, this suite:
##   - calls the pure, static, viewport-free helpers IsoCamera factors its
##     math into (_visible_rect, _clamp_target_to_map, _clamp_or_centre)
##     directly, with synthetic viewport sizes/zooms/map dimensions;
##   - calls the instance methods that do NOT require a live viewport
##     (_recompute_limits(), _process() along the branch that skips
##     get_viewport_rect() when _game_data is unset) directly on an
##     off-tree IsoCamera instance.
## _game_data is typed Node, so a duck-typed fake needs to be a Node
## subclass - FakeGameData below, local to this suite.

const ISO_CAMERA_SCRIPT := preload("res://scripts/world/iso_camera.gd")
const ISO_PROJECTION := preload("res://scripts/globals/iso_projection.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const EPS := 0.01

class FakeGameData extends Node:
	var w: int = 0
	var h: int = 0

	func get_map_width() -> int:
		return w

	func get_map_height() -> int:
		return h


func suite_name() -> String:
	return "iso_camera"


func run(t: Object) -> void:
	_test_zoom_decision(t)
	_test_recompute_limits_real_map(t)
	_test_recompute_limits_synthetic_map(t)
	_test_recompute_limits_noop_without_game_data(t)
	_test_visible_rect_basic(t)
	_test_visible_rect_zoom_scaling(t)
	_test_clamp_or_centre(t)
	_test_clamp_target_no_void_at_all_four_corners(t)
	_test_clamp_target_wide_and_tall_aspect(t)
	_test_clamp_target_falls_back_when_map_smaller_than_viewport(t)
	_test_real_zone_frozen_classification_unchanged_by_aspect_ratio(t)
	_test_per_zone_camera_math(t)
	_test_process_direct_follow_without_game_data(t)
	_test_process_smooths_without_engine_camera_smoothing(t)
	_test_process_skips_when_player_invalid(t)
	t.completed(81)


func _approx(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < EPS


## The zoom value is a tuned design decision (see iso_camera.gd's docstring
## for the reasoning), not an accident of the engine default - pin it so a
## future change is a deliberate, visible diff, not a silent regression.
func _test_zoom_decision(t: Object) -> void:
	t.eq(ISO_CAMERA_SCRIPT.BASE_ZOOM, Vector2(1.0, 1.0), "BASE_ZOOM is the tuned 1.0 value (unchanged by ADR-043 - see iso_camera.gd's docstring for the retune investigation that was reverted)")
	t.section_done("zoom decision")


## Cross-checked by hand against IsoProjection.grid_to_screen for the real
## shipped 24x16 fallowfield (farm_map.json v5, the default-zone alias):
## corners project to (0,0), (768,384), (-512,256), (256,640), giving
## bounding box x in [-512,768], y in [0,640] (ADR-043's 64x32 aspect).
func _test_recompute_limits_real_map(t: Object) -> void:
	var gd := GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.eq(gd.get_map_width(), 24, "precondition: fallowfield (default zone) is 24 wide")
	t.eq(gd.get_map_height(), 16, "precondition: fallowfield (default zone) is 16 tall")
	var cam := ISO_CAMERA_SCRIPT.new()
	cam._game_data = gd
	cam._recompute_limits()
	t.eq(cam.limit_left, -512, "limit_left matches the projected NW-ish corner")
	t.eq(cam.limit_right, 768, "limit_right matches the projected E corner")
	t.eq(cam.limit_top, 0, "limit_top matches the projected origin corner")
	t.eq(cam.limit_bottom, 640, "limit_bottom matches the projected S corner")
	cam.free()
	t.section_done("recompute limits, real map")


## A second map size (not the shipped 30x20) to prove the formula is general
## rather than curve-fit to one map, per ADR-032's "no script may assume
## 30x20" boundary. By hand (ADR-043's 64x32 aspect): corners
## (0,0)->(0,0), (10,0)->(320,160), (0,10)->(-320,160), (10,10)->(0,320);
## box x in [-320,320], y in [0,320].
func _test_recompute_limits_synthetic_map(t: Object) -> void:
	var gd := FakeGameData.new()
	gd.w = 10
	gd.h = 10
	var cam := ISO_CAMERA_SCRIPT.new()
	cam._game_data = gd
	cam._recompute_limits()
	t.eq(cam.limit_left, -320, "limit_left for a 10x10 map")
	t.eq(cam.limit_right, 320, "limit_right for a 10x10 map")
	t.eq(cam.limit_top, 0, "limit_top for a 10x10 map")
	t.eq(cam.limit_bottom, 320, "limit_bottom for a 10x10 map")
	cam.free()
	gd.free()
	t.section_done("recompute limits, synthetic map")


func _test_recompute_limits_noop_without_game_data(t: Object) -> void:
	var cam := ISO_CAMERA_SCRIPT.new()
	var default_left: int = cam.limit_left
	cam._game_data = null
	cam._recompute_limits()
	t.eq(cam.limit_left, default_left, "no _game_data leaves Camera2D's own default limits untouched")
	var gd := FakeGameData.new()
	gd.w = 0
	gd.h = 0
	cam._game_data = gd
	cam._recompute_limits()
	t.eq(cam.limit_left, default_left, "zero-sized map dimensions are also a no-op, not a degenerate 0x0 box")
	cam.free()
	gd.free()
	t.section_done("recompute limits, missing data")


func _test_visible_rect_basic(t: Object) -> void:
	var rect: Rect2 = ISO_CAMERA_SCRIPT._visible_rect(Vector2(1280, 720), Vector2(100, 50), Vector2(1, 1))
	t.ok(_approx(rect.position, Vector2(100 - 640, 50 - 360)), "rect is centred on the camera position at zoom 1")
	t.ok(_approx(rect.size, Vector2(1280, 720)), "rect size matches viewport size at zoom 1")
	t.section_done("visible rect basic")


func _test_visible_rect_zoom_scaling(t: Object) -> void:
	var zoomed_in: Rect2 = ISO_CAMERA_SCRIPT._visible_rect(Vector2(1280, 720), Vector2.ZERO, Vector2(2, 2))
	t.ok(_approx(zoomed_in.size, Vector2(640, 360)), "zooming in to 2x halves the visible rect size")
	var zoomed_out: Rect2 = ISO_CAMERA_SCRIPT._visible_rect(Vector2(1280, 720), Vector2.ZERO, Vector2(0.5, 0.5))
	t.ok(_approx(zoomed_out.size, Vector2(2560, 1440)), "zooming out to 0.5x doubles the visible rect size")
	t.section_done("visible rect zoom scaling")


func _test_clamp_or_centre(t: Object) -> void:
	t.ok(absf(ISO_CAMERA_SCRIPT._clamp_or_centre(5.0, 2.0, 20.0) - 5.0) < EPS,
		"a value already inside [margin, span-margin] is returned unchanged")
	t.ok(absf(ISO_CAMERA_SCRIPT._clamp_or_centre(-5.0, 2.0, 20.0) - 2.0) < EPS,
		"a value below the low bound clamps up to margin")
	t.ok(absf(ISO_CAMERA_SCRIPT._clamp_or_centre(50.0, 2.0, 20.0) - 18.0) < EPS,
		"a value above the high bound clamps down to span - margin")
	t.ok(absf(ISO_CAMERA_SCRIPT._clamp_or_centre(5.0, 30.0, 20.0) - 10.0) < EPS,
		"an inverted range (margin > half the span) falls back to the span midpoint")
	t.section_done("clamp or centre")


## The geometric property that actually matters (file docstring's "CLAMPING"
## section): after _clamp_target_to_map, every one of the viewport's four
## screen-space corners must inverse-project into [0, map_w] x [0, map_h].
## Checked at all four grid corners plus the centre, on a map large enough
## relative to the viewport that a void-free position is possible at all.
func _check_no_void(t: Object, label: String, half_extent: Vector2, map_w: int, map_h: int, target_grid: Vector2) -> void:
	var target_screen: Vector2 = ISO_PROJECTION.grid_to_screen(target_grid)
	var clamped_screen: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(target_screen, half_extent, map_w, map_h)
	var centre_grid: Vector2 = ISO_PROJECTION.screen_to_grid(clamped_screen)
	var corner_a: Vector2 = ISO_PROJECTION.screen_to_grid(half_extent)
	var corner_b: Vector2 = ISO_PROJECTION.screen_to_grid(Vector2(half_extent.x, -half_extent.y))
	var corners: Array[Vector2] = [
		centre_grid + corner_a, centre_grid + corner_b,
		centre_grid - corner_b, centre_grid - corner_a,
	]
	for c: Vector2 in corners:
		t.ok(c.x >= -EPS and c.x <= map_w + EPS and c.y >= -EPS and c.y <= map_h + EPS,
			"%s: viewport corner %s stays within the map (no void)" % [label, c])


func _test_clamp_target_no_void_at_all_four_corners(t: Object) -> void:
	# 100x100 is comfortably larger than the viewport at zoom 1.0 (unlike
	# today's 30x20 slice map - see the fallback test below), so a fully
	# void-free camera position exists everywhere the player can stand.
	var half_extent := Vector2(1280, 720) * 0.5
	_check_no_void(t, "NW corner", half_extent, 100, 100, Vector2(0, 0))
	_check_no_void(t, "NE corner", half_extent, 100, 100, Vector2(100, 0))
	_check_no_void(t, "SW corner", half_extent, 100, 100, Vector2(0, 100))
	_check_no_void(t, "SE corner", half_extent, 100, 100, Vector2(100, 100))
	_check_no_void(t, "centre", half_extent, 100, 100, Vector2(50, 50))
	t.section_done("no void at all four map corners")


func _test_clamp_target_wide_and_tall_aspect(t: Object) -> void:
	# CLAUDE.md section 9.3: nothing may assume the 1280x720 base viewport.
	# Re-run the corner containment check at a wide and a tall aspect ratio.
	var wide_half := Vector2(1920, 1080) * 0.5
	_check_no_void(t, "wide viewport, NW corner", wide_half, 100, 100, Vector2(0, 0))
	_check_no_void(t, "wide viewport, SE corner", wide_half, 100, 100, Vector2(100, 100))
	var tall_half := Vector2(800, 1200) * 0.5
	_check_no_void(t, "tall viewport, NW corner", tall_half, 100, 100, Vector2(0, 0))
	_check_no_void(t, "tall viewport, SE corner", tall_half, 100, 100, Vector2(100, 100))
	t.section_done("no void at wide and tall aspect ratios")


## Today's shipped 30x20 slice map projects to a bounding box (1600x1200 at
## zoom 1.0) comparable to the 1280x720 base viewport - the world is not much
## bigger than the screen, so there is genuinely no camera position whose
## full view is void-free (this is a map-size fact, not a clamp bug - see
## the file docstring's closing paragraph). Confirms the graceful
## narrower-band fallback (plan/ADR-032 integration fix, 2026-08-07) rather
## than a crash, NaN, or - the bug this replaced - a single fixed point the
## camera can never move away from regardless of where the player stands.
## Two player positions are checked specifically because that was the actual
## defect: the original always-collapse-to-map-centre version returned the
## identical (15,10) for BOTH, which is what let the bug hide behind a suite
## that only ever checked one target position.
##
func _test_clamp_target_falls_back_when_map_smaller_than_viewport(t: Object) -> void:
	var half_extent := Vector2(1280, 720) * 0.5
	# ADR-043's 64x32 aspect raises the grid-space margin at this zoom to
	# 21.25 on both axes (was 17.5 under the old 64x48 aspect). On this
	# synthetic 30x20 map that puts the Y margin (21.25) at/above the FULL
	# map_h span (20), so gy no longer reaches even the narrower swapped
	# band - it falls all the way to _clamp_or_centre's fixed-midpoint
	# branch and is frozen at 10.0 regardless of the player's position. X's
	# margin (21.25) stays below its span (30), so gx still uses the
	# narrower swapped band and differs between the two cases below. This
	# is exactly the "64x32 makes the map vertically shorter" consequence
	# the conversion guide flags for Phase 2's zoom retune - not a bug in
	# this clamp math.
	# Player near the map's origin corner.
	var origin_screen: Vector2 = ISO_PROJECTION.grid_to_screen(Vector2(0, 0))
	var origin_clamped: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(origin_screen, half_extent, 30, 20)
	var origin_grid: Vector2 = ISO_PROJECTION.screen_to_grid(origin_clamped)
	t.ok(_approx(origin_grid, Vector2(8.75, 10.0)),
		"clamps to the swapped X band and the frozen Y midpoint (8.75,10.0) for a player near the map's origin corner")
	# Player near the map's opposite corner.
	var far_screen: Vector2 = ISO_PROJECTION.grid_to_screen(Vector2(30, 20))
	var far_clamped: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(far_screen, half_extent, 30, 20)
	var far_grid: Vector2 = ISO_PROJECTION.screen_to_grid(far_clamped)
	t.ok(_approx(far_grid, Vector2(21.25, 10.0)),
		"clamps to the swapped X band and the frozen Y midpoint (21.25,10.0) for a player near the map's far corner")
	# The load-bearing assertion: these two must NOT be the same point - a
	# camera that returns one fixed position regardless of the player's
	# location is the exact bug this fallback was rewritten to fix.
	t.not_ok(_approx(origin_grid, far_grid),
		"the camera position differs between the two player positions - it is not frozen at a single fixed point")
	t.section_done("fallback on a map smaller than the viewport")


## Investigation record (see iso_camera.gd's ADR-043 docstring section): a
## BASE_ZOOM retune from 1.0 was tried and reverted after checking real
## zone dimensions (data/farm_map.json, Sprint 15/ADR-034) instead of the
## conversion guide's illustrative 30x20 map. This is that check, pinned as
## a regression test: for every real outdoor zone, whether an axis hits
## _clamp_or_centre's fixed-midpoint branch is IDENTICAL at the old 64x48
## margin (17.5) and the new 64x32 margin (21.25) at BASE_ZOOM 1.0 - the
## aspect change moved the exact margin value but crossed no real zone's
## freeze threshold, so BASE_ZOOM staying at 1.0 costs nothing relative to
## retuning it. Widths/heights hand-copied from data/farm_map.json's
## "zones" block (player_home_interior excluded - it is a small interior
## room by design, not an outdoor field-of-view case).
func _test_real_zone_frozen_classification_unchanged_by_aspect_ratio(t: Object) -> void:
	var old_margin := 17.5  # 64x48 aspect, BASE_ZOOM 1.0
	var new_margin := 21.25  # 64x32 aspect, BASE_ZOOM 1.0 (current)
	var zones: Array[Array] = [
		["fallowfield", 24, 16], ["north_strip", 24, 8],
		["ediths_plot", 16, 14], ["nettleford", 24, 16],
		["manor", 24, 16], ["upland_commons", 32, 14],
		["cottersward", 24, 14], ["nettle_brook", 16, 32],
		["south_fields", 24, 14],
	]
	for z: Array in zones:
		var zone_id: String = z[0]
		var w: float = float(z[1])
		var h: float = float(z[2])
		t.eq(new_margin >= w, old_margin >= w,
			"%s: X-axis frozen classification unchanged by the aspect ratio change" % zone_id)
		t.eq(new_margin >= h, old_margin >= h,
			"%s: Y-axis frozen classification unchanged by the aspect ratio change" % zone_id)
	t.section_done("real zone frozen classification unaffected by ADR-043")


## Sprint 15a (ADR-034, guide risk 10): per-zone dims exercise the clamp
## with one small zone (north_strip, 24x8) and one large zone (nettle_brook,
## 16x32). Both maps are smaller than the viewport, so the assertion is the
## anti-freeze property - two player positions must clamp to two different
## camera points - plus exact projected limits for each zone's bounding box.
func _test_per_zone_camera_math(t: Object) -> void:
	var gd := GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.eq(gd.get_map_width("north_strip"), 24, "north_strip is 24 wide")
	t.eq(gd.get_map_height("north_strip"), 8, "north_strip is 8 tall")
	t.eq(gd.get_map_width("nettle_brook"), 16, "nettle_brook is 16 wide")
	t.eq(gd.get_map_height("nettle_brook"), 32, "nettle_brook is 32 tall")
	var half := Vector2(1280, 720) * 0.5
	var strip_a: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(
		ISO_PROJECTION.grid_to_screen(Vector2(0, 0)), half, 24, 8)
	var strip_b: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(
		ISO_PROJECTION.grid_to_screen(Vector2(23, 7)), half, 24, 8)
	t.not_ok(_approx(ISO_PROJECTION.screen_to_grid(strip_a), ISO_PROJECTION.screen_to_grid(strip_b)),
		"small-zone clamp differs between two player positions (not frozen)")
	var brook_a: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(
		ISO_PROJECTION.grid_to_screen(Vector2(0, 0)), half, 16, 32)
	var brook_b: Vector2 = ISO_CAMERA_SCRIPT._clamp_target_to_map(
		ISO_PROJECTION.grid_to_screen(Vector2(15, 31)), half, 16, 32)
	t.not_ok(_approx(ISO_PROJECTION.screen_to_grid(brook_a), ISO_PROJECTION.screen_to_grid(brook_b)),
		"large-zone clamp differs between two player positions (not frozen)")
	# Bounding boxes by hand (ADR-043's 64x32 aspect - x is TILE_W-derived
	# and unchanged from the old 64x48 aspect; y is TILE_H-derived and
	# scales down by 32/48): 24x8 -> x in [-256,768], y in [0,512];
	# 16x32 -> x in [-1024,512], y in [0,512].
	t.eq(ISO_PROJECTION.grid_to_screen(Vector2(24, 0)).x, 768, "north_strip east corner x")
	t.eq(ISO_PROJECTION.grid_to_screen(Vector2(0, 8)).x, -256, "north_strip west corner x")
	t.eq(ISO_PROJECTION.grid_to_screen(Vector2(16, 0)).x, 512, "nettle_brook east corner x")
	t.eq(ISO_PROJECTION.grid_to_screen(Vector2(0, 32)).x, -1024, "nettle_brook west corner x")
	t.eq(ISO_PROJECTION.grid_to_screen(Vector2(0, 32)).y, 512, "nettle_brook south corner y")
	gd.free()
	t.section_done("per-zone camera math")


func _test_process_direct_follow_without_game_data(t: Object) -> void:
	var player := Node2D.new()
	player.global_position = Vector2(64.0, 32.0)
	var cam := ISO_CAMERA_SCRIPT.new()
	cam._player = player
	cam._game_data = null
	# _game_data == null skips the get_viewport_rect() branch entirely, so
	# this is safe to call on an off-tree camera in this headless harness.
	cam._process(0.016)
	t.ok(_approx(cam.global_position, ISO_PROJECTION.world_to_screen(player.global_position)),
		"an unconfigured camera still directly follows the player's projected position")
	cam.free()
	player.free()
	t.section_done("process, direct follow")


func _test_process_smooths_without_engine_camera_smoothing(t: Object) -> void:
	var player := Node2D.new()
	var cam := ISO_CAMERA_SCRIPT.new()
	cam._player = player
	cam._game_data = null
	cam._camera_smoothing_speed = 100.0
	cam._process(0.016)
	player.global_position = Vector2(320.0, 0.0)
	var target := ISO_PROJECTION.world_to_screen(player.global_position)
	cam._process(0.016)
	t.ok(cam.global_position.x > 0.0 and cam.global_position.x < target.x,
		"manual camera smoothing moves toward a new projected target")
	t.eq(cam.position_smoothing_enabled, false,
		"engine Camera2D smoothing stays disabled on the projection camera")
	t.ok(cam.global_position.is_finite(),
		"manual camera smoothing keeps the camera position finite")
	cam.free()
	player.free()
	t.section_done("process, manual smoothing")


func _test_process_skips_when_player_invalid(t: Object) -> void:
	var cam := ISO_CAMERA_SCRIPT.new()
	cam._player = null
	var before: Vector2 = cam.global_position
	cam._process(0.016)
	t.eq(cam.global_position, before, "a null/invalid _player leaves the camera position untouched")
	cam.free()
	t.section_done("process, invalid player guard")
