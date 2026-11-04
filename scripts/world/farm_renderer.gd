class_name FarmRenderer
extends Node2D

## Draws the farm grid from FarmGrid state as an isometric field (ADR-032,
## amended ADR-043):
## soil diamonds, tilled darkening, moisture overlay, crop dots, and a
## diamond-lattice grid, all projected through IsoProjection - the ONLY
## screen-space math in this file, per CLAUDE.md section 8's invariant.
## Redraws only on tile_changed or when the camera's visible cull rectangle
## changes (via _request_redraw's queue_redraw), never per-frame from the
## crop/soil data itself - _process() here exists solely to poll the camera's
## position for the redraw trigger, which is presentation, not gameplay state
## (CLAUDE.md section 4).
## ADR-040: demesne tiles carrying a stored-sheaf marker draw a small amber
## bundle so the spatial harvest chore has a visible affordance - same
## geometric-primitives convention as the crop dots.
## Sprint 16 WS-A (ADR-041): forage spawn points (ADR-022) keep their
## primitive glyphs as the fallback but gain a textured StaticPropVisual
## proxy when data/sprites_world_dressing.json carries an entry - the same
## exact spawn point, one proxy per forage-bearing cell under WorldVisuals,
## so the asset y-sorts against the player like every other world proxy.
## ADR-042 (textured terrain): a cell's surface is now a terrain rendering
## SYSTEM, not a flat-color-to-texture swap - deterministic variant
## selection, adjacency-aware edge transitions, and a scatter/decal layer,
## all keyed off data/terrain_manifest.json through GameData, with moisture
## as a wet-soil material (blended toward) instead of a blue alpha wash and
## the diamond lattice contextual (tilled cells only) instead of always-on.
## Every textured path fails soft to the EXACT pre-ADR-042 flat-color fills
## (soil color polygon, tilled darkening, blue moisture wash) when the
## manifest data is absent - terrain_cell_plan() is the single routing
## decision, and _draw_flat_cell() is the untouched pre-ADR-042 inline code.
##
## Same-grid vs dual-grid (the ADR-042 design decision, see
## terrain_cell_plan()): this implementation samples each cell's four
## EDGE-ADJACENT neighbours (which in the isometric diamond share a full
## screen-space edge with the cell) and selects one of the same 16 four-bit
## configurations the dual grid uses, drawing inside the cell's own diamond.
## The half-cell-offset dual grid was deliberately NOT chosen: it needs a
## second render pass over an offset lattice and a second geometry, while
## this keeps _draw()'s iteration and culling structure byte-identical to
## the pre-ADR-042 loop (same cells, same cull rect, same draw count), which
## the task brief explicitly asked not to regress. The 16-piece visual
## repetition the dual grid was meant to halve is instead broken up by
## variant selection and the scatter layer, per ADR-042's own framing.
##
## Culling (IsometricConversion.md section 2.2): _draw() iterates only
## IsoProjection.visible_cells(_camera.get_visible_screen_rect(), ...), never
## the whole map. Map dimensions come from GameData only - no literal 30/20
## anywhere in this file, which is what makes a 4x larger map viable.

## Visual tuning constants - presentation only, not gameplay tunables, so
## these stay as named consts here rather than moving to data/*.json (section
## 6.1 concerns tunables that affect simulation outcomes; these do not).
const FALLBACK_SOIL_COLOR: String = "#8B7355"
const TILLED_OVERLAY_COLOR: Color = Color(0, 0, 0, 0.15)
const MOISTURE_OVERLAY_BASE: Color = Color(0.2, 0.4, 1.0)
const MOISTURE_OVERLAY_MAX_ALPHA: float = 0.35
const MOISTURE_SCALE_MAX: float = 100.0
const GRID_LINE_COLOR: Color = Color(0, 0, 0, 0.15)
const CROP_RIPE_COLOR: Color = Color.GOLD
const CROP_UNRIPE_COLOR: Color = Color.GREEN
## Ratio of IsoProjection.TILE_H used for the crop dot radius - keeps the dot
## proportionate to the diamond without hardcoding a pixel size.
const CROP_DOT_RADIUS_RATIO: float = 0.3
## ADR-040: stored-sheaf marker - a small straw-gold bundle, slightly smaller
## than a ripe crop dot so the two never read as the same thing.
const SHEAF_MARKER_COLOR: Color = Color(0.85, 0.68, 0.30)
const SHEAF_MARKER_RADIUS_RATIO: float = 0.22

## Playtest fix: ADR-022 wild forage and ADR-018's spoiled_crop rot pickup
## were mechanically real (FarmGrid tracked forage_item_id/forage_yield per
## cell) but this renderer never drew them, so a gatherable tile was pixel-
## identical to empty ground. Category-keyed (not per-item) since forage.json
## grows its spawn tables per season - a category not listed here still
## draws the "unknown" glyph below rather than going invisible again, which
## is exactly the bug being fixed.
const FORAGE_GLYPH_CATEGORY: Dictionary = {
	"wild_herb": "plant",
	"wild_onion": "plant",
	"wild_berry": "plant",
	"flint": "flint",
	"wood": "wood",
	"spoiled_crop": "spoiled",
}
const FORAGE_PLANT_COLOR: Color = Color(0.20, 0.50, 0.12)
const FORAGE_PLANT_RADIUS_RATIO: float = 0.18
const FORAGE_FLINT_COLOR: Color = Color(0.55, 0.55, 0.58)
const FORAGE_FLINT_RADIUS_RATIO: float = 0.16
const FORAGE_WOOD_COLOR: Color = Color(0.42, 0.28, 0.14)
const FORAGE_WOOD_HALF_LENGTH_RATIO: float = 0.32
const FORAGE_WOOD_HALF_WIDTH_RATIO: float = 0.09
const FORAGE_SPOILED_COLOR: Color = Color(0.40, 0.36, 0.20)
const FORAGE_SPOILED_RADIUS_RATIO: float = 0.20
const FORAGE_UNKNOWN_COLOR: Color = Color(0.75, 0.75, 0.20)
const FORAGE_UNKNOWN_RADIUS_RATIO: float = 0.16
## Sprint 16 WS-A (ADR-041): manifest ids for forage item ids that now draw
## a textured static prop. A missing/empty entry (or an absent WorldVisuals)
## falls back to the glyph shapes above - FORAGE_GLYPH_CATEGORY still owns
## every item's fallback category, and has_forage_texture() gates both prop
## creation and the glyph skip on a loadable texture.
const FORAGE_SPRITE_IDS: Dictionary = {
	"flint": "world_dressing_rock_flint",
	"wild_herb": "world_dressing_plant_herb",
	"wild_berry": "world_dressing_plant_berry",
	"wild_onion": "world_dressing_plant_onion",
	"wood": "world_dressing_tree_broken",
}

## Playtest fix: the boundary between one zone and the next had no visual
## indication at all - walking off any map edge silently changes zones (or,
## where there is no exit, just clamps the player back inside per
## main.gd._clamp_player_inside), with no way to tell which edges lead
## anywhere without testing every one on foot. A distinct path-colored line
## along each exit's boundary segment, wider than the ordinary grid lines.
const EXIT_PATH_COLOR: Color = Color(0.78, 0.65, 0.35, 0.9)
const EXIT_PATH_WIDTH: float = 4.0
const INTERIOR_FLOOR_COLOR: Color = Color(0.48, 0.36, 0.24)
const INTERIOR_FLOOR_LINE: Color = Color(0.25, 0.18, 0.12, 0.55)
const INTERIOR_WALL_COLOR: Color = Color(0.16, 0.11, 0.08, 0.95)
const INTERIOR_DOOR_COLOR: Color = Color(0.76, 0.58, 0.28, 0.95)

