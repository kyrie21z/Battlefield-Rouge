extends Node3D
## Captures native Forward+ AgX production screenshots of all four combat realms
## and StasisHub with zero runtime lookdev overrides.

const SHOTS := [
	{"id": "01-sloth", "scene": "res://maps/realms/sloth_1.tscn", "stage": true, "pos": Vector3(0.0, 0.1, 13.5), "aim": Vector3(0.5, 2.5, -8.0)},
	{"id": "02-fear", "scene": "res://maps/realms/fear_1.tscn", "stage": true, "pos": Vector3(0.0, 0.1, 13.0), "aim": Vector3(0.0, 2.6, -10.0)},
	{"id": "03-wrath", "scene": "res://maps/realms/wrath_1.tscn", "stage": true, "pos": Vector3(0.0, 0.1, 13.0), "aim": Vector3(0.0, 2.4, -10.0)},
	{"id": "04-sorrow", "scene": "res://maps/realms/sorrow_1.tscn", "stage": true, "pos": Vector3(0.0, 0.1, 13.0), "aim": Vector3(0.0, 2.4, -10.0)},
	{"id": "05-stasis-hub", "scene": "res://levels/stasis_hub/stasis_hub.tscn", "stage": false, "pos": Vector3(0.0, 0.1, 5.8), "aim": Vector3(0.0, 1.9, -4.5)},
]

var _out_dir := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_out_dir = ProjectSettings.globalize_path("res://docs/proof/ultra1-visual-baseline")
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.substr(6)
	DirAccess.make_dir_recursive_absolute(_out_dir)

	for cfg in SHOTS:
		await _capture_scene(cfg)

	print("MONUMENT_PROOF_DONE: " + _out_dir)
	await get_tree().process_frame
	get_tree().quit(0)

func _capture_scene(cfg: Dictionary) -> void:
	var packed := load(cfg["scene"]) as PackedScene
	var root := packed.instantiate()
	if cfg["stage"]:
		(root as RealmStage).campaign = true
	add_child(root)

	for _i in 8:
		await get_tree().process_frame

	if cfg["stage"]:
		var stage := root as RealmStage
		stage.player.health.invulnerable = true
		if stage.selection and stage.selection.visible and stage.selection._offered.size() > 0:
			stage.selection._choose(stage.selection._offered[0])
			for _i in 4:
				await get_tree().process_frame
		get_tree().paused = false
		for e in stage.enemies:
			if is_instance_valid(e):
				e.set_physics_process(false)
				e.set_process(false)
		stage.player.set_physics_process(false)
		stage.player.position = cfg["pos"]
		stage.player.aim_at(cfg["aim"])
		stage.player.view_camera.current = true
	else:
		var hub := root as StasisHub
		hub.player.set_physics_process(false)
		hub.player.position = cfg["pos"]
		hub.player.aim_at(cfg["aim"])
		hub.player.view_camera.current = true

	_hide_canvas_layers(root)
	for _i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out_path := _out_dir.path_join(str(cfg["id"]) + ".jpg")
	get_viewport().get_texture().get_image().save_jpg(out_path, 0.90)
	print("CAPTURED_PROD: " + str(cfg["id"]))

	root.queue_free()
	for _i in 3:
		await get_tree().process_frame

func _hide_canvas_layers(node: Node) -> void:
	if node is CanvasLayer:
		(node as CanvasLayer).visible = false
	for c in node.get_children():
		_hide_canvas_layers(c)
