class_name WrathBoons
extends BoonEffect
## Actual body impulses and swept projectiles implement the spatial Wrath kit.
const COLOR := Color(0.95, 0.16, 0.1)
const GUN := "wrath_gun_cannon"
const BLADE := "wrath_blade_sweep"
const DASH := "wrath_dash_ram"
const BASE_FORCE := 8.0
const SLAM_DAMAGE := 60.0
const SLAM_RADIUS := 3.0
var _spite: Dictionary = {}
var _dash_active := false
var _dash_previous := Vector3.ZERO
var _dash_hits: Dictionary = {}
var traits: WrathTraits
var _slam_fallback: AudioStreamPlayer3D

func setup(value: BoonManager) -> void:
	super.setup(value)
	traits = WrathTraits.new(self)

func on_event(event: StringName, ctx: Dictionary) -> void:
	traits.on_event(event, ctx)
	match event:
		&"shoot_before":
			if manager.has(GUN):
				ctx.cancel_primary = true
		&"shoot_fired":
			if manager.has(GUN):
				WrathProjectile.launch(manager, ctx)
		&"hit_after":
			if float(ctx.get("dealt", 0.0)) <= 0.0 or int(ctx.get("proc_depth", 0)) != 0:
				return
			if (ctx.kind == &"gun" and manager.has(GUN)) or (ctx.kind == &"blade" and manager.has(BLADE)):
				if ctx.kind == &"blade":
					ctx.skip_impact = true
				knock(ctx.target, ctx.direction, 2.5 if ctx.kind == &"gun" else 3.0, ctx)
		&"blade_struck":
			if manager.has(BLADE):
				_sweep_feedback(ctx.position, ctx.direction)
		&"dash_started":
			if manager.has(DASH):
				_dash_active = true
				_dash_previous = ctx.position
				_dash_hits.clear()
				manager.set_modifier(&"wrath_dash_armor", {Stats.ARMOR: {"add": 1.0}}, ctx.duration)
		&"dash_finished":
			if _dash_active:
				_dash_collision(ctx.position)
				_dash_active = false
				manager.remove_modifier(&"wrath_dash_armor")

func tick(delta: float) -> void:
	traits.tick(delta)
	if _dash_active:
		_dash_collision(manager.player.global_position)
	for id in _spite.keys():
		if not is_instance_valid(_spite[id]):
			_spite.erase(id)
		else:
			_spite[id].legendary = manager.has(WrathTraits.LEGENDARY)

func has_spite(enemy: Node) -> bool:
	return is_instance_valid(enemy) and _spite.has(enemy.get_instance_id()) and is_instance_valid(_spite[enemy.get_instance_id()]) and _spite[enemy.get_instance_id()].is_active()

func knock(enemy: Node, direction: Vector3, strength: float, context: Dictionary = {}) -> void:
	if not enemy is CharacterBody3D or not enemy.has_method("apply_impact") or not manager.is_enemy(enemy):
		return
	var health := manager.health_of(enemy)
	if health == null or health.is_dead() or int(context.get("proc_depth", 0)) >= 4:
		return
	var id := enemy.get_instance_id()
	var status: SpiteStatus
	if _spite.has(id) and is_instance_valid(_spite[id]):
		status = _spite[id]
	else:
		status = SpiteStatus.new()
		status.name = "SpiteStatus"
		enemy.add_child(status)
		status.slammed.connect(_wall_slam)
		_spite[id] = status
	var force := BASE_FORCE * maxf(strength, 1.0)
	if "is_boss" in enemy and enemy.is_boss:
		force *= traits.elite_force_scale()
	var ctx := context.duplicate()
	ctx.proc_depth = int(context.get("proc_depth", 0)) + 1
	status.legendary = manager.has(WrathTraits.LEGENDARY)
	status.arm(enemy, direction, force, 0.9, ctx)
	manager.feedback(enemy.global_position + Vector3.UP, COLOR, 0.3)

## Used by dual boons: find the nearest reachable horizontal wall, excluding
## floors/ceilings. Without one, push away from the player using a real impulse.
func knock_toward_wall(enemy: Node, strength: float, context: Dictionary = {}) -> void:
	if not enemy is Node3D:
		return
	var origin: Vector3 = enemy.global_position + Vector3.UP
	var best := INF
	var direction := Vector3.ZERO
	var space: PhysicsDirectSpaceState3D = enemy.get_world_3d().direct_space_state
	for index in 16:
		var ray := Vector3(sin(index * TAU / 16.0), 0.0, cos(index * TAU / 16.0))
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(origin, origin + ray * 14.0, CollisionLayers.WORLD))
		if not hit.is_empty() and absf(hit.normal.y) < 0.5:
			var distance: float = origin.distance_to(hit.position)
			if distance < best:
				best = distance
				direction = ray
	if direction == Vector3.ZERO:
		direction = context.get("direction", enemy.global_position - manager.player.global_position)
		direction.y = 0.0
		if direction.length_squared() < 0.001:
			direction = Vector3.FORWARD
	knock(enemy, direction.normalized(), strength, context)

