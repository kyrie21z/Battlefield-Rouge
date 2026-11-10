extends Node3D
func _ready() -> void:
	var realm := SorrowRealm.new()
	realm.boss_arena = true
	add_child(realm)
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0,0,13)
	add_child(player)
	player.hide()
	player.set_physics_process(false)
	player.set_process_input(false)
	var boss := preload("res://actors/boss/sorrow_monolith/sorrow_monolith.tscn").instantiate() as SorrowMonolith
	boss.position = Vector3(0,0,-5)
	boss.arena = realm
	add_child(boss)
	boss.setup(player,[])
	boss.health.apply_damage(650,Hitbox.BodyPart.BODY,player,{"true_damage":true})
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(9,5.0,-16)
	camera.look_at(Vector3(0,2.4,-4))
	camera.fov = 48
	camera.current = true
	boss.begin_move(SorrowMonolith.Move.TIDE)
	for i in 85:
		await get_tree().physics_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "哀泣巨碑 · 掩面半身巨像\n半血后的真实涨水 / 低台淹没 / 全场潮浪正在扩散"
	title.position = Vector2(32,26)
	title.add_theme_font_size_override("font_size",26)
	layer.add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/proof/issue-145/sorrow-monolith.png"))
	print("SORROW MONOLITH NATIVE: image=%d tides=%d water=%.3f health=%.0f" % [result,boss.tides_released,realm.water_level,boss.health.health])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit(0 if result == OK else 1)
