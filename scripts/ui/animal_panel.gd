class_name AnimalPanel
extends CanvasLayer

## Animal panel (Sprint 14): opened by main.gd when the player interacts with
## a completed coop tile. Buy rows (chicken/goat) disabled with a reason when
## AnimalManager.can_buy_animal is false, and one row per owned animal with a
## happiness bar, "Fed today" state, and a Feed button. Runtime-built
## CanvasLayer per the no-.tscn pattern.

const MENU_ID := "animals"
const LAYER := 10

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
	_title_label = UIKit.make_label("Animals", 24)
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
	PlayerState.money_changed.connect(func(_amount: int) -> void:
		_refresh())
	var tm := get_node_or_null("/root/TimeManager")
	if tm != null:
		tm.day_passed.connect(func(_day: int, _season: String, _year: int) -> void:
			_refresh())
	var am := get_node_or_null("/root/AnimalManager")
	if am != null:
		am.animal_purchased.connect(func(_id: String, _species: String) -> void:
			_refresh())
		am.animal_lost.connect(func(_id: String, _reason: String) -> void:
			_refresh())


func open_for_coop() -> void:
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
	var am := get_node_or_null("/root/AnimalManager")
	if am == null:
		_title_label.text = "Animals"
		_hint_label.text = "AnimalManager autoload not registered - add it in Project Settings -> Autoload."
		_clear_rows()
		return
	var gd := get_node_or_null("/root/GameData")
	if gd == null:
		return
	_title_label.text = "Animals - %d/%d in the coop" % [am.get_owned_count(), am.get_coop_capacity()]
	_clear_rows()
	var species: Dictionary = gd.animals_cfg.get("species", {})
	for species_id: Variant in species:
		_add_buy_row(am, gd, str(species_id), species[species_id] as Dictionary)
	for animal_id: String in am.get_animal_ids():
		_add_animal_row(am, gd, animal_id)
	_hint_label.text = ""


func _add_buy_row(am: Node, gd: Node, species_id: String, def: Dictionary) -> void:
	var price := int(def.get("purchase_price", 0))
	var can: bool = am.can_buy_animal(species_id)
	var reason := _buy_reason(am, def, price)
	var row := HBoxContainer.new()
	var label := UIKit.make_label("%s - %d coin" % [str(def.get("name", species_id)), price],
		16, UIKit.C_LIGHT if can else UIKit.C_MUTED)
	if not can:
		label.text += "  (%s)" % reason
	row.add_child(label)
	var button := UIKit.make_button("Buy")
	button.disabled = not can
	button.pressed.connect(func() -> void:
		if am.buy_animal(species_id):
			_refresh())
	row.add_child(button)
	_rows_box.add_child(row)


## First failing reason in guide order: no coop, at capacity, not enough coin.
func _buy_reason(am: Node, def: Dictionary, price: int) -> String:
	if am.get_coop_capacity() <= 0:
		return "no coop built"
	if am.get_owned_count() >= am.get_coop_capacity():
		return "coop at capacity"
	var player = get_node_or_null("/root/PlayerState")
	if player == null or int(player.money) < price:
		return "not enough coin"
	return "cannot buy"


func _add_animal_row(am: Node, gd: Node, animal_id: String) -> void:
	var a: Dictionary = am.get_animal(animal_id)
	var species_id := str(a.get("species", ""))
	var def: Dictionary = gd.get_animal_species(species_id)
	var max_happy := maxf(1.0, float(gd.animals_cfg.get("max_happiness", 100)))
	var happiness := float(a.get("happiness", 0.0))
	var row := HBoxContainer.new()
	var label := UIKit.make_label("%s (%s) - happy %d%% - fed: %s" % [
		animal_id, str(def.get("name", species_id)), int(round(happiness / max_happy * 100.0)),
		"yes" if bool(a.get("fed_today", false)) else "no"], 16)
	row.add_child(label)
	row.add_child(UIKit.make_bar(happiness / max_happy, UIKit.C_VIGOUR, 120, 10))
	var button := UIKit.make_button("Feed")
	button.disabled = bool(a.get("fed_today", false))
	button.pressed.connect(func() -> void:
		if am.feed_animal(animal_id):
			_refresh())
	row.add_child(button)
	_rows_box.add_child(row)


func _clear_rows() -> void:
	for child: Node in _rows_box.get_children():
		child.queue_free()