func _wall_slam(ctx: Dictionary) -> void:
	var enemy: Node3D = ctx.target
	if not is_instance_valid(enemy):
		return
	var damage := SLAM_DAMAGE * traits.damage_multiplier()
	var depth := int(ctx.get("proc_depth", 1))
	var point: Vector3 = ctx.position
	var origin := enemy.global_position + Vector3.UP
	ctx.damage = damage
	ctx.proc_depth = depth
	traits.before_slam(ctx)
	# The target itself receives a full body hit; nearby unique Health owners
	# are resolved through the same wall-aware query as other boons.
	manager.apply_damage(enemy, damage, {"tag": &"wrath_slam", "proc_depth": depth})
	for other in manager.targets_in_radius(origin, SLAM_RADIUS):
		if other != enemy:
			var pair := traits.full_pair_damage(ctx, other)
			manager.apply_damage(other, damage if pair else damage * 0.5, {"tag": &"wrath_slam", "proc_depth": depth})
			if pair and not manager.health_of(other).is_dead():
				manager.set_status(other, &"wrath_chain", 0.8, 1.0, 1.0, true)
	if not manager.health_of(enemy).is_dead():
		manager.set_status(enemy, &"wrath_slam", 0.8, 1.0, 1.0, true)
	# A blade knock into a real wall produces its distinct second eruption.
	if ctx.get("kind", &"") == &"blade" and not ctx.get("rupture", false):
		manager.aoe(origin, 3.6, 30.0, {"tag": &"wrath_blade_blast", "proc_depth": depth + 1})
	manager.feedback(origin, COLOR, 1.0)
	for index in 3:
		var offset := Vector3(cos(index * TAU / 3.0), 0.5, sin(index * TAU / 3.0))
		manager.feedback(point + offset * 0.5, COLOR.lightened(0.15), 0.12)
	var collider: Node = ctx.get("collider")
	var wall_impact: bool = is_instance_valid(collider) and collider is CollisionObject3D and (collider.collision_layer & CollisionLayers.WORLD) != 0
	ctx.merge({"damage": damage, "proc_depth": depth, "wall_broken": false, "wall_impact": wall_impact}, true)
	traits.after_slam(ctx)
	manager.dispatch(&"wall_slam", ctx)
	# Event consumers mark this same context only after effects have finished.
	_play_slam_fallback.call_deferred(ctx)

func _dash_collision(position: Vector3) -> void:
	var from := _dash_previous + Vector3.UP
	var to := position + Vector3.UP
	var length := from.distance_to(to)
	for enemy in manager.targets_in_radius((from + to) * 0.5, length * 0.5 + 1.5):
		var id := enemy.get_instance_id()
		if _dash_hits.has(id):
			continue
		var point := enemy.global_position + Vector3.UP
		var near := Geometry3D.get_closest_point_to_segment(point, from, to)
		if point.distance_to(near) <= 1.3:
			_dash_hits[id] = true
			knock_toward_wall(enemy, 3.0, {"kind": &"dash", "proc_depth": 0, "direction": to - from})
	_dash_previous = position

func _sweep_feedback(origin: Vector3, forward: Vector3) -> void:
	for index in 7:
		var direction := forward.rotated(Vector3.UP, lerpf(-0.9, 0.9, index / 6.0))
		manager.feedback(origin + direction * 1.1, COLOR, 0.09)

func _play_slam_fallback(ctx: Dictionary) -> void:
	if bool(ctx.get("wrath_wall_audio_managed", false)) or not is_instance_valid(manager):
		return
	if not manager.is_inside_tree() or manager.is_queued_for_deletion() or manager.get_tree().paused:
		return
	if not is_instance_valid(manager.player) or manager.player.is_queued_for_deletion() or not manager.player.is_inside_tree():
		return
	if not is_instance_valid(manager.health) or manager.health.is_dead() or manager.effect_for(get_script()) != self:
		return
	# Legacy combat benches have no RealmAudioDirector. Keep one bounded voice.
	if not is_instance_valid(_slam_fallback):
		_slam_fallback = AudioStreamPlayer3D.new()
		_slam_fallback.name = "WrathWallFallback"
		_slam_fallback.process_mode = Node.PROCESS_MODE_PAUSABLE
		_slam_fallback.stream = ProceduralAudio.generate("clock_break")
		_slam_fallback.volume_db = -8.0
		manager.player.get_parent().add_child(_slam_fallback)
	_slam_fallback.global_position = ctx.position
	_slam_fallback.play()

func cleanup() -> void:
	if is_instance_valid(_slam_fallback):
		_slam_fallback.stop()
		_slam_fallback.queue_free()
	if traits != null:
		traits.cleanup()
	_dash_active = false
	manager.remove_modifier(&"wrath_dash_armor")
	for status in _spite.values():
		if is_instance_valid(status):
			status.cancel()
			status.queue_free()
	_spite.clear()
