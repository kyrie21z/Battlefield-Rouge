extends Node
## Proof frames for the grey-white crystal protagonist body: front / three-quarter
## / side views with normal shadow casting while it holds the pistol in the aim
## pose, the same body SHADOWS_ONLY running and standing with the gun, and
## close-up side / top strips of the upper body with the equipped pistol.
## Needs a real display:
##   godot --path . res://tests/protagonist_body_proof.tscn -- --out=<dir>
## Default output is docs/proof/protagonist-body. Quits 0 after the seven JPGs.

const PLAYER_SCENE := "res://actors/player/player.tscn"
const STILLS := [
	{"file": "01_front.jpg", "from": Vector3(0.0, 0.9, -4.2)},
	{"file": "02_three_quarter.jpg", "from": Vector3(-2.8, 1.05, -3.0)},
	{"file": "03_side.jpg", "from": Vector3(-4.2, 0.9, 0.0)},
]
const LOOK_AT := Vector3(0.0, 0.88, 0.0)
## The stage equips one pistol; keep the old shadow-only rig until #105.
const GUN_SLOTS := 1
const PANEL_WIDTH := 800


var _out_dir := "res://docs/proof/protagonist-body"
var _key: DirectionalLight3D
var _player: Player
var _shadow: Node3D
var _cam: Camera3D


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("protagonist body proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	_build_environment()
	_build_floor()
	# The whole player, so the shadow body finds its weapon and the gun shows.
	_player = load(PLAYER_SCENE).instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.global_position = Vector3.ZERO
	_player.velocity = Vector3.ZERO
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# The first-person viewmodels sit in the world at head height; the camera
	# here is not the player's, so they would float in the frame.
	(_player.get_node("Head") as Node3D).visible = false
	_shadow = _player.get_node("ShadowBody") as Node3D
	_shadow.set_process(false)
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_cam.current = true
	await _frames(3)

	_set_shadows(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	for shot in STILLS:
		_cam.position = shot["from"]
		_cam.look_at(LOOK_AT)
		await _frames(5)
		await _shot(shot["file"])

	# Running: the legs blend onto `run` while the upper body keeps aiming.
	# The ground shots raise the key almost overhead, which keeps the shadow a
	# readable figure instead of a long smear, and look straight down at it.
	_set_shadows(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_key.rotation_degrees = Vector3(-80.0, 155.0, 0.0)
	_cam.fov = 27.0
	_cam.position = Vector3(0.55, 2.4, 1.5)
	_cam.look_at(Vector3(0.1, 0.0, 0.2))
	_player.velocity = Vector3(0.0, 0.0, 3.0)
	_shadow._process(0.2)
	await _frames(24)
	await _shot("04_shadow_run.jpg")

	# Standing again, same shadow view.
	_player.velocity = Vector3.ZERO
	_shadow._process(0.2)
	await _frames(10)
	await _shot("05_shadow_idle.jpg")

	# Close-ups so the gun placement can be judged: one strip per view, one
	# panel per gun, in weapon order.
	await _gun_strip("06_guns_side.jpg", "side")
	await _gun_strip("07_guns_top.jpg", "top")

	print("PROTAGONIST BODY PROOF: saved 7 images to %s" % _out_dir)
	get_tree().quit(0)


## Renders the upper body with each gun and stitches the panels side by side.
func _gun_strip(file: String, view: String) -> void:
	var weapon := _player.get_node("Head/Camera3D/Weapon") as Weapon
	var panels: Array[Image] = []
	# Looking straight down, the whole frame is the light floor; a dark sheet
	# under the upper body keeps the white figure readable.
	var backdrop: MeshInstance3D
	if view == "top":
		backdrop = _dark_sheet()
	for slot in GUN_SLOTS:
		weapon.select(slot)
		await get_tree().process_frame
		_set_shadows(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
		if view == "side":
			_cam.fov = 36.0
			_cam.position = Vector3(-1.80, 1.58, -0.28)
			_cam.look_at(Vector3(0.02, 1.40, -0.28))
		else:
			_cam.fov = 32.0
			_cam.look_at_from_position(Vector3(0.03, 3.5, -0.40),
				Vector3(0.03, 1.4, -0.40), Vector3(0.0, 0.0, -1.0))
		await _frames(4)
		await RenderingServer.frame_post_draw
		panels.append(get_viewport().get_texture().get_image())
	var panel_height := PANEL_WIDTH * panels[0].get_height() / panels[0].get_width()
	var strip := Image.create(PANEL_WIDTH * panels.size(), panel_height, false, Image.FORMAT_RGB8)
	for i in panels.size():
		var panel: Image = panels[i]
		panel.resize(PANEL_WIDTH, panel_height, Image.INTERPOLATE_LANCZOS)
		strip.blit_rect(panel, Rect2i(0, 0, PANEL_WIDTH, panel_height),
			Vector2i(PANEL_WIDTH * i, 0))
	var path := _out_dir.path_join(file)
	var err := strip.save_jpg(path, 0.92)
	print("[proof] %s -> %s (%s)" % [file, path, error_string(err)])
	if backdrop != null:
		backdrop.queue_free()


func _dark_sheet() -> MeshInstance3D:
	var sheet := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(6.0, 6.0)
	sheet.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.12, 0.13, 0.15)
	material.roughness = 1.0
	sheet.material_override = material
	sheet.position = Vector3(0.0, 0.002, 0.0)
	sheet.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(sheet)
	return sheet


func _set_shadows(mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for node in _shadow.find_children("*", "MeshInstance3D", true, false):
		(node as MeshInstance3D).cast_shadow = mode


func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var path := _out_dir.path_join(file)
	var err := get_viewport().get_texture().get_image().save_jpg(path, 0.9)
	print("[proof] %s -> %s (%s)" % [file, path, error_string(err)])


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame


func _build_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.14, 0.15, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.66, 0.68, 0.72)
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment = env
	add_child(world)

	# Key from the model's front-right, so the 01 front view is lit and the
	# run shadow falls to -X +Z, where the 04 camera looks.
	_key = DirectionalLight3D.new()
	_key.light_energy = 1.6
	_key.light_color = Color(0.95, 0.97, 1.0)
	_key.rotation_degrees = Vector3(-55.0, 155.0, 0.0)
	_key.shadow_enabled = true
	add_child(_key)

	var fill := DirectionalLight3D.new()
	fill.light_energy = 0.45
	fill.light_color = Color(0.78, 0.84, 1.0)
	fill.rotation_degrees = Vector3(-25.0, -35.0, 0.0)
	add_child(fill)


func _build_floor() -> void:
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.45, 0.46, 0.47)
	material.roughness = 0.9
	floor_mesh.material_override = material
	floor_mesh.position = Vector3(0.0, -0.001, 0.0)
	floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(floor_mesh)
