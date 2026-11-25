class_name FearOculus
extends Enemy
signal defeated
signal phase_changed(new_phase: int)

const BASE_HEALTH := 1500.0
## Dais and island centres: the eye folds between them, never over the void.
const BLINK_ANCHORS := [
	Vector3(0, 0, -8), Vector3(-7, 0, -8), Vector3(7, 0, -8),
	Vector3(-7, 0, 8), Vector3(7, 0, 8),
]
const WISP := preload("res://actors/enemy/fear/fear_wisp.tscn")
const MAX_WISPS := 2
const BLINK_MIN_PLAYER_GAP := 6.0
const BLINK_MIN_MOVE := 4.0
const GAZE_SWEEP_DEG := 65.0
const GAZE_TICK := 0.20
const GAZE_DAMAGE := 11.0
## cos(25 deg): the cone inside which the player is meeting the pupil.
const GAZE_LOCK_DOT := 0.9063
const GAZE_PARALYSIS_TIME := 0.6
const GAZE_PARALYSIS_MOVE := 0.62
const BEAM_DAMAGE := 22.0
const BEAM_ACTIVE_TIME := 1.2
const RING_ACTIVE_TIME := 1.5
const SNIPER_SPEED := 34.0
const SNIPER_DAMAGE := 16.0
const RING_SPEED := 16.5
const RING_DAMAGE := 12.0
const BRIDGE_INTERVAL := 6.0

@export var realm_damage_scale := 1.0
@export var warnings_enabled := true:
	set(value):
		warnings_enabled = value
		if not value and is_instance_valid(_alarm):
			_alarm.stop()
		if not value and is_instance_valid(_beam) and phase == 0:
			_beam.hide()
var arena: Node3D
var visual: FearOculusVisual
var phase := 0 # 0 windup, 1 active, 2 exposed recovery
var phase_time := 0.0
var attack_kind := 0
var attack_count := 0
## Live-play teleport switch. Unit tests drive advance_attack() by hand and
## keep their fixed coordinates: only try_blink() or a live cycle moves the eye.
var blink_enabled := true
var blink_count := 0
var gaze_punishments := 0
var boss_phase := 1
var _live_combat := false
var _blink_on_cycle := true
var _bridge_timer := BRIDGE_INTERVAL
var _damage_tick := 0.0
var _locked_direction := Vector3.FORWARD
var _beam: MeshInstance3D
var _beam_mesh: CylinderMesh
var _beam_material: StandardMaterial3D
var _projectiles: Array[WeakRef] = []
var _wisps: Array[WeakRef] = []
var _stock: Array[FearWisp] = []
var _alarm: AudioStreamPlayer3D
var _started := false
var _second_ring_left := -1.0

func _ready() -> void:
	enable_crystal_feedback(1)
	is_boss = true
	collision_layer = CollisionLayers.ENEMIES
	collision_mask = CollisionLayers.WORLD
	visual = $Model as FearOculusVisual
	health.max_health = BASE_HEALTH
	health.health = health.max_health
	health.headshot_multiplier = 1.5
	health.before_damage.connect(_before_damage)
	health.died.connect(_on_died)
	health.after_damage.connect(_on_phase_damage)
	_hitbox_rids.append(get_rid())
	for node in find_children("*", "Hitbox", true, false):
		_hitbox_rids.append((node as Hitbox).get_rid())
	_beam = MeshInstance3D.new()
	_beam_mesh = CylinderMesh.new()
	_beam_mesh.radial_segments = 10
	_beam.mesh = _beam_mesh
	_beam_material = StandardMaterial3D.new()
	_beam_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_material.albedo_color = Color(0.6, 0.12, 1.0, 0.7)
	_beam_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_material.emission_enabled = true
	_beam_material.emission = Color(0.5, 0.1, 1.0)
	_beam_material.emission_energy_multiplier = 3.0
	_beam.material_override = _beam_material
	add_child(_beam)
	_beam.hide()
	_alarm = AudioStreamPlayer3D.new()
	_alarm.stream = ProceduralAudio.generate("enemy_shot")
	_alarm.pitch_scale = 0.55
	_alarm.volume_db = -5
	add_child(_alarm)
	FearWisp.prepare_visuals()
	for index in MAX_WISPS:
		_reserve_wisp()
	Events.enemy_registered.emit(self)

