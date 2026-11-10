extends Node3D
## Native captures of the playable actors and their actual geometry, never a render mockup.
var bench: Node3D
var camera: Camera3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	bench = preload("res://tests/fear_realm_bench.tscn").instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	bench.player.hide()
	bench.player.dash.set_physics_process(false)
	bench.status.hide()
	for enemy in bench.enemies:
		enemy.set_physics_process(false)
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 52
	camera.make_current()
	camera.position = Vector3(26, 23, 34)
	camera.look_at(Vector3(0, 0, -1))
	await capture("01-abyss-bridges.png")
	var labels: Array[Label3D] = []
	for index in 3:
		var enemy: FearRealmEnemy = bench.enemies[index]
		enemy.position = Vector3(-2.35 + index * 2.35, 0, 16)
		enemy.rotation = Vector3.ZERO
		var label := Label3D.new()
		label.text = ["WATCHER / GAZE", "TREMBLER / BLINK", "FALLER / TRAP"][index]
		label.font_size = 28
		label.pixel_size = 0.0028
		label.modulate = Color(0.8, 0.65, 1.0)
		label.position = enemy.position + Vector3(0, 3.1, 0)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		labels.append(label)
	camera.position = Vector3(0, 2.4, 7.2)
	camera.look_at(Vector3(0, 1.4, 16))
	camera.fov = 44
	await capture("02-crystal-variants.png")
	for label in labels:
		label.queue_free()
	bench.player.position = Vector3(0, 0, 0)
	var faller: FearRealmEnemy = bench.enemies[2]
	faller.position = Vector3(0, 0.02, 1.5)
	faller.start_attack()
	faller.advance_attack(1.3)
	for frame in 66:
		await get_tree().physics_frame
	camera.position = Vector3(6, 3.8, 5)
	camera.look_at(Vector3(0, -0.6, 0))
	await capture("03-physical-fall-trap.png")
	print("FEAR REALM NATIVE: 3 captures; native production actors and real rotating collider")
	_stop_audio(bench)
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(filename: String) -> void:
	for frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/proof/issue-140")
	DirAccess.make_dir_recursive_absolute(folder)
	var error := get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("CAPTURE %s error=%d" % [filename, error])

func _stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		_stop_audio(child)
