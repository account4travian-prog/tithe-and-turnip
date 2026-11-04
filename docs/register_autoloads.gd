extends SceneTree
## Registers new autoloads through ProjectSettings.save() - the same
## engine-serialization approach docs/bootstrap_project.gd uses for the
## one-time greenfield bootstrap, applied here to the narrower, recurring
## case of a single new autoload landing after a phase (a "DESKTOP step" in
## this project's own vocabulary). Only ever touches the autoload/* keys
## listed in NEW_AUTOLOADS - every other project setting is loaded from the
## existing project.godot and written back unchanged by ProjectSettings.save().
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://docs/register_autoloads.gd
##
## Re-run whenever a phase leaves a new autoload owed - update NEW_AUTOLOADS
## first. Idempotent: re-registering an already-registered autoload with the
## same path is a no-op.

const NEW_AUTOLOADS: Array[Array] = [
	["DialogueManager", "res://scripts/autoloads/dialogue_manager.gd"],
	["FestivalManager", "res://scripts/autoloads/festival_manager.gd"],
	["MarriageManager", "res://scripts/autoloads/marriage_manager.gd"],
	["ZoneManager", "res://scripts/autoloads/zone_manager.gd"],
]


func _initialize() -> void:
	for entry: Array in NEW_AUTOLOADS:
		var key := "autoload/" + str(entry[0])
		var value := "*" + str(entry[1])
		var already := str(ProjectSettings.get_setting(key, ""))
		if already == value:
			print("already registered: %s -> %s" % [entry[0], entry[1]])
			continue
		ProjectSettings.set_setting(key, value)
		print("registered: %s -> %s" % [entry[0], entry[1]])
	var err := ProjectSettings.save()
	if err != OK:
		push_error("[register_autoloads] save failed (err %d)" % err)
		quit(1)
		return
	print("project.godot saved")
	quit()
