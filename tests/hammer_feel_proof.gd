extends Node
## Native-window proof frames for the capture point's hammer feedback:
##   godot --path . res://tests/hammer_feel_proof.tscn -- --out=docs/proof/hammer-feel
## Frames: 01 ordinary strike, 02 perfect strike, 03 quarter break,
## 04 the brass clock-part payoff mid-air, 05 the parts settled. Needs a real
## display. Runs under a fixture, so the perfect hitstop is skipped and the
## frames are not slowed down.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/hammer-feel"
var _player: Player
var _point: CapturePoint
var _hud


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("hammer feel proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_point = scene.get_node("CapturePoint") as CapturePoint
	await _frames(3)
	var choose := InputEventKey.new()
	choose.physical_keycode = KEY_1
	choose.pressed = true
	Input.parse_input_event(choose)
	await _frames(2)
	choose.pressed = false
	Input.parse_input_event(choose)
	await _frames(3)
	get_tree().paused = false
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	_player.set_physics_process(false)
	_player.global_position = _point.global_position + Vector3(0.0, 0.0, 5.0)
	_player.aim_at(_point.global_position + Vector3(0.0, 1.6, 0.0))
	_point.open()
	_point.player_in_reach = true
	await _frames(20)

	# 1. Ordinary strike: chips, the block punch and "+10%".
	_point.resolve_swing(2.3)
	await _seconds(0.1)
	_shot("01_ordinary_strike")
	await _seconds(0.7)

	# 2. Perfect strike: more chips and the gold "+20%".
	_point.resolve_swing(3.0)
	await _seconds(0.28)
	_shot("02_perfect_strike")
	await _seconds(0.7)

	# 3. The front-bottom quarter breaks off (the second pair, so the falling
	# blocks are the ones the camera can see).
	_point.add_capture_progress(0.3)
	await _seconds(0.18)
	_shot("03_quarter_break")
	await _seconds(0.8)

	# 4. Capture: the stopped clock breaks open, gears in the air.
	_point.add_capture_progress(0.5)
	await _seconds(0.35)
	_shot("04_gear_burst")
	await _seconds(1.0)

	# 5. The brass parts settle as litter.
	await _seconds(2.0)
	_shot("05_gears_settled")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
