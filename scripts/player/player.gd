class_name Player
extends CharacterBody2D

## Player controller: 8-direction movement through InputManager, facing
## tracking, and tool use on the `interact` action. Equip keys 1/2/3 come
## from InputManager runtime actions. All input reads go through InputManager.
##
## ADR-032 (isometric projection, amended ADR-043): InputManager still returns a raw
## screen-space vector (CLAUDE.md section 9.4 - InputManager is not the place
## the rotation happens). This script rotates that vector into logical grid
## space via IsoProjection.input_to_world_dir() before it becomes `velocity`,
## so pressing "up" always moves the player visibly up on screen (the
## Stardew convention ADR-032 picked) even though grid-space speed now varies
## by heading (plan section 2.1 - documented, not a bug). Facing widened from
## 4-way to 8-way for the same reason (plan section 2.3): under the rotation
## the four screen cardinals land on the four grid diagonals, so a 4-way
## facing would leave four of every tile's eight neighbours unreachable.
## This script draws nothing of its own - see scripts/player/player_visual.gd
## for the proxy that renders the body and facing indicator at the projected
## screen position (plan section 3). The old `rotation = ...` line that used
## to spin this CharacterBody2D to face its movement direction is gone: that
## was a top-down affordance, and rotating a node whose position is later
## reprojected at an isometric angle would read as a sheared smear.
## ADR-040 (spatial demesne chores): the stewards_demesne feature no longer
## swallows every interaction into the tithe panel. With a hoe or watering
## can equipped, interacting on a demesne tile is a tool chore; with bare
## hands it is harvest (clear stored sheaves) or delivery (carry to the
## tithe chest) when those are available, and only falls back to opening the
## tithe panel when there is no spatial action on offer.

const CELL_SIZE: int = 32

## Deterministic 8-way facing (ADR-032, plan section 2.3): the eight
## Vector2i king-move neighbours, indexed by 45-degree sector starting at
## grid-east (angle 0) and advancing through the sectors in the same
## direction Vector2.angle() increases (mathematically counter-clockwise;
## with Godot's y-down screen/grid convention this reads as clockwise
## through south). See _vector_to_facing for the sector math.
const FACING_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
## One sector's angular width: 360 degrees / 8 = 45 degrees, in radians.
const FACING_SECTOR_ANGLE: float = TAU / 8.0
## Below this squared length, an input vector is treated as "no input" and
## facing is left unchanged rather than snapped to an arbitrary sector -
## structural numerical epsilon (a near-zero vector's angle() is meaningless),
## not a gameplay tunable, so it stays a local constant rather than JSON data.
const FACING_DEADZONE_SQ: float = 0.0001
const TARGET_RESOLVER: Script = preload("res://scripts/player/target_resolver.gd")

signal interacted_with(feature: String, pos: Vector2i)
signal npc_interacted(npc_id: String)
signal station_interacted(station_id: String, pos: Vector2i)

var _facing: Vector2i = Vector2i.DOWN
var _tool_manager: ToolManager
var _farm_grid: Node
## Playtest fix: hold-to-preview state (item 4) - press Interact to start
## aiming (the target indicator appears), release to commit through the
## unchanged _use_tool() path, Esc/any menu opening to cancel with no
## action. See _interact_hold_step for the transition table.
var _interact_hold_active := false
## Sprint 15b: the active zone id, kept in step with the active FarmGrid.
## GameData's zone-aware accessors default to fallowfield, so every feature
## lookup at the faced tile must pass this or wells/market/chapel
## interactions silently die outside the holding.
var _zone_id := "fallowfield"
var _npc_lookup: Callable = Callable()
## Assist tuning is loaded from data/player.json so the forward cone and aim
## cadence can be adjusted without changing gameplay code.
var _interaction_assist_range: int = 2
var _interaction_assist_cone_degrees: float = 45.0
var _aim_repeat_delay: float = 0.22
var _aim_repeat_interval: float = 0.10
var _interact_hold_target: Vector2i = Vector2i.ZERO
var _interact_hold_target_assisted: bool = false
var _interact_hold_target_kind: String = ""
var _aim_target: Vector2i = Vector2i.ZERO
var _aim_direction: Vector2i = Vector2i.ZERO
var _aim_repeat_elapsed: float = 0.0
var _aim_repeat_started: bool = false
var _holding_item_aim: bool = false
## HUD and world-preview consumers can ask for the same read-only interaction
## information during one render frame. Recompute once per physics tick so the
## forward-cone scan and feature/building lookups never run twice per frame.
var _interaction_info_cache: Dictionary = {}
var _interaction_info_cache_valid: bool = false
var _speed := 220.0
## Perf pass (2026-08-10): resolved once and reused across physics ticks
## instead of a fresh get_node_or_null() every tick (60 Hz) - see
## _physics_process's own comment for why get_node_or_null is used at all
## instead of a bare autoload identifier. Caching the resolved Node here
## does not reintroduce that problem: the compile-time hazard is a bare
## AUTOLOAD-TYPED identifier anywhere in the file, not a plain `Node`-typed
## member variable, so this stays just as safe for the headless test
## harness (where both simply stay null, exactly as before).
var _input_manager_ref: Node
var _ui_manager_ref: Node


