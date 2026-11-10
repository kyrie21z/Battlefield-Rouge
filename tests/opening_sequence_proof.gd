extends Node3D
var sequence: OpeningSequence
func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		get_tree().quit(1)
		return
	DisplayServer.window_set_size(Vector2i(1280, 720))
	sequence = preload("res://ui/cinematics/opening_sequence.tscn").instantiate() as OpeningSequence
	add_child(sequence)
	sequence.set_process(false)
	sequence.start()
	await capture("01-reality-blackout.png")
	while sequence.phase < OpeningSequence.Phase.BODY:
		sequence.advance(0.1)
	for step in 38: sequence.advance(0.1)
	await capture("02-white-crystal-body.png")
	while sequence.phase < OpeningSequence.Phase.ENCOUNTER:
		sequence.advance(0.1)
	for step in 27: sequence.advance(0.1)
	await capture("03-simple-crown.png")
	while sequence.phase < OpeningSequence.Phase.CROWNING:
		sequence.advance(0.1)
	for step in 46: sequence.advance(0.1)
	await capture("04-crowning-and-assembly.png")
	while sequence.phase != OpeningSequence.Phase.PLAYABLE:
		sequence.advance(0.1)
	sequence.player.set_physics_process(false)
	await capture("05-control-at-open-gate.png")
	print("OPENING NATIVE: 5 captures from the same production ViewCamera")
	sequence.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	get_tree().quit()
func capture(name: String) -> void:
	for frame in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var folder := ProjectSettings.globalize_path("res://docs/proof/issue-147")
	DirAccess.make_dir_recursive_absolute(folder)
	var result := get_viewport().get_texture().get_image().save_png(folder.path_join(name))
	print("CAPTURE %s error=%d" % [name, result])
