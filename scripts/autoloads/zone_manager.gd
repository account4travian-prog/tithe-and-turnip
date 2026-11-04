extends Node

## ADR-034 (Sprint 15a): the zone registry and zone-keyed world state owner.
## Holds the per-zone FarmGrid references, the active zone id, the player's
## current zone/tile, and the adjacency truth surfaced from zones.json.
## AUTOLOAD - no class_name (CLAUDE.md rule 3.2).
##
## It is deliberately a data/state owner, NOT a world-node owner: change_zone
## only validates, updates state, and emits zone_changed - main.gd's
## zone_changed handler (Sprint 15b) choreographs the scene-side world swap
## (grid/player/camera/renderers/NPC set) so that swap stays in exactly one
## place (the guide's flagged choreography-drift risk).
##
## advance_day() forwards to EVERY registered grid, preserving the current
## single-grid semantics region-wide: rain auto-waters tilled cells in all
## zones even while the player is elsewhere. to_dict()/from_dict() own the
## v18 farm save shape ({current_zone, player_tile, zones}), composing each
## grid's own {cells, daily_dig_count} under its zone id.

signal zone_changed(zone_id: String)

const DEFAULT_ZONE_ID := "fallowfield"
const ISO_PROJECTION := preload("res://scripts/globals/iso_projection.gd")

var _game_data_ref: Node = null
var _grids: Dictionary = {}            # zone_id -> FarmGrid node
var _active_zone_id := DEFAULT_ZONE_ID
var _player_tile := Vector2i(12, 10)   # fallowfield spawn; persisted
var _test_mode := false
var _test_hour := -1                   # -1 = read TimeManager (or work hours)


func configure_for_test(game_data: Node, grids: Dictionary, active_zone := DEFAULT_ZONE_ID) -> void:
	_game_data_ref = game_data
	_grids = grids.duplicate()
	_active_zone_id = active_zone
	_test_mode = true
	if game_data != null and game_data.has_method("get_spawn_point"):
		var spawn: Dictionary = game_data.get_spawn_point()
		if not spawn.is_empty():
			_player_tile = Vector2i(int(spawn.get("x", 12)), int(spawn.get("y", 10)))


func register_farm_grid(zone_id: String, grid: Node) -> void:
	_grids[zone_id] = grid
	if grid != null and grid.has_method("set_zone_id"):
		grid.set_zone_id(zone_id)


func get_farm_grid(zone_id: String) -> Node:
	return _grids.get(zone_id)


func get_all_farm_grids() -> Array[Node]:
	var out: Array[Node] = []
	for zone_id: Variant in _grids:
		out.append(_grids[zone_id])
	return out


func get_active_zone_id() -> String:
	return _active_zone_id


func get_active_farm_grid() -> Node:
	return _grids.get(_active_zone_id)


func get_player_tile() -> Vector2i:
	return _player_tile


func set_player_tile(tile: Vector2i) -> void:
	_player_tile = tile


## The exit whose named edge and index range cover `index` (columns for
## north/south edges, rows for east/west), or {} when no exit matches.
## Index ranges come from zones.json; an omitted range means the whole edge.
func find_exit(zone_id: String, edge: String, index: int) -> Dictionary:
	for exit: Dictionary in get_exits(zone_id):
		if str(exit.get("edge", "")) != edge:
			continue
		if exit.has("x_min"):
			if index < int(exit.get("x_min", 0)) or index > int(exit.get("x_max", -1)):
				continue
		elif exit.has("y_min"):
			if index < int(exit.get("y_min", 0)) or index > int(exit.get("y_max", -1)):
				continue
		return exit
	return {}


func get_exits(zone_id: String) -> Array[Dictionary]:
	var gd := _game_data()
	if gd == null:
		return []
	return gd.get_zone_exits(zone_id)


