extends RefCounted
## ADR-026 investigation coverage: exactly clue_count clues with one true
## entry; reveal hands out distinct clues until exhausted; accuse resolves
## once, correctly or not; to_dict/from_dict round-trips partial state; and a
## false accusation queues exactly one false_accusation offense via the real
## ReputationManager -> TitheManager wiring (the Sprint 11 test_court pattern).
## X6 mercy path: show_mercy only unlocks once the true clue is revealed
## (decoys alone never do), changes no standing, grants the data-driven
## opinion gain, sets the event flag, and resolves the investigation.

const INVESTIGATION_SCRIPT := preload("res://scripts/autoloads/investigation_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")
const PLAYER_SCRIPT := preload("res://scripts/autoloads/player_state.gd")
const REPUTATION_SCRIPT := preload("res://scripts/autoloads/reputation_manager.gd")
const TITHE_SCRIPT := preload("res://scripts/autoloads/tithe_manager.gd")


func suite_name() -> String:
	return "thief_investigation"


func run(t: Object) -> void:
	_test_clue_generation(t)
	_test_reveal_flow(t)
	_test_accuse_lifecycle(t)
	_test_roundtrip(t)
	_test_false_accusation_offense(t)
	_test_mercy_path(t)
	t.completed(6)


func _make_investigation(gd: Node = null) -> Node:
	var inv = INVESTIGATION_SCRIPT.new()
	if gd != null:
		inv.configure_for_test(gd)
	return inv


