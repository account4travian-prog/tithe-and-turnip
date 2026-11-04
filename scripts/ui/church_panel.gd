class_name ChurchPanel
extends CanvasLayer

## Chapel tithe box: voluntary coin/crop donations. Opened on the chapel
## interaction.

const MENU_ID := "church"
const LAYER := 10
const COIN_STEPS: Array[int] = [3, 5, 10]

var _content_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Chapel Tithe Box", 24))
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
	for child: Node in _content_box.get_children():
		child.queue_free()
	for amount: int in COIN_STEPS:
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("Donate %d coin" % amount))
		var donate_button := UIKit.make_button("Donate")
		donate_button.disabled = not TitheManager.can_donate_coin(amount)
		donate_button.pressed.connect(func() -> void:
			TitheManager.donate_coin(amount))
		row.add_child(donate_button)
		_content_box.add_child(row)
	for entry: Variant in PlayerState.list_inventory():
		var stack := entry as Dictionary
		var item_id := str(stack.get("item_id", ""))
		if GameData.get_market_buy_price(item_id) < 0:
			continue
		var quality := str(stack.get("quality", "common"))
		var count := int(stack.get("count", 0))
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("Donate %s (%s) x%d" % [
			str(GameData.get_item(item_id).get("name", item_id)), quality, count]))
		var donate_crop_button := UIKit.make_button("Donate")
		donate_crop_button.pressed.connect(func() -> void:
			TitheManager.donate_crops(item_id, count, quality))
		row.add_child(donate_crop_button)
		_content_box.add_child(row)
