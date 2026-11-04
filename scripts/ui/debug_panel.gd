class_name DebugPanel
extends CanvasLayer

## Cheat/testing panel, modeled on TheAscentGoDot's harness pattern: Ctrl+K
## while the pause menu is open toggles this panel. It manipulates live
## autoload state directly through their existing public APIs (add_money,
## add_item, modify_standing, execute_raid, ...) - a workshop tool, not a
## game feature. main.gd only instantiates this panel when
## OS.is_debug_build() is true; it must never exist in a release export.
##
## SkillManager/BuildingManager/InvestigationManager/CraftingManager/
## AnimalManager are the five autoloads with a history of pending manual
## registration (DEVELOPMENT_STATE.md) - this panel resolves them via
## get_node_or_null, same as every other script that touches them, and shows
## "not registered" instead of a dead button when one is missing.

const MENU_ID := "debug"
const LAYER := 30
## Mirrors SkillManager.SKILL_IDS - duplicated locally rather than read off
## the (possibly-unregistered) autoload so the section can be built even
## before SkillManager exists.
const SKILL_IDS: Array[String] = ["farming", "foraging", "combat", "labor"]
const REPUTATION_AXES: Array[String] = ["manor", "village", "church"]
const ADVANCE_DAYS_MAX := 60
const GIVE_QTY_MAX := 99

var _skill_mgr: Node
var _building_mgr: Node
var _investigation_mgr: Node
var _crafting_mgr: Node
var _animal_mgr: Node
var _marriage_mgr: Node

var _status_label: Label
var _item_dropdown: OptionButton
var _quality_dropdown: OptionButton
var _give_qty_spin: SpinBox
var _advance_days_spin: SpinBox
var _jump_day_spin: SpinBox
var _set_hour_spin: SpinBox
var _set_money_spin: SpinBox
var _marriage_candidate_dropdown: OptionButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	_skill_mgr = get_node_or_null("/root/SkillManager")
	_building_mgr = get_node_or_null("/root/BuildingManager")
	_investigation_mgr = get_node_or_null("/root/InvestigationManager")
	_crafting_mgr = get_node_or_null("/root/CraftingManager")
	_animal_mgr = get_node_or_null("/root/AnimalManager")
	_marriage_mgr = get_node_or_null("/root/MarriageManager")

	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(10)
	frame.add_child(UIKit.make_label("Cheat Options (Debug Build)", 22, UIKit.C_INK))
	_status_label = UIKit.make_label("", 13, UIKit.C_INK_SOFT)
	frame.add_child(_status_label)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(680, 520)
	frame.add_child(scroll)
	var sections := UIKit.make_vbox(16)
	scroll.add_child(sections)

	sections.add_child(_build_time_section())
	sections.add_child(_build_weather_section())
	sections.add_child(_build_economy_section())
	sections.add_child(_build_player_section())
	sections.add_child(_build_inventory_section())
	sections.add_child(_build_skills_section())
	sections.add_child(_build_reputation_section())
	sections.add_child(_build_raid_section())
	sections.add_child(_build_investigation_section())
	sections.add_child(_build_marriage_section())
	sections.add_child(_build_building_crafting_section())
	sections.add_child(_build_save_section())

	var close_button := UIKit.make_button("Close", false, true)
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	center.add_child(UIKit.make_card(frame, 720))

	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_set_status("Day %d of %s, Year %d - %d coin - %d/%d energy" % [
			TimeManager.day, TimeManager.season.capitalize(), TimeManager.year,
			PlayerState.money, int(PlayerState.energy), int(PlayerState.max_energy)])


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false


func _set_status(text: String) -> void:
	_status_label.text = text


func _section_header(text: String) -> Label:
	return UIKit.make_label(text, 16, UIKit.C_GOLD)


func _missing_label(autoload_name: String) -> Label:
	return UIKit.make_label("%s not registered - see Project Settings > Autoload" % autoload_name, 13, UIKit.C_MUTED)


