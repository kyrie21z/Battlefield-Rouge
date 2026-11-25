extends Node3D
## Native-renderer proof for the faceted-obsidian TalentOrb redesign.
## Saves three PNGs under res://docs/proof/talent-orb/ and quits.
##
## Run with:  godot --path . res://tests/talent_orb_proof.tscn

const OUT_DIR := "res://docs/proof/talent-orb"

var camera: Camera3D
var _player: Node3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	camera = Camera3D.new()
	camera.name = "ProofCamera"
	camera.fov = 36.0
	camera.near = 0.03
	add_child(camera)
	camera.current = true

	var ok := await _shoot_lineup()
	ok = ok and await _shoot_closeup()
	ok = ok and await _shoot_sloth_arena()
	if not ok:
		get_tree().quit(1)
		return
	print("TALENT ORB NATIVE: 3 captures in " + OUT_DIR)
	get_tree().quit(0)


func _orb(parent: Node3D, accent: Color, at: Vector3, ground: float) -> TalentOrb:
	var orb := TalentOrb.new()
	orb.name = "TalentOrb"
	orb.set_ground_height(ground)
	orb.position = Vector3(at.x, orb.hover_height(), at.z)
	parent.add_child(orb)
	orb.set_accent(accent)
	orb.set_idle_enabled(false)
	return orb


## Aims the mouth at `target` before the first frame so the proof never catches a
## half-finished turn.
func _face(orb: TalentOrb, target: Vector3) -> void:
	var d := target - orb.global_position
	d.y = 0.0
	if d.length_squared() > 0.0001:
		orb.rotation.y = atan2(-d.x, -d.z)


func _shoot_lineup() -> bool:
	var gallery := Node3D.new()
	gallery.name = "Gallery"
	add_child(gallery)

	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.020, 0.024, 0.032)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.48, 0.54, 0.68)
	environment.ambient_light_energy = 0.24
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.70
	environment.glow_enabled = true
	environment.glow_intensity = 0.52
	environment.glow_bloom = 0.09
	environment.glow_hdr_threshold = 1.02
	var world := WorldEnvironment.new()
	world.environment = environment
	gallery.add_child(world)

	var stone := ShaderMaterial.new()
	stone.shader = preload("res://environments/sloth/stone.gdshader")
	stone.set_shader_parameter("stone_color", Color("857c6d"))
	stone.set_shader_parameter("weathered", true)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(30.0, 0.5, 16.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = stone
	floor_instance.position = Vector3(0.0, -0.25, 0.0)
	gallery.add_child(floor_instance)
	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(30.0, 6.0, 0.5)
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.material_override = stone
	wall.position = Vector3(0.0, 2.75, -7.0)
	gallery.add_child(wall)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-46.0, 34.0, 0.0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.65
	key.shadow_enabled = true
	gallery.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-12.0, -148.0, 0.0)
	rim.light_color = Color(0.55, 0.68, 1.0)
	rim.light_energy = 1.20
	gallery.add_child(rim)

	_player = Node3D.new()
	_player.name = "ProofPlayer"
	_player.position = Vector3(0.0, 0.0, 5.4)
	gallery.add_child(_player)

	var spots: Array[float] = [-2.625, -0.875, 0.875, 2.625]
	for realm in 4:
		var orb := _orb(gallery, BoonIdentity.COLORS[realm], Vector3(spots[realm], 0.0, 0.0), 0.0)
		orb.set_player(_player)
		_face(orb, _player.global_position)

	camera.position = Vector3(0.0, 1.82, 7.40)
	camera.look_at(Vector3(0.0, 1.20, 0.0))
	camera.fov = 31.0
	var saved := await capture("01-four-realms-lineup.png")

	stop_audio(gallery)
	gallery.queue_free()
	await get_tree().process_frame
	return saved


