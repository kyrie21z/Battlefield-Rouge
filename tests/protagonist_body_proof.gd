extends Node
## Proof frames for the grey-white crystal protagonist body: front / three-quarter
## / side views with normal shadow casting, then the same body SHADOWS_ONLY while
## running. Needs a real display:
##   godot --path . res://tests/protagonist_body_proof.tscn -- --out=<dir>
## Default output is docs/proof/protagonist-body. Quits 0 after the four JPGs.

const BODY_SCENE := "res://actors/player/protagonist_body.tscn"
const MATERIAL: Material = preload("res://assets/materials/protagonist_crystal_material.tres")
const STILLS := [
	{"file": "01_front.jpg", "from": Vector3(0.0, 0.9, -4.2)},
	{"file": "02_three_quarter.jpg", "from": Vector3(-2.8, 1.05, -3.0)},
	{"file": "03_side.jpg", "from": Vector3(-4.2, 0.9, 0.0)},
]
const LOOK_AT := Vector3(0.0, 0.88, 0.0)
## Run pose grabbed mid-stride, in seconds into the 0.567 s clip.
const RUN_POSE_SECONDS := 0.4

var _out_dir := "res://docs/proof/protagonist-body"
var _body: Node3D
var _anim: AnimationPlayer
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
	_body = load(BODY_SCENE).instantiate()
	add_child(_body)
	_apply_material()
	for node in _body.find_children("*", "AnimationPlayer", true, false):
		_anim = node as AnimationPlayer
		break
	_cam = Camera3D.new()
	_cam.fov = 35.0
	add_child(_cam)
	_cam.current = true
	await _frames(3)

	_set_shadows(GeometryInstance3D.SHADOW_CASTING_SETTING_ON)
	_pose("idle", 0.8)
	for shot in STILLS:
		_cam.position = shot["from"]
		_cam.look_at(LOOK_AT)
		await _frames(5)
		await _shot(shot["file"])

	_set_shadows(GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY)
	_pose("run", RUN_POSE_SECONDS)
	_cam.fov = 42.0
	_cam.position = Vector3(0.9, 1.15, 1.2)
	_cam.look_at(Vector3(-0.3, 0.0, 0.55))
	await _frames(5)
	await _shot("04_shadow_run.jpg")

	print("PROTAGONIST BODY PROOF: saved 4 images to %s" % _out_dir)
	get_tree().quit(0)


func _pose(clip: String, seconds: float) -> void:
	_anim.stop()
	_anim.play(clip)
	_anim.seek(seconds, true)
	_anim.pause()


func _apply_material() -> void:
	var shadow_caster := StandardMaterial3D.new()
	shadow_caster.albedo_color = Color(0.80, 0.81, 0.83)
	for node in _body.find_children("*", "MeshInstance3D", true, false):
		var mi := node as MeshInstance3D
		mi.material_override = shadow_caster
		mi.material_overlay = MATERIAL


func _set_shadows(mode: GeometryInstance3D.ShadowCastingSetting) -> void:
	for node in _body.find_children("*", "MeshInstance3D", true, false):
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
	var key := DirectionalLight3D.new()
	key.light_energy = 1.6
	key.light_color = Color(0.95, 0.97, 1.0)
	key.rotation_degrees = Vector3(-55.0, 155.0, 0.0)
	key.shadow_enabled = true
	add_child(key)

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
