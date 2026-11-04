

extends SceneTree

## Offline visual-proof capture for the current farmhouse integration. This
## runs the shipped main scene and writes the live viewport after its first
## rendered frames; it does not alter save data or gameplay state.

const OUTPUT_PATH := "res://asset_studio/reviews/farmhouse_4x3_in_game.png"
const MAIN_SCENE := "res://scenes/main.tscn"
const SETTLE_FRAMES: int = 8


func _initialize() -> void:
	_capture.call_deferred()


func _capture() -> void:
	var scene_error := change_scene_to_file(MAIN_SCENE)
	if scene_error != OK:
		printerr("Could not load main scene: %s" % error_string(scene_error))
		quit(1)
		return
	for frame_index: int in range(SETTLE_FRAMES):
		var unused_frame_index := frame_index
		await process_frame
	# The assisted-interaction diamond can cover most of a doorway at this
	# scale. Disable only that presentation node so the proof shows the
	# authored door rather than the player's temporary targeting feedback.
	var active_scene: Node = current_scene
	if active_scene != null:
		var indicator: Variant = active_scene.get("target_indicator")
		if indicator is CanvasItem:
			(indicator as Node).set_process(false)
			(indicator as CanvasItem).visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	var viewport_image := root.get_texture().get_image()
	if viewport_image == null or viewport_image.is_empty():
		printerr("Viewport capture returned an empty image")
		quit(1)
		return
	var absolute_output := ProjectSettings.globalize_path(OUTPUT_PATH)
	var output_dir := absolute_output.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(output_dir) != OK:
		printerr("Could not create capture directory: %s" % output_dir)
		quit(1)
		return
	var save_error := viewport_image.save_png(absolute_output)
	if save_error != OK:
		printerr("Could not save viewport capture: %s" % error_string(save_error))
		quit(1)
		return
	print("Wrote %s" % absolute_output)
	quit(0)




