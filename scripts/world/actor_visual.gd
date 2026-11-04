class_name ActorVisual
extends Node2D

## Visual proxy for a gameplay actor (ADR-032, plan section 3). Tracks its
## owner's logical position onto the screen every _process - presentation
## only, never _physics_process (CLAUDE.md section 4/9.7). Must be added as a
## DIRECT child of WorldVisuals, never of its owner actor - y_sort_enabled
## sorts only direct children (trap 10), so a proxy parented to its actor
## silently drops out of sort order.
##
## Frozen by Phase 0 as the follow/lifecycle contract every actor proxy
## shares, so WS-C's three actors (player, NPC, enemy) follow one proven
## path instead of three independent ones. WS-C supplies the drawn geometry
## per actor type - by extending this class in a file it owns, or by
## overriding _draw() directly - the base only owns tracking and lifecycle.

var _owner: Node2D


## Begins following `owner`'s logical global_position. Call once, immediately
## after adding this node as a child of WorldVisuals.
func track(owner: Node2D) -> void:
	_owner = owner


func _process(_delta: float) -> void:
	if not is_instance_valid(_owner):
		# CLAUDE.md trap 4: queue_free() is deferred, so a just-freed owner
		# is still caught safely here; never read _owner's members past this
		# check once it fails.
		queue_free()
		return
	global_position = IsoProjection.world_to_screen(_owner.global_position)


## ADR-041 (Sprint 16 WS-C): 8-way grid-space facing bucketing from a
## velocity vector, for actor types (NPC, Enemy) with no Player-style stored
## facing of their own - unlike Player, they are not driven by rotated screen
## input, so there is nothing to read a facing off except their own
## CharacterBody2D.velocity each frame. Mirrors player.gd's frozen
## `_vector_to_facing` sector convention exactly (same FACING_NEIGHBOURS
## order, same TAU/8 sector width, same round-half-up tie-break) so the
## resulting Vector2i keys line up with the same "x,y" manifest direction
## strings SpriteManifest expects - but this is an independent
## reimplementation, not a call into player.gd, which the sprint brief
## freezes for this sprint (WS-C consumes Player.get_facing(), it does not
## change how facing is computed there, and _vector_to_facing is a private
## method on a class this workstream does not own besides).
##
## Static and pure (entry vector + current facing in, new facing out) so it
## is testable with no scene tree, no owner node, and no autoloads - see
## tests/suites/test_art_actors.gd.
const FACING_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]
const FACING_SECTOR_ANGLE: float = TAU / 8.0
## Below this squared length, `v` is treated as "no movement" and the current
## facing is kept rather than snapped to an arbitrary sector - same structural
## epsilon reasoning as player.gd's FACING_DEADZONE_SQ (a near-zero vector's
## angle() is meaningless), independently declared for the same reason the
## sector math above is.
const FACING_DEADZONE_SQ: float = 0.0001


static func facing_from_velocity(v: Vector2, current: Vector2i) -> Vector2i:
	if v.length_squared() < FACING_DEADZONE_SQ:
		return current
	var angle := v.angle()
	if angle < 0.0:
		angle += TAU
	var raw_sector := angle / FACING_SECTOR_ANGLE
	var sector := int(floor(raw_sector + 0.5)) % 8
	return FACING_NEIGHBOURS[sector]
