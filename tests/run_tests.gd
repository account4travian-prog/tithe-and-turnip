extends SceneTree
## Headless test runner for Tithe & Turnip.
##
##     Godot_v4.7.1-stable_win64_console.exe --headless --path . --script res://tests/run_tests.gd
##
## Loads every suite, runs it through a shared _TestHarness, aggregates, and
## exits 0 (all pass) or 1 (any failure). No third-party frameworks.

const SUITES: Array[Script] = [
	preload("res://tests/suites/test_contract_sync.gd"),
	preload("res://tests/suites/test_deepseek_contract_sync.gd"),
	preload("res://tests/suites/test_time_math.gd"),
	preload("res://tests/suites/test_crop_growth.gd"),
	preload("res://tests/suites/test_save_roundtrip.gd"),
	preload("res://tests/suites/test_game_data_smoke.gd"),
	preload("res://tests/suites/test_farm_moisture.gd"),
	preload("res://tests/suites/test_weather.gd"),
	preload("res://tests/suites/test_market.gd"),
	preload("res://tests/suites/test_tithe_labor.gd"),
	preload("res://tests/suites/test_church.gd"),
	preload("res://tests/suites/test_reputation.gd"),
	preload("res://tests/suites/test_combat.gd"),
	preload("res://tests/suites/test_sleep_cycle.gd"),
	preload("res://tests/suites/test_season_sim.gd"),
	preload("res://tests/suites/test_ui_manager.gd"),
	preload("res://tests/suites/test_settings_persist.gd"),
	preload("res://tests/suites/test_skills.gd"),
	preload("res://tests/suites/test_forage.gd"),
	preload("res://tests/suites/test_crop_pack.gd"),
	preload("res://tests/suites/test_soil_fertility.gd"),
	preload("res://tests/suites/test_foraging_expansion.gd"),
	preload("res://tests/suites/test_dialogue_engine.gd"),
	preload("res://tests/suites/test_festivals.gd"),
	preload("res://tests/suites/test_festival_contests.gd"),
	preload("res://tests/suites/test_buildings.gd"),
	preload("res://tests/suites/test_tenure.gd"),
	preload("res://tests/suites/test_schedules.gd"),
	preload("res://tests/suites/test_npc_physics.gd"),
	preload("res://tests/suites/test_gifting.gd"),
	preload("res://tests/suites/test_requests.gd"),
	preload("res://tests/suites/test_marriage.gd"),
	preload("res://tests/suites/test_court.gd"),
	preload("res://tests/suites/test_corvee.gd"),
	preload("res://tests/suites/test_blackmarket.gd"),
	preload("res://tests/suites/test_raid_scaling.gd"),
	preload("res://tests/suites/test_thief_investigation.gd"),
	preload("res://tests/suites/test_combat_weapons.gd"),
	preload("res://tests/suites/test_crafting.gd"),
	preload("res://tests/suites/test_cooking.gd"),
	preload("res://tests/suites/test_animals.gd"),
	preload("res://tests/suites/test_board_orders.gd"),
	# Playtest fix (item 4): faced-tile targeting/highlight + hold-to-preview.
	preload("res://tests/suites/test_interact_hold.gd"),
	# Target assist keeps normal character/object selection conservative and
	# gives held item use a separate one-cell-at-a-time logical aim cursor.
	preload("res://tests/suites/test_target_assist.gd"),
	# ADR-034 (Sprint 15a): zone data/geometry and the ZoneManager model.
	# test_zone_transitions (Sprint 15b) registers here now that transitions
	# ship.
	preload("res://tests/suites/test_zones.gd"),
	preload("res://tests/suites/test_zone_manager.gd"),
	preload("res://tests/suites/test_zone_transitions.gd"),
	# ADR-032 (dimetric projection). test_iso_projection and test_iso_invariants
	# are real Phase 0 suites; the other four are pre-registered stubs so each
	# workstream (IsometricConversion.md section 4) only ever touches its own
	# suite file, never this runner - see that plan's section 5.2.
	preload("res://tests/suites/test_iso_projection.gd"),
	preload("res://tests/suites/test_iso_invariants.gd"),
	preload("res://tests/suites/test_iso_terrain.gd"),
	preload("res://tests/suites/test_iso_structures.gd"),
	preload("res://tests/suites/test_iso_actors.gd"),
	preload("res://tests/suites/test_iso_camera.gd"),
	# ADR-041 (Sprint 16, art asset integration): Phase 1 shared foundation -
	# GameData's sprites.json wiring and SpriteManifest's anchor/scale/frame
	# math. WS-A/B/C/D each add their own suite alongside this one as they land.
	preload("res://tests/suites/test_art_foundation.gd"),
	# Sprint 16 WS-B (structures): real manifest entries, static-sprite math
	# against them, and StructureVisual/BuildingRenderer textured wiring.
	preload("res://tests/suites/test_art_structures.gd"),
	# Approved generated well/hearth/coop atlas regions must remain distinct.
	preload("res://tests/suites/test_art_generated_assets.gd"),
	# WS-A (world dressing): forage spawn-point texture manifest + props.
	preload("res://tests/suites/test_art_dressing.gd"),
	# Approved Spring crops: three atlas-backed growth stages per crop.
	preload("res://tests/suites/test_crop_stage_art.gd"),
	# WS-D (UI chrome): textured StyleBoxTexture panels/buttons, pause menu.
	preload("res://tests/suites/test_art_ui.gd"),
	# WS-C (actors): facing-from-velocity math, NPC1/Bandits1 sprite-id
	# resolution, and the textured-child fail-soft build path.
	preload("res://tests/suites/test_art_actors.gd"),
	# ADR-042 (textured terrain): terrain_manifest.json wiring + int casts,
	# deterministic variant/scatter selection, transition-lookup math, and
	# the empty-manifest fallback routing in FarmRenderer + GameData.
	preload("res://tests/suites/test_terrain_manifest.gd"),
	# Interior art remains a clean shell plus data-addressed fixture overlays;
	# protects the north/west cutaway convention and future decorating seam.
	preload("res://tests/suites/test_interior_visuals.gd"),
]


