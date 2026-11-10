class_name SorrowEffect
extends BoonEffect
const GUN := "sorrow_gun_needles"
const BLADE := "sorrow_blade_tide"
const DASH := "sorrow_dash_ribbon"
var states: Dictionary = {}
var tears: Array[TearCrystal] = []
var waters: Array[Dictionary] = []
var _wet_time: Dictionary = {}
var _dashing := false
var _last_dash := Vector3.ZERO
var _water_boost := false
var _visuals: Array[Node3D] = []
var _traits: SorrowTraits


func setup(value: BoonManager) -> void:
	super.setup(value)
	_traits = SorrowTraits.new()
	_traits.setup(self)


func parameter(id: String, key: String, fallback: float) -> float:
	var data := manager.get_boon(id)
	if data == null and id == GUN:
		for core_id: String in [BLADE, DASH]:
			if manager.has(core_id):
				data = manager.get_boon(core_id)
				break
	return float(data.parameters.get(key, fallback)) if data != null else fallback


func on_event(event: StringName, ctx: Dictionary) -> void:
	_traits.on_event(event, ctx)
	_prune_transients()
	match event:
		&"hit_after":
			if int(ctx.get("proc_depth", 0)) > 0 or float(ctx.get("dealt", 0.0)) <= 0.0:
				return
			if ctx.get("kind") == &"gun" and manager.has(GUN):
				add_erosion(ctx.get("target"), 1, ctx)
				_visuals.append(SorrowWaterFx.streak(manager.player.get_parent(), manager.weapon.global_position, ctx.position))
		&"enemy_damage_before":
			var layers := erosion_layers(ctx.get("target"))
			if layers > 0:
				ctx.damage = float(ctx.damage) * (1.0 + 0.1 * layers)
		&"blade_struck":
			if manager.has(BLADE):
				_clear_front_projectiles(ctx)
				for tear: TearCrystal in tears.duplicate():
					if is_instance_valid(tear) and not tear.consumed and _in_fan(tear.global_position, ctx.position, ctx.direction, manager.blade.strike_reach()):
						_strike_tear(tear, {"kind": &"blade", "direction": ctx.direction, "source": manager.player})
		&"dash_started":
			if manager.has(DASH):
				_dashing = true
				_last_dash = ctx.position
				_add_water(_last_dash)
		&"dash_finished":
			if _dashing:
				_trace_water(ctx.position)
				_dashing = false
		&"enemy_killed":
			var enemy := ctx.get("enemy") as Node3D
			if is_instance_valid(enemy) and erosion_layers(enemy) > 0:
				spawn_tear(enemy.global_position, 1, {"enemy": enemy, "reason": &"death"})
				_remove_state(enemy.get_instance_id())


func tick(delta: float) -> void:
	_traits.tick(delta)
	if manager.health.is_dead():
		return
	_prune_transients()
	for key: int in states.keys():
		var status = states[key]
		if not is_instance_valid(status) or not is_instance_valid(status.target) or not _alive(status.target):
			_remove_state(key)
			continue
		var time_scale := float(status.target.get("boon_time_scale")) if "boon_time_scale" in status.target else 1.0
		status.advance(delta * time_scale)
	if _dashing:
		_trace_water(manager.player.global_position)
	_tick_water(delta)
	for tear: TearCrystal in tears.duplicate():
		if not is_instance_valid(tear) or tear.consumed:
			continue
		tear.advance(delta)
		if tear.age >= 0.2 and tear.global_position.distance_to(manager.player.global_position + Vector3.UP * 0.3) <= tear.pickup_radius and manager.line_clear(tear.global_position, manager.player.global_position + Vector3.UP * 0.6):
			_pickup(tear)
	tears = tears.filter(func(tear): return is_instance_valid(tear) and not tear.consumed)
	_visuals = _visuals.filter(func(item): return is_instance_valid(item))


func erosion_layers(enemy: Node) -> int:
	if not is_instance_valid(enemy):
		return 0
	var status = states.get(enemy.get_instance_id())
	return status.layers if is_instance_valid(status) and status.active else 0


