class_name WrathSpire
extends WrathRealmEnemy
## Relentless pressure: it closes distance, retaliates on every hit and turns
## charges into wall-slam shrapnel. Each attack keeps a locked telegraph,
## active period and a gun/blade punish window.
signal realm_defeated(realm_id: int)
signal phase_changed(new_phase: int)
enum Move { VORTEX, FISSURE, SHRAPNEL, VOLLEY, ERUPTION }

const BASE_HEALTH := 1450.0
const BASE_RUN_SPEED := 5.6
const PHASE2_RUN_SPEED := 7.0
const APPROACH_DELAY := 0.25
const RECOVER_PHASE1 := 0.85
const RECOVER_PHASE2 := 1.15
const RAGE_MAX := 100.0
const RAGE_PER_DAMAGE := 0.42
const RAGE_WAVE_RADIUS := 22.0
const RAGE_WAVE_SPEED := 18.0
const RAGE_WAVE_DAMAGE := 14.0
const RAGE_SHARDS := 8
const RAGE_WINDUP := 0.65
const VORTEX_RANGE := 16.0
const VORTEX_SPEED := 14.0
const VORTEX_SPEED_PHASE2 := 16.5
const VORTEX_DASH_TIME := 1.8
const VORTEX_PHASE2_DASHES := 2
const VOLLEY_TRACK_BLEND := 0.55
const WALL_SHARD_SPREAD := [-0.45, -0.27, -0.09, 0.09, 0.27, 0.45]
const NEAR_MOVES: Array[int] = [Move.VORTEX, Move.SHRAPNEL, Move.ERUPTION]
const FAR_MOVES: Array[int] = [Move.VOLLEY, Move.FISSURE, Move.ERUPTION]

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
var _rage_tell: MeshInstance3D
var _rage_primed := false
var boss_phase := 1
var rage := 0.0
var rage_bursts := 0
var wall_slams := 0
var _dashes_left := 0
var _wall_burst_ready := false
var _move_cursor := 0

func _enter_tree() -> void:
	variant = Variant.AGGRESSOR
	is_boss = true
	super._enter_tree()

func _ready() -> void:
	super._ready()
	health.max_health = BASE_HEALTH
	health.health = health.max_health
	health.headshot_multiplier = 1.3
	attack_phase = Attack.APPROACH
	attack_left = APPROACH_DELAY
	_base_run_speed = BASE_RUN_SPEED
	_refresh_tempo_speed()
	health.after_damage.connect(_on_phase_damage)
	health.after_damage.connect(_on_rage_damage)

func _on_phase_damage(_context: Dictionary) -> void:
	if boss_phase != 1 or health.is_dead():
		return
	if health.health > health.max_health * 0.50:
		return
	boss_phase = 2
	boss_phase_tempo_scale = 1.20
	health.max_shield = roundf(health.max_health * 0.15)
	health.shield_points = health.max_shield
	health.shield_regeneration_rate = 0.0
	health.shield_changed.emit(health.shield_points)
	_base_run_speed = PHASE2_RUN_SPEED
	_refresh_tempo_speed()
	phase_changed.emit(2)

