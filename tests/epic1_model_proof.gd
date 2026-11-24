extends Node
## Native Godot model review: authored GLB silhouettes, facets and the reload pose.

enum Pose { REST, BLOOM, KICK }

const PANEL_SIZE := Vector2i(500, 600)
const PISTOL := preload("res://weapons/obsidian_pistol/obsidian_pistol_view.tscn")
const BLADE := preload("res://weapons/mind_blade/mind_blade_view.tscn")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Model proof requires native rendering")
		get_tree().quit(1)
		return
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tools/epic1_models/manifest.json"))
	var pistol: Dictionary = manifest.models[0]
	var blade: Dictionary = manifest.models[1]
	var jobs := [
		[PISTOL, Vector3(2, 0, 0), Pose.REST, "黑晶手枪 · 侧面", _dimensions(pistol)],
		[PISTOL, Vector3(0.96, 0.55, -0.74), Pose.REST, "黑晶手枪 · 四分之三",
			"%d mm 枪口凹深" % roundi(pistol.muzzle_recess_depth_m * 1000)],
		[PISTOL, Vector3(0.034, 0.074, 0.30), Pose.REST, "黑晶手枪 · 照门", _counts(pistol), true],
		[PISTOL, Vector3(-0.86, 0.23, 0.44), Pose.BLOOM, "黑晶手枪 · 绽放", "四块独立枢轴"],
		[BLADE, Vector3(2, 0, 0), Pose.REST, "意志短刃 · 侧面", _counts(blade)],
		[PISTOL, Vector3(-0.9, 0.24, -0.28), Pose.KICK, "黑晶手枪 · 退滑", "32 mm 退滑露出晶核"],
	]
	const COLUMNS := 3
	var strip := Image.create(PANEL_SIZE.x * COLUMNS, PANEL_SIZE.y * 2, false, Image.FORMAT_RGB8)
	for i in jobs.size():
		var panel := await _render(jobs[i])
		var cell := Vector2i(i % COLUMNS, i / COLUMNS)
		strip.blit_rect(panel, Rect2i(Vector2i.ZERO, PANEL_SIZE), cell * PANEL_SIZE)
	var folder := "res://docs/proof/epic1"
	DirAccess.make_dir_recursive_absolute(folder)
	var result := strip.save_png(folder + "/models.png")
	print("MODEL PROOF: %s" % error_string(result))
	get_tree().quit(0 if result == OK else 1)


func _counts(model: Dictionary) -> String:
	return "%d 源多边形 / %d 三角面" % [model.source_polygons, model.glb_triangles]


func _dimensions(model: Dictionary) -> String:
	var xyz: Array = model.bounds_game.size
	return "%d × %d × %d mm（长 × 高 × 宽）" % [
		roundi(xyz[2] * 1000), roundi(xyz[1] * 1000), roundi(xyz[0] * 1000)]


func _render(job: Array) -> Image:
	var viewport := SubViewport.new()
	viewport.size = PANEL_SIZE
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.94, 0.96, 0.99)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65, 0.72, 0.85)
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	world.add_child(environment)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-32, -42, 0)
	key.light_energy = 1.5
	key.light_specular = 0.4
	world.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(28, 132, 0)
	fill.light_color = Color(0.88, 0.94, 1.0)
	fill.light_energy = 0.8
	fill.light_specular = 0.3
	world.add_child(fill)
	var model: Node3D = (job[0] as PackedScene).instantiate()
	world.add_child(model)
	var pose: Pose = job[2]
	if pose == Pose.BLOOM:
		model.set_reassembly_progress(0.5)
	elif pose == Pose.KICK:
		model.kick_fire()
		model.set_process(false)
	var bounds := AABB()
	var first := true
	for found in model.find_children("*", "MeshInstance3D", true, false):
		var part := found as MeshInstance3D
		if not part.is_visible_in_tree():
			continue
		var box := part.global_transform * part.mesh.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 0.28
	match pose:
		Pose.BLOOM:
			camera.size = 0.47
		Pose.KICK:
			camera.size = 0.33
	if job[0] == BLADE:
		camera.size = 0.56
	camera.near = 0.01
	world.add_child(camera)
	var target := bounds.get_center() + Vector3.UP * 0.020
	if job.size() > 5 and job[5]:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = 45.0
		target = Vector3(0, 0.052, -0.027)
	camera.position = target + (job[1] as Vector3)
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var heading := Label.new()
	heading.position = Vector2(24, 22)
	heading.text = str(job[3])
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.12, 0.14, 0.18))
	overlay.add_child(heading)
	var caption := Label.new()
	caption.position = Vector2(24, 63)
	caption.text = str(job[4])
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(0.27, 0.31, 0.39))
	overlay.add_child(caption)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGB8)
	viewport.queue_free()
	await get_tree().process_frame
	return result
