class_name SlothTraits
extends RefCounted
## Extension of the one Sloth effect instance. It owns only reversible sources,
## and its independent player clock can restore a world frozen at scale zero.
const INERTIA := "sloth_inertia"
const RESONANCE := "sloth_resonance"
const STILLNESS := "sloth_stillness"
const RELOAD := "sloth_reload"
const HEAVY := "sloth_heavy_beat"
const DROWSY := "sloth_drowsy"
const DESCENT := "sloth_descent"
const FIELD := "sloth_time_field"
const ETERNAL := "sloth_eternal"
const FIELD_SOURCE := &"sloth_time_field"
var owner: SlothEffect
var manager: BoonManager
var _still_elapsed := 0.0
var _last_position := Vector3.ZERO
var _rest_active := false
var _field_active := false
var _drowsy_applied := false
var _reload_clean := false
var _reload_empty := false
var _beat_elapsed := 0.0
var _beat_ready := false
var _gun_deep := false
var _blade_deep := false
var _time := 0.0
var _kills: Array[float] = []
var _freeze_remaining := 0.0
var _visual: SlothFeedback


func setup(effect: SlothEffect) -> void:
	owner = effect
	manager = owner.manager
	_last_position = manager.player.global_position
	_visual = SlothFeedback.new()
	manager.add_child(_visual)


func value(id: String, key: String, fallback: float) -> float:
	return owner.parameter(id, key, fallback)


func on_event(event: StringName, ctx: Dictionary) -> void:
	match event:
		&"hit_before":
			if manager.has(DESCENT) and int(ctx.get("proc_depth", 0)) == 0 and owner.has_latency(ctx.get("target")):
				ctx.crit_chance_add = float(ctx.get("crit_chance_add", 0.0)) + value(DESCENT, "crit_chance", 0.25)
		&"hit_after":
			if int(ctx.get("proc_depth", 0)) != 0 or float(ctx.get("dealt", 0.0)) <= 0.0:
				return
			var deep := _gun_deep if ctx.get("kind") == &"gun" else _blade_deep if ctx.get("kind") == &"blade" else false
			if deep and manager.has(HEAVY):
				owner.apply_latency(ctx.get("target"), HEAVY, true)
		&"shoot_before":
			_gun_deep = _consume_beat()
		&"blade_started":
			_blade_deep = _consume_beat()
		&"blade_finished":
			_blade_deep = false
		&"reload_started":
			_reload_empty = bool(ctx.get("empty", false))
			_reload_clean = _reload_empty
		&"damage_after":
			if float(ctx.get("dealt", 0.0)) > 0.0:
				_reload_clean = false
		&"reload_finished":
			if manager.has(RELOAD) and _reload_empty and _reload_clean:
				manager.grant_shield(value(RELOAD, "shield", 35.0))
				manager.feedback(manager.player.global_position + Vector3.UP, LatencyStatus.AMBER)
			_reload_clean = false
			_reload_empty = false
		&"projectile_registered":
			_modify_projectile(ctx.get("projectile"))
		&"enemy_registered":
			if _field_active:
				manager.set_status(ctx.get("enemy"), FIELD_SOURCE, 0.0, 1.0, value(FIELD, "world_scale", 0.8))
		&"enemy_killed":
			_record_kill(ctx)


func tick(delta: float) -> void:
	_time += delta
	if _drowsy_applied and not manager.has(DROWSY):
		for projectile: Node3D in manager.projectiles():
			manager.set_projectile_scale(projectile, &"sloth_drowsy", 1.0)
		_drowsy_applied = false
	_freeze_remaining = maxf(0.0, _freeze_remaining - delta)
	if not manager.has(ETERNAL) and _freeze_remaining > 0.0:
		_freeze_remaining = 0.0
		manager.clear_world_freeze(&"sloth_eternal")
	if manager.has(HEAVY):
		_beat_elapsed += delta
		if _beat_elapsed >= value(HEAVY, "interval", 1.5):
			_beat_ready = true
	else:
		_beat_ready = false
		_beat_elapsed = 0.0
	var current := manager.player.global_position
	if current.distance_squared_to(_last_position) > 0.000001 or manager.dash.is_dashing():
		_still_elapsed = 0.0
	else:
		_still_elapsed += delta
	_last_position = current
	_set_rest(manager.has(STILLNESS) and _still_elapsed >= value(STILLNESS, "stand_duration", 1.2))
	var count := 0
	for key: int in owner.clocks:
		var clock = owner.clocks[key]
		if is_instance_valid(clock) and clock.active and is_instance_valid(clock.target) and owner._alive(clock.target):
			clock.pressure_multiplier = value(INERTIA, "pressure_multiplier", 1.5) if manager.has(INERTIA) else 1.0
			count += 1
	_set_field(manager.has(FIELD) and count >= int(value(FIELD, "minimum_targets", 2.0)))
	if is_instance_valid(_visual):
		_visual.show_stillness(_rest_active)
		_visual.time_strength = 0.9 if _freeze_remaining > 0.0 else 0.16 if _field_active else 0.0


