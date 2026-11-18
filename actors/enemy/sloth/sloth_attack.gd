class_name SlothAttack
extends Node3D
## Volley aim follows during formation, then locks before release. Field/wave
## coordinates stay fixed. Scene pause freezes phases; cancel clears fields.

const LINGER_CHARGE_TIME := 2.0
const LINGER_LOCK_WARNING := 0.45
const LINGER_SHOT_SPEED := 40.0
const LINGER_VOLLEY_COUNT := 4
const LINGER_SHOT_INTERVAL := 0.18
const LINGER_SHOT_DAMAGE := 9.0
const LINGER_RELEASE_TAIL := 0.10
const LINGER_FORMATION_FORWARD := 0.45
const FIELD_RADIUS := 3.2
const FIELD_DURATION := 2.6
const WAVE_RADIUS := 7.0
const WAVE_SPEED := 9.0
const WAVE_DURATION := 0.95
const GAP_HALF_ANGLE := deg_to_rad(22.0)
const GOLD_CHARGE := Color(1.0, 0.63, 0.19, 0.72)
const GOLD_LOCK := Color(1.0, 0.89, 0.57, 0.95)
const GOLD_RELEASE := Color(1.0, 0.69, 0.24, 0.8)
const GOLD_PROJECTILE := Color("ffbc4f")
var kind := 0
var caster: SlothEnemy
var target: CharacterBody3D
var elapsed := 0.0
var phase := 0
var locked_direction := Vector3.FORWARD
var field_center := Vector3.ZERO
var _origin := Vector3.ZERO
var _volley: Array[Vector3] = []
var _volley_directions: Array[Vector3] = []
var _fins: Array[MeshInstance3D] = []
var aim_locked := false
var _released := 0
var _hit := false
var _cancelled := false
var _graphics: Node3D
var _ring: MeshInstance3D
var _time_field: SlothTimeField
var _orbs: Array[MeshInstance3D] = []
var _audio: AudioStreamPlayer3D
var _mat: StandardMaterial3D
var _detail_mat: StandardMaterial3D
var _last_radius := 0.0
var _ground_heights: Dictionary = {}
static var _cast_tone: AudioStreamWAV
static var _release_tone: AudioStreamWAV


func warning_time() -> float:
	return (LINGER_CHARGE_TIME if kind == 0 else 0.95) * (caster.boon_windup_scale if is_instance_valid(caster) else 1.0)


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_origin = caster.global_position + Vector3.UP * 1.42
	if kind == 0 and is_instance_valid(caster.visual.staff_tip):
		var tip := caster.visual.staff_tip.global_position
		if _clear_path(_origin,tip):
			_origin = tip
	field_center = target.global_position if kind == 1 else caster.global_position
	if caster.realm_encounter and kind != 0:
		field_center = SlothTimeField.floor_below(get_world_3d().direct_space_state, field_center)
	field_center.y += 0.065
	locked_direction = (target.global_position + Vector3.UP * Enemy.AIM_HEIGHT - _origin).normalized()
	_graphics = Node3D.new()
	add_child(_graphics)
	_graphics.visible = caster.warnings_enabled
	_mat = _material(GOLD_CHARGE if caster.realm_encounter else Color(0.18, 0.40, 0.62, 0.72))
	_detail_mat = _material(Color(1.0, 0.84, 0.52, 0.6) if caster.realm_encounter else Color(0.65, 0.79, 0.88, 0.6))
	if kind == 0:
		_build_volley()
	elif caster.realm_encounter:
		_time_field = SlothTimeField.new()
		_time_field.position = field_center
		_time_field.rotation.y = atan2(locked_direction.x, locked_direction.z)
		_time_field.recluse_wave = kind == 2
		_time_field.reach = WAVE_RADIUS if kind == 2 else FIELD_RADIUS
		_time_field.safe_half_angle = GAP_HALF_ANGLE
		_graphics.add_child(_time_field)
	else:
		_build_field()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _tone(false)
	_audio.position = _origin
	_audio.unit_size = 9.0
	_audio.volume_db = -8.0
	add_child(_audio)
	if caster.warnings_enabled:
		_audio.play()


