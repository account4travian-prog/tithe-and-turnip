class_name SpriteManifest
extends RefCounted

## ADR-041 shared sprite/animation seam (design/sprints/sprint_16_art_integration.md
## Phase 1). Static helper in the IsoProjection pattern - NOT an autoload
## (CLAUDE.md section 5's DESKTOP-step constraint; ADR-035/037). GameData owns
## data/sprites_world_dressing.json / sprites_structures.json / sprites_actors.json
## / sprites_ui.json / sprites_interiors.json parsing (one file per workstream, merged into one
## `sprites` Dictionary - avoids four worktrees conflicting on one shared
## file); this class owns resource construction
## (Texture2D/AtlasTexture/SpriteFrames) and the anchor/scale math every
## workstream shares.
##
## Every function below takes a parsed entry Dictionary (GameData.get_sprite(id))
## rather than an id, so the headless test harness can exercise the math with
## hand-built entries and no /root autoloads - the same off-tree pattern
## test_iso_actors.gd already uses for Player._apply_movement_input.

const FALLBACK_FPS: float = 6.0
const FILTER_NEAREST := "nearest"
const FILTER_LINEAR := "linear"


## Convenience lookup: GameData.get_sprite(id), or {} when the autoload is
## absent (headless tests, early boot). Consumers that already hold GameData
## can pass GameData.get_sprite(id) directly and skip this.
static func get_entry(sprite_id: String) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null or tree.root == null:
		return {}
	var game_data := tree.root.get_node_or_null("/root/GameData")
	if game_data == null:
		return {}
	return game_data.get_sprite(sprite_id)


## Loads the entry's texture. ResourceLoader caches by path, so repeated
## calls are cheap; a missing path loads as null and the caller fails soft.
static func get_static_texture(entry: Dictionary) -> Texture2D:
	var path := str(entry.get("texture", ""))
	if path.is_empty():
		return null
	return load(path) as Texture2D


## The entry's flat frame list, row-major from sheet_w/sheet_h/frame_w/
## frame_h (grid mode) or the explicit `frames` array (atlas mode). Sheet
## dimensions in data mean the math never needs a texture load to answer.
static func get_frame_rects(entry: Dictionary) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if entry.has("frames"):
		for f: Variant in entry.get("frames", []):
			var rect := f as Dictionary
			out.append(Rect2(
				float(rect.get("x", 0)), float(rect.get("y", 0)),
				float(rect.get("w", 0)), float(rect.get("h", 0))))
		return out
	var fw := float(entry.get("frame_w", 0.0))
	var fh := float(entry.get("frame_h", 0.0))
	if fw <= 0.0 or fh <= 0.0:
		return out
	var sheet_w := float(entry.get("sheet_w", 0.0))
	var sheet_h := float(entry.get("sheet_h", 0.0))
	if sheet_w <= 0.0 or sheet_h <= 0.0:
		# Fallback only for entries authored without sheet dims - deriving
		# from the texture costs a load and breaks off-tree tests.
		var tex := get_static_texture(entry)
		sheet_w = float(tex.get_width()) if tex != null else 0.0
		sheet_h = float(tex.get_height()) if tex != null else 0.0
	if sheet_w <= 0.0 or sheet_h <= 0.0:
		return out
	var cols := int(sheet_w / fw)
	var rows := int(sheet_h / fh)
	for r in range(rows):
		for c in range(cols):
			out.append(Rect2(c * fw, r * fh, fw, fh))
	return out


## Returns the source region for a static sprite. A static entry normally
## fills its texture, but generated assets share an atlas and supply one
## explicit frame. Without this branch a static atlas sprite would always
## render from (0, 0), silently showing the first unrelated asset.
static func get_static_region(entry: Dictionary, texture: Texture2D) -> Rect2:
	var explicit_frames: Array = entry.get("frames", [])
	if not explicit_frames.is_empty():
		var frame := explicit_frames[0] as Dictionary
		return Rect2(
			float(frame.get("x", 0)), float(frame.get("y", 0)),
			float(frame.get("w", texture.get_width())),
			float(frame.get("h", texture.get_height())))
	return Rect2(0.0, 0.0,
		float(entry.get("frame_w", texture.get_width())),
		float(entry.get("frame_h", texture.get_height())))


