extends Node3D
## Fixed-step real Player, production Sloth CharacterBody, WORLD contacts and
## flying projectiles. No fabricated wall-hit callbacks in these core checks.
signal step_finished
var failed := 0
var checks := 0
var finished := false
var player: Player
var manager: BoonManager
var effect: WrathBoons
var arena: Node3D
var _slams: Array[Dictionary] = []

func _ready() -> void:
	process_physics_priority = 100
	await _run()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	if not finished:
		failed += 1
	print("WRATH CORE: %d checks, %d failed, completed=%s" % [checks, failed, finished])
	get_tree().quit(0 if failed == 0 else 1)

func _physics_process(_delta: float) -> void:
	step_finished.emit()

func _run() -> void:
	await _world()
	var pool := load("res://buffs/resources/wrath/pool.tres") as BoonPool
	_check("core resource pool has gun/blade/dash", pool.cards.size() >= 3 and pool.cards.slice(0, 3).all(func(card: BoonData): return card.core))
	manager.equip(load("res://buffs/resources/wrath/wrath_gun_cannon.tres"))
	effect = manager.effect_for(load("res://buffs/effects/wrath_effect.gd")) as WrathBoons
	var enemy := _enemy(Vector3(0, 0, -3))
	await _frames(3)
	var health_before := enemy.health.health
	_check("actual gun starts a shot", player.weapon.try_fire())
	_check("crystal shot has travel time, no hidden hitscan", enemy.health.health == health_before)
	await _frames(3)
	_check("real projectile applies gun damage and impulse", enemy.health.health < health_before and effect.has_spite(enemy) and enemy.global_position.z < -3.0)
	var after_shot := enemy.health.health
	await _frames(20)
	_check("real WORLD contact triggers one slam", _slams.size() == 1 and not _slams[0].rupture)
	_check("wall slam deals 60 after the gun body-part hit", is_equal_approx(enemy.health.health, after_shot - 60.0))
	_check("wall hit applies 0.8 second stun", enemy.boon_stunned)
	_check("real enemy never teleports through wall", enemy.global_position.z > -6.0)
	enemy.queue_free()
	await _frames(2)
	var reflected_target := _enemy(Vector3(5, 0, 0))
	await _frames(3)
	var shot := {"origin": Vector3(5, 1.5, -2), "direction": Vector3.FORWARD, "damage_multiplier": 1.0}
	var bullet := WrathProjectile.launch(manager, shot)
	await _frames(4)
	_check("WORLD bounce uses reflected direction and +60% damage", is_instance_valid(bullet) and bullet.ricochets_left == 0 and is_equal_approx(bullet.damage, 56.0) and (-bullet.global_basis.z).z > 0.99)
	await _frames(6)
	_check("ricochet hits a real enemy for boosted damage", is_equal_approx(reflected_target.health.health, 944.0))
	reflected_target.queue_free()
	await _frames(2)
	manager.equip(load("res://buffs/resources/wrath/wrath_blade_sweep.tres"))
	_check("blade resource expands real arc by 50 percent", is_equal_approx(player.stats.get_value(Stats.MELEE_ARC), 1.5))
	var side_target := _enemy(Vector3(2.1, 0, -1.8))
	await _frames(3)
	player.melee.swing_now()
	player.melee._process(0.08)
	player.melee._process(0.12)
	_check("expanded arc hits a target outside the original cone", side_target.health.health < 1000.0)
	_check("basic melee impact does not overwrite Wrath impulse", side_target._impact_velocity.length() >= 23.0)
	await _frames(25)
	_check("blade collision creates secondary lava explosion", side_target.health.health <= 855.0)
	side_target.queue_free()
	player.melee.cancel()
	await _frames(2)
	manager.equip(load("res://buffs/resources/wrath/wrath_dash_ram.tres"))
	var ram_target := _enemy(Vector3(0, 0, -2.8))
	await _frames(3)
	var count_before := _slams.size()
	player.set_physics_process(true)
	_check("real Shift action starts ram", player.dash.try_dash())
	await _frames(25)
	player.set_physics_process(false)
	_check("dash swept volume pushes into actual wall contact", _slams.size() > count_before and ram_target.health.health <= 940.0)
	_check("dash cannot leave armor modifier stuck", player.stats.get_value(Stats.ARMOR) == 0.0)
	ram_target.queue_free()
	await _frames(2)
	var floor_target := _enemy(Vector3(10, 0, 0))
	await _frames(3)
	count_before = _slams.size()
	effect.knock(floor_target, Vector3.FORWARD, 2.5)
	await _frames(25)
	_check("floor contacts do not count as wall slams", _slams.size() == count_before and floor_target.health.health == 1000.0)
	var close_target := _enemy(Vector3(-3, 0, -5.25))
	await _frames(2)
	count_before = _slams.size()
	effect.knock(close_target, Vector3.FORWARD, 3.0)
	await _frames(4)
	_check("near-wall enemy still receives real first-contact slam", _slams.size() == count_before + 1)
	close_target.queue_free()
	await _frames(2)
	var slow_target := _enemy(Vector3(-3, 0, -5.25))
	await _frames(2)
	manager.set_status(slow_target, &"impact_test_slow", 0.5, 0.2)
	count_before = _slams.size()
	effect.knock(slow_target, Vector3.FORWARD, 3.0)
	await _frames(8)
	_check("slowed movement below 6m/s cannot fabricate high-speed contact", _slams.size() == count_before and slow_target.health.health == 1000.0)
	slow_target.queue_free()
	await _frames(2)
	manager.remove(WrathBoons.GUN)
	manager.remove(WrathBoons.BLADE)
	manager.remove(WrathBoons.DASH)
	_check("removing family restores enemy collision mask", (floor_target.collision_mask & CollisionLayers.ENEMIES) == 0)
	finished = true

func _world() -> void:
	arena = Node3D.new()
	add_child(arena)
	_wall(Vector3(0, -0.5, 0), Vector3(40, 1, 40))
	_wall(Vector3(0, 2, -6), Vector3(12, 4, 0.4))
	player = preload("res://actors/player/player.tscn").instantiate() as Player
	arena.add_child(player)
	player.set_physics_process(false)
	player.gravity = 0.0
	player.weapon.set_process(false)
	player.weapon.data = player.weapon.data.duplicate()
	player.weapon.data.hip_spread = 0.0
	player.weapon.data.ads_spread = 0.0
	player.weapon.data.spread_per_shot = 0.0
	player.melee.set_process(false)
	manager = player.boons
	manager.event_dispatched.connect(func(event: StringName, ctx: Dictionary):
		if event == &"wall_slam":
			_slams.append(ctx.duplicate()))
	await _frames(3)

func _enemy(position: Vector3) -> SlothEnemy:
	var enemy := preload("res://actors/enemy/sloth/sloth_enemy.tscn").instantiate() as SlothEnemy
	enemy.kind = SlothEnemy.Kind.RECLUSE
	enemy.position = position
	arena.add_child(enemy)
	enemy.health.max_health = 1000.0
	enemy.health.health = 1000.0
	return enemy

func _wall(position: Vector3, size: Vector3) -> void:
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = position
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	wall.add_child(collision)
	arena.add_child(wall)

func _frames(count: int) -> void:
	for i in count:
		await step_finished

func _check(label: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failed += 1
	print("%s %s" % ["PASS" if ok else "FAIL", label])
