class_name UIKit
extends RefCounted

## Shared UI construction helpers plus the UI reference palette from
## design/ui_mockups/tithe_and_turnip_ui_mockups.dc.html: wood-dark
## backgrounds, parchment cards, ink/border tones, and gold accents. The
## mockup's fonts (Cinzel/Spectral) are not embedded - sizes and colors carry
## the theme; importing real font files would be an asset step, out of scope.
##
## ADR-041 / Sprint 16 WS-D: the shared card and button builders now prefer
## 9-patch StyleBoxTexture styles sourced from data/sprites_ui.json
## (adventure_ui/vector SVGs) and fall back to the original StyleBoxFlat
## primitives whenever the manifest entry or its texture is unavailable -
## primitives remain the default everywhere no asset exists (ADR-041).

const C_BG := Color("1c1712")
const C_PARCHMENT := Color("e8d7b8")
const C_PARCHMENT_EDGE := Color("4a3324")
const C_INK := Color("2b2118")
const C_INK_SOFT := Color("4a3324")
const C_BORDER := Color("6b4a30")
const C_LIGHT := Color("f2e6cf")
const C_MUTED := Color("cbb98f")
const C_GOLD := Color("d4a74f")
const C_HEALTH := Color("b4503f")
const C_VIGOUR := Color("55a05f")
const C_CHURCH := Color("5e86c7")
const C_DARK_PANEL := Color(0.169, 0.129, 0.094, 0.85)  # #2b2118 at 85%

## ADR-041 WS-D manifest ids (data/sprites_ui.json, adventure_ui/vector).
const SPRITE_ID_BUTTON := "adventure_ui_button_brown"
const SPRITE_ID_BUTTON_DANGER := "adventure_ui_button_red"
const SPRITE_ID_BUTTON_DISABLED := "adventure_ui_button_grey"
const SPRITE_ID_PANEL := "adventure_ui_panel_brown"

## Text colors for textured buttons. The AdventureUI button centers are
## light parchment under brown/red/grey frames, so dark ink reads there
## where the flat fallback (dark button on dark backdrop) wants light text.
const C_BUTTON_TEXT := C_INK
const C_BUTTON_TEXT_HOVER := C_INK_SOFT
const C_BUTTON_TEXT_PRESSED := C_PARCHMENT_EDGE
const C_BUTTON_TEXT_DISABLED := Color(0.45, 0.40, 0.36)


static func make_label(text: String, font_size := 18, color := C_LIGHT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


static func make_button(text: String, danger := false, full_width := false) -> Button:
	var button := Button.new()
	button.text = text
	var normal_flat := _button_style(C_INK_SOFT, C_BORDER)
	var hover_flat := _button_style(C_INK_SOFT.lightened(0.10), C_GOLD)
	var pressed_flat := _button_style(C_INK_SOFT.darkened(0.12), C_BORDER)
	var disabled_flat := _button_style(Color(0.23, 0.20, 0.17), Color(0.32, 0.27, 0.22))
	if danger:
		normal_flat.bg_color = Color("4a2119")
		hover_flat.bg_color = Color("5f2a1f")
		pressed_flat.bg_color = Color("3c1a14")
	var sprite_id := SPRITE_ID_BUTTON_DANGER if danger else SPRITE_ID_BUTTON
	var normal_entry := SpriteManifest.get_entry(sprite_id)
	var normal := make_textured_style(normal_entry, normal_flat)
	var textured := normal is StyleBoxTexture
	button.add_theme_color_override("font_color", C_BUTTON_TEXT if textured else C_LIGHT)
	button.add_theme_color_override("font_hover_color", C_BUTTON_TEXT_HOVER if textured else Color.WHITE)
	button.add_theme_color_override("font_pressed_color", C_BUTTON_TEXT_PRESSED if textured else C_PARCHMENT)
	button.add_theme_color_override("font_disabled_color", C_BUTTON_TEXT_DISABLED if textured else Color(0.55, 0.48, 0.40))
	var hover := make_textured_style(normal_entry, hover_flat, Color(1.08, 1.05, 0.94))
	var pressed := make_textured_style(normal_entry, pressed_flat, Color(0.90, 0.88, 0.82))
	var disabled := make_textured_style(
		SpriteManifest.get_entry(SPRITE_ID_BUTTON_DISABLED), disabled_flat, Color(1, 1, 1, 0.75))
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)
	_apply_texture_filter(button, normal_entry)
	if full_width:
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return button


static func make_fullscreen_backdrop(color := Color(0.039, 0.031, 0.024, 0.66)) -> ColorRect:
	var rect := ColorRect.new()
	rect.color = color
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_STOP
	return rect


static func make_centered_container() -> CenterContainer:
	var container := CenterContainer.new()
	container.set_anchors_preset(Control.PRESET_FULL_RECT)
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return container


static func make_vbox(spacing := 6) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	return box


static func make_hbox(spacing := 8) -> HBoxContainer:
	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	return box


