extends RefCounted
## SkillManager XP/level coverage: threshold crossing, level clamping at the
## top of the table, effect lookup by current level, and save round-trip.
## Uses a real GameData (skills.json IS the fixture - the point is to catch
## drift in the shipped thresholds/effects, not to test generic XP math).

const SKILL_MANAGER_SCRIPT := preload("res://scripts/autoloads/skill_manager.gd")
const GAME_DATA_SCRIPT := preload("res://scripts/autoloads/game_data.gd")


func suite_name() -> String:
	return "skills"


func run(t: Object) -> void:
	_test_level_zero_start(t)
	_test_threshold_crossing(t)
	_test_level_clamps_at_max(t)
	_test_xp_to_next_maxed(t)
	_test_effect_lookup(t)
	_test_add_xp_for_source(t)
	_test_save_roundtrip(t)
	t.completed(7)


func _make() -> Array:
	var gd = GAME_DATA_SCRIPT.new()
	gd.load_all()
	var skill = SKILL_MANAGER_SCRIPT.new()
	skill.configure_for_test(gd)
	return [skill, gd]


func _test_level_zero_start(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	t.eq(skill.get_level("farming"), 0, "farming starts at level 0")
	t.eq(skill.get_xp("farming"), 0.0, "farming starts at 0 xp")
	t.section_done("level zero")


func _test_threshold_crossing(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	var leveled: Array = []
	skill.leveled_up.connect(func(skill_id: String, new_level: int) -> void:
		leveled.append([skill_id, new_level]))
	skill.add_xp("farming", 80.0)
	t.eq(skill.get_level("farming"), 1, "80 xp crosses farming's threshold[1] (80)")
	t.eq(leveled.size(), 1, "leveled_up fired exactly once")
	t.eq(leveled[0], ["farming", 1], "leveled_up carried the right skill id and level")
	skill.add_xp("farming", 1.0)
	t.eq(leveled.size(), 1, "gaining xp without crossing a threshold does not re-fire leveled_up")
	t.section_done("threshold crossing")


func _test_level_clamps_at_max(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	var gd = parts[1]
	var thresholds: Array = gd.get_skill_xp_thresholds("farming")
	var max_level: int = thresholds.size() - 1
	skill.add_xp("farming", 100000.0)
	t.eq(skill.get_level("farming"), max_level, "overshooting every threshold caps at the max level index")
	t.section_done("level clamp")


func _test_xp_to_next_maxed(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	skill.add_xp("farming", 100000.0)
	t.eq(skill.get_xp_to_next("farming"), -1.0, "xp_to_next returns -1.0 (not 0.0) once maxed")
	t.section_done("xp to next maxed")


func _test_effect_lookup(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	var gd = parts[1]
	t.eq(skill.get_effect("farming", "tool_energy_cost_mult"), 1.0,
		"level 0 farming tool_energy_cost_mult is the unskilled baseline (1.0)")
	var level_3_effects: Dictionary = gd.get_skill_level_effects("farming", 3)
	skill.add_xp("farming", float(gd.get_skill_xp_thresholds("farming")[3]))
	t.eq(skill.get_level("farming"), 3, "xp set to exactly threshold[3] lands on level 3")
	t.eq(skill.get_effect("farming", "tool_energy_cost_mult"),
		level_3_effects.get("tool_energy_cost_mult"),
		"get_effect at level 3 matches skills.json's level_effects[3] exactly")
	t.section_done("effect lookup")


func _test_add_xp_for_source(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	var gd = parts[1]
	skill.add_xp_for("labor", "chore_complete")
	t.eq(skill.get_xp("labor"), gd.get_skill_xp_source("labor", "chore_complete"),
		"add_xp_for adds exactly the xp_sources value for that source id")
	t.section_done("add xp for")


func _test_save_roundtrip(t: Object) -> void:
	var parts := _make()
	var skill = parts[0]
	skill.add_xp("farming", 45.0)
	skill.add_xp("combat", 12.0)
	skill.add_xp("labor", 5.0)
	var dumped: Dictionary = skill.to_dict()
	var restored = SKILL_MANAGER_SCRIPT.new()
	restored.configure_for_test(parts[1])
	restored.from_dict(dumped)
	for skill_id: String in ["farming", "foraging", "combat", "labor"]:
		t.eq(restored.get_xp(skill_id), skill.get_xp(skill_id),
			"%s xp round-trips through to_dict/from_dict" % skill_id)
	t.section_done("save roundtrip")