func _on_rage_damage(context: Dictionary) -> void:
	if state == State.DEAD or health.is_dead():
		return
	if not (context.get("source") is Player):
		return
	var taken := float(context.get("resolved_damage", 0.0))
	if taken <= 0.0:
		return
	rage = minf(RAGE_MAX, rage + taken * RAGE_PER_DAMAGE)

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
	var missing := 1.0 - clampf(health.health / maxf(health.max_health, 1.0), 0.0, 1.0)
	model.speed_factor = 1.0 + rage / RAGE_MAX * 2.4 + missing * 2.0 + (6.0 if attack_phase == Attack.RUSH else 0.0)
	model.molten = clampf(rage / RAGE_MAX * 0.65 + missing * 0.55, 0.0, 1.0)
	model.telegraph = 1.0 if warnings_enabled and attack_phase == Attack.WINDUP else 0.0
	if is_instance_valid(_aim_tell):
		_aim_tell.visible = warnings_enabled and attack_phase == Attack.WINDUP
	if is_instance_valid(_rage_tell):
		_rage_tell.visible = warnings_enabled and _rage_primed and attack_phase == Attack.WINDUP
	if attack_phase == Attack.APPROACH:
		_pursue_target(delta, flat)
		if rage >= RAGE_MAX:
			_prime_rage_burst()
		elif attack_left <= 0:
			begin_move(move_kind)
	elif attack_phase == Attack.WINDUP:
		_stop()
		if attack_left <= 0:
			attack_phase = Attack.RUSH
			phase_elapsed = 0
			_burst_done = false
			_clear_aim_tell()
			if _rage_primed:
				_rage_primed = false
				_release_rage_burst()
			if move_kind == Move.VORTEX:
				_dashes_left = VORTEX_PHASE2_DASHES if boss_phase >= 2 else 1
				_start_vortex_dash(false)
			else:
				attack_left = 0.8
				if move_kind == Move.FISSURE:
					var offsets := [-0.64,-0.32,0.0,0.32,0.64] if boss_phase >= 2 else [-0.42,0.0,0.42]
					for offset in offsets:
						var wave := WrathShockwave.new()
						wave.source = self
						wave.target = target
						wave.max_radius = 27
						wave.half_angle = 0.24
						wave.direction = locked_direction.rotated(Vector3.UP, offset)
						wave.damage = 15 * realm_damage_scale
						wave.speed = 24
						get_parent().add_child(wave)
						wave.global_position = global_position
						spawned_waves += 1
				elif move_kind == Move.SHRAPNEL:
					_fire_radial(0.0)
				elif move_kind == Move.VOLLEY:
					_fire_volley()
	elif attack_phase == Attack.RUSH:
		if move_kind == Move.VORTEX:
			var dash_speed := VORTEX_SPEED_PHASE2 if boss_phase >= 2 else VORTEX_SPEED
			velocity.x = locked_direction.x * dash_speed
			velocity.z = locked_direction.z * dash_speed
			if flat.length() < 3.3 and _pulse_left <= 0 and _line_clear(target.global_position + Vector3.UP):
				_pulse_left = 0.45
				var hp := target.get_node_or_null("Health") as Health
				if hp != null:
					hp.apply_damage(13 * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"spire_vortex"})
				if target.has_method("apply_external_impulse"):
					target.call("apply_external_impulse", flat.normalized(), 9.0, 0.2)
			if attack_left <= 0:
				if _dashes_left > 1:
					_dashes_left -= 1
					_start_vortex_dash(true)
				else:
					_enter_recover()
		else:
			_stop()
			while move_kind == Move.VOLLEY and _volley_count < 3 and phase_elapsed >= _volley_count*0.28:
				if _volley_count >= 1:
					_track_volley()
				_fire_volley()
			if move_kind == Move.SHRAPNEL and phase_elapsed >= 0.35 and not _burst_done:
				_burst_done = true
				_fire_radial(PI / 12.0)
			if attack_left <= 0:
				_enter_recover()
	else:
		_stop()
		if attack_left <= 0:
			cycle_count += 1
			if rage >= RAGE_MAX:
				_prime_rage_burst()
			else:
				move_kind = _select_move(flat.length())
				attack_phase = Attack.APPROACH
				attack_left = APPROACH_DELAY
	_boon_move_and_slide()
	if attack_phase == Attack.RUSH and move_kind == Move.VORTEX:
		_check_wall_slam()

func _pursue_target(delta: float, flat: Vector3) -> void:
	_face(flat, delta)
	_move_to(target.global_position, run_speed)
	if Vector2(velocity.x, velocity.z).length_squared() < 0.01 and flat.length() > 0.75:
		var direction := flat.normalized()
		velocity.x = direction.x * run_speed
		velocity.z = direction.z * run_speed
	visual.play_motion("walk")

func _start_vortex_dash(relock: bool) -> void:
	if relock and _has_live_target():
		locked_direction = ((target.global_position - global_position) * Vector3(1, 0, 1)).normalized()
		_face(locked_direction, 1.0)
	attack_left = VORTEX_DASH_TIME
	_wall_burst_ready = true

func _enter_recover() -> void:
	attack_phase = Attack.RECOVER
	attack_left = RECOVER_PHASE2 if boss_phase >= 2 else RECOVER_PHASE1
	_dashes_left = 0
	_wall_burst_ready = false

func _select_move(distance: float) -> int:
	var moves: Array[int] = NEAR_MOVES if distance <= 11.0 else FAR_MOVES
	for offset in moves.size():
		var index := (_move_cursor + offset) % moves.size()
		var candidate: int = moves[index]
		if candidate != move_kind:
			_move_cursor = (index + 1) % moves.size()
			return candidate
	return moves[_move_cursor % moves.size()]

