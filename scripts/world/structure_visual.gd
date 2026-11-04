class_name StructureVisual
extends Node2D

## Visual proxy for one isometric structure (ADR-032, amended ADR-043; plan section 3 / WS-B).
## Draws a footprint-sized floor diamond extruded upward into two shaded
## vertical wall faces (IsoProjection.cell_diamond's corner formula
## generalised from a single cell to an arbitrary Rect2i footprint - the
## projection is linear, per iso_projection.gd's own docstring, so the same
## four-corner formula applies unchanged), so a structure spanning more than
## one cell reads as a 3D box under Y-sort instead of the flat top-down rect
## FeatureRenderer/BuildingRenderer used to draw directly from a single
## _draw() call. Must be parented as a DIRECT child of WorldVisuals (CLAUDE.md
## trap 10) - FeatureRenderer and BuildingRenderer each construct and
## configure one instance per structure; neither draws a structure itself
## any more.
##
## ADR-041 (Sprint 16 WS-B): when configure() receives a manifest entry
## (data/sprites_structures.json, resolved by the caller through GameData -
## BuildingRenderer already holds the GameData reference, so it passes
## GameData.get_sprite(building_id) rather than making this node reach for
## /root/GameData), this proxy renders a Sprite2D child built by
## SpriteManifest and _draw() renders nothing - the PlayerVisual pattern
## applied to structures. The primitive extruded-box below remains the
## automatic fallback for every building id without a manifest entry (or
## when the entry's texture cannot be loaded), per ADR-041's "primitives
## remain where no asset exists" rule. `sprite_id` is kept as bookkeeping so
## callers and tests can assert which id produced which visual.
##
## Sort depth: `position` is set to the screen point of the footprint's
## south-east-most grid corner (`footprint.end`), the corner nearest the
## camera - the same "feet" convention ActorVisual uses for actors
## (IsoProjection.world_to_screen(owner.global_position) tracks a single
## point). Every local draw call therefore happens at y <= 0 (up-screen, away
## from the camera) or straddles x either side of that point. y_sort_enabled
## on WorldVisuals compares this single point against every actor's own
## projected position (CLAUDE.md 9.7), so an actor standing behind
## (screen-north of) a structure's footprint sorts underneath it and one
## standing in front sorts on top, with no manual z_index scheme layered on
## top - resist adding one, per the plan's warning that the two fight.
## SpriteManifest.apply_static uses the same anchor formula (child
## position = -anchor * scale, anchor pixel on this node's origin), so a
## textured building keeps the same sort origin the primitive used.
##
## Collision is NOT part of this class. FeatureRenderer's StaticBody2D
## fixtures stay in logical space exactly as built pre-ADR-032; nothing here
## reads or writes a collision shape, and this node has none of its own.

## What extra ornamentation (if any) _draw() layers onto the roof face or
## near walls, on top of the plain extruded box every structure gets.
enum Accent {
	NONE,   ## generic box, no ornamentation (placed buildings, the ghost)
	HOUSE,  ## a bed on the roof face
	WELL,   ## rim + water circles on the roof face
	CHEST,  ## a lid + clasp on the roof face
	STALL,  ## a counter band low on the two near walls
	BOARD,  ## horizontal planks + post on the roof face (the town board)
}

## Neutral near-black trim used for every outline/hatch line regardless of a
## structure's own fill colour - matches the flat look FeatureRenderer's
## pre-ADR-032 COLOR_WALL_EDGE gave every fixture a consistent trim.
const EDGE_COLOR := Color(0.12, 0.09, 0.07, 0.85)
const SIDE_WALL_DARKEN: float = 0.30
const FAR_WALL_DARKEN: float = 0.50
const OUTLINE_WIDTH: float = 1.5
const HATCH_STEP: float = 8.0
const HATCH_COLOR := Color(0.0, 0.0, 0.0, 0.35)
const HOUSE_DOOR_COLOR := Color(0.22, 0.12, 0.06, 0.98)
const HOUSE_DOOR_TRIM := Color(0.82, 0.62, 0.28, 0.95)
## ADR-041: the textured child's only in-progress treatment. The primitive
## hatch below still covers the no-texture fallback; a real sprite cannot be
## hatched without drawing a primitive over it, so dimming the whole sprite
## (same "under construction" message, zero extra geometry) is the textured
## equivalent.
const IN_PROGRESS_MODULATE := Color(1.0, 1.0, 1.0, 0.65)

var footprint: Rect2i = Rect2i(0, 0, 1, 1)
var wall_height: float = 0.0
var top_color: Color = Color.WHITE
var accent: int = Accent.NONE
var accent_primary: Color = Color.WHITE
var accent_secondary: Color = Color.WHITE
var in_progress: bool = false
var draw_outline: bool = true
## ADR-041: the manifest id this proxy was configured with ("" = no texture,
## primitive fallback). Bookkeeping for callers/tests; the actual entry is
## resolved by the caller (BuildingRenderer holds GameData) and passed in.
var sprite_id := ""

var _sprite: Sprite2D
var _texture_active := false


