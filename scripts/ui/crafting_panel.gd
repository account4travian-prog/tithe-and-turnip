class_name CraftingPanel
extends CanvasLayer

## Crafting panel (Sprint 13): opened by main.gd when the player interacts
## with a completed drying_shed/hearth tile. Lists only recipes for that
## station - this is the proximity gate; CraftingManager.can_craft itself
## checks existence-anywhere, skill level, ingredients, and energy. Runtime-
## built CanvasLayer per the no-.tscn pattern.

const MENU_ID := "crafting"
const LAYER := 10

var _station_id := ""

var _title_label: Label
var _hint_label: Label
var _rows_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(6)
	center.add_child(frame)
	_title_label = UIKit.make_label("Crafting", 24)
	frame.add_child(_title_label)
	_hint_label = UIKit.make_label("", 14)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	frame.add_child(_hint_label)
	_rows_box = UIKit.make_vbox(2)
	frame.add_child(_rows_box)
	var close_button := UIKit.make_button("Close")
	close_button.pressed.connect(func() -> void:
		UIManager.close_menu(MENU_ID))
	frame.add_child(close_button)
	UIManager.menu_opened.connect(_on_menu_opened)
	UIManager.menu_closed.connect(_on_menu_closed)
	PlayerState.inventory_changed.connect(func() -> void:
		_refresh())
	PlayerState.energy_changed.connect(func(_energy: float, _max: float) -> void:
		_refresh())
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.day_passed.connect(func(_day: int, _season: String, _year: int) -> void:
			_refresh())


func open_for_station(station_id: String) -> void:
	_station_id = station_id
	UIManager.open_menu(MENU_ID)


func _on_menu_opened(menu_id: String) -> void:
	if menu_id != MENU_ID:
		return
	visible = true
	_refresh()


func _on_menu_closed(menu_id: String) -> void:
	if menu_id != MENU_ID:
		return
	visible = false


func _refresh() -> void:
	if not visible:
		return
	var cm := get_node_or_null("/root/CraftingManager")
	if cm == null:
		_title_label.text = "Crafting"
		_hint_label.text = "CraftingManager autoload not registered - add it in Project Settings -> Autoload."
		_clear_rows()
		return
	_title_label.text = "Crafting - %s" % _station_name()
	_clear_rows()
	var gd := get_node_or_null("/root/GameData")
	if gd == null:
		return
	for recipe_id: String in gd.get_all_recipe_ids():
		var recipe: Dictionary = gd.get_recipe(recipe_id)
		if str(recipe.get("station", "")) != _station_id:
			continue
		_add_recipe_row(cm, recipe)
	var pending: Array = cm.get_pending() as Array
	if not pending.is_empty():
		_hint_label.text = "Crafting: %d item(s) pending (finish tomorrow)." % pending.size()
	else:
		_hint_label.text = ""


func _add_recipe_row(cm: Node, recipe: Dictionary) -> void:
	var recipe_id := str(recipe.get("id", ""))
	var can: bool = cm.can_craft(recipe_id)
	var reason := _block_reason(cm, recipe)
	var row := HBoxContainer.new()
	var label := UIKit.make_label("%s <- %s" % [
		str(recipe.get("output_item_id", "")), _inputs_text(recipe.get("inputs", {}))],
		16, UIKit.C_LIGHT if can else UIKit.C_MUTED)
	if not can:
		label.text += "  (%s)" % reason
	row.add_child(label)
	var button := UIKit.make_button("Craft")
	button.disabled = not can
	button.pressed.connect(func() -> void:
		if cm.craft(recipe_id):
			_refresh())
	row.add_child(button)
	_rows_box.add_child(row)


## First failing reason in guide order: station, skill, ingredients, energy.
func _block_reason(cm: Node, recipe: Dictionary) -> String:
	var station := str(recipe.get("station", ""))
	if not station.is_empty():
		var bm := get_node_or_null("/root/BuildingManager")
		var station_ready := false
		if bm != null:
			for b: Dictionary in bm.get_completed_buildings():
				if str(b.get("building_id", "")) == station:
					station_ready = true
					break
		if not station_ready:
			return "station not built"
	var skill_id := str(recipe.get("skill_id", ""))
	if not skill_id.is_empty():
		var skill := get_node_or_null("/root/SkillManager")
		var level := 0
		if skill != null:
			level = int(skill.get_level(skill_id))
		if level < int(recipe.get("skill_level_required", 0)):
			return "requires %s level %d" % [skill_id, int(recipe.get("skill_level_required", 0))]
	var player = get_node_or_null("/root/PlayerState")
	if player != null:
		var inputs: Dictionary = recipe.get("inputs", {})
		for item_id: Variant in inputs:
			if not player.has_item(str(item_id), int(inputs[item_id]), "common"):
				return "missing ingredients"
		if player.energy < float(recipe.get("energy_cost", 0)):
			return "not enough energy"
	return ""


func _station_name() -> String:
	var gd := get_node_or_null("/root/GameData")
	if gd == null or _station_id.is_empty():
		return _station_id
	return str(gd.get_building(_station_id).get("name", _station_id))


func _inputs_text(inputs: Dictionary) -> String:
	var parts: Array[String] = []
	for item_id: Variant in inputs:
		parts.append("%s x%d" % [str(item_id), int(inputs[item_id])])
	if parts.is_empty():
		return ""
	return ", ".join(parts)


func _clear_rows() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
