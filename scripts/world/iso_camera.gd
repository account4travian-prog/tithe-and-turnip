class_name IsoCamera
extends Camera2D

## Isometric camera (ADR-032, amended ADR-043; plan WS-D): follows the player's *projected*
## screen position, not its logical one, and clamps so the camera's
## rectangular viewport never shows area outside the projected map's
## diamond - not merely inside its screen-space bounding box (see the
## clamp-geometry note below, which is the load-bearing part of this file).
##
## Presentation only: follows in _process, never _physics_process (CLAUDE.md
## section 4/9.7). Runs under normal PROCESS_MODE_INHERIT, so it freezes with
## everything else under pause - main.gd's old camera-follow code lived in
## its own _process for exactly this reason (see that file's history); the
## same reasoning now lives here with the code it explains.
##
## Replaces main.tscn's $Camera2D. That node is left in the scene, disabled
## in main.gd's _ready(), rather than hand-edited out of the .tscn - the same
## precedent as the old $HUD labels documented in main.gd's header docstring.
##
## Frozen by Phase 0, unchanged here: configure() and get_visible_screen_rect()
## are the two methods other workstreams call, both by exact signature.
##
## --- WS-D tuning pass (this file) -----------------------------------------
##
## ZOOM. BASE_ZOOM was 1.0 under ADR-032's original 64x48 aspect, chosen
## deliberately rather than left at the engine default by accident:
##   - At zoom 1.0 a viewport-full grid-space rectangle (IsoProjection's own
##     visible_cells, unclamped by map size) spans ~20x20 grid units, which
##     nets to roughly 16x16 actual cells once visible_cells' own 2-cell
##     cull padding is backed out - a sensible farming-sim field of view,
##     wide enough to read the field, tight enough to keep tiles legible.
##   - The player's collision radius (12 world units, ~0.75 of one 32-unit
##     logical cell - see docs/bootstrap_project.gd) renders at ~48 screen
##     px across at zoom 1.0, comparable to a typical top-down character
##     sprite. Zooming out further (e.g. 0.5) would shrink that to ~24px,
##     hard to read during combat; zooming in buys nothing since the field
##     of view is already reasonable.
##   - TILE_W (64) divides the base viewport width (1280) evenly (20), which
##     only lines up cleanly at zoom 1.0 - a coincidence worth not fighting.
## ADR-043's flatter 64x32 aspect (below) was investigated as a possible
## reason to retune BASE_ZOOM, but checked against the real shipped
## per-zone maps that retune would not have fixed the actual freeze cases
## and was reverted - see the ADR-043 section below for the full
## investigation. BASE_ZOOM stays 1.0, so the FOV/player-legibility
## reasoning above is unchanged, not merely "still holds approximately."
## A single flat BASE_ZOOM (not a table of context-specific values) is
## enough for this slice: nothing in scope changes camera framing by
## context (no cutscenes, no building-placement zoom-out), so a second value
## would be speculative.
##
## SMOOTHING. Player movement is simulated at the fixed 60 Hz physics tick,
## while the camera is rendered at the display rate. Following the raw player
## transform directly therefore produces visible stepping on displays whose
## refresh rate does not line up with 60 Hz. The engine's built-in Camera2D
## smoothing is deliberately disabled: on Godot 4.7.1 with this projected
## camera and an expanded viewport it eventually produced a NaN canvas
## transform, which leaves CanvasLayer UI visible while removing the world.
## The presentation-only interpolation below preserves the intended smooth
## follow without handing the canvas transform to that failing engine path.
## Its speed comes from player.json so it is a tunable rather than a gameplay
## literal.
##
## CLAMPING / THE DIAMOND-VS-RECTANGLE QUESTION. Camera2D's built-in
## limit_left/right/top/bottom (still computed by _recompute_limits(), kept
## as an outer safety net - see below) are four INDEPENDENT scalar bounds,
## i.e. an axis-aligned rectangle. The projected map is a diamond inscribed
## in that rectangle, tangent to it only at the four grid corners. A diamond
## touches its own bounding box at single points, not edges, so there are
## four triangular gaps between the diamond's edges and the bounding
## rectangle's corners - and a rectangular scalar clamp cannot see those
## gaps, because x and y are clamped independently of each other. Concretely
## (worked for the 30x20 slice map at zoom 1.0, viewport 1280x720): clamping
## the camera to the bounding box still lets its view show ~160px of void on
## each side when centred over a map edge near a corner - about an eighth of
## the screen width, on both sides, not a rounding-error case.
##
## The fix is _clamp_target_to_map() below: instead of clamping the camera'
## SCREEN position against a screen-space box, it inverse-projects the
## viewport's own half-extent into grid space (screen_to_grid is linear, so
## this needs only two of the four viewport corners - the other two are
## their negations) and clamps the camera's GRID-space centre so all four
## viewport corners land inside [0, map_w] x [0, map_h] before projecting
## back to screen space. That is the geometrically correct confiner for a
## rectangular viewport inside a linearly-projected rectangular map, and it
## is what actually satisfies "no void at any of the four map edges" - the
## bounding-box limit_* alone do not, and no amount of retuning its four
## scalars fixes that, because the defect is that they are independent.
##
## One case no camera clamp can fully solve: when the map is smaller than
## the viewport at the current zoom (true of today's 30x20 slice map at
## zoom 1.0 - under ADR-032's original 64x48 aspect the whole map's
## projected bounding box was 1600x1200, comparable to the 1280x720
## viewport). Integration-testing this against the live editor (2026-08-07)
## found the ORIGINAL version of this fix collapsed to a single fixed point
## - map_w=30 and map_h=20 both put half the map span (15 and 10) below the
## required margin (17.5 on both axes at that aspect/zoom), so BOTH axes hit
## the degenerate branch simultaneously and the camera never moved at all,
## regardless of the player's position. A camera that never follows the
## player is a worse failure than a little unavoidable void, so
## _clamp_or_centre() below only collapses to a fixed point when the margin
## exceeds the FULL map span (truly impossible to show any of the map
## without void on that axis); when the margin is merely more than half the
## span, it clamps to the narrower, swapped range [span - margin, margin]
## instead, which is still a valid, non-empty band and lets the camera move
## within it rather than freezing.
##
## ADR-043 (2026-08-10) changed the tile aspect to 64x32, which raises the
## grid-space margin at BASE_ZOOM 1.0/1280x720 from 17.5 (old 64x48) to
## 21.25 - shared between axes because it comes from mixing both
## screen-space half-extents through the isometric inverse transform; see
## _clamp_target_to_map's docstring. The guide's own Phase 1/2 planning used
## an illustrative 30x20 map for this arithmetic (ADR-032's original flat
## property map), under which the Y margin newly reaches the full map_h span
## (20) at 21.25, suggesting a Phase-2 zoom retune was needed to stop a new
## freeze.
##
## **Checked against the real, shipped per-zone maps (Sprint 15/ADR-034,
## data/farm_map.json) instead of that illustrative figure, and the
## conclusion changes.** Every outdoor zone's shorter dimension is already
## at or below the OLD margin (17.5): fallowfield/nettleford/manor are
## 24x16, north_strip is 24x8, ediths_plot is 16x14, upland_commons/
## cottersward/south_fields are ~24-32 wide x14 tall, nettle_brook is
## 16x32. Comparing old-margin (17.5) vs new-margin (21.25) against every
## real zone's width/height shows the frozen/non-frozen classification is
## IDENTICAL before and after ADR-043 for all nine outdoor zones - none of
## their dimensions fall in the (17.5, 21.25) gap the aspect change opened
## up. fallowfield's Y axis (and every ~14-16-tall zone's Y axis) was
## already hitting _clamp_or_centre's fixed-midpoint branch under the OLD
## 64x48 aspect, before this ADR existed; ediths_plot's and nettle_brook's
## X axis likewise. This is a pre-existing characteristic of how small
## Sprint 15 made the individual zones, not a regression this aspect
## change introduces or worsens in kind - the margin's exact value moved,
## but not across any real zone's threshold.
##
## A BASE_ZOOM retune was tried and reverted for this reason: escaping the
## freeze for the SMALLEST real zone (north_strip, 8 tall) needs
## margin < 8, i.e. zoom > 21.25/8 = 2.66 - a field-of-view cut steep
## enough to hurt every zone, in exchange for fixing none of the
## ~14-16-tall zones (still need zoom > 21.25/14 = 1.52 at minimum) while
## leaving north_strip itself still frozen below zoom 2.66. No single
## global zoom value makes real, practical progress here; BASE_ZOOM stays
## at 1.0, unchanged from Phase 1. Per-axis centering when a zone is
## shorter/narrower than the viewport is not a bug in `_clamp_or_centre` -
## it is the intended, correct fallback for a map smaller than the camera's
## field of view (see that function's own docstring); the real, separate
## question of whether Sprint 15's zones should be larger is out of scope
## for this presentation-only ADR and is flagged to the owner rather than
## patched here.

