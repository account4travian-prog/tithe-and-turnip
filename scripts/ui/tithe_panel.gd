class_name TithePanel
extends CanvasLayer

## Lord tithe: pay coin, deposit crops, or review the steward's demesne
## chores. Opened on the stewards_demesne interaction (bare hands with no
## spatial chore available - ADR-040).
## ADR-040: the chores view is a status board, not a menu of "Do" buttons -
## till/water/harvest/carry are performed spatially on the demesne with the
## right tool or bare hands, and this panel tells the player what to do and
## whether it is available right now.

const MENU_ID := "tithe"
const LAYER := 10
const COIN_STEPS: Array[int] = [5, 10, 25]

var _content_box: VBoxContainer
var _showing_chores := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Lord's Tithe", 24))
	_content_box = UIKit.make_vbox(2)
	frame.add_child(_content_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.inventory_changed.connect(_refresh)
	PlayerState.money_changed.connect(func(_amount: int) -> void:
		_refresh())
	TitheManager.tithe_updated.connect(func(_paid: float, _goal: int) -> void:
		_refresh())
	# ADR-040: sheaf stockpile / carry state changes refresh the chores board.
	TitheManager.demesne_status_changed.connect(_refresh)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_showing_chores = false
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false


func _refresh() -> void:
	if not visible:
		return
	for child: Node in _content_box.get_children():
		child.queue_free()
	var progress := TitheManager.get_tithe_progress()
	_content_box.add_child(UIKit.make_label(
		"Progress: %d / %d" % [int(progress.get("paid", 0.0)), int(progress.get("goal", 0))]))
	if _showing_chores:
		_build_chores_view()
	else:
		_build_main_view()


func _build_main_view() -> void:
	for amount: int in COIN_STEPS:
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("Pay %d coin" % amount))
		var pay_button := UIKit.make_button("Pay")
		pay_button.disabled = not TitheManager.can_pay_tithe_coin(amount)
		pay_button.pressed.connect(func() -> void:
			TitheManager.pay_tithe_coin(amount))
		row.add_child(pay_button)
		_content_box.add_child(row)
	for entry: Variant in PlayerState.list_inventory():
		var stack := entry as Dictionary
		var item_id := str(stack.get("item_id", ""))
		if GameData.get_market_buy_price(item_id) < 0:
			continue
		var quality := str(stack.get("quality", "common"))
		var count := int(stack.get("count", 0))
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("Deposit %s (%s) x%d" % [
			str(GameData.get_item(item_id).get("name", item_id)), quality, count]))
		var deposit_button := UIKit.make_button("Deposit")
		deposit_button.pressed.connect(func() -> void:
			TitheManager.deposit_tithe_crops(item_id, count, quality))
		row.add_child(deposit_button)
		_content_box.add_child(row)
	var chores_button := UIKit.make_button("Work Chores")
	chores_button.pressed.connect(func() -> void:
		_showing_chores = true
		_refresh())
	_content_box.add_child(chores_button)


## ADR-040: status/instruction rows, not action buttons - the player must
## walk to the demesne and perform each chore spatially. Rows carry the
## chore's listed energy/credit, a what-to-do instruction, and a live
## ready/waiting tag from can_do_chore; harvest and carry also show the
## stockpile and carry state.
func _build_chores_view() -> void:
	_content_box.add_child(UIKit.make_label(
		"Labor remaining today: %d" % int(TitheManager.get_daily_labor_remaining())))
	var status: Dictionary = TitheManager.get_demesne_status()
	var rows: Array[Array] = [
		["till_demesne", "Till an untilled demesne tile with your hoe"],
		["water_demesne", "Water a dry tilled demesne tile with your watering can"],
		["harvest_demesne", "Clear stored sheaves at the demesne (%d ready)" % int(status.get("sheaves_available", 0))],
		["carry_produce", "Carry sheaves to the Lord's Tithe chest (carrying: %d)" % int(status.get("carrying_sheaves", 0))],
	]
	for row: Array in rows:
		var chore_id := str(row[0])
		var chore := GameData.get_chore(chore_id)
		var row_box := HBoxContainer.new()
		row_box.add_child(UIKit.make_label("%s (%d energy / +%d credit)" % [
			str(chore.get("name", chore_id)), int(chore.get("energy_cost", 0)), int(chore.get("credit", 0))]))
		row_box.add_child(UIKit.make_label(" - %s" % str(row[1])))
		row_box.add_child(UIKit.make_label(
			" [%s]" % ("ready" if TitheManager.can_do_chore(chore_id) else "waiting")))
		_content_box.add_child(row_box)
	var back_button := UIKit.make_button("Back")
	back_button.pressed.connect(func() -> void:
		_showing_chores = false
		_refresh())
	_content_box.add_child(back_button)
