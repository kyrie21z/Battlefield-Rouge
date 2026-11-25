class_name WrathProjectile
extends Projectile
## A real moving gun projectile with one WORLD ricochet. Its impact uses the
## same mutable pipeline as hitscan and keeps depth zero for the natural shot.
var manager: BoonManager
var weapon: Weapon
var ricochets_left := 1
var ricochet_multiplier := 1.6
var _base_damage := 0.0

static func launch(owner_manager: BoonManager, shot: Dictionary) -> WrathProjectile:
	var bullet := WrathProjectile.new()
	bullet.manager = owner_manager
	bullet.weapon = owner_manager.weapon
	bullet.source = owner_manager.player
	bullet.speed = 90.0
	bullet.damage = bullet.weapon.data.damage * owner_manager.stats.get_value(Stats.DAMAGE) * float(shot.get("damage_multiplier", 1.0))
	bullet._base_damage = bullet.damage
	bullet.max_distance = bullet.weapon.data.max_range
	bullet.tint = Projectile.realm_tint(&"wrath")
	bullet._collect_exclusions(owner_manager.player)
	owner_manager.player.get_parent().add_child(bullet)
	# shot.origin is the camera (eye) position for a real shot, so the visible
	# round must leave the model muzzle — but still converge on what the crosshair
	# aims at. Synthetic shot dictionaries (fixtures, dual-boon replays) carry their
	# own origin that is unrelated to the camera, so those are used verbatim.
	var muzzle: Vector3 = shot.origin
	var shot_camera: Camera3D = bullet.weapon.camera
	if is_instance_valid(shot_camera) and shot.origin.distance_to(shot_camera.global_position) < 1.5:
		muzzle = bullet.weapon._muzzle_position(shot.origin)
	var aim_point: Vector3 = shot.origin + (shot.direction as Vector3).normalized() * bullet.max_distance
	bullet.global_position = muzzle
	var direction := (aim_point - muzzle).normalized()
	bullet.look_at(bullet.global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	Events.projectile_registered.emit(bullet)
	return bullet

func _physics_process(delta: float) -> void:
	if not is_instance_valid(manager):
		queue_free()
		return
	var distance := speed * delta * boon_time_scale
	if distance <= 0.0:
		return
	var direction := -global_basis.z
	var from := global_position
	var to := from + direction * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD | CollisionLayers.HITBOXES, exclude)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		global_position = to
		_travelled += distance
	else:
		_travelled += from.distance_to(hit.position)
		if hit.collider is Hitbox:
			var box := hit.collider as Hitbox
			var amount := damage * weapon._falloff(_travelled)
			var ctx := {"source": source, "target": box.health.get_parent(), "health": box.health,
				"hitbox": box, "position": hit.position, "direction": direction, "damage": amount,
				"base_damage": amount, "body_part": box.body_part, "kind": &"gun", "tag": &"wrath_gun",
				"proc_depth": 0, "critical": false, "critical_multiplier": 1.0, "cancelled": false,
				"damage_scaled": true}
			manager.dispatch(&"hit_before", ctx)
			var hp := box.health.health
			var dealt := 0.0 if ctx.cancelled else box.apply_hit_at(maxf(ctx.damage, 0.0), source, hit.position, direction, true, ctx)
			ctx.dealt = minf(dealt, hp)
			ctx.killed = box.health.is_dead()
			manager.dispatch(&"hit_after", ctx)
			if dealt > 0.0:
				weapon.hit_landed.emit(box.body_part == Hitbox.BodyPart.HEAD, ctx.killed)
			impacted.emit(box, hit.position)
			queue_free()
			return
		if ricochets_left > 0:
			ricochets_left -= 1
			damage *= ricochet_multiplier
			direction = direction.bounce(hit.normal).normalized()
			global_position = hit.position + hit.normal * 0.025
			look_at(global_position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
			manager.feedback(hit.position, tint, 0.16)
		else:
			manager.feedback(hit.position, tint, 0.2)
			queue_free()
	if _travelled >= max_distance:
		queue_free()