func _physics_process(delta: float) -> void:
	if _cancelled:
		return
	if not is_instance_valid(caster) or caster.state == Enemy.State.DEAD \
			or caster.state == Enemy.State.FLEE or not is_instance_valid(target) \
			or (target is Player and target.health.is_dead()):
		cancel()
		return
	if caster.boon_stunned or caster.boon_time_scale <= 0.0:
		return
	delta *= caster.boon_time_scale * caster.boon_attack_scale
	elapsed += delta
	_graphics.visible = caster.warnings_enabled or (_time_field != null and elapsed >= warning_time())
	if elapsed < warning_time():
		var progress := elapsed / warning_time()
		_mat.emission_energy_multiplier = 0.35 + progress * 0.5
		if kind == 0:
			if not aim_locked:
				_update_volley_aim(target.global_position + Vector3.UP * Enemy.AIM_HEIGHT)
				if elapsed >= warning_time() - LINGER_LOCK_WARNING:
					aim_locked = true
					_audio.pitch_scale = 1.4
					if caster.warnings_enabled:
						_audio.play()
			if caster.realm_encounter:
				_set_gold_color(GOLD_LOCK if aim_locked else GOLD_CHARGE)
			else:
				_mat.albedo_color = Color(0.75,0.9,1.0,0.95) if aim_locked else Color(0.18,0.40,0.62,0.65)
			caster.visual.set_mantle_open(smoothstep(0.45, 0.9, progress))
			caster.set_core_exposed(progress > 0.65)
			for orb in _orbs:
				orb.rotation += Vector3(0.0, 0.6, 0.0) * delta
				orb.scale = Vector3.ONE * (0.15 + progress * 1.25)
		else:
			if _time_field != null:
				_time_field.show_charge(progress)
			else:
				_ring.scale = Vector3.ONE
				_mat.albedo_color.a = 0.22 + progress * 0.45
			caster.visual.set_shell_open(progress if kind == 2 else 0.0)
			if kind == 2:
				caster.set_core_exposed(progress > 0.65)
		return
	if phase == 0:
		phase = 1
		if caster.realm_encounter:
			_set_gold_color(GOLD_RELEASE)
		else:
			_mat.albedo_color = Color(0.32, 0.62, 0.82, 0.8)
		_audio.pitch_scale = 1.0
		_audio.stream = _tone(true)
		_audio.play()
		if kind == 0:
			Events.gunshot.emit(_origin)
	var active_time := elapsed - warning_time()
	match kind:
		0:
			var projectile_color := GOLD_PROJECTILE if caster.realm_encounter else Color(0.40, 0.70, 0.90)
			while _released < LINGER_VOLLEY_COUNT and active_time >= float(_released) * LINGER_SHOT_INTERVAL:
				var from := _volley[_released]
				Projectile.spawn(caster.get_parent(), from, _volley_directions[_released], caster,
					LINGER_SHOT_DAMAGE * caster.realm_damage_scale, LINGER_SHOT_SPEED, caster._hitbox_rids, projectile_color)
				_orbs[_released].hide()
				_released += 1
			if active_time >= float(LINGER_VOLLEY_COUNT - 1) * LINGER_SHOT_INTERVAL + LINGER_RELEASE_TAIL:
				_finish()
		1:
			if _time_field != null:
				_time_field.show_active(active_time, FIELD_RADIUS, FIELD_DURATION)
			else:
				_ring.scale = Vector3.ONE
			_update_stasis()
			if active_time >= FIELD_DURATION:
				_finish()
		2:
			caster.visual.set_shell_open(1.0)
			var radius := minf(WAVE_RADIUS, active_time * WAVE_SPEED)
			if _time_field != null:
				_time_field.show_active(active_time, radius, WAVE_DURATION)
			else:
				_ring.scale = Vector3.ONE * maxf(0.02, radius / WAVE_RADIUS)
			_test_wave(radius)
			_last_radius = radius
			if active_time >= WAVE_DURATION:
				_finish()


func _set_gold_color(color: Color) -> void:
	_mat.albedo_color = color
	_mat.emission = color

func _update_stasis() -> void:
	if not target is Player:
		return
	var player := target as Player
	var offset := player.global_position - field_center
	if Vector2(offset.x, offset.z).length() <= FIELD_RADIUS \
			and absf(offset.y) < 1.5 and _clear_path(field_center + Vector3.UP * 0.5,
			player.global_position + Vector3.UP * 0.7):
		player.set_stasis_source(self, 0.75)
	else:
		player.clear_stasis_source(self)