## ADR-042: the surface half of a material id - terrain_material_id()
## composes "<soil>_<surface>" and the manifest keys its materials by those
## full ids, so each soil type (loamy/sandy/rocky) gets its own grass/tilled/
## wet material family and loamy fields never share textures with rocky ones.
const MATERIAL_SURFACE_GRASS := "grass"
const MATERIAL_SURFACE_TILLED := "tilled"
const MATERIAL_SURFACE_TILLED_WET := "tilled_wet"
## Moisture at or above this threshold IS the wet soil material; below it,
## moisture blends the wet variant over the dry one by moisture / threshold,
## so a half-dry plot reads as damp soil, not a debug-blue wash. The flat
## fallback path keeps the old blue wash (moisture_wash_alpha) exactly.
const MOISTURE_WET_THRESHOLD: float = 50.0
## Scatter decal determinism: scatter_should_draw() maps a hash onto
## [0, SCATTER_HASH_SPACE) and compares against the entry's density - the
## denominator is presentation-only and needs a named home, not a literal.
const SCATTER_HASH_SPACE: int = 10000
## ADR-042: the four edge-adjacent neighbours sampled for transition masks,
## in mask-character order. Each cell's diamond shares a full screen-space
## edge with exactly these four: (0,-1) = the cell's up-right edge, (1,0) =
## down-right, (0,1) = down-left, (-1,0) = up-left. The manifest's 4-bit
## transition config keys ("0000".."1111") use exactly this order - see
## transition_lookup(). Plain Array (not Array[Vector2i]) because typed
## array constants are not guaranteed stable across 4.7 GDScript parser
## revisions; it is read-only and iterated with a typed loop variable.
const NEIGHBOR_OFFSETS: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]

## Test-observability counter: incremented every time this renderer requests
## a redraw (tile change or visible cull-rectangle change). Production code never
## reads it; test_iso_terrain.gd asserts on it to verify the redraw-on-scroll
## trigger without needing to invoke _draw() itself (which requires a live
## CanvasItem draw context that a headless suite does not have).
var redraw_request_count: int = 0

var _farm_grid: Node
var _game_data: Node
## ADR-032 / plan Phase 0: the projected camera, used for get_visible_screen_rect()
## in _draw()'s culling and for the camera-move redraw trigger in _process().
## May be null (e.g. in tests, or before WS-D wiring lands) - _draw() then
## falls back to covering the full map, unculled.
var _camera: IsoCamera
## Last visible cell rectangle, used to detect an actual cull-set change rather
## than redrawing every time the camera crosses a grid cell. This matters for
## small maps: once the camera sees the whole map, crossing more cells cannot
## change the set of terrain cells that _draw() visits. Sentinel-initialised so
## the first _process() call always primes it and triggers one redraw.
var _last_visible_cull_rect: Rect2i = Rect2i()
var _has_visible_cull_rect: bool = false
## Sprint 16 WS-A: the y-sort container (WorldVisuals) textured forage props
## are parented to. Resolved in _ready() from main.gd's sibling node - the
## same lazy-resolution pattern FeatureRenderer uses for /root/TitheManager,
## because configure() runs before add_child() and main.gd already passes
## world_visuals only to FeatureRenderer. Null in off-tree tests, which is
## exactly the fallback path: primitives only, no props.
var _world_visuals: Node
## Live StaticPropVisual per forage-bearing cell (Vector2i -> StaticPropVisual),
## kept in sync from _on_tile_changed and rebuilt whole-grid on zone change.
var _forage_props: Dictionary = {}
## ADR-042 redraw cache: scrolling across a camera cell boundary must redraw
## the visible terrain, but the terrain decision for an unchanged cell does
## not change. Keep the resolved plans by cell so redraws do not resample four
## neighbours, traverse GameData, and reload the same texture for every cell.
var _terrain_plan_cache: Dictionary = {}
## ResourceLoader caches paths globally, but calling through the manifest seam
## for every cell still costs work during each redraw. These renderer-local
## caches keep the hot draw path to dictionary lookups after the first pass.
var _terrain_texture_cache: Dictionary = {}
var _terrain_source_rect_cache: Dictionary = {}
## The current TimeManager season, copied in by Main through set_terrain_season.
## It selects only a manifest art family; FarmGrid state, transition material
## ids, save data, and all simulation outcomes remain season-neutral.
var _terrain_season: String = "spring"


func configure(farm_grid: Node, game_data: Node, camera: IsoCamera) -> void:
	_game_data = game_data
	_camera = camera
	set_active_grid(farm_grid)


## Sprint 15b: re-wires this renderer to another zone's grid without redoing
## one-time setup. Signal management is idempotent - the old grid is
## disconnected only if actually connected, the new grid connected only if
## not already - so repeated zone crossings never double-connect.
func set_active_grid(farm_grid: Node) -> void:
	if _farm_grid == farm_grid:
		_has_visible_cull_rect = false
		_request_redraw()
		return
	if _farm_grid != null and _farm_grid.has_signal("tile_changed") \
			and _farm_grid.tile_changed.is_connected(_on_tile_changed):
		_farm_grid.tile_changed.disconnect(_on_tile_changed)
	_farm_grid = farm_grid
	if _farm_grid != null and _farm_grid.has_signal("tile_changed") \
			and not _farm_grid.tile_changed.is_connected(_on_tile_changed):
		_farm_grid.tile_changed.connect(_on_tile_changed)
	_terrain_plan_cache.clear()
	_has_visible_cull_rect = false
	_rebuild_forage_props()
	_request_redraw()


## Presentation-only season seam. Main owns the TimeManager connection, so
## this renderer has no autoload path lookup and off-tree tests stay explicit.
## A season change invalidates cached plans because the same material id now
## resolves to different art paths; it does not mutate a FarmGrid cell.
func set_terrain_season(season: String) -> void:
	var resolved := season.to_lower()
	if resolved.is_empty():
		resolved = "spring"
	if _terrain_season == resolved:
		return
	_terrain_season = resolved
	_terrain_plan_cache.clear()
	_terrain_texture_cache.clear()
	_terrain_source_rect_cache.clear()
	_request_redraw()


## Resolves the y-sort container from main.gd's sibling node (one-time, not
## hot code - CLAUDE.md's no-string-paths rule targets per-frame lookups).
## _ready() runs after add_child(), so the sibling always exists in the live
## scene; when it does not (headless suites, off-tree tests), set_world_visuals
## receives null and the renderer stays on the primitive-glyph path.
## ADR-042: the renderer pins linear texture filtering for terrain tiles -
## painterly terrain art is authored for linear sampling, and immediate-mode
## draw_texture_rect_region() uses the CanvasItem's node-level filter, so the
## per-entry `filter` field of the sprites manifest does not apply here.
func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_world_visuals(get_node_or_null("../WorldVisuals"))
	# configure() normally runs before add_child(), so its first queue_redraw()
	# can occur before this CanvasItem enters the tree. Request once more here
	# to guarantee a just-opened or save-restored interior paints immediately.
	_request_redraw()


## Presentation-only poll (CLAUDE.md section 4): the visible cull set changes
## as the camera moves, so a redraw is needed when the actual cull rectangle
## changes even though no gameplay data changed. This does not belong in
## _physics_process - it neither reads nor writes gameplay state, only
## screen-space camera position, and queue_redraw() is exactly the kind of
## "rendering only" mutation section 4 carves out for _process().
##
## WS-D API gap noted in DEVELOPMENT_STATE.md: IsoCamera has no movement
## signal, so this polls global_position every frame instead of subscribing
## to one. The poll itself is cheap (the same cull calculation _draw() uses and
## a Rect2i compare) and only calls queue_redraw() when the visible cell set
## actually changes, so it does not reintroduce per-frame redraws or redraw a
## whole small map merely because the camera crossed a cell.
func _process(_delta: float) -> void:
	if _camera == null or not is_instance_valid(_camera):
		return
	var dims := _map_dims()
	var current_cull: Rect2i = get_visible_cull_rect(dims.x, dims.y)
	if not _has_visible_cull_rect or current_cull != _last_visible_cull_rect:
		_has_visible_cull_rect = true
		_last_visible_cull_rect = current_cull
		_request_redraw()


