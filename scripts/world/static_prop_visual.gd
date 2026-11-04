class_name StaticPropVisual
extends Node2D

## Textured static prop proxy (ADR-041, Sprint 16 WS-A). Same contract as
## StructureVisual: must be added as a DIRECT child of WorldVisuals
## (CLAUDE.md trap 10 - y_sort_enabled sorts only direct children), and
## `position` is the footprint's screen-projected south-east corner - the
## single point WorldVisuals sorts against. The Sprite2D child is anchored so
## its visual base lands on that point (SpriteManifest.apply_static), and all
## drawn geometry sits at local y <= 0, so the sort origin never moves.
##
## Collision is NOT part of this class: forage/collision bodies stay in
## logical space exactly as they are today (CLAUDE.md section 8's
## presentation-only invariant). Position is set once in configure() - props
## never move.

var footprint: Rect2i = Rect2i(0, 0, 1, 1)
var _sprite: Sprite2D


## Places the prop at `new_footprint`'s projected corner and wires the
## manifest's sprite. A missing/empty entry leaves the proxy invisible so a
## missing-asset report decides the outcome instead of a silent wrong draw.
func configure(new_footprint: Rect2i, sprite_id: String) -> void:
	footprint = new_footprint
	position = IsoProjection.grid_to_screen(Vector2(footprint.end.x, footprint.end.y))
	var entry := SpriteManifest.get_entry(sprite_id)
	if _sprite == null:
		_sprite = Sprite2D.new()
		add_child(_sprite)
	SpriteManifest.apply_static(_sprite, entry)