## Sets footprint/appearance and repositions to the new footprint's screen
## anchor in one call - the shape every caller needs whether this is the
## first configure() (a fixed fixture, a newly-placed building) or a
## re-configure (the ghost reconfigures every time the player's faced tile
## or the selected building changes).
##
## `new_sprite_id`/`new_sprite_entry` (ADR-041) are the optional textured
## child: the id for bookkeeping, the entry already parsed by the caller
## (BuildingRenderer passes GameData.get_sprite(building_id)). Callers that
## pass neither (fixed fixtures, the ghost) keep the primitive extruded box;
## an empty entry with a non-empty id means "no asset for this building" and
## falls back identically.
func configure(new_footprint: Rect2i, color: Color, height: float,
		new_accent: int = Accent.NONE, primary: Color = Color.WHITE, secondary: Color = Color.WHITE,
		new_sprite_id: String = "", new_sprite_entry: Dictionary = {}) -> void:
	footprint = new_footprint
	top_color = color
	wall_height = height
	accent = new_accent
	accent_primary = primary
	accent_secondary = secondary
	position = IsoProjection.grid_to_screen(Vector2(footprint.end.x, footprint.end.y))
	sprite_id = new_sprite_id
	_apply_sprite_entry(new_sprite_entry)
	queue_redraw()


## Recolours without touching footprint/height/accent - the market stall's
## open/shut toggle is the only structure whose colour changes after it is
## first built, so it does not need a full configure() every market tick.
## Textured visuals ignore this: their palette comes from the sprite, and
## the stall has no manifest entry this sprint.
func set_top_color(color: Color) -> void:
	top_color = color
	queue_redraw()


## In-progress buildings draw dimmer with a construction hatch overlay,
## matching the pre-ADR-032 look. Complete buildings and fixed manor
## fixtures never call this, so the default (false) is already correct for
## them. Textured visuals dim via IN_PROGRESS_MODULATE instead of the hatch.
func set_in_progress(value: bool) -> void:
	in_progress = value
	if _texture_active and _sprite != null:
		_sprite.modulate = IN_PROGRESS_MODULATE if value else Color.WHITE
	queue_redraw()


func _draw() -> void:
	# ADR-041: with a live textured child there is nothing for the primitive
	# path to draw - the same "no primitive left under a real asset" rule
	# PlayerVisual follows.
	if _texture_active:
		return
	var corners := _local_diamond()
	var top: Vector2 = corners[0]
	var right: Vector2 = corners[1]
	var bottom: Vector2 = corners[2]
	var left: Vector2 = corners[3]
	var up := Vector2(0.0, -wall_height)

	var alpha := 0.5 if in_progress else top_color.a
	var fill := Color(top_color.r, top_color.g, top_color.b, alpha)
	var right_wall := fill.darkened(SIDE_WALL_DARKEN)
	var left_wall := fill.darkened(FAR_WALL_DARKEN)

	# The two near faces only exist if there is height to extrude - the
	# ghost and any zero-height caller stay a flat diamond.
	if wall_height > 0.0:
		draw_colored_polygon(PackedVector2Array([right, bottom, bottom + up, right + up]), right_wall)
		draw_colored_polygon(PackedVector2Array([left, bottom, bottom + up, left + up]), left_wall)

	var roof := PackedVector2Array([top + up, right + up, bottom + up, left + up])
	draw_colored_polygon(roof, fill)

	match accent:
		Accent.HOUSE:
			_draw_house_accent(roof, right, bottom, up)
		Accent.WELL:
			_draw_well_accent(roof)
		Accent.CHEST:
			_draw_chest_accent(roof)
		Accent.STALL:
			_draw_stall_accent(right, bottom, left, up)
		Accent.BOARD:
			_draw_board_accent(roof)
		Accent.NONE:
			pass

	if in_progress:
		_draw_hatch(roof)

	if draw_outline:
		draw_polyline(PackedVector2Array([roof[0], roof[1], roof[2], roof[3], roof[0]]), EDGE_COLOR, OUTLINE_WIDTH)
		if wall_height > 0.0:
			draw_polyline(PackedVector2Array([right, bottom, left]), EDGE_COLOR, OUTLINE_WIDTH)


## Applies an already-parsed manifest entry (the caller resolves it through
## GameData; tests call this directly with a GameData-derived entry - the
## same off-tree convention test_iso_structures.gd uses for private renderer
## state). apply_static hides the sprite and reports failure when the
## texture cannot be built, so _texture_active stays false and _draw() falls
## back to primitives.
func _apply_sprite_entry(entry: Dictionary) -> void:
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	_texture_active = SpriteManifest.apply_static(_sprite, entry)
	if _texture_active:
		_sprite.modulate = IN_PROGRESS_MODULATE if in_progress else Color.WHITE


