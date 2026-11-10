class_name WrathRicochet
extends Projectile
var bounces_left := 1
var bounce_count := 0

static func launch(parent: Node3D, from: Vector3, direction: Vector3, owner_node: Node, amount := 10.0, speed_value := 18.0) -> WrathRicochet:
	var bullet := WrathRicochet.new()
	bullet.source = owner_node
	bullet.damage = amount
	bullet.speed = speed_value
	bullet.max_distance = 50.0
	bullet.tint = Color(1.0, 0.12, 0.035)
	if owner_node is CollisionObject3D:
		bullet.exclude.append(owner_node.get_rid())
	for box in owner_node.find_children("*", "Hitbox", true, false):
		bullet.exclude.append((box as Hitbox).get_rid())
	parent.add_child(bullet)
	bullet.global_position = from
	bullet.look_at(from + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	Events.projectile_registered.emit(bullet)
	return bullet

func _physics_process(delta: float) -> void:
	if boon_time_scale <= 0.0:
		return
	if bounces_left > 0:
		var from := global_position
		var direction := -global_basis.z
		var query := PhysicsRayQueryParameters3D.create(from, from + direction * speed * delta * boon_time_scale, MASK, exclude)
		query.collide_with_areas = true
		query.hit_from_inside = true
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		# A nearer hitbox or blade must resolve before a wall in the same sweep.
		if not hit.is_empty() and hit.collider is CollisionObject3D and (hit.collider as CollisionObject3D).collision_layer & CollisionLayers.WORLD:
			global_position = hit.position + hit.normal * 0.04
			direction = direction.bounce(hit.normal).normalized()
			look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
			bounces_left -= 1
			bounce_count += 1
	super._physics_process(delta)
