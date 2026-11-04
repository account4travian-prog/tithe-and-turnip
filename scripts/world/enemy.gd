class_name Enemy
extends CharacterBody2D

## Bandit/thief enemy: seek/attack/flee FSM driven by enemies.json stats.
## Built entirely in code (no scene assets); the body and health bar are
## drawn by an EnemyVisual proxy (scripts/world/enemy_visual.gd), not by
## this node (ADR-032, plan section 3 - a CharacterBody2D's own _draw()
## renders at its logical, un-projected position).
##
## Enemies are spawned dynamically by RaidManager
## (get_tree().current_scene.add_child(enemy) in scripts/autoloads/
## raid_manager.gd - an autoload WS-C does not own), not through main.gd like
## the player and NPCs. So unlike PlayerVisual/NpcVisual, which main.gd
## constructs and tracks, this node wires its OWN proxy in _ready(): it looks
## up the shared WorldVisuals container and adds an EnemyVisual under it.
##
## _wire_visual_proxy() is intentionally the first thing _ready() does, ahead
## of the `_game_data == null` early return below - the proxy has no
## dependency on GameData, and putting it first means an enemy still gets a
## visual even if GameData somehow isn't ready yet.
##
## API gap found here, documented per the conversion plan's section 5.3
## escalation protocol (see this workstream's DEVELOPMENT_STATE.md entry for
## the full note): WorldVisuals was expected to already be registered in the
## "world_visuals" group (per this workstream's task brief), but
## scripts/world/world_visuals.gd - frozen, not owned by this workstream -
## does not actually call add_to_group() anywhere, and neither does
## scripts/main.gd (also frozen). _find_world_visuals() below therefore tries
## the group first (in case a future Phase 0 amendment adds it, at zero cost
## if so) and falls back to a one-time recursive scan from the tree root,
## rather than silently failing to find a container it needs.

signal enemy_died(enemy: Enemy)
signal enemy_fled(enemy: Enemy)

enum State { IDLE, SEEK, ATTACK, FLEE }

@export var enemy_id := ""
@export var villager_id := ""

var health := 0
var max_health := 0

var _damage := 0
var _speed := 80.0
var _reach := 32.0
var _cooldown := 1.0
var _behavior := "melee"
var _attack_cooldown_remaining := 0.0
var _state: State = State.SEEK
var _target: Node2D
var _combat_manager: Node
var _game_data: Node
var _is_thief := false
var _flee_threshold := 0.2
var _flee_exit_timer := 0.0
var _visual: EnemyVisual


func _ready() -> void:
	_wire_visual_proxy()
	_combat_manager = get_node_or_null("/root/CombatManager")
	_game_data = get_node_or_null("/root/GameData")
	if _game_data == null:
		return
	var data: Dictionary = _game_data.get_enemy(enemy_id)
	if data.is_empty():
		return
	_behavior = str(data.get("behavior", "melee"))
	_damage = int(data.get("damage", 5))
	_speed = float(data.get("speed", 80))
	_reach = float(data.get("reach", 32))
	_cooldown = float(data.get("cooldown", 1.0))
	max_health = int(data.get("health", 20))
	health = max_health
	_is_thief = bool(data.get("is_thief", false))
	if _is_thief:
		_flee_threshold = 0.5
	add_to_group("enemy")
	if villager_id != "" or _is_thief:
		add_to_group("villager")
		set_meta("villager_id", villager_id if villager_id != "" else enemy_id)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 20)
	shape.shape = rect
	add_child(shape)
	collision_layer = 1 << (PhysicsLayers.NPC - 1)
	collision_mask = 0
	_state = State.SEEK


func _physics_process(delta: float) -> void:
	# Perf pass (2026-08-10): the group lookup only needs to run once - there
	# is exactly one player node for the whole game session, it never gets
	# freed during normal play, and re-resolving it via get_first_node_in_group
	# every physics tick for every live enemy was pure repeated work for an
	# answer that never changes. is_instance_valid guards the (currently
	# theoretical) case of the player somehow going away mid-session.
	if not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group("player") as Node2D
	if _target == null:
		return
	if _state != State.FLEE:
		if health <= max_health * _flee_threshold:
			_enter_flee()
		elif global_position.distance_to(_target.global_position) <= _reach:
			_state = State.ATTACK
		else:
			_state = State.SEEK
	match _state:
		State.SEEK:
			velocity = (_target.global_position - global_position).normalized() * _speed
			move_and_slide()
		State.ATTACK:
			velocity = Vector2.ZERO
			if _attack_cooldown_remaining <= 0.0:
				_perform_attack()
				_attack_cooldown_remaining = _cooldown
		State.FLEE:
			_flee_exit_timer -= delta
			if _flee_exit_timer <= 0.0:
				_flee_away()
			else:
				velocity = Vector2.ZERO
				move_and_slide()
		State.IDLE:
			velocity = Vector2.ZERO
			move_and_slide()
	_attack_cooldown_remaining -= delta


