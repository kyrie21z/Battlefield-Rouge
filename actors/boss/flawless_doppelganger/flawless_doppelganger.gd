class_name FlawlessDoppelganger
extends Enemy
signal defeated
signal shell_broken(reason: StringName)
enum Move { GUN, DASH_BLADE, GUARD }
enum Phase { WAIT, WINDUP, FIRING, DASHING, GUARD, RECOVER, EXPOSED }
const BASE_HEALTH := 3600.0
const GUN_DAMAGE := 14.0
const SLASH_DAMAGE := 28.0
const CRESCENT_DAMAGE := 16.0
const RIPOSTE_DAMAGE := 18.0
## Below this fraction the shell drops its readable cadence for the last stand.
const HIGH_PRESSURE := 0.55
const HIGH_PRESSURE_CLOCK := 1.30
const RECOVER_WINDOW := 0.85
const HIGH_PRESSURE_RECOVER := 0.55
const WAIT_GAP := 0.25
const HIGH_PRESSURE_WAIT := 0.15
const FAR_RANGE := 11.0
const STRAFE_RANGE := 12.0
const CLOSE_RANGE := 4.0
const STRAFE_ANGLE := 1.1
const STRAFE_FLIP := 1.4
const DASH_SPEED := 23.0
const DASH_MAX_TIME := 0.28
const BLADE_CLOSE_RANGE := 3.5
const BLADE_STOP_DISTANCE := 1.0
const BLADE_BACKSTEP := 1.2
const BLADE_BACKSTEP_TIME := 0.18
const EVADE_COOLDOWN := 4.5
const EVADE_TIME := 0.20
const EVADE_SPEED := 18.0
const CRESCENT_SPEED := 24.0
const CRESCENT_RANGE := 14.0
const RIPOSTE_SPEED := 38.0
const RIPOSTE_RANGE := 40.0
const GUN_TINT := Color(0.9,0.97,1.0)
const CRESCENT_TINT := Color(0.85,0.96,1.0)
const PLATINUM := Color(0.93,0.97,1.0)
var visual: FlawlessVisual
var combat_active := false
var phase := Phase.WAIT
var move_kind := Move.GUN
var phase_left := 0.8
var locked_direction := Vector3.FORWARD
var locked_point := Vector3.ZERO
var resonance_left := 0.0
var resonance_scale := 1.0
var shots := 0
var slashes := 0
var crescents := 0
var ripostes := 0
var wall_breaks := 0
var guard_blocks := 0
var guard_hits_taken := 0
var critical_weak_hits := 0
var _burst_left := 0
var _shot_left := 0.0
var _cycles := 0
var _chained := false
var _force_move := false
var _evade_cooldown := 0.0
var _evade_left := 0.0
var _evade_direction := Vector3.ZERO
var _orbit_sign := 1.0
var _orbit_flip_left := 0.0
var _backstep_left := 0.0
var _backstep_direction := Vector3.ZERO
var _fragment_motion := false
var _owned: Array[WeakRef] = []
func _enter_tree() -> void:
	is_boss = true
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS
func _ready() -> void:
	visual = $Model as FlawlessVisual
	health.max_health = BASE_HEALTH
	health.health = BASE_HEALTH
	health.headshot_multiplier = 1.5
	run_speed = 6.8
	health.before_damage.connect(_before_damage)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_hitbox_rids.append(get_rid())
	for box in find_children("*","Hitbox",true,false):
		_hitbox_rids.append((box as Hitbox).get_rid())
	set_combat_active(false)
	Events.enemy_registered.emit(self)
func set_combat_active(value: bool) -> void:
	combat_active = value
	for box in find_children("*","Hitbox",true,false):
		(box as Hitbox).collision_layer = CollisionLayers.HITBOXES if value else 0
	if value:
		visual.set_print_progress(1)
func setup(value: CharacterBody3D,covers: Array[CoverPoint],board: FiringPositionBoard = null) -> void:
	super.setup(value,covers,board)
	state = State.CHASE
func tempo_multiplier() -> float:
	return resonance_scale if resonance_left > 0 else 1.0
func receive_slumber_resonance(duration: float,scale_value: float) -> void:
	if state == State.DEAD or not combat_active:
		return
	resonance_left = maxf(resonance_left,duration)
	resonance_scale = clampf(scale_value,0.05,1.0)
	_expose(1.0,&"slumber")