## The door whose local tile matches `tile`, or {} when this zone has no door
## there. Unlike an edge exit, a door can sit inside a map and is therefore
## checked by main.gd before the ordinary map-edge probe.
func find_door(zone_id: String, tile: Vector2i) -> Dictionary:
	var gd := _game_data()
	if gd == null or not gd.has_method("get_zone_doors"):
		return {}
	for door: Dictionary in gd.get_zone_doors(zone_id):
		if Vector2i(int(door.get("x", -1)), int(door.get("y", -1))) == tile:
			return door
	return {}


## Door equivalent of resolve_exit: the destination and arrival tile must be
## valid before the scene-side zone_changed choreography is invoked.
func resolve_door(zone_id: String, tile: Vector2i) -> Dictionary:
	var door := find_door(zone_id, tile)
	if door.is_empty():
		return {}
	var gd := _game_data()
	if gd == null:
		return {}
	var dest: Dictionary = gd.get_zone(str(door.get("to", "")))
	if dest.is_empty():
		return {}
	var arrive: Dictionary = door.get("arrive_at", {})
	var ax := int(arrive.get("x", -1))
	var ay := int(arrive.get("y", -1))
	if ax < 0 or ax >= int(dest.get("width", 0)) or ay < 0 or ay >= int(dest.get("height", 0)):
		return {}
	return door


## resolve_exit is find_exit plus validation: the destination zone must exist
## and the exit's arrive_at must land inside it. {} means "no transition" -
## a playable boundary (e.g. the South Fields' south edge) or a data bug.
func resolve_exit(zone_id: String, edge: String, index: int) -> Dictionary:
	var exit := find_exit(zone_id, edge, index)
	if exit.is_empty():
		return {}
	var gd := _game_data()
	if gd == null:
		return {}
	var dest: Dictionary = gd.get_zone(str(exit.get("to", "")))
	if dest.is_empty():
		return {}
	var arrive: Dictionary = exit.get("arrive_at", {})
	var ax := int(arrive.get("x", -1))
	var ay := int(arrive.get("y", -1))
	if ax < 0 or ax >= int(dest.get("width", 0)) or ay < 0 or ay >= int(dest.get("height", 0)):
		return {}
	return exit


## Model-layer transition only: validates the zone, updates the active zone
## and the player's tile, emits zone_changed. Does NOT touch scene nodes -
## main.gd's zone_changed handler owns the world swap (Sprint 15b).
func change_zone(zone_id: String, arrive_tile: Vector2i) -> bool:
	var gd := _game_data()
	if gd == null or not gd.get_zone_ids().has(zone_id):
		return false
	_active_zone_id = zone_id
	_player_tile = arrive_tile
	zone_changed.emit(zone_id)
	return true


## Which zone a villager currently anchors in: marriage override first (the
## spouse lives at Fallowfield's cottage), festival override second (all
## festivals anchor in Nettleford this slice), otherwise the work/home
## schedule's zone for the current hour. Sprint 15b consumes this to decide
## world presence; 15a ships it as the pure data/state query.
func get_npc_zone(npc_id: String) -> String:
	if not _test_mode:
		# Live-tree overrides only: off-tree suites must not trigger
		# get_node_or_null with absolute paths (4.7 errors on that), and
		# neither autoload has a test-injection seam of its own.
		var mm := get_node_or_null("/root/MarriageManager")
		if mm != null and mm.has_method("is_spouse") and mm.is_spouse(npc_id):
			return DEFAULT_ZONE_ID
		var fm := get_node_or_null("/root/FestivalManager")
		if fm != null and fm.has_method("get_active_festival_anchor"):
			var anchor: Dictionary = fm.get_active_festival_anchor()
			if not anchor.is_empty():
				return str(anchor.get("zone", "nettleford"))
	var gd := _game_data()
	if gd == null:
		return DEFAULT_ZONE_ID
	var schedule: Dictionary = gd.get_villager_schedule(npc_id)
	var hour := _current_hour()
	var anchor: Dictionary = schedule.get("work", {}) \
		if hour >= int(schedule.get("work_start_hour", 8)) and hour < int(schedule.get("work_end_hour", 18)) \
		else schedule.get("home", {})
	return str(anchor.get("zone", DEFAULT_ZONE_ID))


