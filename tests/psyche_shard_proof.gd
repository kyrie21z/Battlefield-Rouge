extends Node3D
## Native-renderer proof for the PsycheShardPickup cut-crystal redesign.
## Saves two PNGs under res://docs/proof/psyche-shard/ and quits.
##
## Run with:  godot --path . res://tests/psyche_shard_proof.tscn

const OUT_DIR := "res://docs/proof/psyche-shard"
const SHARD_SCENE := preload("res://zone/psyche_shard_pickup.tscn")

var camera: Camera3D


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	camera = Camera3D.new()
	camera.name = "ProofCamera"
	camera.fov = 38.0
	camera.near = 0.03
	add_child(camera)
	camera.current = true

	var ok := await _shoot_gallery()
	ok = ok and await _shoot_sloth_arena()
	if not ok:
		get_tree().quit(1)
		return
	print("PSYCHE SHARD NATIVE: 2 captures in " + OUT_DIR)
	get_tree().quit(0)


func _shoot_gallery() -> bool:
	var gallery := Node3D.new()
	gallery.name = "Gallery"
	add_child(gallery)

	var environment := preload("res://environments/default_env.tres").duplicate() as Environment
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.022, 0.026, 0.034)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.56, 0.70)
	environment.ambient_light_energy = 0.20
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.tonemap_exposure = 0.66
	environment.glow_enabled = true
	environment.glow_intensity = 0.50
	environment.glow_bloom = 0.08
	environment.glow_hdr_threshold = 1.05
	var world := WorldEnvironment.new()
	world.environment = environment
	gallery.add_child(world)

	var stone := ShaderMaterial.new()
	stone.shader = preload("res://environments/sloth/stone.gdshader")
	stone.set_shader_parameter("stone_color", Color("857c6d"))
	stone.set_shader_parameter("weathered", true)
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(24.0, 0.5, 16.0)
	var floor_instance := MeshInstance3D.new()
	floor_instance.mesh = floor_mesh
	floor_instance.material_override = stone
	floor_instance.position = Vector3(0.0, -0.25, 0.0)
	gallery.add_child(floor_instance)

	var wall_mesh := BoxMesh.new()
	wall_mesh.size = Vector3(24.0, 6.0, 0.5)
	var wall := MeshInstance3D.new()
	wall.mesh = wall_mesh
	wall.material_override = stone
	wall.position = Vector3(0.0, 2.75, -7.0)
	gallery.add_child(wall)

	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-48.0, 32.0, 0.0)
	key.light_color = Color(1.0, 0.93, 0.82)
	key.light_energy = 1.55
	key.shadow_enabled = true
	gallery.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-10.0, -146.0, 0.0)
	rim.light_color = Color(0.55, 0.68, 1.0)
	rim.light_energy = 1.15
	gallery.add_child(rim)

	var positions: Array[Vector3] = [
		Vector3(-2.4, 0.0, 0.0), Vector3(-0.8, 0.0, 0.0),
		Vector3(0.8, 0.0, 0.0), Vector3(2.4, 0.0, 0.0),
	]
	for realm in 4:
		var shard := SHARD_SCENE.instantiate() as PsycheShardPickup
		shard.realm = realm
		shard.position = positions[realm]
		shard.set_physics_process(false)
		gallery.add_child(shard)

	camera.position = Vector3(2.3, 1.70, 6.0)
	camera.look_at(Vector3(0.0, 1.0, 0.0))
	camera.fov = 33.0
	var saved := await capture("01-four-realms-lineup.png")

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

	var sloth := SHARD_SCENE.instantiate() as PsycheShardPickup
	sloth.realm = 0
	sloth.position = Vector3(2.8, 0.02, 3.3)
	sloth.set_physics_process(false)
	arena.add_child(sloth)
	var wrath := SHARD_SCENE.instantiate() as PsycheShardPickup
	wrath.realm = 2
	wrath.position = Vector3(4.6, 0.02, 2.7)
	wrath.set_physics_process(false)
	arena.add_child(wrath)

	camera.position = Vector3(3.2, 1.46, 6.4)
	camera.look_at(Vector3(2.9, 0.98, 3.3))
	camera.fov = 40.0
	var saved := await capture("02-sloth-arena-ingame.png")

	stop_audio(arena)
	arena.queue_free()
	await get_tree().process_frame
	return saved


func capture(filename: String) -> bool:
	for frame in 14:
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
