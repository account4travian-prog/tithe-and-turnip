


class_name FeatureRenderer
extends Node2D

## Owns Tithe & Turnip's fixed manor fixtures - the player's house (with a
## bed), both wells, the chapel's tithe/donation box, the market stall, and
## the Lord's Tithe chest, and (E6/ADR-037) the town notice board - which
## farm_map.json only ever stored as single-tile feature flags with no
## visual presence (VSA-1). Anchor positions come from
## GameData.get_all_features(), so they stay data-driven; footprint
## size/shape/colour are presentation constants here, the same pattern
## BuildingRenderer uses for BUILDING_COLORS.
##
## ADR-032: this node no longer draws anything itself. Each fixture gets its
## own StructureVisual (plan section 3), parented as a direct child of
## world_visuals and positioned at its footprint's projected anchor, so
## y_sort_enabled can sort the player against one fixture at a time instead
## of the whole fixed-fixture set moving as a single depth (see the class
## docstring on structure_visual.gd). Built once at startup - manor fixtures
## never move or get added dynamically, unlike player-placed buildings, so
## there is no add/remove signal wiring here, only a colour update on market
## status change. Collision is unchanged from pre-ADR-032: _build_collision,
## _add_wall_body, and _add_solid_tile still spawn StaticBody2D fixtures on
## PhysicsLayers.INTERACTABLE in logical (32-unit) space - CLAUDE.md section
## 8's projection-is-presentation-only invariant means collision never reads
## a projected coordinate, so a wall's drawn diamond and its collision box
## are deliberately not the same shape on screen.

const CELL_SIZE: int = 32

const COLOR_WALL := Color(0.30, 0.22, 0.15)
const COLOR_FLOOR := Color(0.62, 0.52, 0.38)
const COLOR_BED_FRAME := Color(0.40, 0.24, 0.14)
const COLOR_BED_LINEN := Color(0.88, 0.82, 0.68)
const COLOR_WELL_RIM := Color(0.55, 0.55, 0.58)
const COLOR_WELL_WATER := Color(0.16, 0.30, 0.55)
const COLOR_CHEST_WOOD := Color(0.42, 0.26, 0.14)
const COLOR_CHEST_TRIM_CHURCH := Color(0.45, 0.55, 0.75)
const COLOR_CHEST_TRIM_MANOR := Color(0.83, 0.68, 0.25)
const COLOR_STALL_OPEN := Color(0.75, 0.30, 0.28)
const COLOR_STALL_SHUT := Color(0.35, 0.32, 0.30)
const COLOR_STALL_POST := Color(0.32, 0.24, 0.16)
const COLOR_ALEHOUSE_WALL := Color(0.42, 0.27, 0.16)
const COLOR_BOARD_PLANK := Color(0.72, 0.60, 0.42)
const COLOR_BOARD_POST := Color(0.35, 0.27, 0.18)
## Sprint 15b: the boot/fallback zone (mirrors GameData's DEFAULT_ZONE_ID;
## kept local so this file compiles under the headless harness).
const DEFAULT_ZONE_ID := "fallowfield"
## The fixed house gains one North-South row while its South edge stays fixed.
## Keeping the South door at (11,12) avoids a save/data migration; the added
## depth extends northward and does not move the well or transition tile.
const HOUSE_FOOTPRINT := Vector2i(4, 3)
const HOUSE_ANCHOR_OFFSET := Vector2i(2, 2)

## Wall-extrusion heights, in screen pixels, per fixture kind. Expressed as
## multiples of IsoProjection.TILE_H (32, ADR-043's standard 2:1 isometric
## aspect - was 48 under ADR-032's original shallower dimetric angle) so
## the ratio between a walled building and a knee-high well/chest stays
## legible however the tile size is ever retuned (plan section
## "WS-B - Structures").
const HOUSE_HEIGHT_FACTOR: float = 1.6
const WELL_HEIGHT_FACTOR: float = 0.35
const CHEST_HEIGHT_FACTOR: float = 0.4
const STALL_HEIGHT_FACTOR: float = 1.2
const ALEHOUSE_HEIGHT_FACTOR: float = 1.5
const BOARD_HEIGHT_FACTOR: float = 0.7

