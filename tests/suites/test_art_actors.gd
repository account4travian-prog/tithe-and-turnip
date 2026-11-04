extends RefCounted
## Coverage for ADR-041 Sprint 16 WS-C (actors): the facing-from-velocity
## math ActorVisual now shares with NpcVisual/EnemyVisual, NPC1
## archetype/Bandits1 sprite-id resolution, and the textured-child fail-soft
## build path both actor proxies gained. Every function under test takes
## explicit values or a hand-built entry Dictionary rather than reading a
## live scene tree or GameData, matching test_art_foundation.gd's and
## test_iso_actors.gd's off-tree pattern - this project's headless test
## harness does not resolve /root autoload lookups at all (see
## test_iso_actors.gd's docstring), so no suite in this project depends on a
## live autoload singleton, and this one is no exception.

const NPC_SCRIPT := preload("res://scripts/npc/npc.gd")
const ENEMY_SCRIPT := preload("res://scripts/world/enemy.gd")

## The eight grid-space king-move neighbours, in the same order
## ActorVisual.FACING_NEIGHBOURS (and player.gd's own FACING_NEIGHBOURS) use.
## Deliberately duplicated rather than reading the constant under test - a
## test's expectation should not be sourced from the exact thing it checks
## (test_iso_actors.gd's own stated rule).
const EXPECTED_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]

## A representative hand-built animated entry, shaped like a real
## data/sprites.json entry but pointing at a texture path that does not
## resolve in this checkout - exactly the "your data/sprites.json entries
## will point at paths that don't resolve until [asset staging] lands
## separately" situation this workstream's brief calls out. Every
## fail-soft-build test below uses this to prove the wiring is correct with
## or without staged assets, per that same brief.
const UNRESOLVED_ANIMATED_ENTRY := {
	"id": "test_actor_walk",
	"kind": "animated",
	"texture": "res://assets/sprites/actors/does_not_exist/walk.png",
	"sheet_w": 384, "sheet_h": 256, "frame_w": 64, "frame_h": 64,
	"anchor_x": 32, "anchor_y": 44, "height_tiles": 0.9, "fps": 6.0,
	"directions": {"0,1": {"start": 0, "count": 6, "flip_h": false}},
}


func suite_name() -> String:
	return "art_actors"


func run(t: Object) -> void:
	_test_facing_from_velocity_eight_way(t)
	_test_facing_from_velocity_deadzone_keeps_current(t)
	_test_facing_from_velocity_tie_break_determinism(t)
	_test_npc1_archetype_deterministic_and_valid(t)
	_test_npc1_archetype_empty_id_fails_soft(t)
	_test_bandit_sprite_id_mapping(t)
	_test_bandit_sprite_id_unmapped_fails_soft_to_empty(t)
	_test_thief_villager_reuses_npc1_archetype(t)
	_test_npc_visual_sprite_child_empty_entry_stays_null(t)
	_test_npc_visual_sprite_child_fails_soft_on_missing_texture(t)
	_test_enemy_visual_sprite_child_fails_soft_on_missing_texture(t)
	_test_npc_visual_track_wires_owner_and_facing_default(t)
	_test_enemy_visual_track_wires_owner_and_facing_default(t)
	t.completed(13)


func _test_facing_from_velocity_eight_way(t: Object) -> void:
	for neighbour: Vector2i in EXPECTED_NEIGHBOURS:
		var result := ActorVisual.facing_from_velocity(Vector2(neighbour), Vector2i.DOWN)
		t.eq(result, neighbour,
			"velocity toward grid neighbour %s resolves to that neighbour" % neighbour)
	t.section_done("facing_from_velocity eight-way")


## A near-zero velocity (an idle NPC, or an Enemy momentarily at rest between
## move_and_slide() calls) must keep whatever facing it already had rather
## than snapping to an arbitrary sector - same reasoning as player.gd's own
## deadzone guard, independently re-verified here since this is a separate
## implementation.
func _test_facing_from_velocity_deadzone_keeps_current(t: Object) -> void:
	t.eq(ActorVisual.facing_from_velocity(Vector2.ZERO, Vector2i(1, 0)), Vector2i(1, 0),
		"zero velocity leaves facing unchanged")
	t.eq(ActorVisual.facing_from_velocity(Vector2(0.001, 0.0), Vector2i(-1, 0)), Vector2i(-1, 0),
		"a velocity below the deadzone threshold leaves facing unchanged")
	t.section_done("facing_from_velocity deadzone")


## Exact 22.5-degree sector boundary - the same reachable-on-a-gamepad-stick
## case test_iso_actors.gd checks for player.gd's own sector math, re-checked
## here since this is an independent implementation.
func _test_facing_from_velocity_tie_break_determinism(t: Object) -> void:
	var boundary_dir := Vector2(cos(PI / 8.0), sin(PI / 8.0))
	var first_result := ActorVisual.facing_from_velocity(boundary_dir, Vector2i.DOWN)
	var second_result := ActorVisual.facing_from_velocity(boundary_dir, Vector2i.DOWN)
	t.eq(first_result, second_result,
		"the 22.5-degree boundary resolves to the same facing on repeat calls")
	t.ok(first_result == Vector2i(1, 0) or first_result == Vector2i(1, 1),
		"boundary facing lands on one of the two adjacent sectors, not something unrelated")
	t.section_done("facing_from_velocity tie-break")


