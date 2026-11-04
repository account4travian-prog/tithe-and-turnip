class_name SettingsMenu
extends CanvasLayer

## Window mode, key rebinding (runtime InputMap, mirrors InputManager's own
## registration pattern), and text scale. Persisted to a dedicated
## user://settings.json - deliberately outside SaveManager/SAVE_VERSION,
## since this is local display preference, not game state.

const MENU_ID := "settings"
const LAYER := 10
const SETTINGS_PATH := "user://settings.json"
const REBINDABLE_ACTIONS: Array[StringName] = [
	&"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"attack",
]
const TEXT_SCALES: Array[float] = [0.8, 1.0, 1.2, 1.4]
const BASE_FONT_SIZE := 18

var _content_box: VBoxContainer
var _listening_for_action: StringName = &""
var _text_scale_index := 1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Settings", 24))
	_content_box = UIKit.make_vbox(2)
	frame.add_child(_content_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		var ui = get_node_or_null("/root/UIManager")
		if ui != null:
			ui.close_menu(MENU_ID))
	frame.add_child(close_button)
	var ui = get_node_or_null("/root/UIManager")
	if ui != null:
		ui.menu_opened.connect(_on_menu_opened)
		ui.menu_closed.connect(_on_menu_closed)
	_load_and_apply()


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_listening_for_action = &""
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false
		_listening_for_action = &""


func _input(event: InputEvent) -> void:
	if not visible or _listening_for_action == &"":
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var keycode := (event as InputEventKey).keycode
		InputMap.action_erase_events(_listening_for_action)
		var new_event := InputEventKey.new()
		new_event.keycode = keycode
		InputMap.action_add_event(_listening_for_action, new_event)
		_listening_for_action = &""
		_refresh()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	if not visible:
		return
	for child: Node in _content_box.get_children():
		child.queue_free()

	var mode_row := HBoxContainer.new()
	mode_row.add_child(UIKit.make_label("Window"))
	var windowed_button := UIKit.make_button("Windowed")
	windowed_button.pressed.connect(func() -> void:
		get_window().mode = Window.MODE_WINDOWED
		_save_current())
	mode_row.add_child(windowed_button)
	var fullscreen_button := UIKit.make_button("Fullscreen")
	fullscreen_button.pressed.connect(func() -> void:
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN
		_save_current())
	mode_row.add_child(fullscreen_button)
	_content_box.add_child(mode_row)

	var scale_row := HBoxContainer.new()
	scale_row.add_child(UIKit.make_label("Text size: %.1fx" % TEXT_SCALES[_text_scale_index]))
	var smaller_button := UIKit.make_button("-")
	smaller_button.pressed.connect(func() -> void:
		_change_text_scale(-1))
	scale_row.add_child(smaller_button)
	var larger_button := UIKit.make_button("+")
	larger_button.pressed.connect(func() -> void:
		_change_text_scale(1))
	scale_row.add_child(larger_button)
	_content_box.add_child(scale_row)

	_content_box.add_child(UIKit.make_label("Rebind (click, then press a key)"))
	for action: StringName in REBINDABLE_ACTIONS:
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label(str(action)))
		var is_listening := _listening_for_action == action
		var rebind_button := UIKit.make_button("Press a key..." if is_listening else _key_label_for(action))
		rebind_button.pressed.connect(func() -> void:
			_listening_for_action = action
			_refresh())
		row.add_child(rebind_button)
		_content_box.add_child(row)


func _change_text_scale(direction: int) -> void:
	_text_scale_index = clampi(_text_scale_index + direction, 0, TEXT_SCALES.size() - 1)
	_apply_text_scale()
	_save_current()
	_refresh()


func _apply_text_scale() -> void:
	var theme := Theme.new()
	theme.default_font_size = int(BASE_FONT_SIZE * TEXT_SCALES[_text_scale_index])
	if get_tree() != null and get_tree().current_scene != null:
		get_tree().current_scene.theme = theme


func _key_label_for(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return "(unbound)"
	var first := events[0]
	if first is InputEventKey:
		return OS.get_keycode_string((first as InputEventKey).keycode)
	return "(unbound)"


func _save_current() -> void:
	save_settings({
		"window_mode": "fullscreen" if get_window().mode == Window.MODE_EXCLUSIVE_FULLSCREEN else "windowed",
		"text_scale_index": _text_scale_index,
	})


func _load_and_apply() -> void:
	var data := load_settings()
	if data.has("window_mode"):
		get_window().mode = Window.MODE_EXCLUSIVE_FULLSCREEN \
			if str(data["window_mode"]) == "fullscreen" else Window.MODE_WINDOWED
	if data.has("text_scale_index"):
		_text_scale_index = clampi(int(data["text_scale_index"]), 0, TEXT_SCALES.size() - 1)
		call_deferred("_apply_text_scale")


static func save_settings(data: Dictionary, path := SETTINGS_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return true


static func load_settings(path := SETTINGS_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	return parsed if parsed is Dictionary else {}
