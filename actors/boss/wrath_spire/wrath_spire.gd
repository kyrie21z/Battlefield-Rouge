class_name WrathSpire
extends WrathRealmEnemy
## Each attack has a locked telegraph, active period and a gun/blade punish window.
signal realm_defeated(realm_id: int)
signal phase_changed(new_phase: int)
enum Move { VORTEX, FISSURE, SHRAPNEL, VOLLEY, ERUPTION }
const MOVE_ORDER := [Move.VOLLEY,Move.FISSURE,Move.SHRAPNEL,Move.ERUPTION,Move.VORTEX]
var arena: Node3D
var move_kind := Move.VOLLEY
var phase_elapsed := 0.0
var cycle_count := 0
var spawned_waves := 0
var spawned_bullets := 0
var _pulse_left := 0.0
var _burst_done := false
var _owned_bullets: Array[WeakRef] = []
var spawned_eruptions := 0
var _volley_count := 0
var _locked_aim := Vector3.FORWARD
var _aim_tell: MeshInstance3D
var boss_phase := 1

func _enter_tree() -> void:
	variant = Variant.AGGRESSOR
	is_boss = true
	super._enter_tree()

func _ready() -> void:
	super._ready()
	health.max_health = 1050
	health.health = health.max_health
	health.headshot_multiplier = 1.3
	attack_phase = Attack.APPROACH
	attack_left = 1.4
	run_speed = 3.0
	health.after_damage.connect(_on_phase_damage)

func _on_phase_damage(_context: Dictionary) -> void:
	if boss_phase != 1 or health.is_dead():
		return
	if health.health > health.max_health * 0.50 + 0.001:
		return
	boss_phase = 2
	boss_phase_tempo_scale = 1.20
	health.max_shield = roundf(health.max_health * 0.15)
	health.shield_points = health.max_shield
	health.shield_regeneration_rate = 0.0
	health.shield_changed.emit(health.shield_points)
	phase_changed.emit(2)

func _physics_process(delta: float) -> void:
	if state == State.DEAD or boon_time_scale <= 0 or boon_stunned:
		return
	delta *= boon_time_scale
	if not is_on_floor():
		velocity.y -= gravity * delta
	if not _has_live_target():
		_stop()
		_clear_bullets()
		_boon_move_and_slide()
		return
	if _impact_left > 0:
		_impact_left -= delta
		velocity.x = _impact_velocity.x
		velocity.z = _impact_velocity.z
		_impact_velocity = _impact_velocity.move_toward(Vector3.ZERO, IMPACT_DECAY * delta)
		_boon_move_and_slide()
		return
	var flat := (target.global_position - global_position) * Vector3(1, 0, 1)
	phase_elapsed += delta * effective_attack_scale()
	attack_left -= delta * effective_attack_scale()
	_pulse_left -= delta
	var model := visual as WrathSpireVisual
	model.speed_factor = 5.0 if attack_phase == Attack.RUSH else 1.0
	model.telegraph = 1.0 if warnings_enabled and attack_phase == Attack.WINDUP else 0.0
	if is_instance_valid(_aim_tell):
		_aim_tell.visible = warnings_enabled and attack_phase == Attack.WINDUP
	if attack_phase == Attack.APPROACH:
		_stop()
		_face(flat, delta)
		if attack_left <= 0:
			begin_move(move_kind)
	elif attack_phase == Attack.WINDUP:
		_stop()
		if attack_left <= 0:
			attack_phase = Attack.RUSH
			attack_left = 1.8 if move_kind == Move.VORTEX else 0.8
			phase_elapsed = 0
			_burst_done = false
			_clear_aim_tell()
			if move_kind == Move.FISSURE:
				var offsets := [-0.64,-0.32,0.0,0.32,0.64] if boss_phase >= 2 else [-0.42,0.0,0.42]
				for offset in offsets:
					var wave := WrathShockwave.new()
					wave.source = self
					wave.target = target
					wave.max_radius = 27
					wave.half_angle = 0.24
					wave.direction = locked_direction.rotated(Vector3.UP, offset)
					wave.damage = 13 * realm_damage_scale
					wave.speed = 20
					get_parent().add_child(wave)
					wave.global_position = global_position
					spawned_waves += 1
			elif move_kind == Move.SHRAPNEL:
				_fire_radial(0.0)
			elif move_kind == Move.VOLLEY:
				_fire_volley()
	elif attack_phase == Attack.RUSH:
		if move_kind == Move.VORTEX:
			velocity.x = locked_direction.x * 6.5
			velocity.z = locked_direction.z * 6.5
			if flat.length() < 3.3 and _pulse_left <= 0 and _line_clear(target.global_position + Vector3.UP):
				_pulse_left = 0.45
				var hp := target.get_node_or_null("Health") as Health
				if hp != null:
					hp.apply_damage(13 * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"spire_vortex"})
				if target.has_method("apply_external_impulse"):
					target.call("apply_external_impulse", flat.normalized(), 9.0, 0.2)
		else:
			_stop()
			while move_kind == Move.VOLLEY and _volley_count < 3 and phase_elapsed >= _volley_count*0.28:
				_fire_volley()
			if move_kind == Move.SHRAPNEL and phase_elapsed >= 0.35 and not _burst_done:
				_burst_done = true
				_fire_radial(PI / 12.0)
		if attack_left <= 0:
			attack_phase = Attack.RECOVER
			attack_left = 1.15 if boss_phase >= 2 else 1.5
	else:
		_stop()
		if attack_left <= 0:
			cycle_count += 1
			move_kind = MOVE_ORDER[(MOVE_ORDER.find(move_kind)+1)%MOVE_ORDER.size()]
			attack_phase = Attack.APPROACH
			attack_left = 0.5
	_boon_move_and_slide()

