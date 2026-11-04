extends Control

## Title screen themed to design/ui_mockups/tithe_and_turnip_ui_mockups
## .dc.html: wood-dark backdrop, gold title + tagline, menu list
## ("Begin a New Life", "Return to the Farm", "Leave the Manor"), and the
## vertical-slice footer. The .tscn stays editor-managed; everything here is
## runtime styling + runtime menu items. "Options" is deliberately omitted -
## the settings panel only exists inside the farm scene.

@onready var new_game_button: Button = $VBoxContainer/NewGameButton

var _footer_label: Label


func _ready() -> void:
	_build_backdrop()
	$VBoxContainer.add_theme_constant_override("separation", 14)
	_restyle_title()
	_build_tagline()
	_restyle_new_game()
	_add_menu_button("Return to the Farm", _on_return_pressed)
	_add_menu_button("Leave the Manor", func() -> void:
		get_tree().quit())
	_add_footer()
	resized.connect(_layout)
	_layout()


func _build_backdrop() -> void:
	var bg := ColorRect.new()
	bg.color = UIKit.C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	move_child(bg, 0)


func _restyle_title() -> void:
	var title := $VBoxContainer/TitleLabel
	title.text = "TITHE & TURNIP"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", UIKit.C_LIGHT)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	title.add_theme_constant_override("shadow_offset_x", 2)
	title.add_theme_constant_override("shadow_offset_y", 4)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _build_tagline() -> void:
	var tagline := UIKit.make_label("A Peasant's Portion, Sworn to Spring", 22, Color("d8c39a"))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	$VBoxContainer.add_child(tagline)


func _restyle_new_game() -> void:
	new_game_button.text = "Begin a New Life"
	new_game_button.pressed.connect(_on_new_game_pressed)
	_style_menu_button(new_game_button)


func _add_menu_button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	_style_menu_button(button)
	button.pressed.connect(callback)
	$VBoxContainer.add_child(button)
	return button


func _style_menu_button(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color("e8d7b8"))
	button.add_theme_color_override("font_hover_color", Color("f7e7bd"))
	button.add_theme_color_override("font_pressed_color", Color("f7dfa0"))
	var transparent := _menu_button_style()
	button.add_theme_stylebox_override("normal", transparent)
	button.add_theme_stylebox_override("hover", transparent)
	button.add_theme_stylebox_override("pressed", transparent)
	button.add_theme_stylebox_override("focus", transparent)


func _menu_button_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.content_margin_left = 10.0
	style.content_margin_right = 10.0
	style.content_margin_top = 2.0
	style.content_margin_bottom = 2.0
	return style


func _add_footer() -> void:
	_footer_label = UIKit.make_label("Vertical Slice — Spring, Year 1", 11, Color(0.95, 0.9, 0.81, 0.35))
	add_child(_footer_label)


func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var vbox: VBoxContainer = $VBoxContainer
	vbox.size = vbox.get_combined_minimum_size()
	vbox.position = Vector2((viewport.x - vbox.size.x) * 0.5, 130.0)
	if _footer_label != null:
		_footer_label.size = _footer_label.get_combined_minimum_size()
		_footer_label.position = Vector2(viewport.x - _footer_label.size.x - 22.0, viewport.y - 42.0)


func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")


## Loads the autosave after the farm scene exists: main.gd applies
## SaveManager.pending_load at the end of its _ready (farm-grid injection is
## wired by then), so the payload lands on live nodes.
func _on_return_pressed() -> void:
	if not FileAccess.file_exists("user://save_autosave.json"):
		return
	SaveManager.pending_load = "autosave"
	get_tree().change_scene_to_file("res://scenes/main.tscn")
