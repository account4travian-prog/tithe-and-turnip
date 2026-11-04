extends RefCounted
## Coverage for ADR-041 Sprint 16 Phase 1 (the shared sprite/animation
## foundation): GameData's data/sprites.json wiring and int-casting boundary,
## and SpriteManifest's anchor/scale/frame-rect/facing math. Every
## SpriteManifest function takes a parsed entry Dictionary rather than an id,
## so this suite drives it with hand-built entries off-tree - no autoloads,
## no staged texture files required (Sprint 16's asset-staging step hasn't
## run yet; these are pure-data/math checks that never call load() on a real
## path), matching the pattern test_iso_actors.gd already uses for
## Player._apply_movement_input.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "art_foundation"


func run(t: Object) -> void:
	_test_game_data_sprites_wiring(t)
	_test_game_data_sprite_nested_int_casting(t)
	_test_get_scale(t)
	_test_get_anchor(t)
	_test_direction_key(t)
	_test_get_frame_rects_grid_mode(t)
	_test_get_frame_rects_atlas_mode(t)
	_test_get_frame_rects_missing_dims_returns_empty(t)
	_test_get_facing_sequence(t)
	_test_animation_name(t)
	_test_animation_speed_uses_default_frame_duration(t)
	_test_get_static_texture_missing_path_returns_null(t)
	_test_apply_static_fails_soft_on_missing_texture(t)
	_test_apply_animated_fails_soft_on_missing_frames(t)
	_test_get_animated_frames_empty_entry_removes_default(t)
	_test_set_facing_noop_when_entry_empty(t)
	t.completed(18)


