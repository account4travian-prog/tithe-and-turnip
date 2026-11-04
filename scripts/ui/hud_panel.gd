class_name HudPanel
extends CanvasLayer

## Always-visible HUD themed to design/ui_mockups/tithe_and_turnip_ui_mockups
## .dc.html: parchment date card + weather/skills pills top-left; coin pill +
## tithe card + market pill top-right; HEALTH/VIGOUR bars + standing pills
## bottom-left; message toast + tile tooltip + hotbar + key hints
## bottom-center. Layer 1, never toggled by UIManager. Presentation only -
## it never mutates gameplay state.

const LAYER := 1
const MARGIN := 20.0
const HOTBAR_SLOT := 64.0

const ROMAN: Array[String] = ["0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X"]
const WEATHER_NAMES := {
	"sunny": "Clear Skies",
	"rain": "Rain",
	"overcast": "Overcast",
	"snow": "Snow",
}
const WEATHER_COLORS := {
	"sunny": UIKit.C_GOLD,
	"rain": UIKit.C_CHURCH,
	"overcast": UIKit.C_MUTED,
	"snow": Color.WHITE,
}
const SWATCH_TOOL := Color("c7ac7c")
const SWATCH_WEAPON := Color("9aa0a6")
const SWATCH_SEED := Color("d4a74f")
const SWATCH_BARE := Color("c9a27a")
const DIRECTION_LEGEND := "N ↗  E ↘  S ↙  W ↖"

var _player: Player
var _farm_grid: Node
## Sprint 15b: the active zone id, kept in step with the farm grid so the
## tile tooltip's bounds check and soil read resolve against the zone the
## player is actually standing in.
var _zone_id := "fallowfield"
var _message_timer := 0.0
var _current_water := 0.0
var _current_capacity := 0.0
var _last_coordinate_tile := Vector2i(-1, -1)
var _last_coordinate_zone := ""

var _date_label: Label
var _time_label: Label
var _coin_label: Label
var _tithe_amount_label: Label
var _tithe_bar: ProgressBar
var _health_label: Label
var _health_bar: ProgressBar
var _coordinate_label: Label
var _vigour_label: Label
var _vigour_bar: ProgressBar
var _tooltip_label: Label
var _tooltip_card: PanelContainer
var _message_toast: PanelContainer
var _message_label: Label
var _interact_hint_row: HBoxContainer
var _interact_hint_label: Label

var _top_left: VBoxContainer
var _top_right: VBoxContainer
var _bottom_left: VBoxContainer
var _bottom_center: VBoxContainer
var _weather_pill: PanelContainer
var _skills_pill: PanelContainer
var _market_pill: PanelContainer
var _standing_box: HBoxContainer
var _hotbar_box: HBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	TimeManager.minute_passed.connect(_on_minute_passed)
	PlayerState.energy_changed.connect(_on_energy_changed)
	PlayerState.money_changed.connect(_on_money_changed)
	PlayerState.health_changed.connect(_on_health_changed)
	PlayerState.equipped_changed.connect(_on_equipped_changed)
	PlayerState.weapon_changed.connect(_on_weapon_changed)
	PlayerState.inventory_changed.connect(_on_inventory_changed)
	TitheManager.tithe_updated.connect(_on_tithe_updated)
	TitheManager.market_status_changed.connect(_on_market_status_changed)
	TitheManager.corvee_announced.connect(_on_corvee_announced)
	TitheManager.corvee_started.connect(_on_corvee_started)
	TitheManager.court_held.connect(_on_court_held)
	TitheManager.black_market_status_changed.connect(_on_black_market_status_changed)
	ReputationManager.standing_changed.connect(_on_standing_changed)
	WeatherManager.weather_changed.connect(_on_weather_changed)
	SaveManager.game_loaded.connect(_on_game_loaded)
	var skills = get_node_or_null("/root/SkillManager")
	if skills != null:
		skills.leveled_up.connect(func(_skill_id: String, _new_level: int) -> void:
			refresh_skills())
	_build_columns()
	_on_game_loaded()


