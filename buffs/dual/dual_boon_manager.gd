class_name DualBoonManager
extends BoonEffect
## Six pair synergies. Eligibility always comes from currently equipped cores.
## Family effects own statuses; this adapter composes their public services.

const PAIRS := {
	"dual_slumber_magma": [0, 2], "dual_tearful_panic": [1, 3],
	"dual_spiteful_deluge": [2, 3], "dual_frozen_paranoia": [0, 1],
	"dual_suffocating_mire": [0, 3], "dual_hysterical_rampage": [1, 2],
}
const GAZE := &"dual_gaze"
const MIRE := &"dual_mire"
const MAGMA := &"dual_magma_timing"
var _gazed: Dictionary = {}
var _mire_nodes: Array[MeshInstance3D] = []
var _pools: Array[Dictionary] = []
var _known: Dictionary = {}
static var _scripts: Dictionary = {}


static func install(owner_manager: BoonManager) -> void:
	var callback := apply_privileged_status.bind(owner_manager)
	if not owner_manager.event_dispatched.is_connected(callback):
		owner_manager.event_dispatched.connect(callback)


static func has_pair(owner_manager: BoonManager, first: int, second: int) -> bool:
	var sins: Array[int] = []
	for i in 3:
		var card: BoonData = owner_manager.slots[i].data
		if card != null and card.core and not sins.has(card.sin):
			sins.append(card.sin)
	return sins.has(first) and sins.has(second)


static func family(owner_manager: BoonManager, name: String) -> BoonEffect:
	if not _scripts.has(name):
		var path := "res://buffs/effects/%s_effect.gd" % name
		_scripts[name] = load(path) as Script if ResourceLoader.exists(path) else null
	return owner_manager.effect_for(_scripts[name]) if _scripts[name] != null else null


static func apply_privileged_status(event: StringName, context: Dictionary, owner_manager: BoonManager) -> void:
	if event not in [&"hit_before", &"enemy_damage_before"] or context.get("privileged_applied", false):
		return
	if context.get("source") != owner_manager.player:
		return
	if owner_manager.all_equipped().is_empty():
		return
	var target := context.get("target") as Node3D
	if not is_instance_valid(target) or not owner_manager.is_enemy(target):
		return
	var count := 0
	for item in [["sloth", "has_latency"], ["fear", "has_panic"], ["wrath", "has_spite"], ["sorrow", "erosion_layers"]]:
		var effect := family(owner_manager, item[0])
		if effect != null and bool(effect.call(item[1], target)):
			count += 1
	if count >= 2:
		context.damage *= 1.4
		context.privileged_applied = true


func setup(owner_manager: BoonManager) -> void:
	super.setup(owner_manager)
	manager.changed.connect(_loadout_changed)
	_loadout_changed()


func _active(id: String) -> bool:
	return manager.has(id) and has_pair(manager, PAIRS[id][0], PAIRS[id][1])


func _parameter(id: String, key: String, fallback: float) -> float:
	var card := manager.get_boon(id)
	return float(card.parameters.get(key, fallback)) if card != null else fallback


func _loadout_changed() -> void:
	if _active("dual_slumber_magma"):
		var speed := _parameter("dual_slumber_magma", "attack_speed", 0.8)
		manager.set_modifier(MAGMA, {Stats.FIRE_RATE: {"mul": speed}, Stats.MELEE_SPEED: {"mul": speed}})
	else:
		manager.remove_modifier(MAGMA)
	for id: String in PAIRS:
		if manager.has(id) and not _known.has(id):
			_known[id] = true
			_prismatic_feedback(manager.player.global_position + Vector3.UP)
			var audio := AudioStreamPlayer3D.new()
			audio.stream = ProceduralAudio.generate("clock_perfect")
			audio.pitch_scale = 1.35
			audio.volume_db = -12
			manager.player.add_child(audio)
			audio.play()
			audio.finished.connect(audio.queue_free)