func _draw() -> void:
	if _farm_grid == null or _game_data == null:
		return
	var dims := _map_dims()
	var width := dims.x
	var height := dims.y
	if width <= 0 or height <= 0:
		return
	if _is_interior_zone():
		_draw_interior_room(width, height)
		return

	var cull := get_visible_cull_rect(width, height)
	var gx0 := cull.position.x
	var gy0 := cull.position.y
	var gx1 := cull.position.x + cull.size.x
	var gy1 := cull.position.y + cull.size.y

	for x in range(gx0, gx1):
		for y in range(gy0, gy1):
			var pos := Vector2i(x, y)
			var soil: String = _farm_grid.get_soil(pos)
			if soil.is_empty():
				continue
			var cell: Dictionary = _farm_grid.get_cell(pos)
			# ADR-042: one routing decision per cell. The textured terrain
			# system draws the material variant (or transition tile), wet
			# blend, and scatter; when no manifest texture resolves, the
			# flat-color fills below are EXACTLY today's pre-ADR-042 code
			# (soil color, tilled darkening, blue moisture wash).
			if not _draw_textured_cell(pos, soil, cell):
				_draw_flat_cell(pos, soil, cell)
			var crop_id: String = _farm_grid.get_crop_name(pos)
			if not crop_id.is_empty():
				var growth_progress := float(cell.get("growth_progress", 0.0))
				if not _draw_crop_stage(pos, crop_id, growth_progress):
					var centre := IsoProjection.cell_centre_screen(pos)
					var radius := IsoProjection.TILE_H * CROP_DOT_RADIUS_RATIO
					if growth_progress >= 1.0:
						draw_circle(centre, radius, CROP_RIPE_COLOR)
					else:
						draw_circle(centre, radius, CROP_UNRIPE_COLOR)
			# Playtest fix: forage glyph, drawn after crop/moisture so it reads
			# on top; never coexists with a crop dot since forage only ever
			# spawns on untilled cells (FarmGrid.advance_day's spawn pass skips
			# tilled ground, and the rot branch that leaves spoiled_crop behind
			# runs on an already-untilled cell).
			var forage_item_id := str(cell.get("forage_item_id", ""))
			if not forage_item_id.is_empty():
				# Sprint 16 WS-A: a managed prop for this cell means the
				# textured asset is already in world_visuals, so the primitive
				# glyph is deliberately skipped (ADR-041 definition of done -
				# no primitive left under an integrated asset). No prop means
				# no loadable manifest entry or no WorldVisuals, so the glyph
				# below is the fallback, unchanged.
				if not _forage_props.has(pos):
					_draw_forage_glyph(pos, forage_item_id)
			# ADR-040: a stored-sheaf marker is drawn last so it reads on top
			# of soil/tilled/moisture overlays; sheaves never coexist with a
			# crop (markers only spawn on untilled ground), so no overlap.
			if bool(cell.get("demesne_sheaf", false)):
				draw_circle(IsoProjection.cell_centre_screen(pos),
					IsoProjection.TILE_H * SHEAF_MARKER_RADIUS_RATIO, SHEAF_MARKER_COLOR)

	_draw_tilled_grid_lines(gx0, gy0, gx1, gy1, dims)
	_draw_exit_paths(width, height)


## Draws an approved crop growth stage at the same cell centre previously used
## by the primitive dot. Missing stage data or a missing texture returns false,
## preserving the old dot exactly; this renderer never changes crop state.
func _draw_crop_stage(pos: Vector2i, crop_id: String, progress: float) -> bool:
	var entry := _crop_sprite_entry(crop_id, progress)
	if entry.is_empty():
		return false
	var texture := _cached_texture(entry)
	if texture == null:
		return false
	var region := SpriteManifest.get_static_region(entry, texture)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return false
	var scale := SpriteManifest.get_scale(entry)
	var origin := IsoProjection.cell_centre_screen(pos)
	var draw_rect := Rect2(origin - SpriteManifest.get_anchor(entry) * scale,
		region.size * scale)
	draw_texture_rect_region(texture, draw_rect, region)
	return true


## Resolves a static crop-stage entry through the two presentation seams. The
## crop id and progress come from FarmGrid only as inputs; neither is mutated.
func _crop_sprite_entry(crop_id: String, progress: float) -> Dictionary:
	if _game_data == null or not _game_data.has_method("get_crop_stage_set") \
			or not _game_data.has_method("get_sprite"):
		return {}
	var stage_set: Dictionary = _game_data.get_crop_stage_set(crop_id)
	if stage_set.is_empty():
		return {}
	var sprite_id := SpriteManifest.get_stage_sprite_id(stage_set, progress)
	if sprite_id.is_empty():
		return {}
	return _game_data.get_sprite(sprite_id)


## Active zone dimensions: the connected grid's own size when available (the
## Sprint 15b per-zone path), else GameData's default-zone dims (the
## pre-15b and mock-test path). Never a hardcoded 30x20.
func _map_dims() -> Vector2i:
	if _farm_grid != null and _farm_grid.has_method("get_grid_size"):
		var size: Vector2i = _farm_grid.get_grid_size()
		if size.x > 0 and size.y > 0:
			return size
	if _game_data != null:
		return Vector2i(_game_data.get_map_width(), _game_data.get_map_height())
	return Vector2i.ZERO


func _is_interior_zone() -> bool:
	if _farm_grid == null or _game_data == null \
			or not _farm_grid.has_method("get_zone_id") \
			or not _game_data.has_method("get_zone_metadata"):
		return false
	var zone_id := str(_farm_grid.get_zone_id())
	return bool(_game_data.get_zone_metadata(zone_id).get("is_interior", false))


## Interior presentation is an optional shell-plus-fixtures composition. The
## shell owns only floor + continuous north/west walls; doors, windows, and
## later decorating props are separate zone records layered over it. Gameplay
## still uses FarmGrid bounds and ZoneManager exits; these visuals do not
## create a second coordinate system.
func _draw_interior_room(width: int, height: int) -> void:
	# FeatureRenderer owns successfully loaded interior Sprite2D compositions
	# under WorldVisuals. Keep this terrain renderer's immediate-mode room only
	# as the asset-missing fallback; drawing both would double-blend the shell.
	if _is_interior_shell_managed():
		return
	_draw_primitive_interior_room(width, height)


func _is_interior_shell_managed() -> bool:
	var visual := _interior_visual_record()
	if visual.is_empty() or _game_data == null or not _game_data.has_method("get_sprite"):
		return false
	var shell_entry: Dictionary = _game_data.get_sprite(str(visual.get("shell_sprite_id", "")))
	return _cached_texture(shell_entry) != null


## Missing artwork must retain a fully playable room. The primitive fallback
## respects the same cutaway rule as the textured shell: only north and west
## walls render; south/east fixtures remain independent visual overlays.
func _draw_primitive_interior_room(width: int, height: int) -> void:
	var cull := get_visible_cull_rect(width, height)
	for x in range(cull.position.x, cull.position.x + cull.size.x):
		for y in range(cull.position.y, cull.position.y + cull.size.y):
			var pos := Vector2i(x, y)
			var diamond := IsoProjection.cell_diamond(pos)
			draw_colored_polygon(diamond, INTERIOR_FLOOR_COLOR)
			draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
				INTERIOR_FLOOR_LINE, 1.0)
	var top_left := Vector2(0.0, 0.0)
	var top_right := Vector2(float(width), 0.0)
	var bottom_left := Vector2(0.0, float(height))
	_draw_interior_wall(top_left, top_right)
	_draw_interior_wall(top_left, bottom_left)
	var fixtures := _interior_fixture_records()
	if fixtures.is_empty():
		_draw_primitive_interior_door(_interior_door_side(),
			_interior_door_index(_interior_door_side()), width, height)
		return
	for fixture: Dictionary in fixtures:
		_draw_primitive_interior_fixture(fixture, width, height)


