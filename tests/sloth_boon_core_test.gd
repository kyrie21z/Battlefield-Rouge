extends Node3D
## Production Player, Weapon, Health and Hitbox integration. Explicit effect
## stepping makes the 1.5s boundary independent of render rate.
class Target extends Node3D:
	var team := 1
	var health: Health
	var boon_time_scale := 1.0
	var boon_movement_scale := 1.0
	var boon_stunned := false

var _failed := 0
var _player: Player
var _manager: BoonManager
var _effect: SlothEffect


func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("SLOTH CORE: %s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	await _finish_fixture()
	get_tree().quit(0 if _failed == 0 else 1)


func _run() -> void:
	_player = (load("res://actors/player/player.tscn") as PackedScene).instantiate() as Player
	add_child(_player)
	_player.set_physics_process(false)
	_player.weapon.set_process(false)
	_player.melee.set_process(false)
	_player.dash.set_physics_process(false)
	_manager = _player.get_node("BoonManager") as BoonManager
	_manager.set_physics_process(false)
	_manager.set_process(false)
	for id in [SlothEffect.GUN, SlothEffect.BLADE, SlothEffect.DASH]:
		_check("equip " + id, _manager.equip(load("res://buffs/resources/sloth/%s.tres" % id)))
	_effect = _manager.effect_for(load("res://buffs/effects/sloth_effect.gd")) as SlothEffect
	var target := _target(Vector3(0, 0, -3))
	var neighbour := _target(Vector3(1.2, 0, -3))
	var behind_wall := _target(Vector3(0, 0, -5))
	var ally := _target(Vector3(-1.2, 0, -3), 0)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = Vector3(0, 1, -4)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(4, 3, 0.2)
	shape.shape = box
	wall.add_child(shape)
	add_child(wall)
	for index in 3:
		await get_tree().physics_frame
	_player.weapon._shoot_ray(Vector3(0, 1, 0), Vector3.FORWARD)
	_check("actual pistol hit applies Latency", _effect.has_latency(target))
	if not _effect.has_latency(target):
		return
	var clock := _effect.clocks[target.get_instance_id()] as LatencyStatus
	_check("implanting shot is not retroactively accumulated", is_zero_approx(clock.damage_pressure))
	_player.weapon._shoot_ray(Vector3(0, 1, 0), Vector3.FORWARD)
	_check("repeated gun shot keeps separate 35 damage and 25 shot ledgers", is_equal_approx(clock.damage_pressure, 35.0) and is_equal_approx(clock.shot_pressure, 25.0))
	var before := target.health.health
	_effect.tick(1.49)
	_check("no early detonation", is_equal_approx(before, target.health.health))
	get_tree().paused = true
	clock.advance(20.0)
	_check("pause cannot advance countdown", clock.active and is_equal_approx(clock.remaining, 0.01))
	get_tree().paused = false
	_effect.tick(0.011)
	_check("1.5 seconds delivers 60 + 35 + 25 actual burst", is_equal_approx(before - target.health.health, 120.0))
	_check("burst uses unique health and visible neighbours", is_equal_approx(neighbour.health.health, 880.0))
	_check("WORLD cover and allies reject AoE", behind_wall.health.health == 1000.0 and ally.health.health == 1000.0 and _player.health.health == 100.0)
	_check("detonation cleans clock and slow", not _effect.has_latency(target) and is_equal_approx(target.boon_movement_scale, 1.0))
	# Resolve a real production blade hit through its hitbox path. It must see
	# the pre-existing clock and include the slash's damage before exploding.
	_effect.apply_latency(target)
	before = target.health.health
	var hitbox := _manager.hitbox_of(target)
	_player.melee._struck.clear()
	_player.melee._strike_one(_player.melee.current(), hitbox, Vector3(0, 1, -1.5), Vector3.FORWARD)
	_check("production blade forces clock detonation", not _effect.has_latency(target))
	_check("blade burst includes slash then multiplies by 1.5", is_equal_approx(before - target.health.health, 55.0 + (60.0 + 55.0) * 1.5))
	_check("blade clock stat doubles", is_equal_approx(_player.stats.get_value(&"clock_progress"), 2.0))
	# Real Dash starts the first aura, then finishes at the actual sampled player
	# position. No ideal end point or scene lookup is supplied to the effect.
	_check("production Dash starts", _player.dash.try_dash())
	_check("dash start makes one aura", _effect.auras.size() == 1)
	_player.global_position = Vector3(0, 0, -2)
	_player.dash._physics_process(0.2)
	await get_tree().process_frame
	_check("dash finish records the actual position", _effect.auras.size() == 2 and (_effect.auras.back().origin as Vector3).is_equal_approx(_player.global_position))
	_effect.tick(0.01)
	_check("touching the landing aura roots and marks target", _effect.has_latency(target) and is_zero_approx(target.boon_movement_scale))
	_effect.tick(0.5)
	var ctx := {"damage_multiplier": 1.0}
	_manager.dispatch(&"shoot_before", ctx)
	_check("settled dash boosts one attack by 50 percent", is_equal_approx(ctx.damage_multiplier, 1.5))
	var next_ctx := {"damage_multiplier": 1.0}
	_manager.dispatch(&"shoot_before", next_ctx)
	_check("boost is consumed exactly once", is_equal_approx(next_ctx.damage_multiplier, 1.0))
	# Exercise actual queue-free lifecycle before the next effect tick.
	for wave in _effect._waves:
		if is_instance_valid(wave):
			wave.queue_free()
	var departing := _target(Vector3(20, 0, -3))
	_effect.apply_latency(departing)
	var departing_id := departing.get_instance_id()
	departing.queue_free()
	await get_tree().process_frame
	_effect.tick(0.0)
	_check("freed transient waves and departing enemies are pruned safely", _effect._waves.is_empty() and not _effect.clocks.has(departing_id))
	_manager.clear()
	_check("loadout cleanup restores target slow and clock stat", not _effect.has_latency(target) and is_equal_approx(target.boon_movement_scale, 1.0) and is_equal_approx(_player.stats.get_value(&"clock_progress"), 1.0))


func _target(point: Vector3, team := 1) -> Target:
	var actor := Target.new()
	actor.team = team
	actor.position = point
	actor.health = Health.new()
	actor.health.name = "Health"
	actor.health.max_health = 1000.0
	actor.health.team = team
	actor.add_child(actor.health)
	for index in 2:
		var hitbox := Hitbox.new()
		hitbox.body_part = Hitbox.BodyPart.BODY
		hitbox.position = Vector3(0, 0.8 + index * 0.4, 0)
		var collision := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.3
		collision.shape = sphere
		hitbox.add_child(collision)
		actor.add_child(hitbox)
	add_child(actor)
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
	# Fixed FPS can advance a SceneTreeTimer faster than the audio worker.
	# Let the real worker release stopped WAV/playback references before exit.
	OS.delay_msec(250)
	await get_tree().process_frame