## data/sprites.json (Phase 0.5 hasn't staged any real assets yet, so it
## ships version 1 with an empty sprites array) loads without error and
## get_sprite() fails soft to {} for an unknown id - the exact contract every
## workstream's visual proxy relies on to decide "fall back to primitives".
func _test_game_data_sprites_wiring(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	t.eq(gd.get_sprite("does_not_exist"), {}, "unknown sprite id returns empty Dictionary")
	var male_idle: Dictionary = gd.get_sprite("male1_idle")
	t.eq(male_idle.get("directions", {}).get("0,-1", {}).get("count", 0), 4,
		"male idle north-facing row uses only its four authored frames")
	t.eq(male_idle.get("directions", {}).get("-1,-1", {}).get("count", 0), 4,
		"male idle north-west row uses only its four authored frames")
	t.ok(is_equal_approx(float(male_idle.get("directions", {}).get("0,-1", {}).get("fps", 0.0)), 1.6666667),
		"male idle north-facing row slows to match the longer idle cycle")
	t.section_done("game_data sprites wiring")


## Exercises the exact nested-cast block _cast_nested_ints() gained for
## sprites (directions/frames), the one piece of this phase not already
## verified against the live Godot binary by the DeepSeek foundation
## consult - JSON.parse_string always hands back floats, so this simulates
## that boundary directly rather than trusting the cast happened.
func _test_game_data_sprite_nested_int_casting(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.sprites = {
		"test_sprite": {
			"directions": {"1,0": {"start": 2.0, "count": 3.0, "flip_h": false}},
			"frames": [{"x": 1.0, "y": 2.0, "w": 3.0, "h": 4.0}],
		},
	}
	gd._cast_nested_ints()
	var entry: Dictionary = gd.get_sprite("test_sprite")
	var seq: Dictionary = entry.get("directions", {}).get("1,0", {})
	t.eq(typeof(seq.get("start")), TYPE_INT, "direction 'start' cast to int")
	t.eq(seq.get("start"), 2, "direction 'start' value preserved")
	t.eq(typeof(seq.get("count")), TYPE_INT, "direction 'count' cast to int")
	var frame: Dictionary = entry.get("frames", [])[0]
	t.eq(typeof(frame.get("x")), TYPE_INT, "frame 'x' cast to int")
	t.eq(frame.get("w"), 3, "frame 'w' value preserved")
	t.section_done("sprite nested int casting")


func _test_get_scale(t: Object) -> void:
	t.eq(SpriteManifest.get_scale({"frame_h": 64.0, "height_tiles": 0.75}), 0.375,
		"scale = height_tiles * TILE_H / frame_h (ADR-043: TILE_H 32)")
	t.eq(SpriteManifest.get_scale({}), 1.0, "missing frame_h defaults scale to 1.0")
	t.section_done("get_scale")


func _test_get_anchor(t: Object) -> void:
	t.eq(SpriteManifest.get_anchor({"anchor_x": 32, "anchor_y": 64}), Vector2(32, 64),
		"anchor reads anchor_x/anchor_y")
	t.eq(SpriteManifest.get_anchor({}), Vector2.ZERO, "missing anchor defaults to zero")
	t.section_done("get_anchor")


func _test_direction_key(t: Object) -> void:
	t.eq(SpriteManifest.direction_key(Vector2i(1, 0)), "1,0", "positive facing key")
	t.eq(SpriteManifest.direction_key(Vector2i(-1, -1)), "-1,-1", "negative facing key")
	t.section_done("direction_key")


func _test_get_frame_rects_grid_mode(t: Object) -> void:
	var rects := SpriteManifest.get_frame_rects(
		{"frame_w": 64.0, "frame_h": 64.0, "sheet_w": 128.0, "sheet_h": 64.0})
	t.eq(rects.size(), 2, "2x64 sheet over 64px frames yields 2 frames")
	t.eq(rects[0], Rect2(0, 0, 64, 64), "first grid frame rect")
	t.eq(rects[1], Rect2(64, 0, 64, 64), "second grid frame rect (row-major)")
	t.section_done("get_frame_rects grid mode")


func _test_get_frame_rects_atlas_mode(t: Object) -> void:
	var rects := SpriteManifest.get_frame_rects({"frames": [
		{"x": 0, "y": 0, "w": 32, "h": 32},
		{"x": 32, "y": 0, "w": 32, "h": 32},
	]})
	t.eq(rects.size(), 2, "explicit frames array yields matching rect count")
	t.eq(rects[1], Rect2(32, 0, 32, 32), "explicit frame rects read verbatim")
	t.section_done("get_frame_rects atlas mode")


## No sheet dims, no frame dims, no `frames` array, and critically no
## `texture` path either - must return empty without ever calling load() on
## a nonexistent res:// path (which would push_error and stall on a missing
## asset before Phase 0.5 has staged anything).
func _test_get_frame_rects_missing_dims_returns_empty(t: Object) -> void:
	t.ok(SpriteManifest.get_frame_rects({}).is_empty(),
		"an entry with no frame/sheet data yields no frame rects")
	t.section_done("get_frame_rects missing dims")


func _test_get_facing_sequence(t: Object) -> void:
	var entry := {"directions": {"1,0": {"start": 0, "count": 6, "flip_h": false}}}
	t.eq(SpriteManifest.get_facing_sequence(entry, Vector2i(1, 0)),
		{"start": 0, "count": 6, "flip_h": false}, "known facing returns its sequence")
	t.eq(SpriteManifest.get_facing_sequence(entry, Vector2i(0, -1)), {},
		"unmapped facing returns empty Dictionary")
	t.section_done("get_facing_sequence")


func _test_animation_name(t: Object) -> void:
	t.eq(SpriteManifest.animation_name({"id": "male1_walk"}, "1,0"),
		StringName("male1_walk:1,0"), "animation name combines id and facing key")
	t.section_done("animation_name")


## SpriteFrames stores frame duration as a relative multiplier. The
## animation's FPS is set separately, so every authored frame must retain the
## default multiplier of 1.0; using 1 / fps here makes the animation run at
## roughly fps squared.
func _test_animation_speed_uses_default_frame_duration(t: Object) -> void:
	var entry := {
		"id": "male1_walk",
		"texture": "res://assets/sprites/actors/male1/Unarmed/Without_shadow/Unarmed_Walk_without_shadow.png",
		"fps": 6.67,
		"frames": [
			{"x": 25, "y": 20, "w": 14, "h": 24},
			{"x": 89, "y": 20, "w": 14, "h": 24},
		],
		"directions": {"0,1": {"start": 0, "count": 2}},
	}
	var animation_frames := SpriteManifest.get_animated_frames(entry)
	var animation_name := SpriteManifest.animation_name(entry, "0,1")
	t.eq(animation_frames.get_animation_speed(animation_name), 6.67,
		"animation keeps the authored FPS")
	t.eq(animation_frames.get_frame_duration(animation_name, 0), 1.0,
		"frames use the default relative duration multiplier")
	var directional_entry := entry.duplicate(true)
	directional_entry["directions"] = {
		"0,1": {"start": 0, "count": 2},
		"0,-1": {"start": 0, "count": 2, "fps": 2.5},
	}
	var directional_frames := SpriteManifest.get_animated_frames(directional_entry)
	t.eq(directional_frames.get_animation_speed(
		SpriteManifest.animation_name(directional_entry, "0,-1")), 2.5,
		"a direction-specific FPS overrides the entry cadence")
	t.section_done("animation FPS/duration separation")


func _test_get_static_texture_missing_path_returns_null(t: Object) -> void:
	t.eq(SpriteManifest.get_static_texture({}), null,
		"an entry with no texture path returns null without attempting load()")
	t.section_done("get_static_texture missing path")


func _test_apply_static_fails_soft_on_missing_texture(t: Object) -> void:
	var sprite := Sprite2D.new()
	var applied := SpriteManifest.apply_static(sprite, {})
	t.not_ok(applied, "apply_static reports failure for an entry with no texture")
	t.not_ok(sprite.visible, "sprite is hidden rather than left showing an empty texture")
	t.section_done("apply_static fail-soft")


func _test_apply_animated_fails_soft_on_missing_frames(t: Object) -> void:
	var anim := AnimatedSprite2D.new()
	var applied := SpriteManifest.apply_animated(anim, {})
	t.not_ok(applied, "apply_animated reports failure for an entry with no frames")
	t.not_ok(anim.visible, "animated sprite is hidden rather than left showing nothing")
	t.section_done("apply_animated fail-soft")


## No texture path means no frames get built, but the constructor-supplied
## "default" animation must still have been removed - a stray "default"
## animation left behind would be a silent trap for the first real workstream
## that builds frames from a texture and expects a clean SpriteFrames.
func _test_get_animated_frames_empty_entry_removes_default(t: Object) -> void:
	var frames := SpriteManifest.get_animated_frames({})
	t.ok(frames.get_animation_names().is_empty(),
		"an entry with no texture yields a SpriteFrames with no animations at all")
	t.section_done("get_animated_frames empty entry")


func _test_set_facing_noop_when_entry_empty(t: Object) -> void:
	var anim := AnimatedSprite2D.new()
	SpriteManifest.set_facing(anim, {}, Vector2i(1, 0))
	t.eq(anim.sprite_frames, null,
		"set_facing on an entry with no facing data leaves sprite_frames untouched")
	t.section_done("set_facing noop")
