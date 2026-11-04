extends SceneTree
## Offline feasibility proof for 3D-authored, 2D-runtime structures.
##
## Builds one low-detail 4x2 farmhouse from primitive meshes, renders it
## through an orthographic camera mathematically matched to IsoProjection,
## verifies projected unit vectors, and saves a transparent PNG. Nothing from
## this temporary 3D world enters gameplay or a shipped scene.

const OUTPUT_PATH := "res://asset_studio/3d_proof/farmhouse_blockout.png"
const REPORT_PATH := "res://asset_studio/3d_proof/farmhouse_blockout.json"
const VIEWPORT_SIZE := Vector2i(1024, 1024)
const SOURCE_SCALE := 4.0
const FOOTPRINT := Vector2(4.0, 2.0)
const WALL_HEIGHT := 1.25
const FOUNDATION_HEIGHT := 0.28
const ROOF_RISE := 0.40
const ROOF_OVERHANG := 0.20
const CAMERA_DISTANCE := 12.0
const PROJECTION_TOLERANCE_PX := 0.35


func _initialize() -> void:
	call_deferred("_build_and_render")


func _build_and_render() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://asset_studio/3d_proof"))
	var viewport := SubViewport.new()
	viewport.name = "StructureProofViewport"
	viewport.size = VIEWPORT_SIZE
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var world_root := Node3D.new()
	world_root.name = "FarmhouseBlockout"
	viewport.add_child(world_root)
	_build_farmhouse(world_root)
	_add_lighting(world_root)

	var camera := Camera3D.new()
	camera.name = "DimetricCamera"
	viewport.add_child(camera)
	_configure_camera(camera)
	camera.current = true

	# The viewport and RenderingServer each need a frame after entering the tree
	# before Camera3D projection queries and texture readback are authoritative.
	await process_frame
	await RenderingServer.frame_post_draw
	var report := _projection_report(camera)
	if not bool(report["passed"]):
		push_error("3D proof camera does not match IsoProjection: %s" % JSON.stringify(report))
		quit(2)
		return

	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	if image == null or image.is_empty():
		push_error("3D proof viewport returned an empty image")
		quit(2)
		return
	var save_error := image.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if save_error != OK:
		push_error("Could not save 3D proof PNG: %s" % error_string(save_error))
		quit(2)
		return
	var report_file := FileAccess.open(REPORT_PATH, FileAccess.WRITE)
	if report_file == null:
		push_error("Could not save 3D proof report")
		quit(2)
		return
	report["output"] = OUTPUT_PATH
	report["viewport_size"] = [VIEWPORT_SIZE.x, VIEWPORT_SIZE.y]
	report["footprint_cells"] = [int(FOOTPRINT.x), int(FOOTPRINT.y)]
	report_file.store_string(JSON.stringify(report, "\t") + "\n")
	report_file.close()
	print("3D structure proof passed: %s" % JSON.stringify(report))
	quit(0)