func _ready() -> void:
	add_to_group("player")
	var game_data = get_node_or_null("/root/GameData")
	if game_data != null:
		_speed = float(game_data.player_cfg.get("move_speed", 220.0))
		_interaction_assist_range = maxi(1, int(game_data.player_cfg.get("interaction_assist_range", 2)))
		_interaction_assist_cone_degrees = float(game_data.player_cfg.get("interaction_assist_cone_degrees", 45.0))
		_aim_repeat_delay = maxf(0.0, float(game_data.player_cfg.get("aim_repeat_delay", 0.22)))
		_aim_repeat_interval = maxf(0.01, float(game_data.player_cfg.get("aim_repeat_interval", 0.10)))
	# VSA-1: collide with the new fixed-structure walls (house/well/chapel/
	# market/tithe-chest StaticBody2Ds spawned by FeatureRenderer) without
	# touching the editor-built collision_mask already set on this node.
	set_collision_mask_value(PhysicsLayers.INTERACTABLE, true)


func set_farm_grid(farm_grid: Node) -> void:
	_farm_grid = farm_grid
	_zone_id = _zone_from_grid(farm_grid)
	_invalidate_interaction_info_cache()
	_tool_manager = ToolManager.new()
	add_child(_tool_manager)
	_tool_manager.init(get_node_or_null("/root/PlayerState"), farm_grid)


## Sprint 15b live re-wire: swaps the active grid WITHOUT recreating the
## ToolManager (boot's set_farm_grid owns creation; a zone crossing must not
## reset the tool or refill water). Also flips the active zone id so every
## GameData feature lookup resolves against the new zone.
func set_active_farm_grid(farm_grid: Node) -> void:
	_farm_grid = farm_grid
	_zone_id = _zone_from_grid(farm_grid)
	_invalidate_interaction_info_cache()
	if _tool_manager != null:
		_tool_manager.set_farm_grid(farm_grid)


func get_farm_grid() -> Node:
	return _farm_grid


func _zone_from_grid(farm_grid: Node) -> String:
	if farm_grid != null and farm_grid.has_method("get_zone_id"):
		var zone_id := str(farm_grid.get_zone_id())
		if not zone_id.is_empty():
			return zone_id
	return "fallowfield"


func set_npc_lookup(lookup: Callable) -> void:
	_npc_lookup = lookup
	_invalidate_interaction_info_cache()


func get_tool_manager() -> ToolManager:
	return _tool_manager


