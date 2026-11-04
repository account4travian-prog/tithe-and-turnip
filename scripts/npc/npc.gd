class_name NPC
extends CharacterBody2D

## Slice NPC: a colored marker that follows a home/work schedule from
## villagers.json (anchor switches on the hour) and wanders near the current
## anchor. Reacts to the player's interact (the player reads its dialogue
## line via GameData). No art assets - geometric primitives only.
##
## ADR-032 (isometric projection, amended ADR-043): this node's global_position stays logical
## grid-pixel space (unchanged by the conversion - CLAUDE.md section 8's
## presentation-only invariant). It draws nothing of its own; see
## scripts/npc/npc_visual.gd for the proxy that renders the body at the
## projected screen position (plan section 3). The two home/work tile-to-
## pixel conversions and the wander-radius scale below are the last
## hardcoded 32.0s outside the projection seam itself - replaced with
## IsoProjection.LOGICAL_CELL so there is exactly one place that constant is
## spelled out.
##
## Physics presence (npc-collision workstream): this node is now a
## CharacterBody2D with a CollisionShape2D sized to the drawn body. It sits
## on PhysicsLayers.NPC and masks PhysicsLayers.INTERACTABLE only, so it
## stops at buildings/walls but never blocks the player or other villagers
## (Godot's mutual mask/layer requirement - see DEVELOPMENT_STATE.md).
## CombatManager's melee/projectile hitboxes already scan PhysicsLayers.NPC;
## the villager group, villager_id meta, and take_damage() here are the rest
## of that wiring. Villagers have no death path by design: a hit only moves
## the marker health negative and lets CombatManager apply the attack_villager
## reputation action.

## The drawn body is a 28x28 rect (npc_visual.gd BODY_HALF_SIZE = 14.0); the
## collision shape matches it so the stopping distance at walls matches what
## the player sees.
const BODY_SIZE := 28.0
## A wander leg that makes no progress for this long (e.g. its random target
## landed inside a building) is abandoned so the idle/wander loop keeps
## cycling instead of pushing a wall forever. Structural guard, not a
## gameplay tunable.
const BLOCKED_GIVE_UP_TIME := 0.5

@export var npc_id := ""
@export var wander_radius := 2.0
@export var idle_time := 2.0
@export var move_speed := 40.0

## Villager health is a combat-interface marker only: villagers cannot die,
## so it starts at 0 and take_damage() drives it negative. No floor, no
## death, no flee path - a hit's real consequence is the reputation action
## CombatManager already applies for the "villager" group.
var health := 0

var _color := Color(0.6, 0.6, 0.6)
var _start_pos := Vector2.ZERO
var _target := Vector2.ZERO
var _timer := 0.0
var _wandering := false
var _home_pos := Vector2.ZERO
var _work_pos := Vector2.ZERO
var _work_start_hour := 8
var _work_end_hour := 18
var _anchor := Vector2.ZERO
var _blocked_time := 0.0


func _ready() -> void:
	# Combat eligibility (Problem 2): CombatManager's hitbox handler requires
	# the villager group, the villager_id meta, and take_damage - all three
	# are the entire missing wiring this workstream adds. Done first so it
	# exists even if GameData/TimeManager are absent (tests, partial boot).
	add_to_group("villager")
	set_meta("villager_id", npc_id)
	_build_collision_shape()
	_start_pos = position
	_target = position
	_timer = idle_time
	var game_data = get_node_or_null("/root/GameData")
	if game_data != null:
		var villager: Dictionary = game_data.get_villager(npc_id)
		var color_str := str(villager.get("color", "#888888"))
		_color = Color(color_str)
		var schedule: Dictionary = villager.get("schedule", {})
		var home: Dictionary = schedule.get("home", villager.get("spawn", {}))
		var work: Dictionary = schedule.get("work", villager.get("spawn", {}))
		var half_cell := IsoProjection.LOGICAL_CELL / 2.0
		_home_pos = Vector2(int(home.get("x", 0)) * IsoProjection.LOGICAL_CELL + half_cell,
			int(home.get("y", 0)) * IsoProjection.LOGICAL_CELL + half_cell)
		_work_pos = Vector2(int(work.get("x", 0)) * IsoProjection.LOGICAL_CELL + half_cell,
			int(work.get("y", 0)) * IsoProjection.LOGICAL_CELL + half_cell)
		_work_start_hour = int(schedule.get("work_start_hour", 8))
		_work_end_hour = int(schedule.get("work_end_hour", 18))
	_anchor = _home_pos if _home_pos != Vector2.ZERO else position
	_start_pos = _anchor
	var tm = get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.minute_passed.connect(_on_minute_passed)
		_update_anchor(int(tm.get("hour")))


func _physics_process(delta: float) -> void:
	# Movement is velocity + move_and_slide() now that NPCs are real physics
	# bodies (mirrors Enemy's pattern). The wander/anchor decision logic is
	# unchanged; only the application of motion is. Because villagers only
	# mask INTERACTABLE, they stop at buildings/walls but pass through the
	# player and each other (Godot's mutual mask/layer rule - both bodies
	# must include each other's layer for a CharacterBody2D-vs-CharacterBody2D
	# response, so mask-exclusion is symmetric).
	if _wandering:
		var to_target := _target - position
		if to_target.length() < 4.0:
			_wandering = false
			_timer = idle_time
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * move_speed
	else:
		velocity = Vector2.ZERO
		_timer -= delta
		if _timer <= 0.0:
			_wandering = true
			_target = _start_pos + Vector2(
				randf_range(-wander_radius, wander_radius),
				randf_range(-wander_radius, wander_radius)) * IsoProjection.LOGICAL_CELL
	var was_moving := _wandering and velocity.length_squared() > 0.0
	if was_moving or velocity != Vector2.ZERO:
		var before := position
		move_and_slide()
		if was_moving:
			# A wander leg blocked by a wall (target inside a fixture) would
			# otherwise push forever; give up after BLOCKED_GIVE_UP_TIME and
			# let the next idle tick pick a fresh random target.
			if position.distance_to(before) < 0.5:
				_blocked_time += delta
				if _blocked_time >= BLOCKED_GIVE_UP_TIME:
					_wandering = false
					_timer = idle_time
					velocity = Vector2.ZERO
					_blocked_time = 0.0
			else:
				_blocked_time = 0.0
		else:
			_blocked_time = 0.0


