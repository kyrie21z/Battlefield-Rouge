class_name FearTraitsRuntime
extends RefCounted
## Nine Fear traits share the owner's status and never instantiate a second
## core handler. All gameplay probability uses the manager's seeded RNG.

const DISTANCE := "fear_distant_terror"
const MISFIRE := "fear_paranoia"
const SENSE := "fear_sixth_sense"
const SPREAD := "fear_fracture_spread"
const DESPERATE := "fear_every_shadow"
const EXPOSE := "fear_exposed_terror"
const EXECUTE := "fear_final_execution"
const BLIND := "fear_abyssal_blindness"
const LEGENDARY := "fear_panoptic_dread"

var manager: BoonManager
var fear: FearEffect
var _warning: FearEdgeWarning
var _blind_targets: Dictionary = {}
var _desperate_active := false
var _permanent: Dictionary = {}


func setup(owner_effect: FearEffect) -> void:
	fear = owner_effect
	manager = fear.manager


func before_event(event: StringName, context: Dictionary) -> void:
	if event != &"hit_before":
		return
	var target := context.get("target") as Node3D
	if manager.has(EXPOSE) and is_instance_valid(target):
		fear.set_flaw_area_multiplier(target, &"fear_exposed", parameter(EXPOSE, "area_multiplier", 1.5))
		if context.get("tag", &"") in [&"ricochet", &"splash"] or bool(context.get("splash", false)) or bool(context.get("ricochet", false)):
			context["fear_graze"] = parameter(EXPOSE, "graze_radius", 0.12)


func on_event(event: StringName, context: Dictionary) -> void:
	match event:
		&"hit_before":
			_critical_traits(context)
		&"fear_flaw_broken":
			_fracture_traits(context)
		&"fear_decoy_burst":
			if manager.has(BLIND):
				_blind(context.position)
		&"enemy_shot":
			_enemy_shot(context)
		&"damage_before":
			_incoming(context)
		&"enemy_registered":
			if manager.has(LEGENDARY):
				var status := fear.apply_panic(context.enemy, 0.0, true, 2)
				if status != null:
					_permanent[context.enemy.get_instance_id()] = weakref(status)
		&"damage_after":
			_update_desperate()


func tick(_delta: float) -> void:
	_update_desperate()
	if not manager.has(LEGENDARY):
		for reference in _permanent.values():
			var status := reference.get_ref() as PanicFlawStatus
			if status != null:
				status.permanent = false
				if status.remaining <= 0.0:
					status.clear()
		_permanent.clear()
	# A replaced/excluded trait must release its area immediately even when
	# another Fear card keeps the shared core handler alive.
	for enemy in manager.enemies():
		fear.set_flaw_area_multiplier(enemy, &"fear_exposed", parameter(EXPOSE, "area_multiplier", 1.5) if manager.has(EXPOSE) else 1.0)


func _critical_traits(context: Dictionary) -> void:
	var target := context.get("target") as Node3D
	if not manager.is_enemy(target):
		return
	var health := manager.health_of(target)
	var distance_scale := 1.0
	if manager.has(DISTANCE):
		var distance := manager.player.global_position.distance_to(target.global_position)
		var start := parameter(DISTANCE, "start_distance", 12.0)
		var cap := parameter(DISTANCE, "max_distance", 36.0)
		distance_scale += clampf((distance - start) / maxf(cap - start, 0.01), 0.0, 1.0) * parameter(DISTANCE, "max_bonus", 0.75)
		context["critical_damage_scale"] = distance_scale
		if not bool(context.get("critical", false)) and context.get("body_part") == Hitbox.BodyPart.HEAD:
			context.damage *= health.headshot_multiplier
			context.critical = true
			context.critical_multiplier = health.headshot_multiplier
			context.body_part = Hitbox.BodyPart.BODY
			context["fear_critical"] = true
	if bool(context.get("fear_guaranteed_critical", false)) and not bool(context.get("critical", false)):
		context.damage *= 2.0
		context.critical = true
		context.critical_multiplier = 2.0
		context.body_part = Hitbox.BodyPart.BODY
		context["fear_critical"] = true
	if not bool(context.get("critical", false)):
		return
	var multiplier := float(context.get("critical_multiplier", 2.0))
	var base := float(context.damage) / maxf(multiplier, 1.0)
	if manager.has(EXECUTE) and fear.has_panic(target) and int(context.get("fear_flaw", -1)) >= 0 \
			and health.health / health.max_health < parameter(EXECUTE, "health_threshold", 0.35):
		context.damage = base * parameter(EXECUTE, "critical_multiplier", 5.0)
		context.critical_multiplier = parameter(EXECUTE, "critical_multiplier", 5.0)
		context["fear_execution"] = true
	elif manager.has(DISTANCE):
		context.damage *= distance_scale
		context.critical_multiplier *= distance_scale


