class_name WrathTraits
extends RefCounted
const SHRAPNEL := "wrath_shrapnel"
const RETALIATION := "wrath_retaliation"
const DESPERATION := "wrath_desperation"
const RELOAD := "wrath_reload"
const CRUSHER := "wrath_crusher"
const CHAIN := "wrath_chain"
const BREAKER := "wrath_breaker"
const FRENZY := "wrath_frenzy"
const LEGENDARY := "wrath_cataclysm"
var _host: WeakRef
var host: WrathBoons:
	get:
		return _host.get_ref() as WrathBoons
var manager: BoonManager
var empowered_magazine := false
var frenzy_stacks := 0
var frenzy_left := 0.0
var _rupturing := false
var _desperation_multiplier := -1.0
var _owned_nodes: Array[Node] = []

func _init(owner_effect: WrathBoons) -> void:
	_host = weakref(owner_effect)
	manager = owner_effect.manager

func on_event(event: StringName, ctx: Dictionary) -> void:
	match event:
		&"shoot_before":
			if empowered_magazine and manager.has(RELOAD):
				ctx.damage_multiplier *= 2.0
		&"reload_started":
			empowered_magazine = false
		&"damage_after":
			if manager.health.is_dead() or float(ctx.get("resolved_damage", 0.0)) <= 0.0:
				return
			if manager.has(RELOAD) and manager.weapon.is_reloading() and manager.weapon._reload_empty:
				empowered_magazine = manager.weapon.complete_reload()
			if manager.has(RETALIATION) and manager.is_enemy(ctx.get("source")):
				manager.set_modifier(&"wrath_retaliation", {Stats.DAMAGE: {"mul": 1.4}}, 3.0)
				for enemy in manager.targets_in_radius(manager.player.global_position + Vector3.UP, 4.0):
					host.knock(enemy, enemy.global_position - manager.player.global_position, 3.0,
						{"kind": &"retaliation", "proc_depth": 0})
				manager.feedback(manager.player.global_position + Vector3.UP, WrathBoons.COLOR, 1.1)
		&"enemy_killed":
			if manager.has(FRENZY) and ctx.get("source") == manager.player:
				frenzy_stacks = mini(5, frenzy_stacks + 1)
				frenzy_left = 4.0
				_refresh_frenzy()
	_refresh_desperation()

func tick(delta: float) -> void:
	_refresh_desperation()
	if frenzy_left > 0.0:
		frenzy_left -= delta
	if not manager.has(FRENZY) or frenzy_left <= 0.0:
		frenzy_stacks = 0
		manager.remove_modifier(&"wrath_frenzy")
	if not manager.has(RETALIATION):
		manager.remove_modifier(&"wrath_retaliation")
	if not manager.has(RELOAD):
		empowered_magazine = false
	for node in _owned_nodes:
		if is_instance_valid(node) and node is WrathEmbers and not manager.has(CRUSHER):
			node.queue_free()
	_owned_nodes = _owned_nodes.filter(func(node): return is_instance_valid(node))

func _refresh_desperation() -> void:
	if not manager.has(DESPERATION) or manager.health.is_dead():
		manager.remove_modifier(&"wrath_desperation")
		_desperation_multiplier = -1.0
		return
	var ratio := manager.health.health / manager.health.max_health
	var bonus := 0.6 * clampf((1.0 - ratio) / 0.7, 0.0, 1.0)
	if not is_equal_approx(_desperation_multiplier, 1.0 + bonus):
		_desperation_multiplier = 1.0 + bonus
		manager.set_modifier(&"wrath_desperation", {Stats.DAMAGE: {"mul": _desperation_multiplier}})

func _refresh_frenzy() -> void:
	var boost := 1.0 + frenzy_stacks * 0.1
	manager.set_modifier(&"wrath_frenzy", {Stats.MOVE_SPEED: {"mul": boost}, Stats.MELEE_SPEED: {"mul": boost}, Stats.ARMOR: {"add": 1.0}})

func damage_multiplier() -> float:
	return 1.8 if manager.has(CRUSHER) else 1.0

func elite_force_scale() -> float:
	return 0.85 if manager.has(BREAKER) else 0.45

func full_pair_damage(ctx: Dictionary, target: Node) -> bool:
	return manager.has(CHAIN) and ctx.get("collider") == target and manager.is_enemy(target)

func before_slam(ctx: Dictionary) -> void:
	if not manager.has(BREAKER):
		return
	var health := manager.health_of(ctx.target)
	if health != null and health.break_shield() > 0.0:
		manager.apply_damage(ctx.target, float(ctx.damage) * 2.5, {"tag": &"wrath_shield_break", "proc_depth": ctx.proc_depth,
			"true_damage": true})
		ctx.shield_broken = true

func after_slam(ctx: Dictionary) -> void:
	var point: Vector3 = ctx.position
	var normal: Vector3 = ctx.normal
	var depth := int(ctx.proc_depth) + 1
	if manager.has(SHRAPNEL):
		var forward := Vector3(normal.x, 0.0, normal.z).normalized()
		if forward.length_squared() < 0.01:
			forward = Vector3.FORWARD
		for index in 5:
			var direction := forward.rotated(Vector3.UP, deg_to_rad(-80.0 + index * 40.0))
			_owned_nodes.append(WrathSpike.launch(manager, point + normal * 0.15, direction, depth))
	if manager.has(CRUSHER):
		_owned_nodes.append(WrathEmbers.create(manager, point, normal, depth))
	if manager.has(LEGENDARY):
		_ground_spike(ctx.target.global_position)
		if not _rupturing:
			_rupturing = true
			for status in host._spite.values():
				if is_instance_valid(status):
					status.rupture_if_moving()
			_rupturing = false

func _ground_spike(point: Vector3) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.55
	mesh.height = 1.8
	mesh.radial_segments = 6
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.04, 0.006, 0.004)
	material.roughness = 0.22
	material.emission_enabled = true
	material.emission = WrathBoons.COLOR
	material.emission_energy_multiplier = 0.8
	mesh.material = material
	visual.mesh = mesh
	manager.player.get_parent().add_child(visual)
	visual.global_position = point + Vector3.UP * 0.7
	visual.scale.y = 0.05
	var tween := visual.create_tween()
	tween.tween_property(visual, "scale:y", 1.0, 0.12)
	tween.tween_interval(0.25)
	tween.tween_property(visual, "scale", Vector3.ZERO, 0.25)
	tween.tween_callback(visual.queue_free)
	_owned_nodes.append(visual)

func cleanup() -> void:
	for source in [&"wrath_retaliation", &"wrath_desperation", &"wrath_frenzy"]:
		manager.remove_modifier(source)
	for node in _owned_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_owned_nodes.clear()
