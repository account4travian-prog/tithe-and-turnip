extends RefCounted
## Coverage for ADR-032's WS-C actor/input work (design/IsometricConversion.md
## section 4, WS-C): the 8-way grid-space facing bucketing in
## scripts/player/player.gd's `_vector_to_facing`, its deterministic
## tie-break at 22.5-degree sector boundaries, and that
## IsoProjection.input_to_world_dir() is genuinely wired ahead of `velocity`
## in `_apply_movement_input` - not just present somewhere in the file.
##
## Drives Player's script directly off-tree (preload(...).new(), no scene
## tree, no InputManager autoload), matching the pattern
## test_time_math.gd and test_schedules.gd already use for the same reason:
## test_court.gd's docstring notes that /root autoload lookups do not
## resolve inside this headless harness's SceneTree._initialize(), so no
## suite in this project depends on a live autoload singleton.
## `_apply_movement_input` takes screen-space input as a parameter rather
## than reading InputManager itself specifically so it stays testable this
## way in production code, not just in a test-only shim.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")

## The eight grid-space king-move neighbours, in the same order player.gd's
## own FACING_NEIGHBOURS constant uses. Deliberately duplicated rather than
## reading player.gd's constant - a test's expectation should not be sourced
## from the exact thing it is checking.
const EXPECTED_NEIGHBOURS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1),
	Vector2i(-1, 0), Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
]


func suite_name() -> String:
	return "iso_actors"


func run(t: Object) -> void:
	_test_eight_way_facing_from_screen_input(t)
	_test_tie_break_determinism(t)
	_test_input_rotation_wired_ahead_of_velocity(t)
	_test_facing_getter_reflects_state(t)
	t.completed(4)


func _make_player():
	return PLAYER_SCRIPT.new()


## For each of the 8 grid neighbours, builds the SCREEN-space vector a real
## screen-relative input would need to produce in order to resolve to that
## neighbour after rotation. grid_to_screen is the exact inverse of the
## rotation input_to_world_dir performs (asserted directly in
## test_iso_projection.gd's round-trip coverage), so
## screen_to_grid(grid_to_screen(neighbour)) == neighbour exactly - this
## builds a genuine screen-space vector, not a grid-space vector dressed up
## as one, and runs it through the real _apply_movement_input pipeline
## (screen input -> IsoProjection.input_to_world_dir -> _vector_to_facing),
## not a hand-rolled reimplementation of any piece of it.
func _test_eight_way_facing_from_screen_input(t: Object) -> void:
	for neighbour: Vector2i in EXPECTED_NEIGHBOURS:
		var screen_vec := IsoProjection.grid_to_screen(Vector2(neighbour))
		var player = _make_player()
		player._apply_movement_input(screen_vec)
		t.eq(player.get_facing(), neighbour,
			"screen input for grid neighbour %s resolves to that neighbour" % neighbour)
	t.section_done("eight-way facing")


## Exact 22.5-degree sector boundary, between grid-east (1,0) and its
## clockwise diagonal neighbour (1,1) - reachable on a gamepad stick, not
## just an unreachable keyboard corner case. Calls the exact same pipeline
## twice with the identical input and requires an identical result both
## times: whichever side of the boundary the documented
## `floor(raw_sector + 0.5)` tie-break lands on, it must land there on every
## call, not flicker.
func _test_tie_break_determinism(t: Object) -> void:
	var boundary_grid_dir := Vector2(cos(PI / 8.0), sin(PI / 8.0))
	var screen_vec := IsoProjection.grid_to_screen(boundary_grid_dir)
	var player_a = _make_player()
	player_a._apply_movement_input(screen_vec)
	var first_result: Vector2i = player_a.get_facing()
	var player_b = _make_player()
	player_b._apply_movement_input(screen_vec)
	var second_result: Vector2i = player_b.get_facing()
	t.eq(first_result, second_result,
		"the 22.5-degree boundary resolves to the same facing on repeat calls")
	t.ok(first_result == Vector2i(1, 0) or first_result == Vector2i(1, 1),
		"boundary facing lands on one of the two adjacent sectors, not something unrelated")
	t.section_done("tie-break determinism")


## Proves input_to_world_dir is wired AHEAD of velocity, not merely present
## somewhere in the file: a screen-up press must not produce the naive
## un-rotated velocity (0, -speed) - that would be the "diagonal WASD"
## behaviour ADR-032 explicitly rejected (design/decisions.md ADR-032). It
## must instead match IsoProjection.input_to_world_dir(screen_up) * speed
## exactly, computed independently here rather than re-derived from the
## method under test.
func _test_input_rotation_wired_ahead_of_velocity(t: Object) -> void:
	var screen_up := Vector2(0.0, -1.0)
	var player = _make_player()
	var speed_before: float = player._speed
	player._apply_movement_input(screen_up)
	var naive_velocity: Vector2 = screen_up * speed_before
	t.not_ok(player.velocity.is_equal_approx(naive_velocity),
		"screen-up does not produce the naive un-rotated velocity")
	var expected_velocity: Vector2 = IsoProjection.input_to_world_dir(screen_up) * speed_before
	t.ok(player.velocity.is_equal_approx(expected_velocity),
		"velocity matches IsoProjection.input_to_world_dir(screen_input) * speed exactly")
	t.section_done("input rotation wired ahead of velocity")


## A zero screen input must leave facing (and therefore get_faced_tile())
## unchanged rather than snapping to an arbitrary sector - _vector_to_facing's
## deadzone guard, exercised through the public get_facing()/get_faced_tile()
## getters every downstream tool-use/interaction/combat consumer actually
## reads (plan section 2.3: their signature and meaning are unchanged).
func _test_facing_getter_reflects_state(t: Object) -> void:
	var player = _make_player()
	var initial_facing: Vector2i = player.get_facing()
	player._apply_movement_input(Vector2.ZERO)
	t.eq(player.get_facing(), initial_facing, "zero input leaves facing unchanged")
	var screen_vec := IsoProjection.grid_to_screen(Vector2(-1, 0))
	player._apply_movement_input(screen_vec)
	t.eq(player.get_facing(), Vector2i(-1, 0), "get_facing() reflects the resolved neighbour")
	t.eq(player.get_faced_tile(), player.get_current_tile() + Vector2i(-1, 0),
		"get_faced_tile() keeps its existing signature/meaning downstream of facing")
	t.section_done("facing getter")
