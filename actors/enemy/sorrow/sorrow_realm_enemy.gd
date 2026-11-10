class_name SorrowRealmEnemy
extends Enemy
@export_enum("Corroder","Sunken","Mourner") var variant := 0
@export var warnings_enabled := true
@export var realm_damage_scale := 1.0
var visual: SorrowVisual
var arena: SorrowRealm
var action_left := 1.0
var action := 0 # 0 approach, 1 dive/charge, 2 surface tell, 3 recover
var effect_key: StringName
var dives := 0
var glob_count := 0
var cries := 0
var _owned: Array[WeakRef] = []

func _enter_tree() -> void:
	($Model as SorrowVisual).kind = variant
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD | CollisionLayers.ACTORS

func _ready() -> void:
	visual = $Model as SorrowVisual
	if not is_boss:
		_align_hitboxes()
	health.max_health = [110.0,230.0,130.0][variant]
	health.health = health.max_health
	run_speed = [2.7,1.6,0.7][variant]
	effect_key = StringName("sorrow_%d" % get_instance_id())
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	_hitbox_rids.append(get_rid())
	for box in find_children("*","Hitbox",true,false):
		_hitbox_rids.append((box as Hitbox).get_rid())
	Events.enemy_registered.emit(self)

func setup(value: CharacterBody3D, covers: Array[CoverPoint], board: FiringPositionBoard = null) -> void:
	super.setup(value,covers,board)
	state = State.CHASE

func begin_hunt() -> void:
	if state != State.DEAD:
		state = State.CHASE

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_stunned or boon_time_scale <= 0:
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity*delta
	if state == State.FLEE:
		_clear_owned()
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
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
		_boon_move_and_slide()
		return
	var flat := (target.global_position-global_position)*Vector3(1,0,1)
	var distance := flat.length()
	_face(flat,delta)
	action_left -= delta*boon_attack_scale
	visual.set_cast(1.0 if warnings_enabled and action == 1 else 0.0)
	if variant == 0:
		_corroding(distance,flat)
	elif variant == 1:
		_chase(flat,3.0)
		if target is Player:
			if distance < 6.5 and _line_clear(target.global_position+Vector3.UP):
				(target as Player).set_realm_effect(effect_key,{"owner":self,"duration":0.25,"jump_multiplier":0.28,"dash_distance_multiplier":0.35,"move_multiplier":0.72})
			else:
				(target as Player).clear_realm_effect(effect_key)
	else:
		if action == 1:
			_stop()
			if action_left <= 0:
				release_cry()
				action = 3
				action_left = 4.0
		else:
			_chase(flat,13.0)
			if action_left <= 0 and distance < 18 and _line_clear(target.global_position+Vector3.UP):
				action = 1
				action_left = 0.9*boon_windup_scale
	_boon_move_and_slide()

func _chase(flat: Vector3, stop_distance: float) -> void:
	if flat.length() < stop_distance:
		_stop()
		return
	velocity.x = flat.normalized().x*run_speed
	velocity.z = flat.normalized().z*run_speed
	var nav := _agent.get_navigation_map()
	if nav.is_valid() and NavigationServer3D.map_get_iteration_id(nav)>0:
		_move_to(target.global_position,run_speed)

func _corroding(distance: float, flat: Vector3) -> void:
	if action == 0 or action == 3:
		_chase(flat,6)
		if distance < 18 and action_left <= 0:
			start_dive()
	elif action == 1:
		_stop()
		if action_left <= 0:
			resurface()
	elif action == 2:
		_stop()
		if action_left <= 0:
			spit()
			action = 3
			action_left = 4.0

func start_dive() -> void:
	if state == State.DEAD:
		return
	action = 1
	action_left = 1.1*boon_windup_scale
	visual.set_submerged(true)
	for box in find_children("*","Hitbox",true,false):
		(box as Hitbox).collision_layer = 0
	if is_instance_valid(arena):
		arena.add_ripple(global_position)

