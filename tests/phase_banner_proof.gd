extends Node
## Native-window proof frames for the centre-screen phase banners:
##   godot --path . res://tests/phase_banner_proof.tscn -- --out=docs/proof/phase-banner
## Frames: 01 zone start, 02 the point opens, 03 the first reinforcement,
## 04 the flag, 05 the boss zone. Needs a real display.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/phase-banner"
var _player: Player
var _director: ZoneDirector


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("phase banner proof needs a native display")
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
	_player.health.max_health = 100000.0
	_player.health.health = 100000.0
	for node in get_tree().get_nodes_in_group("enemy"):
		(node as Enemy).set_physics_process(false)
	await _seconds(0.2)
	_shot("01_clear_guards")

	for enemy in _enemies(scene):
		enemy.health.apply_damage(99999.0, Hitbox.BodyPart.BODY)
	await _seconds(0.25)
	_shot("02_hammer_point")

	await _seconds(2.65)
	_shot("03_reinforcement")

	var point := scene.get_node("CapturePoint") as CapturePoint
	point.player_in_reach = true
	point.add_capture_progress(1.0)
	await _seconds(0.25)
	_shot("04_flag_planted")

	scene.queue_free()
	await _frames(2)
	RunState.start_fixture(RunFixture.by_id("FX-002"))
	var boss_scene: Node = load("res://maps/boss.tscn").instantiate()
	add_child(boss_scene)
	await _frames(3)
	get_tree().paused = false
	await _seconds(0.2)
	_shot("05_boss_standing")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _enemies(scene: Node) -> Array[Enemy]:
	var found: Array[Enemy] = []
	for node in get_tree().get_nodes_in_group("enemy"):
		if scene.is_ancestor_of(node):
			found.append(node as Enemy)
	return found


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