var _game_data: Node
var _tithe_manager: Node
var _world_visuals: WorldVisuals
var _current_zone_id: String = DEFAULT_ZONE_ID

var _house_anchor := Vector2i(-1, -1)
var _well_anchors: Array[Vector2i] = []
var _chapel_anchor := Vector2i(-1, -1)
var _market_anchor := Vector2i(-1, -1)
var _alehouse_anchor := Vector2i(-1, -1)
var _tithe_chest_anchor := Vector2i(-1, -1)
var _board_anchor := Vector2i(-1, -1)

var _fixture_visuals: Array[StructureVisual] = []
## Interior shell/fixture Sprite2D roots are also direct WorldVisuals
## children, but are not StructureVisuals because a roomy interior is a
## backdrop rather than a footprint-extruded world fixture.
var _interior_visuals: Array[Node2D] = []
var _market_visual: StructureVisual


func configure(game_data: Node, world_visuals: WorldVisuals) -> void:
	_game_data = game_data
	_world_visuals = world_visuals
	set_active_zone(DEFAULT_ZONE_ID)


## Sprint 15b: rebuilds this renderer's content for another zone. Frees the
## previous zone's collision bodies and StructureVisual proxies
## synchronously (this runs from main.gd's zone_changed handler, never from
## a freed node's own callback - CLAUDE.md trap 4), clears every anchor, and
## re-collects/rebuilds from the new zone's feature list.
func set_active_zone(zone_id: String) -> void:
	_current_zone_id = zone_id
	_free_zone_children()
	_house_anchor = Vector2i(-1, -1)
	_well_anchors.clear()
	_chapel_anchor = Vector2i(-1, -1)
	_market_anchor = Vector2i(-1, -1)
	_alehouse_anchor = Vector2i(-1, -1)
	_tithe_chest_anchor = Vector2i(-1, -1)
	_board_anchor = Vector2i(-1, -1)
	_collect_anchors(zone_id)
	_build_collision()
	_build_structures()
	_refresh_stall_color()


## Immediate free(), not queue_free(): the freed children must not linger a
## frame next to the new zone's fixtures, and this call never runs from one
## of those children's own callbacks.
func _free_zone_children() -> void:
	for child: Node in get_children():
		child.free()
	for visual: StructureVisual in _fixture_visuals:
		if is_instance_valid(visual):
			visual.free()
	_fixture_visuals.clear()
	for visual: Node2D in _interior_visuals:
		if is_instance_valid(visual):
			visual.free()
	_interior_visuals.clear()
	_market_visual = null


## /root/TitheManager can only resolve via absolute path once this node is
## actually inside the tree - configure() runs before add_child() (matching
## the rest of main.gd's renderer-setup order), so this lookup has to happen
## here instead, not in configure().
func _ready() -> void:
	_tithe_manager = get_node_or_null("/root/TitheManager")
	if _tithe_manager == null:
		return
	if _tithe_manager.has_signal("market_status_changed"):
		_tithe_manager.market_status_changed.connect(_on_market_status_changed)
	if _tithe_manager.has_signal("black_market_status_changed"):
		_tithe_manager.black_market_status_changed.connect(_on_market_status_changed)
	_refresh_stall_color()


func _collect_anchors(zone_id: String) -> void:
	for entry: Dictionary in _game_data.get_all_features(zone_id):
		var pos := Vector2i(int(entry.get("x", 0)), int(entry.get("y", 0)))
		match str(entry.get("feature", "")):
			"player_house":
				_house_anchor = pos
			"well":
				_well_anchors.append(pos)
			"chapel":
				_chapel_anchor = pos
			"market_zone":
				_market_anchor = pos
			"alehouse":
				_alehouse_anchor = pos
			"town_board":
				_board_anchor = pos
			"stewards_demesne":
				_tithe_chest_anchor = pos


func _on_market_status_changed(_value: Variant) -> void:
	_refresh_stall_color()


func _refresh_stall_color() -> void:
	if _market_visual == null:
		return
	_market_visual.set_top_color(_stall_color())


