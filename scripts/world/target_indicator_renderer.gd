class_name TargetIndicatorRenderer
extends Node2D

## Playtest fix (item 4): draws the tile(s) the next Interact will affect
## while Interact is held, and draws a lighter assist target when normal
## interaction has selected a nearby character/object. Colors follow the shipped
## BuildingRenderer placement-ghost convention verbatim (green = the action
## will succeed here, red = it won't) for visual consistency across the
## game's two "preview an action before it commits" features. Geometric
## primitives only (CLAUDE.md's out-of-scope list bans sprites/textures) -
## a diamond per tile via IsoProjection.cell_diamond(), the ONLY screen-space
## math this file uses (ADR-032, CLAUDE.md section 8's invariant).
##
## No culling: Player.get_interaction_info()/ToolManager.get_action_info()
## never return more than 3 tiles (the iron hoe's line_3x1), always adjacent
## to the player and therefore always on-screen.
##
## Drawn as a sibling ABOVE world_visuals (main.gd wires this at sibling
## index 4, after the building renderer) so no structure, fixture, or NPC
## can occlude the one thing the player is trying to aim at - deliberately
## the topmost world-space layer; only the HUD CanvasLayer draws above it.

const TARGET_VALID: Color = Color(0.2, 0.8, 0.2, 0.55)   # BuildingRenderer.GHOST_PLACEABLE
const TARGET_INVALID: Color = Color(0.8, 0.2, 0.2, 0.55) # BuildingRenderer.GHOST_BLOCKED
const TARGET_OUTLINE: Color = Color(0.12, 0.09, 0.07, 0.85)
const TARGET_OUTLINE_WIDTH: float = 1.5

var _player: Player
var _tiles: Array[Vector2i] = []
var _tile_valid: Dictionary = {}
var _aggregate_valid: bool = false


func configure(player: Player) -> void:
	_player = player


## Presentation-only poll (CLAUDE.md section 4 - reads gameplay state but
## writes none): there is no facing/tool/hold-changed signal today, and the
## faced tile changes continuously while the player moves. Player interaction
## preview data is cached for the current physics tick, so this render poll
## shares one resolver result with the HUD without repeating the forward scan.
## Redraws remain unconditional while a hold or assist target is active rather
## than diffing against the previous frame's tiles - at most 3 polygons, so a
## Dictionary/Array equality check is not worth the extra state.
func _process(_delta: float) -> void:
	if _player == null or not is_instance_valid(_player):
		if visible:
			visible = false
		return
	var info: Dictionary = _player.get_interaction_info()
	var showing := _player.is_interact_hold_active() or bool(info.get("assisted", false))
	if not showing:
		if visible:
			visible = false
		return
	# Bug fix: `as Array[Vector2i]` on a bare `[target]` literal (an untyped
	# Array at runtime, even though every element is a Vector2i) errors -
	# "Trying to assign an array of type 'Array' to a variable of type
	# 'Array[Vector2i]'" - not a silent no-op. Every get_interaction_info()/
	# get_action_info() branch was audited and fixed to return a properly
	# typed array, but rebuilding by iteration here is robust regardless of
	# whether every future branch remembers to do the same.
	var raw_tiles: Array = info.get("tiles", [])
	var tiles: Array[Vector2i] = []
	for tile: Variant in raw_tiles:
		tiles.append(tile as Vector2i)
	_tiles = tiles
	_tile_valid = info.get("tile_valid", {})
	_aggregate_valid = bool(info.get("valid", false))
	visible = true
	queue_redraw()


func _draw() -> void:
	for tile: Vector2i in _tiles:
		var diamond := IsoProjection.cell_diamond(tile)
		# Per-tile honesty (a line_3x1 swing across a demesne boundary or a
		# partially-tilled row must not read as "the whole row will till") -
		# but the aggregate gate (energy, water, seed/compost inventory)
		# still forces every diamond red if the swing cannot fire at all.
		var tile_ok: bool = _aggregate_valid and bool(_tile_valid.get(tile, false))
		draw_colored_polygon(diamond, TARGET_VALID if tile_ok else TARGET_INVALID)
		draw_polyline(
			PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]),
			TARGET_OUTLINE, TARGET_OUTLINE_WIDTH)