func _process(delta: float) -> void:
	if _message_timer > 0.0:
		_message_timer -= delta
		if _message_timer <= 0.0:
			_message_toast.visible = false
			_message_label.text = ""
	_refresh_tile_tooltip()
	_refresh_interact_hint()
	_refresh_coordinate_readout()
	_layout_columns()


func configure(player: Player, farm_grid: Node) -> void:
	_player = player
	_farm_grid = farm_grid
	if farm_grid != null and farm_grid.has_method("get_zone_id"):
		var zone_id := str(farm_grid.get_zone_id())
		if not zone_id.is_empty():
			_zone_id = zone_id


## Sprint 15b: live re-wire on zone crossings so the tile tooltip reads the
## active zone's grid and bounds. The zone id comes from the grid itself
## (FarmGrid.get_zone_id), so the HUD never guesses which zone it shows.
func set_farm_grid(farm_grid: Node) -> void:
	_farm_grid = farm_grid
	_last_coordinate_zone = ""
	if farm_grid != null and farm_grid.has_method("get_zone_id"):
		var zone_id := str(farm_grid.get_zone_id())
		if not zone_id.is_empty():
			_zone_id = zone_id


func show_message(text: String) -> void:
	_message_label.text = text
	_message_toast.visible = true
	_message_timer = 2.0


func refresh_water(current: float, capacity: float) -> void:
	_current_water = current
	_current_capacity = capacity
	_rebuild_hotbar()


func refresh_skills() -> void:
	if _skills_pill != null and is_instance_valid(_skills_pill):
		_skills_pill.queue_free()
	var skills = get_node_or_null("/root/SkillManager")
	var text := "Farming 0 · Foraging 0 · Combat 0 · Labor 0"
	if skills != null:
		text = "Farming %s · Foraging %s · Combat %s · Labor %s" % [
			_roman(int(skills.get_level("farming"))),
			_roman(int(skills.get_level("foraging"))),
			_roman(int(skills.get_level("combat"))),
			_roman(int(skills.get_level("labor")))]
	_skills_pill = UIKit.make_pill(text, Color(-1, -1, -1), 12)
	_top_left.add_child(_skills_pill)


func _build_columns() -> void:
	_top_left = UIKit.make_vbox(10)
	add_child(_top_left)
	_top_right = UIKit.make_vbox(10)
	add_child(_top_right)
	_bottom_left = UIKit.make_vbox(10)
	add_child(_bottom_left)
	_bottom_center = UIKit.make_vbox(10)
	add_child(_bottom_center)
	_build_date_card()
	_rebuild_weather_pill()
	refresh_skills()
	_build_coin_pill()
	_build_tithe_card()
	_rebuild_market_pill()
	_build_health_vigour()
	_rebuild_standing_pills()
	_build_toast()
	_build_tooltip_card()
	_rebuild_hotbar()
	_build_hints()


func _build_date_card() -> void:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _parchment_style(2, 8))
	var box := UIKit.make_vbox(2)
	card.add_child(box)
	_date_label = UIKit.make_label("", 16, UIKit.C_INK)
	box.add_child(_date_label)
	_time_label = UIKit.make_label("", 14, UIKit.C_INK_SOFT)
	box.add_child(_time_label)
	_top_left.add_child(card)


func _rebuild_weather_pill() -> void:
	if _weather_pill != null and is_instance_valid(_weather_pill):
		_weather_pill.queue_free()
	var weather := WeatherManager.get_today_weather()
	var accent: Color = WEATHER_COLORS.get(weather, UIKit.C_GOLD) as Color
	_weather_pill = UIKit.make_pill(str(WEATHER_NAMES.get(weather, "Clear Skies")), accent)
	_top_left.add_child(_weather_pill)


