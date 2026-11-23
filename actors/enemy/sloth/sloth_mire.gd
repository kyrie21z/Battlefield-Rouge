class_name SlothMire
extends Enemy
## The Resin Husk locks a spot under the player and lobs a pool of resin onto it.
const WINDUP := 1.15
const LOCK_TIME := 0.35
const COOLDOWN := 4.5
const RESIN := Color("f6ae3f")

class ResinBall extends Projectile:
	var pool: SlothResinPool
	var origin := Vector3.ZERO
	var landing_point := Vector3.ZERO
	var flight_time := 0.0
	var elapsed := 0.0
	var arc_height := 0.0

	func _ready() -> void:
		var glob := SlothMire.make_glob()
		glob.scale = Vector3(1,1,1.25)
		add_child(glob)

	func _physics_process(delta: float) -> void:
		super._physics_process(delta)
		if not reflected and elapsed >= flight_time:
			queue_free()

	func _next_position(delta: float) -> Vector3:
		if reflected:
			return super._next_position(delta)
		elapsed = minf(elapsed + delta, flight_time)
		var t := elapsed / flight_time
		var next := origin.lerp(landing_point, t) + Vector3.UP * (4.0 * arc_height * t * (1.0 - t))
		var step := next - global_position
		if not step.is_zero_approx():
			face_step(step)
		return next

	func face_step(step: Vector3) -> void:
		look_at(global_position + step, Vector3.UP if absf(step.normalized().y) < 0.99 else Vector3.RIGHT)

	func _collision_mask() -> int:
		return super._collision_mask() if reflected else CollisionLayers.WORLD | CollisionLayers.PARRY

	func _hit_world(point: Vector3, normal: Vector3) -> void:
		if reflected:
			super._hit_world(point, normal)
		elif is_instance_valid(pool) and normal.y >= SlothResinPool.MIN_FLOOR_NORMAL \
				and pool.global_position.distance_squared_to(point) < 0.16:
			pool.land()
			pool = null

	func reflect(new_source: CollisionObject3D, point: Vector3) -> void:
		super.reflect(new_source, point)
		_clear_warning()

	func _clear_warning() -> void:
		if is_instance_valid(pool) and not pool.is_queued_for_deletion():
			pool.queue_free()
		pool = null

	func _exit_tree() -> void:
		_clear_warning()

var realm_damage_scale := 1.0
var warnings_enabled := true
var cooldown_left := 1.35
var cast_left := 0.0
var shots_fired := 0
var _locked_point := Vector3.ZERO
var _charging: Node3D
var _pool: SlothResinPool
@onready var visual := $Model as SlothMireVisual

func _ready() -> void:
	health.max_health = 105.0
	health.health = health.max_health
	health.headshot_multiplier = 2.0
	health.died.connect(_on_died)
	run_speed = 2.45
	eye_height = 1.35
	_agent.path_height_offset = 0.5
	$CoreHitbox.collision_layer = CollisionLayers.NONE
	_hitbox_rids = [get_rid(), $HeadHitbox.get_rid(), $TorsoHitbox.get_rid()]
	enable_crystal_feedback(0)
	_charging = make_glob()
	_charging.name = "FormingResin"
	_charging.position = Vector3(0.4,1.45,-0.59)
	_charging.hide()
	add_child(_charging)
	SlothResinPool.prepare_shader(self)
	Events.enemy_registered.emit(self)

func setup(value: CharacterBody3D, points: Array[CoverPoint], board: FiringPositionBoard = null) -> void:
	super.setup(value, points, board)
	state = State.CHASE

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if not is_instance_valid(target) or (target is Player and target.health.is_dead()):
		_cancel_cast()
		return
	if boon_stunned or boon_time_scale <= 0.0:
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity * delta
	_stop()
	if state == State.FLEE:
		_process_flee(delta)
	elif _impact_left > 0.0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY * delta)
	else:
		_face(_locked_point - global_position if cast_left > 0.0 else target.global_position - global_position, delta)
		cooldown_left = maxf(0.0,cooldown_left - delta * effective_attack_scale())
		_update_sight()
		if cast_left > 0.0:
			_update_cast(delta * effective_attack_scale())
		elif not _sees_target or _distance_to_target() > 18.0:
			_move_to(target.global_position,run_speed)
		elif cooldown_left <= 0.0:
			start_cast()
	visual.play_motion("walk" if Vector2(velocity.x,velocity.z).length() > 0.2 else "idle")
	_boon_move_and_slide()

func start_cast() -> bool:
	if state in [State.DEAD, State.FLEE] or cast_left > 0.0 or not is_instance_valid(target) or not target is Player:
		return false
	cast_left = WINDUP * boon_windup_scale
	_locked_point = target.global_position
	return true

