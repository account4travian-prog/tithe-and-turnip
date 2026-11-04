class_name DialoguePanel
extends CanvasLayer

## NPC dialogue with response options. `show_dialogue`'s `responses` param
## is `{"text": String, "callback": Callable}` per entry - built this way so
## a later sprint (thief accusation, gift-giving) can hand it real branching
## without a panel rewrite. Empty `responses` auto-adds a "Leave" option.

const MENU_ID := "dialogue"
const LAYER := 10

var _name_label: Label
var _line_label: Label
var _responses_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	_name_label = UIKit.make_label("", 22)
	frame.add_child(_name_label)
	_line_label = UIKit.make_label("")
	frame.add_child(_line_label)
	_responses_box = UIKit.make_vbox(2)
	frame.add_child(_responses_box)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)


func show_dialogue(npc_name: String, line: String, responses: Array[Dictionary] = []) -> void:
	_name_label.text = npc_name
	_line_label.text = line
	for child: Node in _responses_box.get_children():
		child.queue_free()
	var actual_responses := responses
	if actual_responses.is_empty():
		var leave_callback := func() -> void:
			UIManager.close_menu(MENU_ID)
		actual_responses = [{"text": "Leave", "callback": leave_callback}]
	for response: Dictionary in actual_responses:
		var button := UIKit.make_button(str(response.get("text", "...")))
		var callback: Callable = response.get("callback", Callable())
		button.pressed.connect(func() -> void:
			if callback.is_valid():
				callback.call())
		_responses_box.add_child(button)
	visible = true
	UIManager.open_menu(MENU_ID)


## Playtest fix: "Give a gift" opens the inventory panel (a second menu,
## MENU_ID "inventory") on top of this one without ever closing "dialogue"
## on the UIManager stack - the two menus stayed stacked, and this panel's
## full-rect MOUSE_FILTER_STOP backdrop (UIKit.make_fullscreen_backdrop)
## swallowed every click meant for the inventory's Gift buttons underneath,
## with Esc order also backwards (closing the invisible top-of-stack entry
## before the panel actually on screen). Hiding whenever a DIFFERENT menu
## opens - and reshowing when that menu closes, as long as "dialogue" is
## still open - keeps the conversation state intact (no _line_label/
## _responses_box rebuild) while removing the stacking ambiguity entirely,
## rather than re-negotiating CanvasLayer numbers per panel.
func _on_menu_opened(menu_id: String) -> void:
	if menu_id != MENU_ID and UIManager.is_open(MENU_ID):
		visible = false


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false
	elif UIManager.is_open(MENU_ID):
		visible = true
