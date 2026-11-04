extends Node

## Day/season/year clock. Real time is accumulated in _process (a wall-clock
## advance, not physics) but the core method `advance_real_seconds` is what
## tests drive, so the clock is fully deterministic off-tree.
## Reaching hour 24 without sleeping emits forced_collapse (the punished day
## end); sleep_to_next_day() skips it entirely (the safe path).

signal minute_passed(hour: int, minute: int)
signal day_passed(day: int, season: String, year: int)
signal season_changed(season: String)
signal year_passed(year: int)
signal forced_collapse

const DEFAULT_CFG := {
	"real_seconds_per_game_minute": 0.5,
	"minutes_per_hour": 60,
	"days_per_season": 28,
	"seasons": ["spring", "summer", "autumn", "winter"],
	"wake_hour": 6,
	"sleep_hour": 24,
}

var _cfg: Dictionary = {}
var _accum := 0.0
var day := 1
var season := "spring"
var year := 1
var hour := 6
var minute := 0
var paused := false


func _ready() -> void:
	_cfg = DEFAULT_CFG.duplicate(true)
	var game_data = get_node_or_null("/root/GameData")
	if game_data != null and not game_data.time_cfg.is_empty():
		_cfg.merge(game_data.time_cfg, true)


func configure(cfg: Dictionary) -> void:
	_cfg = cfg.duplicate(true)


func _process(delta: float) -> void:
	if not paused:
		advance_real_seconds(delta)


func advance_real_seconds(seconds: float) -> void:
	var seconds_per_minute := float(_cfg.get("real_seconds_per_game_minute", 0.5))
	if seconds_per_minute <= 0.0:
		return
	_accum += seconds
	while _accum >= seconds_per_minute:
		_accum -= seconds_per_minute
		_advance_minute()


func sleep_to_next_day() -> void:
	hour = int(_cfg.get("wake_hour", 6))
	minute = 0
	_advance_day()


func time_string() -> String:
	return "%02d:%02d" % [hour, minute]


func to_dict() -> Dictionary:
	return {"day": day, "season": season, "year": year, "hour": hour, "minute": minute}


func from_dict(data: Dictionary) -> void:
	day = int(data.get("day", 1))
	season = str(data.get("season", "spring"))
	year = int(data.get("year", 1))
	hour = int(data.get("hour", 6))
	minute = int(data.get("minute", 0))


func _advance_minute() -> void:
	_advance_minute_step(true)


## Advance a whole number of game-hours. Optionally skip the forced-collapse
## penalty so an exhaustion recovery can cross midnight without stacking a
## second penalty on top of the one already applied.
func advance_hours(hours: int, trigger_collapse_penalty: bool = true) -> void:
	var steps := hours * int(_cfg.get("minutes_per_hour", 60))
	for _i in range(steps):
		_advance_minute_step(trigger_collapse_penalty)


func _advance_minute_step(trigger_collapse: bool) -> void:
	minute += 1
	var minutes_per_hour := int(_cfg.get("minutes_per_hour", 60))
	if minute >= minutes_per_hour:
		minute = 0
		hour += 1
		if hour >= 24:
			hour = 0
			if trigger_collapse:
				forced_collapse.emit()
			_advance_day()
	minute_passed.emit(hour, minute)


func _advance_day() -> void:
	day += 1
	var days_per_season := int(_cfg.get("days_per_season", 28))
	if day > days_per_season:
		day = 1
		var seasons: Array = _cfg.get("seasons", ["spring"])
		var idx := seasons.find(season) + 1
		if idx >= seasons.size():
			idx = 0
			year += 1
			year_passed.emit(year)
		season = str(seasons[idx])
		season_changed.emit(season)
	day_passed.emit(day, season, year)
