extends Node3D
class Target extends Node3D:
	var team := 1
	var health: Health
	var boon_time_scale := 1.0
	var boon_movement_scale := 1.0
	var boon_stunned := false
	var boon_windup_scale := 1.0

var _failed := 0
var _core_finished := false
var _player: Player
var _manager: BoonManager
var _effect: SorrowEffect


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	_check("core scenario reaches final boundary", _core_finished)
	print("SORROW CORE: %s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	await _finish_fixture()
	get_tree().quit(0 if _failed == 0 else 1)


func _run() -> void:
	_player = (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.dash.set_physics_process(false)
	_manager = _player.boons
	_manager.set_physics_process(false)
	for id: String in [SorrowEffect.GUN, SorrowEffect.BLADE, SorrowEffect.DASH]:
		_check("equip " + id, _manager.equip(load("res://buffs/resources/sorrow/%s.tres" % id)))
	_effect = _manager.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	var target := _target(Vector3(0, 0, -3))
	for index in 3:
		await get_tree().physics_frame
	for index in 5:
		_player.weapon._shoot_ray(Vector3(0, 1, 0), Vector3.FORWARD)
	_check("five real pistol hits saturate at five erosion layers", _effect.erosion_layers(target) == 5)
	_check("each layer amplifies actual incoming gun damage by ten percent", is_equal_approx(target.health.health, 790.0))
	_check("first saturation drops one real crystal", _effect.tears.size() == 1)
	_player.weapon._shoot_ray(Vector3(0, 1, 0), Vector3.FORWARD)
	_check("additional full-stack hit does not duplicate saturation crystal", _effect.tears.size() == 1)
	var before := target.health.health
	_effect.tick(0.49)
	_check("DoT waits for half-second cadence", is_equal_approx(before, target.health.health))
	_effect.tick(0.01)
	_check("five-layer DoT deals amplified real HP damage", is_equal_approx(before - target.health.health, 30.0))
	var state := _effect.states[target.get_instance_id()] as ErosionStatus
	get_tree().paused = true
	state.advance(10.0)
	_check("pause keeps erosion timer unchanged", is_equal_approx(state.remaining, 4.5))
	get_tree().paused = false
	_player.global_position = Vector3(0, 0, -3)
	_effect.tick(0.21)
	_check("walking to crystal consumes it exactly once", _effect.tears.is_empty())
	_check("real pickup grants 25 over-shield", is_equal_approx(_manager.shield_amount, 25.0))
	before = _player.health.health
	_player.health.apply_damage(25.0, Hitbox.BodyPart.BODY, target)
	_check("picked shield absorbs actual incoming damage", is_equal_approx(before, _player.health.health) and is_zero_approx(_manager.shield_amount))
	# A blade waves through forward enemy bullets; rear bullets stay alive.
	_player.global_position = Vector3(-10, 0, 0)
	var front := Projectile.spawn(self, Vector3(-10, 1.0, -2), Vector3.BACK, target, 10.0, 4.0, [])
	var back := Projectile.spawn(self, Vector3(-10, 1.0, 2), Vector3.FORWARD, target, 10.0, 4.0, [])
	front.set_physics_process(false)
	back.set_physics_process(false)
	var wave_target := _target(Vector3(-10, 0, -3))
	_effect.spawn_tear(Vector3(-10, 0, -1.5))
	var launched_tear: TearCrystal = _effect.tears.back()
	var shots_before := _manager.projectiles().filter(func(shot): return shot.source == _player).size()
	_player.melee.swing_now()
	_player.melee._process(0.21)
	_check("real blade active frame clears only front hostile bullets", front.is_queued_for_deletion() and not back.is_queued_for_deletion())
	_check("blade wave applies one erosion layer across fan", _effect.erosion_layers(wave_target) == 1)
	_check("blade consumes ground tear and fires three owned projectiles", launched_tear.consumed and _manager.projectiles().filter(func(shot): return shot.source == _player).size() == shots_before + 3)
	_player.melee.cancel()
	# Actual dash endpoint is provided by PlayerDash after the movement frame.
	_player.global_position = Vector3(-20, 0, 0)
	var wet_target := _target(Vector3(-20, 0, -2))
	_check("production dash starts water ribbon", _player.dash.try_dash())
	_player.global_position = Vector3(-20, 0, -2)
	_player.dash._physics_process(0.2)
	await get_tree().process_frame
	_check("water ribbon samples actual start-to-end route", _effect.water_regions().size() >= 3)
	_effect.tick(0.5)
	_check("water slows actual enemy movement and adds one layer", is_equal_approx(wet_target.boon_movement_scale, 0.6) and _effect.erosion_layers(wet_target) == 1)
	_check("overlapping water samples cannot multiply layer cadence", _effect.erosion_layers(wet_target) == 1)
	_check("player water contact gives reversible move speed", is_equal_approx(_player.stats.get_value(Stats.MOVE_SPEED), 1.3))
	_player.position.x -= 5.0
	_effect.tick(0.01)
	_check("leaving water removes player move modifier", is_equal_approx(_player.stats.get_value(Stats.MOVE_SPEED), 1.0))
	_effect.tick(3.0)
	_check("three-second ribbon expires and restores enemy speed", _effect.waters.is_empty() and is_equal_approx(wet_target.boon_movement_scale, 1.0))
	# Death is delivered through a real Health signal and Events lifecycle.
	var dying := _target(Vector3(-30, 0, -3))
	_effect.add_erosion(dying, 1)
	dying.health.health = 1.0
	var count := _effect.tears.size()
	_manager.apply_damage(dying, 10.0)
	_check("eroded enemy death drops a tear once", _effect.tears.size() == count + 1)
	_manager.clear()
	_check("loadout cleanup removes all water and erosion", _effect.states.is_empty() and _effect.waters.is_empty() and is_equal_approx(wet_target.boon_movement_scale, 1.0))
	_core_finished = true


func _target(point: Vector3, team := 1) -> Target:
	var actor := Target.new()
	actor.team = team
	actor.position = point
	actor.health = Health.new()
	actor.health.name = "Health"
	actor.health.team = team
	actor.health.max_health = 1000.0
	actor.add_child(actor.health)
	var hitbox := Hitbox.new()
	hitbox.body_part = Hitbox.BodyPart.BODY
	hitbox.position.y = 1.0
	var collision := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.45
	collision.shape = shape
	hitbox.add_child(collision)
	actor.add_child(hitbox)
	add_child(actor)
	actor.health.died.connect(func(_source: Node): Events.enemy_killed.emit(actor))
	_manager.register_enemy(actor)
	return actor


func _check(label: String, ok: bool) -> void:
	if not ok:
		_failed += 1
	print("[%s] %s" % ["ok" if ok else "FAIL", label])


func _finish_fixture() -> void:
	if is_instance_valid(_manager):
		_manager.clear()
	_effect = null
	_manager = null
	_player = null
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
