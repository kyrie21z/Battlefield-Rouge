extends Node3D
## Actual production boss winds up and releases a ground fissure.
func _ready() -> void:
	var realm := WrathRealm.new()
	realm.boss_arena = true
	add_child(realm)
	var player := preload("res://actors/player/player.tscn").instantiate() as Player
	player.position = Vector3(0, 0, 12)
	add_child(player)
	player.hide()
	player.set_physics_process(false)
	player.set_process_input(false)
	var boss := preload("res://actors/boss/wrath_spire/wrath_spire.tscn").instantiate() as WrathSpire
	boss.position = Vector3(0, 0, -4)
	boss.arena = realm
	add_child(boss)
	boss.setup(player, [])
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(7.5, 4.5, 7)
	camera.look_at(Vector3(0, 2.0, -3))
	camera.fov = 48
	camera.current = true
	boss.begin_move(WrathSpire.Move.FISSURE)
	for i in 78:
		await get_tree().physics_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "狂暴尖塔 · 人形肢体风暴\n真实地裂扇形正在扩散 · 先兆锁向 / 跳跃与侧移反制"
	title.position = Vector2(32, 26)
	title.add_theme_font_size_override("font_size", 26)
	layer.add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := ProjectSettings.globalize_path("res://docs/proof/issue-143/wrath-spire.png")
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var result := get_viewport().get_texture().get_image().save_png(path)
	print("WRATH SPIRE NATIVE: image=%d waves=%d layers=%d health=%.0f" % [result, boss.spawned_waves, (boss.visual as WrathSpireVisual).storm_rings.size(), boss.health.health])
	var ok := result == OK and boss.spawned_waves == 3
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit(0 if ok else 1)
