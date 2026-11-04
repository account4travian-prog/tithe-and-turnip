class_name SaveSlotPanel
extends CanvasLayer

## Named save slots (ADR-020, CLAUDE.md amended in v0.3 to allow this UI -
## SaveManager already wrote to user://save_<slot>.json files before this
## panel existed; this is UI on top of an existing capability, not a new
## save-file format). Reached from the pause menu's "Save As...".

const MENU_ID := "save_slots"
const LAYER := 10
const SLOTS: Array[String] = ["slot1", "slot2", "slot3"]

var _rows_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Save Slots", 24))
	_rows_box = UIKit.make_vbox(2)
	frame.add_child(_rows_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false


func _refresh() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
	for slot: String in SLOTS:
		_rows_box.add_child(_build_row(slot))


func _build_row(slot: String) -> HBoxContainer:
	var path := "user://save_%s.json" % slot
	var summary := "Empty"
	if FileAccess.file_exists(path):
		var payload := SaveManager.read_payload(path)
		var time: Dictionary = payload.get("time", {})
		if not time.is_empty():
			summary = "Day %d, %s, Year %d" % [
				int(time.get("day", 1)), str(time.get("season", "spring")).capitalize(), int(time.get("year", 1))]
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label("%s - %s" % [slot, summary]))
	var save_button := UIKit.make_button("Save")
	save_button.pressed.connect(func() -> void:
		SaveManager.save_game(slot)
		_refresh())
	row.add_child(save_button)
	var load_button := UIKit.make_button("Load")
	load_button.disabled = summary == "Empty"
	load_button.pressed.connect(func() -> void:
		SaveManager.load_game(slot)
		UIManager.close_menu(MENU_ID)
		UIManager.close_menu("pause"))
	row.add_child(load_button)
	return row
