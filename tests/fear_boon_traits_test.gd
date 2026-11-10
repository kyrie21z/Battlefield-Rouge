extends Node3D

class Actor extends CharacterBody3D:
	var team := 1
	var target: CharacterBody3D
	var boon_movement_scale := 1.0
	var boon_time_scale := 1.0
	var boon_stunned := false

var _failed := 0
var _finished := false
var _manager: BoonManager
var _source: Actor
var _fear: FearEffect
var _runtime: FearTraitsRuntime


func _ready() -> void:
	await _run()
	var ok := _failed == 0 and _finished
	print("%s (%d failed, finished=%s)" % ["ALL PASSED" if ok else "FAIL", _failed, _finished])
	_manager.clear()
	for child in get_children():
		child.queue_free()
	await get_tree().process_frame
	OS.delay_msec(100)
	await get_tree().process_frame
	get_tree().quit(0 if ok else 1)


func _run() -> void:
	_source = _actor(Vector3.ZERO, 0)
	var stats := Stats.new()
	_source.add_child(stats)
	_manager = BoonManager.new()
	_manager.player = _source
	_manager.stats = stats
	_manager.health = _source.get_node("Health")
	_source.add_child(_manager)
	_manager.health.before_damage.connect(_manager._before_damage)
	_manager.health.after_damage.connect(_manager._after_damage)
	_manager.health.died.connect(_manager._on_player_died)
	_manager.health.boon_absorber = _manager._absorb
	_check("advanced execution requires an equipped Fear gun or blade", not _manager.can_equip(_card("final_execution")))
	_check("legendary requires two Fear traits", not _manager.can_equip(_card("panoptic_dread")))
	_manager.equip(_card("gaze_pierce"))
	_check("Fear gun unlocks execution", _manager.can_equip(_card("final_execution")))
	_manager.equip(_card("distant_terror"))
	_manager.equip(_card("exposed_terror"))
	_check("two Fear traits unlock legendary", _manager.can_equip(_card("panoptic_dread")))
	_fear = _manager.effect_for(preload("res://buffs/effects/fear_effect.gd")) as FearEffect
	_runtime = _fear._traits
	_check("distance trait changes consumed projectile-speed Stats", is_equal_approx(stats.get_value(Stats.PROJECTILE_SPEED), 1.5))
	var speed_probe := Projectile.spawn(self, Vector3(0, 5, 0), Vector3.FORWARD, _source, 1.0, 30.0, [])
	_manager.register_projectile(speed_probe)
	_manager.register_projectile(speed_probe)
	_check("actual friendly projectile consumes speed modifier exactly once", is_equal_approx(speed_probe.speed, 45.0))
	speed_probe.queue_free()
	var values: Array[float] = []
	for distance in [12.0, 24.0, 36.0, 60.0]:
		var enemy := _enemy(Vector3(0, 0, distance))
		_fear.apply_panic(enemy)
		values.append(_flaw_hit(enemy, 10.0))
	_check("distance crit grows linearly from 12 to 36m then caps", is_equal_approx(values[0], 26.0) and is_equal_approx(values[1], 35.75) and is_equal_approx(values[2], 45.5) and is_equal_approx(values[3], 45.5))
	_manager.set_modifier(&"critical_probe", {Stats.CRIT_CHANCE: {"add": 1.0}})
	var random_crit_target := _enemy(Vector3(24, 0, 0))
	var random_crit := _manager.apply_damage(random_crit_target, 10.0, {"kind": &"gun", "proc_depth": 0})
	_check("distance scaling also applies to a stat-rolled ordinary critical", is_equal_approx(random_crit, 27.5))
	_manager.remove_modifier(&"critical_probe")
	var head_target := _enemy(Vector3(-24, 0, 0))
	var distant_head := _manager.apply_damage(head_target, 10.0, {"kind": &"gun", "proc_depth": 0, "body_part": Hitbox.BodyPart.HEAD})
	_check("distance trait also scales a native headshot without double-applying its part multiplier", is_equal_approx(distant_head, 34.375))
	_manager.remove("fear_distant_terror")
	_check("removing distance trait restores projectile speed", is_equal_approx(stats.get_value(Stats.PROJECTILE_SPEED), 1.0))
	var dot_target := _enemy(Vector3(0, 0, -8))
	_fear.apply_panic(dot_target)
	var dot := _manager.apply_damage(dot_target, 10.0, {"kind": &"proc", "proc_depth": 1,
		"tag": &"test_dot", "fear_flaw": 0, "fear_critical": true})
	_check("a copied damage-over-time context cannot backstab or inherit a parent's broken facet", is_equal_approx(dot, 10.0) and _fear.status_for(dot_target).facet_count() == 1)
	var enemy := _enemy(Vector3(0, 0, 5))
	var status := _fear.apply_panic(enemy)
	_runtime.tick(0.0)
	_check("exposed area is 150 percent rather than a 150-percent width", is_equal_approx(status.facets[0].scale.x * status.facets[0].scale.y, 1.5))
	var edge := status.facet_position(0) + Vector3(0.25, 0, -0.02)
	_check("enlarged physical diamond accepts the newly exposed edge", status.contact_index(edge, Vector3.BACK) == 0)
	var splash := _manager.apply_damage(enemy, 10.0, {"kind": &"proc", "proc_depth": 1, "splash": true,
		"position": status.facet_position(0) + Vector3(.34, 0, 0), "direction": Vector3.BACK})
	_check("a splash grazing the exposed diamond edge gets the actual critical damage", is_equal_approx(splash, 20.0))
	status.apply(4.0)
	_fear.set_flaw_area_multiplier(enemy, &"dual_test", 3.0)
	_check("independent area sources compose without overwriting exposure", is_equal_approx(status.area_multiplier, 4.5))
	_fear.set_flaw_area_multiplier(enemy, &"dual_test", 1.0)
	_manager.remove("fear_exposed_terror")
	_runtime.tick(0.0)
	_check("removing all area modifiers restores original contact bounds", is_equal_approx(status.area_multiplier, 1.0) and status.contact_index(edge, Vector3.BACK) == -1)
	_manager.equip(_card("final_execution"))
	var health := enemy.get_node("Health") as Health
	health.health = 300.0
	var executed := _flaw_hit(enemy, 20.0)
	_check("below-35-percent flaw gets exactly fivefold without unsupported instant kill", is_equal_approx(executed, 100.0) and is_equal_approx(health.health, 200.0))
	health.health = 40.0
	var lethal_dealt := _flaw_hit(enemy, 20.0)
	_check("fivefold lethal request stays 100 while actual loss caps at 40 and clears physical facets",
		is_equal_approx(lethal_dealt, 40.0)
		and is_equal_approx(float(health.last_damage_context.damage), 100.0)
		and is_equal_approx(float(health.last_damage_context.critical_multiplier), 5.0)
		and health.is_dead() and status.facet_count() == 0)
	_manager.remove("fear_final_execution")
	await _test_spread_blind()
	await _test_misfire()
	await _test_survival()
	await _test_legendary()
	_finished = true


