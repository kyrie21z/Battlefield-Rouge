extends Node3D
## Throwaway preview: drops the real BuffPedestal into a lit room with a fake
## player so the orb can be eyeballed without clearing a whole zone first.
## The scene saves its own PNGs and quits, so no external screenshot tool is needed.
##
## Run with:  godot --path . res://tests/talent_orb_preview.tscn

const OUT_DIR := "res://docs/proof/talent-orb"
const SHOT_FRAMES: Array[int] = [50, 110, 170]

var _pedestal: BuffPedestal
var _fake_player: Node3D
var _camera: Camera3D
var _angle := 0.0
var _frame := 0
var _shot := 0


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_build_room()


func _build_room() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.045, 0.05, 0.065)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.6, 0.75)
	e.ambient_light_energy = 1.4
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_hdr_threshold = 1.3
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46, 36, 0)
	key.light_energy = 2.6
	key.shadow_enabled = true
	add_child(key)

	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12, -150, 0)
	rim.light_energy = 1.3
	rim.light_color = Color(0.6, 0.7, 1.0)
	add_child(rim)

	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(16, 16)
	floor_mesh.mesh = plane
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.07, 0.075, 0.09)
	fm.roughness = 0.95
	floor_mesh.material_override = fm
	add_child(floor_mesh)

	_fake_player = Node3D.new()
	_fake_player.name = "FakePlayer"
	_fake_player.position = Vector3(0, 0, 3.4)
	add_child(_fake_player)

	_pedestal = BuffPedestal.new()
	_pedestal.name = "BuffPedestal"
	_pedestal.set_player(_fake_player)
	add_child(_pedestal)
	_pedestal.global_position = Vector3.ZERO
	_pedestal.show_reward_theme(Color(1.0, 0.62, 0.18))

	_camera = Camera3D.new()
	_camera.fov = 50.0
	_camera.near = 0.03
	add_child(_camera)
	_camera.current = true
	_look(0.0)


func _look(extra: float) -> void:
	# stand where the fake player stands, then orbit a little so the mouth-facing
	# behaviour is visible: the orb should keep turning back toward us
	var a := deg_to_rad(10.0) + extra
	_fake_player.position = Vector3(sin(a) * 3.2, 0.0, cos(a) * 3.2)
	_camera.global_position = _fake_player.position + Vector3(0, 1.55, 0)
	_camera.look_at(Vector3(0, 1.32, 0), Vector3.UP)


func _process(delta: float) -> void:
	_frame += 1
	_angle += delta * 0.28
	_look(_angle)

	if _shot < SHOT_FRAMES.size() and _frame >= SHOT_FRAMES[_shot]:
		_shot += 1
		var img := get_viewport().get_texture().get_image()
		var path := "%s/preview-%d.png" % [OUT_DIR, _shot]
		img.save_png(path)
		print("SAVED ", ProjectSettings.globalize_path(path))
		if _shot >= SHOT_FRAMES.size():
			await get_tree().process_frame
			get_tree().quit()
