extends Node3D
## Native-engine turntable. 1/2/3: inspect a variant, 0: lineup, Space: cast pose.
## --shot=<absolute file> captures a real rendered frame then exits.
var _camera: Camera3D
var _specimens: Array[SlothVisual] = []
var _shot := ""
var _frames := 0
var _selection := -1
var _cast := false
var _yaw := 0.0
var _distance := 4.7


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.028, 0.035, 0.046)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.68, 0.76, 0.9)
	env.ambient_light_energy = 1.05
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	environment.environment = env
	add_child(environment)
	for info in [[Vector3(-4,6,-5), Color(1.0,0.87,0.75), 2.2],
		[Vector3(4,4,2), Color(0.55,0.74,1), 2.8]]:
		var light := OmniLight3D.new()
		light.position = info[0]
		light.light_color = info[1]
		light.light_energy = info[2]
		light.omni_range = 16
		light.shadow_enabled = true
		add_child(light)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(200,200)
	floor_mesh.mesh = plane
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.09,0.105,0.12)
	floor_mat.roughness = 0.78
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)
	var names := ["THE LINGERER", "THE ANCHOR", "THE RECLUSE"]
	var subtitles := ["DELAY / TORN MANTLE", "INERTIA / BOUND HALO", "WITHDRAWAL / SPLIT COCOON"]
	for i in 3:
		var specimen := SlothVisual.new()
		specimen.configure(i)
		specimen.position = Vector3((1 - i) * 2.7, 0.13, 0)
		add_child(specimen)
		specimen.rotation.y = -0.12 if i == 0 else 0.12
		_specimens.append(specimen)
		var pedestal := MeshInstance3D.new()
		var cylinder := CylinderMesh.new()
		cylinder.top_radius = 1.0
		cylinder.bottom_radius = 1.03
		cylinder.height = 0.12
		cylinder.radial_segments = 64
		pedestal.mesh = cylinder
		pedestal.material_override = floor_mat
		pedestal.position = Vector3((1 - i)*2.7,0.06,0)
		add_child(pedestal)
		_label(names[i], Vector3((1-i)*2.7, -0.04,-1.05), 36, Color(0.96,0.93,0.9))
		_label(subtitles[i], Vector3((1-i)*2.7,-0.28,-1.05), 18, Color(0.54,0.64,0.72))
	_label("S L O T H   /   R E D   C R Y S T A L   C O V E N", Vector3(0,3.0,0), 30, Color(0.8,0.83,0.87))
	_label("01   /   ENEMY STUDIES     —     IN-ENGINE MODELS", Vector3(0,2.75,0), 17, Color(0.45,0.55,0.65))
	_camera = Camera3D.new()
	_camera.fov = 39
	add_child(_camera)
	_camera.make_current()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--shot="):
			_shot = arg.trim_prefix("--shot=")
		if arg.begins_with("--kind="):
			_selection = int(arg.trim_prefix("--kind="))
		if arg == "--rear":
			_yaw = PI
		if arg == "--cast":
			_cast = true
	_update_camera()


func _label(text: String, pos: Vector3, size: int, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.004
	label.position = pos
	label.modulate = color
	label.no_depth_test = true
	label.outline_size = 0
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_1,KEY_2,KEY_3]:
			_selection = event.keycode - KEY_1
		elif event.keycode == KEY_0:
			_selection = -1
		elif event.keycode == KEY_SPACE:
			_cast = not _cast
		_update_camera()
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_yaw += event.relative.x * 0.008
		_update_camera()
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = maxf(2.0, _distance - 0.3)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = minf(8.0, _distance + 0.3)
		_update_camera()


func _update_camera() -> void:
	for label in find_children("*", "Label3D", false, false):
		(label as Label3D).visible = _selection < 0
	var center := Vector3(0,1.35,0)
	var distance := 9.6
	if _selection >= 0 and _selection < 3:
		center = _specimens[_selection].position + Vector3.UP * 1.0
		distance = _distance
	_camera.position = center + Vector3(sin(_yaw)*distance,0.6,-cos(_yaw)*distance)
	_camera.look_at(center)


func _process(_delta: float) -> void:
	_frames += 1
	for specimen in _specimens:
		specimen.set_cast(0.8 if _cast else 0.0)
		specimen.set_shell_open(1.0 if _cast else 0.0)
	if _frames == 90 and not _shot.is_empty():
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(_shot)
		print("SLOTH GALLERY: captured ", _shot)
		get_tree().quit()