func _process(_delta: float) -> void:
	if state == State.DEAD or health.is_dead():
		return
	if _stock.size() + living_wisps().size() < MAX_WISPS:
		_reserve_wisp()

func setup(p_target: CharacterBody3D, p_cover_points: Array[CoverPoint], p_firing_board: FiringPositionBoard = null) -> void:
	super.setup(p_target, p_cover_points, p_firing_board)
	state = State.ENGAGE
	start_attack(0)

func start_attack(kind: int) -> bool:
	if health.is_dead() or not is_instance_valid(target):
		return false
	if kind == 3:
		return _summon_wisps()
	attack_kind = kind % 3
	phase = 0
	phase_time = 0.0
	_damage_tick = 0.0
	_started = true
	_locked_direction = (target.global_position + Vector3.UP * 1.1 - eye_position()).normalized()
	if warnings_enabled:
		_alarm.play()
	return true

func _physics_process(delta: float) -> void:
	if get_tree().paused or not _started or health.is_dead() or boon_stunned or boon_time_scale <= 0.0:
		return
	if not is_instance_valid(target) or (target.get_node("Health") as Health).is_dead():
		_beam.hide()
		return
	_live_combat = true
	var scaled := delta * boon_time_scale
	_bridge_timer -= scaled
	if _bridge_timer <= 0.0:
		_bridge_timer = BRIDGE_INTERVAL
		flip_bridge_near_player()
	advance_attack(scaled)

func advance_attack(delta: float) -> void:
	if get_tree().paused or health.is_dead() or not is_instance_valid(target):
		return
	if _second_ring_left > 0.0:
		_second_ring_left -= delta
		if _second_ring_left <= 0.0:
			_second_ring_left = -1.0
			_release_offset_ring()
	phase_time += delta
	visual.charge = minf(1.0, phase_time / windup()) if phase == 0 and warnings_enabled else 0.1
	_face_target(delta)
	match phase:
		0:
			if phase_time < windup() - 0.4:
				_locked_direction = (target.global_position + Vector3.UP * 1.1 - eye_position()).normalized()
			_beam.visible = warnings_enabled and attack_kind != 2
			set_beam(_locked_direction, 0.025 if attack_kind == 1 else 2.0, 34.0)
			if phase_time >= windup():
				phase = 1
				phase_time = 0.0
				attack_count += 1
				if attack_kind == 2:
					release_ring()
		1:
			_damage_tick -= delta
			var sweep_half := GAZE_SWEEP_DEG if attack_kind == 0 else 22.0
			var sweep := deg_to_rad(lerpf(-sweep_half, sweep_half, phase_time / active_duration()))
			var direction := Quaternion(Vector3.UP, sweep) * _locked_direction
			_beam.visible = attack_kind != 2
			set_beam(direction, 7.4 if attack_kind == 0 else 0.2, 38.0)
			if attack_kind != 2 and _damage_tick <= 0:
				_damage_tick = GAZE_TICK if attack_kind == 0 else 0.28
				if attack_kind == 0:
					scan_damage(direction)
				else:
					beam_damage(direction)
			if phase_time >= active_duration():
				if attack_kind == 1 and boss_phase >= 2:
					_fire_sniper(direction)
				phase = 2
				phase_time = 0.0
				_beam.hide()
		2:
			visual.charge = 0.85
			var recovery := 1.05 if boss_phase >= 2 else 1.2
			if phase_time >= recovery / maxf(effective_attack_scale(), 0.1):
				if _live_combat and blink_enabled and _blink_on_cycle and attack_count >= 1:
					try_blink()
				start_attack((attack_kind + 1) % 3)

func windup() -> float:
	return [1.4, 1.25, 1.1][attack_kind] * effective_windup_scale()

func active_duration() -> float:
	return BEAM_ACTIVE_TIME if attack_kind == 1 else RING_ACTIVE_TIME

func eye_position() -> Vector3:
	return global_position + Vector3.UP * 5.3

func _face_target(delta: float) -> void:
	if not is_instance_valid(visual):
		return
	var offset := target.global_position - global_position
	offset.y = 0.0
	if offset.length_squared() < 0.0001:
		return
	visual.rotation.y = lerp_angle(visual.rotation.y, atan2(offset.x, offset.z), minf(delta * 3.0, 1.0))

