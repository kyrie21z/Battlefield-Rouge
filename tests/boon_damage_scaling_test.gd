extends "res://tests/wrath_core_test.gd"
## Full-pool integration: actual HP loss under Wrath offense, with settled
## Sloth pressure and Sorrow debt kept separate from raw ability values.
var _targets: Array[Node] = []

func _ready() -> void:
	process_physics_priority = 100
	await _run()
	manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(250)
	await get_tree().process_frame
	print("DAMAGE SCALING: %d checks, %d failed, completed=%s" % [checks, failed, finished])
	get_tree().quit(0 if failed == 0 and finished else 1)

func _run() -> void:
	await _world()
	manager.set_physics_process(false)
	await _loadout(["wrath_desperation", "sorrow_gun_needles"])
	var enemy := _target(Vector3(0, 0, -3))
	await _frames(3)
	var before := enemy.health.health
	player.weapon.try_fire()
	_check("natural pistol consumes low-health 60 percent offense once", is_equal_approx(before - enemy.health.health, 56.0))
	var sorrow = _family("sorrow")
	before = enemy.health.health
	sorrow.tick(0.5)
	_check("raw Sorrow erosion receives offense then one-layer vulnerability", is_equal_approx(before - enemy.health.health, 7.04))
	await _loadout(["wrath_desperation"])
	enemy = _target(Vector3(0, 0, -3))
	await _frames(3)
	before = enemy.health.health
	player.melee._strike_one(player.melee.blade_data, manager.hitbox_of(enemy), player.global_position + Vector3.UP, Vector3.FORWARD)
	_check("natural blade consumes low-health offense once", is_equal_approx(before - enemy.health.health, 88.0))
	await _loadout(["wrath_desperation", "wrath_gun_cannon"])
	enemy = _target(Vector3(0, 0, -3))
	await _frames(3)
	before = enemy.health.health
	player.weapon.try_fire()
	await _frames(3)
	_check("Wrath real crystal projectile preserves launch-time offense once", is_equal_approx(before - enemy.health.health, 56.0))
	await _frames(20)
	_check("Wrath fixed wall slam receives the same full damage bonus", is_equal_approx(before - enemy.health.health, 56.0 + 96.0))
	await _loadout(["wrath_desperation"])
	enemy = _target(Vector3(10, 0, -3))
	await _frames(3)
	var bullet := Projectile.spawn(arena, Vector3(10, 1.45, -1), Vector3.FORWARD, player, 18.0, 30.0, [])
	_check("player-owned raw projectile gets the shared hit pipeline", bullet.boon_hook.is_valid())
	before = enemy.health.health
	await _frames(6)
	_check("raw spawned projectile deals scaled real damage exactly once", is_equal_approx(before - enemy.health.health, 28.8))
	await _loadout(["wrath_desperation", "sloth_gun_pulse", "sloth_inertia"])
	enemy = _target(Vector3(10, 0, 0))
	await _frames(3)
	var sloth = _family("sloth")
	var latency: LatencyStatus = sloth.apply_latency(enemy)
	manager.apply_damage(enemy, 10.0)
	latency.add_shot_pressure(25.0)
	_check("Sloth pressure records actual scaled HP loss", is_equal_approx(latency.damage_pressure, 16.0))
	before = enemy.health.health
	latency.detonate()
	_check("Sloth burst scales base and shot only, retaining actual pressure", is_equal_approx(before - enemy.health.health, (60.0 + 25.0) * 1.6 + 16.0 * 1.5))
	await _loadout(["wrath_desperation", "sloth_gun_pulse", "sloth_resonance"])
	var fragile := _target(Vector3(10, 0, 0))
	var nearby := _target(Vector3(11.5, 0, 0))
	fragile.health.health = 10.0
	await _frames(3)
	sloth = _family("sloth")
	latency = sloth.apply_latency(fragile)
	before = nearby.health.health
	latency.detonate()
	_check("Sloth rebound reuses scaled burst without a second offense multiplier", is_equal_approx(before - nearby.health.health, 192.0))
	await _loadout(["wrath_desperation", "fear_flash_backstab"])
	enemy = _target(Vector3(10, 0, 0))
	await _frames(3)
	var fear = _family("fear")
	fear.apply_panic(enemy)
	before = enemy.health.health
	fear.detonate_all_flaws({"damage_scaled": true, "damage": 999.0})
	_check("Fear detonation resets copied scaling and scales new base once", is_equal_approx(before - enemy.health.health, 112.0))
	await _loadout(["wrath_desperation", "sorrow_gun_needles", "sorrow_blade_tide", "sorrow_buffer", "wrath_dash_ram", "dual_spiteful_deluge"], false)
	enemy = _target(Vector3(2, 0, 0))
	await _frames(3)
	player.health.apply_damage(60.0, Hitbox.BodyPart.BODY, enemy)
	_check("Sorrow initially defers exactly half the incoming hit", is_equal_approx(player.health.health, 70.0))
	before = enemy.health.health
	var hp_before := player.health.health
	manager._physics_process(0.5)
	_check("settled Sorrow debt stays fixed despite changed player offense", is_equal_approx(hp_before - player.health.health, 5.0) and player.stats.get_value(Stats.DAMAGE) > 1.0)
	_check("two-hundred-percent debt retaliation does not reapply offense", is_equal_approx(before - enemy.health.health, 10.0))
	finished = true

func _loadout(ids: Array, low_health := true) -> void:
	manager.clear()
	for target in _targets:
		if is_instance_valid(target):
			target.queue_free()
	_targets.clear()
	await _frames(2)
	player.health.health = 30.0 if low_health else 100.0
	player.weapon.complete_reload()
	player.weapon.ammo = 8
	player.weapon._cooldown = 0.0
	player.melee.cancel()
	for id: String in ids:
		var choices := BoonCatalog.all().filter(func(card): return card.id == id)
		_check("equip cross-family dependency " + id, not choices.is_empty() and manager.equip(choices[0]))
	manager._physics_process(0.001)

func _family(id: String) -> BoonEffect:
	return manager.effect_for(load("res://buffs/effects/%s_effect.gd" % id))

func _target(position_value: Vector3) -> SlothEnemy:
	var enemy := _enemy(position_value)
	enemy.health.headshot_multiplier = 1.0
	enemy.health.limb_multiplier = 1.0
	_targets.append(enemy)
	return enemy