## The four screen corners of `footprint`'s bounding diamond, in this node's
## local space (i.e. relative to `position`, which sits at the `bottom`
## corner computed here - see the class docstring). Generalises
## IsoProjection.cell_diamond from a single cell to an arbitrary footprint
## rect; grid_to_screen is linear (no translation term - iso_projection.gd's
## own docstring), so the identical corner formula applies unchanged to a
## multi-cell rect, not just a unit cell.
func _local_diamond() -> PackedVector2Array:
	var fx := float(footprint.position.x)
	var fy := float(footprint.position.y)
	var fx1 := float(footprint.end.x)
	var fy1 := float(footprint.end.y)
	var origin := IsoProjection.grid_to_screen(Vector2(fx1, fy1))
	return PackedVector2Array([
		IsoProjection.grid_to_screen(Vector2(fx, fy)) - origin,   # top
		IsoProjection.grid_to_screen(Vector2(fx1, fy)) - origin,  # right
		Vector2.ZERO,                                             # bottom (== position)
		IsoProjection.grid_to_screen(Vector2(fx, fy1)) - origin,  # left
	])


func _draw_house_accent(roof: PackedVector2Array, right: Vector2, bottom: Vector2, up: Vector2) -> void:
	var centre: Vector2 = (roof[0] + roof[1] + roof[2] + roof[3]) / 4.0
	# Nudged toward the roof's "top" (north-most, farthest-from-camera)
	# corner so the bed reads as sitting against the house's back wall.
	var bed_centre := centre + (roof[0] - centre) * 0.35
	var frame := Rect2(bed_centre - Vector2(14, 9), Vector2(28, 18))
	draw_rect(frame, accent_primary)
	var linen := Rect2(frame.position + Vector2(3, 3), frame.size - Vector2(6, 6))
	draw_rect(linen, accent_secondary)
	draw_rect(frame, EDGE_COLOR, false, 1.0)
	# The farmhouse doorway is on the south wall, the near lower-left face
	# from bottom to left in the isometric footprint. FeatureRenderer opens the
	# matching data-defined collision gap on this same side.
	var door_start := bottom.lerp(roof[3], 0.32)
	var door_end := bottom.lerp(roof[3], 0.68)
	var door_up := up * 0.62
	draw_colored_polygon(PackedVector2Array([
		door_start, door_end, door_end + door_up, door_start + door_up]),
		HOUSE_DOOR_COLOR)
	draw_polyline(PackedVector2Array([
		door_start, door_end, door_end + door_up, door_start + door_up, door_start]),
		HOUSE_DOOR_TRIM, 1.5)


func _draw_well_accent(roof: PackedVector2Array) -> void:
	var centre: Vector2 = (roof[0] + roof[1] + roof[2] + roof[3]) / 4.0
	draw_circle(centre, 11.0, EDGE_COLOR)
	draw_circle(centre, 7.0, accent_primary)


func _draw_chest_accent(roof: PackedVector2Array) -> void:
	var centre: Vector2 = (roof[0] + roof[1] + roof[2] + roof[3]) / 4.0
	var lid := Rect2(centre - Vector2(12, 4), Vector2(24, 8))
	draw_rect(lid, accent_primary)
	var clasp := Rect2(centre - Vector2(2, 6), Vector2(4, 6))
	draw_rect(clasp, accent_primary.darkened(0.25))


func _draw_stall_accent(right: Vector2, bottom: Vector2, left: Vector2, up: Vector2) -> void:
	# A counter band low on the two near walls - the same visual role the
	## pre-ADR-032 stall's flat "counter" rect played, translated onto the
	## extruded faces instead of a top-down rect.
	var band_up := up * 0.3
	draw_colored_polygon(PackedVector2Array([right, bottom, bottom + band_up, right + band_up]), accent_primary)
	draw_colored_polygon(PackedVector2Array([left, bottom, bottom + band_up, left + band_up]), accent_primary.darkened(SIDE_WALL_DARKEN))


## A town notice board: two horizontal planks on the roof face held by a
## centre post - same loose geometric fidelity as the chest/stall accents.
func _draw_board_accent(roof: PackedVector2Array) -> void:
	var centre: Vector2 = (roof[0] + roof[1] + roof[2] + roof[3]) / 4.0
	var upper_plank := Rect2(centre - Vector2(15, 3), Vector2(30, 4))
	var lower_plank := Rect2(centre - Vector2(15, 3), Vector2(30, 4))
	lower_plank.position.y += 8.0
	draw_rect(upper_plank, accent_primary)
	draw_rect(lower_plank, accent_primary.darkened(0.15))
	var post := Rect2(centre - Vector2(1.5, 8), Vector2(3, 16))
	draw_rect(post, accent_secondary)


## Diagonal hatch across the roof face's bounding box - an approximation
## (it is not clipped to the diamond's exact edges) that matches the loose
## fidelity the pre-ADR-032 hatch already had over its own bounding rect.
func _draw_hatch(roof: PackedVector2Array) -> void:
	var min_x: float = roof[3].x
	var min_y: float = roof[0].y
	var max_y: float = roof[2].y
	var span := (roof[1].x - roof[3].x) + (max_y - min_y)
	var steps := int(span / HATCH_STEP)
	for i in range(steps):
		var start := Vector2(min_x + i * HATCH_STEP, min_y)
		var end := Vector2(min_x, min_y + i * HATCH_STEP)
		draw_line(start, end, HATCH_COLOR, 1.0)