func _test_wave(radius: float) -> void:
	if _hit or not is_instance_valid(target) or not target.has_node("Health"):
		return
	var player := target
	var offset := player.global_position - field_center
	var flat := Vector3(offset.x, 0.0, offset.z)
	var distance := flat.length()
	# Swept annulus, not a filled damage disk. Jumping over the low wave,
	# crossing the clearly open wedge, cover and the existing dash all work.
	if distance > WAVE_RADIUS or distance < _last_radius - 0.45 or distance > radius + 0.45 \
			or offset.y > 0.28 or offset.y < -0.85:
		return
	var safe_direction := Vector3(locked_direction.x, 0.0, locked_direction.z).normalized()
	if flat.normalized().dot(safe_direction) >= cos(GAP_HALF_ANGLE):
		return
	if not _clear_path(field_center + Vector3.UP * 0.45,
			player.global_position + Vector3.UP * 0.45):
		return
	_hit = true
	(player.get_node("Health") as Health).apply_damage(14.0 * caster.realm_damage_scale, Hitbox.BodyPart.BODY, caster)


func _clear_path(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func cancel() -> void:
	if is_instance_valid(caster) and is_instance_valid(caster.visual):
		caster.visual.set_mantle_open(0.0)
	if _cancelled:
		return
	_cancelled = true
	if is_instance_valid(caster) and caster.active_attack == self:
		caster.active_attack = null
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null
	phase = 2
	_clear_stasis()
	if is_instance_valid(_graphics):
		_graphics.hide()
	set_physics_process(false)
	queue_free()


func _finish() -> void:
	if is_instance_valid(caster):
		caster.attack_finished()
	cancel()


func _clear_stasis() -> void:
	if is_instance_valid(target) and target is Player:
		target.clear_stasis_source(self)


func _exit_tree() -> void:
	_clear_stasis()
	if is_instance_valid(_audio):
		_audio.stop()
		_audio.stream = null


func _build_volley() -> void:
	var side := locked_direction.cross(Vector3.UP).normalized()
	var locked_point := target.global_position + Vector3.UP * Enemy.AIM_HEIGHT
	for i in LINGER_VOLLEY_COUNT:
		var lateral_offset := lerpf(-0.63, 0.63, float(i) / float(LINGER_VOLLEY_COUNT - 1))
		# Keep all four tells ahead of the chest instead of burying the inner pair
		# in the crystal/cloth. The WORLD ray still keeps them behind nearby cover.
		var from := _origin + locked_direction * LINGER_FORMATION_FORWARD + side * lateral_offset
		# Do not place a suspended projectile on the far side of a thin wall.
		if not _clear_path(_origin, from):
			from = _origin
		_volley.append(from)
		var direction := (locked_point - from).normalized()
		_volley_directions.append(direction)
		var orb := MeshInstance3D.new()
		var mesh := SphereMesh.new()
		mesh.radius = 0.075
		mesh.height = 0.30
		mesh.radial_segments = 4
		mesh.rings = 2
		orb.mesh = mesh
		orb.material_override = _mat
		orb.position = from
		orb.scale = Vector3.ONE * 0.15
		_graphics.add_child(orb)
		_orbs.append(orb)
		# Small chevrons announce the locked direction without long floating beams.
		for flank in [-1.0, 1.0]:
			var fin := MeshInstance3D.new()
			var marker := BoxMesh.new()
			marker.size = Vector3(0.012, 0.012, 0.18)
			_fins.append(fin)
			fin.mesh = marker
			fin.material_override = _detail_mat
			_graphics.add_child(fin)
			fin.position = from + direction * 0.25 + side * flank * 0.045
			fin.look_at(fin.position + direction)
			fin.rotate_y(flank * 0.4)


func _update_volley_aim(point: Vector3) -> void:
	locked_direction = (point - _origin).normalized()
	var side := locked_direction.cross(Vector3.UP).normalized()
	for i in _volley.size():
		var direction := (point - _volley[i]).normalized()
		_volley_directions[i] = direction
		for j in 2:
			var flank := -1.0 if j == 0 else 1.0
			var fin := _fins[i * 2 + j]
			fin.position = _volley[i] + direction * 0.25 + side * flank * 0.045
			fin.look_at(fin.position + direction, Vector3.UP if absf(direction.y) < 0.99 else Vector3.RIGHT)
			fin.rotate_y(flank * 0.4)



func _build_field() -> void:
	var radius := FIELD_RADIUS if kind == 1 else WAVE_RADIUS
	var gap := 0.0 if kind == 1 else GAP_HALF_ANGLE
	var yaw := atan2(locked_direction.x, locked_direction.z)
	var outer := _annulus(radius - 0.06, radius, gap, yaw)
	outer.position = field_center
	outer.rotation.y = yaw
	_graphics.add_child(outer)
	_ring = _annulus(radius - (0.2 if kind == 1 else 0.24), radius, gap, yaw)
	_ring.position = field_center + Vector3.UP * 0.018
	_ring.rotation.y = yaw
	_graphics.add_child(_ring)
	# Discrete inward teeth distinguish a slowing field from the moving wave.
	for i in (16 if kind == 1 else 22):
		var angle := TAU * float(i) / (16.0 if kind == 1 else 22.0)
		if kind == 2 and minf(angle, TAU - angle) < gap:
			continue
		var mark := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.07, 0.035, 0.32)
		mark.mesh = box
		mark.material_override = _detail_mat
		mark.position = _project_mark_to_ground(field_center + Vector3(sin(angle + yaw), 0.0, cos(angle + yaw)) * (radius - 0.3)) + Vector3.UP * 0.02
		mark.rotation.y = angle + yaw
		_graphics.add_child(mark)
	if kind == 2:
		for sign_value in [-1.0, 1.0]:
			var edge := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(0.06, 0.03, radius)
			edge.mesh = box
			edge.material_override = _detail_mat
			var angle: float = yaw + gap * sign_value
			edge.position = _project_mark_to_ground(field_center + Vector3(sin(angle), 0.0, cos(angle)) * radius * 0.5) + Vector3.UP * 0.03
			edge.rotation.y = angle
			_graphics.add_child(edge)


