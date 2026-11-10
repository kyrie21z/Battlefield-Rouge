extends "res://tests/sorrow_boon_core_test.gd"
var _traits_finished := false

func _ready() -> void:
	await get_tree().process_frame
	await super._run()
	await _run_traits()
	_check("all scenarios reach final boundary", _core_finished and _traits_finished)
	print("SORROW TRAITS: %s (%d failed)" % ["ALL PASSED" if _failed == 0 else "FAIL", _failed])
	await _finish_fixture()
	get_tree().quit(0 if _failed == 0 else 1)


func _card(id: String) -> BoonData:
	return load("res://buffs/resources/sorrow/%s.tres" % id) as BoonData


func _run_traits() -> void:
	_check("flood requires gun or blade", not _manager.can_equip(_card(SorrowTraits.FLOOD)))
	_check("mercy requires dash or passive", not _manager.can_equip(_card(SorrowTraits.MERCY)))
	_check("abyss requires two sorrow traits", not _manager.can_equip(_card(SorrowTraits.ABYSS)))
	_manager.equip(_card(SorrowEffect.GUN))
	_effect = _manager.effect_for(load("res://buffs/effects/sorrow_effect.gd")) as SorrowEffect
	var traits := _effect._traits as SorrowTraits
	_manager.equip(_card(SorrowTraits.BUFFER))
	_check("one passive satisfies mercy OR requirement", _manager.can_equip(_card(SorrowTraits.MERCY)))
	_check("one passive still excludes legendary", not _manager.can_equip(_card(SorrowTraits.ABYSS)))
	_manager.equip(_card(SorrowTraits.ECHO))
	_check("two passives satisfy legendary", _manager.can_equip(_card(SorrowTraits.ABYSS)))
	_player.global_position = Vector3(-50, 0, 0)
	var attacker := _target(Vector3(-50, 0, -3))
	_player.health.health = 100.0
	_player.health.dash_invulnerable = false
	var before := _player.health.health
	_player.health.apply_damage(40.0, Hitbox.BodyPart.BODY, attacker)
	_check("real burst is split into 20 HP now and 20 debt", is_equal_approx(before - _player.health.health, 20.0) and is_equal_approx(traits.pending_damage(), 20.0))
	var reflected := [0.0]
	_manager.event_dispatched.connect(func(event: StringName, ctx: Dictionary):
		if event == &"sorrow_deferred_tick": reflected[0] += float(ctx.damage))
	_player.health.invulnerable = true
	traits.tick(1.0)
	_check("immunity neither pays debt nor emits false reflected damage", is_equal_approx(traits.pending_damage(), 20.0) and is_zero_approx(reflected[0]))
	_player.health.invulnerable = false
	# A modifier acquired after debt creation must not discount debt again.
	_manager.set_modifier(&"test_debt_reduction", {Stats.DAMAGE_TAKEN: {"mul": 0.5}})
	before = _player.health.health
	traits.tick(1.5)
	_check("half-duration pays exactly ten fixed debt without double reduction", is_equal_approx(before - _player.health.health, 10.0) and is_equal_approx(traits.pending_damage(), 10.0) and is_equal_approx(reflected[0], 10.0))
	_manager.remove_modifier(&"test_debt_reduction")
	_effect.spawn_tear(_player.global_position)
	_effect.tick(0.21)
	_check("real pickup cancels all remaining debt", is_zero_approx(traits.pending_damage()))
	_check("echo pickup applies erosion to nearby enemies", _effect.erosion_layers(attacker) == 1)
	_manager.shield_amount = 0.0
	_manager.remove(SorrowTraits.BUFFER)
	_manager.equip(_card(SorrowTraits.TIDE))
	_effect.spawn_tear(Vector3(-50, 0, -6))
	var crystal: TearCrystal = _effect.tears.back()
	var distance := crystal.global_position.distance_to(_player.global_position)
	traits.tick(0.5)
	_check("gravity moves actual crystal toward player", crystal.global_position.distance_to(_player.global_position) < distance)
	_check("pickup radius is enlarged by 150 percent", is_equal_approx(crystal.pickup_radius, 0.85 * 2.5))
	_manager.remove(SorrowTraits.TIDE)
	_manager.equip(_card(SorrowTraits.PRESSURE))
	var caster := (load("res://actors/enemy/sloth/sloth_enemy.tscn") as PackedScene).instantiate() as SlothEnemy
	caster.position = Vector3(-70, 0, -3)
	add_child(caster)
	caster.set_physics_process(false)
	_manager.register_enemy(caster)
	caster.health.max_health = 1000.0
	caster.health.health = 1000.0
	_effect.add_erosion(caster, 5)
	var attack := SlothAttack.new()
	attack.caster = caster
	attack.target = _player
	attack.kind = 0
	add_child(attack)
	attack.set_physics_process(false)
	_check("full erosion extends real SlothAttack warning to 2.6 seconds", is_equal_approx(attack.warning_time(), 2.6))
	attack.cancel()
	_manager.equip(_card(SorrowEffect.BLADE))
	_effect.spawn_tear(Vector3(-70, 0, -1.0))
	var fired_tear: TearCrystal = _effect.tears.back()
	_effect._strike_tear(fired_tear, {"kind": &"blade", "direction": Vector3.FORWARD, "source": _player})
	var tear_shots: Array[Node3D] = _manager.projectiles().filter(func(projectile): return projectile.source == _player)
	for projectile: Node3D in tear_shots:
		projectile.set_physics_process(false)
	for frame in 3:
		await get_tree().physics_frame
	before = caster.health.health
	for projectile: Node3D in tear_shots:
		if is_instance_valid(projectile) and not projectile.is_queued_for_deletion():
			projectile._physics_process(0.15)
	_check("launched ground crystals damage a production SlothEnemy", caster.health.health < before)
	var shot := Projectile.spawn(self, Vector3(-70, 1, -2), Vector3.BACK, caster, 5.0, 10.0, [])
	shot.set_physics_process(false)
	var from := shot.global_position
	shot._physics_process(0.1)
	_check("full-stack caster emits projectile travelling 60 percent distance", is_equal_approx(from.distance_to(shot.global_position), 0.6))
	_manager.equip(_card(SorrowTraits.SUFFOCATION))
	traits.status_changed(caster)
	caster.health.max_shield = 100.0
	_check("erosion blocks actual shield regeneration", is_zero_approx(caster.health.regenerate_shield(10.0)))
	_effect._remove_state(caster.get_instance_id())
	_check("status removal restores real shield regeneration", is_equal_approx(caster.health.regenerate_shield(10.0), 10.0))
	caster.health.break_shield()
	_effect.add_erosion(caster, 1)
	_manager.set_modifier(&"test_critical", {Stats.CRIT_CHANCE: {"add": 1.0}})
	before = caster.health.health
	_manager.apply_damage(caster, 10.0, {"kind": &"gun", "proc_depth": 0})
	_check("critical damage gains forty percent after shared crit roll", is_equal_approx(before - caster.health.health, 30.8))
	_manager.remove_modifier(&"test_critical")
	_manager.equip(_card(SorrowTraits.FLOOD))
	var saturated := _target(Vector3(-90, 0, -3))
	var spread := _target(Vector3(-88, 0, -3))
	_effect.add_erosion(saturated, 5)
	_manager.apply_damage(saturated, 10.0, {"kind": &"gun", "proc_depth": 0})
	_check("natural hit on saturated victim spreads erosion to nearby enemy", _effect.erosion_layers(spread) == 1)
	_manager.equip(_card(SorrowTraits.SHARDS))
	var splash := _target(Vector3(-110, 0, -3))
	_effect.spawn_tear(Vector3(-110, 0, -1))
	for index in 3:
		await get_tree().physics_frame
	before = splash.health.health
	_player.weapon._shoot_ray(Vector3(-110, 0.28, 1), Vector3.FORWARD)
	_check("real gun hit shatters tear into AoE damage", is_equal_approx(before - splash.health.health, 45.0))
	_check("tear shatter applies two erosion layers", _effect.erosion_layers(splash) == 2)
	_manager.equip(_card(SorrowTraits.MERCY))
	# Place the new tears well away from pickup and AoE. Existing tears may also
	# contribute; ten new ones guarantee the authored maximum of nine counted.
	_effect.spawn_tear(Vector3(-150, 0, -2), 10)
	traits.tick(0.0)
	_check("ten ground tears cap damage reduction at thirty-six percent", is_equal_approx(_player.stats.get_value(Stats.DAMAGE_TAKEN), 0.64))
	_manager.shield_amount = 0.0
	before = _player.health.health
	_player.health.apply_damage(10.0, Hitbox.BodyPart.BODY, attacker)
	_check("mercy modifier reduces real incoming HP damage", is_equal_approx(before - _player.health.health, 6.4))
	traits.tick(0.5)
	_check("taking damage does not interrupt real shield regeneration", is_equal_approx(_manager.shield_amount, 1.0))
	_manager.equip(_card(SorrowTraits.ABYSS))
	traits.tick(0.0)
	_check("legendary transforms real ground tears into flying blades", not traits.blades.is_empty() and _effect.tears.all(func(tear): return not is_instance_valid(tear) or tear.consumed))
	var doomed := _target(Vector3(-170, 0, -3))
	doomed.health.health = 1.0
	_manager.apply_damage(doomed, 10.0)
	_check("real enemy kill creates a fountain", traits.fountains.size() == 1)
	var target := _target(Vector3(-170, 0, -5))
	var farther := _target(Vector3(-170, 0, -7))
	traits._spawn_blade(Vector3(-170, 1, -3))
	var blade: SorrowWaterBlade = traits.blades.back()
	blade.set_physics_process(false)
	before = target.health.health
	blade._physics_process(0.2)
	_check("homing blade deals real damage while piercing two enemies", target.health.health < before and farther.health.health < 1000.0)
	var fountain_count := traits.blades.size()
	traits.tick(0.61)
	_check("fountain periodically launches additional real blades", traits.blades.size() > fountain_count)
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = Vector3(-170, 1, -9)
	var wall_collision := CollisionShape3D.new()
	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(3, 3, 0.2)
	wall_collision.shape = wall_shape
	wall.add_child(wall_collision)
	add_child(wall)
	var hidden := _target(Vector3(-170, 0, -11))
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CollisionLayers.WORLD
	floor_body.position = Vector3(-200, -0.1, 0)
	var floor_collision := CollisionShape3D.new()
	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(6, 0.2, 6)
	floor_collision.shape = floor_shape
	floor_body.add_child(floor_collision)
	add_child(floor_body)
	for frame in 3:
		await get_tree().physics_frame
	traits._spawn_blade(Vector3(-170, 1, -7))
	var blocked_blade: SorrowWaterBlade = traits.blades.back()
	blocked_blade.set_physics_process(false)
	# Already-visited enemies cannot redirect this blade away from the wall.
	for enemy: Node3D in _manager.enemies():
		if enemy != hidden:
			blocked_blade._hits[_manager.health_of(enemy).get_instance_id()] = true
	blocked_blade._physics_process(0.3)
	_check("piercing water blade stops at WORLD cover", hidden.health.health == 1000.0 and blocked_blade.is_queued_for_deletion())
	_effect.spawn_tear(Vector3(-200, 3, 0))
	var grounded: TearCrystal = _effect.tears.back()
	_check("airborne drop projects crystal onto real WORLD floor", is_equal_approx(grounded.global_position.y, 0.28))
	_manager.clear()
	_check("cleanup clears debt, fountains, blades and shield blockers", traits.debt.is_empty() and traits.fountains.is_empty() and traits.blades.is_empty() and not caster.health.shield_regeneration_blocked)
	_traits_finished = true