## Draws the complete room shell first, then each individually-addressable
## fixture. A broken/missing shell fails soft to the primitive room above.
func _draw_interior_visual(width: int, height: int) -> bool:
	var visual := _interior_visual_record()
	var shell_sprite_id := str(visual.get("shell_sprite_id", ""))
	if shell_sprite_id.is_empty() or _game_data == null \
			or not _game_data.has_method("get_sprite"):
		return false
	var shell_entry: Dictionary = _game_data.get_sprite(shell_sprite_id)
	if not _draw_interior_sprite(shell_entry, Vector2.ZERO):
		return false
	for fixture: Dictionary in _interior_fixture_records():
		var fixture_entry: Dictionary = _game_data.get_sprite(str(fixture.get("sprite_id", "")))
		var fixture_origin := IsoProjection.grid_to_screen(interior_fixture_grid_position(
			str(fixture.get("side", "")), int(fixture.get("index", -1)), width, height))
		if not _draw_interior_sprite(fixture_entry, fixture_origin):
			_draw_primitive_interior_fixture(fixture, width, height)
	return true


## Draws one texture by its manifest anchor. Interior entries can opt into a
## draw_scale because a room shell spans many cells rather than a single
## height_tiles world prop; the scale remains data-owned presentation tuning.
func _draw_interior_sprite(entry: Dictionary, origin: Vector2) -> bool:
	if entry.is_empty():
		return false
	var texture := _cached_texture(entry)
	if texture == null:
		return false
	var region := SpriteManifest.get_static_region(entry, texture)
	if region.size.x <= 0.0 or region.size.y <= 0.0:
		return false
	var scale := SpriteManifest.get_draw_scale(entry)
	if scale <= 0.0:
		return false
	var draw_rect := Rect2(origin - SpriteManifest.get_anchor(entry) * scale,
		region.size * scale)
	draw_texture_rect_region(texture, draw_rect, region)
	return true


func _interior_visual_record() -> Dictionary:
	if _farm_grid == null or _game_data == null \
			or not _farm_grid.has_method("get_zone_id") \
			or not _game_data.has_method("get_zone_interior_visual"):
		return {}
	return _game_data.get_zone_interior_visual(str(_farm_grid.get_zone_id()))


func _interior_fixture_records() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for fixture: Variant in _interior_visual_record().get("fixtures", []):
		out.append(fixture as Dictionary)
	return out


## The visible camera-side convention is data-independent and shared by all
## interiors: north/far and west/left walls remain, while east/south cut away.
static func interior_visible_wall_sides() -> Array[String]:
	return ["north", "west"]


## Maps a fixture side/index onto the logical room perimeter. The projection
## itself remains exclusively inside IsoProjection; this helper returns only
## grid coordinates, preserving the presentation-only projection invariant.
static func interior_fixture_grid_position(side: String, index: int,
		width: int, height: int) -> Vector2:
	match side:
		"north":
			return Vector2(float(clampi(index, 0, width - 1)) + 0.5, 0.0)
		"east":
			return Vector2(float(width), float(clampi(index, 0, height - 1)) + 0.5)
		"south":
			return Vector2(float(clampi(index, 0, width - 1)) + 0.5, float(height))
		"west":
			return Vector2(0.0, float(clampi(index, 0, height - 1)) + 0.5)
	return Vector2.ZERO


func _draw_primitive_interior_fixture(fixture: Dictionary, width: int, height: int) -> void:
	var side := str(fixture.get("side", ""))
	var index := int(fixture.get("index", -1))
	var origin := IsoProjection.grid_to_screen(interior_fixture_grid_position(side, index, width, height))
	if str(fixture.get("sprite_id", "")).contains("window"):
		var top_left := origin + Vector2(-10.0, -34.0)
		var top_right := origin + Vector2(10.0, -34.0)
		var bottom_left := origin + Vector2(-10.0, -14.0)
		var bottom_right := origin + Vector2(10.0, -14.0)
		draw_colored_polygon(PackedVector2Array([top_left, top_right, bottom_right, bottom_left]),
			Color(0.31, 0.57, 0.76, 0.92))
		draw_polyline(PackedVector2Array([top_left, top_right, bottom_right, bottom_left, top_left]),
			INTERIOR_WALL_COLOR, 3.0)
		return
	_draw_primitive_interior_door(side, index, width, height)


func _draw_primitive_interior_door(edge: String, door_index: int,
		width: int, height: int) -> void:
	if door_index < 0:
		return
	var from_grid := Vector2.ZERO
	var to_grid := Vector2.ZERO
	var side_length := 0
	match edge:
		"north":
			from_grid = Vector2.ZERO
			to_grid = Vector2(float(width), 0.0)
			side_length = width
		"east":
			from_grid = Vector2(float(width), 0.0)
			to_grid = Vector2(float(width), float(height))
			side_length = height
		"south":
			from_grid = Vector2(0.0, float(height))
			to_grid = Vector2(float(width), float(height))
			side_length = width
		"west":
			from_grid = Vector2.ZERO
			to_grid = Vector2(0.0, float(height))
			side_length = height
		_:
			return
	if door_index >= side_length:
		return
	var door_start := IsoProjection.grid_to_screen(from_grid.lerp(to_grid,
		float(door_index) / float(side_length)))
	var door_end := IsoProjection.grid_to_screen(from_grid.lerp(to_grid,
		float(door_index + 1) / float(side_length)))
	draw_line(door_start, door_end, INTERIOR_DOOR_COLOR, 5.0)


func _interior_door_side() -> String:
	if _farm_grid == null or _game_data == null \
			or not _farm_grid.has_method("get_zone_id") \
			or not _game_data.has_method("get_zone_exits"):
		return ""
	var zone_id := str(_farm_grid.get_zone_id())
	for exit: Dictionary in _game_data.get_zone_exits(zone_id):
		var edge := str(exit.get("edge", ""))
		if edge in ["north", "east", "south", "west"]:
			return edge
	return ""


func _interior_door_index(edge: String) -> int:
	if _farm_grid == null or _game_data == null \
			or not _farm_grid.has_method("get_zone_id") \
			or not _game_data.has_method("get_zone_exits"):
		return -1
	var zone_id := str(_farm_grid.get_zone_id())
	for exit: Dictionary in _game_data.get_zone_exits(zone_id):
		if str(exit.get("edge", "")) != edge:
			continue
		if edge in ["east", "west"]:
			return int(exit.get("y_min", -1))
		return int(exit.get("x_min", -1))
	return -1


func _draw_interior_wall_with_door(from_grid: Vector2, to_grid: Vector2,
		door_index: int, side_length: int) -> void:
	if door_index < 0 or door_index >= side_length:
		_draw_interior_wall(from_grid, to_grid)
		return
	var door_start := IsoProjection.grid_to_screen(from_grid.lerp(to_grid,
		float(door_index) / float(side_length)))
	var door_end := IsoProjection.grid_to_screen(from_grid.lerp(to_grid,
		float(door_index + 1) / float(side_length)))
	if door_index > 0:
		_draw_interior_wall(from_grid, from_grid.lerp(to_grid,
			float(door_index) / float(side_length)))
	if door_index + 1 < side_length:
		_draw_interior_wall(from_grid.lerp(to_grid,
			float(door_index + 1) / float(side_length)), to_grid)
	draw_line(door_start, door_end, INTERIOR_DOOR_COLOR, 5.0)


