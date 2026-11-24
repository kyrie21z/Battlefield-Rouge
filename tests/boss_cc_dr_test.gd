extends Node3D
## Ticket 02 (#267): BoonManager is the single gate for Boss hard-control
## diminishing returns and soft-control floors. Checks use production
## SlothColossus, FlawlessDoppelganger, Enemy and Projectile scenes.
##
## godot --headless --path . res://tests/boss_cc_dr_test.tscn

const PLAYER_SCENE := preload("res://actors/player/player.tscn")
const COLOSSUS_SCENE := preload("res://actors/boss/sloth_colossus/sloth_colossus.tscn")
const FLAWLESS_SCENE := preload("res://actors/boss/flawless_doppelganger/flawless_doppelganger.tscn")
const ENEMY_SCENE := preload("res://actors/enemy/enemy.tscn")

var checks := 0
var failures := 0
var _player: Player
var _manager: BoonManager


func _ready() -> void:
	await _run()
	await _finish()


func _run() -> void:
	_build_floor()
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.set_process_unhandled_input(false)
	_player.health.max_health = 100000.0
	_player.health.health = 100000.0
	_manager = _player.boons
	_manager.set_physics_process(false)
	await _frames(3)
	await _run_ordinary_target()
	await _run_colossus()
	await _run_flawless()


func _run_ordinary_target() -> void:
	var enemy := _spawn_enemy(Vector3(0, 0.05, -4))
	for index in 5:
		_manager.set_status(enemy, StringName("plain_%d" % index), 3.0, 1.0, 0.0, true)
	check("non-boss actors stack five full stuns without DR",
		enemy.boon_stunned and is_zero_approx(enemy.boon_time_scale)
		and _manager.boss_cc_stage(enemy) == 0 and not _manager.boss_cc_immune(enemy))
	_manager._physics_process(3.01)
	check("ordinary actors recover after their full 3 s stun",
		not enemy.boon_stunned and is_equal_approx(enemy.boon_time_scale, 1.0))
	_manager.set_status(enemy, &"plain_soft", 60.0, 1.0, 0.1, false, 3.0, false, 0.2)
	check("ordinary actors keep the raw extreme slow",
		is_equal_approx(enemy.boon_time_scale, 0.1)
		and is_equal_approx(enemy.boon_attack_scale, 0.2)
		and is_equal_approx(enemy.boon_windup_scale, 3.0))
	_manager.clear_status(enemy, &"plain_soft")
	check("clearing the raw slow restores ordinary actors", is_equal_approx(enemy.boon_time_scale, 1.0))
	enemy.queue_free()
	await _frames(2)


