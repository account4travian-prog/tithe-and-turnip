class_name SeasonSummaryPanel
extends CanvasLayer

## Shown once when Spring ends (TimeManager.season_changed to a non-spring
## season). Replaces the old raw HUD message + menu_9/menu_0 key handling.
## Opened directly via show_summary(), not through the normal interact path -
## there is nothing to interact with once the season is over.

const MENU_ID := "season_summary"
const LAYER := 20

## world_bible.md Section X ("Season-End Summary: Success"/"...Failure") -
## Hilda's locked lines, her question-tic intact either way. The "markedly
## successful season" variant the bible offers beyond these two is
## explicitly noted there as "beyond the locked scope" - not wired here.
const HILDA_LINE_SUCCESS := "\"Paid in full, was it? Didn't I say you had it in you?\""
const HILDA_LINE_FAILURE := "\"Some seasons are like that, aren't they? You'll still have a bed and a bowl here. The land's not going anywhere.\""

var _stats_label: Label
var _hilda_label: Label


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = LAYER
	visible = false
	add_child(UIKit.make_fullscreen_backdrop())
	var center := UIKit.make_centered_container()
	add_child(center)
	var frame := UIKit.make_vbox(6)
	center.add_child(frame)
	frame.add_child(UIKit.make_label("Spring is Over", 28))
	_stats_label = UIKit.make_label("")
	frame.add_child(_stats_label)
	_hilda_label = UIKit.make_label("")
	frame.add_child(_hilda_label)
	var restart_button := UIKit.make_button("Restart")
	restart_button.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().reload_current_scene())
	frame.add_child(restart_button)
	var quit_button := UIKit.make_button("Quit")
	quit_button.pressed.connect(func() -> void:
		get_tree().quit())
	frame.add_child(quit_button)


func show_summary() -> void:
	var progress := TitheManager.get_tithe_progress()
	var paid: float = progress.get("paid", 0.0)
	var goal: float = progress.get("goal", 0)
	_stats_label.text = "Tithe: %d/%d\nCrops harvested: %d\nCoin earned: %d" % [
		int(paid), int(goal), PlayerState.total_crops_harvested, PlayerState.total_coins_earned]
	_hilda_label.text = "Hilda: %s" % (HILDA_LINE_SUCCESS if paid >= goal else HILDA_LINE_FAILURE)
	visible = true
	get_tree().paused = true
	UIManager.open_menu(MENU_ID)