func _fracture_traits(context: Dictionary) -> void:
	var point: Vector3 = context.position
	var depth := int(context.get("proc_depth", 0))
	if depth > 2:
		return
	if manager.has(SPREAD) and depth == 0:
		var targets := manager.targets_in_radius(point, parameter(SPREAD, "radius", 8.0))
		targets.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return point.distance_squared_to(a.global_position) < point.distance_squared_to(b.global_position))
		var count := 0
		for target in targets:
			if target == context.get("target"):
				continue
			fear.apply_panic(target, parameter(SPREAD, "panic_duration", 4.0))
			manager.feedback(target.global_position + Vector3.UP, PanicFlawStatus.COLOR, 0.4)
			count += 1
			if count >= 2:
				break
	if manager.has(BLIND):
		_blind(point)
	if manager.has(LEGENDARY) and context.get("tag", &"") != &"fear_legendary" and depth < 2:
		_spawn_crystal(point, context.get("target"), depth + 1)


func _blind(point: Vector3) -> void:
	var radius := parameter(BLIND, "radius", 8.0)
	for enemy in manager.targets_in_radius(point, radius):
		manager.set_status(enemy, &"fear_blind", parameter(BLIND, "duration", 2.0), 1.0, 1.0, true)
		_blind_targets[enemy.get_instance_id()] = weakref(enemy)
	manager.feedback(point, PanicFlawStatus.COLOR, radius)


func _enemy_shot(context: Dictionary) -> void:
	var enemy := context.get("enemy") as Node3D
	var projectile := context.get("projectile") as Projectile
	if enemy == null or projectile == null:
		return
	if manager.has(SENSE):
		var camera: Camera3D = manager.weapon.camera if manager.weapon != null else manager.player.get_node_or_null("Head/Camera3D") as Camera3D
		if camera != null and not camera.is_position_in_frustum(enemy.global_position + Vector3.UP):
			if not is_instance_valid(_warning):
				_warning = FearEdgeWarning.new()
				manager.player.add_child(_warning)
			_warning.warn(camera, enemy.global_position)
	if not manager.has(MISFIRE) or not fear.has_panic(enemy) or manager.rng.randf() >= parameter(MISFIRE, "chance", 0.35):
		return
	projectile.allow_friendly_fire = true
	projectile.boon_context["tag"] = &"fear_misfire"
	projectile.boon_context["harmless_team"] = manager.health.team
	var nearest: Node3D
	var distance := INF
	for target in manager.enemies():
		if target == enemy or manager.health_of(target).is_dead():
			continue
		var point := target.global_position + Vector3.UP * 1.1
		var next := projectile.global_position.distance_squared_to(point)
		if next < distance and manager.line_clear(projectile.global_position, point):
			distance = next
			nearest = target
	if nearest != null:
		projectile.look_at(nearest.global_position + Vector3.UP * 1.1, Vector3.UP)


