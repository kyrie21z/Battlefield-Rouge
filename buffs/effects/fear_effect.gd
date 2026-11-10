class_name FearEffect
extends BoonEffect
## Fear uses actual body contacts, target-local facets, and the same reflected
## projectile that the blade caught. No status is stored in global groups.

const GUN := "fear_gaze_pierce"
const BLADE := "fear_flash_backstab"
const DASH := "fear_tremor_decoy"
const STATUS_NAME := "PanicFlawStatus"

var _statuses: Dictionary = {}
var _decoys: Array[FearDecoy] = []
var _decoy_targets: Dictionary = {}
var _homing: Array[FearHomingCrystal] = []


func tick(_delta: float) -> void:
	for i in range(_homing.size() - 1, -1, -1):
		if not is_instance_valid(_homing[i]):
			_homing.remove_at(i)
	for id in _statuses.keys():
		if not is_instance_valid(_statuses[id]):
			_statuses.erase(id)


func on_event(event: StringName, context: Dictionary) -> void:
	match event:
		&"hit_before":
			_before_hit(context)
		&"hit_after":
			_after_hit(context)
		&"dash_started":
			if manager.has(DASH):
				_spawn_decoy(context.get("position", manager.player.global_position))
		&"parry":
			if manager.has(BLADE):
				_home_reflected(context)
		&"clock_struck":
			if manager.has(BLADE):
				manager.feedback(context.get("position", manager.player.global_position), PanicFlawStatus.COLOR, 1.1)


func status_for(target: Node3D, create := false) -> PanicFlawStatus:
	if not is_instance_valid(target):
		return null
	var status := target.get_node_or_null(STATUS_NAME) as PanicFlawStatus
	if status == null and create:
		status = PanicFlawStatus.new()
		status.name = STATUS_NAME
		status.actor = target
		status.health = manager.health_of(target)
		target.add_child(status)
		_statuses[target.get_instance_id()] = status
	return status


func apply_panic(target: Node3D, duration := 4.0, permanent := false, count := 1) -> PanicFlawStatus:
	if not manager.is_enemy(target):
		return null
	var status := status_for(target, true)
	status.apply(duration, permanent, count)
	return status


func has_panic(target: Node3D) -> bool:
	var status := status_for(target)
	return status != null and status.is_active()


func set_flaw_area_multiplier(target: Node3D, source: StringName, multiplier: float) -> void:
	var status := status_for(target)
	if status != null:
		status.set_area_modifier(source, multiplier)


func _before_hit(context: Dictionary) -> void:
	# Derived attacks may copy a parent context. A facet belongs to this contact,
	# never to the parent hit that caused an explosion or damage-over-time tick.
	for key in ["fear_flaw", "fear_flaw_position", "fear_critical", "fear_execution"]:
		context.erase(key)
	var target := context.get("target") as Node3D
	if not manager.is_enemy(target):
		return
	var status := status_for(target)
	var active := status != null and status.is_active()
	var point: Vector3 = context.get("position", target.global_position + Vector3.UP)
	var direction: Vector3 = context.get("direction", Vector3.ZERO)
	var index := status.contact_index(point, direction) if active else -1
	var hitbox := context.get("hitbox") as Hitbox
	if active and is_instance_valid(hitbox) and hitbox.has_meta("fear_flaw_index"):
		index = int(hitbox.get_meta("fear_flaw_index"))
	var kind: StringName = context.get("kind", &"proc")
	var backstab := _is_backstab(target, context.get("source"))
	var headshot: bool = context.get("body_part", Hitbox.BodyPart.BODY) == Hitbox.BodyPart.HEAD
	var physical_contact := kind in [&"gun", &"blade"] or direction.length_squared() > 0.0001
	var critical := active and (index >= 0 or (physical_contact and (backstab or headshot)))
	critical = critical or (kind == &"blade" and manager.has(BLADE) and backstab)
	if not critical:
		return
	var multiplier := 2.6 if kind == &"gun" and manager.has(GUN) and index >= 0 else 2.0
	context["damage"] = float(context.get("damage", 0.0)) / maxf(float(context.get("critical_multiplier", 1.0)), 1.0) * multiplier
	context["critical"] = true
	context["critical_multiplier"] = multiplier
	context["body_part"] = Hitbox.BodyPart.BODY
	context["fear_critical"] = true
	context["fear_flaw"] = index
	if index >= 0 and status != null:
		context["fear_flaw_position"] = status.facet_position(index)


func _after_hit(context: Dictionary) -> void:
	if float(context.get("dealt", 0.0)) <= 0.0:
		return
	var target := context.get("target") as Node3D
	if not is_instance_valid(target):
		return
	var status := status_for(target)
	var index := int(context.get("fear_flaw", -1))
	var natural := int(context.get("proc_depth", 0)) == 0
	if bool(context.get("fear_critical", false)):
		var point: Vector3 = context.get("position", target.global_position + Vector3.UP)
		manager.feedback(point, PanicFlawStatus.COLOR, 0.7)
		FearCriticalFeedback.spawn(manager.player.get_parent(), point, float(context.dealt))
	if index >= 0 and status != null:
		var point: Vector3 = context.get("fear_flaw_position", status.facet_position(index))
		var broke := status.break_facet(index, context.get("kind") == &"gun" and manager.has(GUN) and not status.health.is_dead())
		if broke or bool(context.get("killed", false)):
			var fracture := context.duplicate()
			fracture["position"] = point
			manager.dispatch(&"fear_flaw_broken", fracture)
	if natural and context.get("kind") == &"gun" and manager.has(GUN) and manager.is_enemy(target):
		apply_panic(target, _parameter(GUN, "panic_duration", 4.0))