func _draw_interior_wall(from_grid: Vector2, to_grid: Vector2) -> void:
	draw_line(IsoProjection.grid_to_screen(from_grid),
		IsoProjection.grid_to_screen(to_grid), INTERIOR_WALL_COLOR, 6.0)


## The cull rect this renderer would use right now, in grid-cell coordinates.
## Public (not underscored) so tests can assert cull-set correctness directly
## rather than through _draw(), which needs a live CanvasItem draw context a
## headless suite does not have. With no camera configured, falls back to the
## full map (unculled) - the pre-ADR-032 behaviour, and what a camera-less
## test configuration gets.
func get_visible_cull_rect(width: int, height: int) -> Rect2i:
	if _camera == null or not is_instance_valid(_camera):
		return Rect2i(0, 0, width, height)
	return IsoProjection.visible_cells(_camera.get_visible_screen_rect(), width, height)


## ADR-042: the surface material for a simulation cell - a pure function of
## existing FarmGrid state (soil type, tilled, moisture), never new state.
## Untilled cells are "<soil>_grass"; tilled cells are "<soil>_tilled", or
## "<soil>_tilled_wet" once moisture reaches the wet threshold. Moisture on
## untilled grass is deliberately ignored: the wet material exists for worked
## soil, and a rained-on lawn reads as grass either way at 64x48.
static func terrain_material_id(soil: String, tilled: bool, moisture: float) -> String:
	if soil.is_empty():
		return ""
	if not tilled:
		return "%s_%s" % [soil, MATERIAL_SURFACE_GRASS]
	var surface := MATERIAL_SURFACE_TILLED
	if moisture >= MOISTURE_WET_THRESHOLD:
		surface = MATERIAL_SURFACE_TILLED_WET
	return "%s_%s" % [soil, surface]


## The flat fallback path's moisture wash alpha - the EXACT pre-ADR-042
## formula, extracted so tests can pin "empty manifest == today's behaviour"
## without invoking _draw(). The textured path never calls this: wetness is
## a soil material there, not a blue wash.
static func moisture_wash_alpha(moisture: float) -> float:
	return moisture / MOISTURE_SCALE_MAX * MOISTURE_OVERLAY_MAX_ALPHA


## ADR-042: how far a tilled cell is blended toward the wet material, 0..1.
## Below the wet threshold the wet variant is drawn over the dry one at this
## alpha; at/above it the cell's material IS tilled_wet and no overlay runs.
static func moisture_wet_blend(moisture: float) -> float:
	if moisture <= 0.0:
		return 0.0
	if moisture >= MOISTURE_WET_THRESHOLD:
		return 1.0
	return moisture / MOISTURE_WET_THRESHOLD


## ADR-042: deterministic variant pick for a cell - a pure function of the
## coordinate (plus the material family, whose entry owns the variant list),
## so the same cell draws the same variant across redraws and sessions with
## nothing persisted. Never randi()/RandomNumberGenerator: ADR-042 demands a
## coordinate hash, and _stable_cell_hash is a fixed integer mix with no
## engine-seed dependence. posmod keeps the index non-negative.
static func terrain_variant_index(pos: Vector2i, variant_count: int) -> int:
	if variant_count <= 0:
		return 0
	return posmod(_stable_cell_hash(pos.x, pos.y), variant_count)


## ADR-042: the adjacency configuration for one cell - the pure
## transition-lookup logic, exposed (exit_line_grid_points pattern) so tests
## can drive it without a live CanvasItem. Neighbours arrive in
## NEIGHBOR_OFFSETS order [N, E, S, W]; the returned "mask" is a 4-char
## string whose chars are 1 where that neighbour's material differs from the
## cell's own (an empty/out-of-bounds neighbour reads as same, so map edges
## never fabricate a boundary). Every differing edge is masked; the pair is
## "<center>|<other>" where `other` is the dominant differing material (max
## count, ties broken by first-seen in N,E,S,W order - deterministic). A
## three-material corner keeps the dominant pair but still transitions on
## every differing edge; the neighbouring cells' own lookups keep the seam
## correct on their side. Returns {"pair", "mask", "other", "is_boundary"}.
static func transition_lookup(center_material: String, neighbors: Array[String]) -> Dictionary:
	var mask_chars := ["0", "0", "0", "0"]
	var counts: Dictionary = {}
	var first_other := ""
	for i in range(4):
		var mat := neighbors[i] if i < neighbors.size() else ""
		if mat != center_material and not mat.is_empty():
			mask_chars[i] = "1"
			counts[mat] = int(counts.get(mat, 0)) + 1
			if first_other.is_empty():
				first_other = mat
	if counts.is_empty():
		return {"pair": "", "mask": "0000", "other": "", "is_boundary": false}
	var other := first_other
	var best_count := 0
	for mat: Variant in counts:
		var count := int(counts[mat])
		if count > best_count:
			best_count = count
			other = str(mat)
	return {
		"pair": "%s|%s" % [center_material, other],
		"mask": "%s%s%s%s" % [mask_chars[0], mask_chars[1], mask_chars[2], mask_chars[3]],
		"other": other,
		"is_boundary": true,
	}


## ADR-042: whether scatter entry `scatter_index` decorates cell `pos` - a
## deterministic hash roll against the entry's density, same
## coordinate-hash discipline as terrain_variant_index. Public so tests can
## pin determinism without a draw context.
static func scatter_should_draw(pos: Vector2i, scatter_index: int, density: float) -> bool:
	if density <= 0.0:
		return false
	var h := posmod(
		_stable_cell_hash(pos.x * 31 + scatter_index * 17, pos.y * 13), SCATTER_HASH_SPACE)
	return float(h) / float(SCATTER_HASH_SPACE) < density


## ADR-042: scatter placement within a cell, normalized to [-0.5, 0.5] on
## each axis (draw code scales by the tile size) - deterministic per cell +
## entry index, so tufts never jump between redraws. Public for tests.
static func scatter_offset(pos: Vector2i, scatter_index: int) -> Vector2:
	var hx := posmod(_stable_cell_hash(pos.x * 5 + scatter_index * 3, pos.y * 7), 1000)
	var hy := posmod(_stable_cell_hash(pos.x * 11, pos.y * 19 + scatter_index), 1000)
	return Vector2(float(hx) / 1000.0 - 0.5, float(hy) / 1000.0 - 0.5)


