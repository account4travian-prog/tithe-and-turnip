extends Node

## Daily weather from seasonal chances (weather.json via GameData). Autoload;
## the source of truth for rain/snow used by farming and future systems.

signal weather_changed(new_weather: String)

const SEASONS: Array[String] = ["spring", "summer", "autumn", "winter"]

var _weather_today: String = "sunny"
var _test_mode: bool = false
var _chances: Dictionary = {}


func _ready() -> void:
	if not _test_mode:
		var game_data := get_node_or_null("/root/GameData")
		if game_data != null:
			for season: String in SEASONS:
				_chances[season] = game_data.get_weather_chances(season)
			advance_day()


func configure_for_test(chances: Dictionary, initial_weather := "") -> void:
	_test_mode = true
	_chances = chances
	if not initial_weather.is_empty():
		_weather_today = initial_weather
	else:
		_weather_today = "sunny"


func advance_day() -> void:
	var season := _current_season()
	var chances: Dictionary = _chances.get(season, {})
	if chances.is_empty():
		chances = {"sunny": 1.0}
	_weather_today = _weighted_pick(chances)
	weather_changed.emit(_weather_today)


func get_today_weather() -> String:
	return _weather_today


func is_raining() -> bool:
	return _weather_today == "rain"


func is_snowing() -> bool:
	return _weather_today == "snow"


func is_overcast() -> bool:
	return _weather_today == "overcast"


## Debug-only lever (Ctrl+K cheat panel): override today's weather outside the
## normal seasonal roll. Mirrors from_dict's validation but also emits
## weather_changed, since from_dict deliberately doesn't (load order reasons)
## and the cheat panel needs the HUD to react immediately.
func force_weather(weather: String) -> bool:
	if not ["sunny", "rain", "overcast", "snow"].has(weather):
		return false
	_weather_today = weather
	weather_changed.emit(_weather_today)
	return true


func to_dict() -> Dictionary:
	return {"weather": _weather_today}


func from_dict(data: Dictionary) -> void:
	var weather := str(data.get("weather", "sunny"))
	if ["sunny", "rain", "overcast", "snow"].has(weather):
		_weather_today = weather
	else:
		_weather_today = "sunny"


func _weighted_pick(weights: Dictionary) -> String:
	var total := 0.0
	for key: Variant in weights:
		total += float(weights[key])
	if total <= 0.0:
		return "sunny"
	var roll := randf() * total
	var cumulative := 0.0
	for key: Variant in weights:
		cumulative += float(weights[key])
		if roll < cumulative:
			return str(key)
	return "sunny"


func _current_season() -> String:
	if _test_mode:
		return "spring"
	var time_manager := get_node_or_null("/root/TimeManager")
	if time_manager == null:
		return "spring"
	return str(time_manager.get("season")).to_lower()