func _run_colossus() -> void:
	var boss := COLOSSUS_SCENE.instantiate() as SlothColossus
	add_child(boss)
	boss.position = Vector3(-6, 0.05, 0)
	boss.setup(_player, [])
	boss.set_physics_process(false)
	var plain := _spawn_enemy(Vector3(0, 0.05, -4))
	var projectile := Projectile.spawn(self, Vector3(0, 1, -6), Vector3.FORWARD, plain, 10.0, 20.0, [])
	projectile.set_physics_process(false)
	await _frames(3)
	check("production colossus starts without DR memory",
		boss.is_boss and _manager.boss_cc_stage(boss) == 0 and not _manager.boss_cc_immune(boss))

	_manager.set_status(boss, &"cc_first", 5.0, 1.0, 0.0)
	check("first boss hard CC caps at 2 s",
		_manager.boss_cc_stage(boss) == 1 and is_zero_approx(boss.boon_time_scale))
	_manager._physics_process(1.0)
	check("first boss freeze still holds after 1 s", is_zero_approx(boss.boon_time_scale))
	_manager._physics_process(1.01)
	check("first boss freeze ends after the 2 s cap, not the requested 5 s",
		is_equal_approx(boss.boon_time_scale, 1.0) and _manager.boss_cc_stage(boss) == 1)

	_manager.set_status(boss, &"cc_second", 5.0, 1.0, 1.0, true)
	check("second boss hard CC halves to 1 s",
		_manager.boss_cc_stage(boss) == 2 and boss.boon_stunned)
	_manager._physics_process(0.99)
	check("second boss stun holds just under 1 s", boss.boon_stunned)
	_manager._physics_process(0.02)
	check("second boss stun ends at 1 s",
		not boss.boon_stunned and _manager.boss_cc_stage(boss) == 2)

	_manager.freeze_world(5.0, &"cc_third")
	check("third boss freeze quarters to 0.5 s and becomes immune",
		_manager.boss_cc_stage(boss) == 3 and _manager.boss_cc_immune(boss)
		and is_zero_approx(boss.boon_time_scale))
	check("freeze_world still freezes ordinary enemies for the full 5 s",
		is_zero_approx(plain.boon_time_scale))
	check("freeze_world still freezes enemy projectiles", is_zero_approx(projectile.boon_time_scale))
	_manager._physics_process(0.51)
	check("boss thaws after 0.5 s while the ordinary enemy stays frozen",
		is_equal_approx(boss.boon_time_scale, 1.0) and is_zero_approx(plain.boon_time_scale))

	_manager.set_status(boss, &"cc_fourth", 5.0, 1.0, 0.0, true, 1.0, true)
	check("fourth boss hard CC is immune and never stuns",
		_manager.boss_cc_stage(boss) == 3 and _manager.boss_cc_immune(boss)
		and not boss.boon_stunned and is_equal_approx(boss.boon_time_scale, 1.0))
	check("the immune call keeps the non-hard block_shield_regen",
		boss.health.shield_regeneration_blocked)
	_manager._physics_process(1.0)
	check("the immune call does not freeze the boss",
		is_equal_approx(boss.boon_time_scale, 1.0) and not boss.boon_stunned)

	get_tree().paused = true
	_manager._physics_process(30.0)
	get_tree().paused = false
	check("pause freezes the 12 s boss CC window", _manager.boss_cc_stage(boss) == 3)
	_manager._physics_process(10.4)
	check("the window still holds just under 12 s",
		_manager.boss_cc_stage(boss) == 3 and _manager.boss_cc_immune(boss))
	_manager._physics_process(0.2)
	check("12 s without hard CC resets the stage",
		_manager.boss_cc_stage(boss) == 0 and not _manager.boss_cc_immune(boss))

	_manager.set_status(boss, &"soft", 60.0, 1.0, 0.1, false, 3.0, false, 0.2)
	check("boss soft controls clamp to the safe floors",
		is_equal_approx(boss.boon_time_scale, BoonManager.BOSS_MIN_TIME_SCALE)
		and is_equal_approx(boss.boon_attack_scale, BoonManager.BOSS_MIN_ATTACK_SCALE)
		and is_equal_approx(boss.boon_windup_scale, BoonManager.BOSS_MAX_WINDUP_SCALE)
		and not boss.boon_stunned)
	_manager.set_status(boss, &"soft_freeze", 1.5, 1.0, 0.0)
	check("a hard freeze overrides the floor while active", is_zero_approx(boss.boon_time_scale))
	_manager._physics_process(1.51)
	check("the soft floor returns after the hard freeze",
		is_equal_approx(boss.boon_time_scale, BoonManager.BOSS_MIN_TIME_SCALE))
	_manager.clear_status(boss, &"soft")
	check("clearing boss controls restores full speed", is_equal_approx(boss.boon_time_scale, 1.0))

	projectile.queue_free()
	plain.queue_free()
	boss.queue_free()
	await _frames(2)


