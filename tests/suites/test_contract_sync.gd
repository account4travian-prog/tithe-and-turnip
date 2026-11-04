extends RefCounted
## Fails the suite if `AGENTS.md` and `CLAUDE.md` have drifted apart.
##
## Two harnesses read two filenames for the same engineering contract - Claude
## Code opens `CLAUDE.md`, the co-developer's harness requires `AGENTS.md` -
## and neither will go looking for the other. The failure this prevents is
## silent and mutual. The check runs against `docs/make_agents.gd`'s own
## `derive()`, not a reimplementation, so "in sync" means exactly what the
## generator means.

const GEN := preload("res://docs/make_agents.gd")

const SOURCE := "res://CLAUDE.md"
const DERIVED := "res://AGENTS.md"


func suite_name() -> String:
	return "contract_sync"


func run(t: Object) -> void:
	_test_both_exist(t)
	_test_in_sync(t)
	_test_transform_is_sound(t)
	t.completed(3)


func _test_both_exist(t: Object) -> void:
	t.ok(FileAccess.file_exists(SOURCE), "CLAUDE.md exists - it is the source of the contract")
	t.ok(FileAccess.file_exists(DERIVED),
		"AGENTS.md exists - the co-developer's harness requires this filename")
	t.section_done("both exist")


## The assertion the suite is for.
func _test_in_sync(t: Object) -> void:
	if not (FileAccess.file_exists(SOURCE) and FileAccess.file_exists(DERIVED)):
		t.fail("cannot compare - one of the two files is missing")
		t.section_done("in sync")
		return

	var expected := GEN.derive(FileAccess.get_file_as_string(SOURCE))
	var actual := FileAccess.get_file_as_string(DERIVED)

	if t.eq(actual.length(), expected.length(),
			"AGENTS.md matches CLAUDE.md in length",
			"regenerate with: --script res://docs/make_agents.gd"):
		pass
	var a := actual.split("\n")
	var e := expected.split("\n")
	var first_diff := -1
	for i in mini(a.size(), e.size()):
		if a[i] != e[i]:
			first_diff = i
			break
	if first_diff < 0 and a.size() != e.size():
		first_diff = mini(a.size(), e.size())

	t.eq(first_diff, -1, "AGENTS.md and CLAUDE.md are in sync",
		"first difference at line %d - regenerate with docs/make_agents.gd" % (first_diff + 1)
			if first_diff >= 0 else "")
	t.section_done("in sync")


## The transform itself, so a change to `derive()` cannot quietly redefine what
## "in sync" means.
func _test_transform_is_sound(t: Object) -> void:
	var sample := "Read CLAUDE.md before touching CLAUDE.md. See CLAUDE.md section 6."
	var out: String = GEN.derive(sample)

	t.ok(out.contains("AGENTS.md section 6"),
		"section citations are rewritten to the derived filename")
	t.ok(out.begins_with("<!--"), "the derived file opens with a generated-do-not-edit banner")

	# Scoped to the BODY, deliberately. The banner names CLAUDE.md on purpose.
	var body: String = out.substr(out.find("\n") + 1)
	t.not_ok(body.contains("CLAUDE.md"),
		"no reference to the source filename survives in the CONTRACT BODY")
	t.section_done("transform")
