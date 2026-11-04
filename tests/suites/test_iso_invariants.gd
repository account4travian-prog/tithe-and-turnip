extends RefCounted
## ADR-032 guard suite (CLAUDE.md section 8's projection-is-presentation-only
## invariant; section 9.4's input abstraction layer). Static analysis over
## scripts/, not runtime behaviour - it catches a defect no behavioural suite
## can: a second, drifted copy of the projection formula, or a direct
## Input.* call sneaking in outside InputManager as the four workstreams
## touch player/npc/enemy input handling. Best-effort, not exhaustive - see
## each check's docstring for what it can and cannot catch.

const SCRIPTS_ROOT := "res://scripts"
const PROJECTION_FILE := "res://scripts/globals/iso_projection.gd"
const INPUT_MANAGER_FILE := "res://scripts/autoloads/input_manager.gd"

## Identifiers introduced by ADR-032's projection seam. None of these should
## ever be defined a second time outside iso_projection.gd - a reimplementation
## with different names entirely would slip past a name-based check like this
## one, which is why this is "best-effort" rather than a proof.
const FORBIDDEN_TOKENS: Array[String] = [
	"grid_to_screen", "screen_to_grid", "world_to_screen", "screen_to_world",
	"input_to_world_dir", "cell_diamond", "cell_centre_screen", "visible_cells",
	"TILE_W", "TILE_H", "LOGICAL_CELL",
]


func suite_name() -> String:
	return "iso_invariants"


func run(t: Object) -> void:
	_test_projection_formula_confined(t)
	_test_no_direct_input_calls(t)
	_test_no_bare_actor_visual_instantiation(t)
	t.completed(3)


## Matches a DECLARATION of a forbidden name (`func grid_to_screen(`,
## `const TILE_W`) - not a call site. `IsoProjection.world_to_screen(...)` is
## the whole point of the seam and must not itself trip this check; only a
## second `func`/`const` under that name would.
func _test_projection_formula_confined(t: Object) -> void:
	var offenders: Array[String] = []
	for path: String in _all_gd_files(SCRIPTS_ROOT):
		if path == PROJECTION_FILE:
			continue
		var text := FileAccess.get_file_as_string(path)
		for token: String in FORBIDDEN_TOKENS:
			var re := RegEx.new()
			re.compile("\\b(func|const)\\s+%s\\b" % token)
			if re.search(text) != null:
				offenders.append("%s (token: %s)" % [path, token])
	t.eq(offenders, [],
		"no projection formula/constant DECLARED a second time outside iso_projection.gd (CLAUDE.md section 8)",
		"found: %s" % ", ".join(offenders))
	t.section_done("projection confined")


## \bInput\. requires a word boundary immediately before "Input" and a
## literal "." right after it, so it matches a bare Input.is_action_pressed()
## call but not InputManager.foo(), InputMap.foo(), InputEventMouseButton, or
## a hypothetical PlayerInput.foo().
func _test_no_direct_input_calls(t: Object) -> void:
	var re := RegEx.new()
	re.compile("\\bInput\\.")
	var offenders: Array[String] = []
	for path: String in _all_gd_files(SCRIPTS_ROOT):
		if path == INPUT_MANAGER_FILE:
			continue
		var text := FileAccess.get_file_as_string(path)
		if re.search(text) != null:
			offenders.append(path)
	t.eq(offenders, [],
		"no direct Input.* call under scripts/ outside InputManager (CLAUDE.md section 9.4)",
		"found: %s" % ", ".join(offenders))
	t.section_done("input abstraction")


## Regression guard for a real integration bug (found 2026-08-07 during
## live-editor verification, not by this suite): main.gd originally
## instantiated the generic `ActorVisual` base class directly for the player
## and every NPC. That's valid GDScript - ActorVisual is a real, constructible
## class - so nothing errored and every automated suite stayed green, but
## ActorVisual draws nothing by design (only its subclasses PlayerVisual/
## NpcVisual/EnemyVisual do), so the player and every NPC were silently
## invisible on screen while their positions tracked correctly underneath.
## enemy.gd already instantiates EnemyVisual correctly; this only needs to
## watch main.gd; a bare `ActorVisual.new()` anywhere in scripts/ is the
## same class of mistake and worth catching too.
func _test_no_bare_actor_visual_instantiation(t: Object) -> void:
	var re := RegEx.new()
	re.compile("\\bActorVisual\\.new\\(")
	var offenders: Array[String] = []
	for path: String in _all_gd_files(SCRIPTS_ROOT):
		var text := FileAccess.get_file_as_string(path)
		if re.search(text) != null:
			offenders.append(path)
	t.eq(offenders, [],
		"no bare ActorVisual.new() anywhere in scripts/ - use a concrete subclass (PlayerVisual/NpcVisual/EnemyVisual) that actually draws something",
		"found: %s" % ", ".join(offenders))
	t.section_done("no bare ActorVisual instantiation")


func _all_gd_files(root: String) -> Array[String]:
	var out: Array[String] = []
	_walk(root, out)
	return out


func _walk(dir_path: String, out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not entry.begins_with("."):
			var full := dir_path + "/" + entry
			if dir.current_is_dir():
				_walk(full, out)
			elif entry.ends_with(".gd"):
				out.append(full)
		entry = dir.get_next()
	dir.list_dir_end()