func resurface() -> void:
	if not is_instance_valid(target):
		return
	var candidate := target.global_position+target.global_basis.z.normalized()*3.0
	candidate.y = 0.0
	var ray := PhysicsRayQueryParameters3D.create(target.global_position+Vector3.UP,candidate+Vector3.UP,CollisionLayers.WORLD)
	var wall := get_world_3d().direct_space_state.intersect_ray(ray)
	if not wall.is_empty():
		candidate = wall.position+wall.normal*0.65-Vector3.UP
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.9
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY,candidate+Vector3.UP)
	query.collision_mask = CollisionLayers.WORLD
	if get_world_3d().direct_space_state.intersect_shape(query,1).is_empty():
		global_position = candidate
	visual.set_submerged(false)
	for box in find_children("*","Hitbox",true,false):
		(box as Hitbox).collision_layer = CollisionLayers.HITBOXES
	dives += 1
	action = 2
	action_left = 0.65*boon_windup_scale
	if is_instance_valid(arena):
		arena.add_ripple(global_position)

func spit() -> void:
	if not is_instance_valid(target):
		return
	var bullet := SorrowGlob.new()
	bullet.source = self
	bullet.caster_ref = weakref(self)
	bullet.effect_target = target as Player
	bullet.effect_key = effect_key
	bullet.damage = 10*realm_damage_scale
	bullet.speed = 11
	bullet.max_distance = 28
	bullet.exclude = _hitbox_rids.duplicate()
	get_parent().add_child(bullet)
	bullet.global_position = global_position+Vector3.UP*1.1
	bullet.look_at(target.global_position+Vector3.UP)
	_owned.append(weakref(bullet))
	Events.projectile_registered.emit(bullet)
	glob_count += 1

func release_cry() -> void:
	cries += 1
	var pulse := SorrowCry.new()
	pulse.source = self
	pulse.target = target as Player
	pulse.effect_key = effect_key
	get_parent().add_child(pulse)
	pulse.global_position = global_position
	_owned.append(weakref(pulse))

func _line_clear(point: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(global_position+Vector3.UP,point,CollisionLayers.WORLD)).is_empty()

func _on_damaged(_amount: float,_part: Hitbox.BodyPart,_source: Node) -> void:
	pass

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_stop()
	_leave_cover()
	_release_firing_position()
	collision_layer = 0
	for box in find_children("*","Hitbox",true,false):
		(box as Hitbox).collision_layer = 0
	_clear_owned()
	visual.die(global_position+Vector3.UP,Vector3.BACK)
	Events.enemy_killed.emit(self)

func _clear_owned() -> void:
	if is_instance_valid(target) and target is Player:
		(target as Player).clear_realm_effect(effect_key)
	for ref in _owned:
		var node := ref.get_ref() as Node
		if is_instance_valid(node):
			node.queue_free()
	_owned.clear()

func _exit_tree() -> void:
	_clear_owned()

func set_boon_animation_scale(_value: float) -> void:
	pass

func _align_hitboxes() -> void:
	var rig := visual.skeleton
	var head := visual.model.to_global(rig.get_bone_global_pose(rig.find_bone("Head")).origin)
	(get_node("HeadHitbox") as Hitbox).position = to_local(head)
	var chest := visual.model.to_global(rig.get_bone_global_pose(rig.find_bone("Chest")).origin)
	var hips := visual.model.to_global(rig.get_bone_global_pose(rig.find_bone("Hips")).origin)
	(get_node("TorsoHitbox") as Hitbox).position = to_local((chest+hips)*0.5)
	var collision := get_node("TorsoHitbox/Shape") as CollisionShape3D
	var shape := collision.shape.duplicate() as CapsuleShape3D
	shape.radius = 0.3
	shape.height = maxf(0.65,hips.distance_to(chest)+0.4)
	collision.shape = shape
	(get_node("CoreHitbox") as Hitbox).position = to_local(chest)+Vector3.FORWARD*0.25
