class_name FearOculus
extends Enemy
signal defeated
@export var realm_damage_scale := 1.0
@export var warnings_enabled := true:
	set(value):
		warnings_enabled = value
		if not value and is_instance_valid(_alarm):
			_alarm.stop()
		if not value and is_instance_valid(_beam) and phase == 0:
			_beam.hide()
var arena: Node3D
var visual: FearOculusVisual
var phase := 0 # 0 windup, 1 active, 2 exposed recovery
var phase_time := 0.0
var attack_kind := 0
var attack_count := 0
var _damage_tick := 0.0
var _locked_direction := Vector3.FORWARD
var _beam: MeshInstance3D
var _beam_mesh: CylinderMesh
var _beam_material: StandardMaterial3D
var _projectiles: Array[WeakRef] = []
var _alarm: AudioStreamPlayer3D
var _started := false

func _ready() -> void:
	enable_crystal_feedback(1)
	is_boss = true
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD
	visual = $Model as FearOculusVisual
	health.max_health = 1250.0
	health.health = health.max_health
	health.headshot_multiplier = 1.5
	health.before_damage.connect(_before_damage)
	health.died.connect(_on_died)
	_hitbox_rids.append(get_rid())
	for node in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((node as Hitbox).get_rid())
	_beam = MeshInstance3D.new()
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.radial_segments = 10
	_beam.mesh = _beam_mesh
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.albedo_color = Color(0.6, 0.12, 1.0, 0.7)
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.emission_enabled = true
	_beam_material.emission = Color(0.5, 0.1, 1.0)
	_beam_material.emission_energy_multiplier = 3.0
	_beam.material_override = _beam_material
	add_child(_beam)
	_beam.hide()
	_alarm = AudioStreamPlayer3D.new()
	_alarm.stream = ProceduralAudio.generate("enemy_shot")
	_alarm.pitch_scale = 0.55
	_alarm.volume_db = -5
	add_child(_alarm)
	Events.enemy_registered.emit(self)

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint], p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target, p_cover_points, p_firing_board)
	state = State.ENGAGE
	start_attack(0)

func start_attack(kind: int) -> bool:
	if health.is_dead() or not is_instance_valid(target):
		return false
	attack_kind = kind % 3
	phase = 0
	phase_time = 0.0
	_damage_tick = 0.0
	_started = true
	_locked_direction = (target.global_position + Vector3.UP * 1.1 - eye_position()).normalized()
	if warnings_enabled:
		_alarm.play()
	return true

func _physics_process(delta: float) -> void:
	if get_tree().paused or not _started or health.is_dead() or boon_stunned or boon_time_scale <= 0.0:
		return
	if not is_instance_valid(target) or (target.get_node("Health") as Health).is_dead():
		_beam.hide()
		return
	advance_attack(delta * boon_time_scale)

func advance_attack(delta: float) -> void:
	if get_tree().paused or health.is_dead() or not is_instance_valid(target):
		return
	phase_time += delta
	visual.charge = minf(1.0, phase_time / windup()) if phase == 0 and warnings_enabled else 0.1
	match phase:
		0:
			if phase_time < windup() - 0.4:
				_locked_direction = (target.global_position + Vector3.UP * 1.1 - eye_position()).normalized()
			_beam.visible = warnings_enabled and attack_kind != 2
			set_beam(_locked_direction, 0.025 if attack_kind == 1 else 2.0, 34.0)
			if phase_time >= windup():
				phase = 1
				phase_time = 0.0
				attack_count += 1
				if attack_kind == 2:
					release_ring()
		1:
			_damage_tick -= delta
			var sweep := deg_to_rad(lerpf(-48.0 if attack_kind == 0 else -22.0, 48.0 if attack_kind == 0 else 22.0, phase_time / 1.5))
			var direction := Quaternion(Vector3.UP, sweep) * _locked_direction
			_beam.visible = attack_kind != 2
			set_beam(direction, 7.4 if attack_kind == 0 else 0.2, 38.0)
			if attack_kind != 2 and _damage_tick <= 0:
				_damage_tick = 0.28
				if attack_kind == 0:
					scan_damage(direction)
				else:
					beam_damage(direction)
			if phase_time >= 1.5:
				phase = 2
				phase_time = 0.0
				_beam.hide()
		2:
			visual.charge = 0.85
			if phase_time >= 1.4 / maxf(effective_attack_scale(), 0.1):
				start_attack((attack_kind + 1) % 3)

func windup() -> float:
	return [1.4, 1.25, 1.1][attack_kind] * effective_windup_scale()

func eye_position() -> Vector3:
	return global_position + Vector3.UP * 5.3

func scan_damage(direction: Vector3) -> void:
	var offset := target.global_position + Vector3.UP - eye_position()
	if offset.length() > 38 or direction.dot(offset.normalized()) < cos(deg_to_rad(11)):
		return
	var ray := PhysicsRayQueryParameters3D.create(eye_position(), target.global_position + Vector3.UP, CollisionLayers.WORLD)
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		(target.get_node("Health") as Health).apply_damage(9.0 * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"oculus_gaze"})

func beam_damage(direction: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(eye_position(), eye_position() + direction * 42, CollisionLayers.WORLD | CollisionLayers.HITBOXES, _hitbox_rids)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		set_beam(direction, 0.2, eye_position().distance_to(hit.position))
		if hit.collider is Hitbox:
			(hit.collider as Hitbox).apply_hit_at(18.0 * realm_damage_scale, self, hit.position, direction, false, {"tag": &"oculus_beam"})

func release_ring() -> void:
	for index in 24:
		var angle := TAU * index / 24.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var bullet := Projectile.spawn(get_parent(), global_position + Vector3.UP * 1.1 + direction * 1.0,
			direction, self, 12.0 * realm_damage_scale, 13.0, _hitbox_rids, Color(0.6, 0.2, 0.95))
		_projectiles.append(weakref(bullet))

func set_beam(direction: Vector3, radius: float, distance: float) -> void:
	_beam_mesh.top_radius = radius
	_beam_mesh.bottom_radius = 0.04 if attack_kind == 0 else radius
	_beam_mesh.height = distance
	_beam.global_position = eye_position() + direction * distance * 0.5
	var right := direction.cross(Vector3.FORWARD)
	if right.length_squared() < 0.001:
		right = direction.cross(Vector3.RIGHT)
	right = right.normalized()
	_beam.global_basis = Basis(right, direction, right.cross(direction).normalized())

func _before_damage(context: Dictionary) -> void:
	# The open pupil rewards the recovery window without making a build unwinnable.
	if phase != 2 and not context.get("true_damage", false):
		context.damage *= 0.4

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_started = false
	_beam.hide()
	_alarm.stop()
	collision_layer = 0
	for box in find_children("*", "Hitbox", true, false):
		(box as Hitbox).collision_layer = 0
	for item in _projectiles:
		var bullet := item.get_ref() as Projectile
		if is_instance_valid(bullet):
			bullet.queue_free()
	_projectiles.clear()
	visual.shatter()
	if is_instance_valid(arena) and arena.has_method("set_deprivation"):
		arena.call("set_deprivation", true)
	Events.enemy_killed.emit(self)
	defeated.emit()

func _exit_tree() -> void:
	if is_instance_valid(_alarm):
		_alarm.stop()
		_alarm.stream = null

func set_boon_animation_scale(_value: float) -> void:
	pass
