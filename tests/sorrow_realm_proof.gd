extends Node3D
func _ready() -> void:
	var realm := SorrowRealm.new()
	add_child(realm)
	for i in 3:
		var actor := preload("res://actors/enemy/sorrow/sorrow_realm_enemy.tscn").instantiate() as SorrowRealmEnemy
		actor.variant = i
		actor.position = Vector3((i-1)*3.3,0,-3)
		add_child(actor)
		var nameplate := Label3D.new()
		nameplate.text = ["溶蚀者","沉沦者","哀泣者"][i]
		nameplate.position.y = 2.6
		nameplate.font_size = 42
		nameplate.pixel_size = 0.003
		nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(nameplate)
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(2,3,-11)
	camera.look_at(Vector3(0,1.0,-3))
	camera.fov = 54
	camera.current = true
	for i in 90:
		await get_tree().physics_frame
	realm.add_ripple(Vector3(0,0,-5))
	for i in 20:
		await get_tree().physics_frame
	var layer := CanvasLayer.new()
	add_child(layer)
	var title := Label.new()
	title.text = "悲伤镜潭 · 流态与下沉\n原始晶体人形 / 融柱 / 白雨 / 实时水面波纹"
	title.position = Vector2(32,26)
	title.add_theme_font_size_override("font_size",26)
	layer.add_child(title)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var result := get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://docs/proof/issue-144/sorrow-realm.png"))
	print("SORROW REALM NATIVE: image=%d ripples=%d water=%.2f" % [result,realm.ripple_count,realm.water_level])
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit(0 if result == OK else 1)