const BASE_ZOOM: Vector2 = Vector2(1.0, 1.0)

var _player: Node2D
var _game_data: Node
## Sprint 15b: explicit per-zone dimensions supplied by main.gd's
## zone_changed handler. (-1, -1) means "read GameData's default-zone dims",
## the boot behavior.
var _map_dims_override := Vector2i(-1, -1)
## Presentation-only smoothing rate in screen pixels per second. It is read
## from player.json and applied by the manual interpolation path because the
## built-in Camera2D smoothing path is unsafe for this projected viewport.
var _camera_smoothing_speed: float = 0.0
## False until the first target is known, so startup and zone crossings snap
## to the active player rather than animating from the old zone's camera.
var _has_smoothed_position: bool = false


func configure(player: Node2D, game_data: Node) -> void:
	_player = player
	_game_data = game_data
	_map_dims_override = Vector2i(-1, -1)
	zoom = BASE_ZOOM
	# Godot 4.7.1's built-in smoothing can eventually write NaN into the
	# canvas transform here; manual presentation smoothing below avoids it.
	position_smoothing_enabled = false
	_camera_smoothing_speed = 0.0
	if _game_data != null:
		_camera_smoothing_speed = float(_game_data.player_cfg.get(
			"camera_smoothing_speed", 600.0))
	_has_smoothed_position = false
	_recompute_limits()
	make_current()