func _build_coin_pill() -> void:
	var pill := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_DARK_PANEL
	style.border_color = Color(UIKit.C_GOLD.r, UIKit.C_GOLD.g, UIKit.C_GOLD.b, 0.65)
	style.set_border_width_all(2)
	style.set_corner_radius_all(20)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	pill.add_theme_stylebox_override("panel", style)
	var row := UIKit.make_hbox(9)
	pill.add_child(row)
	row.add_child(UIKit.make_dot(UIKit.C_GOLD, 16))
	_coin_label = UIKit.make_label("", 17, Color("f3e2b6"))
	row.add_child(_coin_label)
	_top_right.add_child(pill)


func _build_tithe_card() -> void:
	var card := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_DARK_PANEL
	style.border_color = UIKit.C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.content_margin_left = 14.0
	style.content_margin_right = 14.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	card.add_theme_stylebox_override("panel", style)
	card.custom_minimum_size = Vector2(210, 0)
	var box := UIKit.make_vbox(6)
	card.add_child(box)
	var row := UIKit.make_hbox()
	row.add_child(UIKit.make_label("LORD'S TITHE", 13, UIKit.C_LIGHT))
	_tithe_amount_label = UIKit.make_label("", 13, UIKit.C_LIGHT)
	_tithe_amount_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_tithe_amount_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_tithe_amount_label)
	box.add_child(row)
	_tithe_bar = UIKit.make_bar(0.0, UIKit.C_GOLD, 210, 8)
	box.add_child(_tithe_bar)
	_top_right.add_child(card)


func _rebuild_market_pill() -> void:
	if _market_pill != null and is_instance_valid(_market_pill):
		_market_pill.queue_free()
	var info := TitheManager.get_market_info()
	var text := "Manor Market — open today"
	if not bool(info.get("open", false)):
		text = "Manor Market — shut until Day %d" % int(info.get("next_day", 1))
	_market_pill = UIKit.make_pill(text, Color(-1, -1, -1), 13)
	_top_right.add_child(_market_pill)


func _build_health_vigour() -> void:
	_coordinate_label = UIKit.make_label("", 12, UIKit.C_LIGHT)
	_bottom_left.add_child(_coordinate_label)
	_bottom_left.add_child(_build_bar_block("HEALTH", UIKit.C_HEALTH, true))
	_bottom_left.add_child(_build_bar_block("VIGOUR", UIKit.C_VIGOUR, false))


func _build_bar_block(title: String, color: Color, is_health: bool) -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	var row := UIKit.make_hbox()
	row.add_child(UIKit.make_label(title, 11, UIKit.C_LIGHT))
	var value_label := UIKit.make_label("", 11, UIKit.C_LIGHT)
	value_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value_label)
	box.add_child(row)
	var bar := UIKit.make_bar(0.0, color, 220, 10)
	box.add_child(bar)
	if is_health:
		_health_label = value_label
		_health_bar = bar
	else:
		_vigour_label = value_label
		_vigour_bar = bar
	return box


func _rebuild_standing_pills() -> void:
	if _standing_box != null and is_instance_valid(_standing_box):
		_standing_box.queue_free()
	_standing_box = UIKit.make_hbox(8)
	_standing_box.add_child(UIKit.make_pill(
		"Manor %d" % int(ReputationManager.get_standing("manor")), UIKit.C_GOLD, 11))
	_standing_box.add_child(UIKit.make_pill(
		"Village %d" % int(ReputationManager.get_standing("village")), UIKit.C_VIGOUR, 11))
	_standing_box.add_child(UIKit.make_pill(
		"Church %d" % int(ReputationManager.get_standing("church")), UIKit.C_CHURCH, 11))
	_bottom_left.add_child(_standing_box)


func _build_toast() -> void:
	_message_toast = UIKit.make_toast("")
	_message_label = _message_toast.get_child(0) as Label
	_message_toast.visible = false
	_bottom_center.add_child(_message_toast)


func _build_tooltip_card() -> void:
	_tooltip_card = PanelContainer.new()
	_tooltip_card.add_theme_stylebox_override("panel", _parchment_style(2, 8))
	_tooltip_label = UIKit.make_label("", 13, UIKit.C_INK)
	_tooltip_card.add_child(_tooltip_label)
	_tooltip_card.visible = false
	_bottom_center.add_child(_tooltip_card)