## Single read-only interaction dispatch (VSA-2, extended - playtest fix,
## item 4): every consumer - the HUD text hint, the target indicator - reads
## this one chain so the branches cannot drift from each other or from
## _use_tool()'s real mutation chain. Normal interaction first resolves the
## nearest eligible character, then the nearest eligible object in the narrow
## forward cone. Held item aiming bypasses that assist and uses its own grid
## target. Returns { "text": String, "valid": bool, "tiles":
## Array[Vector2i], "tile_valid": Dictionary (Vector2i -> bool), "target":
## Vector2i, "assisted": bool }.
func get_interaction_info() -> Dictionary:
	var empty := {"text": "", "valid": false, "tiles": [] as Array[Vector2i], "tile_valid": {}}
	var ui = get_node_or_null("/root/UIManager")
	if ui != null and bool(ui.get("menu_open")):
		return empty
	if _interaction_info_cache_valid:
		return _interaction_info_cache
	if _farm_grid == null or _tool_manager == null:
		_interaction_info_cache = empty
		_interaction_info_cache_valid = true
		return _interaction_info_cache
	var target: Vector2i = get_faced_tile()
	var assisted := false
	var target_kind := ""
	if _interact_hold_active:
		target = _aim_target if _holding_item_aim else _interact_hold_target
		assisted = _interact_hold_target_assisted and not _holding_item_aim
		target_kind = "" if _holding_item_aim else _interact_hold_target_kind
	else:
		var resolved := _resolve_normal_target()
		target = resolved.get("target", target) as Vector2i
		assisted = bool(resolved.get("assisted", false))
		target_kind = str(resolved.get("kind", ""))
	var info := _interaction_info_at(target, target_kind)
	info["target"] = target
	info["assisted"] = assisted
	_interaction_info_cache = info
	_interaction_info_cache_valid = true
	return _interaction_info_cache


## Exact target dispatch used by both normal fallback and held aim. The
## assist resolver is deliberately outside this chain so farming tools never
## silently jump to a nearby tile.

func _interaction_info_at(target: Vector2i, preferred_kind: String = "") -> Dictionary:
	if preferred_kind == "character":
		return _npc_interaction_info(target)
	if preferred_kind == "object":
		return _object_interaction_info(target)
	var object_info := _object_interaction_info(target)
	if not str(object_info.get("text", "")).is_empty():
		return object_info
	var npc_info := _npc_interaction_info(target)
	if not str(npc_info.get("text", "")).is_empty():
		return npc_info
	return _tool_manager.get_action_info(target)


## Normal interaction assist: characters always outrank objects, and both are
## constrained to a deterministic forward cone. If nothing qualifies, the
## exact faced tile remains the fallback for tools and tile actions.
func _resolve_normal_target() -> Dictionary:
	var current := get_current_tile()
	var offsets: Array[Vector2i] = TARGET_RESOLVER.forward_offsets(
		_facing, _interaction_assist_range, _interaction_assist_cone_degrees)
	for offset: Vector2i in offsets:
		var target := current + offset
		var npc_id := _npc_id_at(target)
		if not npc_id.is_empty():
			return {"target": target, "assisted": target != get_faced_tile(),
				"kind": "character", "npc_id": npc_id}
	for offset: Vector2i in offsets:
		var target := current + offset
		var object_info := _object_interaction_info(target)
		if bool(object_info.get("valid", false)) and not str(object_info.get("text", "")).is_empty():
			return {"target": target, "assisted": target != get_faced_tile(), "kind": "object"}
	return {"target": get_faced_tile(), "assisted": false, "kind": ""}