func _test_spread_blind() -> void:
	_manager.equip(_card("fracture_spread"))
	_manager.equip(_card("abyssal_blindness"))
	var center := _enemy(Vector3(30, 0, 0))
	var peers: Array[Actor] = [_enemy(Vector3(32, 0, 0)), _enemy(Vector3(34, 0, 0)), _enemy(Vector3(36, 0, 0))]
	_fear.apply_panic(center)
	_flaw_hit(center, 5.0)
	_check("fracture spreads to exactly two nearest visible enemies", _fear.has_panic(peers[0]) and _fear.has_panic(peers[1]) and not _fear.has_panic(peers[2]))
	_check("fracture blinds all enemies within eight metres", peers.all(func(actor: Actor) -> bool: return actor.boon_stunned))
	get_tree().paused = true
	_manager._physics_process(3.0)
	_check("paused blindness timer cannot expire", peers[0].boon_stunned)
	get_tree().paused = false
	_manager._physics_process(2.01)
	_check("blindness expires after two simulation seconds", not peers[0].boon_stunned)
	var fourth := _enemy(Vector3(31, 0, 2))
	_manager.dispatch(&"fear_flaw_broken", {"target": center, "position": center.global_position + Vector3.UP, "proc_depth": 2, "tag": &"fear_legendary"})
	_check("proc fractures do not recursively spread new flaws", not _fear.has_panic(fourth))
	_manager.remove("fear_fracture_spread")
	_manager.remove("fear_abyssal_blindness")


