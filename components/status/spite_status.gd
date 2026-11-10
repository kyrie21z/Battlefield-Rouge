class_name SpiteStatus
extends Node
## Reads CharacterBody's actual Jolt contacts after its motion step. A floor
## never qualifies as a wall, and displacement is never synthesized by teleport.
signal slammed(context: Dictionary)
var actor: CharacterBody3D
var remaining := 0.0
var threshold := 6.0
var legendary := false
var context: Dictionary = {}
var _before_velocity := Vector3.ZERO
var _previous_mask := 0
var _elapsed := 0.0
var _resolved := false

func _init() -> void:
	process_physics_priority = 20

func arm(body: CharacterBody3D, direction: Vector3, force: float, duration: float, details: Dictionary) -> void:
	if "ordinary_impacts_enabled" in body and not body.ordinary_impacts_enabled:
		cancel()
		return
	if actor == null:
		actor = body
		_previous_mask = actor.collision_mask
	actor.collision_mask |= CollisionLayers.ENEMIES
	remaining = maxf(duration, 0.01)
	_elapsed = 0.0
	_resolved = false
	_before_velocity = Vector3(direction.x, 0.0, direction.z).normalized() * force
	if "boon_time_scale" in actor:
		_before_velocity *= actor.boon_time_scale * actor.boon_movement_scale
	context = details.duplicate()
	actor.apply_impact(direction, force, duration)

func is_active() -> bool:
	if _resolved or remaining <= 0.0 or not is_instance_valid(actor):
		return false
	var health := actor.get_node_or_null("Health") as Health
	return health == null or not health.is_dead()

func _physics_process(delta: float) -> void:
	if is_instance_valid(actor) and "ordinary_impacts_enabled" in actor and not actor.ordinary_impacts_enabled:
		cancel()
		return
	if not is_active():
		if remaining > 0.0:
			cancel()
		return
	if "boon_time_scale" in actor and (actor.boon_time_scale <= 0.0 or actor.boon_stunned):
		return
	_elapsed += delta
	remaining -= delta
	for index in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(index)
		var other := collision.get_collider() as Node
		var normal := collision.get_normal()
		if absf(normal.y) >= 0.5:
			continue
		var world: bool = other is CollisionObject3D and (other.collision_layer & CollisionLayers.WORLD) != 0
		var other_enemy := other is CharacterBody3D and other != actor and other.has_node("Health")
		if not world and not other_enemy:
			continue
		var other_velocity: Vector3 = other.get_real_velocity() if other_enemy else Vector3.ZERO
		var relative := _before_velocity - other_velocity
		if -relative.dot(normal) <= threshold:
			continue
		_resolve(collision.get_position(), normal, other, false)
		return
	# Legendary rupture still requires a real moving impulse, after travel time.
	if legendary and _elapsed >= 0.16 and _before_velocity.length() > threshold:
		_resolve(actor.global_position + Vector3.UP * 0.1, Vector3.UP, null, true)
		return
	_before_velocity = actor.get_real_velocity()
	if remaining <= 0.0:
		cancel()

func rupture_if_moving() -> void:
	if is_active() and legendary and _elapsed >= 0.05 and _before_velocity.length() > threshold:
		_resolve(actor.global_position + Vector3.UP * 0.1, Vector3.UP, null, true)

func _resolve(point: Vector3, normal: Vector3, other: Node, rupture: bool) -> void:
	_resolved = true
	var result := context.duplicate()
	result.merge({"target": actor, "position": point, "normal": normal,
		"collider": other, "relative_speed": _before_velocity.length(), "rupture": rupture}, true)
	_restore_mask()
	slammed.emit(result)

func cancel() -> void:
	remaining = 0.0
	_resolved = true
	_restore_mask()

func _restore_mask() -> void:
	if is_instance_valid(actor):
		actor.collision_mask = _previous_mask

func _exit_tree() -> void:
	_restore_mask()
