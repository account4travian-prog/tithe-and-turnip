class_name BuildingPanel
extends CanvasLayer

## Build & tenure panel (B key): pick a building to enter placement mode
## (ghost follows the faced tile, Interact confirms), or rent land strips
## from the manor. Runtime-built CanvasLayer per the no-.tscn pattern.

const MENU_ID := "build"
const LAYER := 10

var _player: Player
var _building_manager: Node
var _renderer: Node
var _selected_building_id := ""
var _placement_active := false
var _tab := "build"

var _build_box: VBoxContainer
var _tenure_box: VBoxContainer
var _money_label: Label
var _hint_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(6)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Build & Tenure", 24))
	var tabs := HBoxContainer.new()
	var build_tab := UIKit.make_button("Build")
	build_tab.pressed.connect(func() -> void:
		_tab = "build"
		_show_tab())
	tabs.add_child(build_tab)
	var tenure_tab := UIKit.make_button("Tenure")
	tenure_tab.pressed.connect(func() -> void:
		_tab = "tenure"
		_show_tab())
	tabs.add_child(tenure_tab)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	tabs.add_child(close_button)
	frame.add_child(tabs)
	_money_label = UIKit.make_label("")
	frame.add_child(_money_label)
	_hint_label = UIKit.make_label("", 14)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(_hint_label)
	_build_box = UIKit.make_vbox(2)
	frame.add_child(_build_box)
	_tenure_box = UIKit.make_vbox(2)
	frame.add_child(_tenure_box)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.money_changed.connect(func(_amount: int) -> void:
		_refresh())
	PlayerState.inventory_changed.connect(func() -> void:
		_refresh())


func configure(player: Player, building_manager: Node, renderer: Node) -> void:
	_player = player
	_building_manager = building_manager
	_renderer = renderer


func _process(_delta: float) -> void:
	if not visible or not _placement_active:
		return
	if _renderer == null or _player == null or _selected_building_id.is_empty():
		return
	var tile := _player.get_faced_tile()
	_renderer.show_ghost(_selected_building_id, tile)
	if InputManager.is_action_just_pressed("interact"):
		if _building_manager != null and _building_manager.start_building(_selected_building_id, tile):
			_hint_label.text = "Building started."
			_placement_active = false
			_renderer.hide_ghost()
			_refresh()
		else:
			_hint_label.text = "Cannot build there - check coin, materials, and free land."


func _on_menu_opened(menu_id: String) -> void:
	if menu_id != MENU_ID:
		return
	visible = true
	if _building_manager == null:
		_hint_label.text = "BuildingManager autoload not registered - add it in Project Settings -> Autoload."
	_show_tab()
	_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id != MENU_ID:
		return
	visible = false
	_placement_active = false
	_selected_building_id = ""
	if _renderer != null:
		_renderer.hide_ghost()


func _show_tab() -> void:
	_build_box.visible = _tab == "build"
	_tenure_box.visible = _tab == "tenure"


func _refresh() -> void:
	if not visible:
		return
	var player = get_node_or_null("/root/PlayerState")
	var flint := 0
	if player != null:
		flint = int(player.get_item_count("flint"))
	_money_label.text = "Coin: %d | Flint: %d" % [
		int(player.get("money")) if player != null else 0, flint]
	_refresh_build_rows()
	_refresh_tenure_rows()


func _refresh_build_rows() -> void:
	for child: Node in _build_box.get_children():
		child.queue_free()
	for building_id: String in GameData.get_all_building_ids():
		var def: Dictionary = GameData.get_building(building_id)
		var build_days := int(def.get("build_days", 0))
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("%s - %d coin %s (%d day%s)" % [
			str(def.get("name", building_id)),
			int(def.get("cost_coin", 0)),
			_materials_text(def.get("cost_materials", {})),
			build_days, "s" if build_days != 1 else ""]))
		var button := UIKit.make_button("Place")
		button.disabled = not _can_afford(def)
		button.pressed.connect(func() -> void:
			_begin_placement(building_id))
		row.add_child(button)
		_build_box.add_child(row)


func _refresh_tenure_rows() -> void:
	for child: Node in _tenure_box.get_children():
		child.queue_free()
	var tenure: Dictionary = GameData.get_tenure_data()
	var per_strip_tithe := int(GameData.get_tithe_data().get("coin_per_held_strip", 0))
	var owned := UIKit.make_label("Owned by default: the %dx%d home plot" % [
		int((tenure.get("default_owned_rect", {}) as Dictionary).get("width", 0)),
		int((tenure.get("default_owned_rect", {}) as Dictionary).get("height", 0))])
	_tenure_box.add_child(owned)
	for strip: Variant in tenure.get("strips", []):
		var s := strip as Dictionary
		var strip_id := str(s.get("id", ""))
		var rented: bool = _building_manager != null and bool(_building_manager.is_strip_rented(strip_id))
		var row := HBoxContainer.new()
		row.add_child(UIKit.make_label("%s - adds %d coin to the Lord's Tithe each season" % [
			str(s.get("name", strip_id)), per_strip_tithe]))
		var button := UIKit.make_button("Rented" if rented else "Rent")
		button.disabled = rented or _building_manager == null
		button.pressed.connect(func() -> void:
			if _building_manager != null:
				_building_manager.rent_strip(strip_id)
				_refresh())
		row.add_child(button)
		_tenure_box.add_child(row)


func _begin_placement(building_id: String) -> void:
	_selected_building_id = building_id
	_placement_active = true
	_hint_label.text = "Walk to a tile and press Interact to place %s. B or Esc cancels." % str(
		GameData.get_building(building_id).get("name", building_id))


func _can_afford(def: Dictionary) -> bool:
	var player = get_node_or_null("/root/PlayerState")
	if player == null:
		return false
	if int(player.get("money")) < int(def.get("cost_coin", 0)):
		return false
	var mats: Dictionary = def.get("cost_materials", {})
	for mat_id: Variant in mats:
		if not player.has_item(str(mat_id), int(mats[mat_id])):
			return false
	return true


func _materials_text(mats: Dictionary) -> String:
	var parts: Array[String] = []
	for mat_id: Variant in mats:
		parts.append("%s x%d" % [str(mat_id), int(mats[mat_id])])
	if parts.is_empty():
		return ""
	return "+ " + ", ".join(parts)