func _spawn_decoy(point: Vector3) -> void:
	var decoy := FearDecoy.new()
	decoy.lifetime = _parameter(DASH, "decoy_duration", 2.0)
	decoy.pose_source = manager.player.get_node_or_null("ShadowBody") as Node3D
	manager.player.get_parent().add_child(decoy)
	decoy.global_position = point
	if decoy.pose_source == null:
		decoy.global_basis = manager.player.global_basis
	_decoys.append(decoy)
	decoy.burst.connect(_decoy_burst.bind(decoy))
	for enemy in manager.targets_in_radius(point, _parameter(DASH, "aggro_radius", 16.0)):
		if not "target" in enemy:
			continue
		var id := enemy.get_instance_id()
		if not _decoy_targets.has(id):
			_decoy_targets[id] = {"enemy": weakref(enemy), "target": weakref(enemy.target) if is_instance_valid(enemy.target) else null}
		enemy.target = decoy


func _decoy_burst(point: Vector3, decoy: FearDecoy) -> void:
	_restore_decoy_targets(decoy)
	_decoys.erase(decoy)
	for enemy in manager.targets_in_radius(point, _parameter(DASH, "panic_radius", 6.0)):
		apply_panic(enemy, _parameter(DASH, "panic_duration", 4.0))
	manager.feedback(point + Vector3.UP, PanicFlawStatus.COLOR, _parameter(DASH, "panic_radius", 6.0))


func _restore_decoy_targets(decoy: FearDecoy) -> void:
	for id in _decoy_targets.keys():
		var record: Dictionary = _decoy_targets[id]
		var enemy: Node = record.enemy.get_ref()
		if not is_instance_valid(enemy):
			_decoy_targets.erase(id)
			continue
		if enemy.target == decoy:
			var original: Node = record.target.get_ref() if record.target != null else null
			enemy.target = original if is_instance_valid(original) else manager.player
			_decoy_targets.erase(id)


func _home_reflected(context: Dictionary) -> void:
	var projectile := context.get("projectile") as Projectile
	if projectile == null:
		return
	var target := _nearest_flaw(projectile.global_position)
	var steering := FearHomingCrystal.new()
	steering.target = target
	if target != null:
		steering.target_position = _target_flaw_position.bind(target)
	steering.impact_callback = _detonate_flaws
	projectile.add_child(steering)
	_homing.append(steering)
	projectile.max_distance = 150.0


func _nearest_flaw(point: Vector3) -> Node3D:
	var result: Node3D
	var distance := INF
	for enemy in manager.enemies():
		var status := status_for(enemy)
		if status == null or not status.is_active() or status.facet_count() == 0:
			continue
		var next := point.distance_squared_to(enemy.global_position)
		if next < distance:
			distance = next
			result = enemy
	return result


func _target_flaw_position(target: Node3D) -> Vector3:
	var status := status_for(target)
	if status != null:
		for i in status.facets.size():
			if is_instance_valid(status.facets[i]):
				return status.facet_position(i)
	return target.global_position + Vector3.UP


func _detonate_flaws(victim: Node, _point: Vector3) -> void:
	if manager.is_enemy(victim):
		detonate_all_flaws({"tag": &"fear_parry_detonation", "proc_depth": 1})


func detonate_all_flaws(context: Dictionary = {}) -> void:
	# Snapshot protects iteration from kills removing actors and from a later
	# secondary boon adding facets while this detonation is resolving.
	var pending: Array[Dictionary] = []
	for enemy in manager.enemies():
		var status := status_for(enemy)
		if status != null and status.is_active():
			for i in status.facets.size():
				if is_instance_valid(status.facets[i]):
					pending.append({"target": enemy, "index": i, "point": status.facet_position(i)})
	for entry in pending:
		var target := entry.target as Node3D
		if not manager.is_enemy(target):
			continue
		var hit := context.duplicate()
		hit.merge({"kind": &"proc", "tag": &"fear_detonation", "proc_depth": 1}, false)
		hit.merge({"position": entry.point, "fear_flaw": entry.index, "critical": true, "critical_multiplier": 1.0, "damage_scaled": false}, true)
		manager.apply_damage(target, _parameter(BLADE, "detonation_damage", 35.0), hit)


func _is_backstab(target: Node3D, source: Node) -> bool:
	if not source is Node3D:
		return false
	var toward := (source as Node3D).global_position - target.global_position
	toward.y = 0.0
	return toward.length_squared() > 0.0001 and toward.normalized().dot(target.global_basis.z.normalized()) > 0.5


func _parameter(id: String, key: String, fallback: float) -> float:
	var data := manager.get_boon(id)
	return float(data.parameters.get(key, fallback)) if data != null else fallback


func cleanup() -> void:
	for steering in _homing:
		if is_instance_valid(steering):
			steering.impact_callback = Callable()
			steering.queue_free()
	_homing.clear()
	for decoy in _decoys:
		if is_instance_valid(decoy):
			_restore_decoy_targets(decoy)
			decoy.cancel()
	_decoys.clear()
	_decoy_targets.clear()
	for status in _statuses.values():
		if is_instance_valid(status):
			status.clear()
			status.queue_free()
	_statuses.clear()