func on_event(event: StringName, context: Dictionary) -> void:
	if int(context.get("proc_depth", 0)) > 3:
		return
	if event == &"wall_slam":
		_wall_synergies(context)
		return
	if context.get("dual_chain", false):
		return
	match event:
		&"sloth_burst":
			if _active("dual_slumber_magma"):
				_slumber_magma(context)
		&"fear_flaw_broken":
			if _active("dual_tearful_panic"):
				_tearful_panic(context)
			if _active("dual_hysterical_rampage"):
				var wrath := family(manager, "wrath")
				var target := context.get("target") as Node3D
				if wrath != null and is_instance_valid(target):
					wrath.call("knock_toward_wall", target, _parameter("dual_hysterical_rampage", "launch_strength", 3.5), _child_context(context))
		&"sorrow_deferred_tick":
			if _active("dual_spiteful_deluge"):
				var amount := float(context.get("damage", 0.0)) * _parameter("dual_spiteful_deluge", "retaliation_multiplier", 2.0)
				if amount > 0.0:
					_radial_spikes(manager.player.global_position + Vector3.UP, _parameter("dual_spiteful_deluge", "retaliation_radius", 6.0), amount, context, true)
		&"sorrow_tear_broken":
			if _active("dual_spiteful_deluge"):
				_radial_spikes(context.position, _parameter("dual_spiteful_deluge", "tear_radius", 5.0), _parameter("dual_spiteful_deluge", "tear_damage", 90.0), context)
		&"sorrow_tear_spawn_before":
			if _active("dual_suffocating_mire") and context.get("reason", &"") == &"death" and _in_mire(context.position):
				context.count = int(context.get("count", 1)) * 2


func _child_context(context: Dictionary) -> Dictionary:
	var child := context.duplicate()
	for key in ["target", "health", "hitbox", "body_part", "critical", "critical_multiplier",
		"critical_damage_scale", "crit_chance_add", "fear_flaw", "fear_critical", "cancelled",
		"dealt", "killed", "skip_damage_multiplier", "original_damage", "absorbed", "resolved_damage",
		"skip_impact", "damage", "privileged_applied", "direction", "position", "fear_flaw_position",
		"fear_execution", "fear_guaranteed_critical", "harmless_team", "allow_friendly_fire"]:
		child.erase(key)
	child.source = manager.player
	child.kind = &"proc"
	child.body_part = Hitbox.BodyPart.BODY
	child.critical = false
	child.cancelled = false
	child.proc_depth = int(context.get("proc_depth", 0)) + 1
	child.tag = &"dual"
	child.dual_chain = true
	child.damage_scaled = false
	return child


func _slumber_magma(context: Dictionary) -> void:
	var sloth := family(manager, "sloth")
	var wrath := family(manager, "wrath")
	if sloth == null or wrath == null:
		return
	var enemies: Array[Node3D] = []
	enemies.assign(sloth.call("latent_enemies"))
	var bursting := context.get("target") as Node3D
	if is_instance_valid(bursting) and not enemies.has(bursting):
		enemies.append(bursting)
	for enemy in enemies:
		var child := _child_context(context)
		child.dual_slumber_slam = true
		wrath.call("knock_toward_wall", enemy, _parameter("dual_slumber_magma", "launch_strength", 3.0), child)
	_prismatic_feedback(context.position)


func _wall_synergies(context: Dictionary) -> void:
	# Existing architecture is static. The slam shatters a local crystal effect,
	# retaining the level's collision; enemy collisions/air ruptures do not count.
	if not context.get("wall_impact", false):
		return
	if _active("dual_slumber_magma") and context.get("dual_slumber_slam", false):
		_radial_spikes(context.position, _parameter("dual_slumber_magma", "lava_radius", 4.0), _parameter("dual_slumber_magma", "lava_damage", 45.0), context)
	if _active("dual_hysterical_rampage") and not context.get("dual_flaw_cascade", false):
		var fear := family(manager, "fear")
		if fear != null:
			var child := _child_context(context)
			child.dual_flaw_cascade = true
			fear.call("detonate_all_flaws", child)
			_prismatic_feedback(context.position)