## ADR-042: the FULL per-cell texture-resolution decision _draw() consumes -
## public (exit_line_grid_points pattern) because the headless harness
## cannot invoke _draw(). Returns:
##   has_texture    false -> _draw() must take the flat-color path; the
##                  plan's selection fields are still reported so tests can
##                  distinguish "no manifest entry" from "entry but unloadable"
##   material_id    the composed "<soil>_<surface>" id
##   pair_key       "<center>|<other>" when the cell borders another material
##   mask_key       4-char N,E,S,W edge mask for that pair
##   wet_blend      0..1 wet-overlay alpha (moisture toward the wet material)
##   base_entry / base_texture   the chosen variant or transition tile
##   wet_entry / wet_texture     the wet overlay tile, {} / null when none
##   scatter_entries             the material's scatter list (density+entry)
## Resolution rules: a boundary cell prefers its transition tile and only
## degrades to the base variant when the transition entry is missing; a cell
## whose chosen entry cannot load a texture reports has_texture=false, which
## routes to today's flat fills - the fail-soft contract.
func terrain_cell_plan(pos: Vector2i, soil: String, cell: Dictionary) -> Dictionary:
	var tilled := bool(cell.get("tilled", false))
	var moisture := float(cell.get("moisture", 0.0))
	var material_id := terrain_material_id(soil, tilled, moisture)
	var plan := {
		"has_texture": false,
		"material_id": material_id,
		"pair_key": "",
		"mask_key": "0000",
		"wet_blend": moisture_wet_blend(moisture) if tilled else 0.0,
		"base_entry": {},
		"wet_entry": {},
		"base_texture": null,
		"wet_texture": null,
		"scatter_entries": [],
	}
	if material_id.is_empty():
		return plan
	var lookup := transition_lookup(material_id, _neighbor_materials(pos))
	var pair_key := ""
	var mask_key := "0000"
	var other := ""
	if bool(lookup.get("is_boundary", false)):
		pair_key = str(lookup.get("pair", ""))
		mask_key = str(lookup.get("mask", "0000"))
		other = str(lookup.get("other", ""))
	var base_entry := _variant_entry(_terrain_material_entry(material_id), pos)
	if not pair_key.is_empty():
		var transition_entry := _terrain_transition_entry(pair_key, mask_key)
		if not transition_entry.is_empty():
			base_entry = transition_entry
	plan["pair_key"] = pair_key
	plan["mask_key"] = mask_key
	if base_entry.is_empty():
		return plan
	var base_texture := _cached_texture(base_entry)
	if base_texture == null:
		return plan
	plan["has_texture"] = true
	plan["base_entry"] = base_entry
	plan["base_texture"] = base_texture
	# Partial wetness (0 < moisture < threshold) draws the wet variant or wet
	# transition over the dry base at moisture/threshold alpha - "blended
	# toward" per ADR-042. At/above the threshold the base material is already
	# tilled_wet, so no overlay is needed (blend is 1.0 by construction).
	if tilled and moisture > 0.0 and moisture_wet_blend(moisture) < 1.0:
		var wet_entry := _wet_overlay_entry(material_id, pair_key, mask_key, other, pos)
		if not wet_entry.is_empty():
			var wet_texture := _cached_texture(wet_entry)
			if wet_texture != null:
				plan["wet_entry"] = wet_entry
				plan["wet_texture"] = wet_texture
	plan["scatter_entries"] = _terrain_scatter_entries(material_id)
	return plan


## Presentation-only glyph for a forage-bearing tile, category-keyed via
## FORAGE_GLYPH_CATEGORY so a shape (not just a color) distinguishes plant/
## flint/wood/spoiled finds from each other and from the crop dot / ADR-040
## sheaf marker's circles. An item_id missing from that map still draws the
## "unknown" glyph rather than nothing - see the map's own comment.
func _draw_forage_glyph(pos: Vector2i, item_id: String) -> void:
	var category: String = str(FORAGE_GLYPH_CATEGORY.get(item_id, "unknown"))
	var centre := IsoProjection.cell_centre_screen(pos)
	match category:
		"flint":
			draw_colored_polygon(
				_small_diamond(centre, IsoProjection.TILE_H * FORAGE_FLINT_RADIUS_RATIO),
				FORAGE_FLINT_COLOR)
		"wood":
			var half_w := IsoProjection.TILE_W * FORAGE_WOOD_HALF_LENGTH_RATIO
			var half_h := IsoProjection.TILE_H * FORAGE_WOOD_HALF_WIDTH_RATIO
			draw_rect(Rect2(centre - Vector2(half_w, half_h), Vector2(half_w, half_h) * 2.0), FORAGE_WOOD_COLOR)
		"spoiled":
			draw_circle(centre, IsoProjection.TILE_H * FORAGE_SPOILED_RADIUS_RATIO, FORAGE_SPOILED_COLOR)
		"plant":
			draw_circle(centre, IsoProjection.TILE_H * FORAGE_PLANT_RADIUS_RATIO, FORAGE_PLANT_COLOR)
		_:
			draw_circle(centre, IsoProjection.TILE_H * FORAGE_UNKNOWN_RADIUS_RATIO, FORAGE_UNKNOWN_COLOR)


## A small diamond polygon centred at `centre` with half-height `r`, widened
## by IsoProjection's TILE_W/TILE_H aspect so it reads as a diamond (matching
## the cell diamonds' own proportions) rather than a square - used for the
## flint glyph so it is a distinct shape from the crop/sheaf/forage circles,
## not just a different color.
func _small_diamond(centre: Vector2, r: float) -> PackedVector2Array:
	var rw := r * (IsoProjection.TILE_W / IsoProjection.TILE_H)
	return PackedVector2Array([
		centre + Vector2(0.0, -r),
		centre + Vector2(rw, 0.0),
		centre + Vector2(0.0, r),
		centre + Vector2(-rw, 0.0),
	])


## The two grid-space endpoints of `exit_data`'s boundary segment (a zones.json
## exit entry: edge + x_min/x_max for north/south, y_min/y_max for east/west).
## Public (not underscored) so tests can assert the geometry directly,
## matching get_visible_cull_rect()'s own reasoning: _draw() itself needs a
## live CanvasItem context a headless suite does not have. Grid-space, not
## screen-space - _draw_exit_paths projects the result via
## IsoProjection.grid_to_screen, the same technique _draw_tilled_grid_lines
## uses (the projection is linear, so a straight grid-space segment stays
## straight once projected). Returns an empty array for an unrecognised edge
## string rather than guessing a direction.
func exit_line_grid_points(exit_data: Dictionary, map_width: int, map_height: int) -> Array[Vector2]:
	match str(exit_data.get("edge", "")):
		"north":
			return [Vector2(float(exit_data.get("x_min", 0)), 0.0),
				Vector2(float(exit_data.get("x_max", 0)) + 1.0, 0.0)]
		"south":
			var y := float(map_height)
			return [Vector2(float(exit_data.get("x_min", 0)), y),
				Vector2(float(exit_data.get("x_max", 0)) + 1.0, y)]
		"west":
			return [Vector2(0.0, float(exit_data.get("y_min", 0))),
				Vector2(0.0, float(exit_data.get("y_max", 0)) + 1.0)]
		"east":
			var x := float(map_width)
			return [Vector2(x, float(exit_data.get("y_min", 0))),
				Vector2(x, float(exit_data.get("y_max", 0)) + 1.0)]
		_:
			return []


## Playtest fix: one path-colored line per exit, drawn regardless of the
## cull rect (exits are rare - at most a handful per zone - and always at
## the map edge, so this is cheap even when off-screen). Silently no-ops if
## GameData or the active grid can't report a zone id - the mock GameData
## test_iso_terrain.gd/test_iso_structures.gd use has no get_zone_exits(),
## and this is only ever reached from _draw(), which those suites never
## invoke (documented limitation - no live CanvasItem context headless).
func _draw_exit_paths(width: int, height: int) -> void:
	if _game_data == null or _farm_grid == null or not _game_data.has_method("get_zone_exits"):
		return
	var zone_id := str(_farm_grid.get_zone_id()) if _farm_grid.has_method("get_zone_id") else ""
	if zone_id.is_empty():
		return
	for exit_data: Dictionary in _game_data.get_zone_exits(zone_id):
		var points := exit_line_grid_points(exit_data, width, height)
		if points.size() != 2:
			continue
		draw_line(IsoProjection.grid_to_screen(points[0]), IsoProjection.grid_to_screen(points[1]),
			EXIT_PATH_COLOR, EXIT_PATH_WIDTH)


