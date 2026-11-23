class_name WrathRealmEnemy
extends Enemy
enum Variant { PIERCER, ACCUMULATOR, AGGRESSOR, READER }
enum Attack { APPROACH, WINDUP, RUSH, RELEASE, RECOVER }
const READER_WALK_SPEED := 3.0
const READER_CHASE_SPEED := 9.2
const READER_LUNGE_SPEED := 20.0
const READER_LUNGE_DURATION := 0.17
const READER_RECOVERY := 0.90
@export_enum("Piercer", "Accumulator", "Aggressor", "Reader") var variant := 0
@export var warnings_enabled := true
@export var realm_damage_scale := 1.0
var visual: WrathVisual
var attack_phase := Attack.APPROACH
var attack_left := 0.0
var pressure := 0.0
var blocked_shots := 0
var emitted_shards := 0
var wall_detonations := 0
var wave_releases := 0
var locked_direction := Vector3.FORWARD
var _contact_hit := false
var paper_torn := false

func _enter_tree() -> void:
	($Model as WrathVisual).kind = variant
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS

func _ready() -> void:
	enable_crystal_feedback(2)
	visual = $Model as WrathVisual
	health.max_health = [110.0, 220.0, 160.0, 90.0][variant]
	health.health = health.max_health
	run_speed = [3.6, 1.6, 5.0, READER_WALK_SPEED][variant]
	health.before_damage.connect(_before_damage)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_cache_hitboxes()
	Events.enemy_registered.emit(self)

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint], p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target, p_cover_points, p_firing_board)
	state = State.CHASE

func begin_hunt() -> void:
	if state != State.DEAD:
		state = State.CHASE

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity * delta
	if state == State.FLEE:
		_process_flee(delta)
		_boon_move_and_slide()
		return
	if not is_instance_valid(target):
		_stop()
		_boon_move_and_slide()
		return
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
		_boon_move_and_slide()
		return
	var offset := target.global_position - global_position
	var flat := Vector3(offset.x, 0, offset.z)
	var distance := flat.length()
	if variant == Variant.READER:
		_process_reader(delta, flat, offset.y)
		_boon_move_and_slide()
		return
	if attack_phase != Attack.RUSH:
		_face(flat, delta)
	visual.pressure = pressure / 100.0
	visual.set_cast(1.0 if warnings_enabled and attack_phase == Attack.WINDUP else 0.0)
	attack_left -= delta * effective_attack_scale()
	if attack_phase == Attack.APPROACH:
		_pursue(flat)
		if variant == Variant.ACCUMULATOR:
			if distance < 8.0:
				_stop()
			if pressure >= 100.0:
				start_attack()
		elif distance < (16.0 if variant == Variant.PIERCER else 4.5) and attack_left <= 0 and _line_clear(target.global_position + Vector3.UP):
			start_attack()
	elif attack_phase == Attack.WINDUP:
		_stop()
		if attack_left <= 0:
			attack_phase = Attack.RUSH if variant != Variant.ACCUMULATOR else Attack.RELEASE
			attack_left = 1.6 if variant == Variant.PIERCER else 0.42
			if variant == Variant.ACCUMULATOR:
				release_wave()
	elif attack_phase == Attack.RUSH:
		var speed_value := 23.0 if variant == Variant.PIERCER else 14.0
		velocity.x = locked_direction.x * speed_value
		velocity.z = locked_direction.z * speed_value
		if distance < 1.3 and not _contact_hit:
			_contact_hit = true
			var hp := target.get_node_or_null("Health") as Health
			if hp != null:
				hp.apply_damage((22.0 if variant == Variant.PIERCER else 13.0) * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"wrath_contact"})
			if target.has_method("apply_external_impulse"):
				target.call("apply_external_impulse", locked_direction, 8.0, 0.18)
		if attack_left <= 0:
			attack_phase = Attack.RECOVER
			attack_left = 1.0
	else:
		_stop()
		if attack_left <= 0:
			attack_phase = Attack.APPROACH
			attack_left = 0.8
	_boon_move_and_slide()
	if variant == Variant.PIERCER and attack_phase == Attack.RUSH:
		for i in get_slide_collision_count():
			var collision := get_slide_collision(i)
			var object := collision.get_collider() as CollisionObject3D
			if object != null and object.collision_layer & CollisionLayers.WORLD and absf(collision.get_normal().y) < 0.5:
				detonate_at_wall(collision.get_position(), collision.get_normal())
				break

func _pursue(flat: Vector3) -> void:
	var direction := flat.normalized()
	velocity.x = direction.x * run_speed
	velocity.z = direction.z * run_speed
	var nav := _agent.get_navigation_map()
	if nav.is_valid() and NavigationServer3D.map_get_iteration_id(nav) > 0:
		_move_to(target.global_position, run_speed)
	visual.play_motion("walk")

