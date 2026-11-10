extends Node
## Native Godot model review: authored GLB silhouettes, facets and the reload pose.

const PANEL_SIZE := Vector2i(500, 600)
const PISTOL := preload("res://weapons/obsidian_pistol/obsidian_pistol_view.tscn")


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Model proof requires native rendering")
		get_tree().quit(1)
		return
	var jobs := [
		[PISTOL, Vector3(2, 0, 0), false, "黑晶手枪 · 侧面", "120 源多边形 / 180 三角面 · 220 mm"],
		[PISTOL, Vector3(0.9, 0.5, -0.9), false, "黑晶手枪 · 四分之三", "220 × 135 × 32 mm · 内凹六角枪口"],
	]
	var strip := Image.create(PANEL_SIZE.x * jobs.size(), PANEL_SIZE.y, false, Image.FORMAT_RGB8)
	for i in jobs.size():
		var panel := await _render(jobs[i])
		strip.blit_rect(panel, Rect2i(Vector2i.ZERO, PANEL_SIZE), Vector2i(i * PANEL_SIZE.x, 0))
	var folder := "res://docs/proof/issue-101"
	DirAccess.make_dir_recursive_absolute(folder)
	var result := strip.save_png(folder + "/models.png")
	print("MODEL PROOF: %s" % error_string(result))
	get_tree().quit(0 if result == OK else 1)


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
	settings.background_color = Color(0.055, 0.065, 0.082)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color(0.65, 0.72, 0.85)
	settings.ambient_light_energy = 0.6
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
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
	if job[2]:
		model.set_reassembly_progress(0.5)
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
	camera.size = 0.46 if job[2] else (0.38 if job[0] == PISTOL else 0.56)
	camera.near = 0.01
	world.add_child(camera)
	var target := bounds.get_center() + Vector3.UP * 0.035
	camera.position = target + (job[1] as Vector3)
	camera.look_at(target, Vector3.UP)
	camera.make_current()
	var overlay := CanvasLayer.new()
	viewport.add_child(overlay)
	var heading := Label.new()
	heading.position = Vector2(24, 22)
	heading.text = str(job[3])
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	overlay.add_child(heading)
	var caption := Label.new()
	caption.position = Vector2(24, 63)
	caption.text = str(job[4])
	caption.add_theme_font_size_override("font_size", 17)
	caption.add_theme_color_override("font_color", Color(0.65, 0.72, 0.83))
	overlay.add_child(caption)
	for frame in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var result := viewport.get_texture().get_image()
	result.convert(Image.FORMAT_RGB8)
	viewport.queue_free()
	await get_tree().process_frame
	return result