func scan_damage(direction: Vector3) -> void:
	var offset := target.global_position + Vector3.UP - eye_position()
	if offset.length() > 38 or direction.dot(offset.normalized()) < cos(deg_to_rad(11)):
		return
	var ray := PhysicsRayQueryParameters3D.create(eye_position(), target.global_position + Vector3.UP, CollisionLayers.WORLD)
	if get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		(target.get_node("Health") as Health).apply_damage(GAZE_DAMAGE * realm_damage_scale, Hitbox.BodyPart.BODY, self, {"tag": &"oculus_gaze"})
		_punish_gaze()

func _punish_gaze() -> void:
	var camera := target.get_node_or_null("Head/Camera3D") as Camera3D
	if camera == null:
		return
	var offset := eye_position() - camera.global_position
	if offset.length() < 0.01 or offset.length() > 45.0:
		return
	if (-camera.global_basis.z).dot(offset.normalized()) < GAZE_LOCK_DOT:
		return
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, eye_position(), CollisionLayers.WORLD)
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return
	if target.has_method("set_realm_effect"):
		target.call("set_realm_effect", &"oculus_gaze", {"owner": self, "duration": GAZE_PARALYSIS_TIME, "move_multiplier": GAZE_PARALYSIS_MOVE})
		gaze_punishments += 1

func beam_damage(direction: Vector3) -> void:
	var ray := PhysicsRayQueryParameters3D.create(eye_position(), eye_position() + direction * 42, CollisionLayers.WORLD | CollisionLayers.HITBOXES, _hitbox_rids)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		set_beam(direction, 0.2, eye_position().distance_to(hit.position))
		if hit.collider is Hitbox:
			(hit.collider as Hitbox).apply_hit_at(BEAM_DAMAGE * realm_damage_scale, self, hit.position, direction, false, {"tag": &"oculus_beam"})

func release_ring() -> void:
	for index in 24:
		var angle := TAU * index / 24.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var bullet := Projectile.spawn(get_parent(), global_position + Vector3.UP * 1.1 + direction * 1.0,
			direction, self, RING_DAMAGE * realm_damage_scale, RING_SPEED, _hitbox_rids, Color(0.6, 0.2, 0.95))
		_projectiles.append(weakref(bullet))
	if boss_phase >= 2:
		_second_ring_left = 0.35
	_summon_wisps()
	flip_bridge_near_player()

func _release_offset_ring() -> void:
	for index in 12:
		var angle := TAU * (float(index) + 0.5) / 12.0
		var direction := Vector3(sin(angle), 0, cos(angle))
		var bullet := Projectile.spawn(get_parent(), global_position + Vector3.UP * 1.1 + direction * 1.0,
			direction, self, RING_DAMAGE * realm_damage_scale, RING_SPEED, _hitbox_rids, Color(0.6, 0.2, 0.95))
		_projectiles.append(weakref(bullet))

func _fire_sniper(direction: Vector3) -> void:
	var bullet := Projectile.spawn(get_parent(), eye_position() + direction * 1.0, direction, self,
		SNIPER_DAMAGE * realm_damage_scale, SNIPER_SPEED, _hitbox_rids, Color(0.66, 0.32, 1.0))
	_projectiles.append(weakref(bullet))

func _summon_wisps() -> bool:
	if health.is_dead() or not is_instance_valid(target):
		return false
	var live := living_wisps()
	_wisps.clear()
	for wisp in live:
		_wisps.append(weakref(wisp))
	var missing := MAX_WISPS - live.size()
	var released := 0
	for slot in missing:
		var offset := Vector3((slot - (missing - 1) * 0.5) * 1.2, 1.6, 1.1)
		var point := global_transform * offset
		var query := PhysicsShapeQueryParameters3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = 0.45
		query.shape = sphere
		query.transform.origin = point
		query.collision_mask = CollisionLayers.WORLD
		if not get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty():
			continue
		if _stock.is_empty():
			_reserve_wisp()
		var wisp := _stock.pop_back() as FearWisp
		wisp.activate(point, self, target)
		_wisps.append(weakref(wisp))
		released += 1
	return released > 0

func _reserve_wisp() -> void:
	var wisp := WISP.instantiate() as FearWisp
	wisp.dormant = true
	wisp.summoner = weakref(self)
	get_parent().add_child(wisp)
	_stock.append(wisp)

