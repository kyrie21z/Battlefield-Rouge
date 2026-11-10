extends Node3D
var bench: Node3D
var camera: Camera3D

func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Native renderer required")
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	bench = preload("res://tests/fear_oculus_bench.tscn").instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	bench.player.dash.set_physics_process(false)
	bench.player.hide()
	bench.status.hide()
	bench.boss.set_physics_process(false)
	bench.boss.phase = 2
	bench.boss.visual.charge = 0.8
	camera = Camera3D.new()
	add_child(camera)
	camera.fov = 52
	camera.make_current()
	camera.position = Vector3(0, 6.5, 6)
	camera.look_at(Vector3(0, 5.3, -8))
	await capture("01-folded-human-oculus.png")
	bench.boss.start_attack(1)
	bench.boss.advance_attack(1.3)
	bench.boss.advance_attack(0.75)
	camera.position = Vector3(12, 8, 14)
	camera.look_at(Vector3(0, 3.5, -4))
	await capture("02-cutting-beam.png")
	bench.boss.start_attack(2)
	bench.boss.advance_attack(1.2)
	for frame in 22:
		await get_tree().physics_frame
	camera.position = Vector3(13, 13, 12)
	camera.look_at(Vector3(0, 1.5, -8))
	await capture("03-physical-ring-wave.png")
	print("FEAR OCULUS NATIVE: 3 captures; live 36-limb rings, cutting ray and 24 physical projectiles")
	stop_audio(bench)
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()

func capture(filename: String) -> void:
	for frame in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/proof/issue-141")
	DirAccess.make_dir_recursive_absolute(folder)
	var error := get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("CAPTURE %s error=%d" % [filename, error])

func stop_audio(node: Node) -> void:
	if node is AudioStreamPlayer or node is AudioStreamPlayer3D:
		node.stop()
		node.stream = null
	for child in node.get_children():
		stop_audio(child)