## Sprint 15b: the active zone's map dimensions, overriding the
## default-zone GameData read in _process/_recompute_limits. IsoCamera has
## no way to know "which zone" on its own, so main.gd supplies the values
## explicitly on every zone change.
func set_map_dims(width: int, height: int) -> void:
	_map_dims_override = Vector2i(width, height)
	_has_smoothed_position = false
	_recompute_limits()


## The dimensions currently in effect: the zone override when set, else
## GameData's default-zone dims (fallowfield at boot).
func get_map_dims() -> Vector2i:
	if _map_dims_override.x >= 0 and _map_dims_override.y >= 0:
		return _map_dims_override
	if _game_data != null:
		return Vector2i(_game_data.get_map_width(), _game_data.get_map_height())
	return Vector2i.ZERO


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		return
	var target: Vector2 = IsoProjection.world_to_screen(_player.global_position)
	if _game_data != null:
		var half_extent: Vector2 = (get_viewport_rect().size / zoom) * 0.5
		var dims := get_map_dims()
		var map_w := dims.x
		var map_h := dims.y
		target = _clamp_target_to_map(target, half_extent, map_w, map_h)
	if not _has_smoothed_position:
		global_position = target
		_has_smoothed_position = true
		return
	if _camera_smoothing_speed <= 0.0 or delta <= 0.0:
		global_position = target
		return
	global_position = global_position.move_toward(
		target, _camera_smoothing_speed * delta)


## WS-A's terrain culling seam (IsometricConversion.md section 2.2): the
## camera's current screen-space visible rect, in the same coordinate space
## IsoProjection consumes. Frozen signature - WS-A depends on it existing.
## Delegates to the pure helper below so the size/zoom math is testable
## without a live viewport (see tests/suites/test_iso_camera.gd).
func get_visible_screen_rect() -> Rect2:
	return _visible_rect(get_viewport_rect().size, global_position, zoom)


static func _visible_rect(viewport_size: Vector2, centre: Vector2, cam_zoom: Vector2) -> Rect2:
	var vp_size: Vector2 = viewport_size / cam_zoom
	return Rect2(centre - vp_size * 0.5, vp_size)