func _shoot_closeup() -> bool:
	var gallery := Node3D.new()
	gallery.name = "Closeup"
	add_child(gallery)

	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.016, 0.019, 0.026)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.46, 0.52, 0.66)
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.72
	environment.glow_enabled = true
	environment.glow_intensity = 0.46
	environment.glow_bloom = 0.10
	environment.glow_hdr_threshold = 1.06
	var world := WorldEnvironment.new()
	world.environment = environment
	gallery.add_child(world)

	var stone := ShaderMaterial.new()
	stone.shader = preload("res://environments/sloth/stone.gdshader")
	stone.set_shader_parameter("stone_color", Color("7c7466"))
	stone.set_shader_parameter("weathered", true)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(18.0, 0.5, 12.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = stone
	floor_instance.position = Vector3(0.0, -0.25, 0.0)
	gallery.add_child(floor_instance)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-38.0, 26.0, 0.0)
	key.light_color = Color(1.0, 0.94, 0.84)
	key.light_energy = 1.85
	key.shadow_enabled = true
	gallery.add_child(key)
	var strip := DirectionalLight3D.new()
	strip.rotation_degrees = Vector3(-4.0, -120.0, 0.0)
	strip.light_color = Color(0.62, 0.74, 1.0)
	strip.light_energy = 1.45
	gallery.add_child(strip)

	var looker := Node3D.new()
	looker.position = Vector3(2.9, 0.0, 2.2)
	gallery.add_child(looker)

	var front := _orb(gallery, BoonIdentity.COLORS[0], Vector3(-0.55, 0.0, -0.2), 0.0)
	front.set_player(looker)
	_face(front, looker.global_position)
	var rear := _orb(gallery, BoonIdentity.COLORS[1], Vector3(0.78, 0.0, -0.62), 0.0)
	rear.rotation.y = 0.34

	camera.position = Vector3(0.05, 1.44, 2.55)
	camera.look_at(Vector3(0.10, 1.27, -0.40))
	camera.fov = 34.0
	var saved := await capture("02-closeup-and-back.png")

	stop_audio(gallery)
	gallery.queue_free()
	await get_tree().process_frame
	return saved


func _shoot_sloth_arena() -> bool:
	var arena := Node3D.new()
	arena.name = "SlothArena"
	add_child(arena)

	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	var sky_material := ShaderMaterial.new()
	sky_material.shader = preload("res://environments/sloth/sanctum_sky.gdshader")
	var sky := Sky.new()
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	sky.sky_material = sky_material
	environment.background_mode = Environment.BG_SKY
	environment.sky = sky
	environment.fog_enabled = true
	environment.fog_light_color = Color("b8c2c8")
	environment.fog_density = 0.0022
	environment.fog_sky_affect = 0.14
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("e1e5ed")
	environment.ambient_light_energy = 0.48
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.glow_enabled = true
	environment.glow_intensity = 0.32
	var world := WorldEnvironment.new()
	world.environment = environment
	arena.add_child(world)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52.0, -28.0, 0.0)
	sun.light_color = Color("ffeece")
	sun.light_energy = 1.22
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 74.0
	arena.add_child(sun)

	var geometry := SlothRealm.new()
	geometry.name = "Geometry"
	geometry.boss_arena = true
	arena.add_child(geometry)
	await get_tree().process_frame
	await get_tree().process_frame

	var player := Node3D.new()
	player.position = Vector3(3.4, 0.0, 6.8)
	arena.add_child(player)
	var orb := _orb(arena, BoonIdentity.COLORS[0], Vector3(2.8, 0.0, 3.3), 0.02)
	orb.set_player(player)
	_face(orb, player.global_position)

	camera.position = Vector3(3.2, 1.52, 6.4)
	camera.look_at(Vector3(2.9, 1.16, 3.3))
	camera.fov = 40.0
	var saved := await capture("03-sloth-arena-ingame.png")

	stop_audio(arena)
	arena.queue_free()
	await get_tree().process_frame
	return saved


func capture(filename: String) -> bool:
	for frame in 20:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path(OUT_DIR)
	var dir_err := DirAccess.make_dir_recursive_absolute(folder)
	if dir_err != OK:
		push_error("Failed to create proof folder %s: error=%d" % [folder, dir_err])
		return false
	var error := get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("CAPTURE %s error=%d" % [filename, error])
	if error != OK:
		push_error("Failed to save proof image %s: error=%d" % [filename, error])
		return false
	return true


func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