## ADR-042: the flat-color fallback - verbatim the pre-ADR-042 inline fills
## (soil color polygon, tilled darkening, blue moisture wash). Keeping it as
## one function is what makes "empty manifest == today's exact behaviour"
## provable: terrain_cell_plan() returns has_texture=false and this runs
## unchanged, including the old moisture wash formula (moisture_wash_alpha).
func _draw_flat_cell(pos: Vector2i, soil: String, cell: Dictionary) -> void:
	var diamond := IsoProjection.cell_diamond(pos)
	var props: Dictionary = _game_data.get_soil_properties(soil)
	draw_colored_polygon(diamond, Color(str(props.get("color", FALLBACK_SOIL_COLOR))))
	if bool(cell.get("tilled", false)):
		draw_colored_polygon(diamond, TILLED_OVERLAY_COLOR)
	var moisture := float(cell.get("moisture", 0.0))
	if moisture > 0.0:
		draw_colored_polygon(diamond, Color(
			MOISTURE_OVERLAY_BASE.r, MOISTURE_OVERLAY_BASE.g, MOISTURE_OVERLAY_BASE.b,
			moisture_wash_alpha(moisture)))


## ADR-042: draws one cell's textured terrain from terrain_cell_plan() - the
## same decision the tests drive. Returns false when the plan reports no
## texture, which is the caller's cue to run _draw_flat_cell() instead.
## Tile textures are authored as the tile's rect (TILE_W x TILE_H screen
## px) with transparency outside the inscribed diamond: adjacent cells'
## rects overlap at their corners, so opaque corners would paint over
## neighbours in row-major draw order. The offline dual-grid tool owns that
## authoring contract; this code only maps the rect region into place.
func _draw_textured_cell(pos: Vector2i, soil: String, cell: Dictionary) -> bool:
	var plan := _cached_terrain_cell_plan(pos, soil, cell)
	if not bool(plan.get("has_texture", false)):
		return false
	var dest := _tile_dest_rect(pos)
	var base_texture := plan.get("base_texture") as Texture2D
	if base_texture != null:
		draw_texture_rect_region(base_texture, dest,
			_cached_source_rect(plan.get("base_entry", {}), base_texture))
	var wet_texture := plan.get("wet_texture") as Texture2D
	var wet_blend := float(plan.get("wet_blend", 0.0))
	if wet_texture != null and wet_blend > 0.0:
		draw_texture_rect_region(wet_texture, dest,
			_cached_source_rect(plan.get("wet_entry", {}), wet_texture),
			Color(1.0, 1.0, 1.0, wet_blend))
	_draw_scatter(pos, plan.get("scatter_entries", []))
	return true


## ADR-042: the scatter/decal pass - deterministic per-cell placement of the
## material's sparse dressing (tufts, pebbles, ruts) to break variant
## repetition. Each entry is a sprite-shaped dictionary with a float density;
## unloadable textures are skipped, matching the fail-soft contract.
func _draw_scatter(pos: Vector2i, scatter_entries: Array) -> void:
	for i in range(scatter_entries.size()):
		var entry := scatter_entries[i] as Dictionary
		if not scatter_should_draw(pos, i, float(entry.get("density", 0.0))):
			continue
		var texture := _cached_texture(entry)
		if texture == null:
			continue
		var centre := IsoProjection.cell_centre_screen(pos)
		var offset := scatter_offset(pos, i)
		var size := Vector2(IsoProjection.TILE_W, IsoProjection.TILE_H) * 0.5
		var dest := Rect2(centre + offset * size - size * 0.5, size)
		draw_texture_rect_region(texture, dest, _cached_source_rect(entry, texture))


## The four edge-adjacent neighbours' materials in NEIGHBOR_OFFSETS order.
## Out-of-bounds neighbours read as "" (FarmGrid.get_soil returns ""), which
## transition_lookup() treats as same-material, so map edges never fabricate
## a boundary. A null grid (off-tree plan tests) yields all "".
func _neighbor_materials(pos: Vector2i) -> Array[String]:
	var out: Array[String] = []
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		if _farm_grid == null:
			out.append("")
			continue
		var neighbor := pos + offset
		out.append(terrain_material_id(
			_farm_grid.get_soil(neighbor),
			_farm_grid.is_tilled(neighbor),
			_farm_grid.get_cell_moisture(neighbor)))
	return out


func _terrain_material_entry(material_id: String) -> Dictionary:
	if _game_data == null or not _game_data.has_method("get_terrain_material"):
		return {}
	return _game_data.get_terrain_material(material_id, _terrain_season)


## Internal redraw-only wrapper. The public terrain_cell_plan() remains pure
## and uncached for headless tests and tooling that supplies changing neighbour
## seams directly; production _draw() reaches this wrapper because FarmGrid's
## tile_changed signal invalidates every affected cell before redraw.
func _cached_terrain_cell_plan(pos: Vector2i, soil: String, cell: Dictionary) -> Dictionary:
	if _terrain_plan_cache.has(pos):
		return _terrain_plan_cache[pos] as Dictionary
	var plan := terrain_cell_plan(pos, soil, cell)
	_terrain_plan_cache[pos] = plan
	return plan


func _cached_source_rect(entry: Dictionary, texture: Texture2D) -> Rect2:
	var path := str(entry.get("texture", ""))
	if not path.is_empty() and _terrain_source_rect_cache.has(path):
		return _terrain_source_rect_cache[path] as Rect2
	var rect := _source_rect_for(entry, texture)
	if not path.is_empty():
		_terrain_source_rect_cache[path] = rect
	return rect


func _cached_texture(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("texture", ""))
	if path.is_empty():
		return null
	if _terrain_texture_cache.has(path):
		return _terrain_texture_cache[path] as Texture2D
	var texture := SpriteManifest.get_static_texture(entry)
	_terrain_texture_cache[path] = texture
	return texture


func _terrain_transition_entry(pair_key: String, mask_key: String) -> Dictionary:
	if _game_data == null or not _game_data.has_method("get_terrain_transition"):
		return {}
	return _game_data.get_terrain_transition(pair_key, mask_key, _terrain_season)


func _terrain_scatter_entries(material_id: String) -> Array[Dictionary]:
	if _game_data == null or not _game_data.has_method("get_terrain_scatter"):
		return []
	return _game_data.get_terrain_scatter(material_id, _terrain_season)


## One material entry's variant for a cell - deterministic via
## terrain_variant_index(), never randi(). {} when the entry has no variants.
func _variant_entry(material_entry: Dictionary, pos: Vector2i) -> Dictionary:
	var variants: Array = material_entry.get("variants", [])
	if variants.is_empty():
		return {}
	return variants[terrain_variant_index(pos, variants.size())] as Dictionary


## The wet overlay tile for a partially-wet tilled cell: the wet transition
## for the same edge configuration when the base is a transition, else the
## wet material's base variant. {} when neither resolves (partial manifests
## degrade to dry-looking soil - never the old blue wash; the blue wash is
## reserved for the no-texture-at-all flat path).
func _wet_overlay_entry(material_id: String, pair_key: String, mask_key: String,
		other: String, pos: Vector2i) -> Dictionary:
	var wet_id := _wet_material_id(material_id)
	if wet_id.is_empty():
		return {}
	if not pair_key.is_empty() and not other.is_empty():
		var wet_pair := "%s|%s" % [wet_id, other]
		var transition_entry := _terrain_transition_entry(wet_pair, mask_key)
		if not transition_entry.is_empty():
			return transition_entry
	return _variant_entry(_terrain_material_entry(wet_id), pos)


## "<soil>_tilled" -> "<soil>_tilled_wet"; anything else (grass, already wet,
## empty) -> "" so no wet overlay exists for it.
func _wet_material_id(material_id: String) -> String:
	if material_id.ends_with("_%s" % MATERIAL_SURFACE_TILLED):
		return material_id.replace("_%s" % MATERIAL_SURFACE_TILLED,
			"_%s" % MATERIAL_SURFACE_TILLED_WET)
	return ""


