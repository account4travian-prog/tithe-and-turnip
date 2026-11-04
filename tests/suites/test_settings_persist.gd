extends RefCounted
## SettingsMenu.save_settings/load_settings round-trip through a scratch
## user:// path - deliberately not the real user://settings.json, and
## deliberately not part of SaveManager/SAVE_VERSION (local display
## preference, not game state).

const SETTINGS_SCRIPT := preload("res://scripts/ui/settings_menu.gd")
const SCRATCH_PATH := "user://test_settings_scratch.json"


func suite_name() -> String:
	return "settings_persist"


func run(t: Object) -> void:
	_test_roundtrip(t)
	_test_missing_file(t)
	_cleanup()
	t.completed(2)


func _test_roundtrip(t: Object) -> void:
	_cleanup()
	var data := {"window_mode": "windowed", "text_scale_index": 2}
	t.ok(SETTINGS_SCRIPT.save_settings(data, SCRATCH_PATH), "save_settings writes the scratch file")
	var loaded := SETTINGS_SCRIPT.load_settings(SCRATCH_PATH)
	t.eq(str(loaded.get("window_mode", "")), "windowed", "window_mode round-trips")
	t.eq(int(loaded.get("text_scale_index", -1)), 2, "text_scale_index round-trips")
	t.section_done("roundtrip")


func _test_missing_file(t: Object) -> void:
	_cleanup()
	var loaded := SETTINGS_SCRIPT.load_settings(SCRATCH_PATH)
	t.ok(loaded.is_empty(), "load_settings on a missing file returns an empty dictionary, not an error")
	t.section_done("missing file")


func _cleanup() -> void:
	if FileAccess.file_exists(SCRATCH_PATH):
		DirAccess.remove_absolute(SCRATCH_PATH)
