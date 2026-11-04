extends RefCounted
## Fails the suite if DEEPSEEK.md and CLAUDE.md have drifted apart.
## Mirrors tests/suites/test_contract_sync.gd for the DeepSeek variant: the
## check runs against docs/derive_deepseek.gd's own derive, not a
## reimplementation, so "in sync" means exactly what the generator means.

const GEN := preload("res://docs/derive_deepseek.gd")

const SOURCE := "res://CLAUDE.md"
const DERIVED := "res://DEEPSEEK.md"
const HARNESS_HEADING := "## DeepSeek harness"


func suite_name() -> String:
	return "deepseek_contract_sync"


func run(t: Object) -> void:
	_test_both_exist(t)
	_test_in_sync(t)
	_test_transform_is_sound(t)
	t.completed(3)


func _test_both_exist(t: Object) -> void:
	t.ok(FileAccess.file_exists(SOURCE), "CLAUDE.md exists - the source of the contract")
	t.ok(FileAccess.file_exists(DERIVED), "DEEPSEEK.md exists - the DeepSeek variant")
	t.section_done("both exist")


func _test_in_sync(t: Object) -> void:
	if not (FileAccess.file_exists(SOURCE) and FileAccess.file_exists(DERIVED)):
		t.fail("cannot compare - one of the two files is missing")
		t.section_done("in sync")
		return

	var expected := GEN.derive_deepseek(FileAccess.get_file_as_string(SOURCE))
	var actual := FileAccess.get_file_as_string(DERIVED)

	t.eq(actual.length(), expected.length(),
		"DEEPSEEK.md matches CLAUDE.md in length",
		"regenerate with: --script res://docs/make_deepseek.gd")

	var a := actual.split("\n")
	var e := expected.split("\n")
	var first_diff := -1
	for i in mini(a.size(), e.size()):
		if a[i] != e[i]:
			first_diff = i
			break
	if first_diff < 0 and a.size() != e.size():
		first_diff = mini(a.size(), e.size())

	t.eq(first_diff, -1, "DEEPSEEK.md and CLAUDE.md are in sync",
		"first difference at line %d - regenerate with docs/make_deepseek.gd" % (first_diff + 1)
			if first_diff >= 0 else "")
	t.section_done("in sync")


func _test_transform_is_sound(t: Object) -> void:
	var sample := "Read CLAUDE.md before touching CLAUDE.md. See CLAUDE.md section 6."
	var out: String = GEN.derive_deepseek(sample)

	t.ok(out.contains("DEEPSEEK.md section 6"),
		"section citations are rewritten to the derived filename")
	t.ok(out.begins_with("<!--"), "the derived file opens with a generated-do-not-edit banner")
	t.ok(out.contains(HARNESS_HEADING), "the derived file appends the DeepSeek harness section")

	var before_harness := out.substr(0, out.find(HARNESS_HEADING))
	var body := before_harness.substr(before_harness.find("\n") + 1)
	t.not_ok(body.contains("CLAUDE.md"),
		"no reference to the source filename survives in the CONTRACT BODY before the appended harness")
	t.section_done("transform")