func _initialize() -> void:
	var total_passed := 0
	var failures: Array[String] = []

	for suite_script: Script in SUITES:
		var suite = suite_script.new()
		var harness := _TestHarness.new()
		suite.run(harness)
		total_passed += harness.passed_count
		failures.append_array(harness.failure_messages)
		print("[suite] %s: %d passed, %d failed" % [
			harness.suite_name, harness.passed_count, harness.failure_messages.size()])

	if failures.is_empty():
		print("ALL SUITES PASSED (%d checks)" % total_passed)
		quit(0)
	else:
		print("FAILURES (%d):" % failures.size())
		for message: String in failures:
			print("  - " + message)
		quit(1)


## Minimal assertion harness shared by every suite. Suites call `ok`, `eq`,
## `fail`, `section_done`, and `completed`; the runner only reads the tallies.
class _TestHarness:
	var suite_name := "unnamed"
	var passed_count := 0
	var failure_messages: Array[String] = []

	func _init(name := "") -> void:
		suite_name = name

	func ok(condition: bool, message: String) -> void:
		if condition:
			passed_count += 1
		else:
			failure_messages.append("[%s] FAIL: %s" % [suite_name, message])

	func not_ok(condition: bool, message: String) -> void:
		ok(not condition, message)

	func eq(actual: Variant, expected: Variant, message: String, hint := "") -> void:
		if actual == expected:
			passed_count += 1
		else:
			var suffix := ""
			if not hint.is_empty():
				suffix = " (%s)" % hint
			failure_messages.append("[%s] FAIL: %s - expected %s, got %s%s" % [
				suite_name, message, str(expected), str(actual), suffix])

	func fail(message: String) -> void:
		failure_messages.append("[%s] FAIL: %s" % [suite_name, message])

	func section_done(_name: String) -> void:
		# Kept for interface parity with the Ascent suites; no-op.
		pass

	func completed(_expected_checks: int) -> void:
		# Kept for interface parity; the runner tallies from ok/eq calls.
		pass
