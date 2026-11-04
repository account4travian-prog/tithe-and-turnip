extends RefCounted
## NPC physics presence coverage (npc-collision workstream): the collision
## body wiring (CharacterBody2D + CollisionShape2D + layer/mask), the combat
## eligibility trio CombatManager's hitbox handler requires (villager group,
## villager_id meta, take_damage), the no-death damage path, and the
## live-tile lookup main.gd's interaction closure delegates to
## (NPC.npc_id_at over current positions, not a stale spawn-tile dictionary).
##
## NPC._ready() is invoked manually on off-tree instances: the headless
## harness runs inside SceneTree._initialize(), where nodes added to root are
## not yet inside the tree and _ready would not fire (the same constraint
## test_iso_camera.gd documents). _ready's combat wiring is deliberately
## first so it exists without GameData/TimeManager, which is exactly the
## condition this harness provides.

const NPC_SCRIPT := preload("res://scripts/npc/npc.gd")
const PHYSICS_LAYERS := preload("res://scripts/globals/physics_layers.gd")

## Mirror of npc.gd's BODY_SIZE / the drawn NpcVisual body (BODY_HALF_SIZE
## 14.0). Kept independent so the test isn't sourced from the code it checks.
const BODY_SIZE := 28.0
const CELL := 32


func suite_name() -> String:
	return "npc_physics"


func run(t: Object) -> void:
	_test_collision_body_wiring(t)
	_test_combat_eligibility(t)
	_test_take_damage_no_death_path(t)
	_test_live_tile_lookup(t)
	t.completed(4)


func _make_ready_npc(id: String) -> NPC:
	var npc: NPC = NPC_SCRIPT.new()
	npc.npc_id = id
	npc._ready()
	return npc


func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(tile.x * CELL + CELL / 2.0, tile.y * CELL + CELL / 2.0)


func _test_collision_body_wiring(t: Object) -> void:
	var npc := _make_ready_npc("steward")
	t.ok(npc is CharacterBody2D, "NPC extends CharacterBody2D")
	t.eq(npc.collision_layer, 1 << (PHYSICS_LAYERS.NPC - 1),
		"NPC collision_layer is the NPC layer")
	t.eq(npc.collision_mask, 1 << (PHYSICS_LAYERS.INTERACTABLE - 1),
		"NPC collision_mask is INTERACTABLE only (no player/NPC blocking)")
	var shape: CollisionShape2D = null
	for child: Node in npc.get_children():
		if child is CollisionShape2D:
			shape = child as CollisionShape2D
	t.ok(shape != null, "NPC has a CollisionShape2D child")
	if shape != null:
		t.ok(shape.shape is RectangleShape2D, "NPC collision shape is a rectangle")
		var rect := shape.shape as RectangleShape2D
		t.eq(rect.size, Vector2(BODY_SIZE, BODY_SIZE),
			"NPC shape matches the 28x28 drawn body")
	npc.free()
	t.section_done("collision body wiring")


func _test_combat_eligibility(t: Object) -> void:
	var npc := _make_ready_npc("priest")
	t.ok(npc.is_in_group("villager"), "NPC is in the villager group")
	t.eq(str(npc.get_meta("villager_id", "")), "priest",
		"NPC carries the villager_id meta CombatManager reads")
	t.ok(npc.has_method("take_damage"),
		"NPC exposes take_damage so CombatManager hitboxes can call it")
	npc.free()
	t.section_done("combat eligibility")


func _test_take_damage_no_death_path(t: Object) -> void:
	var npc := _make_ready_npc("villager_1")
	npc.take_damage(4, Vector2(10.0, 0.0))
	t.eq(npc.health, -4,
		"take_damage reduces health below zero (marker-only, no floor needed)")
	t.eq(npc.velocity, Vector2(10.0, 0.0),
		"knockback parameter mirrors Enemy.take_damage's signature")
	t.ok(is_instance_valid(npc),
		"villager survives the hit: no death/free/flee path")
	npc.free()
	t.section_done("take damage")


func _test_live_tile_lookup(t: Object) -> void:
	var steward := _make_ready_npc("steward")
	var priest := _make_ready_npc("priest")
	steward.global_position = _tile_center(Vector2i(25, 15))
	priest.global_position = _tile_center(Vector2i(10, 15))
	var npcs: Array[NPC] = [steward, priest]
	var spawn_tile := steward.current_tile()
	t.eq(spawn_tile, Vector2i(25, 15), "spawn tile precondition is the 25,15 tile")
	t.eq(NPC_SCRIPT.npc_id_at(npcs, spawn_tile), "steward",
		"spawn tile resolves before movement")
	steward.global_position = _tile_center(Vector2i(26, 15))
	t.eq(NPC_SCRIPT.npc_id_at(npcs, spawn_tile), "",
		"old spawn tile no longer resolves after movement")
	t.eq(NPC_SCRIPT.npc_id_at(npcs, steward.current_tile()), "steward",
		"NPC's CURRENT tile resolves after movement")
	t.eq(NPC_SCRIPT.npc_id_at(npcs, priest.current_tile()), "priest",
		"a second villager still resolves at its own live tile")
	steward.free()
	priest.free()
	t.section_done("live tile lookup")