func add_erosion(enemy: Node, layers: int, _context: Dictionary = {}) -> void:
	if not _alive(enemy):
		return
	var key := enemy.get_instance_id()
	var status = states.get(key)
	if not is_instance_valid(status) or not status.active:
		status = ErosionStatus.new()
		status.setup(enemy, parameter(GUN, "erosion_duration", 5.0), parameter(GUN, "interval", 0.5))
		enemy.add_child(status)
		states[key] = status
		status.pulse.connect(_pulse)
		status.saturated.connect(func(value: ErosionStatus): spawn_tear(value.target.global_position, 1, {"enemy": value.target, "reason": &"saturation"}))
		status.expired.connect(func(value: ErosionStatus): _remove_state(value.target.get_instance_id()))
	status.add_layers(layers)
	_traits.status_changed(enemy)


func _alive(enemy: Node) -> bool:
	return is_instance_valid(enemy) and manager.is_enemy(enemy) and not manager.health_of(enemy).is_dead()


func _pulse(status: ErosionStatus, layers: int) -> void:
	manager.apply_damage(status.target, parameter(GUN, "damage_per_layer", 4.0) * layers, {"tag": &"sorrow_erosion", "proc_depth": 1})


func _remove_state(key: int) -> void:
	var status = states.get(key)
	if is_instance_valid(status):
		status.cancel()
	states.erase(key)
	if _traits != null and is_instance_valid(status) and is_instance_valid(status.target):
		_traits.status_changed(status.target)


func spawn_tear(pos: Vector3, count := 1, context: Dictionary = {}) -> void:
	var ctx := context.duplicate()
	ctx.merge({"count": count, "position": pos, "reason": &"effect"}, false)
	manager.dispatch(&"sorrow_tear_spawn_before", ctx)
	for index in clampi(int(ctx.count), 0, 32):
		var tear := (load("res://objects/tear_crystal.tscn") as PackedScene).instantiate() as TearCrystal
		manager.player.get_parent().add_child(tear)
		tear.global_position = _tear_ground(pos + Vector3(float(index) * 0.25, 0, 0))
		tear.struck.connect(_strike_tear)
		tears.append(tear)


func _pickup(tear: TearCrystal) -> void:
	if not tear.consume():
		return
	manager.grant_shield(parameter(GUN, "tear_shield", 25.0))
	var origin := manager.player.global_position + Vector3.UP
	manager.dispatch(&"sorrow_tear_collected", {"position": origin})
	_traits.pickup(origin)
	manager.aoe(origin, parameter(GUN, "pickup_radius", 3.0), parameter(GUN, "pickup_damage", 10.0), {"tag": &"sorrow_pickup", "proc_depth": 1})
	manager.feedback(origin, ErosionStatus.CYAN, 1.0)


func _strike_tear(tear: TearCrystal, ctx: Dictionary) -> void:
	if _traits.break_tear(tear, ctx):
		return
	if ctx.get("kind") != &"blade" or not manager.has(BLADE):
		return
	var position := tear.global_position
	if not tear.consume():
		return
	var direction: Vector3 = ctx.get("direction", -manager.player.global_basis.z)
	for angle in [-0.14, 0.0, 0.14]:
		var shot := Projectile.spawn(manager.player.get_parent(), position + Vector3.UP * parameter(BLADE, "tear_launch_height", 0.35), direction.rotated(Vector3.UP, angle), manager.player, parameter(BLADE, "tear_damage", 18.0), parameter(BLADE, "tear_speed", 24.0), [], ErosionStatus.CYAN)
		shot.max_distance = 18.0
	manager.dispatch(&"sorrow_tear_broken", {"position": position, "proc_depth": 1, "tag": &"sorrow_tear"})


func _clear_front_projectiles(ctx: Dictionary) -> void:
	for shot: Node3D in manager.projectiles():
		if is_instance_valid(shot) and manager.is_enemy(shot.get("source")) and _in_fan(shot.global_position, ctx.position, ctx.direction, parameter(BLADE, "wave_reach", 4.5)):
			manager.feedback(shot.global_position, ErosionStatus.CYAN, 0.15)
			shot.queue_free()
	for enemy: Node3D in manager.enemies():
		if _alive(enemy) and _in_fan(enemy.global_position + Vector3.UP, ctx.position, ctx.direction, manager.blade.strike_reach()):
			add_erosion(enemy, 1)