func apply_impact(_direction: Vector3,_force: float,_stagger: float) -> void:
	pass # Ordinary weapons never push this perfect shell; the shard has its own path.
func apply_fragment_impact(direction: Vector3,force: float,stagger: float) -> void:
	super.apply_fragment_impact(direction,force,stagger)
	_fragment_motion = _impact_left > 0
func _physics_process(delta: float) -> void:
	if not combat_active or state == State.DEAD or boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	resonance_left = maxf(0,resonance_left-delta)
	delta *= tempo_multiplier()
	if not is_on_floor():
		velocity.y -= gravity*delta
	if not is_instance_valid(target):
		return
	_evade_cooldown = maxf(0,_evade_cooldown-delta)
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
		_move_timed()
		if _fragment_motion:
			for i in get_slide_collision_count():
				var contact := get_slide_collision(i)
				var wall := contact.get_collider() as CollisionObject3D
				if wall != null and wall.collision_layer & CollisionLayers.WORLD and absf(contact.get_normal().y) < 0.5:
					if wall.has_method("fracture"):
						wall.call("fracture",contact.get_position(),contact.get_normal())
					wall_breaks += 1
					_fragment_motion = false
					_impact_left = 0
					_expose(1.6,&"spite_wall")
					break
		return
	if _evade_left > 0:
		# The phase clock holds so the counterattack starts after the slide.
		_evade_left -= delta
		velocity.x = _evade_direction.x*EVADE_SPEED
		velocity.z = _evade_direction.z*EVADE_SPEED
		visual.play_motion("run")
		if _evade_left <= 0:
			visual.play_motion("Aim" if move_kind == Move.GUN else "idle")
		_move_timed()
		return
	_fragment_motion = false
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	var clock_scale := boon_attack_scale if phase == Phase.EXPOSED else effective_attack_scale()*(HIGH_PRESSURE_CLOCK if _high_pressure() else 1.0)
	phase_left -= delta*clock_scale
	visual.set_guard(phase == Phase.GUARD)
	if phase != Phase.DASHING:
		_face(flat,delta*2)
	if phase == Phase.WAIT:
		_strafe(flat,delta)
		if phase_left <= 0:
			_chained = false
			var next := move_kind if _force_move else _choose_move()
			_force_move = false
			begin_move(next)
	elif phase == Phase.WINDUP:
		if _backstep_left > 0:
			_backstep_left -= delta
			velocity.x = _backstep_direction.x*run_speed
			velocity.z = _backstep_direction.z*run_speed
			visual.play_motion("run")
		else:
			_stop()
		if phase_left <= 0:
			if move_kind == Move.GUN:
				phase = Phase.FIRING
				_burst_left = 4
				_shot_left = 0
			elif move_kind == Move.DASH_BLADE:
				phase = Phase.DASHING
				phase_left = _dash_time()
				visual.play_motion("run")
			else:
				phase = Phase.GUARD
				phase_left = 1.0
				guard_hits_taken = 0
	elif phase == Phase.FIRING:
		_stop()
		_shot_left -= delta
		if _shot_left <= 0 and _burst_left > 0:
			if _burst_left < 4:
				locked_point = target.global_position+Vector3.UP
			_fire()
			if _burst_left == 1 and _high_pressure():
				_fire_pair()
			_burst_left -= 1
			_shot_left = 0.13
		if _burst_left == 0:
			if _high_pressure() and not _chained and move_kind == Move.GUN:
				_chained = true
				begin_move(Move.DASH_BLADE)
			else:
				_recover()
	elif phase == Phase.DASHING:
		velocity.x = locked_direction.x*DASH_SPEED
		velocity.z = locked_direction.z*DASH_SPEED
		if phase_left <= 0:
			_slash()
			_recover()
	elif phase == Phase.GUARD:
		_stop()
		if phase_left <= 0:
			_recover()
	else:
		_stop()
		if phase_left <= 0:
			_cycles += 1
			phase = Phase.WAIT
			phase_left = HIGH_PRESSURE_WAIT if _high_pressure() else WAIT_GAP
	_move_timed()
func _move_timed() -> void:
	var unscaled := velocity
	velocity *= tempo_multiplier()
	_boon_move_and_slide()
	if tempo_multiplier() > 0:
		velocity /= tempo_multiplier()
	velocity.y = minf(velocity.y,unscaled.y) if is_on_floor() else velocity.y
