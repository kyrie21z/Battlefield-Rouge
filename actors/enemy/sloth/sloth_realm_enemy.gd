class_name SlothRealmEnemy
extends Enemy
## New realm actors leave the original SlothEnemy and its legacy fixtures untouched.
enum Variant { LAGGARD, ANCHOR, RETREATER }
@export_enum("Laggard","Anchor","Retreater") var variant := 0
@export var warnings_enabled := true
@export var opening_delay := 0.7
const ANCHOR_RADIUS := 8.0
var realm_damage_scale := 1.0
var visual: SlothRealmVisual
var cooldown_left := 0.0
var cast_left := 0.0
var retreat_left := 0.0
var shots_fired := 0
var anchor_active := false
var _effect_source: StringName
var _field: MeshInstance3D
var _locked_point := Vector3.ZERO
var _last_hit_point := Vector3.ZERO
var _last_hit_direction := Vector3.FORWARD

func _enter_tree() -> void:
	($Model as SlothRealmVisual).configure(variant)

func _ready() -> void:
	visual = $Model
	run_speed = [2.2,0.0,2.8][variant]
	engage_range = [22.0,8.0,16.0][variant]
	eye_height = 1.5
	health.max_health = [110.0,190.0,125.0][variant]
	health.health = health.max_health
	health.headshot_multiplier = 2.0
	cooldown_left = opening_delay
	_effect_source = StringName("sloth_anchor_%d" % get_instance_id())
	_hitbox_rids.append(get_rid())
	for hitbox in find_children("*","Hitbox",true,false):
		_hitbox_rids.append((hitbox as Hitbox).get_rid())
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	if variant == Variant.ANCHOR:
		var ring := TorusMesh.new()
		ring.inner_radius = ANCHOR_RADIUS-0.06
		ring.outer_radius = ANCHOR_RADIUS
		ring.rings = 64
		ring.ring_segments = 4
		_field = MeshInstance3D.new()
		_field.mesh = ring
		_field.material_override = SlothAttack._material(Color(1,0.62,0.2,0.5))
		_field.position.y = 0.045
		add_child(_field)
	Events.enemy_registered.emit(self)

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint],
		p_firing_board: FiringPositionBoard = null) -> void:
	_clear_anchor()
	super.setup(p_target,p_cover_points,p_firing_board)
	begin_hunt()

func begin_hunt() -> void:
	if is_instance_valid(target) and state != State.DEAD:
		state = State.CHASE

func _physics_process(delta: float) -> void:
	if state == State.DEAD:
		return
	if boon_time_scale <= 0.0 or boon_stunned:
		_clear_anchor()
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity*delta
	if state == State.FLEE:
		_clear_anchor()
		_process_flee(delta)
		_boon_move_and_slide()
		return
	if not is_instance_valid(target) or not target.has_node("Health") or (target.get_node("Health") as Health).is_dead():
		_clear_anchor()
		return
	cooldown_left = maxf(0.0,cooldown_left-delta*boon_attack_scale)
	retreat_left = maxf(0.0,retreat_left-delta)
	_face(target.global_position-global_position,delta)
	if _impact_left > 0.0:
		_clear_anchor()
		_impact_left = maxf(0.0,_impact_left-delta)
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO,IMPACT_DECAY*delta)
		_boon_move_and_slide()
		return
	_stop()
	if variant == Variant.ANCHOR:
		_update_anchor()
		_boon_move_and_slide()
		return
	if cast_left > 0.0:
		cast_left = maxf(0.0,cast_left-delta*boon_attack_scale/maxf(boon_windup_scale,0.01))
		visual.set_cast(1.0-cast_left/1.2 if warnings_enabled else 0.0)
		if cast_left <= 0.0:
			_release_volley()
	elif retreat_left > 0.0:
		var away := global_position-target.global_position
		away.y = 0.0
		away = away.normalized()
		velocity.x = away.x*run_speed*1.8
		velocity.z = away.z*run_speed*1.8
		if cooldown_left <= 0.0:
			_release_retaliation()
	elif _distance_to_target() > engage_range or not clear_path(_eye(),_target_point()):
		_move_to(target.global_position,run_speed)
	elif cooldown_left <= 0.0:
		if variant == Variant.LAGGARD:
			start_volley()
		else:
			_release_retaliation()
	visual.play_motion("walk" if Vector2(velocity.x,velocity.z).length()>0.2 else "CowerIdle" if variant == 2 else "idle")
	_boon_move_and_slide()