func _stall_color() -> Color:
	var open := false
	if _tithe_manager != null:
		if _tithe_manager.has_method("is_market_open") and bool(_tithe_manager.is_market_open()):
			open = true
		if _tithe_manager.has_method("is_black_market_open") and bool(_tithe_manager.is_black_market_open()):
			open = true
	return COLOR_STALL_OPEN if open else COLOR_STALL_SHUT


## One StructureVisual per fixture (plan section 3), each a direct child of
## world_visuals so y_sort_enabled sorts them individually against the
## player and NPCs - never a child of this node or of the fixture's own
## collision body.
func _build_structures() -> void:
	if _world_visuals == null:
		return
	if _build_interior_visuals():
		return
	var tile_h := IsoProjection.TILE_H
	if _house_anchor.x >= 0:
		# The feature/bed anchor and South edge stay fixed; the added row
		# extends northward while preserving the existing South door.
		var fx := _house_anchor.x - HOUSE_ANCHOR_OFFSET.x
		var fy := _house_anchor.y - HOUSE_ANCHOR_OFFSET.y
		var house := StructureVisual.new()
		_world_visuals.add_child(house)
		house.configure(Rect2i(Vector2i(fx, fy), HOUSE_FOOTPRINT), COLOR_WALL, tile_h * HOUSE_HEIGHT_FACTOR,
			StructureVisual.Accent.HOUSE, COLOR_BED_FRAME, COLOR_BED_LINEN,
			"player_house", _fixture_sprite_entry("player_house"))
		_fixture_visuals.append(house)
	for well_pos: Vector2i in _well_anchors:
		var well := StructureVisual.new()
		_world_visuals.add_child(well)
		well.configure(Rect2i(well_pos, Vector2i(1, 1)), COLOR_WELL_RIM, tile_h * WELL_HEIGHT_FACTOR,
			StructureVisual.Accent.WELL, COLOR_WELL_WATER,
			Color.WHITE, "well", _fixture_sprite_entry("well"))
		_fixture_visuals.append(well)
	if _chapel_anchor.x >= 0:
		var chapel_chest := StructureVisual.new()
		_world_visuals.add_child(chapel_chest)
		chapel_chest.configure(Rect2i(_chapel_anchor, Vector2i(1, 1)), COLOR_CHEST_WOOD, tile_h * CHEST_HEIGHT_FACTOR,
			StructureVisual.Accent.CHEST, COLOR_CHEST_TRIM_CHURCH,
			Color.WHITE, "chapel", _fixture_sprite_entry("chapel"))
		_fixture_visuals.append(chapel_chest)
	if _tithe_chest_anchor.x >= 0:
		var tithe_chest := StructureVisual.new()
		_world_visuals.add_child(tithe_chest)
		tithe_chest.configure(Rect2i(_tithe_chest_anchor, Vector2i(1, 1)), COLOR_CHEST_WOOD, tile_h * CHEST_HEIGHT_FACTOR,
			StructureVisual.Accent.CHEST, COLOR_CHEST_TRIM_MANOR,
			Color.WHITE, "tithe_chest", _fixture_sprite_entry("tithe_chest"))
		_fixture_visuals.append(tithe_chest)
	if _market_anchor.x >= 0:
		_market_visual = StructureVisual.new()
		_world_visuals.add_child(_market_visual)
		_market_visual.configure(Rect2i(_market_anchor, Vector2i(1, 1)), _stall_color(), tile_h * STALL_HEIGHT_FACTOR,
			StructureVisual.Accent.STALL, COLOR_STALL_POST,
			Color.WHITE, "market_stall", _fixture_sprite_entry("market_stall"))
		_fixture_visuals.append(_market_visual)
	if _alehouse_anchor.x >= 0:
		var alehouse := StructureVisual.new()
		_world_visuals.add_child(alehouse)
		alehouse.configure(Rect2i(_alehouse_anchor, Vector2i(3, 2)), COLOR_ALEHOUSE_WALL,
			tile_h * ALEHOUSE_HEIGHT_FACTOR, StructureVisual.Accent.HOUSE, COLOR_BED_FRAME,
			COLOR_BED_LINEN, "alehouse", _fixture_sprite_entry("alehouse"))
		_fixture_visuals.append(alehouse)
	if _board_anchor.x >= 0:
		var board := StructureVisual.new()
		_world_visuals.add_child(board)
		board.configure(Rect2i(_board_anchor, Vector2i(1, 1)), COLOR_BOARD_PLANK, tile_h * BOARD_HEIGHT_FACTOR,
			StructureVisual.Accent.BOARD, COLOR_BOARD_POST,
			Color.WHITE, "town_board", _fixture_sprite_entry("town_board"))
		_fixture_visuals.append(board)


