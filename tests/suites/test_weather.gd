extends RefCounted
## WeatherManager coverage: rain/snow predicates, deterministic daily roll,
## signal emission, and save shape. Uses configure_for_test; TimeManager
## autoload supplies the season (spring in the test run).

const WEATHER_SCRIPT := preload("res://scripts/autoloads/weather_manager.gd")

var _weather_signal_fired := false


func suite_name() -> String:
	return "weather"


func run(t: Object) -> void:
	_test_rain_predicate(t)
	_test_snow_predicate(t)
	_test_overcast_predicate(t)
	_test_daily_roll_distribution(t)
	_test_signal_emitted(t)
	_test_serialization(t)
	t.completed(6)


func _test_rain_predicate(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 0.7, "rain": 0.3}}, "rain")
	t.ok(wm.is_raining(), "rain weather reports raining")
	t.not_ok(wm.is_snowing(), "rain weather is not snowing")
	t.eq(wm.get_today_weather(), "rain", "today weather is rain")
	t.section_done("rain")


func _test_snow_predicate(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "snow")
	t.ok(wm.is_snowing(), "snow weather reports snowing")
	t.not_ok(wm.is_raining(), "snow weather is not raining")
	t.section_done("snow")


func _test_overcast_predicate(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "overcast")
	t.ok(wm.is_overcast(), "overcast weather reports overcast")
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "sunny")
	t.not_ok(wm.is_overcast(), "sunny weather is not overcast")
	t.section_done("overcast")


func _test_daily_roll_distribution(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 0.7, "rain": 0.3}}, "sunny")
	seed(99)
	var rain_days := 0
	for _i in range(200):
		wm.advance_day()
		if wm.is_raining():
			rain_days += 1
	t.ok(rain_days > 20 and rain_days < 100,
		"seeded rain rate stays near expectation (got %d)" % rain_days)
	t.section_done("distribution")


func _test_signal_emitted(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "sunny")
	_weather_signal_fired = false
	wm.weather_changed.connect(_on_weather_changed)
	wm.advance_day()
	t.ok(_weather_signal_fired, "weather_changed fires on advance_day")
	t.section_done("signal")


func _on_weather_changed(_weather: String) -> void:
	_weather_signal_fired = true


func _test_serialization(t: Object) -> void:
	var wm = WEATHER_SCRIPT.new()
	wm.configure_for_test({"spring": {"sunny": 1.0}}, "sunny")
	wm.from_dict({"weather": "snow"})
	t.ok(wm.is_snowing(), "from_dict restores snow")
	t.eq(wm.to_dict().get("weather", ""), "snow", "to_dict roundtrips snow")
	t.section_done("serialization")
