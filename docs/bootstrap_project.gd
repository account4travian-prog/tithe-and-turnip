extends SceneTree
## One-time headless bootstrap for the greenfield project.
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://docs/bootstrap_project.gd
##
## Writes project settings (window, stretch, physics tick, autoloads, input
## map) through ProjectSettings.save(), then builds the initial scenes
## (title_screen.tscn, main.tscn) with PackedScene.pack() + ResourceSaver.
##
## This is the DOCUMENTED EXCEPTION to the never-hand-edit rule for
## Godot-managed files (.deepseek/rules/godot-files.md): a greenfield repo has
## nothing for the editor to open. A minimal project.godot seed exists at repo
## bootstrap (the engine cannot create one from an empty directory headless);
## this script rewrites it and builds the scenes through the engine's own
## serialization APIs. After it runs, project.godot and the scenes are
## editor-managed like any other.

const AUTOLOADS: Array[Array] = [
	["GameData", "res://scripts/autoloads/game_data.gd"],
	["EventBus", "res://scripts/autoloads/event_bus.gd"],
	["InputManager", "res://scripts/autoloads/input_manager.gd"],
	["TimeManager", "res://scripts/autoloads/time_manager.gd"],
	["PlayerState", "res://scripts/autoloads/player_state.gd"],
	["SaveManager", "res://scripts/autoloads/save_manager.gd"],
	["UIManager", "res://scripts/autoloads/ui_manager.gd"],
]

const INPUT_ACTIONS: Array[Dictionary] = [
	{
		"action": "move_left",
		"keys": [KEY_A, KEY_LEFT],
	},
	{
		"action": "move_right",
		"keys": [KEY_D, KEY_RIGHT],
	},
	{
		"action": "move_up",
		"keys": [KEY_W, KEY_UP],
	},
	{
		"action": "move_down",
		"keys": [KEY_S, KEY_DOWN],
	},
	{
		"action": "interact",
		"keys": [KEY_E, KEY_SPACE],
	},
	{
		"action": "inventory",
		"keys": [KEY_TAB, KEY_I],
	},
	{
		"action": "pause",
		"keys": [KEY_ESCAPE],
	},
]


func _initialize() -> void:
	_ensure_dirs()
	_apply_project_settings()
	_build_title_scene()
	_build_main_scene()
	print("bootstrap complete: project.godot, scenes/title_screen.tscn, scenes/main.tscn")
	quit()


func _ensure_dirs() -> void:
	for dir: String in ["res://scenes", "res://scenes/ui", "res://assets"]:
		DirAccess.make_dir_recursive_absolute(dir)


func _apply_project_settings() -> void:
	ProjectSettings.set_setting("application/config/name", "Tithe & Turnip")
	ProjectSettings.set_setting("application/run/main_scene", "res://scenes/main.tscn")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1280)
	ProjectSettings.set_setting("display/window/size/viewport_height", 720)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("display/window/stretch/aspect", "expand")
	ProjectSettings.set_setting("physics/common/physics_ticks_per_second", 60)
	for entry: Array in AUTOLOADS:
		ProjectSettings.set_setting("autoload/" + str(entry[0]), "*" + str(entry[1]))
	for action_def: Dictionary in INPUT_ACTIONS:
		_register_action(action_def)
	ProjectSettings.save()
	print("project settings written")


func _register_action(action_def: Dictionary) -> void:
	var events: Array = []
	for key: Variant in action_def.get("keys", []):
		var event := InputEventKey.new()
		event.keycode = key as Key
		events.append(event)
	ProjectSettings.set_setting(
		"input/" + str(action_def.get("action", "")),
		{"deadzone": 0.2, "events": events})


func _build_title_scene() -> void:
	var root := Control.new()
	root.name = "TitleScreen"
	root.set_script(load("res://scripts/ui/title_screen.gd"))
	root.set_anchors_preset(Control.PRESET_FULL_RECT)

	var vbox := VBoxContainer.new()
	vbox.name = "VBoxContainer"
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.position = Vector2(500, 280)
	root.add_child(vbox)

	var title := Label.new()
	title.name = "TitleLabel"
	title.text = "Tithe & Turnip"
	title.add_theme_font_size_override("font_size", 48)
	vbox.add_child(title)

	var button := Button.new()
	button.name = "NewGameButton"
	button.text = "New Game"
	vbox.add_child(button)

	_save_scene(root, "res://scenes/title_screen.tscn")


func _build_main_scene() -> void:
	var root := Node2D.new()
	root.name = "Main"
	root.set_script(load("res://scripts/main.gd"))

	var farm := Node2D.new()
	farm.name = "FarmGrid"
	farm.set_script(load("res://scripts/world/farm_grid.gd"))
	root.add_child(farm)

	var player := CharacterBody2D.new()
	player.name = "Player"
	player.set_script(load("res://scripts/player/player.gd"))
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var shape := CircleShape2D.new()
	shape.radius = 12.0
	collision.shape = shape
	player.add_child(collision)
	root.add_child(player)

	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position = Vector2(320, 180)
	root.add_child(camera)

	var hud := CanvasLayer.new()
	hud.name = "HUD"
	var time_label := Label.new()
	time_label.name = "TimeLabel"
	time_label.position = Vector2(8, 4)
	var energy_label := Label.new()
	energy_label.name = "EnergyLabel"
	energy_label.position = Vector2(8, 28)
	var money_label := Label.new()
	money_label.name = "MoneyLabel"
	money_label.position = Vector2(8, 52)
	hud.add_child(time_label)
	hud.add_child(energy_label)
	hud.add_child(money_label)
	root.add_child(hud)

	_save_scene(root, "res://scenes/main.tscn")


func _save_scene(root: Node, path: String) -> void:
	# PackedScene.pack() only serializes children whose `owner` is the root;
	# without this, scenes would save as a lone root node.
	for child: Node in root.get_children():
		_assign_owners(child, root)
	var scene := PackedScene.new()
	if scene.pack(root) != OK:
		push_error("[bootstrap] failed to pack %s" % path)
		return
	var err := ResourceSaver.save(scene, path)
	if err != OK:
		push_error("[bootstrap] failed to save %s (err %d)" % [path, err])
		return
	print("wrote %s" % path)


func _assign_owners(node: Node, owner: Node) -> void:
	node.owner = owner
	for child: Node in node.get_children():
		_assign_owners(child, owner)
