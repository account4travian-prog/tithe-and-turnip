extends Node

## CombatManager autoload - real-time melee/ranged combat orchestration.
## No class_name (autoload rule). Polls attack input via InputManager,
## spawns hitboxes/projectiles in code (no scene assets), applies damage.

signal player_attack_started(weapon_id: String)
signal player_hit_enemy(enemy: Node, damage: int, knockback: Vector2)
signal player_damaged(amount: int, attacker: Node)
signal player_knocked_out(cause: String)
signal enemy_defeated(enemy: Node)
signal enemy_fled(enemy: Node)

const HITBOX_LIFETIME := 0.15
const PROJECTILE_LIFETIME := 3.0
const DEFAULT_PROJECTILE_SPEED := 350.0
const MELEE_HITBOX_WIDTH := 18
const KNOCKBACK_STRENGTH := 120.0

var _player_state: Node
var _game_data: Node
var _input_manager: Node
var _test_input_callable: Callable = Callable()

var _last_facing: Vector2 = Vector2.RIGHT
var _cooldown_remaining := 0.0


func _ready() -> void:
	_player_state = _player_state if _player_state != null else get_node_or_null("/root/PlayerState")
	_game_data = _game_data if _game_data != null else get_node_or_null("/root/GameData")
	_input_manager = _input_manager if _input_manager != null else get_node_or_null("/root/InputManager")


func _physics_process(delta: float) -> void:
	if _cooldown_remaining > 0.0:
		_cooldown_remaining -= delta
	if _input_manager != null:
		var movement: Vector2 = _input_manager.get_movement_vector()
		if movement != Vector2.ZERO:
			_last_facing = movement.normalized()
	var want_attack := false
	if _test_input_callable.is_valid():
		want_attack = bool(_test_input_callable.call())
	elif _input_manager != null:
		want_attack = _input_manager.is_action_just_pressed("attack") \
			or _input_manager.is_action_just_pressed("attack_mouse")
	if want_attack:
		_try_attack()


func damage_player(amount: int, attacker: Node) -> void:
	_player_state.take_damage(amount)
	player_damaged.emit(amount, attacker)
	if int(_player_state.get("health")) <= 0:
		_player_state.apply_pass_out_penalty("combat")
		player_knocked_out.emit("combat")


func configure_for_test(p_player_state: Node, p_game_data: Node, p_input_callable: Callable = Callable()) -> void:
	_player_state = p_player_state
	_game_data = p_game_data
	_test_input_callable = p_input_callable


func _try_attack() -> void:
	if _cooldown_remaining > 0.0:
		return
	var weapon_id := str(_player_state.get("equipped_weapon_id"))
	var weapon: Dictionary
	if weapon_id.is_empty() or weapon_id == "fists":
		weapon = {
			"id": "fists", "name": "Fists", "type": "weapon",
			"damage": 2, "reach": 24, "cooldown": 0.5, "energy_cost": 1,
		}
	else:
		weapon = _game_data.get_item(weapon_id)
		if weapon.is_empty():
			return
	if not _player_state.consume_energy(float(weapon.get("energy_cost", 0))):
		return
	_cooldown_remaining = float(weapon.get("cooldown", 0.5))
	player_attack_started.emit(str(weapon.get("id", weapon_id)))
	if str(weapon.get("projectile_id", "")) != "":
		_spawn_projectile(weapon)
	else:
		_spawn_melee_hitbox(weapon)


func _spawn_melee_hitbox(weapon: Dictionary) -> void:
	var player := _player_node()
	if player == null:
		return
	var reach := float(weapon.get("reach", 24))
	var hitbox := Area2D.new()
	hitbox.collision_layer = 0
	hitbox.collision_mask = PhysicsLayers.NPC
	var shape := CollisionShape2D.new()
	shape.shape = RectangleShape2D.new()
	shape.shape.size = Vector2(reach, MELEE_HITBOX_WIDTH)
	hitbox.add_child(shape)
	hitbox.global_position = player.global_position + _last_facing * (reach / 2.0 + 16.0)
	hitbox.rotation = _last_facing.angle()
	player.get_parent().add_child(hitbox)
	var player_pos := player.global_position
	hitbox.body_entered.connect(_on_melee_hitbox_entered.bind(weapon, player_pos))
	get_tree().create_timer(HITBOX_LIFETIME).timeout.connect(hitbox.queue_free)


func _on_melee_hitbox_entered(body: Node2D, weapon: Dictionary, player_pos: Vector2) -> void:
	if not body.has_method("take_damage"):
		return
	var skill := get_node_or_null("/root/SkillManager")
	var mult := float(skill.get_effect("combat", "damage_mult", 1.0)) if skill != null else 1.0
	var damage := int(float(weapon.get("damage", 0)) * mult)
	var knockback := (body.global_position - player_pos).normalized() * KNOCKBACK_STRENGTH
	body.take_damage(damage, knockback)
	player_hit_enemy.emit(body, damage, knockback)
	if skill != null:
		skill.add_xp_for("combat", "hit_enemy")
	if body.is_in_group("villager"):
		var rep := get_node_or_null("/root/ReputationManager")
		if rep != null:
			rep.apply_action("attack_villager", str(body.get_meta("villager_id", "")))


func _spawn_projectile(weapon: Dictionary) -> void:
	if int(_player_state.get("arrow_count")) <= 0:
		return
	_player_state.arrow_count = int(_player_state.get("arrow_count")) - 1
	var player := _player_node()
	if player == null:
		return
	var proj := Projectile.new()
	proj.collision_layer = PhysicsLayers.PROJECTILE
	proj.collision_mask = PhysicsLayers.NPC
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	shape.shape = circle
	proj.add_child(shape)
	proj.speed = float(weapon.get("projectile_speed", DEFAULT_PROJECTILE_SPEED))
	proj.direction = _last_facing
	proj.damage = int(weapon.get("damage", 0))
	proj.lifetime = PROJECTILE_LIFETIME
	proj.combat_manager = self
	proj.global_position = player.global_position + _last_facing * 16.0
	player.get_parent().add_child(proj)


func _player_node() -> Node2D:
	if get_tree() == null:
		return null
	return get_tree().get_first_node_in_group("player") as Node2D


class Projectile extends CharacterBody2D:
	var speed := 350.0
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
			if body != null and body.has_method("take_damage"):
				var skill := get_node_or_null("/root/SkillManager")
				var mult := float(skill.get_effect("combat", "damage_mult", 1.0)) if skill != null else 1.0
				var final_damage := int(float(damage) * mult)
				body.take_damage(final_damage)
				if skill != null:
					skill.add_xp_for("combat", "hit_enemy")
				if combat_manager != null:
					combat_manager.player_hit_enemy.emit(body, final_damage, Vector2.ZERO)
			queue_free()