func _update_cast(delta: float) -> void:
	var lock_at := minf(LOCK_TIME, WINDUP * boon_windup_scale * 0.5)
	if cast_left > lock_at:
		_locked_point = target.global_position
		if cast_left - delta <= lock_at:
			_lock_landing()
	cast_left = maxf(0.0,cast_left - delta)
	var progress := 1.0 - cast_left / maxf(0.01,WINDUP * boon_windup_scale)
	_charging.visible = warnings_enabled
	_charging.scale = Vector3.ONE * lerpf(0.32,1.25,progress)
	_charging.rotation.z += delta * 2.1
	visual.set_windup(progress)
	if cast_left <= 0.0:
		_release_ball()

func _lock_landing() -> void:
	var query := PhysicsRayQueryParameters3D.create(_locked_point + Vector3.UP * 0.20,
		_locked_point - Vector3.UP * 3.5, CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < SlothResinPool.MIN_FLOOR_NORMAL:
		return
	_locked_point = hit.position
	_pool = SlothResinPool.new()
	_pool.name = "SlothResinPool"
	_pool.position = get_parent_node_3d().to_local(_locked_point)
	_pool.victim = target as Player
	_pool.attacker = self
	_pool.damage_scale = realm_damage_scale
	_pool.visible = warnings_enabled
	get_parent().add_child(_pool)

func _release_ball() -> void:
	cooldown_left = COOLDOWN
	if not is_instance_valid(_pool):
		_cancel_cast()
		return
	var start := _charging.global_position
	var eye := _eye()
	var query := PhysicsRayQueryParameters3D.create(eye,start,CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		start = eye
	var ball := ResinBall.new()
	ball.pool = _pool
	_pool = null
	ball.origin = start
	ball.landing_point = _locked_point - Vector3.UP * 0.12
	var distance := Vector2(start.x - _locked_point.x, start.z - _locked_point.z).length()
	ball.flight_time = clampf(distance / 12.0, 0.4, 1.6)
	ball.arc_height = clampf(0.62 + distance * 0.075, 0.65, 1.75)
	ball.source = self
	ball.exclude = _hitbox_rids.duplicate()
	ball.damage = 0.0
	ball.speed = 12.0
	ball.max_distance = 30.0
	get_parent().add_child(ball)
	ball.global_position = start
	ball.face_step(ball.landing_point - start + Vector3.UP * 4.0 * ball.arc_height)
	Events.projectile_registered.emit(ball)
	shots_fired += 1
	_cancel_cast()

func apply_impact(direction: Vector3, force: float, stagger: float) -> void:
	if not ordinary_impacts_enabled:
		return
	if cast_left > 0.0:
		_cancel_cast()
		cooldown_left = maxf(cooldown_left,1.1)
	super.apply_impact(direction, force, stagger)

func begin_retreat(goal: Vector3, timeout: float) -> void:
	_cancel_cast()
	super.begin_retreat(goal, timeout)

func _cancel_cast() -> void:
	cast_left = 0.0
	_charging.hide()
	visual.set_windup(0.0)
	_clear_landing()

func _clear_landing() -> void:
	if is_instance_valid(_pool) and not _pool.is_queued_for_deletion():
		_pool.queue_free()
	_pool = null

func _exit_tree() -> void:
	_clear_landing()

func _on_died(source: Node) -> void:
	state = State.DEAD
	collision_layer = CollisionLayers.NONE
	$HeadHitbox.collision_layer = CollisionLayers.NONE
	$TorsoHitbox.collision_layer = CollisionLayers.NONE
	_cancel_cast()
	var direction := (global_position - (source as Node3D).global_position).normalized() if source is Node3D else Vector3.FORWARD
	visual.die(global_position + Vector3.UP, direction)
	Events.enemy_killed.emit(self)

static func make_glob() -> Node3D:
	var glob := Node3D.new()
	var skin := StandardMaterial3D.new()
	skin.albedo_color = RESIN
	skin.roughness = 0.26
	skin.emission_enabled = true
	skin.emission = RESIN
	skin.emission_energy_multiplier = 0.75
	var core := StandardMaterial3D.new()
	core.albedo_color = Color("6d401a")
	for i in 5:
		var piece := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.22 if i == 0 else 0.085
		mesh.height = mesh.radius * 2.0
		mesh.radial_segments = 8
		mesh.rings = 4
		piece.mesh = mesh
		piece.material_override = skin if i != 4 else core
		if i > 0:
			var angle := float(i) * TAU / 4.0
			piece.position = Vector3(cos(angle) * 0.18,sin(angle) * 0.18,0.135)
		piece.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		glob.add_child(piece)
	return glob
