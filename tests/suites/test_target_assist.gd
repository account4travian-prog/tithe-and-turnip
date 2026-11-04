## Characterization coverage for the conservative interaction assist and the
## separate one-cell-at-a-time item aiming cursor.

const PLAYER_SCRIPT := preload("res://scripts/player/player.gd")
const TARGET_RESOLVER_SCRIPT := preload("res://scripts/player/target_resolver.gd")


func suite_name() -> String:
	return "target_assist"


func run(t: Object) -> void:
	_test_forward_candidate_order(t)
	_test_forward_candidates_exclude_the_rear(t)
	_test_character_assist_beats_a_farther_object_shape(t)
	_test_cardinal_item_aim_controls(t)
	_test_aim_step_is_one_cell(t)
	t.completed(4)


func _test_forward_candidate_order(t: Object) -> void:
	var offsets: Array[Vector2i] = TARGET_RESOLVER_SCRIPT.forward_offsets(Vector2i.RIGHT, 2, 45.0)
	t.eq(offsets[0], Vector2i.RIGHT, "the exact faced tile is the first assist candidate")
	t.eq(offsets[1], Vector2i(1, -1), "the closer forward diagonal follows the faced tile")
	t.eq(offsets[2], Vector2i(1, 1), "the other forward diagonal follows deterministically")
	t.section_done("forward candidate order")


func _test_forward_candidates_exclude_the_rear(t: Object) -> void:
	var offsets: Array[Vector2i] = TARGET_RESOLVER_SCRIPT.forward_offsets(Vector2i.RIGHT, 2, 45.0)
	t.not_ok(offsets.has(Vector2i.LEFT), "a character behind the player is not assisted")
	t.not_ok(offsets.has(Vector2i(-1, -1)), "a rear diagonal is not assisted")
	t.section_done("forward cone")


## Bug fix (2026-08-10): this test placed "hilda" at (6, 5), which - for a
## player at (5, 5) facing RIGHT - IS the exact faced tile
## (get_faced_tile() = get_current_tile() + _facing = (5,5) + (1,0) =
## (6,5), confirmed against player.gd's own implementation and matching
## _test_forward_candidate_order's own "the exact faced tile is the first
## assist candidate"). "assisted" is defined as `target != get_faced_tile()`
## (player.gd's _resolve_normal_target, and independently documented in
## target_indicator_renderer.gd's docstring: the assist indicator exists
## specifically for when the resolver redirects to a NEARBY tile, not the
## one already faced) - so a character sitting exactly on the faced tile is
## correctly NOT marked assisted, and the old assertion was asserting the
## wrong expectation, not exercising a real bug. Moved the character to the
## resolver's second candidate ((6, 4), forward_offsets(RIGHT, ...)[1] per
## _test_forward_candidate_order) so this test genuinely exercises a
## redirected/assisted selection instead of a coincidental exact-tile match.
func _test_character_assist_beats_a_farther_object_shape(t: Object) -> void:
	var player = PLAYER_SCRIPT.new()
	player.global_position = Vector2(5.0 * 32.0, 5.0 * 32.0)
	player._facing = Vector2i.RIGHT
	player.set_npc_lookup(func(tile: Vector2i) -> String:
		return "hilda" if tile == Vector2i(6, 4) else "")
	var resolved: Dictionary = player._resolve_normal_target()
	t.eq(resolved.get("target"), Vector2i(6, 4), "the nearest forward character is selected")
	t.ok(bool(resolved.get("assisted")), "a redirected forward character target is marked assisted")
	t.section_done("character priority")


func _test_aim_step_is_one_cell(t: Object) -> void:
	var player = PLAYER_SCRIPT.new()
	player._aim_target = Vector2i(4, 4)
	player._advance_item_aim(Vector2.RIGHT, 1.0 / 60.0)
	t.eq(player._aim_target, Vector2i(5, 4), "the first aim input advances exactly one logical cell")
	player._advance_item_aim(Vector2.RIGHT, 0.05)
	t.eq(player._aim_target, Vector2i(5, 4), "aim repeat waits for the configured delay")
	player._advance_item_aim(Vector2.RIGHT, 0.22)
	t.eq(player._aim_target, Vector2i(6, 4), "aim repeat advances one additional logical cell")
	t.section_done("grid aim")


func _test_cardinal_item_aim_controls(t: Object) -> void:
	t.eq(IsoProjection.input_to_aim_grid_dir(Vector2.UP), Vector2i(0, -1),
		"W/up selects the North grid face")
	t.eq(IsoProjection.input_to_aim_grid_dir(Vector2.DOWN), Vector2i(0, 1),
		"S/down selects the South grid face")
	t.eq(IsoProjection.input_to_aim_grid_dir(Vector2.LEFT), Vector2i(-1, 0),
		"A/left selects the West grid face")
	t.eq(IsoProjection.input_to_aim_grid_dir(Vector2.RIGHT), Vector2i(1, 0),
		"D/right selects the East grid face")
	t.section_done("cardinal aim controls")