func _make_spinbox(min_value: float, max_value: float, default_value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = min_value
	spin.max_value = max_value
	spin.value = default_value
	spin.custom_minimum_size = Vector2(80, 0)
	return spin


## ---- Time ----------------------------------------------------------------

func _build_time_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Time"))

	var advance_row := UIKit.make_hbox(8)
	_advance_days_spin = _make_spinbox(1, ADVANCE_DAYS_MAX, 1)
	advance_row.add_child(_advance_days_spin)
	var advance_button := UIKit.make_button("Advance Day(s) (full cascade)")
	advance_button.pressed.connect(_on_advance_days_pressed)
	advance_row.add_child(advance_button)
	box.add_child(advance_row)

	var jump_row := UIKit.make_hbox(8)
	_jump_day_spin = _make_spinbox(1, float(GameData.time_cfg.get("days_per_season", 28)), TimeManager.day)
	jump_row.add_child(_jump_day_spin)
	var jump_button := UIKit.make_button("Jump to Day (no cascade)")
	jump_button.pressed.connect(_on_jump_day_pressed)
	jump_row.add_child(jump_button)
	box.add_child(jump_row)

	var hour_row := UIKit.make_hbox(8)
	_set_hour_spin = _make_spinbox(0, 23, TimeManager.hour)
	hour_row.add_child(_set_hour_spin)
	var hour_button := UIKit.make_button("Set Hour")
	hour_button.pressed.connect(_on_set_hour_pressed)
	hour_row.add_child(hour_button)
	box.add_child(hour_row)

	return box


func _on_advance_days_pressed() -> void:
	var count := int(_advance_days_spin.value)
	for _i in range(count):
		PlayerState.sleep_restore()
		TimeManager.sleep_to_next_day()
	_set_status("Advanced %d day(s) - now Day %d of %s, Year %d" % [
		count, TimeManager.day, TimeManager.season.capitalize(), TimeManager.year])


func _on_jump_day_pressed() -> void:
	TimeManager.day = int(_jump_day_spin.value)
	_set_status("Day set to %d (no growth/tithe/etc. cascade ran)" % TimeManager.day)


func _on_set_hour_pressed() -> void:
	TimeManager.hour = int(_set_hour_spin.value)
	TimeManager.minute = 0
	_set_status("Hour set to %02d:00" % TimeManager.hour)


## ---- Weather ---------------------------------------------------------------

func _build_weather_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Weather"))
	var row := UIKit.make_hbox(8)
	for weather_id: String in ["sunny", "rain", "overcast", "snow"]:
		var button := UIKit.make_button(weather_id.capitalize())
		button.pressed.connect(_on_force_weather.bind(weather_id))
		row.add_child(button)
	box.add_child(row)
	return box


func _on_force_weather(weather_id: String) -> void:
	WeatherManager.force_weather(weather_id)
	_set_status("Weather forced to %s" % weather_id)


## ---- Economy ----------------------------------------------------------------

func _build_economy_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Economy"))
	var row := UIKit.make_hbox(8)
	var add_100 := UIKit.make_button("+100 Coin")
	add_100.pressed.connect(_on_add_money.bind(100))
	row.add_child(add_100)
	var add_1000 := UIKit.make_button("+1000 Coin")
	add_1000.pressed.connect(_on_add_money.bind(1000))
	row.add_child(add_1000)
	box.add_child(row)

	var set_row := UIKit.make_hbox(8)
	_set_money_spin = _make_spinbox(0, 999999, PlayerState.money)
	set_row.add_child(_set_money_spin)
	var set_button := UIKit.make_button("Set Money To")
	set_button.pressed.connect(_on_set_money_pressed)
	set_row.add_child(set_button)
	box.add_child(set_row)
	return box


func _on_add_money(amount: int) -> void:
	PlayerState.add_money(amount)
	_set_status("Added %d coin - now %d" % [amount, PlayerState.money])


func _on_set_money_pressed() -> void:
	var target := int(_set_money_spin.value)
	PlayerState.add_money(target - PlayerState.money)
	_set_status("Money set to %d" % PlayerState.money)


## ---- Player vitals -----------------------------------------------------------

func _build_player_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Player"))
	var row := UIKit.make_hbox(8)
	var energy_button := UIKit.make_button("Full Energy")
	energy_button.pressed.connect(func() -> void:
		PlayerState.restore_energy(PlayerState.max_energy)
		_set_status("Energy restored to %d" % int(PlayerState.energy)))
	row.add_child(energy_button)
	var health_button := UIKit.make_button("Full Health")
	health_button.pressed.connect(func() -> void:
		PlayerState.heal(PlayerState.max_health)
		_set_status("Health restored to %d" % PlayerState.health))
	row.add_child(health_button)
	var wound_button := UIKit.make_button("Clear Wound")
	wound_button.pressed.connect(func() -> void:
		PlayerState.wound_days_remaining = 0
		_set_status("Wound cleared"))
	row.add_child(wound_button)
	box.add_child(row)
	return box


## ---- Inventory ---------------------------------------------------------------

func _build_inventory_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Inventory"))

	var kit_button := UIKit.make_button("Give Starter Kit (seeds, materials, tools, weapons, coin)", false, true)
	kit_button.pressed.connect(_on_give_starter_kit)
	box.add_child(kit_button)

	var give_row := UIKit.make_hbox(8)
	_item_dropdown = OptionButton.new()
	var item_ids := GameData.get_all_item_ids()
	item_ids.sort()
	for item_id: String in item_ids:
		_item_dropdown.add_item(item_id)
	give_row.add_child(_item_dropdown)
	_quality_dropdown = OptionButton.new()
	for quality: String in ["common", "fine", "choice"]:
		_quality_dropdown.add_item(quality)
	give_row.add_child(_quality_dropdown)
	_give_qty_spin = _make_spinbox(1, GIVE_QTY_MAX, 10)
	give_row.add_child(_give_qty_spin)
	var give_button := UIKit.make_button("Give")
	give_button.pressed.connect(_on_give_item_pressed)
	give_row.add_child(give_button)
	box.add_child(give_row)
	return box


func _on_give_starter_kit() -> void:
	PlayerState.add_money(1000)
	PlayerState.add_item("turnip_seed", 10)
	PlayerState.add_item("barley_seed", 10)
	PlayerState.add_item("cabbage_seed", 10)
	PlayerState.add_item("wood", 40)
	PlayerState.add_item("flint", 40)
	PlayerState.add_item("hoe_iron", 1)
	PlayerState.add_item("can_iron", 1)
	PlayerState.add_item("spear", 1)
	PlayerState.add_item("bow", 1)
	PlayerState.add_item("arrow", 20)
	PlayerState.add_item("guard_dog", 1)
	PlayerState.add_item("hired_guard", 1)
	_set_status("Starter kit given")


func _on_give_item_pressed() -> void:
	if _item_dropdown.get_item_count() == 0:
		return
	var item_id := _item_dropdown.get_item_text(_item_dropdown.selected)
	var quality := _quality_dropdown.get_item_text(_quality_dropdown.selected)
	var qty := int(_give_qty_spin.value)
	PlayerState.add_item(item_id, qty, quality)
	_set_status("Gave %d x %s (%s)" % [qty, item_id, quality])


## ---- Skills --------------------------------------------------------------

func _build_skills_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Skills"))
	if _skill_mgr == null:
		box.add_child(_missing_label("SkillManager"))
		return box
	var row := UIKit.make_hbox(8)
	for skill_id: String in SKILL_IDS:
		var button := UIKit.make_button("+1000 XP %s" % skill_id.capitalize())
		button.pressed.connect(_on_add_xp.bind(skill_id))
		row.add_child(button)
	box.add_child(row)
	var max_button := UIKit.make_button("Max All Skills")
	max_button.pressed.connect(_on_max_all_skills)
	box.add_child(max_button)
	return box


func _on_add_xp(skill_id: String) -> void:
	_skill_mgr.add_xp(skill_id, 1000.0)
	_set_status("%s: level %d" % [skill_id.capitalize(), _skill_mgr.get_level(skill_id)])


func _on_max_all_skills() -> void:
	for skill_id: String in SKILL_IDS:
		_skill_mgr.add_xp(skill_id, 1000000.0)
	_set_status("All skills maxed")


## ---- Reputation ------------------------------------------------------------

func _build_reputation_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Reputation"))
	for axis: String in REPUTATION_AXES:
		var row := UIKit.make_hbox(8)
		row.add_child(UIKit.make_label(axis.capitalize(), 14))
		var plus_button := UIKit.make_button("+20")
		plus_button.pressed.connect(_on_modify_standing.bind(axis, 20.0))
		row.add_child(plus_button)
		var minus_button := UIKit.make_button("-20")
		minus_button.pressed.connect(_on_modify_standing.bind(axis, -20.0))
		row.add_child(minus_button)
		box.add_child(row)
	var reset_button := UIKit.make_button("Reset All Standings + Opinions to Neutral")
	reset_button.pressed.connect(func() -> void:
		ReputationManager.reset_all()
		_set_status("Reputation reset to neutral"))
	box.add_child(reset_button)
	var mass_button := UIKit.make_button("Force Attend Mass (attend_mass reputation action)")
	mass_button.pressed.connect(func() -> void:
		ReputationManager.apply_action("attend_mass")
		_set_status("attend_mass applied"))
	box.add_child(mass_button)
	var gift_cap_button := UIKit.make_button("Reset Daily Gift Cap")
	gift_cap_button.pressed.connect(func() -> void:
		ReputationManager.reset_daily_gift_cap()
		_set_status("Daily gift cap reset"))
	box.add_child(gift_cap_button)
	return box


func _on_modify_standing(axis: String, amount: float) -> void:
	ReputationManager.modify_standing(axis, amount)
	_set_status("%s standing: %d" % [axis.capitalize(), int(ReputationManager.get_standing(axis))])


## ---- Raids, combat, investigation ---------------------------------------------

func _build_raid_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Raids & Combat"))
	var row := UIKit.make_hbox(8)
	var scripted_button := UIKit.make_button("Trigger Scripted Raid")
	scripted_button.pressed.connect(func() -> void:
		RaidManager.execute_raid()
		_set_status("Scripted raid triggered"))
	row.add_child(scripted_button)
	var dynamic_button := UIKit.make_button("Trigger Dynamic Raid")
	dynamic_button.pressed.connect(func() -> void:
		RaidManager.execute_dynamic_raid()
		_set_status("Dynamic raid triggered"))
	row.add_child(dynamic_button)
	var theft_button := UIKit.make_button("Trigger Theft Event")
	theft_button.pressed.connect(func() -> void:
		RaidManager.execute_theft()
		_set_status("Theft event triggered"))
	row.add_child(theft_button)
	box.add_child(row)

	var deterrence_row := UIKit.make_hbox(8)
	var zero_button := UIKit.make_button("Deterrence -> 0")
	zero_button.pressed.connect(func() -> void:
		PlayerState.raid_deterrence = 0
		_set_status("Deterrence set to 0 (effective: %d)" % RaidManager.get_effective_deterrence()))
	deterrence_row.add_child(zero_button)
	var max_button := UIKit.make_button("Deterrence -> 100")
	max_button.pressed.connect(func() -> void:
		PlayerState.raid_deterrence = 100
		_set_status("Deterrence set to 100 (effective: %d)" % RaidManager.get_effective_deterrence()))
	deterrence_row.add_child(max_button)
	box.add_child(deterrence_row)
	return box


func _build_investigation_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Thief Investigation"))
	if _investigation_mgr == null:
		box.add_child(_missing_label("InvestigationManager"))
		return box
	var reveal_button := UIKit.make_button("Reveal All Clues", false, true)
	reveal_button.pressed.connect(_on_reveal_all_clues)
	box.add_child(reveal_button)
	return box


func _on_reveal_all_clues() -> void:
	var revealed := 0
	while _investigation_mgr.can_accuse():
		var clue: Dictionary = _investigation_mgr.reveal_clue_for("debug")
		if clue.is_empty():
			break
		revealed += 1
	if revealed > 0:
		_set_status("Revealed %d clue(s)" % revealed)
	else:
		_set_status("No investigation open, or all clues already revealed")


## ---- Marriage ---------------------------------------------------------------

func _build_marriage_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Marriage"))
	if _marriage_mgr == null:
		box.add_child(_missing_label("MarriageManager"))
		return box

	var candidates: Array[String] = GameData.get_marriage_candidates()
	_marriage_candidate_dropdown = OptionButton.new()
	for candidate_id: String in candidates:
		_marriage_candidate_dropdown.add_item(candidate_id)
	box.add_child(_marriage_candidate_dropdown)

	var one_shot := UIKit.make_button(
		"Marry Selected Candidate Now (max opinion + ring + propose + merchet + ceremony)",
		false, true)
	one_shot.pressed.connect(_on_marry_selected_now)
	box.add_child(one_shot)

	var step_row_1 := UIKit.make_hbox(8)
	var opinion_button := UIKit.make_button("Max Opinion With Selected")
	opinion_button.pressed.connect(_on_max_opinion_selected)
	step_row_1.add_child(opinion_button)
	var ring_button := UIKit.make_button("Give Betrothal Ring")
	ring_button.pressed.connect(func() -> void:
		PlayerState.add_item("betrothal_ring", 1)
		_set_status("Gave 1x betrothal_ring"))
	step_row_1.add_child(ring_button)
	box.add_child(step_row_1)

	var step_row_2 := UIKit.make_hbox(8)
	var propose_button := UIKit.make_button("Propose To Selected")
	propose_button.pressed.connect(_on_propose_selected)
	step_row_2.add_child(propose_button)
	var merchet_button := UIKit.make_button("Pay Merchet")
	merchet_button.pressed.connect(func() -> void:
		_set_status("Merchet paid" if _marriage_mgr.pay_merchet() else "Cannot pay merchet right now"))
	step_row_2.add_child(merchet_button)
	var ceremony_button := UIKit.make_button("Ceremonize")
	ceremony_button.pressed.connect(func() -> void:
		_set_status("Ceremony complete - spouse: %s" % _marriage_mgr.get_spouse_id()
			if _marriage_mgr.ceremonize() else "Cannot ceremonize right now"))
	step_row_2.add_child(ceremony_button)
	box.add_child(step_row_2)

	var chore_button := UIKit.make_button("Force Complete Spouse Chore")
	chore_button.pressed.connect(func() -> void:
		_set_status("Spouse chore completed" if _marriage_mgr.complete_chore() else "No spouse, or nothing to do")
	)
	box.add_child(chore_button)

	return box


func _selected_marriage_candidate() -> String:
	if _marriage_candidate_dropdown.get_item_count() == 0:
		return ""
	return _marriage_candidate_dropdown.get_item_text(_marriage_candidate_dropdown.selected)


func _on_max_opinion_selected() -> void:
	var candidate_id := _selected_marriage_candidate()
	if candidate_id.is_empty():
		return
	ReputationManager.modify_opinion(candidate_id, 1000.0)
	_set_status("%s opinion: %d" % [candidate_id, int(ReputationManager.get_opinion(candidate_id))])


func _on_propose_selected() -> void:
	var candidate_id := _selected_marriage_candidate()
	if candidate_id.is_empty():
		return
	_set_status("Proposed to %s" % candidate_id if _marriage_mgr.propose(candidate_id)
		else "Cannot propose to %s right now (needs max opinion + a betrothal ring)" % candidate_id)


## Drives the whole proposal -> merchet -> ceremony chain for the selected
## candidate in one click - the fast path this section exists for. Each step
## still uses the manager's own gating (can_propose/can_pay_merchet/
## can_ceremonize), so this can never put the state machine somewhere the
## normal game flow couldn't also reach.
func _on_marry_selected_now() -> void:
	var candidate_id := _selected_marriage_candidate()
	if candidate_id.is_empty():
		_set_status("No marriage candidates in villagers.json")
		return
	ReputationManager.modify_opinion(candidate_id, 1000.0)
	if not PlayerState.has_item("betrothal_ring", 1):
		PlayerState.add_item("betrothal_ring", 1)
	if not _marriage_mgr.propose(candidate_id):
		_set_status("Stopped at propose() for %s - already married or already pending?" % candidate_id)
		return
	var fee: int = _marriage_mgr.get_merchet_fee()
	if int(PlayerState.money) < fee:
		PlayerState.add_money(fee - int(PlayerState.money))
	if not _marriage_mgr.pay_merchet():
		_set_status("Stopped at pay_merchet() for %s - insufficient coin?" % candidate_id)
		return
	if not _marriage_mgr.ceremonize():
		_set_status("Stopped at ceremonize() for %s" % candidate_id)
		return
	_set_status("Married %s." % candidate_id)


## ---- Buildings & crafting --------------------------------------------------

func _build_building_crafting_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Buildings & Crafting"))
	if _building_mgr == null:
		box.add_child(_missing_label("BuildingManager"))
	else:
		var complete_button := UIKit.make_button("Force-Complete All Constructions", false, true)
		complete_button.pressed.connect(func() -> void:
			_building_mgr.force_complete_all()
			_set_status("All in-progress constructions completed"))
		box.add_child(complete_button)
	if _crafting_mgr == null:
		box.add_child(_missing_label("CraftingManager"))
	else:
		var finish_button := UIKit.make_button("Finish All Pending Crafts", false, true)
		finish_button.pressed.connect(func() -> void:
			_crafting_mgr.force_finish_all()
			_set_status("All pending crafts finished"))
		box.add_child(finish_button)
	if _animal_mgr == null:
		box.add_child(_missing_label("AnimalManager"))
	return box


## ---- Save ------------------------------------------------------------------

func _build_save_section() -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	box.add_child(_section_header("Save"))
	var row := UIKit.make_hbox(8)
	var save_button := UIKit.make_button("Quick Save (autosave slot)")
	save_button.pressed.connect(func() -> void:
		SaveManager.save_game("autosave")
		_set_status("Saved to autosave slot"))
	row.add_child(save_button)
	var load_button := UIKit.make_button("Quick Load (autosave slot)")
	load_button.pressed.connect(func() -> void:
		SaveManager.load_game("autosave")
		_set_status("Loaded from autosave slot"))
	row.add_child(load_button)
	box.add_child(row)
	return box