func take_damage(amount: int, knockback: Vector2 = Vector2.ZERO) -> void:
	health -= amount
	velocity += knockback
	if health <= 0:
		_die()


func _perform_attack() -> void:
	if _behavior == "ranged":
		_spawn_ranged_attack()
	else:
		_spawn_melee_attack()


func _spawn_melee_attack() -> void:
	var dir := (_target.global_position - global_position).normalized()
	var hitbox := Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = PhysicsLayers.PLAYER
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(_reach, 16)
	shape.shape = rect
	hitbox.add_child(shape)
	hitbox.global_position = global_position + dir * (_reach / 2.0 + 8.0)
	hitbox.rotation = dir.angle()
	get_parent().add_child(hitbox)
	hitbox.body_entered.connect(_on_attack_hitbox_entered.bind(hitbox))
	get_tree().create_timer(0.15).timeout.connect(hitbox.queue_free)


func _on_attack_hitbox_entered(body: Node2D, hitbox: Area2D) -> void:
	if body.is_in_group("player") and _combat_manager != null:
		_combat_manager.damage_player(_damage, self)
		hitbox.queue_free()


func _spawn_ranged_attack() -> void:
	var dir := (_target.global_position - global_position).normalized()
	var proj := EnemyProjectile.new()
	proj.collision_layer = PhysicsLayers.PROJECTILE
	proj.collision_mask = PhysicsLayers.PLAYER
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	proj.add_child(shape)
	proj.direction = dir
	proj.damage = _damage
	proj.combat_manager = _combat_manager
	proj.global_position = global_position + dir * 12.0
	get_parent().add_child(proj)


func _enter_flee() -> void:
	_state = State.FLEE
	_flee_exit_timer = 3.0


func _flee_away() -> void:
	if _combat_manager != null:
		_combat_manager.emit_signal("enemy_fled", self)
	enemy_fled.emit(self)
	queue_free()


func _die() -> void:
	if _combat_manager != null:
		_combat_manager.emit_signal("enemy_defeated", self)
	enemy_died.emit(self)
	queue_free()


## Creates this enemy's EnemyVisual and parents it under the shared
## WorldVisuals container, if one can be found (see the class docstring for
## why "if" is doing real work here). No-ops harmlessly if not - an enemy
## with no proxy is a visible bug (invisible enemy), not a crash, matching
## ActorVisual's own fail-soft design (it just queue_free()s itself if its
## owner ever disappears).
func _wire_visual_proxy() -> void:
	var container := _find_world_visuals()
	if container == null:
		return
	_visual = EnemyVisual.new()
	container.add_child(_visual)
	_visual.track(self)


## Group lookup first (the documented, intended path - see class docstring),
## then a recursive fallback from the tree root. The fallback exists solely
## because the group registration this workstream was told to expect is not
## actually present in the frozen world_visuals.gd/main.gd this workstream
## does not own.
func _find_world_visuals() -> Node:
	var tree := get_tree()
	if tree == null:
		return null
	var by_group := tree.get_first_node_in_group("world_visuals")
	if by_group != null:
		return by_group
	return _find_world_visuals_recursive(tree.root)


func _find_world_visuals_recursive(node: Node) -> Node:
	if node is WorldVisuals:
		return node
	for child in node.get_children():
		var found := _find_world_visuals_recursive(child)
		if found != null:
			return found
	return null


class EnemyProjectile extends CharacterBody2D:
	var speed := 300.0
	var direction := Vector2.RIGHT
	var damage := 0
	var lifetime := 3.0
	var combat_manager: Node
	var _time_alive := 0.0

	func _physics_process(delta: float) -> void:
		_time_alive += delta
		if _time_alive > lifetime:
			queue_free()
			return
		velocity = direction * speed
		move_and_slide()
		if get_slide_collision_count() > 0:
			var body := get_slide_collision(0).get_collider() as Node2D
			if body != null and body.is_in_group("player") and combat_manager != null:
				combat_manager.damage_player(damage, self)
			queue_free()