## The geometrically correct camera confiner for a rectangular viewport
## inside a linearly-projected rectangular map - see the file docstring's
## "CLAMPING" section for the full reasoning. Pure and static so it is
## testable without a scene tree or live viewport: every input is a plain
## value, nothing is read from `self`.
##
## `half_extent` is the camera's screen-space half-viewport (already divided
## by zoom). Because IsoProjection.screen_to_grid is linear (no translation),
## the viewport's four screen-space corners map to `centre_grid + one of
## {corner_a, corner_b, -corner_b, -corner_a}` in grid space - two inverse
## projections are enough to characterise all four.
static func _clamp_target_to_map(target: Vector2, half_extent: Vector2, map_w: int, map_h: int) -> Vector2:
	if map_w <= 0 or map_h <= 0:
		return target
	var corner_a: Vector2 = IsoProjection.screen_to_grid(half_extent)
	var corner_b: Vector2 = IsoProjection.screen_to_grid(Vector2(half_extent.x, -half_extent.y))
	var margin_x: float = maxf(absf(corner_a.x), absf(corner_b.x))
	var margin_y: float = maxf(absf(corner_a.y), absf(corner_b.y))
	var g: Vector2 = IsoProjection.screen_to_grid(target)
	var gx: float = _clamp_or_centre(g.x, margin_x, float(map_w))
	var gy: float = _clamp_or_centre(g.y, margin_y, float(map_h))
	return IsoProjection.grid_to_screen(Vector2(gx, gy))


## Clamps `value` into `[margin, span - margin]` when that range is valid.
## When `margin` exceeds half of `span` (the viewport's half-extent on this
## axis is more than half the map - the map is smaller than the screen at
## the current zoom), that range is inverted; rather than collapsing straight
## to a single fixed point, this first tries the SWAPPED range
## `[span - margin, margin]`, which is still valid and non-empty as long as
## `margin < span` (true whenever the map is at least as big as the required
## clearance on one side) - it gives the camera real, if narrower, room to
## follow the player instead of freezing outright. Only when `margin >= span`
## (the required clearance exceeds the ENTIRE map - clearance impossible on
## that axis) does it fall back to the fixed midpoint, the last resort. See
## the file docstring's closing paragraph for why the original always-
## collapse-to-midpoint version was wrong for the shipped 30x20 map at zoom
## 1.0, where it made the camera never move at all.
static func _clamp_or_centre(value: float, margin: float, span: float) -> float:
	var low: float = margin
	var high: float = span - margin
	if low > high:
		if margin >= span:
			return span * 0.5
		return clampf(value, high, low)
	return clampf(value, low, high)


## limit_enabled defaults to true on a fresh Camera2D (verified against the
## live 4.7.1 binary via ClassDB during Phase 0), so setting the four
## limit_* bounds is sufficient - no separate enable step. Kept as an outer
## safety net beneath _clamp_target_to_map(): it bounds the camera to the
## map's true screen-space bounding box (so a bug or an unconfigured
## _game_data path can never scroll arbitrarily far off-map), but it is not
## itself sufficient to prevent void at the diamond's four corners - see the
## file docstring's "CLAMPING" section for why, and _clamp_target_to_map()
## for the fix that actually satisfies that requirement.
func _recompute_limits() -> void:
	if _game_data == null:
		return
	var dims := get_map_dims()
	var w := dims.x
	var h := dims.y
	if w <= 0 or h <= 0:
		return
	var corners: Array[Vector2] = [
		IsoProjection.grid_to_screen(Vector2(0, 0)),
		IsoProjection.grid_to_screen(Vector2(w, 0)),
		IsoProjection.grid_to_screen(Vector2(0, h)),
		IsoProjection.grid_to_screen(Vector2(w, h)),
	]
	var min_x: float = corners[0].x
	var max_x: float = corners[0].x
	var min_y: float = corners[0].y
	var max_y: float = corners[0].y
	for c: Vector2 in corners:
		min_x = minf(min_x, c.x)
		max_x = maxf(max_x, c.x)
		min_y = minf(min_y, c.y)
		max_y = maxf(max_y, c.y)
	limit_left = int(min_x)
	limit_right = int(max_x)
	limit_top = int(min_y)
	limit_bottom = int(max_y)