func _build_farmhouse(parent: Node3D) -> void:
	var plaster := _material(Color("d9c397"))
	var timber := _material(Color("74421f"))
	var timber_dark := _material(Color("412515"))
	var stone := _material(Color("777064"))
	var thatch := _material(Color("d99a2b"))
	var thatch_dark := _material(Color("8d5522"))
	var glass := _material(Color("4d8294"))

	_add_box(parent, "Foundation", Vector3(2.0, FOUNDATION_HEIGHT * 0.5, 1.0),
		Vector3(FOOTPRINT.x, FOUNDATION_HEIGHT, FOOTPRINT.y), stone)
	var wall_base := FOUNDATION_HEIGHT
	var wall_mesh_height := WALL_HEIGHT - wall_base
	_add_box(parent, "WallMass", Vector3(2.0, wall_base + wall_mesh_height * 0.5, 1.0),
		Vector3(FOOTPRINT.x - 0.12, wall_mesh_height, FOOTPRINT.y - 0.12), plaster)

	for x: float in [0.06, FOOTPRINT.x - 0.06]:
		for z: float in [0.06, FOOTPRINT.y - 0.06]:
			_add_box(parent, "CornerPost", Vector3(x, wall_base + wall_mesh_height * 0.5, z),
				Vector3(0.16, wall_mesh_height, 0.16), timber)
	_add_box(parent, "SouthSill", Vector3(2.0, wall_base + 0.07, FOOTPRINT.y - 0.02),
		Vector3(FOOTPRINT.x, 0.14, 0.14), timber_dark)
	_add_box(parent, "SouthPlate", Vector3(2.0, WALL_HEIGHT - 0.08, FOOTPRINT.y - 0.02),
		Vector3(FOOTPRINT.x, 0.16, 0.14), timber_dark)
	_add_box(parent, "EastSill", Vector3(FOOTPRINT.x - 0.02, wall_base + 0.07, 1.0),
		Vector3(0.14, 0.14, FOOTPRINT.y), timber_dark)
	_add_box(parent, "EastPlate", Vector3(FOOTPRINT.x - 0.02, WALL_HEIGHT - 0.08, 1.0),
		Vector3(0.14, 0.16, FOOTPRINT.y), timber_dark)

	# The fixed exterior door remains on the third South cell, matching the
	# existing logical door tile after the footprint expands west.
	_add_box(parent, "SouthDoor", Vector3(2.52, wall_base + 0.49, FOOTPRINT.y + 0.035),
		Vector3(0.62, 0.98, 0.08), timber)
	_add_box(parent, "DoorLintel", Vector3(2.52, wall_base + 1.00, FOOTPRINT.y + 0.075),
		Vector3(0.76, 0.12, 0.10), timber_dark)
	_add_box(parent, "EastWindow", Vector3(FOOTPRINT.x + 0.035, 0.80, 1.04),
		Vector3(0.08, 0.46, 0.58), glass)
	_add_box(parent, "WindowTop", Vector3(FOOTPRINT.x + 0.075, 1.06, 1.04),
		Vector3(0.10, 0.10, 0.72), timber_dark)
	_add_box(parent, "WindowBottom", Vector3(FOOTPRINT.x + 0.075, 0.54, 1.04),
		Vector3(0.10, 0.10, 0.72), timber_dark)
	_add_box(parent, "WindowNorthShutter", Vector3(FOOTPRINT.x + 0.075, 0.80, 0.68),
		Vector3(0.10, 0.50, 0.16), timber)
	_add_box(parent, "WindowSouthShutter", Vector3(FOOTPRINT.x + 0.075, 0.80, 1.40),
		Vector3(0.10, 0.50, 0.16), timber)

	var roof := MeshInstance3D.new()
	roof.name = "GabledThatchRoof"
	roof.mesh = _roof_mesh(thatch)
	parent.add_child(roof)
	_add_box(parent, "RidgeCap", Vector3(2.0, WALL_HEIGHT + ROOF_RISE + 0.05, 1.0),
		Vector3(FOOTPRINT.x + ROOF_OVERHANG * 2.0, 0.12, 0.16), thatch_dark)


func _add_lighting(parent: Node3D) -> void:
	var environment_node := WorldEnvironment.new()
	environment_node.name = "ProofEnvironment"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("d9c79f")
	environment.ambient_light_energy = 0.72
	environment_node.environment = environment
	parent.add_child(environment_node)

	var light := DirectionalLight3D.new()
	light.name = "WarmKeyLight"
	light.light_color = Color("ffe0ad")
	light.light_energy = 1.15
	light.rotation_degrees = Vector3(-52.0, -38.0, 0.0)
	light.shadow_enabled = false
	parent.add_child(light)


