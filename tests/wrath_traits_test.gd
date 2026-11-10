extends "res://tests/wrath_core_test.gd"
## Complements the core contact test with nine real card behaviors.

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
	print("WRATH TRAITS: %d checks, %d failed, completed=%s" % [checks, failed, finished])
	get_tree().quit(0 if failed == 0 else 1)

func _run() -> void:
	await _world()
	var pool := load("res://buffs/resources/wrath/pool.tres") as BoonPool
	_check("Wrath pool has 12 distinct ids", pool.cards.size() == 12 and _unique_ids(pool.cards) == 12)
	_check("high tier breaker is unavailable without a gun/blade", not manager.can_equip(_data("wrath_breaker")))
	manager.equip(_data("wrath_gun_cannon"))
	_check("owning a gun satisfies breaker OR prerequisite", manager.can_equip(_data("wrath_breaker")))
	_check("legendary requires two Wrath traits", not manager.can_equip(_data("wrath_cataclysm")))
	manager.equip(_data("wrath_reload"))
	manager.equip(_data("wrath_retaliation"))
	_check("two family traits unlock legendary", manager.can_equip(_data("wrath_cataclysm")))
	_reset(["wrath_desperation"])
	player.health.health = 30.0
	await _frames(1)
	_check("30 percent HP grants maximum 60 percent all damage", is_equal_approx(player.stats.get_value(Stats.DAMAGE), 1.6))
	player.health.health = 100.0
	await _frames(1)
	_check("healing removes low-health damage bonus", is_equal_approx(player.stats.get_value(Stats.DAMAGE), 1.0))
	_reset(["wrath_retaliation"])
	var source := _enemy(Vector3(1.5, 0, -1))
	await _frames(2)
	player.health.apply_damage(5.0, Hitbox.BodyPart.BODY, source)
	_check("real incoming hit grants 40 percent offense for three seconds", is_equal_approx(player.stats.get_value(Stats.DAMAGE), 1.4))
	_check("retaliation uses real physical enemy impulse", effect.has_spite(source) and source._impact_velocity.length() >= 23.0)
	await _frames(185)
	_check("retaliation boost expires", is_equal_approx(player.stats.get_value(Stats.DAMAGE), 1.0))
	_reset(["wrath_reload"])
	player.weapon.ammo = 0
	player.weapon.try_reload()
	_check("empty magazine is actually reassembling", player.weapon.is_reloading())
	player.health.apply_damage(2.0, Hitbox.BodyPart.BODY, source)
	_check("being hit instantly refills through normal weapon path", not player.weapon.is_reloading() and player.weapon.ammo == 8 and effect.traits.empowered_magazine)
	var multipliers: Array[float] = []
	var observer := func(event: StringName, ctx: Dictionary):
		if event == &"shoot_fired":
			multipliers.append(ctx.damage_multiplier)
	manager.event_dispatched.connect(observer)
	for index in 8:
		player.weapon._cooldown = 0.0
		player.weapon.try_fire()
	_check("all eight bullets in empowered magazine receive double damage", multipliers.size() == 8 and multipliers.all(func(value: float): return value == 2.0))
	_check("next empty reassembly clears magazine empowerment", player.weapon.is_reloading() and not effect.traits.empowered_magazine)
	player.weapon.complete_reload()
	player.weapon._cooldown = 0.0
	player.weapon.try_fire()
	_check("following magazine returns to ordinary damage", multipliers.size() == 9 and multipliers.back() == 1.0)
	manager.event_dispatched.disconnect(observer)
	source.queue_free()
	await _frames(2)
	_reset(["wrath_gun_cannon", "wrath_crusher"])
	var crushed := _enemy(Vector3(0, 0, -3))
	await _frames(2)
	effect.knock(crushed, Vector3.FORWARD, 3.0)
	await _frames(18)
	_check("crusher adds 80 percent to actual wall slam", not _slams.is_empty() and is_equal_approx(_slams.back().damage, 108.0))
	var after_slam := crushed.health.health
	await _frames(35)
	_check("wall scar deals actual repeated burn damage", crushed.health.health < after_slam)
	_check("burn patch has a real three-second lifetime", effect.traits._owned_nodes.any(func(node): return is_instance_valid(node) and node is WrathEmbers and node.remaining < 3.0))
	manager.remove("wrath_crusher")
	await _frames(2)
	_check("removing crusher cleans persistent ember sources", not effect.traits._owned_nodes.any(func(node): return is_instance_valid(node) and node is WrathEmbers and not node.is_queued_for_deletion()))
	var patch := WrathEmbers.create(manager, crushed.global_position + Vector3.UP, Vector3.UP, 2)
	patch.set_physics_process(false)
	var before_burn := crushed.health.health
	patch._physics_process(3.05)
	_check("burn timer resolves exactly six ticks even across a long frame", is_equal_approx(crushed.health.health, before_burn - 48.0))
	crushed.queue_free()
	await _frames(2)
	_reset(["wrath_gun_cannon", "wrath_shrapnel"])
	var spiked := _enemy(Vector3(0, 0, -3))
	await _frames(2)
	effect.knock(spiked, Vector3.FORWARD, 3.0)
	await _frames(12)
	_check("one physical wall contact launches five piercing spikes", effect.traits._owned_nodes.filter(func(node): return is_instance_valid(node) and node is WrathSpike).size() == 5)
	spiked.queue_free()
	await _frames(2)
	var first := _enemy(Vector3(10, 0, -5))
	var second := _enemy(Vector3(10, 0, -2))
	await _frames(3)
	var frozen_spike := WrathSpike.launch(manager, Vector3(10, 1.45, -8), Vector3.BACK, 2)
	frozen_spike.boon_time_scale = 0.0
	await _frames(2)
	_check("local projectile freeze preserves spike position and health", frozen_spike.global_position == Vector3(10, 1.45, -8) and first.health.health == 1000.0)
	frozen_spike.boon_time_scale = 1.0
	await _frames(15)
	_check("one real spike pierces two enemies exactly once each", first.health.health == 982.0 and second.health.health == 982.0)
	first.queue_free()
	second.queue_free()
	await _frames(2)
	_reset(["wrath_gun_cannon", "wrath_chain"])
	first = _enemy(Vector3(10, 0, -3))
	second = _enemy(Vector3(10, 0, 0))
	await _frames(3)
	effect.knock(first, Vector3.BACK, 3.0)
	await _frames(18)
	_check("actual enemy-to-enemy contact deals full slam to both", first.health.health == 940.0 and second.health.health == 940.0)
	_check("both bodies are stunned by chain collision", first.boon_stunned and second.boon_stunned)
	first.queue_free()
	second.queue_free()
	await _frames(2)
	_reset(["wrath_gun_cannon", "wrath_breaker"])
	var shielded := _enemy(Vector3(0, 0, -3))
	shielded.is_boss = true
	shielded.health.max_shield = 120.0
	shielded.health.grant_shield(120.0)
	await _frames(2)
	effect.knock(shielded, Vector3.FORWARD, 3.0)
	_check("breaker weakens actual elite knockback resistance", shielded._impact_velocity.length() > 20.0)
	await _frames(20)
	_check("wall slam destroys full real Health barrier", shielded.health.shield_points == 0.0)
	_check("shield break adds 250 percent true damage before ordinary slam", is_equal_approx(shielded.health.health, 790.0))
	shielded.queue_free()
	await _frames(2)
	_reset(["wrath_reload", "wrath_frenzy"])
	for index in 6:
		var victim := _enemy(Vector3(15 + index * 0.3, 0, -8))
		manager.apply_damage(victim, 2000.0, {"tag": &"test_kill", "proc_depth": 1})
		victim.queue_free()
	_check("successive credited kills cap movement and blade speed at 50 percent", effect.traits.frenzy_stacks == 5 and is_equal_approx(player.stats.get_value(Stats.MOVE_SPEED), 1.5) and is_equal_approx(player.stats.get_value(Stats.MELEE_SPEED), 1.5))
	player._shake_left = 0.0
	var hp_before := player.health.health
	player.health.apply_damage(1.0, Hitbox.BodyPart.BODY)
	_check("frenzy armor blocks actual hurt flinch while HP still falls", player._shake_left == 0.0 and is_equal_approx(player.health.health, hp_before - 1.0))
	await _frames(245)
	_check("four-second kill chain expires and restores stats", player.stats.get_value(Stats.MOVE_SPEED) == 1.0 and player.stats.get_value(Stats.ARMOR) == 0.0)
	_reset(["wrath_reload", "wrath_frenzy", "wrath_cataclysm"])
	first = _enemy(Vector3(10, 0, 6))
	second = _enemy(Vector3(16, 0, 6))
	await _frames(2)
	var previous_slams := _slams.size()
	effect.knock(first, Vector3.FORWARD, 3.0)
	effect.knock(second, Vector3.FORWARD, 3.0)
	await _frames(15)
	_check("legendary creates real moving-air ruptures without a wall", _slams.size() == previous_slams + 2 and _slams.back().rupture and not _slams.back().wall_impact)
	_check("both physically knocked enemies receive rupture damage", first.health.health == 940.0 and second.health.health == 940.0)
	_check("legendary raises visible ground crystals", effect.traits._owned_nodes.filter(func(node): return is_instance_valid(node) and node is MeshInstance3D).size() >= 2)
	var doomed := _enemy(Vector3(22, 0, 6))
	await _frames(2)
	effect.knock(doomed, Vector3.FORWARD, 3.0)
	previous_slams = _slams.size()
	manager.apply_damage(doomed, 2000.0, {"tag": &"test_kill", "proc_depth": 1})
	await _frames(15)
	_check("dead enemies cannot trigger a later legendary rupture", _slams.size() == previous_slams and (not is_instance_valid(doomed) or not effect.has_spite(doomed)))
	manager.clear()
	await _frames(2)
	_check("cleanup restores masks and temporary modifiers", (first.collision_mask & CollisionLayers.ENEMIES) == 0 and player.stats.get_value(Stats.MOVE_SPEED) == 1.0)
	finished = true

func _reset(ids: Array) -> void:
	manager.clear()
	player.health.health = 100.0
	for id in ids:
		manager.equip(_data(id))
	effect = manager.effect_for(load("res://buffs/effects/wrath_effect.gd")) as WrathBoons

func _data(id: String) -> BoonData:
	return load("res://buffs/resources/wrath/%s.tres" % id) as BoonData

func _unique_ids(cards: Array[BoonData]) -> int:
	var ids := {}
	for card in cards:
		ids[card.id] = true
	return ids.size()
