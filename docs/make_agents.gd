extends SceneTree
## Dev-only: regenerates `AGENTS.md` from `CLAUDE.md`.
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://docs/make_agents.gd
##
## WHY TWO FILES EXIST AT ALL. They hold the same engineering contract under two names because two
## harnesses look for two filenames - Claude Code reads `CLAUDE.md`, the co-developer's harness
## requires `AGENTS.md`. Neither is willing to go looking for the other.
##
## WHY NOT A POINTER. `AGENTS.md` could be three lines saying "the contract is CLAUDE.md". That
## depends on the reading agent taking a hop, every session, including when it is under context
## pressure and skimming - and a contract followed 90% of the time produces an incompatible change
## a week. The tier-0 document is the wrong place to accept a probabilistic read.
##
## WHY NOT TWO HAND-MAINTAINED COPIES. One source, one derived file, and
## `tests/suites/test_contract_sync.gd` fails the suite if they disagree. Drift becomes
## impossible rather than discouraged.
##
## THE TRANSFORM IS ONE SUBSTITUTION and lives in `derive()` below, which the test calls too. If
## the generator and the check ever disagreed about what "in sync" means, the check would be
## worthless, so there is exactly one definition.

const SOURCE := "res://CLAUDE.md"
const DERIVED := "res://AGENTS.md"

## Stamped into the derived file so a human editing the wrong one finds out immediately rather
## than at the next regeneration.
const BANNER := "<!-- GENERATED FROM CLAUDE.md - do not edit. Run docs/make_agents.gd. -->\n"


func _initialize() -> void:
	if not FileAccess.file_exists(SOURCE):
		push_error("[make_agents] %s is missing" % SOURCE)
		quit(1)
		return

	var out := derive(FileAccess.get_file_as_string(SOURCE))
	var f := FileAccess.open(DERIVED, FileAccess.WRITE)
	if f == null:
		push_error("[make_agents] cannot write %s" % DERIVED)
		quit(1)
		return
	f.store_string(out)
	f.close()
	print("wrote %s (%d bytes) from %s" % [DERIVED, out.length(), SOURCE])
	quit()


## `CLAUDE.md`'s text as `AGENTS.md` should hold it.
##
## The whole transform: swap the filename, so every self-reference names the file the reader
## actually opened. Static, so `test_contract_sync.gd` can apply the identical transform without
## running a SceneTree.
static func derive(source_text: String) -> String:
	return BANNER + source_text.replace("CLAUDE.md", "AGENTS.md")
