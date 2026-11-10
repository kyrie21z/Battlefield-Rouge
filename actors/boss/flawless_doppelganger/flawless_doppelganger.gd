class_name FlawlessDoppelganger
extends Enemy
signal defeated
signal shell_broken(reason: StringName)
enum Move { GUN, DASH_BLADE, SHIELD }
enum Phase { WAIT, WINDUP, FIRING, DASHING, GUARD, RECOVER, EXPOSED }
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
var wall_breaks := 0
var guard_blocks := 0
var critical_weak_hits := 0
var _burst_left := 0
var _shot_left := 0.0
var _cycles := 0
var _fragment_motion := false
var _owned: Array[WeakRef] = []
func _enter_tree() -> void:
	is_boss = true
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS
func _ready() -> void:
	visual = $Model as FlawlessVisual
	health.max_health = 1650
	health.health = 1650
	health.headshot_multiplier = 1.5
	run_speed = 6.0
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
	_fragment_motion = false
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	phase_left -= delta*boon_attack_scale*(1.18 if health.health < health.max_health*0.5 else 1.0)
	visual.set_guard(phase == Phase.GUARD)
	if phase != Phase.DASHING:
		_face(flat,delta*2)
	if phase == Phase.WAIT:
		if flat.length() > 10:
			velocity.x = flat.normalized().x*run_speed
			velocity.z = flat.normalized().z*run_speed
			visual.play_motion("run")
		else:
			_stop()
			if phase_left <= 0:
				begin_move(move_kind)
	elif phase == Phase.WINDUP:
		_stop()
		if phase_left <= 0:
			if move_kind == Move.GUN:
				phase = Phase.FIRING
				_burst_left = 4
				_shot_left = 0
			elif move_kind == Move.DASH_BLADE:
				phase = Phase.DASHING
				phase_left = 0.28
				visual.play_motion("run")
			else:
				phase = Phase.GUARD
				phase_left = 1.0
	elif phase == Phase.FIRING:
		_stop()
		_shot_left -= delta
		if _shot_left <= 0 and _burst_left > 0:
			_fire()
			_burst_left -= 1
			_shot_left = 0.13
		if _burst_left == 0:
			_recover()
	elif phase == Phase.DASHING:
		velocity.x = locked_direction.x*23
		velocity.z = locked_direction.z*23
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
			move_kind = (move_kind+1)%3
			phase = Phase.WAIT
			phase_left = 0.25
	_move_timed()
func _move_timed() -> void:
	var unscaled := velocity
	velocity *= tempo_multiplier()
	_boon_move_and_slide()
	if tempo_multiplier() > 0:
		velocity /= tempo_multiplier()
	velocity.y = minf(velocity.y,unscaled.y) if is_on_floor() else velocity.y
func begin_move(kind: int) -> void:
	if state == State.DEAD or not combat_active or not is_instance_valid(target):
		return
	move_kind = kind
	locked_point = target.global_position+Vector3.UP
	locked_direction = ((target.global_position-global_position)*Vector3(1,0,1)).normalized()
	if kind == Move.DASH_BLADE and global_position.distance_to(target.global_position) < 4:
		locked_direction = locked_direction.rotated(Vector3.UP,PI*0.5*(-1 if _cycles%2 else 1))
	phase = Phase.WINDUP
	phase_left = (0.55 if kind == Move.DASH_BLADE else 0.45)*boon_windup_scale
	visual.play_motion("Aim" if kind == Move.GUN else "idle")
func _fire() -> void:
	var bullet := FlawlessBullet.new()
	bullet.source = self
	bullet.damage = 10
	bullet.speed = 42
	bullet.max_distance = 40
	bullet.tint = Color(0.9,0.97,1.0)
	bullet.exclude = _hitbox_rids.duplicate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position+Vector3.UP*1.6
	bullet.look_at(locked_point)
	_owned.append(weakref(bullet))
	Events.projectile_registered.emit(bullet)
	shots += 1
func _slash() -> void:
	slashes += 1
	visual.play_motion("punch")
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	var toward := ((locked_point-global_position)*Vector3(1,0,1)).normalized()
	if flat.length() < 3.0 and flat.normalized().dot(toward) > 0.35 and _line_clear(target.global_position+Vector3.UP):
		var hp := target.get_node("Health") as Health
		var dealt := hp.apply_damage(22,Hitbox.BodyPart.BODY,self,{"tag":&"aurora_slash"})
		if dealt > 0 and target.has_method("apply_external_impulse"):
			target.call("apply_external_impulse",flat.normalized(),8.0,0.18)
func _recover() -> void:
	phase = Phase.RECOVER
	phase_left = 0.85
	visual.set_guard(false)
func _expose(duration: float,reason: StringName) -> void:
	phase = Phase.EXPOSED
	phase_left = duration
	visual.set_guard(false)
	shell_broken.emit(reason)
func _before_damage(ctx: Dictionary) -> void:
	if not combat_active:
		ctx.cancelled = true
	elif phase == Phase.GUARD:
		ctx.cancelled = true
		guard_blocks += 1
	elif phase in [Phase.EXPOSED,Phase.RECOVER] and bool(ctx.get("critical",false)):
		ctx.damage *= 1.5
		critical_weak_hits += 1
func _line_clear(point: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,point,CollisionLayers.WORLD)).is_empty()
func _on_damaged(_amount: float,_part: Hitbox.BodyPart,_source: Node) -> void:
	pass
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