func _tearful_panic(context: Dictionary) -> void:
	var sorrow := family(manager, "sorrow")
	if sorrow == null:
		return
	var center: Vector3 = context.position
	var radius := _parameter("dual_tearful_panic", "pool_radius", 5.0)
	for enemy in manager.targets_in_radius(center, radius):
		sorrow.call("add_erosion", enemy, 5, _child_context(context))
		var direction := center - (enemy.global_position + Vector3.UP)
		direction.y = 0.0
		if direction.length_squared() > 0.01 and enemy.has_method("apply_impact"):
			enemy.call("apply_impact", direction.normalized(), minf(direction.length() * 4.0, _parameter("dual_tearful_panic", "pull_speed", 12.0)), 0.25)
	var pool := _disc(radius, Color(0.18, 0.11, 0.38, 0.65))
	var ground := manager.player.get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(center + Vector3.UP * 0.2, center + Vector3.DOWN * 30.0, CollisionLayers.WORLD))
	pool.global_position = (ground.position if not ground.is_empty() else center) + Vector3.UP * 0.03
	_pools.append({"node": pool, "remaining": _parameter("dual_tearful_panic", "pool_duration", 2.0)})
	_prismatic_feedback(center)


func _radial_spikes(center: Vector3, radius: float, damage: float, context: Dictionary, settled_damage := false) -> void:
	var child := _child_context(context)
	child.damage_scaled = settled_damage
	manager.aoe(center, radius, damage, child)
	for i in 8:
		var angle := i * TAU / 8.0
		manager.feedback(center + Vector3(cos(angle), 0.0, sin(angle)) * radius * 0.6, Color("f26464"), 0.25)
		var spike := MeshInstance3D.new()
		var mesh := CylinderMesh.new()
		mesh.top_radius = 0.0
		mesh.bottom_radius = 0.2
		mesh.height = 1.1
		mesh.radial_segments = 4
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("400e17")
		material.emission_enabled = true
		material.emission = Color("e84942")
		material.emission_energy_multiplier = 0.3
		mesh.material = material
		spike.mesh = mesh
		manager.player.get_parent().add_child(spike)
		spike.global_position = center + Vector3(cos(angle) * radius * 0.6, -0.45, sin(angle) * radius * 0.6)
		_pools.append({"node": spike, "remaining": 0.6})


func tick(delta: float) -> void:
	_tick_gaze()
	_tick_mire()
	for i in range(_pools.size() - 1, -1, -1):
		_pools[i].remaining -= delta
		if _pools[i].remaining <= 0.0:
			if is_instance_valid(_pools[i].node):
				_pools[i].node.queue_free()
			_pools.remove_at(i)


func _tick_gaze() -> void:
	var fear := family(manager, "fear")
	var current: Dictionary = {}
	var aiming := bool(manager.player.call("is_aiming")) if manager.player.has_method("is_aiming") else false
	if _active("dual_frozen_paranoia") and (manager.player.velocity.length_squared() < 0.01 or aiming):
		var camera := manager.weapon.camera
		var forward := -camera.global_basis.z
		var cone := deg_to_rad(_parameter("dual_frozen_paranoia", "aim_half_angle_degrees", 8.0))
		for enemy in manager.enemies():
			var target_health := manager.health_of(enemy)
			var point := enemy.global_position + Vector3.UP
			if target_health == null or target_health.is_dead() or not manager.is_enemy(enemy):
				continue
			if forward.angle_to(point - camera.global_position) <= cone and manager.line_clear(camera.global_position, point):
				current[enemy.get_instance_id()] = weakref(enemy)
				manager.set_status(enemy, GAZE, 0.15, _parameter("dual_frozen_paranoia", "move_scale", 0.2))
				if fear != null:
					fear.call("set_flaw_area_multiplier", enemy, GAZE, _parameter("dual_frozen_paranoia", "flaw_area", 3.0))
	for id in _gazed:
		if not current.has(id):
			var enemy = _gazed[id].get_ref()
			if is_instance_valid(enemy):
				manager.clear_status(enemy, GAZE)
				if fear != null:
					fear.call("set_flaw_area_multiplier", enemy, GAZE, 1.0)
	_gazed = current