func begin_move(kind: int) -> void:
	if not _has_live_target() or state == State.DEAD:
		return
	var distance := target.global_position.distance_to(global_position)
	move_kind = Move.VOLLEY if kind == Move.VORTEX and distance > VORTEX_RANGE else kind
	locked_direction = ((target.global_position - global_position) * Vector3(1, 0, 1)).normalized()
	_locked_aim = (target.global_position+Vector3.UP*1.0-(global_position+Vector3.UP*1.9)).normalized()
	attack_phase = Attack.WINDUP
	attack_left = (0.95 if move_kind == Move.ERUPTION else 1.1) * boon_windup_scale
	phase_elapsed = 0
	_volley_count = 0
	_dashes_left = 0
	_wall_burst_ready = false
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

func _track_volley() -> void:
	if not _has_live_target():
		return
	var desired := (target.global_position+Vector3.UP*1.0-(global_position+Vector3.UP*1.9)).normalized()
	_locked_aim = _locked_aim.slerp(desired, VOLLEY_TRACK_BLEND).normalized()

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
	if is_instance_valid(_rage_tell): _rage_tell.queue_free()
	_rage_tell = null

func _show_rage_tell() -> void:
	if is_instance_valid(_rage_tell):
		_rage_tell.queue_free()
	_rage_tell = MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = 2.6
	mesh.outer_radius = 3.1
	mesh.rings = 32
	mesh.ring_segments = 4
	_rage_tell.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(1.0, 0.22, 0.04, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_rage_tell.material_override = material
	add_child(_rage_tell)
	_rage_tell.position = Vector3(0, 0.22, 0)
	_rage_tell.visible = warnings_enabled

func _prime_rage_burst() -> void:
	if not _has_live_target() or state == State.DEAD:
		return
	rage = 0.0
	_rage_primed = true
	begin_move(Move.VORTEX)
	attack_left = RAGE_WINDUP * boon_windup_scale
	if warnings_enabled:
		_show_rage_tell()

func _fire_radial(offset: float) -> void:
	for i in 12:
		var angle := i * TAU / 12.0 + offset
		var bullet := WrathRicochet.launch(get_parent(), global_position + Vector3.UP * 1.4 + Vector3(sin(angle), 0, cos(angle)) * 1.5, Vector3(sin(angle), 0, cos(angle)), self, 9.0 * realm_damage_scale, 21.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _fire_rage_radial() -> void:
	for i in RAGE_SHARDS:
		var angle := i * TAU / float(RAGE_SHARDS)
		var direction := Vector3(sin(angle), 0, cos(angle))
		var bullet := WrathRicochet.launch(get_parent(), global_position + Vector3.UP * 1.4 + direction * 1.6, direction, self, 10.0 * realm_damage_scale, 21.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _release_rage_burst() -> void:
	if not _has_live_target() or state == State.DEAD:
		return
	rage = 0.0
	rage_bursts += 1
	var wave := WrathShockwave.new()
	wave.source = self
	wave.target = target
	wave.max_radius = RAGE_WAVE_RADIUS
	wave.speed = RAGE_WAVE_SPEED
	wave.damage = RAGE_WAVE_DAMAGE * realm_damage_scale
	get_parent().add_child(wave)
	wave.global_position = global_position
	spawned_waves += 1
	_fire_rage_radial()

func _check_wall_slam() -> void:
	if not _wall_burst_ready:
		return
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		var object := collision.get_collider() as CollisionObject3D
		if object == null or not (object.collision_layer & CollisionLayers.WORLD):
			continue
		var normal := collision.get_normal()
		if absf(normal.y) >= 0.5:
			continue
		_slam_wall(collision.get_position(), normal)
		return

func _slam_wall(point: Vector3, normal: Vector3) -> void:
	_wall_burst_ready = false
	wall_slams += 1
	var outward := Vector3(normal.x, 0.0, normal.z).normalized()
	if outward.is_zero_approx():
		outward = -locked_direction
	for angle: float in WALL_SHARD_SPREAD:
		var direction := outward.rotated(Vector3.UP, angle)
		var bullet := WrathRicochet.launch(get_parent(), point + normal*0.5 + Vector3.UP*0.9, direction, self, 10.0*realm_damage_scale, 19.0)
		_owned_bullets.append(weakref(bullet))
		spawned_bullets += 1

func _on_died(source: Node) -> void:
	if state == State.DEAD:
		return
	super._on_died(source)
	_clear_bullets()
	rage = 0.0
	_rage_primed = false
	_dashes_left = 0
	_wall_burst_ready = false
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