func _test_misfire() -> void:
	_manager.equip(_card("paranoia"))
	var enemy := _enemy(Vector3(60, 0, 0))
	var peer := _enemy(Vector3(60, 0, -4))
	_fear.apply_panic(enemy)
	var before := (peer.get_node("Health") as Health).health
	_manager.rng.seed = _seed_for(true)
	var projectile := Projectile.spawn(self, Vector3(60, 1.1, -1), Vector3.BACK, enemy, 17.0, 30.0, [])
	_manager.register_projectile(projectile)
	_check("seeded successful misfire enables friendly damage and tags player immunity", projectile.allow_friendly_fire and projectile.boon_context.get("tag") == &"fear_misfire")
	for i in 15:
		await get_tree().physics_frame
	_check("misfired production projectile actually damages a fellow enemy", (peer.get_node("Health") as Health).health < before)
	var player_hp := _manager.health.health
	_manager.health.apply_damage(20.0, Hitbox.BodyPart.BODY, enemy, {"tag": &"fear_misfire"})
	_check("misfire cannot damage the player", is_equal_approx(_manager.health.health, player_hp))
	_manager.rng.seed = _seed_for(false)
	projectile = Projectile.spawn(self, Vector3(60, 1.1, 1), Vector3.BACK, enemy, 17.0, 30.0, [])
	_manager.register_projectile(projectile)
	_check("failed deterministic probability leaves ordinary hostile shot intact", not projectile.allow_friendly_fire)
	projectile.queue_free()
	_manager.remove("fear_paranoia")


func _test_survival() -> void:
	_manager.equip(_card("every_shadow"))
	_manager.health.health = 499.0
	_runtime.tick(0.0)
	_check("below half health grants speed, crit and recharge together", is_equal_approx(_manager.stats.get_value(Stats.MOVE_SPEED), 1.25) and is_equal_approx(_manager.stats.get_value(Stats.CRIT_CHANCE), 0.2) and is_equal_approx(_manager.stats.get_value(Stats.DASH_RECHARGE), 1.4))
	_manager.health.health = 500.0
	_runtime.tick(0.0)
	_check("exactly half health removes conditional bonuses", is_equal_approx(_manager.stats.get_value(Stats.MOVE_SPEED), 1.0) and is_equal_approx(_manager.stats.get_value(Stats.CRIT_CHANCE), 0.0))
	_manager.equip(_card("sixth_sense"))
	var enemy := _enemy(Vector3(0, 0, -10))
	_manager.health.health = 100.0
	_manager.rng.seed = _seed_for(true)
	var before := _source.global_position
	_manager.health.apply_damage(150.0, Hitbox.BodyPart.BODY, enemy)
	_check("seeded lethal evade cancels damage and moves exactly three metres back", is_equal_approx(_manager.health.health, 100.0) and _source.global_position.is_equal_approx(before + Vector3.BACK * 3.0))
	_source.global_position = Vector3.ZERO
	var wall := StaticBody3D.new()
	wall.collision_layer = CollisionLayers.WORLD
	wall.position = Vector3(0, 1, 1.6)
	var wall_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 3, .2)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	add_child(wall)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_manager.rng.seed = _seed_for(true)
	_manager.health.apply_damage(150.0, Hitbox.BodyPart.BODY, enemy)
	_check("lethal evade sweeps the real player collision and stops before a wall", _source.position.z > 0.5 and _source.position.z < 1.3 and is_equal_approx(_manager.health.health, 100.0))
	wall.queue_free()
	_source.global_position = Vector3.ZERO
	_manager.grant_shield(200.0)
	var random_before := _manager.rng.state
	_manager.health.apply_damage(150.0, Hitbox.BodyPart.BODY, enemy)
	_check("shield-survivable damage neither rolls lethal evade nor moves the player", _source.position.is_zero_approx() and is_equal_approx(_manager.health.health, 100.0) and _manager.rng.state == random_before)
	_manager.shield_amount = 0.0
	var head := Node3D.new()
	head.name = "Head"
	_source.add_child(head)
	var camera := Camera3D.new()
	camera.name = "Camera3D"
	head.add_child(camera)
	var rear := _enemy(_source.global_position + Vector3(0, 0, 10))
	var projectile := Projectile.spawn(self, rear.global_position + Vector3.UP, Vector3.FORWARD, rear, 5.0, 10.0, [])
	_manager.register_projectile(projectile)
	_check("offscreen shot produces a visible edge cue", _runtime._warning != null and _runtime._warning.edges.cues.size() == 1)
	projectile.queue_free()
	_manager.remove("fear_every_shadow")
	_manager.remove("fear_sixth_sense")
	_runtime.tick(0.0)
	_source.global_position = Vector3.ZERO
	_manager.health.health = 1000.0


