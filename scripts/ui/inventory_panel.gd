class_name InventoryPanel
extends CanvasLayer

## Inventory grid: one row per quality-stacked item, Equip/Eat buttons.
## Gift mode (open_for_gift) swaps every row's button for "Gift" and closes
## back to the dialogue panel on success (Sprint 10).
## No "Drop" - there is no ground-item entity for a dropped stack to become
## yet (see design/sprints/sprint_07_ui_layer.md's divergences).

const MENU_ID := "inventory"
const LAYER := 10

var _rows_box: VBoxContainer
var _gift_npc_id := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(4)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Inventory", 24))
	_rows_box = UIKit.make_vbox(2)
	frame.add_child(_rows_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.inventory_changed.connect(_refresh)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = true
		_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id == MENU_ID:
		visible = false
		_gift_npc_id = ""


## Opens the inventory in gift mode for an NPC: every row's button becomes
## "Gift" (ReputationManager.gift_item) and a successful gift pops the panel
## back to whichever menu opened it (the dialogue panel).
func open_for_gift(npc_id: String) -> void:
	_gift_npc_id = npc_id
	UIManager.open_menu(MENU_ID)


func _refresh() -> void:
	if not visible:
		return
	for child: Node in _rows_box.get_children():
		child.queue_free()
	var stacks := PlayerState.list_inventory()
	if stacks.is_empty():
		_rows_box.add_child(UIKit.make_label("(empty)"))
		return
	for entry: Variant in stacks:
		_rows_box.add_child(_build_row(entry as Dictionary))


func _build_row(stack: Dictionary) -> HBoxContainer:
	var item_id := str(stack.get("item_id", ""))
	var quality := str(stack.get("quality", "common"))
	var count := int(stack.get("count", 0))
	var item := GameData.get_item(item_id)
	var row := HBoxContainer.new()
	row.add_child(UIKit.make_label("%s (%s) x%d" % [str(item.get("name", item_id)), quality, count]))
	if not _gift_npc_id.is_empty():
		var gift_callback := func() -> void:
			var given: bool = ReputationManager.gift_item(_gift_npc_id, item_id)
			if given:
				UIManager.close_menu(MENU_ID)
		var gift_button := UIKit.make_button("Gift")
		gift_button.pressed.connect(gift_callback)
		row.add_child(gift_button)
		return row
	var item_type := str(item.get("type", ""))
	# E2: compost is type "material" (not "tool"), but is equipped and used
	# on a cell the same way a seed or tool is - fertilize_amount is what
	# distinguishes it from inert materials (flint, wood, spoiled_crop),
	# which have no cell action and stay un-equippable.
	if item_type == "tool" or item_type == "seed" \
			or (item_type == "material" and item.has("fertilize_amount")):
		var equip_button := UIKit.make_button("Equip")
		equip_button.pressed.connect(func() -> void:
			PlayerState.set_equipped_tool(item_id))
		row.add_child(equip_button)
	elif item_type == "weapon":
		var equip_weapon_button := UIKit.make_button("Equip")
		equip_weapon_button.pressed.connect(func() -> void:
			PlayerState.set_equipped_weapon(item_id))
		row.add_child(equip_weapon_button)
	elif item_type == "food":
		var eat_button := UIKit.make_button("Eat")
		eat_button.pressed.connect(func() -> void:
			PlayerState.eat(item_id))
		row.add_child(eat_button)
	return row