func start_volley() -> bool:
	if state == State.DEAD or cast_left > 0.0 or not is_instance_valid(target):
		return false
	cast_left = 1.2
	_locked_point = _target_point()
	cooldown_left = 4.0
	return true

func _release_volley() -> void:
	var origin := _eye()
	var forward := (_locked_point-origin).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	for i in 4:
		var from := origin+right*(float(i)-1.5)*0.34+forward*0.45
		if not clear_path(origin,from):
			from = origin
		SlothRealmProjectile.launch(get_parent(),from,(_locked_point-from).normalized(),self,10.0*realm_damage_scale,0.8+i*0.13)
		shots_fired += 1
	visual.set_cast(0.0)

func _release_retaliation() -> void:
	if not is_instance_valid(target):
		return
	SlothRealmProjectile.launch(get_parent(),_eye(),(_target_point()-_eye()).normalized(),self,9.0*realm_damage_scale,0.35,target)
	shots_fired += 1
	cooldown_left = 1.15 if retreat_left > 0.0 else 3.0

func _update_anchor() -> void:
	var offset := target.global_position-global_position
	anchor_active = cooldown_left <= 0.0 and Vector2(offset.x,offset.z).length() <= ANCHOR_RADIUS \
		and absf(offset.y)<2.2 and clear_path(_eye(),_target_point())
	if is_instance_valid(_field):
		_field.visible = warnings_enabled
		_field.scale = Vector3.ONE*(1.0 if cooldown_left<=0.0 else 0.95)
	if anchor_active and target.has_method("set_realm_effect"):
		target.call("set_realm_effect",_effect_source,{"dash_blocked":true,"move_multiplier":0.55})
	else:
		_clear_anchor()

func _clear_anchor() -> void:
	anchor_active = false
	if is_instance_valid(target) and target.has_method("clear_realm_effect"):
		target.call("clear_realm_effect",_effect_source)

func clear_path(from: Vector3,to: Vector3) -> bool:
	return get_world_3d().direct_space_state.intersect_ray(
		PhysicsRayQueryParameters3D.create(from,to,CollisionLayers.WORLD)).is_empty()

func _on_damaged(_amount: float,_part: Hitbox.BodyPart,source: Node) -> void:
	_last_hit_point = global_position+Vector3.UP
	_last_hit_direction = (global_position-source.global_position).normalized() if source is Node3D else Vector3.FORWARD
	if variant == Variant.RETREATER:
		retreat_left = 1.8
		cooldown_left = minf(cooldown_left,0.25)
	state = State.CHASE if state != State.DEAD else state

func apply_impact(direction: Vector3,force: float,stagger: float) -> void:
	if "ordinary_impacts_enabled" in self and not get("ordinary_impacts_enabled"):
		return
	cast_left = 0.0
	_clear_anchor()
	super.apply_impact(direction,force,stagger)

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	cast_left = 0.0
	_clear_anchor()
	_leave_cover()
	_release_firing_position()
	collision_layer = 0
	for hitbox in find_children("*","Hitbox",true,false):
		(hitbox as Hitbox).collision_layer = 0
	visual.die(_last_hit_point,_last_hit_direction)
	Events.enemy_killed.emit(self)

func set_boon_animation_scale(value: float) -> void:
	if is_instance_valid(visual) and is_instance_valid(visual.animation):
		visual.animation.speed_scale = value

func _exit_tree() -> void:
	_clear_anchor()