func _regions() -> Array[Dictionary]:
	var regions: Array[Dictionary] = []
	if not _active("dual_suffocating_mire"):
		return regions
	var sloth := family(manager, "sloth")
	var sorrow := family(manager, "sorrow")
	if sloth != null:
		regions.append_array(sloth.call("aura_regions"))
	if sorrow != null:
		regions.append_array(sorrow.call("water_regions"))
	return regions


func _inside(point: Vector3, region: Dictionary) -> bool:
	var difference: Vector3 = point - region.center
	return absf(difference.y) <= 2.5 and Vector2(difference.x, difference.z).length_squared() <= float(region.radius) * float(region.radius)


func _in_mire(point: Vector3) -> bool:
	for region in _regions():
		if _inside(point, region) and manager.line_clear(region.center + Vector3.UP * 0.15, point + Vector3.UP * 0.1):
			return true
	return false


func _tick_mire() -> void:
	var regions := _regions()
	_mire_nodes = _mire_nodes.filter(func(node): return is_instance_valid(node))
	while _mire_nodes.size() > regions.size():
		var node := _mire_nodes.pop_back() as MeshInstance3D
		if is_instance_valid(node):
			node.queue_free()
	for i in regions.size():
		if i >= _mire_nodes.size():
			_mire_nodes.append(_disc(float(regions[i].radius), Color(0.06, 0.1, 0.16, 0.62)))
		var node := _mire_nodes[i]
		node.global_position = regions[i].center + Vector3.UP * 0.025
		(node.mesh as CylinderMesh).top_radius = float(regions[i].radius)
		(node.mesh as CylinderMesh).bottom_radius = float(regions[i].radius)
	if regions.is_empty():
		return
	for enemy in manager.enemies():
		if manager.is_enemy(enemy) and _in_mire(enemy.global_position + Vector3.UP):
			manager.set_status(enemy, MIRE, 0.15, 1.0, 1.0, false, 1.0, false, _parameter("dual_suffocating_mire", "attack_scale", 0.5))
	for projectile in manager.projectiles():
		if manager.is_enemy(projectile.get("source")) and _in_mire(projectile.global_position):
			manager.set_projectile_scale(projectile, MIRE, _parameter("dual_suffocating_mire", "projectile_scale", 0.05), 0.15)


func _disc(radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.035
	mesh.radial_segments = 16
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = color
	mesh.material = material
	node.mesh = mesh
	manager.player.get_parent().add_child(node)
	return node


func _prismatic_feedback(position: Vector3) -> void:
	for i in 4:
		manager.feedback(position + Vector3(cos(i * PI * 0.5), 0.0, sin(i * PI * 0.5)) * 0.35, BoonPalette.COLORS[i], 0.16)


func cleanup() -> void:
	if manager.changed.is_connected(_loadout_changed):
		manager.changed.disconnect(_loadout_changed)
	manager.remove_modifier(MAGMA)
	var fear := family(manager, "fear")
	for enemy in manager.enemies():
		manager.clear_status(enemy, GAZE)
		manager.clear_status(enemy, MIRE)
		if fear != null:
			fear.call("set_flaw_area_multiplier", enemy, GAZE, 1.0)
	_mire_nodes = _mire_nodes.filter(func(node): return is_instance_valid(node))
	for node in _mire_nodes:
		if is_instance_valid(node):
			node.queue_free()
	for entry in _pools:
		if is_instance_valid(entry.node):
			entry.node.queue_free()
	_mire_nodes.clear()
	_pools.clear()
	_gazed.clear()