func _test_clue_generation(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var inv := _make_investigation(gd)
	var empty: Dictionary = inv.reveal_clue_for("steward")
	t.eq(empty, {}, "no clues before an investigation starts")
	inv.start_investigation("villager_3")
	var clues: Array = []
	for _i in range(6):
		var clue: Dictionary = inv.reveal_clue_for("steward")
		if clue.is_empty():
			break
		clues.append(clue)
	t.eq(clues.size(), 3, "exactly clue_count clues are generated")
	var true_clues := 0
	var true_suspect := ""
	for clue: Variant in clues:
		if bool((clue as Dictionary).get("true", false)):
			true_clues += 1
			true_suspect = str((clue as Dictionary).get("suspect_id", ""))
	t.eq(true_clues, 1, "exactly one clue is true")
	t.eq(true_suspect, "villager_3", "the true clue names the real thief")
	t.section_done("clue generation")


func _test_reveal_flow(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var inv := _make_investigation(gd)
	inv.start_investigation("villager_3")
	var first: Dictionary = inv.reveal_clue_for("villager_1")
	t.not_ok(first.is_empty(), "first reveal returns a clue")
	var seen: Dictionary = {}
	seen[str(first.get("text", ""))] = true
	var revealed: Array = []
	for _i in range(4):
		var clue: Dictionary = inv.reveal_clue_for("villager_1")
		if clue.is_empty():
			break
		revealed.append(clue)
		seen[str(clue.get("text", ""))] = true
	t.eq(revealed.size(), 2, "two further reveals exhaust the three clues")
	t.eq(seen.size(), 3, "each reveal returns a distinct clue")
	t.eq(inv.reveal_clue_for("villager_1"), {}, "reveal past the end returns nothing")
	t.ok(inv.can_accuse(), "investigation stays open after all clues are heard")
	t.section_done("reveal flow")


func _test_accuse_lifecycle(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var inv := _make_investigation(gd)
	t.not_ok(inv.can_accuse(), "cannot accuse before an investigation")
	inv.start_investigation("villager_3")
	t.ok(inv.can_accuse(), "can accuse while the investigation is open")
	t.eq(inv.accuse("villager_3"), true, "accusing the true suspect returns true")
	t.not_ok(inv.can_accuse(), "cannot accuse again after resolution")
	t.eq(inv.accuse("villager_3"), false, "a second accuse is rejected")
	var inv2 := _make_investigation(gd)
	inv2.start_investigation("villager_3")
	t.eq(inv2.accuse("villager_1"), false, "accusing a decoy returns false")
	t.section_done("accuse lifecycle")


func _test_roundtrip(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var inv_a := _make_investigation(gd)
	inv_a.start_investigation("villager_3")
	inv_a.reveal_clue_for("steward")
	inv_a.reveal_clue_for("priest")
	var inv_b := _make_investigation(gd)
	inv_b.from_dict(inv_a.to_dict())
	t.eq(inv_b.can_accuse(), true, "round-trip keeps the investigation open")
	t.eq(inv_b.get_revealed_clues().size(), 2, "round-trip keeps revealed clues")
	t.eq(inv_b.get_revealed_clues(), inv_a.get_revealed_clues(),
		"round-trip preserves the exact revealed clue set")
	t.eq(inv_b.to_dict().get("true_suspect_id"), "villager_3",
		"round-trip preserves the true suspect")
	inv_b.accuse("villager_3")
	t.not_ok(inv_b.can_accuse(), "round-trip state is live and resolvable")
	t.section_done("roundtrip")


func _test_false_accusation_offense(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	ps.money = 100
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	var day_holder := [12]
	var tm = TITHE_SCRIPT.new()
	tm.configure_for_test(ps, gd, func() -> int: return day_holder[0], null, rep)
	rep.action_applied.connect(tm._on_reputation_action)
	var inv = INVESTIGATION_SCRIPT.new()
	inv.configure_for_test(gd, rep)
	inv.start_investigation("villager_3")
	t.eq(inv.accuse("villager_1"), false, "decoy accusation fails")
	var pending: Array = tm.get("_pending_offenses") as Array
	t.eq(pending.size(), 1, "exactly one offense queued")
	t.eq(str(pending[0]), "false_accusation", "offense kind is false_accusation")
	t.eq(rep.get_standing("village"), -8.0, "village standing drops 8")
	t.eq(rep.get_standing("manor"), -3.0, "manor standing drops 3")
	t.eq(rep.get_opinion("villager_1"), -10.0, "the innocent's opinion drops 10")
	t.section_done("false accusation")


func _test_mercy_path(t: Object) -> void:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var ps = PLAYER_SCRIPT.new()
	var rep = REPUTATION_SCRIPT.new()
	rep.configure_for_test(gd, ps)
	var inv = INVESTIGATION_SCRIPT.new()
	inv.configure_for_test(gd, rep, ps)
	t.not_ok(inv.can_show_mercy("villager_3"), "mercy unavailable before an investigation")
	inv.start_investigation("villager_3")
	t.not_ok(inv.can_show_mercy("villager_3"), "mercy unavailable before the true clue is revealed")
	t.eq(inv.show_mercy("villager_3"), false, "show_mercy is rejected before the true clue is revealed")
	# The reveal order is shuffled, so force the decoy-only case directly:
	# every non-true clue revealed, true clue still hidden - this must never
	# unlock mercy (a minimum-clue-count proxy would wrongly pass here).
	var decoy_indices: Array[int] = []
	for i in range(inv._clues.size()):
		if not bool(inv._clues[i].get("true", false)):
			decoy_indices.append(int(i))
	inv._revealed_clue_indices = decoy_indices
	t.not_ok(inv.can_show_mercy("villager_3"), "decoy clues alone do not unlock mercy")
	t.eq(inv.show_mercy("villager_3"), false, "show_mercy is rejected on decoys alone")
	# Positive path through the real API: reveal until the true clue appears.
	var revealed: Array[Dictionary] = inv.get_revealed_clues()
	var guard := 0
	while not _has_true_clue(revealed) and guard < 8:
		var clue: Dictionary = inv.reveal_clue_for("villager_1")
		if clue.is_empty():
			break
		revealed = inv.get_revealed_clues()
		guard += 1
	t.ok(_has_true_clue(revealed), "true clue reached by the normal reveal path")
	t.ok(inv.can_show_mercy("villager_3"), "mercy unlocks once the true clue is revealed")
	t.not_ok(inv.can_show_mercy("villager_1"), "mercy only applies to the true suspect")
	var action_applied := [0]
	rep.action_applied.connect(func(_action_id: String) -> void:
		action_applied[0] += 1)
	var opinion_before: float = rep.get_opinion("villager_3")
	var expected_gain := float(gd.get_reputation_effect("show_mercy").get("opinion_delta", 0))
	t.eq(inv.show_mercy("villager_3"), true, "showing mercy to the true suspect resolves")
	t.eq(rep.get_opinion("villager_3"), opinion_before + expected_gain,
		"mercy grants the data-driven opinion gain")
	t.eq(rep.get_standing("manor"), 0.0, "mercy leaves manor standing unchanged")
	t.eq(rep.get_standing("village"), 0.0, "mercy leaves village standing unchanged")
	t.eq(rep.get_standing("church"), 0.0, "mercy leaves church standing unchanged")
	t.eq(action_applied[0], 0, "mercy never fires a reputation action (no court offense path)")
	t.ok(ps.has_event_flag("investigation.showed_mercy_villager_3"),
		"mercy sets the show_mercy event flag")
	t.not_ok(inv.can_accuse(), "investigation resolves after mercy")
	t.not_ok(inv.can_show_mercy("villager_3"), "mercy cannot be offered twice")
	t.eq(inv.accuse("villager_3"), false, "accuse after mercy is rejected")
	t.eq(inv.show_mercy("villager_3"), false, "a second show_mercy is rejected")
	t.section_done("mercy path")


func _has_true_clue(clues: Array[Dictionary]) -> bool:
	for clue: Dictionary in clues:
		if bool(clue.get("true", false)):
			return true
	return false