func _run_flawless() -> void:
	var boss := FLAWLESS_SCENE.instantiate() as FlawlessDoppelganger
	add_child(boss)
	boss.position = Vector3(8, 0.05, 0)
	boss.setup(_player, [])
	boss.set_combat_active(true)
	boss.set_physics_process(false)
	await _frames(3)
	check("the final shell is a boss target", boss.is_boss)

	_manager.set_status(boss, &"final_first", 5.0, 1.0, 0.0)
	_manager.set_status(boss, &"final_second", 5.0, 1.0, 1.0, true)
	_manager.set_status(boss, &"final_third", 5.0, 1.0, 0.0)
	check("the final shell follows the same 1x/0.5x/0.25x ladder into immunity",
		_manager.boss_cc_stage(boss) == 3 and _manager.boss_cc_immune(boss))
	for source in [&"final_first", &"final_second", &"final_third"]:
		_manager.clear_status(boss, source)
	check("clearing the hard CC leaves the immune shell mobile",
		not boss.boon_stunned and is_equal_approx(boss.boon_time_scale, 1.0)
		and _manager.boss_cc_immune(boss))

	_player.fragments.configure_deprivation([0, 1, 2, 3])
	for realm in 4:
		_player.fragments.acquire(realm)
	_player.global_position = boss.global_position + Vector3(0, 0.05, 4)
	await _frames(2)
	check("Slumber resonance still breaks an immune final shell",
		_player.fragments.try_slumber_resonance()
		and boss.phase == FlawlessDoppelganger.Phase.EXPOSED
		and is_equal_approx(boss.tempo_multiplier(), 0.25))

	boss.resonance_left = 0.0
	boss.phase = FlawlessDoppelganger.Phase.GUARD
	boss.phase_left = 20.0
	boss.position = Vector3(11, 0.05, 0)
	_player.global_position = Vector3(9, 0.05, 0)
	boss.set_physics_process(true)
	var wall := FlawlessFractureWall.new()
	wall.position = Vector3(13.5, 1.5, 0)
	add_child(wall)
	await _frames(3)
	_player.fragments.barrier = 0.0
	_player.health.apply_damage(5.0, Hitbox.BodyPart.BODY, boss)
	var ticks := 0
	while not wall.broken and ticks < 180:
		await get_tree().physics_frame
		ticks += 1
	check("the innate wall break still exposes the immune final shell",
		wall.broken and boss.wall_breaks == 1
		and boss.phase == FlawlessDoppelganger.Phase.EXPOSED)
	check("the innate break leaves the CC memory untouched", _manager.boss_cc_immune(boss))

	_manager.set_status(boss, &"final_cleanup", 5.0, 1.0, 0.0, true)
	check("the cleanup request stays immune", _manager.boss_cc_stage(boss) == 3)
	_manager.clear()
	check("death and teardown cleanup clears the boss CC memory",
		_manager.boss_cc_stage(boss) == 0 and not _manager.boss_cc_immune(boss))
	boss.set_physics_process(false)
	boss.queue_free()
	wall.queue_free()
	await _frames(2)


func _spawn_enemy(point: Vector3) -> Enemy:
	var enemy := ENEMY_SCENE.instantiate() as Enemy
	add_child(enemy)
	enemy.position = point
	enemy.setup(_player, [])
	enemy.set_physics_process(false)
	return enemy


func _build_floor() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = CollisionLayers.NONE
	body.position = Vector3(0, -0.5, 0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(80, 1, 80)
	shape.shape = box
	body.add_child(shape)
	add_child(body)


func _finish() -> void:
	if is_instance_valid(_manager):
		_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("BOSS CC DR: %s (%d checks, %d failed)" % [
		"ALL PASSED" if failures == 0 else "FAIL", checks, failures])
	get_tree().quit(0 if failures == 0 else 1)


func _frames(count: int) -> void:
	for index in count:
		await get_tree().physics_frame


func check(label: String, passed: bool) -> void:
	checks += 1
	if not passed:
		failures += 1
	print("%s %s" % ["PASS" if passed else "FAIL", label])
