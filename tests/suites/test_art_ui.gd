extends RefCounted
## Coverage for ADR-041 Sprint 16 WS-D (UI chrome): the sprites_ui.json
## manifest entries for the adventure_ui/vector pack, the real SVG-import
## texture loads behind them, and UIKit.make_textured_style's 9-patch
## construction + primitive fallback. Follows test_art_foundation.gd's
## pattern - GameData parsed directly (no autoloads exist under
## --script mode), and SpriteManifest/UIKit functions driven with real
## parsed entries. Unlike the foundation suite, this one DOES load the
## staged textures on purpose: the sprint gate always runs
## `--headless --path . --import` first, and proving the AdventureUI SVGs
## rasterize to usable Texture2Ds is WS-D's empirical API check.

const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")

const BUTTON_ID := "adventure_ui_button_brown"
const BUTTON_DANGER_ID := "adventure_ui_button_red"
const BUTTON_DISABLED_ID := "adventure_ui_button_grey"
const PANEL_ID := "adventure_ui_panel_brown"


func suite_name() -> String:
	return "art_ui"


func run(t: Object) -> void:
	_test_game_data_parses_ui_entries(t)
	_test_manifest_textures_load(t)
	_test_textured_style_button(t)
	_test_textured_style_panel(t)
	_test_textured_style_tint(t)
	_test_textured_style_fallback_empty_entry(t)
	_test_textured_style_fallback_missing_texture(t)
	t.completed(7)


func _game_data() -> Object:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	return gd


## The four WS-D entries parse through the shared sprite boundary: keyed by
## id, static kind, real res:// texture path, int-cast frame dims, and the
## UI-only float margins (texture_margin_*/content_margin_*) that
## StyleBoxTexture consumes - no GameData cast needed for those.
func _test_game_data_parses_ui_entries(t: Object) -> void:
	var gd := _game_data()
	for sprite_id: String in [BUTTON_ID, BUTTON_DANGER_ID, BUTTON_DISABLED_ID, PANEL_ID]:
		var entry: Dictionary = gd.get_sprite(sprite_id)
		t.not_ok(entry.is_empty(), "%s has a manifest entry" % sprite_id)
		t.eq(str(entry.get("kind", "")), "static", "%s is a static entry" % sprite_id)
		t.ok(str(entry.get("texture", "")).begins_with("res://assets/sprites/ui/"),
			"%s points at a staged UI texture" % sprite_id)
		t.eq(typeof(entry.get("frame_w")), TYPE_INT, "%s frame_w cast to int" % sprite_id)
		t.eq(typeof(entry.get("texture_margin_left")), TYPE_FLOAT,
			"%s texture_margin_left stays a float (no int cast needed)" % sprite_id)
	t.eq(int(gd.get_sprite(BUTTON_ID).get("frame_w")), 48, "button entry frame width is 48")
	t.eq(int(gd.get_sprite(PANEL_ID).get("frame_w")), 64, "panel entry frame width is 64")
	t.section_done("game_data sprites_ui entries")


## The empirical SVG-import check, kept as a regression test: Godot 4.7.1's
## headless importer rasterizes the vector/ SVGs to CompressedTexture2D
## resources with their authored pixel sizes (48x24 buttons, 64x64 panel).
func _test_manifest_textures_load(t: Object) -> void:
	var gd := _game_data()
	var expected_sizes := {
		BUTTON_ID: Vector2(48, 24),
		BUTTON_DANGER_ID: Vector2(48, 24),
		BUTTON_DISABLED_ID: Vector2(48, 24),
		PANEL_ID: Vector2(64, 64),
	}
	for sprite_id: String in expected_sizes:
		var texture := SpriteManifest.get_static_texture(gd.get_sprite(sprite_id))
		t.not_ok(texture == null, "%s texture loads non-null after --import" % sprite_id)
		if texture != null:
			t.eq(texture.get_size(), expected_sizes[sprite_id],
				"%s texture has its authored pixel size" % sprite_id)
	t.section_done("manifest texture loads")


func _test_textured_style_button(t: Object) -> void:
	var gd := _game_data()
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("4a2119")
	flat.content_margin_left = 14.0
	flat.content_margin_right = 14.0
	flat.content_margin_top = 8.0
	flat.content_margin_bottom = 8.0
	var style := UIKit.make_textured_style(gd.get_sprite(BUTTON_ID), flat)
	t.ok(style is StyleBoxTexture, "button entry builds a StyleBoxTexture")
	var textured := style as StyleBoxTexture
	if textured == null:
		return
	t.not_ok(textured.texture == null, "textured button style carries the SVG texture")
	t.eq(textured.texture_margin_left, 6.0, "button texture margin protects the 9-patch edge")
	t.eq(textured.content_margin_left, 14.0, "button content margin matches the flat fallback")
	t.eq(textured.content_margin_top, 8.0, "button vertical content margin matches the flat fallback")
	t.section_done("textured style button")


func _test_textured_style_panel(t: Object) -> void:
	var gd := _game_data()
	var flat := StyleBoxFlat.new()
	flat.content_margin_left = 28.0
	flat.content_margin_right = 28.0
	flat.content_margin_top = 24.0
	flat.content_margin_bottom = 24.0
	var style := UIKit.make_textured_style(gd.get_sprite(PANEL_ID), flat)
	t.ok(style is StyleBoxTexture, "panel entry builds a StyleBoxTexture")
	var textured := style as StyleBoxTexture
	if textured == null:
		return
	t.eq(textured.texture_margin_left, 12.0, "panel texture margin keeps the frame unstreched")
	t.eq(textured.texture_margin_top, 12.0, "panel top texture margin matches the frame")
	t.eq(textured.content_margin_left, 28.0, "panel content margin matches the parchment card padding")
	t.section_done("textured style panel")


func _test_textured_style_tint(t: Object) -> void:
	var gd := _game_data()
	var flat := StyleBoxFlat.new()
	var tint := Color(0.9, 0.88, 0.82)
	var style := UIKit.make_textured_style(gd.get_sprite(BUTTON_ID), flat, tint)
	t.ok(style is StyleBoxTexture, "tinted entry still builds a StyleBoxTexture")
	var textured := style as StyleBoxTexture
	if textured != null:
		t.eq(textured.modulate_color, tint, "hover/pressed tint lands on modulate_color")
	t.section_done("textured style tint")


func _test_textured_style_fallback_empty_entry(t: Object) -> void:
	var flat := StyleBoxFlat.new()
	flat.bg_color = Color("4a2119")
	var style := UIKit.make_textured_style({}, flat)
	t.ok(style is StyleBoxFlat, "empty entry falls back to the flat primitive style")
	t.eq((style as StyleBoxFlat).bg_color, Color("4a2119"),
		"fallback preserves the caller's flat background")
	t.section_done("textured style fallback empty")


func _test_textured_style_fallback_missing_texture(t: Object) -> void:
	var flat := StyleBoxFlat.new()
	var style := UIKit.make_textured_style({"texture": ""}, flat)
	t.ok(style is StyleBoxFlat,
		"an entry whose texture cannot load falls back to the flat primitive style")
	t.section_done("textured style fallback missing texture")
