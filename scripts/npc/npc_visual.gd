class_name NpcVisual
extends ActorVisual

## Draws an NPC's body under the isometric projection (ADR-032, amended ADR-043, WS-C - see
## design/IsometricConversion.md section 3, rule 1). NPC.gd is a
## CharacterBody2D whose global_position is logical simulation space; it no
## longer draws itself, since a _draw() left there would render at the
## un-projected position. main.gd constructs and tracks one of these per
## spawned villager (scripts/main.gd's `_spawn_npcs()`).
##
## ADR-041 (Sprint 16 WS-C): when the manifest carries this NPC's assigned
## NPC1 archetype entry, this proxy renders an AnimatedSprite2D child facing
## the direction of the NPC's own movement. NPC.gd has no Player-style stored
## facing (it isn't player-controlled), so facing here is derived every frame
## from the NPC's own CharacterBody2D.velocity (a built-in, already-public
## property - npc.gd needed no change for this) via
## ActorVisual.facing_from_velocity(), an independent reimplementation of
## player.gd's frozen _vector_to_facing sector convention (see that
## function's docstring for why it is not a call into the frozen original).
## The primitive body _draw() below stays only as the no-asset fallback, per
## ADR-041's "primitives remain where no asset exists" rule - once the
## textured child exists, _draw() renders nothing.
##
## Archetype assignment: NPC1 ships three archetypes (Artist, Astrologer,
## Citizen; design/sprints/sprint_16_art_integration.md section 1). No
## per-villager art direction has been made yet, so archetype_sprite_id()
## assigns one deterministically from the villager's own npc_id (a stable
## string hash, not a new villagers.json field) - "villager visual variety"
## per the sprint's own framing for this pack, editable to a curated
## per-villager choice later without changing this proxy's contract.
##
## data/sprites.json carries no npc1_*_walk entries yet (their exact frame
## geometry has not been verified against the real NPC1 source files - this
## checkout has no SourceArtAssets/ tree to verify against, and this
## project's own history records DeepSeek guessing wrong about a specific
## file's shape before, per the sprint guide's reconciliation-is-mandatory
## note). SpriteManifest.get_entry() fails soft to {} for an unmapped id
## exactly like an id with a not-yet-resolvable texture path, so this proxy
## is correct today (primitives) and correct once both the entries and the
## staged textures land, with no further change here.

const NPC1_SPRITE_IDS: Array[String] = [
	"npc1_artist_walk", "npc1_astrologer_walk", "npc1_citizen_walk",
]

const OUTLINE_COLOR := Color(0.1, 0.1, 0.1)
const OUTLINE_WIDTH := 2.0
const BODY_HALF_SIZE := 14.0

var _npc: NPC
var _anim: AnimatedSprite2D
var _sprite_entry: Dictionary = {}
var _facing: Vector2i = Vector2i.DOWN
## Sentinel outside FACING_NEIGHBOURS' range (perf pass, 2026-08-10) so the
## first real _process call always applies a facing, then only re-applies
## on an actual change - SpriteManifest.set_facing() does string formatting
## and a PackedStringArray rebuild internally, wasted work when the NPC's
## facing hasn't moved since the last frame (the common case).
var _last_set_facing := Vector2i(99, 99)


## Overrides ActorVisual.track() to additionally cache the owner as a typed
## NPC - the base class only keeps a plain Node2D reference, and this proxy
## needs get_color(), which is NPC-specific. Also builds the textured child,
## if any, from this NPC's assigned archetype entry.
func track(owner: Node2D) -> void:
	super.track(owner)
	_npc = owner as NPC
	if _npc != null:
		_build_sprite_child(SpriteManifest.get_entry(archetype_sprite_id(_npc.npc_id)))


## Builds the AnimatedSprite2D child from an already-resolved manifest entry.
## Split out from track() so tests can drive it directly with a hand-built
## entry without depending on the GameData autoload being reachable - this
## project's headless test harness does not resolve /root autoload lookups
## at all (see test_iso_actors.gd's docstring), so this is the only way to
## exercise the fail-soft build path off-tree, matching the pattern
## SpriteManifest's own functions are already tested with in
## tests/suites/test_art_foundation.gd.
func _build_sprite_child(entry: Dictionary) -> void:
	_sprite_entry = entry
	if _sprite_entry.is_empty():
		return
	_anim = AnimatedSprite2D.new()
	add_child(_anim)
	if SpriteManifest.apply_animated(_anim, _sprite_entry):
		_anim.play()
	else:
		# Entry present but texture/frames unavailable (e.g. assets not yet
		# staged) - fall back to primitives rather than rendering nothing.
		_anim.queue_free()
		_anim = null


func _process(delta: float) -> void:
	# Base class does the position follow (and frees this node if the NPC is
	# ever gone - CLAUDE.md trap 4). Only redraw/reface while that still holds.
	super._process(delta)
	if not is_instance_valid(_npc):
		return
	_facing = ActorVisual.facing_from_velocity(_npc.velocity, _facing)
	if _anim != null:
		if _facing != _last_set_facing:
			SpriteManifest.set_facing(_anim, _sprite_entry, _facing)
			_last_set_facing = _facing
	else:
		queue_redraw()


func _draw() -> void:
	if _anim != null or not is_instance_valid(_npc):
		return
	var rect := Rect2(-BODY_HALF_SIZE, -BODY_HALF_SIZE, BODY_HALF_SIZE * 2.0, BODY_HALF_SIZE * 2.0)
	draw_rect(rect, _npc.get_color())
	draw_rect(rect, OUTLINE_COLOR, false, OUTLINE_WIDTH)


## Deterministic NPC1 archetype pick from a villager id - the same id always
## maps to the same archetype, spread across the three NPC1 archetypes via a
## stable string hash (String.hash(), core Godot API unchanged since 3.x;
## posmod() keeps the result non-negative regardless of the hash's sign).
## Static and pure so it is testable with no scene tree/autoloads, and reused
## by EnemyVisual.resolve_sprite_id() for the thief-in-disguise case - a
## thief_villager enemy should look like the villager it is, not like a
## Bandits1 archetype.
static func archetype_sprite_id(npc_id: String) -> String:
	if npc_id.is_empty():
		return NPC1_SPRITE_IDS[0]
	return NPC1_SPRITE_IDS[posmod(npc_id.hash(), NPC1_SPRITE_IDS.size())]