func living_wisps() -> Array[FearWisp]:
	var result: Array[FearWisp] = []
	for reference in _wisps:
		var wisp := reference.get_ref() as FearWisp
		if is_instance_valid(wisp) and not wisp.is_queued_for_deletion() and not wisp.health.is_dead():
			result.append(wisp)
	return result

func try_blink() -> bool:
	if not blink_enabled or health.is_dead() or not _started or not is_instance_valid(target):
		return false
	var point := _blink_target()
	if point == Vector3.INF:
		return false
	if is_instance_valid(visual):
		visual.spawn_ghost()
	global_position = point
	velocity = Vector3.ZERO
	reset_physics_interpolation()
	_locked_direction = (target.global_position + Vector3.UP * 1.1 - eye_position()).normalized()
	_beam.hide()
	blink_count += 1
	return true

func _blink_target() -> Vector3:
	var best := Vector3.INF
	var best_gap := -1.0
	for anchor in BLINK_ANCHORS:
		if anchor.distance_to(global_position) < BLINK_MIN_MOVE:
			continue
		var gap := Vector2(anchor.x - target.global_position.x, anchor.z - target.global_position.z).length()
		if gap < BLINK_MIN_PLAYER_GAP or gap <= best_gap:
			continue
		var point := _supported_anchor(anchor)
		if point == Vector3.INF:
			continue
		best = point
		best_gap = gap
	return best

func _supported_anchor(anchor: Vector3) -> Vector3:
	var ray := PhysicsRayQueryParameters3D.create(anchor + Vector3.UP * 2.0, anchor - Vector3.UP * 2.0, CollisionLayers.WORLD)
	var support := get_world_3d().direct_space_state.intersect_ray(ray)
	if support.is_empty() or support.normal.y < 0.7:
		return Vector3.INF
	return support.position + Vector3.UP * 0.02

func flip_bridge_near_player() -> bool:
	if health.is_dead() or not is_instance_valid(target) or not is_instance_valid(arena):
		return false
	if not arena.has_method("flip_tile_near"):
		return false
	return bool(arena.call("flip_tile_near", target.global_position))

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
	phase_changed.emit(2)

func set_beam(direction: Vector3, radius: float, distance: float) -> void:
	_beam_mesh.top_radius = radius
	_beam_mesh.bottom_radius = 0.04 if attack_kind == 0 else radius
	_beam_mesh.height = distance
	_beam.global_position = eye_position() + direction * distance * 0.5
	var right := direction.cross(Vector3.FORWARD)
	if right.length_squared() < 0.001:
		right = direction.cross(Vector3.RIGHT)
	right = right.normalized()
	_beam.global_basis = Basis(right, direction, right.cross(direction).normalized())

func _before_damage(context: Dictionary) -> void:
	# The open pupil rewards the recovery window without making a build unwinnable.
	if phase != 2 and not context.get("true_damage", false):
		context.damage *= 0.4

func _on_died(_source: Node) -> void:
	if state == State.DEAD:
		return
	state = State.DEAD
	_started = false
	_live_combat = false
	_second_ring_left = -1.0
	_beam.hide()
	_alarm.stop()
	collision_layer = 0
	for box in find_children("*", "Hitbox", true, false):
		(box as Hitbox).collision_layer = 0
	_free_projectiles()
	_dismiss_wisps()
	_free_stock()
	if is_instance_valid(visual):
		visual.clear_ghosts()
	visual.shatter()
	if is_instance_valid(arena) and arena.has_method("set_deprivation"):
		arena.call("set_deprivation", true)
	Events.enemy_killed.emit(self)
	defeated.emit()

func _exit_tree() -> void:
	_free_projectiles()
	_dismiss_wisps()
	_free_stock()
	if is_instance_valid(visual):
		visual.clear_ghosts()
	if is_instance_valid(_alarm):
		_alarm.stop()
		_alarm.stream = null

func _free_projectiles() -> void:
	for item in _projectiles:
		var bullet := item.get_ref() as Projectile
		if is_instance_valid(bullet):
			bullet.queue_free()
	_projectiles.clear()

func _dismiss_wisps() -> void:
	for wisp in living_wisps():
		wisp.dismiss()
	_wisps.clear()

func _free_stock() -> void:
	for wisp in _stock:
		if is_instance_valid(wisp):
			wisp.queue_free()
	_stock.clear()

func set_boon_animation_scale(_value: float) -> void:
	pass