func _process_reader(delta: float, flat: Vector3, height_delta: float) -> void:
	attack_left -= delta * effective_attack_scale()
	var distance := flat.length()
	if attack_phase == Attack.RECOVER:
		_stop()
		visual.play_motion("idle")
		if attack_left <= 0.0:
			attack_phase = Attack.APPROACH
		return
	if attack_phase == Attack.APPROACH:
		_face(flat, delta)
		if paper_torn and distance <= 4.0 and absf(height_delta) < 1.25 and _line_clear(target.global_position + Vector3.UP):
			start_attack()
		elif not paper_torn and distance < 3.8:
			_stop()
			visual.play_motion("idle")
			return
		else:
			_pursue(flat)
			return
	velocity.x = locked_direction.x * READER_LUNGE_SPEED
	velocity.z = locked_direction.z * READER_LUNGE_SPEED
	var contact := distance <= 1.10 and absf(height_delta) < 1.25 and flat.dot(locked_direction) >= -0.02
	if contact and _line_clear(target.global_position + Vector3.UP):
		var hp := target.get_node_or_null("Health") as Health
		if hp != null:
			hp.apply_damage(10.0 * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"wrath_contact"})
		attack_left = 0.0
	if attack_left <= 0.0:
		_stop()
		attack_phase = Attack.RECOVER
		attack_left = READER_RECOVERY

func start_attack() -> void:
	if not is_instance_valid(target) or state == State.DEAD:
		return
	if variant == Variant.READER and (not paper_torn or attack_phase != Attack.APPROACH):
		return
	locked_direction = (target.global_position - global_position) * Vector3(1, 0, 1)
	locked_direction = locked_direction.normalized()
	if variant == Variant.READER:
		if locked_direction.is_zero_approx():
			locked_direction = -global_basis.z
		attack_phase = Attack.RUSH
		attack_left = READER_LUNGE_DURATION
		visual.play_motion("run")
		return
	attack_phase = Attack.WINDUP
	attack_left = (0.75 if variant != Variant.AGGRESSOR else 0.4) * boon_windup_scale
	_contact_hit = false

func release_wave() -> void:
	var wave := WrathShockwave.new()
	wave.source = self
	wave.target = target
	wave.damage *= realm_damage_scale
	get_parent().add_child(wave)
	wave.global_position = global_position
	pressure = 0.0
	wave_releases += 1
	attack_phase = Attack.RECOVER
	attack_left = 1.8

func detonate_at_wall(point: Vector3, normal: Vector3) -> void:
	if state == State.DEAD:
		return
	wall_detonations += 1
	for i in 8:
		var angle := TAU * i / 8.0
		var direction := Vector3(sin(angle), 0.08, cos(angle)).normalized()
		WrathRicochet.launch(get_parent(), point + normal * 0.5 + Vector3.UP * 0.8, direction, self, 10.0 * realm_damage_scale)
		emitted_shards += 1
	health.apply_damage(health.health + 1.0, Hitbox.BodyPart.BODY, null, {"true_damage": true})

func _before_damage(ctx: Dictionary) -> void:
	if variant == Variant.READER and not paper_torn and not ctx.cancelled and float(ctx.damage) > 0.0 and ctx.source is Player:
		paper_torn = true
		ctx.cancelled = not ctx.get("true_damage", false)
		_base_run_speed = READER_CHASE_SPEED
		set_realm_tempo(realm_tempo_scale)
		visual.tear_paper()
		return
	if variant != Variant.ACCUMULATOR or attack_phase in [Attack.RELEASE, Attack.RECOVER]:
		return
	if ctx.get("kind", &"") != &"gun" and ctx.get("tag", &"") not in [&"projectile", &"wrath_projectile"]:
		return
	var incoming: Vector3 = ctx.get("direction", Vector3.ZERO)
	if incoming.length_squared() < 0.01:
		return
	if (-incoming.normalized()).dot(-global_basis.z) < 0.5:
		return
	ctx.cancelled = true
	ctx["blocked_by_shield"] = true
	pressure = minf(100.0, pressure + float(ctx.damage))
	blocked_shots += 1
	visual.pressure = pressure / 100.0

func _on_damaged(_amount: float, _part: Hitbox.BodyPart, source: Node) -> void:
	if is_instance_valid(source) and source is Node3D and target == null:
		_last_known = source.global_position

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_stop()
	_leave_cover()
	_release_firing_position()
	collision_layer = CollisionLayers.NONE
	_set_hitboxes_layer(CollisionLayers.NONE)
	visual.die(global_position + Vector3.UP, locked_direction)
	Events.enemy_killed.emit(self)

func apply_impact(direction: Vector3, force: float, stagger: float) -> void:
	if variant == Variant.AGGRESSOR:
		return
	super.apply_impact(direction, force, stagger)

func set_boon_animation_scale(value: float) -> void:
	if is_instance_valid(visual) and visual.animation != null:
		visual.animation.speed_scale = value

func _line_clear(point: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, point, CollisionLayers.WORLD)).is_empty()
