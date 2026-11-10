extends Node
## Native-window proof frames for the gun-feel work:
##   godot --path . res://tests/gun_feel_proof.tscn -- --out=docs/proof/gun-feel
## Frames: mid-recoil, tracer + impact, enemy flash, pistol blast, kill marker.
## Needs a real display (headless has no renderer).

const ZONE := "res://maps/zone_1.tscn"

var _out_dir := "res://docs/proof/gun-feel"
var _player: Player
var _weapon: Weapon
var _guard: Enemy
var _failures := 0


func _ready() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			_out_dir = arg.trim_prefix("--out=")
	_out_dir = ProjectSettings.globalize_path(_out_dir)
	if DisplayServer.get_name() == "headless":
		push_error("gun feel proof needs a native display")
		get_tree().quit(1)
		return
	DirAccess.make_dir_recursive_absolute(_out_dir)
	DisplayServer.window_set_size(Vector2i(1280, 720))
	RunState.start_fixture(RunFixture.by_id("FX-001"))
	var scene: Node = load(ZONE).instantiate()
	add_child(scene)
	_player = scene.get_node("Player") as Player
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
		if _guard == null:
			_guard = enemy
	_guard.health.max_health = 100000.0
	_guard.health.health = 100000.0
	_player.set_physics_process(false)
	await _stage(0, 9.0)

	# 1. pistol, hip: the frame right after a shot, then the spring ringing back.
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await _frames(1)
	_shot("01_pistol_recoil_frame1")
	await _frames(2)
	_shot("02_pistol_tracer_impact_flash")
	await _frames(10)
	_shot("03_pistol_settled")

	# 2. a flash on the enemy, caught the frame after the hit.
	await _stage(0, 9.0)
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await _frames(2)
	_shot("04_enemy_flash")
	await _frames(12)
	_shot("05_enemy_after")

	# 3. pistol: heavy kick and several tracers.
	await _stage(1, 7.0)
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await _frames(2)
	_shot("06_pistol_blast")

	# 4. kill: the red, bigger marker.
	await _stage(0, 9.0)
	_guard.health.health = 30.0
	_weapon._cooldown = 0.0
	_weapon.try_fire()
	await _frames(3)
	_shot("07_kill_marker")
	await _frames(20)

	# 5. crosshair: hip lines + dot, then iron sights with the dot alone.
	_player.set_physics_process(true)
	var names := ["pistol"]
	for slot in 1:
		await _stage(slot, 12.0)
		_player.set_physics_process(true)
		Input.action_release("aim")
		await _seconds(0.8)
		_shot("%02d_%s_hip_crosshair" % [8 + slot * 2, names[slot]])
		Input.action_press("aim")
		await _seconds(0.9)
		_shot("%02d_%s_ads_dot" % [9 + slot * 2, names[slot]])
		Input.action_release("aim")
		await _seconds(0.5)
	print("proof frames written to %s" % _out_dir)
	get_tree().quit(0)


## Puts the guard `distance` m ahead of the eye and points the gun at its torso.
func _stage(_slot: int, distance: float) -> void:

	_weapon.ammo = _weapon.magazine_capacity()
	_player.global_position = Vector3(0, 0, 8)
	_player.global_rotation = Vector3.ZERO
	_guard.health.health = 100000.0
	_guard.global_position = _player.global_position + Vector3(0, 0, -distance)
	_guard.rotation.y = 0.0
	await _frames(25)
	_player.aim_at(_torso().global_position)
	await _frames(25)


func _torso() -> Hitbox:
	for node in _guard.find_children("*", "Hitbox", true, false):
		if (node as Hitbox).body_part == Hitbox.BodyPart.BODY:
			return node as Hitbox
	return null


func _shot(name: String) -> void:
	var image := get_viewport().get_texture().get_image()
	image.save_jpg("%s/%s.jpg" % [_out_dir, name], 0.88)
	# The crosshair frames also get a 4x nearest-neighbour crop of the screen centre.
	if name.contains("crosshair") or name.contains("ads_dot"):
		var centre := image.get_size() / 2
		var crop := image.get_region(Rect2i(centre - Vector2i(100, 70), Vector2i(200, 140)))
		crop.resize(800, 560, Image.INTERPOLATE_NEAREST)
		crop.save_jpg("%s/%s_zoom.jpg" % [_out_dir, name], 0.9)


func _seconds(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout


func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
