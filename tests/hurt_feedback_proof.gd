extends Node
## Native-window proof frames for the player hurt feedback:
##   godot --path . res://tests/hurt_feedback_proof.tscn -- --out=docs/proof/hurt-feedback
## Frames: 01 the single-hit vignette at full HP, 02 direction arcs from
## behind and right, 03 the low-health pulse. Needs a real display.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/hurt-feedback"
var _player: Player
var _hud
var _guard: Enemy
var _scene: Node


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("hurt feedback proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	_scene = scene
	add_child(scene)
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
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
		var enemy := node as Enemy
		enemy.set_physics_process(false)
		if _guard == null:
			_guard = enemy
	_guard.health.max_health = 100000.0
	_guard.health.health = 100000.0
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0, 8)
	_player.global_rotation = Vector3.ZERO
	_guard.global_position = _player.global_position + Vector3(0, 0, -9.0)
	_guard.rotation.y = 0.0
	await _frames(25)
	_player.aim_at(_torso().global_position)
	await _frames(10)

	# 1. One hit at full HP: the red edge is clearly there, the centre is not.
	_hit(10.0, null)
	await _seconds(0.09)
	_shot("01_full_hp_vignette")

	# 2. Two arcs: one attacker behind, one to the right.
	var behind := _marker_at(Vector3(0, 0, 5))
	var right := _marker_at(Vector3(5, 0, 0))
	_hit(4.0, behind)
	_hit(4.0, right)
	await _seconds(0.09)
	_shot("02_indicator_behind_right")
	await _seconds(1.1)

	# 3. Low health: the edge pulses on its own; catch it near the top.
	_player.health.health = 15.0
	for i in 120:
		await get_tree().process_frame
		if _hud._damage_flash.color.a >= 0.50:
			break
	_shot("03_low_hp")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _hit(amount: float, source: Node) -> void:
	_player.health.apply_damage(amount, Hitbox.BodyPart.BODY, source)


func _marker_at(offset: Vector3) -> Node3D:
	var marker := Node3D.new()
	_scene.add_child(marker)
	marker.global_position = _player.global_position + offset
	return marker


func _torso() -> Hitbox:
	for node in _guard.find_children("*", "Hitbox", true, false):
		if (node as Hitbox).body_part == Hitbox.BodyPart.BODY:
			return node as Hitbox
	return null


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)
	# The centre crop proves the vignette leaves the aiming area clear.
	if name == "01_full_hp_vignette":
		var centre := image.get_size() / 2
		var crop := image.get_region(Rect2i(centre - Vector2i(160, 120), Vector2i(320, 240)))
		crop.resize(640, 480, Image.INTERPOLATE_NEAREST)
		crop.save_jpg("%s/%s_centre.jpg" % [_out_dir, name], 0.9)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
