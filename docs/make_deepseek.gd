extends SceneTree
## Dev-only: regenerates `DEEPSEEK.md` from `CLAUDE.md`.
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://docs/make_deepseek.gd
##
## DEEPSEEK.md is the DeepSeek variant of the engineering contract. One source
## (CLAUDE.md), one derived file, and `tests/suites/test_deepseek_contract_sync.gd`
## fails the suite if they disagree - the same argument as make_agents.gd.

const SOURCE := "res://CLAUDE.md"
const DERIVED := "res://DEEPSEEK.md"


func _initialize() -> void:
	if not FileAccess.file_exists(SOURCE):
		push_error("[make_deepseek] %s is missing" % SOURCE)
		quit(1)
		return

	var derive_helper := preload("res://docs/derive_deepseek.gd")
	var out := derive_helper.derive_deepseek(FileAccess.get_file_as_string(SOURCE))

	var f := FileAccess.open(DERIVED, FileAccess.WRITE)
	if f == null:
		push_error("[make_deepseek] cannot write %s" % DERIVED)
		quit(1)
		return
	f.store_string(out)
	f.close()
	print("wrote %s (%d bytes) from %s" % [DERIVED, out.length(), SOURCE])
	quit()
