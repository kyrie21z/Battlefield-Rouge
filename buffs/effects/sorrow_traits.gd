class_name SorrowTraits
extends RefCounted
const ECHO := "sorrow_echo"
const TIDE := "sorrow_gravity"
const BUFFER := "sorrow_buffer"
const PRESSURE := "sorrow_pressure"
const SHARDS := "sorrow_shards"
const SUFFOCATION := "sorrow_suffocation"
const FLOOD := "sorrow_flood"
const MERCY := "sorrow_mercy"
const ABYSS := "sorrow_abyss"
var owner: SorrowEffect
var manager: BoonManager
var debt: Array[Dictionary] = []
var fountains: Array[Dictionary] = []
var blades: Array[SorrowWaterBlade] = []
var _resolved_debt := 0.0
var _mercy_count := -1
var _flood_depth := 0


func setup(effect: SorrowEffect) -> void:
	owner = effect
	manager = owner.manager


func value(id: String, key: String, fallback: float) -> float:
	return owner.parameter(id, key, fallback)


func on_event(event: StringName, ctx: Dictionary) -> void:
	match event:
		&"damage_before":
			if ctx.get("tag") == &"sorrow_deferred" or ctx.get("unbuffered",false):
				return
			if manager.has(BUFFER) and float(ctx.damage) >= value(BUFFER, "threshold", 20.0):
				var deferred := float(ctx.damage) * value(BUFFER, "fraction", 0.5)
				ctx.damage = float(ctx.damage) - deferred
				debt.append({"remaining": deferred, "rate": deferred / value(BUFFER, "duration", 3.0), "source": weakref(ctx.get("source")) if is_instance_valid(ctx.get("source")) else null})
		&"damage_after":
			if ctx.get("tag") == &"sorrow_deferred":
				_resolved_debt = float(ctx.get("resolved_damage", 0.0))
		&"enemy_damage_before":
			if manager.has(SUFFOCATION) and owner.erosion_layers(ctx.get("target")) > 0 and bool(ctx.get("critical", false)):
				ctx.damage = float(ctx.damage) * value(SUFFOCATION, "critical_multiplier", 1.4)
		&"enemy_damage":
			if manager.has(FLOOD) and _flood_depth == 0 and float(ctx.get("dealt", 0.0)) > 0.0 and owner.erosion_layers(ctx.get("target")) >= 5:
				_flood_depth += 1
				var enemy := ctx.get("target") as Node3D
				for nearby: Node3D in manager.targets_in_radius(enemy.global_position + Vector3.UP, value(FLOOD, "radius", 3.5)):
					if nearby != enemy:
						owner.add_erosion(nearby, int(value(FLOOD, "spread_layers", 1.0)), {"proc_depth": 1, "tag": &"sorrow_flood"})
				manager.feedback(enemy.global_position + Vector3.UP, ErosionStatus.CYAN, 0.6)
				_flood_depth -= 1
		&"projectile_registered":
			var shot := ctx.get("projectile") as Node3D
			if manager.has(PRESSURE) and is_instance_valid(shot) and owner.erosion_layers(shot.get("source")) >= 5:
				manager.set_projectile_scale(shot, &"sorrow_pressure", value(PRESSURE, "projectile_scale", 0.6))
		&"enemy_killed":
			if manager.has(ABYSS) and ctx.get("source") == manager.player:
				var enemy := ctx.get("enemy") as Node3D
				if is_instance_valid(enemy):
					_spawn_fountain(enemy.global_position)


func tick(delta: float) -> void:
	owner._prune_transients()
	_tick_debt(delta)
	if manager == null:
		return
	for enemy: Node3D in manager.enemies():
		_refresh_enemy(enemy)
	if not manager.has(PRESSURE):
		for shot: Node3D in manager.projectiles():
			manager.set_projectile_scale(shot, &"sorrow_pressure", 1.0)
	var count := 0
	for tear: TearCrystal in owner.tears.duplicate():
		if not is_instance_valid(tear) or tear.consumed:
			continue
		tear.pickup_radius = 0.85 * value(TIDE, "pickup_multiplier", 2.5) if manager.has(TIDE) else 0.85
		if manager.has(ABYSS):
			var origin := tear.global_position + Vector3.UP * 0.6
			if tear.consume():
				_spawn_blade(origin)
		else:
			count += 1
		if not manager.has(ABYSS) and manager.has(TIDE):
			var end := manager.player.global_position + Vector3.UP * 0.28
			var step := tear.global_position.move_toward(end, delta * value(TIDE, "pull_speed", 2.0))
			if manager.line_clear(tear.global_position, step):
				tear.global_position = step
	if manager.has(MERCY):
		if count != _mercy_count:
			_mercy_count = count
			manager.set_modifier(&"sorrow_mercy", {Stats.DAMAGE_TAKEN: {"mul": 1.0 - minf(value(MERCY, "maximum_reduction", 0.36), count * value(MERCY, "per_tear", 0.04))}})
		var capacity := value(MERCY, "shield_cap", 35.0)
		if manager.shield_amount < capacity:
			manager.grant_shield(minf(capacity - manager.shield_amount, delta * value(MERCY, "shield_regen", 2.0)))
	else:
		manager.remove_modifier(&"sorrow_mercy")
		_mercy_count = -1
	_tick_fountains(delta)
	blades = blades.filter(func(blade): return is_instance_valid(blade))


func status_changed(enemy: Node3D) -> void:
	_refresh_enemy(enemy)


