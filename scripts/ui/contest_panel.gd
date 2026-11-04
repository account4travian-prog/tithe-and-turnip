class_name ContestPanel
extends CanvasLayer

## Festival contests (world_bible.md Section V): opened on the active
## festival's anchor tile during its window. Offers direct entry (the timed
## press-race UI) and/or cheer-with-optional-bet for the festival's named
## entrants. Participation is one-shot per festival occurrence through
## PlayerState.event_flags ("festival.contest_entered_<id>" /
## "festival.contest_cheered_<id>"), so the panel owns no persistence and
## no SAVE_VERSION bump is needed.
##
## The race runs in FestivalManager._physics_process (the Tick Rule). This
## panel only polls get_race_state() in _process for rendering, and sends
## presses through the Press button - gameplay state is never mutated from
## _process here. Unreachable-season contests (Summer lifting, Autumn
## sheaf-tying stub, Winter storytelling) render from the same data path;
## only Spring's Furrow Race is reachable in the vertical slice.

const MENU_ID := "contest"
const LAYER := 15

var _content_box: VBoxContainer
var _money_label: Label
var _message_label: Label
var _festival_id := ""
var _race_was_active := false
var _race_status_label: Label
var _race_bar: ProgressBar
var _race_press_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(6)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Festival Contests", 24))
	_money_label = UIKit.make_label("", 15, UIKit.C_INK_SOFT)
	frame.add_child(_money_label)
	_message_label = UIKit.make_label("", 15, UIKit.C_GOLD)
	frame.add_child(_message_label)
	_content_box = UIKit.make_vbox(4)
	frame.add_child(_content_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.money_changed.connect(func(_amount: int) -> void:
		_refresh_money())


func _process(_delta: float) -> void:
	if not visible:
		return
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager == null or not festival_manager.has_method("get_race_state"):
		return
	var state: Dictionary = festival_manager.get_race_state()
	var active := bool(state.get("active", false))
	if active:
		_race_was_active = true
		_update_race_ui(state)
	elif _race_was_active:
		_race_was_active = false
		var result: Dictionary = state.get("result", {})
		if result.is_empty():
			_refresh()
		else:
			_show_race_result(result)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_race_was_active = false
		_refresh_money()
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false
		_race_was_active = false
		var festival_manager := get_node_or_null("/root/FestivalManager")
		if festival_manager != null and festival_manager.has_method("is_race_active") \
				and festival_manager.is_race_active():
			# An externally-closed panel (pause/inventory hotkeys) must not
			# leave a race ticking with no way to press; abandoning keeps the
			# one-shot flag, so it is never a free replay.
			festival_manager.cancel_race()


func _refresh() -> void:
	if not visible:
		return
	for child: Node in _content_box.get_children():
		child.queue_free()
	_race_status_label = null
	_race_bar = null
	_race_press_button = null
	var festival_manager := get_node_or_null("/root/FestivalManager")
	if festival_manager == null or not festival_manager.has_method("get_active_contest"):
		_content_box.add_child(UIKit.make_label("The festival is over."))
		return
	var festival: Dictionary = festival_manager.get_active_festival()
	var contest: Dictionary = festival_manager.get_active_contest()
	if festival.is_empty() or contest.is_empty():
		_content_box.add_child(UIKit.make_label("No contest is open right now."))
		return
	_festival_id = str(festival.get("id", ""))
	var festival_name := str(festival.get("name", _festival_id))
	var contest_name := str(contest.get("name", "Contest"))
	_content_box.add_child(UIKit.make_label(
		"%s - %s" % [festival_name, contest_name], 20))
	_build_direct_entry_section(festival_manager, contest)
	_build_cheer_section(festival_manager, contest)


func _build_direct_entry_section(festival_manager: Node, contest: Dictionary) -> void:
	if not bool(contest.get("has_direct_entry", false)):
		_content_box.add_child(UIKit.make_label(
			"No direct entry at this contest.", 15, UIKit.C_INK_SOFT))
		if contest.has("note"):
			_content_box.add_child(UIKit.make_label(
				str(contest.get("note", "")), 14, UIKit.C_INK_SOFT))
		return
	var entered_flag := "festival.contest_entered_%s" % _festival_id
	if PlayerState.has_event_flag(entered_flag):
		if festival_manager.is_race_active():
			_build_race_ui(festival_manager, contest)
		else:
			_content_box.add_child(UIKit.make_label(
				"You already entered the %s at this festival." % str(contest.get("name", "contest")),
				15, UIKit.C_INK_SOFT))
		return
	var row := UIKit.make_hbox(8)
	row.add_child(UIKit.make_label("Enter the %s (tests %s)" % [
		str(contest.get("name", "contest")), str(contest.get("skill_id", "farming"))]))
	var enter_button := UIKit.make_button("Enter")
	enter_button.pressed.connect(func() -> void:
		var result: Dictionary = festival_manager.start_contest(_festival_id)
		if bool(result.get("ok", false)):
			_message_label.text = "The contest begins - watch for the prompt!"
			_refresh()
		else:
			_message_label.text = "You cannot enter right now.")
	row.add_child(enter_button)
	_content_box.add_child(row)


func _build_race_ui(festival_manager: Node, _contest: Dictionary) -> void:
	_race_status_label = UIKit.make_label("The contest begins...", 17, UIKit.C_INK)
	_content_box.add_child(_race_status_label)
	_race_bar = UIKit.make_bar(0.0, UIKit.C_GOLD, 360, 14)
	_content_box.add_child(_race_bar)
	_race_press_button = UIKit.make_button("Press!")
	_race_press_button.pressed.connect(func() -> void:
		var scored: bool = festival_manager.press_race()
		_message_label.text = "A clean strike!" if scored else "No furrow scored.")
	_content_box.add_child(_race_press_button)


func _update_race_ui(state: Dictionary) -> void:
	if _race_status_label == null or not is_instance_valid(_race_status_label):
		return
	var beat_count := int(state.get("beat_count", 0))
	var next_beat := int(state.get("beat_index", 0))
	var active_beat := int(state.get("active_beat", -1))
	var successes := int(state.get("successes", 0))
	if next_beat >= beat_count:
		_race_status_label.text = "The team has passed..."
	else:
		var beat_text := "Prompt %d of %d - %d straight" % [
			next_beat + 1, beat_count, successes]
		if active_beat >= next_beat:
			_race_status_label.text = beat_text + " - PRESS NOW!"
		else:
			_race_status_label.text = beat_text + " - wait..."
	if _race_bar != null and is_instance_valid(_race_bar):
		_race_bar.value = float(state.get("window_fraction", 0.0)) * 100.0


func _show_race_result(result: Dictionary) -> void:
	if _race_status_label != null and is_instance_valid(_race_status_label):
		_race_status_label.text = "Race done: %d straight - %+d coin" % [
			int(result.get("successes", 0)), int(result.get("payout", 0))]
	if _race_press_button != null and is_instance_valid(_race_press_button):
		_race_press_button.disabled = true
	_message_label.text = "The village applauds your furrow."


func _build_cheer_section(festival_manager: Node, contest: Dictionary) -> void:
	if not bool(contest.get("has_cheer", false)):
		_content_box.add_child(UIKit.make_label(
			"No cheering at this contest yet.", 15, UIKit.C_INK_SOFT))
		return
	var cheered_flag := "festival.contest_cheered_%s" % _festival_id
	if PlayerState.has_event_flag(cheered_flag):
		_content_box.add_child(UIKit.make_label(
			"You already cheered at this festival.", 15, UIKit.C_INK_SOFT))
		return
	var has_bet := bool(contest.get("has_bet", false))
	var bet_cfg: Dictionary = contest.get("bet", {})
	var min_bet := int(bet_cfg.get("min", 0))
	var max_bet := int(bet_cfg.get("max", 0))
	_content_box.add_child(UIKit.make_label("Cheer for a contender:", 16, UIKit.C_INK))
	var entrants: Array = contest.get("entrants", [])
	for entrant_id: Variant in entrants:
		var id_str := str(entrant_id)
		var villager: Dictionary = GameData.get_villager(id_str)
		var name := str(villager.get("name", id_str))
		var row := UIKit.make_hbox(8)
		row.add_child(UIKit.make_label(name))
		var bet_spin: SpinBox = null
		if has_bet and max_bet > min_bet:
			bet_spin = SpinBox.new()
			bet_spin.min_value = min_bet
			bet_spin.max_value = max_bet
			bet_spin.value = min_bet
			bet_spin.step = 1
			bet_spin.custom_minimum_size = Vector2(70, 0)
			row.add_child(bet_spin)
		var cheer_button := UIKit.make_button("Cheer")
		cheer_button.pressed.connect(func() -> void:
			var bet := min_bet
			if bet_spin != null:
				bet = int(bet_spin.value)
			var result: Dictionary = festival_manager.cheer(_festival_id, id_str, bet)
			if not bool(result.get("ok", false)):
				_message_label.text = "You cannot cheer right now."
				return
			if bool(result.get("win", false)):
				_message_label.text = "%s wins! You collect %d coin." % [
					name, int(result.get("payout", 0))]
			else:
				_message_label.text = "%s did not win. The bet is lost." % name
			_refresh())
		row.add_child(cheer_button)
		_content_box.add_child(row)


func _refresh_money() -> void:
	if not visible:
		return
	_money_label.text = "You have %d coin" % PlayerState.money
