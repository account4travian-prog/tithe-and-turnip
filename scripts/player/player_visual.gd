class_name PlayerVisual
extends ActorVisual

## Draws the player's body under the isometric projection (ADR-032, amended ADR-043, WS-C - see
## design/IsometricConversion.md section 3, rule 1). Player.gd is a
## CharacterBody2D whose global_position is logical simulation space; it no
## longer draws itself, since a _draw() left there would render at the
## un-projected position. This proxy is what main.gd tracks instead
## (scripts/main.gd's `_player_visual`, wired in _ready()).
##
## ADR-041 (Sprint 16 WS-C): when data/sprites_actors.json carries the
## player actor entries, this proxy renders an AnimatedSprite2D child driven
## by Player.get_facing() (a GRID-space Vector2i; player.gd's facing
## computation is frozen for this sprint and consumed, not changed). The primitive
## body/face-bar _draw() below stays only as the no-asset fallback, per
## ADR-041's "primitives remain where no asset exists" rule - once the
## textured child exists, _draw() renders nothing.

const IDLE_SPRITE_ID := "male1_idle"
const WALK_SPRITE_ID := "male1_walk"

const BODY_COLOR := Color(0.35, 0.55, 0.30)
const OUTLINE_COLOR := Color(0.10, 0.15, 0.10)
const OUTLINE_WIDTH := 2.0
const FACE_COLOR := Color(0.90, 0.80, 0.40)
const BODY_HALF_SIZE := 14.0
const FACE_BAR_LENGTH := 16.0
const FACE_BAR_HALF_WIDTH := 2.0

var _player: Player
var _anim: AnimatedSprite2D
var _idle_entry: Dictionary = {}
var _walk_entry: Dictionary = {}
var _sprite_entry: Dictionary = {}
var _animation_state := ""
## Sentinel outside FACING_NEIGHBOURS' range (perf pass, 2026-08-10) - see
## NpcVisual's identical field for the full rationale.
var _last_set_facing := Vector2i(99, 99)


## Overrides ActorVisual.track() to additionally cache the owner as a typed
## Player - the base class only keeps a plain Node2D reference, and this
## proxy needs get_facing(), which is Player-specific. Also builds the
## textured child once, if and only if the manifest carries an actor entry.
func track(owner: Node2D) -> void:
	super.track(owner)
	_player = owner as Player
	_idle_entry = SpriteManifest.get_entry(IDLE_SPRITE_ID)
	_walk_entry = SpriteManifest.get_entry(WALK_SPRITE_ID)
	if _idle_entry.is_empty() and _walk_entry.is_empty():
		return
	_anim = AnimatedSprite2D.new()
	add_child(_anim)
	if not _switch_animation_state("idle"):
		# Entry present but texture/frames unavailable (e.g. assets not yet
		# staged) - fall back to primitives rather than rendering nothing.
		_anim.queue_free()
		_anim = null


func _process(delta: float) -> void:
	# Base class does the position follow (and frees this node if the player
	# is ever gone - CLAUDE.md trap 4).
	super._process(delta)
	if not is_instance_valid(_player):
		return
	if _anim != null:
		var desired_state := "walk" if _player.velocity.length_squared() > ActorVisual.FACING_DEADZONE_SQ else "idle"
		_switch_animation_state(desired_state)
		var facing := _player.get_facing()
		if facing != _last_set_facing:
			SpriteManifest.set_facing(_anim, _sprite_entry, facing)
			_last_set_facing = facing
	else:
		queue_redraw()


## Keeps the walking loop from running while the player is stationary. The
## idle entry is optional so an incomplete asset pack still falls back to the
## existing walk-only behavior without making the actor disappear.
func _switch_animation_state(state: String) -> bool:
	var requested_entry := _walk_entry if state == "walk" else _idle_entry
	if requested_entry.is_empty():
		requested_entry = _walk_entry if state == "idle" else _idle_entry
	if requested_entry.is_empty():
		return false
	if _animation_state == state and _sprite_entry == requested_entry:
		return true
	if not SpriteManifest.apply_animated(_anim, requested_entry):
		return false
	_sprite_entry = requested_entry
	_animation_state = state
	_last_set_facing = _player.get_facing()
	SpriteManifest.set_facing(_anim, _sprite_entry, _last_set_facing)
	_anim.play()
	return true


func _draw() -> void:
	# Primitive fallback only: once the textured child exists, nothing here
	# draws (ADR-041's definition of done forbids a primitive left under a
	# real asset).
	if _anim != null or not is_instance_valid(_player):
		return
	var body := Rect2(-BODY_HALF_SIZE, -BODY_HALF_SIZE, BODY_HALF_SIZE * 2.0, BODY_HALF_SIZE * 2.0)
	draw_rect(body, BODY_COLOR)
	draw_rect(body, OUTLINE_COLOR, false, OUTLINE_WIDTH)
	var facing := _player.get_facing()
	# facing is a grid-space unit offset (a Vector2i king-move neighbour, see
	# player.gd's _vector_to_facing) - project it with grid_to_screen, NOT
	# world_to_screen, which expects LOGICAL_CELL-scaled world units.
	var screen_dir := IsoProjection.grid_to_screen(Vector2(facing))
	if screen_dir == Vector2.ZERO:
		screen_dir = Vector2.DOWN
	else:
		screen_dir = screen_dir.normalized()
	var perp := Vector2(-screen_dir.y, screen_dir.x)
	var tip := screen_dir * FACE_BAR_LENGTH
	var base_a := perp * FACE_BAR_HALF_WIDTH
	var base_b := -perp * FACE_BAR_HALF_WIDTH
	draw_polygon(PackedVector2Array([base_a, base_b, tip]),
		PackedColorArray([FACE_COLOR, FACE_COLOR, FACE_COLOR]))
