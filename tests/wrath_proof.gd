extends "res://tests/wrath_core_test.gd"
## Native-render proof of real wall slams or legendary moving-air ruptures.
## -- --proof=<absolute PNG path> [--legendary] captures and exits.
func _ready() -> void:
	process_physics_priority = 100
	var proof_path := ""
	var legendary := false
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--proof="):
			proof_path = arg.trim_prefix("--proof=")
		legendary = legendary or arg == "--legendary"
	await _world()
	player.visible = false
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color(0.72, 0.76, 0.8)
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.WHITE
	settings.ambient_light_energy = 0.55
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.35
	sun.shadow_enabled = true
	add_child(sun)
	_white_box(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_white_box(Vector3(0, 2, -6), Vector3(12, 4, 0.4))
	var camera := Camera3D.new()
	add_child(camera)
	camera.global_position = Vector3(8, 6, 7)
	camera.look_at(Vector3(0, 1.0, -3.5))
	camera.fov = 58.0
	camera.current = true
	manager.equip(load("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
	if legendary:
		manager.equip(load("res://buffs/resources/wrath/wrath_shrapnel.tres"))
		manager.equip(load("res://buffs/resources/wrath/wrath_crusher.tres"))
		manager.equip(load("res://buffs/resources/wrath/wrath_cataclysm.tres"))
	effect = manager.effect_for(load("res://buffs/effects/wrath_effect.gd")) as WrathBoons
	var actors: Array[SlothEnemy] = []
	for index in 3:
		actors.append(_enemy(Vector3((index - 1) * 3.0, 0, 0.5 if legendary else -3.0)))
	await _frames(3)
	for actor in actors:
		effect.knock(actor, Vector3.FORWARD, 3.0)
	await _frames(14 if legendary else 12)
	var layer := CanvasLayer.new()
	var title := Label.new()
	title.text = "灾厄怒潮 · 移动中的空间断层" if legendary else "愤怒 · 真实撞墙破裂"
	title.position = Vector2(42, 30)
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.12, 0.07, 0.06))
	layer.add_child(title)
	add_child(layer)
	if proof_path.is_empty():
		return
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(proof_path)
	print("WRATH PROOF: ", result, " path=", proof_path)
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit(0 if result == OK else 1)

func _white_box(position: Vector3, size_value: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.93, 0.95)
	material.roughness = 0.85
	mesh.material = material
	visual.mesh = mesh
	visual.position = position
	add_child(visual)