func _test_npc1_archetype_deterministic_and_valid(t: Object) -> void:
	var villager_ids := ["steward", "priest", "villager_1", "villager_2", "villager_3",
		"villager_4", "villager_5", "villager_6", "simkin"]
	var seen: Dictionary = {}
	for npc_id: String in villager_ids:
		var first_pick := NpcVisual.archetype_sprite_id(npc_id)
		var second_pick := NpcVisual.archetype_sprite_id(npc_id)
		t.eq(first_pick, second_pick,
			"archetype_sprite_id(%s) is deterministic across calls" % npc_id)
		t.ok(NpcVisual.NPC1_SPRITE_IDS.has(first_pick),
			"archetype_sprite_id(%s) returns one of the three known NPC1 archetypes" % npc_id)
		seen[first_pick] = true
	t.ok(seen.size() >= 2,
		"the real villager roster spreads across more than one NPC1 archetype, not one for all")
	t.section_done("npc1 archetype deterministic/valid")


func _test_npc1_archetype_empty_id_fails_soft(t: Object) -> void:
	t.eq(NpcVisual.archetype_sprite_id(""), NpcVisual.NPC1_SPRITE_IDS[0],
		"an empty npc_id resolves to a defined archetype rather than indexing out of range")
	t.section_done("npc1 archetype empty id")


func _test_bandit_sprite_id_mapping(t: Object) -> void:
	t.eq(EnemyVisual.resolve_sprite_id("bandit_melee", ""), "bandit_robber_walk",
		"bandit_melee maps to the Robber archetype")
	t.eq(EnemyVisual.resolve_sprite_id("bandit_archer", ""), "bandit_assassin_walk",
		"bandit_archer maps to the Assassin archetype")
	t.eq(EnemyVisual.resolve_sprite_id("raid_leader", ""), "bandit_thug_walk",
		"raid_leader maps to the Thug archetype")
	t.section_done("bandit sprite id mapping")


func _test_bandit_sprite_id_unmapped_fails_soft_to_empty(t: Object) -> void:
	t.eq(EnemyVisual.resolve_sprite_id("some_future_enemy_id", ""), "",
		"an enemy_id with no mapping resolves to an empty sprite id, not a guess")
	t.section_done("bandit sprite id unmapped")


## A thief_villager enemy carries a real villager_id (the villager it is
## disguised as, per enemy.gd/data/enemies.json's is_thief shape) - it must
## look like that villager, not like any Bandits1 archetype, regardless of
## its own enemy_id.
func _test_thief_villager_reuses_npc1_archetype(t: Object) -> void:
	var result := EnemyVisual.resolve_sprite_id("thief_villager", "villager_3")
	t.eq(result, NpcVisual.archetype_sprite_id("villager_3"),
		"a thief_villager enemy resolves to its disguised villager's own NPC1 archetype")
	t.section_done("thief villager archetype reuse")


func _test_npc_visual_sprite_child_empty_entry_stays_null(t: Object) -> void:
	var visual := NpcVisual.new()
	visual._build_sprite_child({})
	t.eq(visual._anim, null, "an empty manifest entry leaves the textured child unbuilt")
	visual.free()
	t.section_done("npc visual empty entry")


## The exact scenario this workstream's brief calls out: an entry shaped like
## a real one but whose texture path is not staged yet. Must fail soft to a
## null anim (primitives stay visible), never error out or leave a half-built
## AnimatedSprite2D behind.
func _test_npc_visual_sprite_child_fails_soft_on_missing_texture(t: Object) -> void:
	var visual := NpcVisual.new()
	visual._build_sprite_child(UNRESOLVED_ANIMATED_ENTRY)
	t.eq(visual._anim, null,
		"a manifest entry with an unresolved texture path falls back to null (primitives stay visible)")
	visual.free()
	t.section_done("npc visual fail-soft missing texture")


func _test_enemy_visual_sprite_child_fails_soft_on_missing_texture(t: Object) -> void:
	var visual := EnemyVisual.new()
	visual._build_sprite_child(UNRESOLVED_ANIMATED_ENTRY)
	t.eq(visual._anim, null,
		"a manifest entry with an unresolved texture path falls back to null (primitives stay visible)")
	visual.free()
	t.section_done("enemy visual fail-soft missing texture")


## track() itself resolves SpriteManifest.get_entry() through the GameData
## autoload, which this headless harness never reaches - so _anim is
## guaranteed null here regardless of data/sprites.json's contents (that path
## is exercised by _test_npc_visual_sprite_child_fails_soft_on_missing_texture
## above via the explicit-entry seam instead). What this test actually
## proves: track() wires the typed owner correctly and the default facing
## starts at DOWN, matching player.gd's own _facing default, before any
## movement has occurred.
func _test_npc_visual_track_wires_owner_and_facing_default(t: Object) -> void:
	var npc: NPC = NPC_SCRIPT.new()
	npc.npc_id = "villager_1"
	var visual := NpcVisual.new()
	visual.track(npc)
	t.eq(visual._npc, npc, "track() caches the owner as a typed NPC")
	t.eq(visual._facing, Vector2i.DOWN, "facing starts at DOWN before any movement")
	visual.free()
	npc.free()
	t.section_done("npc visual track wiring")


func _test_enemy_visual_track_wires_owner_and_facing_default(t: Object) -> void:
	var enemy: Enemy = ENEMY_SCRIPT.new()
	enemy.enemy_id = "bandit_melee"
	var visual := EnemyVisual.new()
	visual.track(enemy)
	t.eq(visual._enemy, enemy, "track() caches the owner as a typed Enemy")
	t.eq(visual._facing, Vector2i.DOWN, "facing starts at DOWN before any movement")
	visual.free()
	enemy.free()
	t.section_done("enemy visual track wiring")