## Selects the last stage whose threshold is at or below the crop's current
## growth progress. Stage ordering lives in the manifest, keeping this a pure
## presentation lookup with no crop-data or gameplay dependency.
static func get_stage_sprite_id(stage_set: Dictionary, progress: float) -> String:
	var selected := ""
	for stage: Variant in stage_set.get("stages", []):
		var entry := stage as Dictionary
		if progress >= float(entry.get("min_progress", 0.0)):
			selected = str(entry.get("sprite_id", ""))
	return selected


## Source-pixel offset from the frame top-left to the visual base.
static func get_anchor(entry: Dictionary) -> Vector2:
	return Vector2(
		float(entry.get("anchor_x", 0)), float(entry.get("anchor_y", 0)))


## Uniform scale factor: target frame height (height_tiles * TILE_H) divided
## by the source frame height. See design/sprints/sprint_16_art_integration.md
## Phase 1 deliverable 3 for the derivation.
static func get_scale(entry: Dictionary) -> float:
	var fh := float(entry.get("frame_h", 0.0))
	if fh <= 0.0:
		return 1.0
	return float(entry.get("height_tiles", 1.0)) * IsoProjection.TILE_H / fh


## Explicit presentation scale for non-grid assets such as a complete interior
## shell. Ordinary world sprites retain the shared height_tiles formula.
static func get_draw_scale(entry: Dictionary) -> float:
	if entry.has("draw_scale"):
		return float(entry.get("draw_scale", 1.0))
	return get_scale(entry)


## "x,y" string key for a grid-space facing, matching the manifest's
## directions object (player.gd's FACING_NEIGHBOURS values).
static func direction_key(facing: Vector2i) -> String:
	return "%d,%d" % [facing.x, facing.y]


## The {"start", "count", "flip_h"} sequence for one facing; {} if absent.
static func get_facing_sequence(entry: Dictionary, facing: Vector2i) -> Dictionary:
	var directions: Dictionary = entry.get("directions", {})
	return directions.get(direction_key(facing), {})


## Stable per-direction animation name inside a SpriteFrames resource.
static func animation_name(entry: Dictionary, facing_key: String) -> StringName:
	return StringName("%s:%s" % [str(entry.get("id", "sprite")), facing_key])


## Cache of built SpriteFrames, keyed on the full entry Dictionary rather
## than entry["id"] (perf pass, 2026-08-10). SpriteFrames is a read-only
## Resource safe to share across every AnimatedSprite2D that plays it -
## playback state (current animation, frame, playing) lives on the node,
## not the resource - so this avoids rebuilding an identical
## AtlasTexture-per-frame set every time the same entry is requested (e.g.
## PlayerVisual switching between its idle/walk entries every time the
## player starts/stops moving, or several enemies sharing one archetype).
## Keying on entry["id"] alone would be wrong: test_art_foundation.gd's
## `directional_entry` reuses `entry`'s id with different `directions`, and
## GDScript Dictionary equality/hashing is by value, so keying on the whole
## entry only ever collides for genuinely identical entries.
static var _animated_frames_cache: Dictionary = {}