## Interior art is a background composition, not a terrain tile: place the
## clean shell and every movable fixture directly under WorldVisuals, the
## same live Sprite2D layer that already renders actors. FarmRenderer keeps a
## primitive fallback only if this manifest-backed composition cannot build.
func _build_interior_visuals() -> bool:
	if _game_data == null or not _game_data.has_method("get_zone_interior_visual") \
			or not _game_data.has_method("get_sprite"):
		return false
	var metadata: Dictionary = _game_data.get_zone_metadata(_current_zone_id)
	if not bool(metadata.get("is_interior", false)):
		return false
	var visual_data: Dictionary = _game_data.get_zone_interior_visual(_current_zone_id)
	var shell_entry: Dictionary = _game_data.get_sprite(str(visual_data.get("shell_sprite_id", "")))
	var shell_root := Node2D.new()
	shell_root.name = "InteriorShellVisual"
	var shell_sprite := Sprite2D.new()
	shell_root.add_child(shell_sprite)
	if not SpriteManifest.apply_static(shell_sprite, shell_entry):
		shell_root.free()
		return false
	_world_visuals.add_child(shell_root)
	_interior_visuals.append(shell_root)
	var zone: Dictionary = _game_data.get_zone(_current_zone_id)
	var width := int(zone.get("width", 0))
	var height := int(zone.get("height", 0))
	for fixture_variant: Variant in visual_data.get("fixtures", []):
		var fixture: Dictionary = fixture_variant as Dictionary
		var fixture_entry: Dictionary = _game_data.get_sprite(str(fixture.get("sprite_id", "")))
		var fixture_root := Node2D.new()
		fixture_root.name = "InteriorFixture_%s" % str(fixture.get("sprite_id", ""))
		fixture_root.position = IsoProjection.grid_to_screen(FarmRenderer.interior_fixture_grid_position(
			str(fixture.get("side", "")), int(fixture.get("index", -1)), width, height))
		var fixture_sprite := Sprite2D.new()
		fixture_root.add_child(fixture_sprite)
		if not SpriteManifest.apply_static(fixture_sprite, fixture_entry):
			fixture_root.free()
			continue
		_world_visuals.add_child(fixture_root)
		_interior_visuals.append(fixture_root)
	return true


## Fixed fixtures use the same manifest seam as player-built structures.
## Entries remain optional: an unapproved or absent art asset returns {}, and
## StructureVisual continues to draw the established primitive proxy.
func _fixture_sprite_entry(sprite_id: String) -> Dictionary:
	if _game_data == null or not _game_data.has_method("get_sprite"):
		return {}
	return _game_data.get_sprite(sprite_id)


func _build_collision() -> void:
	_build_interior_walls()
	if _house_anchor.x >= 0:
		_build_house_walls(_house_anchor)
	for well_pos: Vector2i in _well_anchors:
		_add_solid_tile(well_pos)
	if _chapel_anchor.x >= 0:
		_add_solid_tile(_chapel_anchor)
	if _tithe_chest_anchor.x >= 0:
		_add_solid_tile(_tithe_chest_anchor)
	if _market_anchor.x >= 0:
		_add_solid_tile(_market_anchor)
	if _alehouse_anchor.x >= 0:
		_add_solid_footprint(_alehouse_anchor, Vector2i(3, 2))
	if _board_anchor.x >= 0:
		_add_solid_tile(_board_anchor)


