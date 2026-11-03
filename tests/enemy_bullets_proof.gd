extends Node
## Native-window proof frames for the faster enemy bullets and the out-of-sight
## reinforcement spawns:
##   godot --path . res://tests/enemy_bullets_proof.tscn -- --out=docs/proof/enemy-bullets
## Frames: 01 a 30 m/s enemy tracer in flight, 02 a wave spawning out of sight
## while the player hammers the building. Needs a real display.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/enemy-bullets"
var _player: Player
var _director: ZoneDirector
var _scene: Node
var _guard: Enemy


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("enemy bullets proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	_scene = load(ZONE).instantiate()
	add_child(_scene)
	await _frames(3)
	await _press_one()
	get_tree().paused = false
	_player = _scene.get_node("Player") as Player
	_director = _scene.get_node("ZoneDirector") as ZoneDirector
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		enemy.set_physics_process(false)
		if _guard == null:
			_guard = enemy
	_player.set_physics_process(false)

	# 1. A real enemy round crossing the view at 30 m/s.
	_player.global_position = Vector3(0.0, 0.0, 8.0)
	_player.global_rotation = Vector3.ZERO
	await _frames(5)
	Projectile.spawn(_scene, Vector3(5.5, 1.3, 3.0), Vector3.LEFT, _guard, 10.0, 30.0, [])
	await _seconds(0.06)
	_shot("01_enemy_tracer")

	# 2. Hammering the building when a wave spawns at the hidden flank markers.
	var point := _scene.get_node("CapturePoint") as CapturePoint
	_player.global_position = point.global_position + Vector3(0.0, 0.0, 3.4)
	_player.global_rotation = Vector3.ZERO
	point.open()
	point.player_in_reach = true
	await _frames(5)
	point.resolve_swing(2.0)
	await _seconds(0.15)
	_director._reinforcing = true
	_director._spawn_wave()
	_director._reinforcing = false
	await _seconds(0.2)
	_shot("02_wave_out_of_sight")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


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