## Parchment card used by the pause menu and the HUD date/tooltip cards.
static func make_card(child: Control, min_width := 0) -> PanelContainer:
	var card := PanelContainer.new()
	if min_width > 0:
		card.custom_minimum_size = Vector2(min_width, 0)
	var panel_entry := SpriteManifest.get_entry(SPRITE_ID_PANEL)
	var style := make_textured_style(panel_entry, _card_style())
	card.add_theme_stylebox_override("panel", style)
	_apply_texture_filter(card, panel_entry)
	card.add_child(child)
	return card


## ADR-041 WS-D: builds a 9-patch StyleBoxTexture from a parsed sprites_ui
## entry. `flat` is the primitive fallback - an empty entry or a texture
## that fails to load returns it untouched, keeping primitives as the
## default wherever no asset exists. `tint` modulates the texture for
## hover/pressed/disabled states (StyleBoxTexture.modulate_color, verified
## on the local 4.7.1 binary by the WS-D probe). Entries carry
## texture_margin_* (the protected 9-patch edges) and content_margin_*
## (text padding) as floats, so no GameData int cast is needed for them.
static func make_textured_style(entry: Dictionary, flat: StyleBoxFlat, tint := Color.WHITE) -> StyleBox:
	if entry.is_empty():
		return flat
	var texture := SpriteManifest.get_static_texture(entry)
	if texture == null:
		return flat
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = float(entry.get("texture_margin_left", 6.0))
	style.texture_margin_right = float(entry.get("texture_margin_right", 6.0))
	style.texture_margin_top = float(entry.get("texture_margin_top", 6.0))
	style.texture_margin_bottom = float(entry.get("texture_margin_bottom", 6.0))
	style.content_margin_left = float(entry.get("content_margin_left", flat.content_margin_left))
	style.content_margin_right = float(entry.get("content_margin_right", flat.content_margin_right))
	style.content_margin_top = float(entry.get("content_margin_top", flat.content_margin_top))
	style.content_margin_bottom = float(entry.get("content_margin_bottom", flat.content_margin_bottom))
	style.modulate_color = tint
	return style


## Fill bar (health/vigour/tithe) as a native ProgressBar with styled
## background/fill. fraction is 0..1.
static func make_bar(fraction: float, fill_color: Color, width := 220, height := 10) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, height)
	bar.show_percentage = false
	bar.max_value = 100.0
	bar.value = clampf(fraction, 0.0, 1.0) * 100.0
	var bg := StyleBoxFlat.new()
	bg.bg_color = C_BG
	bg.set_corner_radius_all(5)
	bg.set_border_width_all(1)
	bg.border_color = C_BORDER
	bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = fill_color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	return bar


## Dark rounded pill (weather, market, standings, skills). accent is a dot
## color; pass Color(-1, -1, -1) for no dot.
static func make_pill(text: String, accent := Color(-1, -1, -1), font_size := 13) -> PanelContainer:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = C_DARK_PANEL
	style.border_color = C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 6.0
	style.content_margin_bottom = 6.0
	pill.add_theme_stylebox_override("panel", style)
	var row := make_hbox(8)
	pill.add_child(row)
	if accent.a >= 0.0:
		row.add_child(make_dot(accent, 9))
	row.add_child(make_label(text, font_size))
	return pill


## Gold message toast (the mockup's harvest-message pill).
static func make_toast(text: String, font_size := 13) -> PanelContainer:
	var toast := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(C_GOLD.r, C_GOLD.g, C_GOLD.b, 0.92)
	style.set_corner_radius_all(20)
	style.content_margin_left = 18.0
	style.content_margin_right = 18.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	style.shadow_color = Color(0, 0, 0, 0.4)
	style.shadow_size = 8
	toast.add_theme_stylebox_override("panel", style)
	toast.add_child(make_label(text, font_size, C_INK))
	return toast


static func make_dot(color: Color, size := 9) -> Panel:
	var dot := Panel.new()
	dot.custom_minimum_size = Vector2(size, size)
	dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(int(size / 2.0))
	dot.add_theme_stylebox_override("panel", style)
	return dot


static func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_PARCHMENT
	style.border_color = C_PARCHMENT_EDGE
	style.set_border_width_all(4)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28.0
	style.content_margin_right = 28.0
	style.content_margin_top = 24.0
	style.content_margin_bottom = 24.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 12
	return style


## Per-entry filter (Sprint 16 Phase 1 deliverable 4) applied to the owning
## Control: StyleBoxTexture draws through the control's CanvasItem filter,
## so the manifest's linear/nearest choice lands here, never in an .import
## edit. No-op on the primitive fallback path.
static func _apply_texture_filter(control: Control, entry: Dictionary) -> void:
	if entry.is_empty():
		return
	if str(entry.get("filter", SpriteManifest.FILTER_LINEAR)) == SpriteManifest.FILTER_NEAREST:
		control.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	else:
		control.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


static func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style