func _rebuild_hotbar() -> void:
	if _hotbar_box == null:
		_hotbar_box = UIKit.make_hbox(10)
		_bottom_center.add_child(_hotbar_box)
	for child: Node in _hotbar_box.get_children():
		child.queue_free()
	_hotbar_box.add_child(_build_bare_hands_slot("0"))
	_hotbar_box.add_child(_build_tool_slot("1", str(PlayerState.equipped_tool_id)))
	_hotbar_box.add_child(_build_can_slot("2"))
	_hotbar_box.add_child(_build_stack_slot("3", "turnip_seed"))
	_hotbar_box.add_child(_build_weapon_slot("4"))
	_hotbar_box.add_child(_build_bow_slot("5"))
	_hotbar_box.add_child(_build_stack_slot("6", "arrow"))


## VSA-3: the "put tools away" slot - selected exactly when
## PlayerState.equipped_tool_id is empty, which is what ToolManager.use_tool
## requires for bare-hand harvest/forage.
func _build_bare_hands_slot(key_text: String) -> VBoxContainer:
	var selected := str(PlayerState.equipped_tool_id).is_empty()
	return _build_slot_box(key_text, "Bare Hands", SWATCH_BARE, selected)


func _build_tool_slot(key_text: String, tool_id: String) -> VBoxContainer:
	var item := GameData.get_item(tool_id)
	var name := str(item.get("name", "Fists")) if not item.is_empty() else "Fists"
	var selected := tool_id == str(PlayerState.equipped_tool_id)
	return _build_slot_box(key_text, name, SWATCH_TOOL, selected)


func _build_can_slot(key_text: String) -> VBoxContainer:
	var item := GameData.get_item("can_wood")
	var name := str(item.get("name", "Watering Can"))
	var selected := "can_wood" == str(PlayerState.equipped_tool_id)
	var water_fraction := _current_water / maxf(_current_capacity, 1.0)
	var caption := "%s (%d/%d)" % [name, int(_current_water), int(_current_capacity)]
	return _build_slot_box(key_text, caption, SWATCH_TOOL, selected, -1, water_fraction)


func _build_stack_slot(key_text: String, item_id: String) -> VBoxContainer:
	var item := GameData.get_item(item_id)
	var name := str(item.get("name", item_id))
	var count := PlayerState.get_item_count(item_id)
	var selected := item_id == str(PlayerState.equipped_tool_id)
	return _build_slot_box(key_text, name, SWATCH_SEED, selected, count)


## Slot 4 shows the equipped weapon, or Fists when none/bow is equipped
## (the bow has its own slot 5).
func _build_weapon_slot(key_text: String) -> VBoxContainer:
	var equipped := str(PlayerState.equipped_weapon_id)
	var slot_id := equipped
	if equipped.is_empty() or equipped == "bow":
		slot_id = "fists"
	var item := GameData.get_item(slot_id)
	var name := str(item.get("name", "Fists")) if not item.is_empty() else "Fists"
	var selected := slot_id != "fists" and slot_id == equipped
	return _build_slot_box(key_text, name, SWATCH_WEAPON, selected)


func _build_bow_slot(key_text: String) -> VBoxContainer:
	var item := GameData.get_item("bow")
	var name := str(item.get("name", "Bow"))
	var selected := str(PlayerState.equipped_weapon_id) == "bow"
	return _build_slot_box(key_text, name, SWATCH_WEAPON, selected)


