class_name SlothMire
extends Enemy
## The Resin Husk throws one committed projectile. A new coat refreshes the
## same status instead of multiplying either slowdown or damage ticks.
const WINDUP := 1.15
const LOCK_TIME := 0.35
const COOLDOWN := 4.5
const RESIN := Color(0.67,0.76,0.26)
const COATING_NAME := "SlothResinCoating"

class Coating extends Node:
	const EFFECT := &"sloth_resin"
	const STEP := 0.25
	var victim: Player
	var attacker: Enemy
	var tick_damage := 2.5
	var remaining := 4
	var clock := STEP

	func refresh(new_attacker: Enemy, scale_value: float) -> void:
		attacker = new_attacker
		tick_damage = 2.5 * scale_value
		remaining = 4
		clock = STEP
		victim.set_realm_effect(EFFECT, {"move_multiplier":0.65, "owner":self})

	func _physics_process(delta: float) -> void:
		if not is_instance_valid(victim) or victim.health.is_dead() or not is_instance_valid(attacker) or attacker.health.is_dead():
			queue_free()
			return
		clock -= delta
		while remaining > 0 and clock <= 0.00001:
			clock += STEP
			remaining -= 1
			victim.health.apply_damage(tick_damage, Hitbox.BodyPart.BODY, attacker, {"tag":&"sloth_resin", "kind":&"proc", "proc_depth":1})
			if victim.health.is_dead():
				break
		if remaining == 0 or victim.health.is_dead():
			queue_free()

	func _exit_tree() -> void:
		if is_instance_valid(victim):
			victim.clear_realm_effect(EFFECT)

class ResinBall extends Projectile:
	var victim: Player
	var attacker: Enemy
	var curse_scale := 1.0

	func _ready() -> void:
		var glob := SlothMire.make_glob()
		glob.scale = Vector3(1,1,1.25)
		add_child(glob)
		impacted.connect(_coat)

	func _coat(collider: Node, _point: Vector3) -> void:
		var box := collider as Hitbox
		if reflected or box == null or not is_instance_valid(victim) or box.health != victim.health:
			return
		if not is_instance_valid(attacker) or attacker.health.is_dead() or victim.health.is_dead():
			return
		if (victim.health.invulnerable and not victim.health.unbuffered) or victim.health.dash_invulnerable or victim.health.parrying:
			return
		var coating := victim.get_node_or_null(SlothMire.COATING_NAME) as Coating
		if coating == null:
			coating = Coating.new()
			coating.name = SlothMire.COATING_NAME
			coating.victim = victim
			victim.add_child(coating)
		coating.refresh(attacker, curse_scale)

var realm_damage_scale := 1.0
var warnings_enabled := true
var cooldown_left := 1.35
var cast_left := 0.0
var shots_fired := 0
var _locked_point := Vector3.ZERO
var _charging: Node3D
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
		cooldown_left = maxf(0.0,cooldown_left - delta * boon_attack_scale)
		_update_sight()
		if cast_left > 0.0:
			_update_cast(delta * boon_attack_scale)
		elif not _sees_target or _distance_to_target() > 18.0:
			_move_to(target.global_position,run_speed)
		elif cooldown_left <= 0.0:
			start_cast()
	visual.play_motion("walk" if Vector2(velocity.x,velocity.z).length() > 0.2 else "idle")
	_boon_move_and_slide()

func start_cast() -> bool:
	if state in [State.DEAD, State.FLEE] or cast_left > 0.0 or not target is Player:
		return false
	cast_left = WINDUP * boon_windup_scale
	_locked_point = _target_point()
	return true

func _update_cast(delta: float) -> void:
	if cast_left > LOCK_TIME:
		_locked_point = _target_point()
	cast_left = maxf(0.0,cast_left - delta)
	var progress := 1.0 - cast_left / maxf(0.01,WINDUP * boon_windup_scale)
	_charging.visible = warnings_enabled
	_charging.scale = Vector3.ONE * lerpf(0.32,1.25,progress)
	_charging.rotation.z += delta * 2.1
	visual.set_windup(progress)
	if cast_left <= 0.0:
		_release_ball()

func _release_ball() -> void:
	var start := _charging.global_position
	var eye := _eye()
	var query := PhysicsRayQueryParameters3D.create(eye,start,CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(query).is_empty():
		start = eye
	var direction := (_locked_point - start).normalized()
	if direction.is_zero_approx():
		direction = -global_basis.z
	var ball := ResinBall.new()
	ball.victim = target as Player
	ball.attacker = self
	ball.source = self
	ball.exclude = _hitbox_rids.duplicate()
	ball.damage = 0.0
	ball.speed = 12.0
	ball.max_distance = 30.0
	ball.curse_scale = realm_damage_scale
	get_parent().add_child(ball)
	ball.global_position = start
	ball.look_at(start + direction,Vector3.UP if absf(direction.y)<0.99 else Vector3.RIGHT)
	Events.projectile_registered.emit(ball)
	shots_fired += 1
	cooldown_left = COOLDOWN
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
	core.albedo_color = Color("283427")
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