func _npc_interaction_info(target: Vector2i) -> Dictionary:
	var npc_id := _npc_id_at(target)
	if npc_id.is_empty():
		return {"text": "", "valid": false, "tiles": [] as Array[Vector2i], "tile_valid": {}}
	var game_data = get_node_or_null("/root/GameData")
	var villager: Dictionary = game_data.get_villager(npc_id) if game_data != null else {}
	return {"text": "Talk to %s" % str(villager.get("name", "Someone")), "valid": true,
		"tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}


func _object_interaction_info(target: Vector2i) -> Dictionary:
	var game_data = get_node_or_null("/root/GameData")
	var feature := ""
	if game_data != null:
		feature = game_data.get_feature_at(target.x, target.y, _zone_id)
	var bm = get_node_or_null("/root/BuildingManager")
	if feature == "well" or (bm != null and bm.is_well_at(target, _zone_id)):
		# Playtest fix: this used to say "Fill Watering Can" unconditionally,
		# even with a hoe equipped - _use_tool() would then no-op, since
		# ToolManager.refill_watering_can() only succeeds with a can
		# equipped. can_refill_watering_can() makes the text/validity agree
		# with what interacting would actually do.
		var can_refill: bool = _tool_manager.can_refill_watering_can()
		var text := "Fill Watering Can" if can_refill else ""
		return {"text": text, "valid": can_refill, "tiles": [target] as Array[Vector2i], "tile_valid": {target: can_refill}}
	var station_id: String = bm.get_building_id_at(target, _zone_id) if bm != null else ""
	if station_id == "coop":
		return {"text": "Tend the Coop", "valid": true, "tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}
	if station_id == "drying_shed" or station_id == "hearth":
		var text := "Use the %s" % (str(game_data.get_building(station_id).get("name", station_id)) if game_data != null else station_id)
		return {"text": text, "valid": true, "tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}
	# ADR-040: on the demesne, the preview reflects the spatial action that
	# interact will actually take - a tool chore, a bare-hand chore, or the
	# tithe panel as the fallback.
	if feature == "stewards_demesne":
		if _equipped_is_farm_tool():
			return _tool_manager.get_action_info(target)
		var tm := get_node_or_null("/root/TitheManager")
		if tm != null and tm.has_method("can_demesne_chore_at"):
			if bool(tm.can_demesne_chore_at("carry_produce", target)):
				return {"text": "Deliver Sheaves to the Tithe Chest", "valid": true,
					"tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}
			if bool(tm.can_demesne_chore_at("harvest_demesne", target)):
				return {"text": "Clear Stored Sheaves", "valid": true,
					"tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}
		return {"text": "Pay the Lord's Tithe", "valid": true, "tiles": [target] as Array[Vector2i], "tile_valid": {target: true}}
	if not feature.is_empty():
		var text := _describe_feature(feature)
		var ok := not text.is_empty()
		return {"text": text, "valid": ok, "tiles": [target] as Array[Vector2i], "tile_valid": {target: ok}}
	return {"text": "", "valid": false, "tiles": [] as Array[Vector2i], "tile_valid": {}}


func _npc_id_at(target: Vector2i) -> String:
	if not _npc_lookup.is_valid():
		return ""
	return str(_npc_lookup.call(target))


## Text-only wrapper over get_interaction_info() - kept for HudPanel's
## existing call site (unchanged).
func get_interaction_preview() -> String:
	return str(get_interaction_info().get("text", ""))


func _describe_feature(feature: String) -> String:
	match feature:
		"market_zone":
			return "Open the Market"
		"chapel":
			return "Donate at the Tithe Box"
		"stewards_demesne":
			return "Pay the Lord's Tithe"
		"town_board":
			return "Read the Town Board"
		"player_house":
			return "Sleep"
		_:
			return ""


## The tile in front of the player - shared by tool use (`_use_tool`) and
## Sprint 7's HUD tile tooltip, so the facing math lives in exactly one place.
## Signature and meaning are unchanged by ADR-032 - every downstream consumer
## (tool use, feature interaction, NPC dialogue, combat) keeps working as-is.
func get_faced_tile() -> Vector2i:
	return get_current_tile() + _facing


## The tile the player is standing on (not the faced tile).
func get_current_tile() -> Vector2i:
	return Vector2i(floori(global_position.x / CELL_SIZE), floori(global_position.y / CELL_SIZE))


## Current 8-way grid-space facing, as a unit king-move offset. Read by
## PlayerVisual (scripts/player/player_visual.gd) to orient the drawn face
## indicator - the proxy has no other way to see this private state.
func get_facing() -> Vector2i:
	return _facing


## Playtest fix: whether Interact is currently held (aiming). Read by
## UIManager (Esc-vs-pause routing) and TargetIndicatorRenderer (whether to
## draw at all).
func is_interact_hold_active() -> bool:
	return _interact_hold_active


## Aborts a hold with no action taken. Idempotent - called by UIManager
## (Esc while holding, or any menu opening) and main.gd's zone-crossing
## handler, so a hold can never commit across a map swap or into a menu the
## player never saw open.
func cancel_interact_hold() -> void:
	_interact_hold_active = false
	_interact_hold_target_assisted = false
	_interact_hold_target_kind = ""
	_holding_item_aim = false
	_aim_direction = Vector2i.ZERO
	_aim_repeat_elapsed = 0.0
	_aim_repeat_started = false
	_invalidate_interaction_info_cache()


func _invalidate_interaction_info_cache() -> void:
	_interaction_info_cache_valid = false


func _physics_process(delta: float) -> void:
	# get_node_or_null rather than the bare `InputManager` singleton
	# identifier - a deliberate divergence from this method's pre-ADR-032
	# form. GDScript resolves ALL identifiers in a script at compile time
	# (whole-class static analysis), so a bare autoload identifier anywhere
	# in the file - even one this method alone used - makes the WHOLE script
	# fail to compile when the autoload isn't registered, which is exactly
	# the case for tests/suites/test_iso_actors.gd's
	# preload("res://scripts/player/player.gd").new(): the headless harness
	# never boots autoloads (test_court.gd's docstring notes the same for
	# /root lookups generally). get_node_or_null resolves at runtime instead,
	# so it compiles fine either way and is identical at runtime to the bare
	# form once the game is actually running. Perf pass (2026-08-10): the
	# resolved reference is now cached in _input_manager_ref/_ui_manager_ref
	# and only re-resolved when invalid, instead of paying for the lookup
	# every one of these 60-Hz ticks.
	if not is_instance_valid(_input_manager_ref):
		_input_manager_ref = get_node_or_null("/root/InputManager")
	var input_manager = _input_manager_ref
	if input_manager == null:
		return
	_invalidate_interaction_info_cache()
	if not is_instance_valid(_ui_manager_ref):
		_ui_manager_ref = get_node_or_null("/root/UIManager")
	var ui = _ui_manager_ref
	var menu_open := ui != null and bool(ui.get("menu_open"))
	var pressed: bool = bool(input_manager.is_action_just_pressed("interact"))
	var released: bool = bool(input_manager.is_action_just_released("interact"))
	var was_holding := _interact_hold_active
	if menu_open:
		velocity = Vector2.ZERO
	elif was_holding:
		# While a hold is active, the player stays physically still. Item aim
		# input advances the logical target one cell at a time; it never fights
		# CharacterBody2D collision or changes the simulation position.
		if not released:
			_advance_item_aim(input_manager.get_movement_vector(), delta)
		velocity = Vector2.ZERO
	elif pressed:
		_begin_interact_hold()
		velocity = Vector2.ZERO
	else:
		_apply_movement_input(input_manager.get_movement_vector())
		move_and_slide()
	# Playtest fix: hold-to-preview (item 4) - commit on release, not press,
	# so the target indicator has a chance to show the affected tile(s)
	# before anything actually happens. The step is a pure function (see its
	# own docstring) so this call site stays a thin driver.
	var step := _interact_hold_step(
		_interact_hold_active,
		pressed,
		released,
		menu_open)
	var commit_target := _aim_target if _holding_item_aim else _interact_hold_target
	var commit_npc_id := "" if _holding_item_aim else _interact_hold_target_npc_id()
	_interact_hold_active = bool(step.get("holding", false))
	if str(step.get("event", "none")) == "commit":
		_use_tool(commit_target, commit_npc_id)
		cancel_interact_hold()
	elif str(step.get("event", "none")) == "cancel":
		cancel_interact_hold()
	_handle_equip_shortcuts()
	_invalidate_interaction_info_cache()


## Rotates `screen_input` (in the shape InputManager.get_movement_vector()
## returns) into grid space via IsoProjection.input_to_world_dir() - ADR-032's
## Stardew rotation, done once, at the point of entry (plan section 2.1) - and
## updates `velocity` and `_facing` from the result. Deliberately does nothing
## else: no move_and_slide(), no tree access, so this is the one piece of
## _physics_process that is directly unit-testable off-tree.
## tests/suites/test_iso_actors.gd calls this with controlled screen-space
## vectors to prove the rotation is actually wired ahead of velocity, not
## just present elsewhere in the file.
func _apply_movement_input(screen_input: Vector2) -> void:
	var world_dir := IsoProjection.input_to_world_dir(screen_input)
	if screen_input.length_squared() > 0.01:
		_facing = _vector_to_facing(world_dir)
	velocity = world_dir * _speed


## Pure hold-state transition for the Interact action (playtest fix, item
## 4) - no tree/Input access, so this is directly unit-testable off-tree,
## the same pattern _apply_movement_input above already established.
## Transition table: press while idle -> start holding (no action yet);
## release while holding -> commit (the caller runs _use_tool()); a menu
## open (or already open) while holding -> cancel with no action; every
## other combination is a no-op. A same-tick press+release commits exactly
## once (the press is folded into `holding` before the release check runs).
## Returns {"holding": bool, "event": "start"|"commit"|"cancel"|"none"}.
func _interact_hold_step(holding: bool, pressed: bool, released: bool, menu_open: bool) -> Dictionary:
	var event := "none"
	if menu_open:
		if holding:
			holding = false
			event = "cancel"
		return {"holding": holding, "event": event}
	if pressed and not holding:
		holding = true
		event = "start"
	if released and holding:
		holding = false
		event = "commit"
	return {"holding": holding, "event": event}


## Captures a stable target at the start of a hold. Bare-hand interaction
## holds lock the assisted character/object; equipped items start at the exact
## faced tile and switch to grid aim instead.
func _begin_interact_hold() -> void:
	_holding_item_aim = _has_equipped_item()
	_aim_direction = Vector2i.ZERO
	_aim_repeat_elapsed = 0.0
	_aim_repeat_started = false
	if _holding_item_aim:
		_aim_target = get_faced_tile()
		_interact_hold_target_assisted = false
	else:
		var resolved := _resolve_normal_target()
		_interact_hold_target = resolved.get("target", get_faced_tile()) as Vector2i
		_interact_hold_target_assisted = bool(resolved.get("assisted", false))
		_interact_hold_target_kind = str(resolved.get("kind", ""))


func _interact_hold_target_npc_id() -> String:
	if _interact_hold_target_kind != "character":
		return ""
	return _npc_id_at(_interact_hold_target)


func _has_equipped_item() -> bool:
	var player_state = get_node_or_null("/root/PlayerState")
	if player_state == null:
		return false
	return not str(player_state.get("equipped_tool_id")).is_empty()


## Converts the screen-relative movement vector through the same projection
## seam as ordinary movement, then applies one logical-cell step immediately
## and controlled repeats thereafter. The target cursor, not the player body,
## is the thing that snaps to the grid.
func _advance_item_aim(screen_input: Vector2, delta: float) -> void:
	var direction := IsoProjection.input_to_aim_grid_dir(screen_input)
	if direction == Vector2i.ZERO:
		_aim_direction = Vector2i.ZERO
		_aim_repeat_elapsed = 0.0
		_aim_repeat_started = false
		return
	if direction != _aim_direction:
		_aim_direction = direction
		_aim_repeat_elapsed = 0.0
		_aim_repeat_started = false
		_aim_target = TARGET_RESOLVER.aim_step(_aim_target, direction)
		_facing = direction
		return
	_aim_repeat_elapsed += delta
	var threshold := _aim_repeat_interval if _aim_repeat_started else _aim_repeat_delay
	if _aim_repeat_elapsed < threshold:
		return
	_aim_repeat_elapsed -= threshold
	_aim_repeat_started = true
	_aim_target = TARGET_RESOLVER.aim_step(_aim_target, direction)
	_facing = direction


func _use_tool(target: Vector2i, preferred_npc_id: String = "") -> void:
	var ui = get_node_or_null("/root/UIManager")
	if ui != null and bool(ui.get("menu_open")):
		return
	if _farm_grid == null or _tool_manager == null:
		return
	# Normal assist gives characters priority over objects. Re-check the live
	# tile at commit so a walking NPC cannot be talked to after it has moved
	# away from the locked preview target.
	if not preferred_npc_id.is_empty() and _npc_id_at(target) == preferred_npc_id:
		npc_interacted.emit(preferred_npc_id)
		return
	var game_data = get_node_or_null("/root/GameData")
	var feature := ""
	if game_data != null:
		feature = game_data.get_feature_at(target.x, target.y, _zone_id)
	# A player-built extra well (ADR-023) refills exactly like a manor well -
	# is_well_at checks only completed well_extra buildings at this exact tile.
	var bm = get_node_or_null("/root/BuildingManager")
	if feature == "well" or (bm != null and bm.is_well_at(target, _zone_id)):
		_tool_manager.refill_watering_can()
		return
	# Crafting stations (Sprint 13) + coop (Sprint 14): a completed
	# drying_shed/hearth tile opens the crafting panel and a coop tile opens
	# the animal panel; proximity is enforced here (the faced tile), while the
	# managers themselves only check existence-anywhere.
	var station_id: String = bm.get_building_id_at(target, _zone_id) if bm != null else ""
	if station_id == "drying_shed" or station_id == "hearth" or station_id == "coop":
		station_interacted.emit(station_id, target)
		return
	# ADR-040: the demesne no longer swallows every interaction into the
	# tithe panel. A hoe/can swing is a spatial chore; bare hands clear
	# stored sheaves or deliver a carried load; the panel is the fallback.
	if feature == "stewards_demesne":
		if _equipped_is_farm_tool():
			_tool_manager.use_tool(target)
			return
		var tm := get_node_or_null("/root/TitheManager")
		if tm != null and tm.has_method("can_demesne_chore_at"):
			if bool(tm.can_demesne_chore_at("carry_produce", target)):
				tm.complete_demesne_interaction("carry_produce", target)
				return
			if bool(tm.can_demesne_chore_at("harvest_demesne", target)):
				tm.complete_demesne_interaction("harvest_demesne", target)
				return
		interacted_with.emit(feature, target)
		return
	if not feature.is_empty():
		interacted_with.emit(feature, target)
		return
	if _npc_lookup.is_valid():
		var npc_id := str(_npc_lookup.call(target))
		if not npc_id.is_empty():
			npc_interacted.emit(npc_id)
			return
	_tool_manager.use_tool(target)


## ADR-040: with a hoe or watering can equipped, interacting on the demesne
## is a chore action; with bare hands it is harvest/delivery (or the tithe
## panel when nothing is available). The tool-category check lives here in
## one place so _use_tool and get_interaction_info cannot drift.
func _equipped_is_farm_tool() -> bool:
	var player_state = get_node_or_null("/root/PlayerState")
	var game_data = get_node_or_null("/root/GameData")
	if player_state == null or game_data == null:
		return false
	var tool_id := str(player_state.get("equipped_tool_id"))
	if tool_id.is_empty():
		return false
	var item: Dictionary = game_data.get_item(tool_id)
	var category := str(item.get("tool_category", ""))
	return category == "hoe" or category == "watering_can"


func _handle_equip_shortcuts() -> void:
	var ui = get_node_or_null("/root/UIManager")
	if ui != null and bool(ui.get("menu_open")):
		return
	# get_node_or_null rather than the bare `InputManager`/`PlayerState`
	# singleton identifiers - same compile-time reason as _physics_process
	# above.
	var input_manager = get_node_or_null("/root/InputManager")
	var player_state = get_node_or_null("/root/PlayerState")
	if input_manager == null or player_state == null:
		return
	if input_manager.is_action_just_pressed("equip_hoe"):
		player_state.set_equipped_tool("hoe_wood")
	elif input_manager.is_action_just_pressed("equip_can"):
		player_state.set_equipped_tool("can_wood")
	elif input_manager.is_action_just_pressed("equip_turnip_seed"):
		player_state.set_equipped_tool("turnip_seed")
	elif input_manager.is_action_just_pressed("equip_none"):
		# Bare hands (VSA-3): required for harvest/forage, which only run
		# when equipped_tool_id is empty (see ToolManager.use_tool). Feature/
		# NPC interaction already ignores the equipped tool entirely.
		player_state.set_equipped_tool("")
	elif input_manager.is_action_just_pressed("equip_spear"):
		player_state.set_equipped_weapon("spear")
	elif input_manager.is_action_just_pressed("equip_bow"):
		player_state.set_equipped_weapon("bow")


## Buckets an already-rotated GRID-SPACE vector into one of 8 45-degree
## sectors and returns the matching king-move neighbour (ADR-032, plan
## section 2.3). `v` must already be grid-space (i.e. the output of
## IsoProjection.input_to_world_dir), never raw screen-space input - the
## whole point of 8-way facing is that it operates downstream of the
## rotation.
##
## Tie-break at exact 22.5-degree sector boundaries: `floor(raw_sector +
## 0.5)` is an explicit round-half-up, so a boundary angle always resolves to
## the same (higher-numbered / clockwise) sector on every call. This is
## spelled out in code rather than left to a library rounding convention
## because the boundary is reachable on a gamepad stick, not just an
## unreachable keyboard corner case.
func _vector_to_facing(v: Vector2) -> Vector2i:
	if v.length_squared() < FACING_DEADZONE_SQ:
		return _facing
	var angle := v.angle()
	if angle < 0.0:
		angle += TAU
	var raw_sector := angle / FACING_SECTOR_ANGLE
	var sector := int(floor(raw_sector + 0.5)) % 8
	return FACING_NEIGHBOURS[sector]