func _project_mark_to_ground(point: Vector3) -> Vector3:
	# Sample each unique point once at construction, not every physics frame.
	# A short WORLD-only ray stays on the caster/target's current storey; a bridge
	# far above or another court far below must not move this tell to that floor.
	var key := Vector2(point.x, point.z)
	if _ground_heights.has(key):
		return Vector3(point.x, float(_ground_heights[key]), point.z)
	var height := point.y
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0,
		point - Vector3.UP * 6.0, CollisionLayers.WORLD)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and absf(hit.position.y - field_center.y) < 1.5:
		height = hit.position.y + 0.065
	_ground_heights[key] = height
	return Vector3(point.x, height, point.z)


func _annulus(inner: float, outer: float, gap: float, yaw := 0.0) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a := gap + (TAU - gap * 2.0) * float(i) / 96.0
		var b := gap + (TAU - gap * 2.0) * float(i + 1) / 96.0
		var points := [Vector3(sin(a) * inner, 0, cos(a) * inner),
			Vector3(sin(a) * outer, 0, cos(a) * outer),
			Vector3(sin(b) * outer, 0, cos(b) * outer),
			Vector3(sin(b) * inner, 0, cos(b) * inner)]
		for j in points.size():
			var world_point := field_center + (points[j] as Vector3).rotated(Vector3.UP, yaw)
			points[j].y = _project_mark_to_ground(world_point).y - field_center.y
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_normal(Vector3.UP)
			surface.add_vertex(points[index])
	var result := MeshInstance3D.new()
	result.mesh = surface.commit()
	result.material_override = _mat
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


static func _material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = 0.55
	return material


static func prepare_audio() -> void:
	_tone(false)
	_tone(true)


static func _tone(release: bool) -> AudioStreamWAV:
	var cached := _release_tone if release else _cast_tone
	if cached != null:
		return cached
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var duration := 0.24 if release else 0.7
	var frames := int(22050.0 * duration)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	for i in frames:
		var t := float(i) / 22050.0
		var frequency := 420.0 if release else 180.0
		var value := sin(TAU * (frequency * t + (50.0 if release else 170.0) * t * t))
		value *= sin(PI * t / duration) * (1.0 - t / duration) * 0.22
		bytes.encode_s16(i * 2, int(value * 32767.0))
	stream.data = bytes
	if release:
		_release_tone = stream
	else:
		_cast_tone = stream
	return stream
