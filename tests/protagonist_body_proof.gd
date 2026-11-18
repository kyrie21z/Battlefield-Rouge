extends Node3D
## Native, production-player evidence: horizontal, torso/legs, gait and shadow.
## godot --path . res://tests/protagonist_body_proof.tscn -- --out=<directory>
var _out_dir := "res://docs/proof/epic1"
var _player: Player
var _body: Node3D

func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("Body awareness proof requires a renderer")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 900))
	_environment()
	_player = preload("res://actors/player/player.tscn").instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_body = _player.get_node("ShadowBody")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	await _frames(8)
	await _shot("body_forward.png")
	_player._pitch = deg_to_rad(-65.0)
	_player._apply_look()
	await _frames(5)
	await _shot("body_torso.png")
	_player._pitch = deg_to_rad(-88.0)
	_player._apply_look()
	await _frames(5)
	await _shot("body_0.png")
	_player.velocity = Vector3(0.0, 0.0, -3.0)
	await _frames(18)
	await _shot("body_walking_a.png")
	await _frames(20)
	await _shot("body_walking_b.png")
	_player.velocity = Vector3.ZERO
	_player._pitch = deg_to_rad(-65.0)
	_player._apply_look()
	for level in [1, 2, 3, 4]:
		_player._pitch = 0.0 if level == 1 else deg_to_rad(-88.0)
		_player._apply_look()
		_body.set_fracture_level(level)
		await _frames(5)
		await _shot("body_%d.png" % level)
	_body.set_fracture_level(0)
	_player._pitch = 0.0
	_player._apply_look()
	_player._pitch = deg_to_rad(80.0)
	_player._apply_look()
	await _frames(5)
	await _shot("body_aim_up.png")
	_player._pitch = 0.0
	_player._apply_look()
	_player.melee.swing_now()
	_advance_combat(0.14)
	await _frames(5)
	await _shot("body_melee.png")
	_advance_combat(0.35)
	# The same production nodes, with both presentation clocks advanced together:
	# settled 58-degree ADS, final body fracture and the middle of a real slash.
	_body.set_fracture_level(4)
	_player.weapon.aiming = true
	_advance_combat(1.0)
	await _frames(5)
	await _shot("body_ads_4.png")
	_player.melee.swing_now()
	_advance_combat(0.14)
	await _frames(5)
	await _shot("body_ads_melee_4.png")
	_advance_combat(0.35)
	_player.weapon.aiming = false
	_advance_combat(1.0)
	await _frames(10)
	await _shot("body_regripped_4.png")
	if not _player.weapon.try_fire():
		push_error("Could not fire the pistol for the recoil and reload proof")
		get_tree().quit(1)
		return
	_advance_combat(0.025)
	await _frames(1)
	await _shot("body_recoil_4.png")
	_player.weapon.try_reload()
	_advance_combat(0.43)
	await _frames(2)
	await _shot("body_reload_4.png")
	_advance_combat(0.5)
	_body.set_fracture_level(0)
	var camera := Camera3D.new()
	add_child(camera)
	camera.fov = 48.0
	camera.current = true
	var pistol := _player.weapon.grip_transform()
	var grip_center := pistol * Vector3(0.0, 0.02, 0.013)
	camera.look_at_from_position(pistol * Vector3(-0.37, 0.11, -0.16), grip_center)
	await _frames(5)
	await _shot("body_grip_detail.png")
	camera.look_at_from_position(pistol * Vector3(0.34, 0.10, -0.22), grip_center)
	await _frames(5)
	await _shot("body_right_grip_detail.png")
	_player.melee.swing_now()
	_advance_combat(0.14)
	var blade := _player.melee.grip_transform()
	camera.look_at_from_position(blade * Vector3(0.32, 0.15, -0.08), blade.origin)
	await _frames(5)
	await _shot("body_blade_grip_detail.png")
	_advance_combat(0.50)
	await _frames(10)
	camera.look_at_from_position(Vector3(-2.5, 1.5, -2.6), Vector3(0.0, 0.85, 0.0))
	# The head remains shadows-only in every first-person frame. This external
	# audit restores it only to show that the original full body is retained.
	var head_mesh := _body.find_child("GEO_m_head", true, false) as MeshInstance3D
	head_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	await _frames(5)
	await _shot("body_external.png")
	_body.set_fracture_level(4)
	await _frames(5)
	await _shot("body_full_4.png")
	_body.set_fracture_level(0)
	camera.look_at_from_position(Vector3(0.0, 3.5, 2.3), Vector3(0.0, 0.0, -0.6))
	await _frames(5)
	await _shot("body_shadow.png")
	print("BODY AWARENESS PROOF: complete")
	get_tree().quit()

func _advance_combat(seconds: float) -> void:
	var remaining := seconds
	while remaining > 0.000001:
		var step := minf(remaining, 1.0 / 120.0)
		# Scene order matches production: pistol presentation, then blade phase.
		_player.weapon._process(step)
		_player.melee._process(step)
		_player._process(step)
		remaining -= step

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame

func _shot(file: String) -> void:
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png(_out_dir.path_join(file))
	if error != OK:
		push_error("Could not save " + file)
		get_tree().quit(1)

func _environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.23)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.45
	world.environment = env
	add_child(world)
	var key := DirectionalLight3D.new()
	key.light_energy = 1.2
	key.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	key.shadow_enabled = true
	add_child(key)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(20.0, 20.0)
	floor_mesh.mesh = plane
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.33, 0.35, 0.38)
	floor_mesh.material_override = material
	add_child(floor_mesh)
