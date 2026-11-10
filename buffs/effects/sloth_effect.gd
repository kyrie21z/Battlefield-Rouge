class_name SlothEffect
extends BoonEffect
## Sloth clocks never refresh. Pressure is observed from Health, while extra
## pistol pressure is a separate ledger. Bursts cannot feed other clocks.
const GUN := "sloth_gun_pulse"
const BLADE := "sloth_blade_cleave"
const DASH := "sloth_dash_ripple"
const STATUS := &"sloth_latency"
const ROOT := &"sloth_ripple_root"
var clocks: Dictionary = {}
var auras: Array[Dictionary] = []
var _burst_depth := 0
var _waves: Array[Node3D] = []
var _traits: SlothTraits
var _dash_settling := false
var _still_elapsed := 0.0
var _last_position := Vector3.ZERO
var _attack_ready := false
var _blade_boost := false


func setup(value: BoonManager) -> void:
	super.setup(value)
	_last_position = manager.player.global_position
	_traits = SlothTraits.new()
	_traits.setup(self)


func parameter(id: String, key: String, fallback: float) -> float:
	var data := manager.get_boon(id)
	return float(data.parameters.get(key, fallback)) if data != null else fallback


func on_event(event: StringName, ctx: Dictionary) -> void:
	if event != &"hit_after":
		_traits.on_event(event, ctx)
	match event:
		&"enemy_damage":
			var victim := ctx.get("target") as Node3D
			if _burst_depth == 0 and ctx.get("tag") != &"sloth_burst" and has_latency(victim):
				(clocks[victim.get_instance_id()] as LatencyStatus).record_damage(float(ctx.get("dealt", 0.0)))
		&"enemy_killed":
			var victim := ctx.get("enemy") as Node3D
			if is_instance_valid(victim):
				_remove_clock(victim.get_instance_id())
		&"hit_after":
			if int(ctx.get("proc_depth", 0)) > 0 or float(ctx.get("dealt", 0.0)) <= 0.0:
				return
			var victim := ctx.get("target") as Node3D
			if not manager.is_enemy(victim):
				return
			if ctx.get("kind") == &"gun" and manager.has(GUN):
				if has_latency(victim):
					(clocks[victim.get_instance_id()] as LatencyStatus).add_shot_pressure(parameter(GUN, "repeat_pressure", 25.0))
				else:
					apply_latency(victim, GUN)
			elif ctx.get("kind") == &"blade" and manager.has(BLADE):
				if has_latency(victim):
					(clocks[victim.get_instance_id()] as LatencyStatus).detonate(parameter(BLADE, "detonation_multiplier", 1.5))
				else:
					apply_latency(victim, BLADE)
			_traits.on_event(event, ctx)
		&"hit_before":
			if ctx.get("kind") == &"blade" and int(ctx.get("proc_depth", 0)) == 0 and _blade_boost:
				ctx.damage = float(ctx.damage) * parameter(DASH, "next_attack_multiplier", 1.5)
		&"shoot_before":
			if _attack_ready and manager.has(DASH):
				ctx.damage_multiplier = float(ctx.get("damage_multiplier", 1.0)) * parameter(DASH, "next_attack_multiplier", 1.5)
				_attack_ready = false
		&"blade_started":
			_blade_boost = _attack_ready and manager.has(DASH)
			_attack_ready = false
			if manager.has(BLADE):
				manager.set_modifier(&"sloth_blade_armor", {&"armor": {"add": 1.0}})
		&"blade_finished":
			_blade_boost = false
			manager.remove_modifier(&"sloth_blade_armor")
		&"dash_started":
			_dash_settling = false
			_attack_ready = false
			if manager.has(DASH):
				_spawn_aura(ctx.position)
		&"dash_finished":
			if manager.has(DASH):
				_spawn_aura(ctx.position)
				_dash_settling = true
				_still_elapsed = 0.0
				_last_position = manager.player.global_position


func tick(delta: float) -> void:
	_traits.tick(delta)
	_waves = _waves.filter(func(wave): return is_instance_valid(wave))
	for key: int in clocks.keys():
		var clock = clocks[key]
		if not is_instance_valid(clock) or not is_instance_valid(clock.target) or not _alive(clock.target):
			_remove_clock(key)
			continue
		var scale := float(clock.target.get("boon_time_scale")) if "boon_time_scale" in clock.target else 1.0
		clock.advance(delta * scale)
	for index in range(auras.size() - 1, -1, -1):
		var aura: Dictionary = auras[index]
		aura.remaining = float(aura.remaining) - delta
		for victim: Node3D in manager.targets_in_radius(aura.origin + Vector3.UP, aura.radius):
			var key := victim.get_instance_id()
			if aura.touched.has(key):
				continue
			aura.touched[key] = true
			manager.set_status(victim, ROOT, parameter(DASH, "root_duration", 1.0), 0.0)
			apply_latency(victim, DASH)
		if float(aura.remaining) <= 0.0:
			auras.remove_at(index)
	if _dash_settling:
		var current := manager.player.global_position
		if current.distance_squared_to(_last_position) > 0.000001 or manager.dash.is_dashing():
			_still_elapsed = 0.0
		else:
			_still_elapsed += delta
		_last_position = current
		if _still_elapsed >= parameter(DASH, "settle_duration", 0.5):
			_dash_settling = false
			_attack_ready = true