func _test_legendary() -> void:
	_manager.equip(_card("panoptic_dread"))
	var first := _enemy(Vector3(90, 0, 0))
	var second := _enemy(Vector3(93, 0, 0))
	var status := _fear.status_for(first)
	_check("newly registered enemy immediately owns permanent front/back flaws", status != null and status.permanent and status.facet_count() == 2)
	status._process(10000.0)
	_check("permanent panic has no lifetime expiration", status.is_active() and status.facet_count() == 2)
	var before := (second.get_node("Health") as Health).health
	var shot_contexts: Array[Dictionary] = []
	_manager.event_dispatched.connect(func(event: StringName, context: Dictionary):
		if event == &"hit_after" and context.get("tag") == &"fear_legendary":
			shot_contexts.append(context.duplicate())
	)
	_flaw_hit(first, 5.0)
	for i in 40:
		await get_tree().physics_frame
	_check("legendary broken facet launches a real homing crystal into another enemy", (second.get_node("Health") as Health).health < before and not shot_contexts.is_empty())
	_check("legendary crystal is guaranteed critical and cannot recursively launch itself", shot_contexts.size() == 1 and shot_contexts[0].critical and shot_contexts[0].proc_depth == 1)
	_manager.remove("fear_panoptic_dread")
	_runtime.tick(0.0)
	_check("removing legendary revokes permanent panic while other Fear cards remain", not status.permanent and not _fear.status_for(second).permanent)
	_manager.equip(_card("panoptic_dread"))
	var final_target := _enemy(Vector3(96, 0, 0))
	status = _fear.status_for(final_target)
	_manager.health.apply_damage(2000.0, Hitbox.BodyPart.BODY, first)
	_check("actual player death releases permanent flaws and owned temporary effects", _manager.health.is_dead() and not status.is_active() and _fear._decoys.is_empty() and _fear._homing.is_empty())


func _seed_for(success: bool) -> int:
	var probe := RandomNumberGenerator.new()
	for value in 100:
		probe.seed = value
		if (probe.randf() < 0.35) == success:
			return value
	return -1


func _flaw_hit(enemy: Actor, damage: float) -> float:
	var status := _fear.status_for(enemy)
	var index := 0 if is_instance_valid(status.facets[0]) else 1
	var point := status.facet_position(index)
	var direction := Vector3.BACK if index == 0 else Vector3.FORWARD
	return _manager.apply_damage(enemy, damage, {"kind": &"gun", "proc_depth": 0, "position": point, "direction": direction, "hitbox": status.facets[index], "source": _source})


func _card(id: String) -> BoonData:
	return load("res://buffs/resources/fear/%s.tres" % id)


func _enemy(point: Vector3) -> Actor:
	var enemy := _actor(point)
	_manager.register_enemy(enemy)
	return enemy


func _actor(point: Vector3, team := 1) -> Actor:
	var actor := Actor.new()
	actor.team = team
	actor.position = point
	var health := Health.new()
	health.name = "Health"
	health.max_health = 1000.0
	health.team = team
	actor.add_child(health)
	var hitbox := Hitbox.new()
	hitbox.name = "Body"
	hitbox.position.y = 1.1
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.5, 1.2, 0.5)
	collider.shape = shape
	hitbox.add_child(collider)
	actor.add_child(hitbox)
	if team == 0:
		actor.collision_layer = CollisionLayers.ACTORS
		actor.collision_mask = CollisionLayers.WORLD
		var movement := CollisionShape3D.new()
		var capsule := CapsuleShape3D.new()
		capsule.height = 1.8
		capsule.radius = 0.3
		movement.shape = capsule
		movement.position.y = 0.9
		actor.add_child(movement)
	add_child(actor)
	return actor


func _check(label: String, condition: bool) -> void:
	print("  [%s] %s" % ["ok" if condition else "FAIL", label])
	if not condition:
		_failed += 1
