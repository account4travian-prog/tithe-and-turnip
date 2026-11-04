extends Node

## The ONLY place gameplay input is read (CLAUDE.md section 9.4). Gameplay
## scripts call these wrappers; they never touch Input.* directly.
## Runtime actions (equip + menu keys) are registered here via the InputMap
## API so project.godot stays editor-managed; documented divergence.


func _ready() -> void:
	_register_runtime_actions()


func get_movement_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down", 0.15)


func is_action_just_pressed(action: StringName) -> bool:
	return Input.is_action_just_pressed(action)


func is_action_pressed(action: StringName) -> bool:
	return Input.is_action_pressed(action)


## Release twin of is_action_just_pressed - the hold-to-preview interact
## model (Player._interact_hold_step) commits on release, not press.
## Long-stable core Input API, unchanged since Godot 3.x.
func is_action_just_released(action: StringName) -> bool:
	return Input.is_action_just_released(action)


func is_using_gamepad() -> bool:
	return Input.get_connected_joypads().size() > 0


func _register_runtime_actions() -> void:
	_register_key_action("equip_hoe", KEY_1)
	_register_key_action("equip_can", KEY_2)
	_register_key_action("equip_turnip_seed", KEY_3)
	_register_key_action("equip_spear", KEY_4)
	_register_key_action("equip_bow", KEY_5)
	# Same physical key as menu_0 below (separate InputMap actions on one
	# key, same precedent as equip_hoe/menu_1 both sitting on KEY_1) -
	# player._handle_equip_shortcuts()'s existing menu-open guard means only
	# one of the two ever fires at a time.
	_register_key_action("equip_none", KEY_0)
	_register_key_action("attack", KEY_J)
	_register_key_action("open_build_menu", KEY_B)
	if not InputMap.has_action("attack_mouse"):
		InputMap.add_action("attack_mouse")
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		InputMap.action_add_event("attack_mouse", mouse)
	_register_key_action("menu_0", KEY_0)
	_register_key_action("menu_1", KEY_1)
	_register_key_action("menu_2", KEY_2)
	_register_key_action("menu_3", KEY_3)
	_register_key_action("menu_4", KEY_4)
	_register_key_action("menu_5", KEY_5)
	_register_key_action("menu_6", KEY_6)
	_register_key_action("menu_7", KEY_7)
	_register_key_action("menu_8", KEY_8)
	_register_key_action("menu_9", KEY_9)
	_register_ctrl_key_action("toggle_debug_panel", KEY_K)


func _register_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	InputMap.action_add_event(action, event)


## Ctrl+<key> variant of _register_key_action, used only by the debug cheat
## panel toggle (Ctrl+K) so it can never collide with an unmodified gameplay
## key.
func _register_ctrl_key_action(action: StringName, keycode: Key) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.keycode = keycode
	event.ctrl_pressed = true
	InputMap.action_add_event(action, event)