func has_latency(victim: Node) -> bool:
	if not is_instance_valid(victim):
		return false
	var clock = clocks.get(victim.get_instance_id())
	return is_instance_valid(clock) and clock.active


func apply_latency(victim: Node3D, card := GUN, deep := false) -> LatencyStatus:
	if not _alive(victim):
		return null
	var key := victim.get_instance_id()
	if has_latency(victim):
		var existing := clocks[key] as LatencyStatus
		if deep:
			existing.deepen()
			manager.set_status(victim, STATUS, 0.0, existing.slow_factor)
		return existing
	var clock := LatencyStatus.new()
	clock.setup(victim, parameter(card, "latency_duration", 1.5), parameter(card, "burst_damage", 60.0), deep)
	clock.offense_scale = manager.stats.get_value.bind(Stats.DAMAGE)
	clocks[key] = clock
	victim.add_child(clock)
	clock.detonated.connect(_on_detonated)
	_traits.prepare_clock(clock)
	manager.set_status(victim, STATUS, 0.0, clock.slow_factor)
	return clock


func _alive(victim: Node) -> bool:
	if not is_instance_valid(victim) or not manager.is_enemy(victim):
		return false
	var health := manager.health_of(victim)
	return health != null and not health.is_dead()


func _on_detonated(clock: LatencyStatus, origin: Vector3, damage: float) -> void:
	var key := clock.target.get_instance_id()
	_remove_clock(key, false)
	_burst_depth += 1
	manager.dispatch(&"sloth_burst", {"target": clock.target, "position": origin, "damage": damage, "proc_depth": 1, "tag": &"sloth_burst", "damage_scaled": true})
	var radius := _burst_radius()
	var victims := manager.targets_in_radius(origin, radius)
	manager.aoe(origin, radius, damage, {"tag": &"sloth_burst", "proc_depth": 1, "damage_scaled": true})
	_traits.after_burst(origin, damage, radius, victims)
	_burst_depth -= 1
	_waves.append(SlothWave.spawn(manager.player.get_parent(), origin - Vector3.UP * 0.8, _burst_radius()))


func _burst_radius() -> float:
	for id: String in [GUN, BLADE, DASH]:
		if manager.has(id):
			return parameter(id, "burst_radius", 3.0) * _traits.radius_multiplier()
	return parameter(SlothTraits.HEAVY, "burst_radius", 3.0) * _traits.radius_multiplier()


func _remove_clock(key: int, cancel := true) -> void:
	var clock = clocks.get(key)
	if is_instance_valid(clock):
		if is_instance_valid(clock.target):
			manager.clear_status(clock.target, STATUS)
		if cancel:
			clock.cancel()
	clocks.erase(key)


func _spawn_aura(origin: Vector3) -> void:
	var radius := parameter(DASH, "aura_radius", 2.5)
	var duration := parameter(DASH, "aura_duration", 1.25)
	auras.append({"origin": origin, "radius": radius, "remaining": duration, "touched": {}})
	_waves.append(SlothWave.spawn(manager.player.get_parent(), origin, radius, duration, false))


func cleanup() -> void:
	_waves = _waves.filter(func(wave): return is_instance_valid(wave))
	_traits.cleanup()
	_traits = null
	for wave: Node3D in _waves:
		if is_instance_valid(wave):
			wave.queue_free()
	_waves.clear()
	for key: int in clocks.keys():
		_remove_clock(key)
	for victim: Node3D in manager.enemies():
		manager.clear_status(victim, ROOT)
	auras.clear()
	_dash_settling = false
	_attack_ready = false
	_blade_boost = false
	manager.remove_modifier(&"sloth_blade_armor")


func latent_enemies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for key: int in clocks:
		var clock = clocks[key]
		if is_instance_valid(clock) and clock.active and is_instance_valid(clock.target) and _alive(clock.target):
			result.append(clock.target)
	return result


func aura_regions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for aura: Dictionary in auras:
		result.append({"center": aura.origin, "radius": aura.radius, "remaining": aura.remaining})
	return result
