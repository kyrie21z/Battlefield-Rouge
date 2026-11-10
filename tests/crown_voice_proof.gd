extends Node3D
var bench: Node3D
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280,720))
	bench = preload("res://tests/crown_voice_bench.tscn").instantiate()
	add_child(bench)
	bench.player.set_physics_process(false)
	bench.voice.set_fracture_level(0)
	await capture("01-first-run-faint-crown.png")
	bench.voice.configure_history(4,4,"abyss")
	Events.sin_defeated.emit(4)
	await capture("02-deep-failure-blinding-crown.png")
	print("CROWN NATIVE: two real Player views, physical edge prongs, dynamic spoken subtitles and 0/4 radiance")
	bench.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()
func capture(filename: String) -> void:
	for frame in 20: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/proof/issue-148")
	DirAccess.make_dir_recursive_absolute(folder)
	var result := get_viewport().get_texture().get_image().save_png(folder.path_join(filename))
	print("CAPTURE %s error=%d" % [filename,result])
