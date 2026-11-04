class_name EnemyVisual
extends ActorVisual

## Draws an enemy's body and health bar under the isometric projection
## (ADR-032, WS-C - see design/IsometricConversion.md section 3, rule 1).
## Enemy.gd is a CharacterBody2D whose global_position is logical simulation
## space; it no longer draws itself, since a _draw() left there would render
## at the un-projected position. Unlike PlayerVisual/NpcVisual, this proxy is
## NOT constructed by main.gd - enemies are spawned dynamically by
## RaidManager, outside main.gd's tree-building _ready() - so Enemy.gd wires
## its own EnemyVisual in its own _ready() (see enemy.gd's
## _wire_visual_proxy()).
##
## ADR-041 (Sprint 16 WS-C): when the manifest carries this enemy's resolved
## sprite entry, this proxy renders an AnimatedSprite2D child facing the
## direction of the enemy's own movement, via
## ActorVisual.facing_from_velocity() off Enemy's own (already-public)
## CharacterBody2D.velocity - the same reasoning as NpcVisual, since Enemy
## has no Player-style stored facing either. Sprite selection
## (resolve_sprite_id) has two cases: a thief_villager enemy (villager_id
## set) reuses the disguised villager's own NPC1 archetype via
## NpcVisual.archetype_sprite_id() - a thief should look like the villager it
## is, not like a bandit - and every other enemy_id maps to one of the three
## Bandits1 archetypes via BANDIT_SPRITE_IDS. The primitive body square below
## stays only as the no-asset fallback and is suppressed once the textured
## child exists; the health bar is not part of any pack's art and always
## stays in sync with Enemy.health (perf pass, 2026-08-10: redraws are now
## dirty-checked against the last-drawn health value instead of requested
## unconditionally every frame - still always current, just no longer
## paying for a _draw() call on frames where nothing changed).
##
## data/sprites.json carries no bandit_*_walk entries yet, for the same
## verified-facts-only reason NpcVisual's NPC1 archetypes are held back (see
## that class's docstring) - Bandits1's per-direction sheet layout is only
## partially confirmed (one direction's dimensions, not all eight), and this
## checkout has no SourceArtAssets/ tree to verify the rest against.
## SpriteManifest.get_entry() fails soft to {} for an unmapped id, so this
## proxy is correct today and correct once the entries and textures land.

const BODY_COLOR_BANDIT := Color.FIREBRICK
const BODY_COLOR_THIEF := Color(0.7, 0.3, 0.6)
const HEALTH_BAR_COLOR := Color.GREEN
const BODY_SIZE := 20.0
const HEALTH_BAR_HEIGHT := 3.0
const HEALTH_BAR_Y_OFFSET := -14.0

## data/enemies.json's four ids mapped onto Bandits1's three archetypes
## (design/sprints/sprint_16_art_integration.md section 1) - a thematic pick
## to eyeball once real assets are staged (ADR-041 Phase 1 deliverable 4's
## own precedent for "flag, don't lock blind" texture-filter defaults applies
## equally here), not a verified source-asset fact. bandit_melee (the plain
## rank-and-file raider) reads as Robber; bandit_archer (a ranged specialist)
## reads as Assassin; raid_leader (the toughest scripted enemy) reads as
## Thug. An enemy_id with no mapping (thief_villager routes through the
## villager-archetype branch instead; any future enemy_id not yet listed)
## falls back to "" - SpriteManifest.get_entry("") fails soft to an empty
## entry, same as any other unresolved sprite id.
const BANDIT_SPRITE_IDS := {
	"bandit_melee": "bandit_robber_walk",
	"bandit_archer": "bandit_assassin_walk",
	"raid_leader": "bandit_thug_walk",
}

var _enemy: Enemy
var _anim: AnimatedSprite2D
var _sprite_entry: Dictionary = {}
var _facing: Vector2i = Vector2i.DOWN
## Sentinel outside FACING_NEIGHBOURS' range (perf pass, 2026-08-10) - see
## NpcVisual's identical field for the full rationale.
var _last_set_facing := Vector2i(99, 99)
## -1 forces the first _process call to redraw regardless of health (perf
## pass, 2026-08-10). The unconditional per-frame queue_redraw() this
## replaces was deliberate (docstring above: the health bar "keeps drawing
## regardless") because health only changes on take_damage(), not every
## frame - this dirty-check gets the same always-current health bar without
## paying for a _draw() call on every frame an enemy is simply standing or
## walking undamaged.
var _last_drawn_health := -1


## Overrides ActorVisual.track() to additionally cache the owner as a typed
## Enemy - the base class only keeps a plain Node2D reference, and this proxy
## reads Enemy's villager_id/health/max_health every frame. Also builds the
## textured child, if any, from this enemy's resolved sprite entry.
func track(owner: Node2D) -> void:
	super.track(owner)
	_enemy = owner as Enemy
	if _enemy != null:
		_build_sprite_child(SpriteManifest.get_entry(
			resolve_sprite_id(_enemy.enemy_id, _enemy.villager_id)))


## Builds the AnimatedSprite2D child from an already-resolved manifest entry.
## Split out from track() so tests can drive it directly with a hand-built
## entry without depending on the GameData autoload being reachable - see
## NpcVisual._build_sprite_child's identical rationale (this project's
## headless test harness never resolves /root autoload lookups).
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
	# Base class does the position follow (and frees this node if the enemy
	# is ever gone - CLAUDE.md trap 4). Only reface/redraw while that holds.
	super._process(delta)
	if not is_instance_valid(_enemy):
		return
	_facing = ActorVisual.facing_from_velocity(_enemy.velocity, _facing)
	if _anim != null:
		if _facing != _last_set_facing:
			SpriteManifest.set_facing(_anim, _sprite_entry, _facing)
			_last_set_facing = _facing
	if _enemy.health != _last_drawn_health:
		_last_drawn_health = _enemy.health
		queue_redraw()


func _draw() -> void:
	if not is_instance_valid(_enemy):
		return
	if _anim == null:
		var color := BODY_COLOR_THIEF if _enemy.villager_id != "" else BODY_COLOR_BANDIT
		draw_rect(Rect2(-BODY_SIZE / 2.0, -BODY_SIZE / 2.0, BODY_SIZE, BODY_SIZE), color)
	var bar_width := BODY_SIZE * (float(_enemy.health) / float(maxi(_enemy.max_health, 1)))
	draw_rect(Rect2(-BODY_SIZE / 2.0, HEALTH_BAR_Y_OFFSET, bar_width, HEALTH_BAR_HEIGHT), HEALTH_BAR_COLOR)


## Resolves which manifest sprite id an enemy with these fields should
## render, per the class docstring's two-case rule. Static and pure so it is
## testable with no live Enemy node.
static func resolve_sprite_id(enemy_id: String, villager_id: String) -> String:
	if villager_id != "":
		return NpcVisual.archetype_sprite_id(villager_id)
	return str(BANDIT_SPRITE_IDS.get(enemy_id, ""))
