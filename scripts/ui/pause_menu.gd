class_name PauseMenu
extends CanvasLayer

## Pause menu themed to the mockups: parchment card, "Resume Toil" /
## "Options" / "Keep Record" / "Keep As..." / "Leave the Farm". Opening and
## closing this specific menu id is what freezes/unfreezes the game -
## main.gd never touches get_tree().paused directly.

const MENU_ID := "pause"
const LAYER := 20

var _subtitle_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(22)
	var title := UIKit.make_label("Paused", 30, UIKit.C_INK)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(title)
	_subtitle_label = UIKit.make_label("", 13, UIKit.C_INK_SOFT)
	_subtitle_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	frame.add_child(_subtitle_label)
	if OS.is_debug_build():
		var debug_hint := UIKit.make_label("Ctrl+K: Cheat Options (debug build)", 12, UIKit.C_MUTED)
		debug_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		frame.add_child(debug_hint)
	var divider := HSeparator.new()
	var divider_style := StyleBoxLine.new()
	divider_style.color = UIKit.C_BORDER
	divider_style.thickness = 1
	divider.add_theme_stylebox_override("separator", divider_style)
	frame.add_child(divider)
	var resume_button := UIKit.make_button("Resume Toil", false, true)
	resume_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(resume_button)
	var options_button := UIKit.make_button("Options", false, true)
	options_button.pressed.connect(func() -> void:
		UIManager.open_menu("settings"))
	frame.add_child(options_button)
	var save_button := UIKit.make_button("Keep Record", false, true)
	save_button.pressed.connect(_on_save_pressed)
	frame.add_child(save_button)
	var save_as_button := UIKit.make_button("Keep As...", false, true)
	save_as_button.pressed.connect(func() -> void:
		UIManager.open_menu("save_slots"))
	frame.add_child(save_as_button)
	var quit_button := UIKit.make_button("Leave the Farm", true, true)
	quit_button.pressed.connect(func() -> void:
		get_tree().quit())
	frame.add_child(quit_button)
	center.add_child(UIKit.make_card(frame, 440))
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		_subtitle_label.text = "Day %d of %s · Year %d · %s" % [
			TimeManager.day, TimeManager.season.capitalize(), TimeManager.year,
			TimeManager.time_string()]
		visible = true
		get_tree().paused = true


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false
		get_tree().paused = false


func _on_save_pressed() -> void:
	SaveManager.save_game("autosave")