func _build_slot_box(
	key_text: String, name: String, swatch: Color, selected: bool, count := -1, water_fraction := -1.0
) -> VBoxContainer:
	var box := UIKit.make_vbox(4)
	var slot := Panel.new()
	slot.custom_minimum_size = Vector2(HOTBAR_SLOT, HOTBAR_SLOT)
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_PARCHMENT
	style.border_color = UIKit.C_GOLD if selected else UIKit.C_BORDER
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	slot.add_theme_stylebox_override("panel", style)
	box.add_child(slot)
	var key := UIKit.make_label(key_text, 10, UIKit.C_INK_SOFT)
	key.position = Vector2(4, 2)
	slot.add_child(key)
	var swatch_panel := Panel.new()
	swatch_panel.custom_minimum_size = Vector2(30, 30)
	swatch_panel.position = Vector2((HOTBAR_SLOT - 30.0) * 0.5, (HOTBAR_SLOT - 30.0) * 0.5 - 4.0)
	var swatch_style := StyleBoxFlat.new()
	swatch_style.bg_color = swatch
	swatch_style.set_corner_radius_all(6)
	swatch_panel.add_theme_stylebox_override("panel", swatch_style)
	slot.add_child(swatch_panel)
	if count >= 0:
		slot.add_child(_build_count_badge(count))
	if water_fraction >= 0.0:
		# VSA-3: was 5px tall and easy to miss entirely; UIKit.make_bar
		# always draws a bordered background track, so the fix here is size
		# and the equip-change/game-loaded sync in _sync_water_from_tool_manager,
		# not the bar's own visibility.
		var bar := UIKit.make_bar(water_fraction, UIKit.C_CHURCH, 56, 9)
		bar.position = Vector2(4, HOTBAR_SLOT - 12.0)
		slot.add_child(bar)
	var caption := UIKit.make_label(name, 11, UIKit.C_LIGHT)
	caption.custom_minimum_size = Vector2(HOTBAR_SLOT, 0)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(caption)
	return box


func _build_count_badge(count: int) -> Panel:
	var badge := Panel.new()
	badge.custom_minimum_size = Vector2(18, 18)
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_INK
	style.border_color = UIKit.C_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	badge.add_theme_stylebox_override("panel", style)
	var label := UIKit.make_label(str(count), 10, Color("f3e2b6"))
	label.size = Vector2(18, 18)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(label)
	badge.position = Vector2(HOTBAR_SLOT - 15.0, HOTBAR_SLOT - 15.0)
	return badge


func _build_hints() -> void:
	var row := UIKit.make_hbox(26)
	row.add_child(_make_hint("I/Tab", "Satchel"))
	row.add_child(_make_hint("Esc", "Pause"))
	row.add_child(_make_hint("0", "Bare Hands"))
	var interact_hint := _make_hint("E", "")
	_interact_hint_row = interact_hint
	_interact_hint_label = interact_hint.get_child(1) as Label
	row.add_child(interact_hint)
	_bottom_center.add_child(row)


## VSA-2: the E-hint used to be a static "Work the Land" label regardless of
## what the player faced. Now it mirrors Player.get_interaction_preview() -
## a read-only echo of the same dispatch _use_tool() actually runs - so it
## always names the real action (or hides itself when there's nothing to do).
## Playtest fix (item 4): while the hold-to-preview is active, the hint
## names what RELEASING will do (plus the cancel key) instead of the plain
## action text, so it agrees with the on-field target indicator rather than
## reading like the action already fired.
func _refresh_interact_hint() -> void:
	if _player == null or _interact_hint_label == null:
		return
	var preview := _player.get_interaction_preview()
	_interact_hint_row.visible = not preview.is_empty()
	if preview.is_empty():
		return
	if _player.is_interact_hold_active():
		_interact_hint_label.text = "Release: %s (Esc to cancel)" % preview
	else:
		_interact_hint_label.text = preview


func _make_hint(key: String, label_text: String) -> HBoxContainer:
	var row := UIKit.make_hbox(6)
	var key_box := Panel.new()
	key_box.custom_minimum_size = Vector2(22, 22)
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_INK
	style.border_color = Color("8a6642")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	key_box.add_theme_stylebox_override("panel", style)
	var key_label := UIKit.make_label(key, 11, UIKit.C_LIGHT)
	key_label.size = Vector2(22, 22)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	key_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	key_box.add_child(key_label)
	row.add_child(key_box)
	row.add_child(UIKit.make_label(label_text, 12, UIKit.C_MUTED))
	return row