## The screen-space rect a terrain tile occupies: the TILE_W x TILE_H
## bounding box of the cell's diamond, centred on IsoProjection's cell
## centre. All terrain textures draw into this rect via
## draw_texture_rect_region (source rects come from the manifest entry's
## frame rects), so authored tiles at any resolution scale to the tile.
static func _tile_dest_rect(pos: Vector2i) -> Rect2:
	var centre := IsoProjection.cell_centre_screen(pos)
	return Rect2(centre - Vector2(IsoProjection.TILE_W * 0.5, IsoProjection.TILE_H * 0.5),
		Vector2(IsoProjection.TILE_W, IsoProjection.TILE_H))


## The source region for one terrain tile: the entry's first frame rect
## (SpriteManifest's sheet/frames convention), else frame_w x frame_h, else
## the whole texture. SpriteManifest owns the frame math - this only picks
## which frame and falls back for entries authored without sheet data.
static func _source_rect_for(entry: Dictionary, texture: Texture2D) -> Rect2:
	var rects := SpriteManifest.get_frame_rects(entry)
	if not rects.is_empty():
		return rects[0]
	var fw := float(entry.get("frame_w", 0.0))
	var fh := float(entry.get("frame_h", 0.0))
	if fw > 0.0 and fh > 0.0:
		return Rect2(0.0, 0.0, fw, fh)
	return Rect2(Vector2.ZERO, texture.get_size())


## Deterministic 64-bit-ish integer mix for a cell coordinate - the ADR-042
## "hash of the coordinate" requirement, self-contained so variant/scatter
## selection never depends on Godot's hash() implementation or any RNG seed.
## Pure function of (x, y): same cell, same value, every redraw and session.
static func _stable_cell_hash(x: int, y: int) -> int:
	var h := x * 374761393 + y * 668265263
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return h


func _on_tile_changed(pos: Vector2i) -> void:
	_terrain_plan_cache.erase(pos)
	for offset: Vector2i in NEIGHBOR_OFFSETS:
		_terrain_plan_cache.erase(pos + offset)
	_sync_forage_prop(pos)
	_request_redraw()


## WS-A test seam and _ready()'s resolution path: points prop management at
## the y-sort container and rebuilds every forage prop from the active grid.
## Safe to call more than once (zone crossings re-parent/re-verify).
func set_world_visuals(visuals: Node) -> void:
	_world_visuals = visuals
	_rebuild_forage_props()


## The manifest id for a forage item's textured proxy, or "" when WS-A has
## not integrated an asset for that item - "" is the primitive-glyph path.
func forage_sprite_id(item_id: String) -> String:
	return str(FORAGE_SPRITE_IDS.get(item_id, ""))


## Whether the manifest carries a loadable texture for this sprite id - the
## single gate prop creation and the _draw() glyph-skip share, mirroring
## SpriteManifest.apply_static's fail-soft contract as PlayerVisual consumes
## it (entry present but texture unavailable == fall back to primitives).
func has_forage_texture(sprite_id: String) -> bool:
	if _game_data == null or not _game_data.has_method("get_sprite"):
		return false
	var entry: Dictionary = _game_data.get_sprite(sprite_id)
	return not entry.is_empty() and SpriteManifest.get_static_texture(entry) != null


## Frees every managed forage prop and rebuilds from the active grid's live
## forage cells. Runs once per zone change (and from _ready after the
## sibling lookup) - whole-grid is cheap because forage concurrency is
## capped (~40 spawns per zone in forage.json), and props are inert nodes.
func _rebuild_forage_props() -> void:
	for key: Variant in _forage_props.keys():
		var prop: StaticPropVisual = _forage_props[key]
		if is_instance_valid(prop):
			prop.free()
	_forage_props.clear()
	if _farm_grid == null or not _farm_grid.has_method("has_forage") \
			or not _farm_grid.has_method("get_cell"):
		return
	var dims := _map_dims()
	for y in range(dims.y):
		for x in range(dims.x):
			_sync_forage_prop(Vector2i(x, y))


## One cell's prop lifecycle: create/reconfigure a StaticPropVisual when the
## cell carries a forage item with a loadable manifest texture, free it when
## it does not. Runs from tile_changed (gather, day-pass spawn, save restore)
## and from the whole-grid rebuild; off-tree grids without get_cell simply
## never manage props, which is the fallback path.
func _sync_forage_prop(pos: Vector2i) -> void:
	if _world_visuals == null or _farm_grid == null \
			or not _farm_grid.has_method("has_forage") \
			or not _farm_grid.has_method("get_cell"):
		return
	var existing: StaticPropVisual = _forage_props.get(pos, null)
	var item_id := str(_farm_grid.get_cell(pos).get("forage_item_id", ""))
	var sprite_id := forage_sprite_id(item_id)
	if sprite_id.is_empty() or not has_forage_texture(sprite_id):
		if existing != null and is_instance_valid(existing):
			existing.free()
		_forage_props.erase(pos)
		return
	if existing == null or not is_instance_valid(existing):
		existing = StaticPropVisual.new()
		_world_visuals.add_child(existing)
		_forage_props[pos] = existing
	existing.configure(Rect2i(pos, Vector2i(1, 1)), sprite_id)


func _request_redraw() -> void:
	redraw_request_count += 1
	queue_redraw()


## ADR-042: the diamond lattice is now CONTEXTUAL - drawn only over tilled
## cells, which are exactly the interaction/placement surface (hoe, watering,
## planting, harvest all act on tilled ground), so the lattice reads as a
## workability affordance and never fights painterly grass. Chosen over a
## player-radius or a toggle because it is stateless, deterministic, and
## costs less than the old always-on lattice (most of a fresh map is
## untilled). Each edge is drawn exactly once: a constant-x grid line's
## segment at cell (x, y) is the shared edge of cells (x-1, y) and (x, y), so
## the segment is emitted when EITHER is tilled; constant-y lines mirror that
## for (x, y-1) / (x, y). Runs of consecutive active points are merged into
## one draw_line each, so adjacent tilled cells share one unbroken edge.
func _draw_tilled_grid_lines(gx0: int, gy0: int, gx1: int, gy1: int, dims: Vector2i) -> void:
	for x in range(gx0, gx1 + 1):
		var y := gy0
		while y <= gy1:
			if not _lattice_active_x(x, y, dims):
				y += 1
				continue
			var y_start := y
			while y <= gy1 and _lattice_active_x(x, y, dims):
				y += 1
			draw_line(IsoProjection.grid_to_screen(Vector2(x, y_start)),
				IsoProjection.grid_to_screen(Vector2(x, y)), GRID_LINE_COLOR)
	for y in range(gy0, gy1 + 1):
		var x := gx0
		while x <= gx1:
			if not _lattice_active_y(x, y, dims):
				x += 1
				continue
			var x_start := x
			while x <= gx1 and _lattice_active_y(x, y, dims):
				x += 1
			draw_line(IsoProjection.grid_to_screen(Vector2(x_start, y)),
				IsoProjection.grid_to_screen(Vector2(x, y)), GRID_LINE_COLOR)


## Whether the constant-x grid line at `x` carries an edge at cell row `y`:
## true when either of the two cells sharing that edge segment is tilled.
func _lattice_active_x(x: int, y: int, dims: Vector2i) -> bool:
	return (x > 0 and _tilled_cell(x - 1, y, dims)) or (x < dims.x and _tilled_cell(x, y, dims))


## Whether the constant-y grid line at `y` carries an edge at cell column `x`:
## true when either of the two cells sharing that edge segment is tilled.
func _lattice_active_y(x: int, y: int, dims: Vector2i) -> bool:
	return (y > 0 and _tilled_cell(x, y - 1, dims)) or (y < dims.y and _tilled_cell(x, y, dims))


func _tilled_cell(x: int, y: int, dims: Vector2i) -> bool:
	if x < 0 or y < 0 or x >= dims.x or y >= dims.y:
		return false
	return _farm_grid.is_tilled(Vector2i(x, y))