## Builds one SpriteFrames with one animation per direction mapping, each
## frame an AtlasTexture region of the entry's sheet. Verified on the local
## Godot 4.7.1 binary (2026-08-08): SpriteFrames.add_frame(anim, texture,
## duration, at_position) takes a Texture2D, not a rect - sheet slicing goes
## through AtlasTexture, and a new SpriteFrames starts with a "default"
## animation that must be removed.
static func get_animated_frames(entry: Dictionary) -> SpriteFrames:
	if _animated_frames_cache.has(entry):
		return _animated_frames_cache[entry]
	var frames := SpriteFrames.new()
	if frames.get_animation_names().has("default"):
		frames.remove_animation("default")
	var texture := get_static_texture(entry)
	var rects := get_frame_rects(entry)
	if texture == null or rects.is_empty():
		return frames
	var fps := float(entry.get("fps", 0.0))
	if fps <= 0.0:
		push_error("[SpriteManifest] %s: fps missing or non-positive" % str(entry.get("id", "?")))
		fps = FALLBACK_FPS
	var directions: Dictionary = entry.get("directions", {})
	for key: Variant in directions:
		var seq := directions[key] as Dictionary
		var start := int(seq.get("start", 0))
		var count := int(seq.get("count", 0))
		if count <= 0:
			count = rects.size() - start
		var anim_name := animation_name(entry, str(key))
		frames.add_animation(anim_name)
		# A direction may override the entry cadence when its authored frame
		# count differs. The player idle sheet has four back-facing frames but
		# twelve on the other rows, so keeping the same cycle duration requires
		# a slower per-direction FPS for the back view.
		var direction_fps := float(seq.get("fps", fps))
		if direction_fps <= 0.0:
			direction_fps = fps
		frames.set_animation_speed(anim_name, direction_fps)
		for i in range(count):
			var idx := start + i
			if idx < 0 or idx >= rects.size():
				break
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = rects[idx]
			# `set_animation_speed()` is the FPS control. SpriteFrames' frame
			# duration is a relative multiplier, not a duration in seconds;
			# passing 1 / fps here multiplied the requested speed a second time.
			frames.add_frame(anim_name, atlas)
	_animated_frames_cache[entry] = frames
	return frames


## Configures a Sprite2D child so its anchor pixel lands on this node's
## origin. Returns false (and hides the sprite) when the entry can't build a
## texture, so callers can fall back to primitives.
static func apply_static(sprite: Sprite2D, entry: Dictionary) -> bool:
	var texture := get_static_texture(entry)
	if texture == null:
		sprite.visible = false
		return false
	sprite.texture = texture
	sprite.region_enabled = true
	sprite.region_rect = get_static_region(entry, texture)
	sprite.centered = false
	sprite.offset = Vector2.ZERO
	var scale := get_draw_scale(entry)
	sprite.scale = Vector2(scale, scale)
	sprite.position = -get_anchor(entry) * scale
	sprite.texture_filter = _filter_mode(entry)
	sprite.visible = true
	return true


## Same contract for AnimatedSprite2D. Verified on 4.7.1: AnimatedSprite2D
## has `centered`, so both node types share one formula (centered=false +
## position = -anchor * scale); the offset property is deliberately unused.
static func apply_animated(anim: AnimatedSprite2D, entry: Dictionary) -> bool:
	var frames := get_animated_frames(entry)
	if frames.get_animation_names().is_empty():
		anim.visible = false
		return false
	anim.sprite_frames = frames
	anim.centered = false
	anim.offset = Vector2.ZERO
	var scale := get_scale(entry)
	anim.scale = Vector2(scale, scale)
	anim.position = -get_anchor(entry) * scale
	anim.texture_filter = _filter_mode(entry)
	anim.visible = true
	return true


## Switches an AnimatedSprite2D to the animation (and flip state) for a
## grid-space facing. Called every _process by actor visuals; cheap because
## animation switching never rebuilds frames.
static func set_facing(anim: AnimatedSprite2D, entry: Dictionary, facing: Vector2i) -> void:
	var seq := get_facing_sequence(entry, facing)
	if seq.is_empty() or anim.sprite_frames == null:
		return
	var anim_name := animation_name(entry, direction_key(facing))
	if anim.sprite_frames.get_animation_names().has(String(anim_name)):
		anim.animation = anim_name
		anim.flip_h = bool(seq.get("flip_h", false))


## Per-entry filter (Phase 1 deliverable 4): Nearest for pixel packs, Linear
## for painted/vector-clean packs, applied at the node so no .import edit or
## project-wide override is needed. Verified enum values on 4.7.1:
## PARENT_NODE=0, NEAREST=1, LINEAR=2.
static func _filter_mode(entry: Dictionary) -> int:
	if str(entry.get("filter", FILTER_LINEAR)) == FILTER_NEAREST:
		return CanvasItem.TEXTURE_FILTER_NEAREST
	return CanvasItem.TEXTURE_FILTER_LINEAR