func prepare_clock(clock: LatencyStatus) -> void:
	clock.pressure_multiplier = value(INERTIA, "pressure_multiplier", 1.5) if manager.has(INERTIA) else 1.0


func radius_multiplier() -> float:
	return value(RESONANCE, "radius_multiplier", 1.6) if manager.has(RESONANCE) else 1.0


func after_burst(origin: Vector3, damage: float, radius: float, victims: Array[Node3D]) -> void:
	if manager.has(DESCENT):
		for victim: Node3D in manager.targets_in_radius(origin, radius):
			manager.set_status(victim, &"sloth_sleep", value(DESCENT, "sleep_duration", 1.0), 1.0, 1.0, true)
	if not manager.has(RESONANCE):
		return
	# Exactly one rebound per original wave, even when it killed several actors.
	# The rebound itself does not call after_burst: it cannot spawn recursively.
	for victim: Node3D in victims:
		if is_instance_valid(victim) and manager.health_of(victim).is_dead():
			manager.aoe(origin, radius, damage, {"tag": &"sloth_rebound", "proc_depth": 2, "damage_scaled": true})
			SlothWave.spawn(manager.player.get_parent(), origin - Vector3.UP * 0.8, radius, 0.65)
			break


func _consume_beat() -> bool:
	if not manager.has(HEAVY) or not _beat_ready:
		return false
	_beat_ready = false
	_beat_elapsed = 0.0
	return true


func _set_rest(enabled: bool) -> void:
	if enabled == _rest_active:
		return
	_rest_active = enabled
	if enabled:
		manager.set_modifier(&"sloth_stillness", {Stats.DAMAGE_TAKEN: {"mul": value(STILLNESS, "damage_taken", 0.6)}, Stats.RELOAD_SPEED: {"mul": value(STILLNESS, "reload_speed", 2.0)}})
	else:
		manager.remove_modifier(&"sloth_stillness")


func _set_field(enabled: bool) -> void:
	if enabled == _field_active:
		return
	_field_active = enabled
	if enabled:
		manager.set_modifier(FIELD_SOURCE, {Stats.DASH_RECHARGE: {"mul": value(FIELD, "dash_recharge", 1.5)}})
	else:
		manager.remove_modifier(FIELD_SOURCE)
	for victim: Node3D in manager.enemies():
		if enabled:
			manager.set_status(victim, FIELD_SOURCE, 0.0, 1.0, value(FIELD, "world_scale", 0.8))
		else:
			manager.clear_status(victim, FIELD_SOURCE)
	for projectile: Node3D in manager.projectiles():
		if _hostile_projectile(projectile):
			manager.set_projectile_scale(projectile, FIELD_SOURCE, value(FIELD, "world_scale", 0.8) if enabled else 1.0)


func _modify_projectile(projectile: Node) -> void:
	if not _hostile_projectile(projectile):
		return
	if _field_active:
		manager.set_projectile_scale(projectile, FIELD_SOURCE, value(FIELD, "world_scale", 0.8))
	if manager.has(DROWSY) and owner.has_latency(projectile.get("source")):
		_drowsy_applied = true
		manager.set_projectile_scale(projectile, &"sloth_drowsy", value(DROWSY, "projectile_scale", 0.5))


func _hostile_projectile(projectile: Node) -> bool:
	return is_instance_valid(projectile) and "source" in projectile and is_instance_valid(projectile.get("source")) and manager.is_enemy(projectile.get("source"))


func _record_kill(ctx: Dictionary) -> void:
	if not manager.has(ETERNAL) or ctx.get("source") != manager.player:
		return
	var victim := ctx.get("enemy") as Node3D
	var sloth_kill: bool = ctx.get("tag") in [&"sloth_burst", &"sloth_rebound"]
	var elite: bool = is_instance_valid(victim) and (("is_boss" in victim and bool(victim.get("is_boss"))) or bool(victim.get_meta(&"elite", false)))
	_kills.append(_time)
	var window := value(ETERNAL, "kill_window", 3.0)
	while not _kills.is_empty() and _time - _kills.front() > window:
		_kills.pop_front()
	if (sloth_kill and elite) or _kills.size() >= int(value(ETERNAL, "kill_count", 3.0)):
		_kills.clear()
		_freeze_remaining = value(ETERNAL, "freeze_duration", 2.0)
		manager.freeze_world(_freeze_remaining, &"sloth_eternal")
		if is_instance_valid(_visual):
			_visual.freeze_pulse()


func cleanup() -> void:
	manager.clear_world_freeze(&"sloth_eternal")
	_set_rest(false)
	_set_field(false)
	for victim: Node3D in manager.enemies():
		manager.clear_status(victim, &"sloth_sleep")
	for projectile: Node3D in manager.projectiles():
		manager.set_projectile_scale(projectile, &"sloth_drowsy", 1.0)
	_kills.clear()
	_reload_clean = false
	_reload_empty = false
	if is_instance_valid(_visual):
		_visual.queue_free()
	_visual = null
	owner = null
	manager = null