func begin_move(kind: int) -> void:
	if not _has_live_target() or state == State.DEAD:
		return
	move_kind = Move.VOLLEY if kind == Move.VORTEX and target.global_position.distance_to(global_position) > 9.0 else kind
	locked_direction = ((target.global_position - global_position) * Vector3(1, 0, 1)).normalized()
	_locked_aim = (target.global_position+Vector3.UP*1.0-(global_position+Vector3.UP*1.9)).normalized()
	attack_phase = Attack.WINDUP
	attack_left = (1.2 if move_kind == Move.ERUPTION else 1.1) * boon_windup_scale
	phase_elapsed = 0
	_volley_count = 0
	_clear_aim_tell()
	if move_kind == Move.VOLLEY and warnings_enabled:
		_show_aim_tell()
	elif move_kind == Move.ERUPTION:
		_spawn_eruptions()

func _has_live_target() -> bool:
	if not is_instance_valid(target):
		return false
	var hp := target.get_node_or_null("Health") as Health
	return hp == null or not hp.is_dead()

func _fire_volley() -> void:
	_volley_count += 1
	for angle in [-0.32,-0.16,0.0,0.16,0.32]:
		var direction := _locked_aim.rotated(Vector3.UP,angle)
		var bullet := WrathRicochet.launch(get_parent(),global_position+Vector3.UP*1.9+direction*1.6,direction,self,10.0*realm_damage_scale,24.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _spawn_eruptions() -> void:
	var center := target.global_position
	if center.distance_to(global_position) > 40.0:
		return
	var side := locked_direction.cross(Vector3.UP).normalized()
	var offsets := [-6.0,-3.0,0.0,3.0,6.0] if boss_phase >= 2 else [-4.5,0.0,4.5]
	for offset in offsets:
		var point: Vector3 = center+side*offset
		if not _line_clear(point+Vector3.UP):
			continue
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*4,point-Vector3.UP*6,CollisionLayers.WORLD)
		var ground := get_world_3d().direct_space_state.intersect_ray(ray)
		if ground.is_empty() or ground.normal.y < 0.8:
			continue
		var eruption := SpireEruption.new()
		eruption.source = self
		eruption.target = target
		eruption.damage = 18.0*realm_damage_scale
		eruption.warning_seconds = attack_left
		get_parent().add_child(eruption)
		eruption.global_position = ground.position
		_owned_bullets.append(weakref(eruption))
		spawned_eruptions += 1

func _show_aim_tell() -> void:
	_aim_tell = MeshInstance3D.new()
	var from := global_position+Vector3.UP*1.9
	var to := target.global_position+Vector3.UP
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.035,0.035,from.distance_to(to))
	_aim_tell.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1,0.15,0.03)
	_aim_tell.material_override = material
	get_parent().add_child(_aim_tell)
	_aim_tell.global_position = (from+to)*0.5
	_aim_tell.look_at(to)

func _clear_aim_tell() -> void:
	if is_instance_valid(_aim_tell): _aim_tell.queue_free()
	_aim_tell = null

func _fire_radial(offset: float) -> void:
	for i in 12:
		var angle := i * TAU / 12.0 + offset
		var bullet := WrathRicochet.launch(get_parent(), global_position + Vector3.UP * 1.4 + Vector3(sin(angle), 0, cos(angle)) * 1.5, Vector3(sin(angle), 0, cos(angle)), self, 9.0 * realm_damage_scale, 17.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _on_died(source: Node) -> void:
	if state == State.DEAD:
		return
	super._on_died(source)
	_clear_bullets()
	if is_instance_valid(arena) and arena.has_method("set_deprivation"):
		arena.call("set_deprivation", true)
	realm_defeated.emit(2)

func _clear_bullets() -> void:
	_clear_aim_tell()
	for reference in _owned_bullets:
		var bullet := reference.get_ref() as Node
		if is_instance_valid(bullet):
			bullet.queue_free()
	_owned_bullets.clear()

func _exit_tree() -> void:
	_clear_bullets()
