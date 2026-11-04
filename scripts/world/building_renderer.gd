class_name BuildingRenderer
extends Node2D

## Owns the visuals for BuildingManager state: completed footprints, in-
## progress ones dimmer with a construction hatch, plus the placement ghost
## (green = placeable, red = blocked) that follows the player's faced tile
## while the build panel is in placement mode.
##
## ADR-032: this node no longer draws anything itself. Every placed building
## - and the ghost - gets its own StructureVisual (plan section 3), parented
## as a direct child of world_visuals and positioned at its footprint's
## projected anchor, so y_sort_enabled can sort the player against one
## building at a time instead of the whole placed-building set moving as a
## single depth. The building list only changes on building_started/
## building_completed, so the child set is rebuilt on those signals rather
## than redrawn every frame; the ghost reconfigures its single persistent
## StructureVisual every time show_ghost() moves it.
##
## ADR-041 (Sprint 16 WS-B): placed buildings pass their building id and
## its manifest entry (GameData.get_sprite(building_id), resolved here
## because this renderer already holds the GameData reference) into
## StructureVisual.configure(), so a building with an entry in
## data/sprites_structures.json renders a textured child and every other id
## keeps the primitive extruded-box fallback. The ghost deliberately gets no
## sprite id or entry: its green/red tint is the placeable/blocked signal
## and must stay primitive.

const BUILDING_COLORS := {
	"storage_chest": Color(0.55, 0.42, 0.25),
	"drying_shed": Color(0.72, 0.60, 0.38),
	"well_extra": Color(0.35, 0.55, 0.65),
	"fence": Color(0.45, 0.40, 0.35),
	"cottage_upgrade": Color(0.50, 0.28, 0.22),
}
const DEFAULT_BUILDING_COLOR := Color(0.6, 0.6, 0.6)

## Wall-extrusion heights, in screen pixels, per building id - a fence reads
## as knee-high, a cottage upgrade as a full second structure, everything
## else in between. Unlisted ids (a future building.json entry with no
## height tuned yet) fall back to DEFAULT_HEIGHT_FACTOR rather than drawing
## flat, so a new building always reads as a box on day one. Textured
## buildings keep their tuned factor as the primitive's own height, but the
## visible height comes from the sprite's height_tiles data instead.
const BUILDING_HEIGHT_FACTORS := {
	"storage_chest": 0.5,
	"drying_shed": 0.9,
	"well_extra": 0.35,
	"fence": 0.25,
	"cottage_upgrade": 1.3,
}
const DEFAULT_HEIGHT_FACTOR: float = 0.6

const GHOST_PLACEABLE := Color(0.2, 0.8, 0.2, 0.55)
const GHOST_BLOCKED := Color(0.8, 0.2, 0.2, 0.55)

var _building_manager: Node
var _game_data: Node
var _world_visuals: WorldVisuals
## Sprint 15b: which zone's placed buildings this renderer currently shows.
## All buildings live on fallowfield this sprint, but the rebuild must not
## mix zone-local coordinates across maps.
var _active_zone_id := "fallowfield"
var _ghost_id := ""
var _ghost_pos := Vector2i(-1, -1)

var _building_visuals: Array[StructureVisual] = []
var _ghost_visual: StructureVisual


func configure(building_manager: Node, game_data: Node, world_visuals: WorldVisuals) -> void:
	_building_manager = building_manager
	_game_data = game_data
	_world_visuals = world_visuals
	_active_zone_id = "fallowfield"
	if _building_manager != null:
		if _building_manager.has_signal("building_started"):
			_building_manager.building_started.connect(_on_buildings_changed)
		if _building_manager.has_signal("building_completed"):
			_building_manager.building_completed.connect(_on_buildings_changed)
	if _world_visuals != null:
		_ghost_visual = StructureVisual.new()
		_world_visuals.add_child(_ghost_visual)
		_ghost_visual.visible = false
	_rebuild_buildings()