func _refresh_enemy(enemy: Node3D) -> void:
	var layers := owner.erosion_layers(enemy)
	if manager.has(PRESSURE) and layers >= 5:
		manager.set_status(enemy, &"sorrow_pressure", 0.0, 1.0, 1.0, false, value(PRESSURE, "windup_scale", 1.3))
	else:
		manager.clear_status(enemy, &"sorrow_pressure")
	var health := manager.health_of(enemy)
	if health != null:
		health.set_shield_regeneration_blocked(&"sorrow_suffocation", manager.has(SUFFOCATION) and layers > 0)


func pickup(origin: Vector3) -> void:
	# A tear cancels the deferred debt, independently of its normal 25 shield.
	debt.clear()
	if not manager.has(ECHO):
		return
	for enemy: Node3D in manager.targets_in_radius(origin, value(ECHO, "radius", 3.5)):
		owner.add_erosion(enemy, 1)
		if enemy.has_method("apply_impact"):
			var direction := (enemy.global_position - manager.player.global_position).normalized()
			enemy.apply_impact(direction, value(ECHO, "force", 4.0), 0.15)


func break_tear(tear: TearCrystal, context: Dictionary) -> bool:
	if not manager.has(SHARDS) or context.get("kind") not in [&"gun", &"blade"]:
		return false
	var origin := tear.global_position
	if not tear.consume():
		return true
	var radius := value(SHARDS, "radius", 3.0)
	manager.aoe(origin + Vector3.UP * 0.4, radius, value(SHARDS, "damage", 45.0), {"tag": &"sorrow_shards", "proc_depth": 1})
	for enemy: Node3D in manager.targets_in_radius(origin + Vector3.UP * 0.4, radius):
		owner.add_erosion(enemy, 2)
	manager.feedback(origin, ErosionStatus.CYAN, radius * 0.45)
	manager.dispatch(&"sorrow_tear_broken", {"position": origin, "proc_depth": 1, "tag": &"sorrow_shards"})
	return true


func pending_damage() -> float:
	var result := 0.0
	for entry: Dictionary in debt:
		result += float(entry.remaining)
	return result


func _tick_debt(delta: float) -> void:
	if manager == null:
		return
	for index in range(debt.size() - 1, -1, -1):
		var entry: Dictionary = debt[index]
		var amount := minf(float(entry.remaining), float(entry.rate) * delta)
		if manager.health.unbuffered:
			amount = float(entry.remaining)
		if amount <= 0.0:
			continue
		var attacker: Node = entry.source.get_ref() if entry.source != null else null
		_resolved_debt = 0.0
		var live_manager := manager
		live_manager.health.apply_damage(amount, Hitbox.BodyPart.BODY, attacker, {"tag": &"sorrow_deferred", "skip_damage_multiplier": true, "proc_depth": 1})
		if manager == null or live_manager.health.is_dead():
			return
		var resolved := minf(amount, _resolved_debt)
		entry.remaining = maxf(float(entry.remaining) - resolved, 0.0)
		if resolved > 0.0:
			manager.dispatch(&"sorrow_deferred_tick", {"damage": resolved, "resolved_debt": resolved, "position": manager.player.global_position, "source": attacker, "tag": &"sorrow_deferred", "proc_depth": 1})
		if float(entry.remaining) <= 0.00001:
			debt.remove_at(index)


func _spawn_fountain(origin: Vector3) -> void:
	var duration := value(ABYSS, "fountain_duration", 6.0)
	var visual := SorrowWaterFx.pool(manager.player.get_parent(), origin, 0.75, duration)
	var jet := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(0.35, 2.4, 0.35)
	jet.mesh = prism
	jet.material_override = visual.material_override
	jet.position.y = 1.1
	visual.add_child(jet)
	fountains.append({"origin": origin, "remaining": duration, "until_fire": 0.0, "visual": visual})
	while fountains.size() > int(value(ABYSS, "maximum_fountains", 12.0)):
		var old: Dictionary = fountains.pop_front()
		if is_instance_valid(old.visual):
			old.visual.queue_free()


func _tick_fountains(delta: float) -> void:
	for index in range(fountains.size() - 1, -1, -1):
		var fountain: Dictionary = fountains[index]
		fountain.remaining = float(fountain.remaining) - delta
		fountain.until_fire = float(fountain.until_fire) - delta
		if not manager.has(ABYSS) or float(fountain.remaining) <= 0.0:
			if is_instance_valid(fountain.visual):
				fountain.visual.queue_free()
			fountains.remove_at(index)
			continue
		while float(fountain.until_fire) <= 0.0:
			fountain.until_fire = float(fountain.until_fire) + value(ABYSS, "fire_interval", 0.6)
			_spawn_blade(fountain.origin + Vector3.UP * 1.2)


func _spawn_blade(origin: Vector3) -> void:
	var blade := SorrowWaterBlade.new()
	blade.manager = manager
	blade.source = manager.player
	blade.damage = value(ABYSS, "blade_damage", 14.0)
	blade.speed = value(ABYSS, "blade_speed", 22.0)
	manager.player.get_parent().add_child(blade)
	blade.global_position = origin
	blades.append(blade)


func cleanup() -> void:
	blades = blades.filter(func(blade): return is_instance_valid(blade))
	debt.clear()
	for enemy: Node3D in manager.enemies():
		manager.clear_status(enemy, &"sorrow_pressure")
		var health := manager.health_of(enemy)
		if health != null:
			health.set_shield_regeneration_blocked(&"sorrow_suffocation", false)
	for shot: Node3D in manager.projectiles():
		manager.set_projectile_scale(shot, &"sorrow_pressure", 1.0)
	for blade: SorrowWaterBlade in blades:
		if is_instance_valid(blade):
			blade.queue_free()
	for fountain: Dictionary in fountains:
		if is_instance_valid(fountain.visual):
			fountain.visual.queue_free()
	blades.clear()
	fountains.clear()
	manager.remove_modifier(&"sorrow_mercy")
	owner = null
	manager = null