func _incoming(context: Dictionary) -> void:
	if context.get("tag", &"") == &"fear_misfire":
		context.damage = 0.0
		context.cancelled = true
		return
	if not manager.has(SENSE) or bool(context.get("cancelled", false)):
		return
	# Only roll when the pending hit exceeds known current absorption too.
	var protected_hp := manager.health.health + manager.shield_amount
	var shield := manager.player.get_node_or_null("Shield") as PlayerShield
	if shield != null and shield.is_active() and shield.is_counter_mode():
		protected_hp += maxf(0.0, shield.capacity() - shield.absorbed_damage())
	if float(context.get("damage", 0.0)) < protected_hp or manager.rng.randf() >= parameter(SENSE, "evade_chance", 0.35):
		return
	context.damage = 0.0
	context.cancelled = true
	var motion := manager.player.global_basis.z.normalized() * parameter(SENSE, "evade_distance", 3.0)
	var collision := KinematicCollision3D.new()
	if manager.player.test_move(manager.player.global_transform, motion, collision, 0.05):
		motion = collision.get_travel()
	manager.player.global_position += motion
	manager.feedback(manager.player.global_position + Vector3.UP, PanicFlawStatus.COLOR, 1.0)


func _update_desperate() -> void:
	var active := manager.has(DESPERATE) and manager.health.health / manager.health.max_health < parameter(DESPERATE, "health_threshold", 0.5)
	if active == _desperate_active:
		return
	_desperate_active = active
	if active:
		manager.set_modifier(&"fear_desperate", {Stats.MOVE_SPEED: {"mul": parameter(DESPERATE, "move_multiplier", 1.25)},
			Stats.CRIT_CHANCE: {"add": parameter(DESPERATE, "critical_add", 0.20)}, Stats.DASH_RECHARGE: {"mul": parameter(DESPERATE, "recharge_multiplier", 1.4)}})
	else:
		manager.remove_modifier(&"fear_desperate")


func _spawn_crystal(point: Vector3, broken_target: Node, depth: int) -> void:
	var target: Node3D
	var distance := INF
	for enemy in manager.enemies():
		if enemy == broken_target or manager.health_of(enemy).is_dead():
			continue
		var next := point.distance_squared_to(enemy.global_position)
		if next < distance:
			distance = next
			target = enemy
	if target == null:
		return
	var direction := (target.global_position + Vector3.UP - point).normalized()
	var excluded: Array[RID] = []
	_collect_rids(manager.player, excluded)
	if is_instance_valid(broken_target):
		_collect_rids(broken_target, excluded)
	var projectile := Projectile.spawn(manager.player.get_parent(), point + direction * 0.1, direction,
		manager.player, parameter(LEGENDARY, "crystal_damage", 35.0), parameter(LEGENDARY, "crystal_speed", 36.0), excluded, PanicFlawStatus.COLOR)
	projectile.boon_hook = manager.dispatch
	projectile.boon_context = {"tag": &"fear_legendary", "proc_depth": depth, "kind": &"proc", "fear_guaranteed_critical": true}
	var steering := FearHomingCrystal.new()
	steering.target = target
	steering.target_position = fear._target_flaw_position.bind(target)
	projectile.add_child(steering)
	fear._homing.append(steering)


func _collect_rids(node: Node, result: Array[RID]) -> void:
	if node is CollisionObject3D:
		result.append((node as CollisionObject3D).get_rid())
	for child in node.get_children():
		_collect_rids(child, result)


func parameter(id: String, key: String, fallback: float) -> float:
	return fear._parameter(id, key, fallback)


func cleanup() -> void:
	manager.remove_modifier(&"fear_desperate")
	for reference in _blind_targets.values():
		var enemy := reference.get_ref() as Node
		if enemy != null:
			manager.clear_status(enemy, &"fear_blind")
	_blind_targets.clear()
	_permanent.clear()
	if is_instance_valid(_warning):
		_warning.queue_free()
