class_name IsoProjection
extends RefCounted

## The ADR-032 projection seam - the ONLY place a grid or world coordinate
## becomes a screen coordinate, or vice versa (CLAUDE.md section 8's
## presentation-only invariant; section 9.7). Every constant and formula here
## is frozen by IsometricConversion.md's Phase 0 - workstreams call these
## functions and do not reimplement them. All static; nothing here holds
## state, so no instance is ever needed.
##
## The map from grid space to screen space is linear (no translation): both
## grid_to_screen and world_to_screen are matrix multiplies with no added
## offset. That is what makes it valid to also run direction vectors (not
## just positions) through the same functions - see input_to_world_dir.
##
## ADR-043 (2026-08-10): the tile aspect changed from the original ADR-032
## dimetric `64x48` (2:1.33, chosen for structure headroom before this
## project had any art) to standard `64x32` 2:1 isometric, so commercial/
## found modular isometric art packs have a realistic integration path.
## Every other ADR-032 ruling - presentation-only, this single seam,
## screen-relative input, 8-way facing, y_sort depth ordering - is
## unaffected; only TILE_H changed.

## Screen width/height of one cell's diamond (CLAUDE.md section 1). Standard
## 2:1 isometric (ADR-043) - TILE_W is exactly double TILE_H.
const TILE_W: float = 64.0
const TILE_H: float = 32.0

## World-unit size of one grid cell in the (unchanged) logical simulation
## space. Physics, collision, and saves are expressed in this unit.
const LOGICAL_CELL: float = 32.0

## Active-item aiming uses the player's screen controls as the compass: W/S
## select the north/south grid faces and A/D select west/east. This is an
## input convention, not a second coordinate projection; ordinary movement
## continues to use input_to_world_dir() below.
const AIM_INPUT_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const AIM_INPUT_DEADZONE_SQ: float = 0.0001

## visible_cells() pads the inverse-projected camera rect by this many cells
## on every side, so a structure whose footprint origin is off-screen but
## whose drawn body is not still gets culled in, not out.
const CULL_PADDING: int = 2


## Fractional grid coordinates -> screen coordinates.
static func grid_to_screen(g: Vector2) -> Vector2:
	return Vector2((g.x - g.y) * (TILE_W / 2.0), (g.x + g.y) * (TILE_H / 2.0))


## Screen coordinates -> fractional grid coordinates. Inverse of grid_to_screen.
static func screen_to_grid(s: Vector2) -> Vector2:
	var gx := (s.x / (TILE_W / 2.0) + s.y / (TILE_H / 2.0)) / 2.0
	var gy := (s.y / (TILE_H / 2.0) - s.x / (TILE_W / 2.0)) / 2.0
	return Vector2(gx, gy)


## Logical world units -> screen coordinates.
static func world_to_screen(w: Vector2) -> Vector2:
	return grid_to_screen(w / LOGICAL_CELL)


## Screen coordinates -> logical world units. Inverse of world_to_screen.
static func screen_to_world(s: Vector2) -> Vector2:
	return screen_to_grid(s) * LOGICAL_CELL


## The four screen corners of grid cell `cell` (occupying grid square
## [x, x+1] x [y, y+1]), wound top/right/bottom/left. Cell (0,0) therefore
## winds (0,0) -> (32,16) -> (0,32) -> (-32,16) at the default tile size.
static func cell_diamond(cell: Vector2i) -> PackedVector2Array:
	var gx := float(cell.x)
	var gy := float(cell.y)
	return PackedVector2Array([
		grid_to_screen(Vector2(gx, gy)),        # top
		grid_to_screen(Vector2(gx + 1.0, gy)),  # right
		grid_to_screen(Vector2(gx + 1.0, gy + 1.0)), # bottom
		grid_to_screen(Vector2(gx, gy + 1.0)),  # left
	])


## Screen-space centre of grid cell `cell`.
static func cell_centre_screen(cell: Vector2i) -> Vector2:
	return grid_to_screen(Vector2(cell.x + 0.5, cell.y + 0.5))


## The Stardew convention (ADR-032): rotates a screen-space input vector
## (as InputManager.get_movement_vector() returns) into a logical-space
## direction, so pressing "up" always moves the player visibly up on screen.
## Because the projection is linear, this also means apparent on-screen
## speed is constant in every direction - grid-space speed is not (plan
## section 2.1, a documented and deliberate divergence, not a bug).
static func input_to_world_dir(screen_vec: Vector2) -> Vector2:
	return screen_to_grid(screen_vec) * LOGICAL_CELL


## Resolves active-item cursor input in screen-control space rather than
## projected movement space. This makes W unambiguously North (grid -Y) and S
## unambiguously South (grid +Y), while diagonal input still reaches the four
## diagonal cells one at a time.
static func input_to_aim_grid_dir(screen_vec: Vector2) -> Vector2i:
	if screen_vec.length_squared() < AIM_INPUT_DEADZONE_SQ:
		return Vector2i.ZERO
	var angle := screen_vec.angle()
	if angle < 0.0:
		angle += TAU
	var raw_sector := angle / (TAU / 8.0)
	var sector := int(floor(raw_sector + 0.5)) % 8
	return AIM_INPUT_NEIGHBOURS[sector]


## WS-A's terrain culling seam (plan section 2.2): inverse-projects the
## camera's screen-space rect, takes the grid-space bounding box, pads by
## CULL_PADDING cells on every side, and clamps to the map bounds. The
## bounding box of the inverse-projected corners over-selects cells near the
## diamond's corners - deliberate and cheap; do not tighten this into a
## per-row scan without a measured reason.
static func visible_cells(screen_rect: Rect2, map_w: int, map_h: int) -> Rect2i:
	var corners: Array[Vector2] = [
		screen_rect.position,
		screen_rect.position + Vector2(screen_rect.size.x, 0.0),
		screen_rect.position + Vector2(0.0, screen_rect.size.y),
		screen_rect.end,
	]
	var min_g := screen_to_grid(corners[0])
	var max_g := min_g
	for c: Vector2 in corners:
		var g := screen_to_grid(c)
		min_g.x = minf(min_g.x, g.x)
		min_g.y = minf(min_g.y, g.y)
		max_g.x = maxf(max_g.x, g.x)
		max_g.y = maxf(max_g.y, g.y)

	var gx0 := maxi(floori(min_g.x) - CULL_PADDING, 0)
	var gy0 := maxi(floori(min_g.y) - CULL_PADDING, 0)
	var gx1 := mini(ceili(max_g.x) + CULL_PADDING, map_w)
	var gy1 := mini(ceili(max_g.y) + CULL_PADDING, map_h)

	return Rect2i(gx0, gy0, maxi(gx1 - gx0, 0), maxi(gy1 - gy0, 0))