func _strafe(flat: Vector3,delta: float) -> void:
	_orbit_flip_left -= delta
	if _orbit_flip_left <= 0:
		_orbit_sign = -_orbit_sign
		_orbit_flip_left = STRAFE_FLIP
	var distance := flat.length()
	var direction := flat.normalized()
	if distance > STRAFE_RANGE:
		pass
	elif distance > CLOSE_RANGE:
		direction = direction.rotated(Vector3.UP,_orbit_sign*STRAFE_ANGLE)
	else:
		direction = (direction.cross(Vector3.UP)*_orbit_sign-direction).normalized()
	velocity.x = direction.x*run_speed
	velocity.z = direction.z*run_speed
	visual.play_motion("run")
func _choose_move() -> int:
	var options: Array[int] = [Move.GUN,Move.DASH_BLADE]
	if global_position.distance_to(target.global_position) <= FAR_RANGE:
		options.append(Move.GUARD)
	var pick: int = options[_cycles%options.size()]
	if pick == move_kind:
		pick = options[(_cycles+1)%options.size()]
	return pick
func _dash_time() -> float:
	var gap := maxf(global_position.distance_to(target.global_position)-BLADE_STOP_DISTANCE,0.3)
	var clock := effective_attack_scale()*(HIGH_PRESSURE_CLOCK if _high_pressure() else 1.0)
	return clampf(gap/DASH_SPEED,0.10,DASH_MAX_TIME)*clock
func begin_move(kind: int) -> void:
	if state == State.DEAD or not combat_active or not is_instance_valid(target):
		return
	move_kind = kind
	locked_point = target.global_position+Vector3.UP
	locked_direction = ((target.global_position-global_position)*Vector3(1,0,1)).normalized()
	_backstep_left = 0
	if kind == Move.DASH_BLADE and global_position.distance_to(target.global_position) < BLADE_CLOSE_RANGE and _step_clear(-locked_direction,BLADE_BACKSTEP):
		_backstep_direction = -locked_direction
		_backstep_left = BLADE_BACKSTEP_TIME
	phase = Phase.WINDUP
	phase_left = (0.55 if kind == Move.DASH_BLADE else 0.45)*boon_windup_scale
	visual.play_motion("Aim" if kind == Move.GUN else "idle")
func _fire() -> void:
	_spawn_round((locked_point-_muzzle()).normalized(),GUN_DAMAGE,42,40,GUN_TINT)
	shots += 1
func _fire_pair() -> void:
	var aim := (locked_point-_muzzle()).normalized()
	for angle in [-0.14,0.14]:
		_spawn_round(aim.rotated(Vector3.UP,angle),GUN_DAMAGE,42,40,GUN_TINT)
		shots += 1
func _riposte() -> void:
	if not combat_active or state == State.DEAD or boon_stunned or not _has_live_target():
		return
	_spawn_round(((target.global_position+Vector3.UP)-_muzzle()).normalized(),RIPOSTE_DAMAGE,RIPOSTE_SPEED,RIPOSTE_RANGE,PLATINUM)
	ripostes += 1
	guard_hits_taken = 0
	_force_move = true
	move_kind = Move.DASH_BLADE
	phase = Phase.WAIT
	phase_left = HIGH_PRESSURE_WAIT if _high_pressure() else WAIT_GAP
	visual.set_guard(false)
func _has_live_target() -> bool:
	if not is_instance_valid(target):
		return false
	var hp := target.get_node_or_null("Health") as Health
	return hp == null or not hp.is_dead()
func _spawn_round(direction: Vector3,damage: float,speed: float,range_limit: float,tint: Color,crescent := false) -> FlawlessBullet:
	var bullet := FlawlessBullet.new()
	bullet.source = self
	bullet.damage = damage
	bullet.speed = speed
	bullet.max_distance = range_limit
	bullet.tint = tint
	bullet.crescent = crescent
	bullet.exclude = _hitbox_rids.duplicate()
	get_parent().add_child(bullet)
	var origin := _muzzle()
	bullet.global_position = origin
	bullet.look_at(origin+direction,Vector3.UP if absf(direction.y) < 0.99 else Vector3.FORWARD)
	_owned.append(weakref(bullet))
	Events.projectile_registered.emit(bullet)
	return bullet
func _muzzle() -> Vector3:
	return global_position+Vector3.UP*1.6