func _refresh_tile_tooltip() -> void:
	if _player == null or _farm_grid == null:
		_tooltip_card.visible = false
		return
	var tile := _player.get_faced_tile()
	if not GameData.is_within_farm(tile.x, tile.y, _zone_id):
		_tooltip_card.visible = false
		return
	var soil: String = _farm_grid.get_soil(tile)
	if soil.is_empty():
		_tooltip_card.visible = false
		return
	var moisture: float = _farm_grid.get_cell_moisture(tile)
	var crop_name: String = _farm_grid.get_crop_name(tile)
	var text := "%s SOIL · %s" % [soil.to_upper(), _moisture_word(moisture)]
	if not crop_name.is_empty():
		var cell: Dictionary = _farm_grid.get_cell(tile)
		var growth := float(cell.get("growth_progress", 0.0)) * 100.0
		text += " · %s — %d%% to harvest" % [crop_name, int(growth)]
		var crop_data: Dictionary = GameData.get_crop(str(cell.get("crop_id", "")))
		var spoil_after := int(crop_data.get("spoil_after_days", 0))
		if spoil_after > 0 and int(cell.get("days_mature", 0)) > spoil_after:
			text += " (SPOILING)"
	if not _farm_grid.is_owned(tile):
		text += " · NOT OWNED - rent from the manor"
	_tooltip_label.text = text
	_tooltip_card.visible = true


## Coordinates are the player's current simulation tile, not projected screen
## pixels. The legend pins the owner's agreed diamond orientation: north is the
## top-right face, then clockwise east/south/west. This is a presentation-only
## diagnostic readout and deliberately does not enter gameplay state.
func _refresh_coordinate_readout() -> void:
	if _player == null or _coordinate_label == null:
		return
	var tile := _player.get_current_tile()
	var zone_id := _zone_id
	if _farm_grid != null and _farm_grid.has_method("get_zone_id"):
		var grid_zone := str(_farm_grid.get_zone_id())
		if not grid_zone.is_empty():
			zone_id = grid_zone
	if tile == _last_coordinate_tile and zone_id == _last_coordinate_zone:
		return
	_last_coordinate_tile = tile
	_last_coordinate_zone = zone_id
	var zone_name := zone_id
	var metadata: Dictionary = GameData.get_zone_metadata(zone_id)
	if not str(metadata.get("name", "")).is_empty():
		zone_name = str(metadata.get("name", zone_id))
	_coordinate_label.text = "[%d, %d - %s]  %s" % [tile.x, tile.y, zone_name, DIRECTION_LEGEND]


func _layout_columns() -> void:
	var viewport := get_viewport().get_visible_rect().size
	_top_left.position = Vector2(MARGIN, MARGIN)
	_top_right.position = Vector2(viewport.x - _top_right.size.x - MARGIN, MARGIN)
	_bottom_left.position = Vector2(MARGIN, viewport.y - _bottom_left.size.y - MARGIN)
	_bottom_center.position = Vector2(
		(viewport.x - _bottom_center.size.x) * 0.5, viewport.y - _bottom_center.size.y - MARGIN)


