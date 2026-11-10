class_name FearRealmEnemy
extends Enemy
## Actual gaze cancellation, collision-checked blink and a warned physical pounce.
enum Variant { WATCHER, TREMBLER, FALLER }
@export_enum("Watcher", "Trembler", "Faller") var variant := 0
@export var warnings_enabled := true:
	set(value):
		warnings_enabled = value
		if not value and is_instance_valid(_line):
			_line.hide()
		if not value and is_instance_valid(visual):
			visual.set_cast(0.0)
var arena: Node3D
var visual: FearRealmVisual
var attack_elapsed := -1.0
var attack_cooldown := 0.6
var locked_direction := Vector3.FORWARD
var gaze_progress := 0.0
var gaze_interrupts := 0
var shots_fired := 0
var blink_count := 0
var pounce_hits := 0
var _pounce_hit := false
var _elapsed := 0.0
var _line: MeshInstance3D
var _line_mesh: CylinderMesh
var _impact_point := Vector3.INF
var _impact_direction := Vector3.FORWARD

func _enter_tree() -> void:
	($Model as FearRealmVisual).configure(variant)

func _ready() -> void:
	visual = $Model as FearRealmVisual
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS
	Events.enemy_registered.emit(self)
	health.max_health = [65.0, 85.0, 115.0][variant]
	health.health = health.max_health
	run_speed = [0.0, 3.4, 4.2][variant]
	eye_height = [2.1, 1.6, 0.75][variant]
	$HeadHitbox.position.y = eye_height
	$TorsoHitbox.position.y = [1.35, 0.94, 0.65][variant]
	_hitbox_rids.append(get_rid())
	for child in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((child as Hitbox).get_rid())
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_line = MeshInstance3D.new()
	_line_mesh = CylinderMesh.new()
	_line_mesh.top_radius = 0.009
	_line_mesh.bottom_radius = 0.009
	_line_mesh.radial_segments = 5
	_line.mesh = _line_mesh
	var red := StandardMaterial3D.new()
	red.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	red.albedo_color = Color(1.0, 0.06, 0.14)
	red.emission_enabled = true
	red.emission = red.albedo_color
	red.emission_energy_multiplier = 2.0
	_line.material_override = red
	add_child(_line)
	_line.hide()

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint], p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target, p_cover_points, p_firing_board)
	state = State.CHASE

func begin_hunt() -> void:
	if state != State.DEAD:
		state = State.CHASE

func begin_retreat(goal: Vector3, timeout: float) -> void:
	attack_elapsed = -1.0
	_line.hide()
	super.begin_retreat(goal, timeout)

func _physics_process(delta: float) -> void:
	if get_tree().paused or state == State.DEAD or boon_time_scale <= 0.0 or boon_stunned:
		return
	delta *= boon_time_scale
	_elapsed += delta
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.FLEE:
		_process_flee(delta)
		if not _departed:
			_boon_move_and_slide()
		return
	_stop()
	if not is_instance_valid(target) or (target.get_node_or_null("Health") != null and (target.get_node("Health") as Health).is_dead()):
		attack_elapsed = -1.0
		_line.hide()
		_boon_move_and_slide()
		return
	_face(target.global_position - global_position, delta)
	if _impact_left > 0.0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
	elif variant != Variant.WATCHER and attack_elapsed < 0.0:
		if _distance_to_target() > 2.0:
			_move_to(target.global_position, run_speed)
	attack_cooldown = maxf(0.0, attack_cooldown - delta * boon_attack_scale)
	if attack_elapsed < 0.0 and attack_cooldown <= 0.0 and has_line_of_sight():
		start_attack()
	if attack_elapsed >= 0.0:
		advance_attack(delta)
	_boon_move_and_slide()

