class_name ShopPanel
extends CanvasLayer

## Manor market stall: buy from the stall inventory, sell owned crop stacks.
## Opened on the market_zone interaction, only while the market is open.

const MENU_ID := "shop"
const LAYER := 10

var _buy_box: VBoxContainer
var _sell_box: VBoxContainer
var _black_header: Label
var _black_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Manor Market", 24))
	frame.add_child(UIKit.make_label("Buy"))
	_buy_box = UIKit.make_vbox(2)
	frame.add_child(_buy_box)
	frame.add_child(UIKit.make_label("Sell"))
	_sell_box = UIKit.make_vbox(2)
	frame.add_child(_sell_box)
	_black_header = UIKit.make_label("Black Market (no toll)")
	_black_header.visible = false
	frame.add_child(_black_header)
	_black_box = UIKit.make_vbox(2)
	_black_box.visible = false
	frame.add_child(_black_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.inventory_changed.connect(_refresh)
	PlayerState.money_changed.connect(func(_amount: int) -> void:
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
	for child: Node in _buy_box.get_children():
		child.queue_free()
	for child: Node in _sell_box.get_children():
		child.queue_free()
	for child: Node in _black_box.get_children():
		child.queue_free()
	var black_open := TitheManager.is_black_market_open()
	_black_header.visible = black_open
	_black_box.visible = black_open
	for entry: Dictionary in GameData.get_stall_inventory():
		_buy_box.add_child(_build_buy_row(str(entry.get("item_id", ""))))
	for entry: Variant in PlayerState.list_inventory():
		var stack := entry as Dictionary
		var item_id := str(stack.get("item_id", ""))
		if GameData.get_market_buy_price(item_id) < 0:
			continue
		_sell_box.add_child(_build_sell_row(stack))
	if black_open:
		for entry: Variant in PlayerState.list_inventory():
			var stack := entry as Dictionary
			var item_id := str(stack.get("item_id", ""))
			if GameData.get_market_buy_price(item_id) < 0:
				continue
			_black_box.add_child(_build_black_row(stack))


func _build_buy_row(item_id: String) -> HBoxContainer:
	var item := GameData.get_item(item_id)
	var price := TitheManager.get_buy_price(item_id, 1)
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label("%s - %d coin" % [str(item.get("name", item_id)), price]))
	var buy_button := UIKit.make_button("Buy")
	buy_button.disabled = not TitheManager.can_buy(item_id, 1)
	buy_button.pressed.connect(func() -> void:
		TitheManager.buy_item(item_id, 1))
	row.add_child(buy_button)
	return row


func _build_sell_row(stack: Dictionary) -> HBoxContainer:
	var item_id := str(stack.get("item_id", ""))
	var quality := str(stack.get("quality", "common"))
	var count := int(stack.get("count", 0))
	var item := GameData.get_item(item_id)
	var net := TitheManager.get_sell_price(item_id, count, quality)
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label("%s (%s) x%d - %d coin" % [
		str(item.get("name", item_id)), quality, count, net]))
	var sell_button := UIKit.make_button("Sell All")
	sell_button.pressed.connect(func() -> void:
		TitheManager.sell_crop(item_id, count, quality))
	row.add_child(sell_button)
	return row


func _build_black_row(stack: Dictionary) -> HBoxContainer:
	var item_id := str(stack.get("item_id", ""))
	var quality := str(stack.get("quality", "common"))
	var count := int(stack.get("count", 0))
	var item := GameData.get_item(item_id)
	var net := TitheManager.get_black_market_price(item_id, count, quality)
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label("%s (%s) x%d - %d coin, no toll" % [
		str(item.get("name", item_id)), quality, count, net]))
	var sell_button := UIKit.make_button("Sell All")
	sell_button.disabled = not TitheManager.can_black_market_sell(item_id, count, quality)
	sell_button.pressed.connect(func() -> void:
		TitheManager.black_market_sell(item_id, count, quality))
	row.add_child(sell_button)
	return row
