class_name FearReaper
extends Enemy
## Summons are temporary threats: the room counts their master, not the wisps.
const WISP := preload("res://actors/enemy/fear/fear_wisp.tscn")
const MAX_WISPS := 3
const SUMMON_WINDUP := 1.2
const SUMMON_COOLDOWN := 5.5
const SCYTHE_WINDUP := 0.9
const SCYTHE_RANGE := 3.1
@export var realm_damage_scale := 1.0
@export var warnings_enabled := true
var wisps: Array[WeakRef] = []
var attack_elapsed := -1.0
var melee := false
var attack_cooldown := 1.2
var summons_cast := 0
var scythe_hits := 0
var visual: FearReaperVisual

func _ready() -> void:
	visual = $Model as FearReaperVisual
	health.max_health = 140.0
	health.health = health.max_health
	run_speed = 2.4
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS
	for box in find_children("*","Hitbox",true,false): _hitbox_rids.append((box as Hitbox).get_rid())
	_hitbox_rids.append(get_rid())
	health.died.connect(_on_died)
	FearWisp.prepare_visuals()
	enable_crystal_feedback(1)
	Events.enemy_registered.emit(self)

func setup(value: CharacterBody3D, points: Array[CoverPoint], board: FiringPositionBoard = null) -> void:
	super.setup(value,points,board)
	state = State.CHASE

func living_wisps() -> Array[FearWisp]:
	var result: Array[FearWisp] = []
	for reference in wisps:
		var wisp := reference.get_ref() as FearWisp
		if is_instance_valid(wisp) and not wisp.is_queued_for_deletion() and not wisp.health.is_dead(): result.append(wisp)
	return result

func _target_alive() -> bool:
	if not is_instance_valid(target): return false
	var hp := target.get_node_or_null("Health") as Health
	return hp != null and not hp.is_dead()

func _sight() -> bool:
	return _target_alive() and get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(_eye(),_target_point(),CollisionLayers.WORLD)).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0.0: return
	delta *= boon_time_scale
	if not is_on_floor(): velocity.y -= gravity*delta
	_stop()
	if state == State.FLEE:
		_process_flee(delta)
		_boon_move_and_slide()
		return
	if not _target_alive():
		_cancel_attack()
		_dismiss_wisps()
		_boon_move_and_slide()
		return
	_face(target.global_position-global_position,delta)
	attack_cooldown = maxf(0.0,attack_cooldown-delta*boon_attack_scale)
	if attack_elapsed < 0:
		if _distance_to_target() > 10.0 or not _sight(): _move_to(target.global_position,run_speed)
		if attack_cooldown <= 0 and _distance_to_target() <= 22.0 and _sight(): start_attack()
	else:
		attack_elapsed += delta
		var duration := (SCYTHE_WINDUP if melee else SUMMON_WINDUP)*boon_windup_scale
		visual.set_ritual(clampf(attack_elapsed/maxf(duration,0.01),0.0,1.0) if warnings_enabled else 0.0,melee)
		if attack_elapsed >= duration:
			if melee: _scythe_strike()
			elif _sight(): _summon()
			_cancel_attack()
			attack_cooldown = 1.8 if melee else SUMMON_COOLDOWN
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
	visual.play_motion("walk" if Vector2(velocity.x,velocity.z).length() > 0.3 else "idle")
	_boon_move_and_slide()

func start_attack() -> bool:
	if attack_elapsed >= 0 or health.is_dead() or state == State.FLEE or not _target_alive(): return false
	melee = _distance_to_target() <= SCYTHE_RANGE
	if not melee and living_wisps().size() >= MAX_WISPS: return false
	attack_elapsed = 0.0
	return true

func _summon() -> void:
	if health.is_dead() or not _target_alive(): return
	var live := living_wisps()
	wisps.clear()
	for wisp in live: wisps.append(weakref(wisp))
	for slot in MAX_WISPS-live.size():
		var offset := Vector3((slot-1)*0.75,1.4,-0.65)
		var point := global_transform*offset
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.38
		query.shape = sphere
		query.transform.origin = point
		query.collision_mask = CollisionLayers.WORLD
		if not get_world_3d().direct_space_state.intersect_shape(query,1).is_empty(): continue
		var wisp := WISP.instantiate() as FearWisp
		wisp.summoner = weakref(self)
		wisp.realm_damage_scale = realm_damage_scale
		wisp.warnings_enabled = warnings_enabled
		wisp.position = get_parent().to_local(point)
		get_parent().add_child(wisp)
		wisp.setup(target,[])
		wisps.append(weakref(wisp))
	summons_cast += 1

func _scythe_strike() -> void:
	if _distance_to_target() <= SCYTHE_RANGE and _sight() and absf(target.global_position.y-global_position.y) < 2.0:
		scythe_hits += 1
		(target.get_node("Health") as Health).apply_damage(16.0*realm_damage_scale,Hitbox.BodyPart.BODY,self)

func _cancel_attack() -> void:
	attack_elapsed = -1.0
	visual.set_ritual(0.0,false)

func _dismiss_wisps() -> void:
	for wisp in living_wisps(): wisp.dismiss()
	wisps.clear()

func begin_retreat(goal: Vector3, timeout: float) -> void:
	_cancel_attack()
	_dismiss_wisps()
	super.begin_retreat(goal,timeout)

func _on_died(_source: Node) -> void:
	if state == State.DEAD: return
	state = State.DEAD
	_cancel_attack()
	_dismiss_wisps()
	collision_layer = 0
	for box in find_children("*","Hitbox",true,false): (box as Hitbox).collision_layer = 0
	velocity = Vector3.ZERO
	visual.die()
	Events.enemy_killed.emit(self)

func _exit_tree() -> void:
	_dismiss_wisps()