## The set of villager ids whose current zone (get_npc_zone, with every
## override applied) equals the active zone. Sprint 15b consumes this to
## decide world presence at zone crossings and on the hour boundary; the
## integration suite asserts the membership matrix directly.
func get_active_zone_npc_ids() -> Array[String]:
	var out: Array[String] = []
	var gd := _game_data()
	if gd == null:
		return out
	for npc_id: String in gd.get_all_villager_ids():
		if get_npc_zone(npc_id) == _active_zone_id:
			out.append(npc_id)
	return out


## Forwards to every registered grid: the rain/overcast day rollover applies
## region-wide, preserving the single-grid semantics where one advance_day
## touched every tilled cell (now per zone). `day` (ADR-040) drives the
## demesne's stored-sheaf replenish cadence on whichever zone's grid owns
## the lord's demesne - forwarded to every grid the same way rain/overcast
## already are, since each grid's advance_day ignores it harmlessly if it
## carries no demesne rect.
func advance_day(rain: bool, overcast: bool, day: int = 1) -> void:
	for zone_id: Variant in _grids:
		var grid := _grids[zone_id] as Node
		if grid != null:
			grid.advance_day(rain, overcast, day)


## The v18 farm save shape: current_zone + player_tile + one {cells,
## daily_dig_count} per registered zone. FarmGrid itself never learns about
## zones in its own to_dict - the zone dimension is composed here.
func to_dict() -> Dictionary:
	var zones := {}
	for zone_id: Variant in _grids:
		var grid := _grids[zone_id] as Node
		if grid != null:
			zones[zone_id] = grid.to_dict()
	return {
		"current_zone": _active_zone_id,
		"player_tile": {"x": _player_tile.x, "y": _player_tile.y},
		"zones": zones,
	}


## Restores per-zone farm state into every registered grid, plus the active
## zone and player tile. A flat {cells, daily_dig_count} payload (the
## pre-v18 shape, e.g. from an injected single-grid test fixture) falls back
## to the default zone's grid.
func from_dict(data: Dictionary) -> void:
	_active_zone_id = str(data.get("current_zone", DEFAULT_ZONE_ID))
	var tile: Dictionary = data.get("player_tile", {})
	_player_tile = Vector2i(int(tile.get("x", 12)), int(tile.get("y", 10)))
	var zones: Dictionary = data.get("zones", {})
	if zones.is_empty() and data.has("cells"):
		var default_grid: Node = _grids.get(DEFAULT_ZONE_ID)
		if default_grid != null:
			default_grid.from_dict(data)
		return
	for zone_id: Variant in zones:
		var grid: Node = _grids.get(zone_id)
		if grid != null:
			grid.from_dict(zones[zone_id] as Dictionary)


## Repositions the player to the persisted tile and announces the saved zone
## so the world swap can run. main.gd calls this after load once Sprint 15b
## ships the zone_changed handler; 15a keeps it available and untriggered
## (the player position is otherwise scene-default at boot).
func apply_saved_state(player: Node) -> void:
	if player == null:
		return
	var half_cell := ISO_PROJECTION.LOGICAL_CELL / 2.0
	player.position = Vector2(
		_player_tile.x * ISO_PROJECTION.LOGICAL_CELL + half_cell,
		_player_tile.y * ISO_PROJECTION.LOGICAL_CELL + half_cell)
	if player.get("velocity") != null:
		player.set("velocity", Vector2.ZERO)
	zone_changed.emit(_active_zone_id)


func _current_hour() -> int:
	if _test_hour >= 0:
		return _test_hour
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		return int(tm.get("hour"))
	## Off-tree (tests) with no injected hour: every shipped schedule's work
	## window starts at or before 8, so hour 8 resolves every villager to
	## their work anchor deterministically.
	return 8


func _game_data() -> Node:
	if _game_data_ref != null:
		return _game_data_ref
	return get_node_or_null("/root/GameData")