## Sprint 15b: rebuilds visuals for another zone's placed buildings. The
## ghost is hidden - its footprint/position are zone-local and stale across
## a crossing.
func set_active_zone(zone_id: String) -> void:
	_active_zone_id = zone_id
	hide_ghost()
	_rebuild_buildings()


func show_ghost(building_id: String, pos: Vector2i) -> void:
	_ghost_id = building_id
	_ghost_pos = pos
	_update_ghost()


func hide_ghost() -> void:
	_ghost_id = ""
	_ghost_pos = Vector2i(-1, -1)
	if _ghost_visual != null:
		_ghost_visual.visible = false


func _on_buildings_changed(_building_id: String, _pos: Vector2i) -> void:
	_rebuild_buildings()
	# A newly-started/completed building can change what tile the ghost is
	# currently sitting on top of - can_place_building's answer may have
	# flipped, so re-evaluate rather than leaving a stale colour up.
	if not _ghost_id.is_empty():
		_update_ghost()


## Frees the previous StructureVisual set and rebuilds it from
## BuildingManager's current list. Uses an immediate free() rather than
## queue_free(): this runs from a BuildingManager signal, never from one of
## these visuals' own callbacks, so freeing them synchronously here is safe
## (CLAUDE.md trap 4 is about touching an already-freed node, not about which
## free variant a safe owner uses) and keeps world_visuals' child set
## consistent the instant this call returns, with no deferred-frame window
## where a stale and a fresh visual for the same building would coexist.
func _rebuild_buildings() -> void:
	for visual: StructureVisual in _building_visuals:
		if is_instance_valid(visual):
			visual.free()
	_building_visuals.clear()
	if _building_manager == null or _game_data == null or _world_visuals == null:
		return
	for entry: Dictionary in _building_manager.get_placed_buildings(_active_zone_id):
		var x := int(entry.get("x", 0))
		var y := int(entry.get("y", 0))
		var w := int(entry.get("w", 1))
		var h := int(entry.get("h", 1))
		var building_id := str(entry.get("building_id", ""))
		var visual := StructureVisual.new()
		_world_visuals.add_child(visual)
		# ADR-041: the building id doubles as the manifest sprite id, and the
		# parsed entry comes from the GameData reference this renderer already
		# holds (no /root/GameData reach needed, so off-tree tests exercise the
		# real textured path deterministically). An empty entry for an unlisted
		# id leaves the primitive fallback below.
		var sprite_entry: Dictionary = _game_data.get_sprite(building_id)
		visual.configure(Rect2i(x, y, w, h), _color_for(building_id), _height_for(building_id),
			StructureVisual.Accent.NONE, Color.WHITE, Color.WHITE, building_id, sprite_entry)
		visual.set_in_progress(not bool(entry.get("complete", false)))
		_building_visuals.append(visual)


func _update_ghost() -> void:
	if _ghost_visual == null or _game_data == null or _building_manager == null:
		return
	var def: Dictionary = _game_data.get_building(_ghost_id)
	if def.is_empty():
		_ghost_visual.visible = false
		return
	var w := int(def.get("footprint_w", 1))
	var h := int(def.get("footprint_h", 1))
	var placeable: bool = bool(_building_manager.can_place_building(_ghost_id, _ghost_pos))
	var color := GHOST_PLACEABLE if placeable else GHOST_BLOCKED
	# No sprite id or entry on purpose: the ghost's green/red tint is its
	# meaning.
	_ghost_visual.configure(Rect2i(_ghost_pos, Vector2i(w, h)), color, _height_for(_ghost_id))
	_ghost_visual.visible = true


func _color_for(building_id: String) -> Color:
	return BUILDING_COLORS.get(building_id, DEFAULT_BUILDING_COLOR)


func _height_for(building_id: String) -> float:
	var factor: float = BUILDING_HEIGHT_FACTORS.get(building_id, DEFAULT_HEIGHT_FACTOR)
	return IsoProjection.TILE_H * factor
