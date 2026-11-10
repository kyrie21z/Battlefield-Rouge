extends Node3D
## Production enemies, real front bullet contacts; tableau only, not a gameplay recording.
func _ready() -> void:
	var realm := WrathRealm.new()
	add_child(realm)
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0, -10)
	add_child(player)
	player.hide()
	player.set_physics_process(false)
	player.set_process_input(false)
	var actors: Array[WrathRealmEnemy] = []
	for i in 3:
		var actor := preload("res://actors/enemy/wrath/wrath_realm_enemy.tscn").instantiate() as WrathRealmEnemy
		actor.variant = i
		actor.position = Vector3((i - 1) * 3.8, 0, -3)
		add_child(actor)
		actors.append(actor)
		var label := Label3D.new()
		label.text = ["突刺者", "蓄压体", "侵犯者"][i]
		label.position.y = 2.6
		label.font_size = 44
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.modulate = Color(1.0, 0.83, 0.65)
		actor.add_child(label)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7, 3.8, -14)
	camera.look_at(Vector3(0, 1.2, -3))
	camera.fov = 48
	camera.current = true
	for i in 4:
		await get_tree().physics_frame
	for i in 2:
		player.weapon._shoot_ray(Vector3(0, 1.1, -10), Vector3.BACK)
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "愤怒之境 · 白瓷熔炉 / 异化晶体\n三种生产敌人 · 中央盾体已承受两次真实正面枪击"
	title.position = Vector2(32, 26)
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/proof/issue-142/wrath-realm.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("WRATH REALM NATIVE: image=%d pressure=%.1f blocked=%d bones=%d" % [result, actors[1].pressure, actors[1].blocked_shots, actors[0].visual.skeleton.get_bone_count()])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit(0 if result == OK and actors.size() == 3 else 1)
