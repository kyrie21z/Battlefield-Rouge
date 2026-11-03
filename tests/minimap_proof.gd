extends Node
## Native-window proof frames for the HUD minimap:
##   godot --path . res://tests/minimap_proof.tscn -- --out=docs/proof/minimap
## Frames: 01 zone 1 at the start, 02 after a 90 degree turn, 03 a
## reinforcement pulse plus an out-of-range capture arrow, 04 the boss map.
## Needs a real display.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/minimap"
var _player: Player
var _director: ZoneDirector


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("minimap proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))

	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	await _frames(3)
	await _press_one()
	get_tree().paused = false
	_player = scene.get_node("Player") as Player
	_director = scene.get_node("ZoneDirector") as ZoneDirector
	_freeze_actors()
	_player.set_physics_process(false)
	_player.global_position = Vector3(0.0, 0.0, 14.0)
	_player.global_rotation = Vector3.ZERO
	await _seconds(0.3)
	_shot("01_zone1_start")

	_player.global_rotation = Vector3(0.0, PI * 0.5, 0.0)
	await _seconds(0.2)
	_shot("02_turned_90")

	_player.global_position = Vector3(28.0, 0.0, 28.0)
	_player.global_rotation = Vector3.ZERO
	await _seconds(0.2)
	_director._spawn_one()
	await _seconds(0.15)
	_shot("03_reinforcement_pulse")

	scene.queue_free()
	await _frames(2)
	RunState.start_fixture(RunFixture.by_id("FX-002"))
	var boss_scene: Node = load("res://maps/boss.tscn").instantiate()
	add_child(boss_scene)
	await _frames(5)
	get_tree().paused = false
	_player = boss_scene.get_node("Player") as Player
	_director = boss_scene.get_node("ZoneDirector") as ZoneDirector
	_freeze_actors()
	_player.set_physics_process(false)
	_player.global_position = Vector3(0.0, 0.0, -7.0)
	_player.global_rotation = Vector3.ZERO
	await _seconds(0.3)
	_shot("04_boss")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _freeze_actors() -> void:
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)


func _press_one() -> void:
	var choose := InputEventKey.new()
	choose.physical_keycode = KEY_1
	choose.pressed = true
	Input.parse_input_event(choose)
	await _frames(2)
	choose.pressed = false
	Input.parse_input_event(choose)
	await _frames(3)


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
