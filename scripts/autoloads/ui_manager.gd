extends Node

## Owns UI focus: a stack of open menu ids. `menu_open` is kept as a public
## bool for backward compatibility - Player suppresses tool use and equip
## shortcuts while it is true (player.gd). AUTOLOAD - no class_name.
##
## Also owns the global menu-toggle keybinds (pause, inventory, build menu,
## the debug cheat panel) via _process. This autoload sets itself to
## PROCESS_MODE_ALWAYS deliberately: the SceneTree root resolves to
## PROCESS_MODE_PAUSABLE by default, so main.gd's own _process stops firing
## the instant get_tree().paused becomes true (PauseMenu sets that on open).
## A toggle that must still work WHILE paused - closing pause with the same
## key, or opening the debug panel with Ctrl+K - cannot live in main.gd's
## _process for that reason. Living here instead is also semantically
## correct: UIManager is the thing that owns menu focus, and setting only
## this autoload to ALWAYS cannot cascade pause-unfreezing to gameplay nodes
## (Player, FarmGrid, NPCs) the way setting main.gd itself to ALWAYS would
## (they are not descendants of this autoload).

signal menu_opened(menu_id: String)
signal menu_closed(menu_id: String)
signal all_menus_closed

var menu_open := false

var _stack: Array[String] = []
## Playtest fix (item 4): cached player-group lookup, same pattern
## CombatManager/RaidManager/Enemy already use for get_first_node_in_group
## ("player") - lets UIManager query and cancel the hold-to-preview state
## without main.gd wiring a direct reference in.
var _player: Node = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(_delta: float) -> void:
	# get_node_or_null, not the bare InputManager identifier: test_ui_manager.gd
	# preloads this script and calls .new() off-tree (no autoloads resolvable
	# there), and a bare global-singleton reference fails to COMPILE in that
	# context (the same trap settings_menu.gd hit in Sprint 9 - "test-compiled
	# scripts must reach autoloads via get_node_or_null"). Off-tree instances
	# are never added to a tree, so _process never runs on them anyway; this
	# guard exists purely so the script still compiles when preloaded.
	var input_manager := get_node_or_null("/root/InputManager")
	if input_manager == null:
		return
	# Playtest fix (item 4): Escape does double duty (pause AND the
	# hold-to-preview cancel). _resolve_pause_action is the single, pure
	# decision so the two never race for the same press - see its docstring.
	var player := _player_ref()
	var hold_active := player != null and player.has_method("is_interact_hold_active") \
		and bool(player.is_interact_hold_active())
	match _resolve_pause_action(hold_active, not current_menu().is_empty(),
			input_manager.is_action_just_pressed("pause")):
		"cancel_hold":
			if player != null and player.has_method("cancel_interact_hold"):
				player.cancel_interact_hold()
		"open_pause":
			open_menu("pause")
		"close_top":
			close_top()
		_:
			pass
	if input_manager.is_action_just_pressed("inventory"):
		var current := current_menu()
		if current == "inventory":
			close_menu("inventory")
		elif current.is_empty():
			open_menu("inventory")
	if input_manager.is_action_just_pressed("open_build_menu"):
		var current := current_menu()
		if current == "build":
			close_menu("build")
		elif current.is_empty():
			open_menu("build")
	# Ctrl+K cheat panel: only while paused (mirrors TheAscentGoDot's
	# pattern), and never in a release export - the same OS.is_debug_build()
	# gate main.gd uses before it ever instantiates DebugPanel, so opening
	# "debug" here can never orphan a menu id with no listening panel.
	if OS.is_debug_build() and input_manager.is_action_just_pressed("toggle_debug_panel") and is_open("pause"):
		if is_open("debug"):
			close_menu("debug")
		else:
			open_menu("debug")


## Playtest fix (item 4): what should an Escape press do, given whether a
## hold-to-preview is active and whether a menu is already open? Pure - no
## tree/Input access - so it is directly unit-testable off-tree, the same
## pattern Player._interact_hold_step uses. A menu already open wins over a
## stale hold flag (defense-in-depth; a hold cannot actually survive a menu
## opening since open_menu() below cancels it synchronously), so Escape can
## never be permanently swallowed by either feature.
func _resolve_pause_action(hold_active: bool, has_open_menu: bool, pause_just_pressed: bool) -> String:
	if not pause_just_pressed:
		return "none"
	if has_open_menu:
		return "close_top"
	if hold_active:
		return "cancel_hold"
	return "open_pause"


func _player_ref() -> Node:
	if _player == null or not is_instance_valid(_player):
		var tree := get_tree()
		if tree != null:
			_player = tree.get_first_node_in_group("player")
	return _player


func open_menu(menu_id: String) -> void:
	# Playtest fix (item 4): every menu opening aborts a pending hold
	# synchronously, so a later release can never commit into a menu, or
	# after a state the player never saw (the target indicator disappears
	# the same instant).
	var player := _player_ref()
	if player != null and player.has_method("cancel_interact_hold"):
		player.cancel_interact_hold()
	if not _stack.has(menu_id):
		_stack.append(menu_id)
	menu_open = true
	menu_opened.emit(menu_id)


func close_menu(menu_id: String) -> void:
	_stack.erase(menu_id)
	menu_open = not _stack.is_empty()
	menu_closed.emit(menu_id)
	if _stack.is_empty():
		all_menus_closed.emit()


func close_top() -> void:
	if _stack.is_empty():
		return
	close_menu(_stack[-1])


func is_open(menu_id: String) -> bool:
	return _stack.has(menu_id)


func current_menu() -> String:
	return _stack[-1] if not _stack.is_empty() else ""


func close_all() -> void:
	var ids := _stack.duplicate()
	for id: String in ids:
		close_menu(id)