## The body colour resolved from villagers.json at _ready(). Read by
## NpcVisual (scripts/npc/npc_visual.gd) - the proxy has no other way to see
## this private state.
func get_color() -> Color:
	return _color


## Exact signature CombatManager calls (body.take_damage(damage, knockback)),
## matching Enemy.take_damage(). Deliberately minimal: no _die(), no flee,
## no retaliation - villagers have no death concept in this game.
func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	velocity += knockback


## The grid tile this NPC currently occupies, derived from its live logical
## position (same floor-divide Player.get_current_tile() uses). This is what
## main.gd's interaction lookup compares against, so the player talks to an
## NPC where it actually stands rather than at a cached spawn tile.
func current_tile() -> Vector2i:
	return Vector2i(
		floori(global_position.x / IsoProjection.LOGICAL_CELL),
		floori(global_position.y / IsoProjection.LOGICAL_CELL))


## Live-position interaction lookup (Problem 3): main.gd's closure delegates
## here so it stays a one-liner while the logic is unit-testable. O(n) over
## ~6-8 villagers is fine - CLAUDE.md section 9.1's note explicitly excludes
## this from the O(n x m) engine-query rule, so no spatial-partitioning
## machinery is warranted.
static func npc_id_at(npcs: Array[NPC], tile: Vector2i) -> String:
	for npc: NPC in npcs:
		if npc.current_tile() == tile:
			return npc.npc_id
	return ""


## Schedules are deterministic given an hour - Sprint 12's investigation
## should read GameData.get_villager_schedule() directly rather than tracking
## movement history; this recomputes the same comparison on each minute tick.
func _on_minute_passed(hour: int, _minute: int) -> void:
	_update_anchor(hour)


func _update_anchor(hour: int) -> void:
	var festival_anchor := _festival_anchor_position()
	var marriage_anchor := _marriage_anchor_position()
	var new_anchor := festival_anchor if festival_anchor != Vector2.ZERO \
		else (marriage_anchor if marriage_anchor != Vector2.ZERO \
		else (_work_pos if (hour >= _work_start_hour and hour < _work_end_hour) else _home_pos))
	if new_anchor != _anchor and new_anchor != Vector2.ZERO:
		_anchor = new_anchor
		_start_pos = _anchor
		_wandering = true
		_target = _anchor


## ADR-031 (realized): once this NPC is the current spouse, they anchor at
## the player's cottage instead of their own work/home schedule - "moves
## into the player's cottage, gains a home-based schedule." Festivals still
## take precedence via the check above. The player_house tile comes from
## farm_map.json through GameData rather than a second hardcoded constant;
## main.gd's CHAPEL_TILE stays as its own citing-commented constant since it
## already exists and is used by the mass/festival checks.
func _marriage_anchor_position() -> Vector2:
	var marriage_manager := get_node_or_null("/root/MarriageManager")
	if marriage_manager == null or not marriage_manager.has_method("is_spouse") \
			or not marriage_manager.is_spouse(npc_id):
		return Vector2.ZERO
	var game_data := get_node_or_null("/root/GameData")
	if game_data == null or not game_data.has_method("get_feature_tile"):
		return Vector2.ZERO
	var tile: Vector2i = game_data.get_feature_tile("player_house")
	if tile.x < 0:
		return Vector2.ZERO
	var half_cell := IsoProjection.LOGICAL_CELL / 2.0
	return Vector2(tile.x * IsoProjection.LOGICAL_CELL + half_cell,
		tile.y * IsoProjection.LOGICAL_CELL + half_cell)


## E5 (ADR-036): during an active festival every villager's anchor moves to
## the festival tile instead of their normal work/home schedule.
## FestivalManager is a pending-DESKTOP autoload (ADR-036) - reached via
## get_node_or_null, not a bare reference, same as main.gd's own check.
## Vector2.ZERO as "no override" is safe here the same way it already is for
## _home_pos/_work_pos above: every real anchor gets +half_cell added, so a
## genuine festival at grid (0,0) never collides with the sentinel.
func _festival_anchor_position() -> Vector2:
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager == null:
		return Vector2.ZERO
	var anchor: Dictionary = festival_manager.get_active_festival_anchor()
	if anchor.is_empty():
		return Vector2.ZERO
	var half_cell := IsoProjection.LOGICAL_CELL / 2.0
	return Vector2(int(anchor.get("x", 0)) * IsoProjection.LOGICAL_CELL + half_cell,
		int(anchor.get("y", 0)) * IsoProjection.LOGICAL_CELL + half_cell)


func _build_collision_shape() -> void:
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(BODY_SIZE, BODY_SIZE)
	shape.shape = rect
	add_child(shape)
	# NPC layer only; mask INTERACTABLE only. Combat hitboxes (Area2D with
	# collision_mask = PhysicsLayers.NPC) detect this body regardless of its
	# own mask - Area2D monitoring is one-directional from the area's mask.
	collision_layer = 1 << (PhysicsLayers.NPC - 1)
	collision_mask = 1 << (PhysicsLayers.INTERACTABLE - 1)
