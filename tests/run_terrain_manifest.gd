extends SceneTree
## Focused runner for ADR-042 terrain art and season-aware manifest coverage.

const SUITE: Script = preload("res://tests/suites/test_terrain_manifest.gd")


func _initialize() -> void:
	var suite: Object = SUITE.new()
	var harness := _TestHarness.new(suite.suite_name())
	suite.run(harness)
	print("[suite] %s: %d passed, %d failed" % [
		harness.suite_name, harness.passed_count, harness.failure_messages.size()])
	if harness.failure_messages.is_empty():
		quit(0)
		return
	for message: String in harness.failure_messages:
		print("  - " + message)
	quit(1)


class _TestHarness:
	var suite_name: String = "unnamed"
	var passed_count: int = 0
	var failure_messages: Array[String] = []

	func _init(name: String) -> void:
		suite_name = name

	func ok(condition: bool, message: String) -> void:
		if condition:
			passed_count += 1
		else:
			failure_messages.append("[%s] FAIL: %s" % [suite_name, message])

	func not_ok(condition: bool, message: String) -> void:
		ok(not condition, message)

	func eq(actual: Variant, expected: Variant, message: String, hint: String = "") -> void:
		if actual == expected:
			passed_count += 1
			return
		var suffix := ""
		if not hint.is_empty():
			suffix = " (%s)" % hint
		failure_messages.append("[%s] FAIL: %s - expected %s, got %s%s" % [
			suite_name, message, str(expected), str(actual), suffix])

	func fail(message: String) -> void:
		failure_messages.append("[%s] FAIL: %s" % [suite_name, message])

	func section_done(_name: String) -> void:
		pass

	func completed(_expected_checks: int) -> void:
		pass