func _parchment_style(border_width: int, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.C_PARCHMENT
	style.border_color = UIKit.C_BORDER
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 10.0
	style.content_margin_bottom = 10.0
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	return style


func _moisture_word(moisture: float) -> String:
	if moisture >= 80.0:
		return "well-watered"
	if moisture > 0.0:
		return "moist"
	return "dry"


func _roman(level: int) -> String:
	return ROMAN[clampi(level, 0, ROMAN.size() - 1)]


func _time_of_day_phrase(hour: int) -> String:
	if hour < 12:
		return "in the morning"
	if hour < 18:
		return "in the afternoon"
	return "in the evening"


func _refresh_time() -> void:
	_date_label.text = "Day %d of %s · Year %d" % [
		TimeManager.day, TimeManager.season.capitalize(), TimeManager.year]
	_time_label.text = "%s %s" % [TimeManager.time_string(), _time_of_day_phrase(TimeManager.hour)]


func _on_minute_passed(_hour: int, _minute: int) -> void:
	_refresh_time()


func _on_energy_changed(current: float, max_energy: float) -> void:
	_vigour_label.text = "%d / %d" % [int(current), int(max_energy)]
	_vigour_bar.value = clampf(current / maxf(max_energy, 1.0), 0.0, 1.0) * 100.0


func _on_money_changed(amount: int) -> void:
	_coin_label.text = "%d Coin" % amount


func _on_health_changed(current: int, max_health: int) -> void:
	_health_label.text = "%d / %d" % [current, max_health]
	_health_bar.value = clampf(float(current) / maxf(float(max_health), 1.0), 0.0, 1.0) * 100.0


func _on_equipped_changed(_tool_id: String) -> void:
	_sync_water_from_tool_manager()
	_rebuild_hotbar()


## VSA-3: _current_water/_current_capacity previously only updated from
## ToolManager.water_level_changed, which never fires before the can's first
## refill/use - so the gauge could read stale on boot or right after a load.
## Pulling the live values here (already-public getters) makes the HUD
## authoritative instead of signal-dependent. Runs on every equip change,
## which covers boot/load too since _on_game_loaded() already calls
## _on_equipped_changed().
func _sync_water_from_tool_manager() -> void:
	if _player == null:
		return
	var tool_manager := _player.get_tool_manager()
	if tool_manager == null:
		return
	_current_water = tool_manager.get_current_water()
	_current_capacity = tool_manager.get_current_capacity()


func _on_weapon_changed(_weapon_id: String) -> void:
	_rebuild_hotbar()


func _on_inventory_changed() -> void:
	_rebuild_hotbar()


func _on_tithe_updated(paid: float, goal: int) -> void:
	_tithe_amount_label.text = "%d / %d" % [int(paid), goal]
	_tithe_bar.value = clampf(paid / maxf(float(goal), 1.0), 0.0, 1.0) * 100.0


func _on_market_status_changed(_is_open: bool) -> void:
	_rebuild_market_pill()


func _on_corvee_announced(day: int) -> void:
	show_message("The steward demands labor in %d days" % day)


func _on_corvee_started() -> void:
	show_message("Corvee today - work the demesne or answer for it")


func _on_court_held(total_fine: int, offenses: Array) -> void:
	if total_fine == 0:
		show_message("Manor court held - no offenses this session")
		return
	var offense_list := ""
	for offense: Variant in offenses:
		if not offense_list.is_empty():
			offense_list += ", "
		offense_list += str(offense)
	show_message("Manor court fined you %d coin (%s)" % [total_fine, offense_list])


## Deliberate discoverability addition beyond the guide's three HUD messages:
## without a notice, the black-market tab (a UI-only trader) would be
## invisible to a player who never opens the shop on days 9/20.
func _on_black_market_status_changed(is_open: bool) -> void:
	if is_open:
		show_message("A black-market trader lurks in the village today")


func _on_standing_changed(_axis: String, _new_value: float) -> void:
	_rebuild_standing_pills()


func _on_weather_changed(_weather: String) -> void:
	_rebuild_weather_pill()


func _on_game_loaded() -> void:
	_refresh_time()
	_on_energy_changed(PlayerState.energy, PlayerState.max_energy)
	_on_money_changed(PlayerState.money)
	_on_health_changed(PlayerState.health, PlayerState.max_health)
	_on_equipped_changed(PlayerState.equipped_tool_id)
	_on_weapon_changed(PlayerState.equipped_weapon_id)
	_on_inventory_changed()
	_on_tithe_updated(TitheManager.get_tithe_progress().get("paid", 0.0),
		int(TitheManager.get_tithe_progress().get("goal", 0)))
	_on_market_status_changed(TitheManager.is_market_open())
	_on_standing_changed("", 0.0)
	_on_weather_changed(WeatherManager.get_today_weather())
	refresh_skills()