func _slash() -> void:
	slashes += 1
	visual.play_motion("punch")
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	var toward := ((locked_point-global_position)*Vector3(1,0,1)).normalized()
	if flat.length() < 3.0 and flat.normalized().dot(toward) > 0.35 and _line_clear(target.global_position+Vector3.UP):
		var hp := target.get_node("Health") as Health
		var dealt := hp.apply_damage(SLASH_DAMAGE,Hitbox.BodyPart.BODY,self,{"tag":&"aurora_slash"})
		if dealt > 0 and target.has_method("apply_external_impulse"):
			target.call("apply_external_impulse",flat.normalized(),8.0,0.18)
	var direction := Vector3(locked_direction.x,0,locked_direction.z)
	if direction.length_squared() < 0.0001:
		direction = Vector3.BACK
	crescents += 1
	_spawn_round(direction.normalized(),CRESCENT_DAMAGE,CRESCENT_SPEED,CRESCENT_RANGE,CRESCENT_TINT,true)
func _recover() -> void:
	phase = Phase.RECOVER
	phase_left = HIGH_PRESSURE_RECOVER if _high_pressure() else RECOVER_WINDOW
	visual.set_guard(false)
	guard_hits_taken = 0
func _high_pressure() -> bool:
	return health.health + 0.001 < health.max_health*HIGH_PRESSURE
func _expose(duration: float,reason: StringName) -> void:
	phase = Phase.EXPOSED
	phase_left = duration
	visual.set_guard(false)
	guard_hits_taken = 0
	_force_move = false
	shell_broken.emit(reason)
func _before_damage(ctx: Dictionary) -> void:
	if not combat_active:
		ctx.cancelled = true
	elif phase == Phase.GUARD:
		if boon_stunned or state == State.DEAD:
			return
		ctx.cancelled = true
		guard_blocks += 1
		if ctx.get("tag") == &"gun":
			guard_hits_taken += 1
			if guard_hits_taken >= 2 and _has_live_target():
				_riposte()
	elif phase in [Phase.EXPOSED,Phase.RECOVER] and bool(ctx.get("critical",false)):
		ctx.damage *= 1.5
		critical_weak_hits += 1
func _on_damaged(_amount: float,_part: Hitbox.BodyPart,_source: Node) -> void:
	if health.is_dead() or not combat_active or not is_instance_valid(target):
		return
	if phase not in [Phase.WAIT,Phase.WINDUP] or _evade_cooldown > 0:
		return
	var context := health.last_damage_context
	if context.get("tag") != &"gun" or bool(context.get("true_damage",false)):
		return
	_mirror_evade()
func _mirror_evade() -> void:
	var aim := (global_position-target.global_position)*Vector3(1,0,1)
	if aim.length_squared() < 0.0001:
		aim = Vector3.BACK
	var lateral := aim.normalized().cross(Vector3.UP)*_orbit_sign
	if not _step_clear(lateral,EVADE_SPEED*EVADE_TIME):
		lateral = -lateral
		if not _step_clear(lateral,EVADE_SPEED*EVADE_TIME):
			return
	_evade_direction = lateral
	_evade_left = EVADE_TIME
	_evade_cooldown = EVADE_COOLDOWN
	phase_left = 0.05
	_stop()
	visual.play_motion("run")
func _step_clear(direction: Vector3,distance: float) -> bool:
	var from := global_position+Vector3.UP
	return _clear_line(from,from+direction*distance)
func _line_clear(point: Vector3) -> bool:
	return _clear_line(global_position+Vector3.UP,point)
func _clear_line(from: Vector3,to: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from,to,CollisionLayers.WORLD)).is_empty()
func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_stop()
	collision_layer = 0
	for box in find_children("*","Hitbox",true,false):
		(box as Hitbox).collision_layer = 0
	_clear_bullets()
	visual.die(global_position+Vector3.UP,Vector3.UP)
	Events.enemy_killed.emit(self)
	defeated.emit()
func _clear_bullets() -> void:
	for ref in _owned:
		var bullet := ref.get_ref() as Node
		if is_instance_valid(bullet):
			bullet.queue_free()
	_owned.clear()
func _exit_tree() -> void:
	_clear_bullets()
func set_boon_animation_scale(value: float) -> void:
	if is_instance_valid(visual) and visual.animation != null:
		visual.animation.speed_scale = value*tempo_multiplier()