func _build_house_walls(bed: Vector2i) -> void:
	var fx := bed.x - HOUSE_ANCHOR_OFFSET.x
	var fy := bed.y - HOUSE_ANCHOR_OFFSET.y
	var width := HOUSE_FOOTPRINT.x
	var height := HOUSE_FOOTPRINT.y
	const WALL_THICK := 6.0
	_add_wall_body(Vector2(fx * CELL_SIZE, fy * CELL_SIZE), Vector2(width * CELL_SIZE, WALL_THICK))
	_add_wall_body(Vector2(fx * CELL_SIZE, fy * CELL_SIZE), Vector2(WALL_THICK, height * CELL_SIZE))
	var door_pos := _house_door_pos()
	var east_door_y := door_pos.y if door_pos.x == fx + width else -1
	if east_door_y < fy or east_door_y >= fy + height:
		_add_wall_body(Vector2((fx + width) * CELL_SIZE - WALL_THICK, fy * CELL_SIZE), Vector2(WALL_THICK, height * CELL_SIZE))
	else:
		if east_door_y > fy:
			_add_wall_body(Vector2((fx + width) * CELL_SIZE - WALL_THICK, fy * CELL_SIZE),
				Vector2(WALL_THICK, float(east_door_y - fy) * CELL_SIZE))
		var lower_start := east_door_y + 1
		if lower_start < fy + height:
			_add_wall_body(Vector2((fx + width) * CELL_SIZE - WALL_THICK, lower_start * CELL_SIZE),
				Vector2(WALL_THICK, float(fy + height - lower_start) * CELL_SIZE))
	var south_door_x := door_pos.x if door_pos.y == fy + height else -1
	if south_door_x < fx or south_door_x >= fx + width:
		_add_wall_body(Vector2(fx * CELL_SIZE, (fy + height) * CELL_SIZE - WALL_THICK),
			Vector2(width * CELL_SIZE, WALL_THICK))
		return
	if south_door_x > fx:
		_add_wall_body(Vector2(fx * CELL_SIZE, (fy + height) * CELL_SIZE - WALL_THICK),
			Vector2(float(south_door_x - fx) * CELL_SIZE, WALL_THICK))
	var south_lower_start := south_door_x + 1
	if south_lower_start < fx + width:
		_add_wall_body(Vector2(south_lower_start * CELL_SIZE, (fy + height) * CELL_SIZE - WALL_THICK),
			Vector2(float(fx + width - south_lower_start) * CELL_SIZE, WALL_THICK))


func _house_door_pos() -> Vector2i:
	if _game_data == null or not _game_data.has_method("get_zone_doors"):
		return Vector2i(-1, -1)
	for door: Dictionary in _game_data.get_zone_doors(DEFAULT_ZONE_ID):
		if str(door.get("to", "")) == "player_home_interior":
			return Vector2i(int(door.get("x", -1)), int(door.get("y", -1)))
	return Vector2i(-1, -1)


## Interior zones are small flat rooms rather than farmland. Their outer walls
## are collision bodies in logical space, with the entrance side left open at
## the range declared by the zone's edge exit. The side is data-defined so the
## interior preserves the exterior building's orientation.
func _build_interior_walls() -> void:
	if _game_data == null or not _game_data.has_method("get_zone"):
		return
	var zone_id := _active_zone_id()
	var metadata: Dictionary = _game_data.get_zone_metadata(zone_id) if _game_data.has_method("get_zone_metadata") else {}
	if not bool(metadata.get("is_interior", false)):
		return
	var zone: Dictionary = _game_data.get_zone(zone_id)
	var width := int(zone.get("width", 0))
	var height := int(zone.get("height", 0))
	if width <= 0 or height <= 0:
		return
	const WALL_THICK := 6.0
	var entrance_side := _interior_entrance_side(zone_id)
	var entrance_index := _interior_entrance_index(zone_id, entrance_side)
	_add_interior_horizontal_wall(interior_collision_wall_origin("north", width, height,
		WALL_THICK).y, width, "north", entrance_side,
		entrance_index, WALL_THICK)
	_add_interior_horizontal_wall(interior_collision_wall_origin("south", width, height,
		WALL_THICK).y, width,
		"south", entrance_side, entrance_index, WALL_THICK)
	_add_interior_vertical_wall(interior_collision_wall_origin("west", width, height,
		WALL_THICK).x, height, "west", entrance_side,
		entrance_index, WALL_THICK)
	_add_interior_vertical_wall(interior_collision_wall_origin("east", width, height,
		WALL_THICK).x, height,
		"east", entrance_side, entrance_index, WALL_THICK)