func has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(_eye(), _target_point(), CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func is_being_watched() -> bool:
	if not is_instance_valid(target):
		return false
	var camera := target.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return false
	var offset := _eye() - camera.global_position
	if offset.length() > 40.0 or offset.length() < 0.01:
		return false
	if (-camera.global_basis.z).dot(offset.normalized()) < cos(deg_to_rad(9.0)):
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, _eye(), CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func start_attack() -> bool:
	if attack_elapsed >= 0.0 or not is_instance_valid(target) or health.is_dead() or state == State.FLEE:
		return false
	if variant == Variant.FALLER and _distance_to_target() > 7.5:
		return false
	attack_elapsed = 0.0
	gaze_progress = 0.0
	_pounce_hit = false
	locked_direction = (_target_point() - _eye()).normalized()
	if variant == Variant.TREMBLER:
		try_blink()
	return true

func advance_attack(delta: float) -> void:
	if get_tree().paused or attack_elapsed < 0.0 or health.is_dead():
		return
	attack_elapsed += delta
	visual.set_cast(0.0 if not warnings_enabled else clampf(attack_elapsed / windup(), 0.0, 1.0))
	match variant:
		Variant.WATCHER:
			_line.visible = warnings_enabled
			_update_lock_line()
			gaze_progress = gaze_progress + delta if is_being_watched() else 0.0
			if gaze_progress >= 0.15:
				gaze_interrupts += 1
				_finish_attack(1.7)
			elif attack_elapsed >= windup():
				_fire(27.0, 55.0)
				_finish_attack(2.2)
		Variant.TREMBLER:
			if attack_elapsed >= windup():
				_fire(13.0, 32.0)
				_finish_attack(2.4)
		Variant.FALLER:
			if attack_elapsed >= windup() and attack_elapsed < windup() + 0.38:
				velocity.x = locked_direction.x * 16.0
				velocity.z = locked_direction.z * 16.0
				if not _pounce_hit and _distance_to_target() < 1.9 and has_line_of_sight():
					_pounce_hit = true
					pounce_hits += 1
					(target.get_node("Health") as Health).apply_damage(22.0, Hitbox.BodyPart.BODY, self)
			elif attack_elapsed >= windup() + 0.38:
				if is_instance_valid(arena) and arena.has_method("flip_tile_near"):
					arena.call("flip_tile_near", global_position)
				_finish_attack(3.0)

func windup() -> float:
	return [1.6, 0.55, 0.85][variant] * boon_windup_scale

func _finish_attack(cooldown: float) -> void:
	attack_elapsed = -1.0
	attack_cooldown = cooldown
	_line.hide()
	visual.set_cast(0.0)

func _fire(damage: float, speed: float) -> void:
	if not has_line_of_sight():
		return
	shots_fired += 1
	Projectile.spawn(get_parent(), _eye(), locked_direction, self, damage, speed, _hitbox_rids, Color(0.66, 0.28, 0.96))

func _update_lock_line() -> void:
	var a := _eye()
	var b := a + locked_direction * minf(40.0, a.distance_to(_target_point()))
	_line.global_position = (a + b) * 0.5
	_line_mesh.height = a.distance_to(b)
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD)
	if right.length_squared() < 0.001:
		right = up.cross(Vector3.RIGHT)
	right = right.normalized()
	_line.global_basis = Basis(right, up, right.cross(up).normalized())

func try_blink() -> bool:
	if not is_instance_valid(target):
		return false
	var toward := target.global_position - global_position
	toward.y = 0.0
	if toward.length() < 2.8:
		return false
	var point := global_position + toward.normalized() * minf(4.0, toward.length() - 2.2)
	var wall := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, point + Vector3.UP, CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(wall).is_empty():
		return false
	var ground := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2, point - Vector3.UP * 2, CollisionLayers.WORLD)
	var support := get_world_3d().direct_space_state.intersect_ray(ground)
	if support.is_empty() or support.normal.y < 0.7:
		return false
	point.y = support.position.y + 0.02
	var clearance := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.36
	capsule.height = 1.9
	clearance.shape = capsule
	clearance.transform = Transform3D(Basis.IDENTITY, point + Vector3.UP)
	clearance.collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS | CollisionLayers.ENEMIES
	clearance.exclude = _hitbox_rids
	if not get_world_3d().direct_space_state.intersect_shape(clearance, 1).is_empty():
		return false
	visual.spawn_ghost()
	global_position = point
	blink_count += 1
	return true

func _on_damaged(_amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	_impact_point = global_position + Vector3.UP
	_impact_direction = (global_position - source.global_position).normalized() if source is Node3D else Vector3.FORWARD
	for child in find_children("*", "Hitbox", true, false):
		var box := child as Hitbox
		if box.resolving_surface_hit:
			_impact_point = box.surface_point
			_impact_direction = box.surface_direction
			break
	if variant == Variant.TREMBLER and not health.is_dead():
		visual.spawn_ghost()

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	attack_elapsed = -1.0
	_line.hide()
	velocity = Vector3.ZERO
	collision_layer = 0
	for box in find_children("*", "Hitbox", true, false):
		(box as Hitbox).collision_layer = 0
	visual.die(_impact_point, _impact_direction)
	Events.enemy_killed.emit(self)

func set_boon_animation_scale(_value: float) -> void:
	pass