func _in_fan(point: Vector3, origin: Vector3, direction: Vector3, reach: float) -> bool:
	var offset := point - origin
	if offset.length() > reach or not manager.line_clear(origin, point):
		return false
	offset.y = 0.0
	direction.y = 0.0
	return offset.length_squared() < 0.001 or offset.normalized().dot(direction.normalized()) >= cos(deg_to_rad(40.0))


func _trace_water(end: Vector3) -> void:
	var gap := _last_dash.distance_to(end)
	if gap < 0.45:
		return
	var pieces := maxi(1, int(ceilf(gap / 0.65)))
	for index in pieces:
		_add_water(_last_dash.lerp(end, float(index + 1) / pieces))
	_last_dash = end


func _add_water(point: Vector3) -> void:
	var radius := parameter(DASH, "radius", 1.15)
	var duration := parameter(DASH, "duration", 3.0)
	waters.append({"center": point, "radius": radius, "remaining": duration})
	_visuals.append(SorrowWaterFx.pool(manager.player.get_parent(), point, radius, duration))


func _tick_water(delta: float) -> void:
	var wet: Dictionary = {}
	var player_wet := false
	for index in range(waters.size() - 1, -1, -1):
		var water: Dictionary = waters[index]
		water.remaining = float(water.remaining) - delta
		if float(water.remaining) <= 0.0:
			waters.remove_at(index)
			continue
		player_wet = player_wet or _inside_water(manager.player, water)
		for enemy: Node3D in manager.enemies():
			if _alive(enemy) and _inside_water(enemy, water):
				wet[enemy.get_instance_id()] = enemy
	for enemy: Node3D in manager.enemies():
		var key := enemy.get_instance_id()
		if wet.has(key):
			manager.set_status(enemy, &"sorrow_water", 0.0, 0.6)
			_wet_time[key] = float(_wet_time.get(key, 0.0)) + delta
			while _wet_time[key] >= 0.5:
				_wet_time[key] -= 0.5
				add_erosion(enemy, 1)
		else:
			manager.clear_status(enemy, &"sorrow_water")
			_wet_time.erase(key)
	if player_wet != _water_boost:
		_water_boost = player_wet
		if player_wet:
			manager.set_modifier(&"sorrow_water", {Stats.MOVE_SPEED: {"mul": 1.3}})
		else:
			manager.remove_modifier(&"sorrow_water")


func _inside_water(actor: Node3D, water: Dictionary) -> bool:
	var offset := actor.global_position - (water.center as Vector3)
	return absf(offset.y) < 0.7 and Vector2(offset.x, offset.z).length() <= float(water.radius) and manager.line_clear(water.center + Vector3.UP * 0.5, actor.global_position + Vector3.UP * 0.5)


func water_regions() -> Array[Dictionary]:
	return waters.duplicate(true)


func cleanup() -> void:
	_traits.cleanup()
	_traits = null
	_prune_transients()
	for key: int in states.keys():
		_remove_state(key)
	for tear: TearCrystal in tears:
		if is_instance_valid(tear):
			tear.queue_free()
	tears.clear()
	for item: Node3D in _visuals:
		if is_instance_valid(item):
			item.queue_free()
	_visuals.clear()
	waters.clear()
	for enemy: Node3D in manager.enemies():
		manager.clear_status(enemy, &"sorrow_water")
	manager.remove_modifier(&"sorrow_water")


func _prune_transients() -> void:
	tears = tears.filter(func(tear): return is_instance_valid(tear) and not tear.consumed)
	_visuals = _visuals.filter(func(item): return is_instance_valid(item))


func _tear_ground(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP, point - Vector3.UP * 12.0, CollisionLayers.WORLD)
	var hit := manager.player.get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and (hit.normal as Vector3).y > 0.5:
		return hit.position + Vector3.UP * 0.28
	return point + Vector3.UP * 0.28