func _configure_camera(camera: Camera3D) -> void:
	# Camera elevation is derived from the projection ratio: each logical axis
	# projects 32px horizontally and 24px vertically, so sin(elevation)=24/32.
	var elevation := asin(IsoProjection.TILE_H / IsoProjection.TILE_W)
	var horizontal := cos(elevation) / sqrt(2.0)
	var direction := Vector3(horizontal, sin(elevation), horizontal)
	var target := Vector3(FOOTPRINT.x * 0.5, 0.72, FOOTPRINT.y * 0.5)
	camera.position = target + direction * CAMERA_DISTANCE
	camera.look_at(target, Vector3.UP)
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	var pixels_per_world := (IsoProjection.TILE_W * 0.5 * SOURCE_SCALE) / (1.0 / sqrt(2.0))
	camera.set_orthogonal(float(VIEWPORT_SIZE.y) / pixels_per_world, 0.05, 40.0)


func _projection_report(camera: Camera3D) -> Dictionary:
	var origin := camera.unproject_position(Vector3.ZERO)
	var east := camera.unproject_position(Vector3(1.0, 0.0, 0.0))
	var south := camera.unproject_position(Vector3(0.0, 0.0, 1.0))
	var east_delta := east - origin
	var south_delta := south - origin
	var expected_east := Vector2(IsoProjection.TILE_W * 0.5, IsoProjection.TILE_H * 0.5) * SOURCE_SCALE
	var expected_south := Vector2(-IsoProjection.TILE_W * 0.5, IsoProjection.TILE_H * 0.5) * SOURCE_SCALE
	var east_error := east_delta.distance_to(expected_east)
	var south_error := south_delta.distance_to(expected_south)
	return {
		"passed": east_error <= PROJECTION_TOLERANCE_PX and south_error <= PROJECTION_TOLERANCE_PX,
		"east_delta_px": [east_delta.x, east_delta.y],
		"south_delta_px": [south_delta.x, south_delta.y],
		"expected_east_px": [expected_east.x, expected_east.y],
		"expected_south_px": [expected_south.x, expected_south.y],
		"east_error_px": east_error,
		"south_error_px": south_error,
	}


func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 1.0
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return material


func _add_box(parent: Node3D, node_name: String, position: Vector3, size: Vector3,
		material: Material) -> void:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	instance.position = position
	parent.add_child(instance)


func _roof_mesh(material: Material) -> ArrayMesh:
	var x0 := -ROOF_OVERHANG
	var x1 := FOOTPRINT.x + ROOF_OVERHANG
	var z0 := -ROOF_OVERHANG
	var z1 := FOOTPRINT.y + ROOF_OVERHANG
	var ridge_z := FOOTPRINT.y * 0.5
	var eave_y := WALL_HEIGHT
	var ridge_y := WALL_HEIGHT + ROOF_RISE
	var west_north := Vector3(x0, eave_y, z0)
	var west_ridge := Vector3(x0, ridge_y, ridge_z)
	var west_south := Vector3(x0, eave_y, z1)
	var east_north := Vector3(x1, eave_y, z0)
	var east_ridge := Vector3(x1, ridge_y, ridge_z)
	var east_south := Vector3(x1, eave_y, z1)
	var faces: Array[PackedVector3Array] = [
		PackedVector3Array([west_south, east_south, east_ridge]),
		PackedVector3Array([west_south, east_ridge, west_ridge]),
		PackedVector3Array([west_north, west_ridge, east_ridge]),
		PackedVector3Array([west_north, east_ridge, east_north]),
		PackedVector3Array([east_north, east_ridge, east_south]),
		PackedVector3Array([west_north, west_south, west_ridge]),
		PackedVector3Array([west_north, east_north, east_south]),
		PackedVector3Array([west_north, east_south, west_south]),
	]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface.set_material(material)
	for face: PackedVector3Array in faces:
		for vertex: Vector3 in face:
			surface.add_vertex(vertex)
	surface.generate_normals()
	return surface.commit()
