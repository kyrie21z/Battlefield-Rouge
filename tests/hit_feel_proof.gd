extends Node
## Native-window proof frames for the stronger hit / kill feedback:
##   godot --path . res://tests/hit_feel_proof.tscn -- --out=docs/proof/hit-feel
## Frames: 01 body kill burst + 击杀, 02 headshot kill burst + 爆头击杀,
## 03 双杀, 04 the shotgun's stronger kick. Needs a real display.

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/hit-feel"
var _player: Player
var _weapon: Weapon
var _hud
var _guards: Array[Enemy] = []


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("hit feel proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	_player = scene.get_node("Player") as Player
	_hud = scene.get_node("HUD")
	_weapon = _player.weapon
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
		_guards.append(enemy)
	_player.set_physics_process(false)
	_player.global_position = Vector3(0, 0, 8)
	_player.global_rotation = Vector3.ZERO
	await _frames(5)
	# 4. The shotgun's stronger kick, on a clean scene before the kills. The
	# target stands at 8 m and takes the blast without dying.
	_place(_guards[0], Vector3(0, 0, 0), 100000.0)
	await _aim(_hitbox(_guards[0], Hitbox.BodyPart.BODY))
	_weapon.select(1)
	_weapon.ammo = _weapon.magazine_capacity()
	await _frames(12)
	_fire()
	await _frames(2)
	_shot("04_shotgun_kick")
	_guards[0].global_position = Vector3(15, 0, 15)
	_weapon.select(0)
	await _frames(6)

	# 1. Body kill: chunks at the chest, 击杀 under the crosshair.
	_place(_guards[1], Vector3(0, 0, 3), 1.0)
	await _aim(_hitbox(_guards[1], Hitbox.BodyPart.BODY))
	_fire()
	await _seconds(0.2)
	_shot("01_body_kill_burst")
	await _seconds(2.7)

	# 2. Headshot kill: the burst comes from the head, 爆头击杀 in gold.
	_place(_guards[2], Vector3(2, 0, 3), 1.0)
	await _aim(_hitbox(_guards[2], Hitbox.BodyPart.HEAD))
	_fire()
	await _seconds(0.2)
	_shot("02_headshot_kill_burst")

	# 3. A second kill right after: 双杀.
	_place(_guards[3], Vector3(-2, 0, 3), 1.0)
	await _aim(_hitbox(_guards[3], Hitbox.BodyPart.BODY))
	_fire()
	await _seconds(0.2)
	_shot("03_double_kill")
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


func _place(enemy: Enemy, at: Vector3, health: float) -> void:
	enemy.health.max_health = maxf(health, 100.0)
	enemy.health.health = health
	enemy.global_position = at
	# Face the player: the model's forward is -Z, the player stands at +Z.
	enemy.rotation.y = PI


func _aim(hitbox: Hitbox) -> void:
	_weapon.ammo = _weapon.magazine_capacity()
	_weapon._cooldown = 0.0
	_player.aim_at(hitbox.global_position)
	await _frames(10)


func _fire() -> void:
	_weapon._cooldown = 0.0
	_weapon.try_fire()


func _hitbox(enemy: Enemy, part: Hitbox.BodyPart) -> Hitbox:
	for node in enemy.find_children("*", "Hitbox", true, false):
		if (node as Hitbox).body_part == part:
			return node as Hitbox
	return null


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
