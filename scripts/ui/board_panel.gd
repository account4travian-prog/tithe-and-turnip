class_name BoardPanel
extends CanvasLayer

## Town notice board (E6/ADR-037): lists the active board orders and lets the
## player fulfill any order they hold the goods for. Orders are generated on
## market days by TitheManager and persist until their deadline; fulfilling
## deducts inventory across any quality mix, grants coin + optional standing,
## and removes the order. Opened via UIManager.open_menu("board") on the
## town_board feature tile - the same panel pattern as every other menu.

const MENU_ID := "board"
const LAYER := 10

var _rows_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Town Board", 24))
	_rows_box = UIKit.make_vbox(2)
	frame.add_child(_rows_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.inventory_changed.connect(_refresh)
	TitheManager.order_fulfilled.connect(func(_order_id: String, _reward: int) -> void:
		_refresh())


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false


func _refresh() -> void:
	if not visible:
		return
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var orders := TitheManager.get_active_orders()
	if orders.is_empty():
		_rows_box.add_child(UIKit.make_label("(no orders posted)"))
		return
	for order: Dictionary in orders:
		_rows_box.add_child(_build_row(order))


func _build_row(order: Dictionary) -> HBoxContainer:
	var crop_id := str(order.get("crop_id", ""))
	var quantity := int(order.get("quantity", 0))
	var reward := int(order.get("reward_money", 0))
	var deadline := int(order.get("deadline_day", 0))
	var axis := str(order.get("reward_standing", ""))
	var amount := int(order.get("standing_amount", 0))
	var crop := GameData.get_crop(crop_id)
	# E6/ADR-037 display: count-aware produce phrasing ("Deliver a basket of
	# turnips" / "Deliver 4 baskets of turnips"). Unknown crops fall back to
	# the raw count so the row never invents text.
	var produce_text := GameData.format_produce_count(crop_id, quantity)
	var label_text := ""
	if produce_text.is_empty():
		label_text = "Deliver %d %s by Day %d - %d coin" % [
			quantity, str(crop.get("name", crop_id)), deadline, reward]
	else:
		label_text = "Deliver %s by Day %d - %d coin" % [
			produce_text, deadline, reward]
	if not axis.is_empty() and amount != 0:
		label_text += " (+%d %s)" % [amount, axis]
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label(label_text))
	var order_id := str(order.get("id", ""))
	var deliver_button := UIKit.make_button("Deliver")
	deliver_button.disabled = not TitheManager.can_fulfill_order(order_id)
	deliver_button.pressed.connect(func() -> void:
		TitheManager.fulfill_order(order_id))
	row.add_child(deliver_button)
	return row
