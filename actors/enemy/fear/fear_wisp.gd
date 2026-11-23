class_name FearWisp
extends Enemy
## Short-lived, shootable flying summon. Never awards kills or gates room clear.
const SPEED := 7.0
const TRIGGER_RANGE := 1.8
const WINDUP := 0.55
const LIFETIME := 8.0
var summoner: WeakRef
var realm_damage_scale := 1.0
var warnings_enabled := true
var attack_elapsed := -1.0
var elapsed := 0.0
var hits := 0
var locked_direction := Vector3.FORWARD
var visual: FearWispVisual
var dormant := false

static func prepare_visuals() -> void:
	FearWispVisual.prepare()

func _ready() -> void:
	prepare_visuals()
	health.max_health = 18.0*realm_hp_scale
	health.health = health.max_health
	run_speed = SPEED
	health.died.connect(_on_died)
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS
	visual = FearWispVisual.new()
	$Model.add_child(visual)
	if dormant:
		process_mode = Node.PROCESS_MODE_DISABLED
		collision_layer = 0
		$TorsoHitbox.collision_layer = 0
		hide()
	else: Events.enemy_registered.emit(self)

func activate(point: Vector3, owner_actor: Enemy, victim: CharacterBody3D) -> void:
	dormant = false
	summoner = weakref(owner_actor)
	warnings_enabled = bool(owner_actor.get("warnings_enabled"))
	apply_realm_scaling(owner_actor.realm_hp_scale,
		float(owner_actor.get("realm_damage_scale")), owner_actor.realm_tempo_scale)
	health.health = health.max_health
	global_position = point
	scale = Vector3.ONE
	visual.advance(0.0,0.0,false)
	process_mode = Node.PROCESS_MODE_INHERIT
	collision_layer = CollisionLayers.ENEMIES
	$TorsoHitbox.collision_layer = CollisionLayers.HITBOXES
	setup(victim,[])
	show()
	Events.enemy_registered.emit(self)

func setup(value: CharacterBody3D, points: Array[CoverPoint], board: FiringPositionBoard = null) -> void:
	super.setup(value,points,board)
	state = State.CHASE

func _owner_alive() -> bool:
	var actor := summoner.get_ref() as Enemy if summoner != null else null
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and not actor.health.is_dead()

func _target_alive() -> bool:
	if not is_instance_valid(target): return false
	var hp := target.get_node_or_null("Health") as Health
	return hp != null and not hp.is_dead()

func _sight() -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position,_target_point(),CollisionLayers.WORLD)).is_empty()

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0.0: return
	if not _owner_alive() or not _target_alive():
		dismiss()
		return
	delta *= boon_time_scale
	elapsed += delta
	if elapsed >= LIFETIME:
		dismiss()
		return
	var windup_time := WINDUP*effective_windup_scale()
	var offset := _target_point()-global_position
	_face(offset,delta)
	if attack_elapsed < 0:
		velocity = offset.normalized()*run_speed
		if offset.length() <= TRIGGER_RANGE and _sight():
			attack_elapsed = 0.0
			locked_direction = offset.normalized()
	else:
		attack_elapsed += delta
		velocity = Vector3.ZERO if attack_elapsed < windup_time else locked_direction*12.0
	var lunging := attack_elapsed >= windup_time
	var expression := 1.0 if lunging else (maxf(0.0,attack_elapsed)/maxf(0.01,windup_time) if warnings_enabled else 0.0)
	visual.advance(delta,expression,lunging)
	if _impact_left > 0:
		_impact_left -= delta
		velocity = _impact_velocity
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
	var before := global_position
	_boon_move_and_slide()
	if attack_elapsed >= windup_time:
		var closest := Geometry3D.get_closest_point_to_segment(_target_point(),before,global_position)
		if closest.distance_to(_target_point()) < 0.85 and _sight():
			hits += 1
			(target.get_node("Health") as Health).apply_damage(8.0*realm_damage_scale,Hitbox.BodyPart.BODY,self)
			dismiss()
		elif attack_elapsed >= windup_time+0.25: dismiss()

func _on_died(_source: Node) -> void:
	dismiss()

func dismiss() -> void:
	state = State.DEAD
	collision_layer = 0
	$TorsoHitbox.collision_layer = 0
	set_physics_process(false)
	hide()
	queue_free()

func begin_retreat(_goal: Vector3, _timeout: float) -> void:
	dismiss()
