extends "res://tests/sloth_boon_core_test.gd"
## Adds #116 behavior on the same real Player rig. Resource eligibility is
## checked through the production manager; combat assertions inspect HP/motion.

func _ready() -> void:
	await get_tree().process_frame
	await super._run()
	await _run_traits()
	print("SLOTH TRAITS: %s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	await _finish_fixture()
	get_tree().quit(0 if _failed == 0 else 1)


func _card(id: String) -> BoonData:
	return load("res://buffs/resources/sloth/%s.tres" % id) as BoonData


func _run_traits() -> void:
	_check("unmet gun-or-blade prerequisite excludes descent", not _manager.can_equip(_card(SlothTraits.DESCENT)))
	_check("unmet dash-or-passive prerequisite excludes time field", not _manager.can_equip(_card(SlothTraits.FIELD)))
	_check("no traits excludes legendary", not _manager.can_equip(_card(SlothTraits.ETERNAL)))
	_manager.equip(_card(SlothEffect.GUN))
	_effect = _manager.effect_for(load("res://buffs/effects/sloth_effect.gd")) as SlothEffect
	var traits := _effect._traits as SlothTraits
	_check("one gun satisfies OR prerequisite", _manager.can_equip(_card(SlothTraits.DESCENT)))
	_manager.equip(_card(SlothTraits.INERTIA))
	_check("one trait cannot unlock legendary", not _manager.can_equip(_card(SlothTraits.ETERNAL)))
	_check("one passive satisfies time-field alternative", _manager.can_equip(_card(SlothTraits.FIELD)))
	_manager.equip(_card(SlothTraits.RESONANCE))
	_check("two sloth traits unlock legendary", _manager.can_equip(_card(SlothTraits.ETERNAL)))
	_manager.remove(SlothTraits.RESONANCE)
	var pressured := _target(Vector3(-12, 0, -4))
	_effect.apply_latency(pressured)
	_manager.apply_damage(pressured, 20.0, {"tag": &"test_external"})
	var before := pressured.health.health
	_effect.tick(1.51)
	_check("inertia multiplies actual pressure by 1.5", is_equal_approx(before - pressured.health.health, 90.0))
	_manager.remove(SlothTraits.INERTIA)
	_manager.equip(_card(SlothTraits.RESONANCE))
	var doomed := _target(Vector3(-24, 0, -4))
	var rebound := _target(Vector3(-20, 0, -4))
	doomed.health.health = 40.0
	_effect.apply_latency(doomed)
	_effect.tick(1.51)
	_check("radius grows from 3 to 4.8m and one equal rebound follows lethal burst", is_equal_approx(rebound.health.health, 880.0))
	_manager.remove(SlothTraits.RESONANCE)
	_manager.equip(_card(SlothTraits.STILLNESS))
	traits.tick(1.21)
	_player.health.dash_invulnerable = false
	_player.health.invulnerable = false
	before = _player.health.health
	_player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, pressured)
	_check("stationary status reduces actual incoming HP loss by 40 percent", is_equal_approx(before - _player.health.health, 12.0))
	_player.weapon.ammo = 0
	_player.weapon.try_reload()
	_check("rest doubles actual empty recharge rate", is_equal_approx(_player.weapon._reload_duration(true), _player.weapon.data.reload_time_empty * 0.5))
	_player.weapon._finish_reload()
	_player.position.x += 1.0
	traits.tick(0.01)
	before = _player.health.health
	_player.health.apply_damage(20.0, Hitbox.BodyPart.BODY, pressured)
	_check("movement removes damage reduction source immediately", is_equal_approx(before - _player.health.health, 20.0))
	_manager.remove(SlothTraits.STILLNESS)
	_manager.equip(_card(SlothTraits.RELOAD))
	_player.weapon.ammo = 0
	_player.weapon.try_reload()
	_player.weapon._finish_reload()
	_check("clean empty refill grants 35 actual barrier", is_equal_approx(_manager.shield_amount, 35.0))
	before = _player.health.health
	_player.health.apply_damage(35.0, Hitbox.BodyPart.BODY, pressured)
	_check("over-shield absorbs real incoming damage", is_equal_approx(before, _player.health.health) and is_zero_approx(_manager.shield_amount))
	_player.weapon.ammo = 0
	_player.weapon.try_reload()
	_player.health.apply_damage(1.0, Hitbox.BodyPart.BODY, pressured)
	_player.weapon._finish_reload()
	_check("damaged bloom does not grant shield", is_zero_approx(_manager.shield_amount))
	_player.weapon.ammo = 4
	_player.weapon.try_reload()
	_player.weapon._finish_reload()
	_check("tactical refill does not grant empty-magazine bonus", is_zero_approx(_manager.shield_amount))
	_manager.equip(_card(SlothTraits.HEAVY))
	var deep := _target(Vector3(-36, 0, -3))
	traits.tick(1.5)
	_player.weapon._cooldown = 0.0
	_player.weapon._reload_left = 0.0
	# Successful shot boundary reserves the beat; actual ray resolves its hit.
	_manager.dispatch(&"shoot_before", {"damage_multiplier": 1.0})
	_player.weapon._shoot_ray(Vector3(-36, 1, 0), Vector3.FORWARD)
	_check("heavy beat changes actual enemy movement to 30 percent", _effect.has_latency(deep) and is_equal_approx(deep.boon_movement_scale, 0.3))
	_manager.equip(_card(SlothTraits.DROWSY))
	var bullet := Projectile.spawn(self, Vector3(-36, 1, -2), Vector3.BACK, deep, 10.0, 10.0, [])
	_manager.register_projectile(bullet)
	bullet.set_physics_process(false)
	var from := bullet.global_position
	bullet._physics_process(0.1)
	_check("drowsy emitted projectile travels half actual distance", is_equal_approx(from.distance_to(bullet.global_position), 0.5))
	_manager.remove(SlothTraits.DROWSY)
	traits.tick(0.0)
	_check("removing drowsy restores existing projectiles while core remains", is_equal_approx(bullet.boon_time_scale, 1.0))
	_manager.equip(_card(SlothTraits.DESCENT))
	var chance := {"target": deep, "proc_depth": 0, "kind": &"gun", "damage": 10.0}
	traits.on_event(&"hit_before", chance)
	_check("descent adds exactly 25 percent to shared critical roll", is_equal_approx(chance.get("crit_chance_add", 0.0), 0.25))
	_manager.set_modifier(&"test_critical", {Stats.CRIT_CHANCE: {"add": 0.75}})
	before = deep.health.health
	_manager.apply_damage(deep, 10.0, {"kind": &"gun", "proc_depth": 0})
	_check("descent chance combines with shared stats to double actual damage", is_equal_approx(before - deep.health.health, 20.0))
	_manager.remove_modifier(&"test_critical")
	var sleeper := _target(Vector3(-35, 0, -3))
	(_effect.clocks[deep.get_instance_id()] as LatencyStatus).detonate()
	_check("real burst sleeps nearby survivors", sleeper.boon_stunned)
	_manager.equip(_card(SlothTraits.FIELD))
	_effect.apply_latency(deep)
	_effect.apply_latency(sleeper)
	traits.tick(0.0)
	_check("two active clocks slow enemy world to 80 percent", is_equal_approx(sleeper.boon_time_scale, 0.8))
	_check("active field accelerates dash recharge", is_equal_approx(_player.stats.get_value(Stats.DASH_RECHARGE), 1.5))
	_effect._remove_clock(sleeper.get_instance_id())
	traits.tick(0.0)
	_check("threshold loss removes world and recharge modifiers", is_equal_approx(sleeper.boon_time_scale, 1.0) and is_equal_approx(_player.stats.get_value(Stats.DASH_RECHARGE), 1.0))
	_manager.equip(_card(SlothTraits.ETERNAL))
	var watcher := (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as Enemy
	watcher.position = Vector3(-55, 0, -3)
	add_child(watcher)
	watcher.set_physics_process(false)
	_manager.register_enemy(watcher)
	var elite := (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as Enemy
	elite.position = Vector3(-50, 0, -3)
	elite.is_boss = true
	add_child(elite)
	elite.set_physics_process(false)
	_manager.register_enemy(elite)
	elite.health.health = 40.0
	_effect.apply_latency(elite)
	(_effect.clocks[elite.get_instance_id()] as LatencyStatus).detonate()
	_check("latency elite kill freezes enemies and existing hostile bullet", is_zero_approx(deep.boon_time_scale) and is_zero_approx(bullet.boon_time_scale))
	var enemy_before := watcher.global_transform
	watcher.velocity = Vector3.FORWARD * 3.0
	watcher._physics_process(1.0)
	_check("production SlothEnemy is physically frozen", watcher.global_transform.is_equal_approx(enemy_before))
	var frozen := bullet.global_position
	bullet._physics_process(1.0)
	_check("projectile remains exactly suspended", bullet.global_position.is_equal_approx(frozen))
	_check("absolute freeze never stops global engine time", is_equal_approx(Engine.time_scale, 1.0))
	_manager._physics_process(1.99)
	_check("freeze remains before two-second boundary", is_zero_approx(bullet.boon_time_scale))
	_manager._physics_process(0.02)
	_check("player manager clock restores freeze at two seconds", deep.boon_time_scale > 0.0 and bullet.boon_time_scale > 0.0)
	_manager.freeze_world(2.0, &"sloth_eternal")
	traits._freeze_remaining = 2.0
	_manager.remove(SlothTraits.ETERNAL)
	traits.tick(0.0)
	_check("removing legendary restores freeze source", deep.boon_time_scale > 0.0 and bullet.boon_time_scale > 0.0)
	_manager.equip(_card(SlothTraits.ETERNAL))
	for index in 4:
		var chain_target := _target(Vector3(-65 - index * 2, 0, -3))
		chain_target.health.health = 5.0
		chain_target.health.died.connect(func(_source: Node): Events.enemy_killed.emit(chain_target))
		_manager.apply_damage(chain_target, 10.0)
		if index == 0:
			traits.tick(3.01)
		elif index == 2:
			_check("a kill older than three seconds is excluded", not is_zero_approx(bullet.boon_time_scale))
	_check("three kills within the sliding window trigger actual freeze", is_zero_approx(bullet.boon_time_scale))
	_manager.clear()
	_check("full cleanup restores all enemy and projectile time sources", is_equal_approx(deep.boon_time_scale, 1.0) and is_equal_approx(bullet.boon_time_scale, 1.0) and not sleeper.boon_stunned)