## Collision bands live just OUTSIDE the logical room rectangle. Their inner
## edges therefore coincide exactly with the perimeter rendered from the
## grid, instead of stealing walkable space inside an otherwise open tile.
static func interior_collision_wall_origin(side: String, width: int, height: int,
		wall_thick: float) -> Vector2:
	match side:
		"north":
			return Vector2(0.0, -wall_thick)
		"east":
			return Vector2(float(width * CELL_SIZE), 0.0)
		"south":
			return Vector2(0.0, float(height * CELL_SIZE))
		"west":
			return Vector2(-wall_thick, 0.0)
	return Vector2.ZERO


func _interior_entrance_side(zone_id: String) -> String:
	if not _game_data.has_method("get_zone_exits"):
		return ""
	for exit: Dictionary in _game_data.get_zone_exits(zone_id):
		var edge := str(exit.get("edge", ""))
		if edge in ["north", "east", "south", "west"]:
			return edge
	return ""


func _interior_entrance_index(zone_id: String, side: String) -> int:
	if not _game_data.has_method("get_zone_exits"):
		return -1
	for exit: Dictionary in _game_data.get_zone_exits(zone_id):
		if str(exit.get("edge", "")) != side:
			continue
		if side in ["east", "west"]:
			return int(exit.get("y_min", -1))
		return int(exit.get("x_min", -1))
	return -1


func _add_interior_horizontal_wall(y: float, width: int, side: String,
		entrance_side: String, entrance_index: int, wall_thick: float) -> void:
	var wall_size := Vector2(float(width * CELL_SIZE), wall_thick)
	if side != entrance_side or entrance_index < 0 or entrance_index >= width:
		_add_wall_body(Vector2(0.0, y), wall_size)
		return
	if entrance_index > 0:
		_add_wall_body(Vector2(0.0, y),
			Vector2(float(entrance_index * CELL_SIZE), wall_thick))
	var lower_start := entrance_index + 1
	if lower_start < width:
		_add_wall_body(Vector2(float(lower_start * CELL_SIZE), y),
			Vector2(float((width - lower_start) * CELL_SIZE), wall_thick))


func _add_interior_vertical_wall(x: float, height: int, side: String,
		entrance_side: String, entrance_index: int, wall_thick: float) -> void:
	var wall_size := Vector2(wall_thick, float(height * CELL_SIZE))
	if side != entrance_side or entrance_index < 0 or entrance_index >= height:
		_add_wall_body(Vector2(x, 0.0), wall_size)
		return
	if entrance_index > 0:
		_add_wall_body(Vector2(x, 0.0),
			Vector2(wall_thick, float(entrance_index * CELL_SIZE)))
	var lower_start := entrance_index + 1
	if lower_start < height:
		_add_wall_body(Vector2(x, float(lower_start * CELL_SIZE)),
			Vector2(wall_thick, float((height - lower_start) * CELL_SIZE)))


func _active_zone_id() -> String:
	return _current_zone_id


func _add_wall_body(top_left: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 0
	body.collision_mask = 0
	body.set_collision_layer_value(PhysicsLayers.INTERACTABLE, true)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	shape.position = top_left + size * 0.5
	body.add_child(shape)
	add_child(body)


func _add_solid_tile(pos: Vector2i) -> void:
	_add_wall_body(Vector2(pos.x * CELL_SIZE, pos.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))


func _add_solid_footprint(anchor: Vector2i, size: Vector2i) -> void:
	for y in range(anchor.y, anchor.y + size.y):
		for x in range(anchor.x, anchor.x + size.x):
			_add_solid_tile(Vector2i(x, y))
