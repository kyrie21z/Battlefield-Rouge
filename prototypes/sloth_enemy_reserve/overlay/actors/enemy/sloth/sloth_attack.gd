class_name SlothAttack
extends Node3D
## Volley aim follows during formation, then locks before release. Field/wave
## coordinates stay fixed. Scene pause freezes phases; cancel clears fields.

const LINGER_CHARGE_TIME := 2.0
const LINGER_LOCK_WARNING := 0.45
const LINGER_SHOT_SPEED := 40.0
const FIELD_RADIUS := 3.2
const WAVE_RADIUS := 7.0
const GAP_HALF_ANGLE := deg_to_rad(22.0)
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
var _orbs: Array[MeshInstance3D] = []
var _audio: AudioStreamPlayer3D
var _mat: StandardMaterial3D
var _detail_mat: StandardMaterial3D
var _last_radius := 0.0


func warning_time() -> float:
	return LINGER_CHARGE_TIME if kind == 0 else 0.95


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_origin = caster.global_position + Vector3.UP * 1.42
	field_center = target.global_position if kind == 1 else caster.global_position
	field_center.y += 0.065
	locked_direction = (target.global_position + Vector3.UP * Enemy.AIM_HEIGHT - _origin).normalized()
	_graphics = Node3D.new()
	add_child(_graphics)
	_mat = _material(Color(0.18, 0.40, 0.62, 0.72))
	_detail_mat = _material(Color(0.65, 0.79, 0.88, 0.6))
	if kind == 0:
		_build_volley()
	else:
		_build_field()
	_audio = AudioStreamPlayer3D.new()
	_audio.stream = _tone(false)
	_audio.position = _origin
	_audio.unit_size = 9.0
	_audio.volume_db = -8.0
	add_child(_audio)
	_audio.play()


func _physics_process(delta: float) -> void:
	if _cancelled:
		return
	if not is_instance_valid(caster) or caster.state == Enemy.State.DEAD \
			or caster.state == Enemy.State.FLEE or not is_instance_valid(target) \
			or (target is Player and target.health.is_dead()):
		cancel()
		return
	elapsed += delta
	if elapsed < warning_time():
		var progress := elapsed / warning_time()
		_mat.emission_energy_multiplier = 0.35 + progress * 0.5
		if kind == 0:
			if not aim_locked:
				_update_volley_aim(target.global_position + Vector3.UP * Enemy.AIM_HEIGHT)
				if elapsed >= warning_time() - LINGER_LOCK_WARNING:
					aim_locked = true
					_audio.pitch_scale = 1.4
					_audio.play()
			_mat.albedo_color = Color(0.75,0.9,1.0,0.95) if aim_locked else Color(0.18,0.40,0.62,0.65)
			caster.visual.set_mantle_open(smoothstep(0.45, 0.9, progress))
			caster.set_core_exposed(progress > 0.65)
			for orb in _orbs:
				orb.rotation += Vector3(0.0, 0.6, 0.0) * delta
				orb.scale = Vector3.ONE * (0.15 + progress * 1.25)
		else:
			_ring.scale = Vector3.ONE
			_mat.albedo_color.a = 0.22 + progress * 0.45
			caster.visual.set_shell_open(progress if kind == 2 else 0.0)
			if kind == 2:
				caster.set_core_exposed(progress > 0.65)
		return
	if phase == 0:
		phase = 1
		_mat.albedo_color = Color(0.32, 0.62, 0.82, 0.8)
		_audio.pitch_scale = 1.0
		_audio.stream = _tone(true)
		_audio.play()
		if kind == 0:
			Events.gunshot.emit(_origin)
	var active_time := elapsed - warning_time()
	match kind:
		0:
			while _released < 2 and active_time >= float(_released) * 0.18:
				var from := _volley[_released]
				Projectile.spawn(caster.get_parent(), from, _volley_directions[_released], caster,
					9.0, LINGER_SHOT_SPEED, caster._hitbox_rids, Color(0.40, 0.70, 0.90))
				_orbs[_released].hide()
				_released += 1
			if active_time >= 0.25:
				_finish()
		1:
			_ring.scale = Vector3.ONE
			_update_stasis()
			if active_time >= 2.6:
				_finish()
		2:
			caster.visual.set_shell_open(1.0)
			var radius := minf(WAVE_RADIUS, active_time * 9.0)
			_ring.scale = Vector3.ONE * maxf(0.02, radius / WAVE_RADIUS)
			_test_wave(radius)
			_last_radius = radius
			if active_time >= 0.95:
				_finish()


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
	if _hit or not target is Player:
		return
	var player := target as Player
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
	player.health.apply_damage(14.0, Hitbox.BodyPart.BODY, caster)


func _clear_path(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func cancel() -> void:
	if is_instance_valid(caster) and is_instance_valid(caster.visual):
		caster.visual.set_mantle_open(0.0)
	if _cancelled:
		return
	_cancelled = true
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


func _build_volley() -> void:
	var side := locked_direction.cross(Vector3.UP).normalized()
	var locked_point := target.global_position + Vector3.UP * Enemy.AIM_HEIGHT
	for i in 2:
		var from := _origin + side * (-0.42 if i == 0 else 0.42)
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
	var outer := _annulus(radius - 0.06, radius, gap)
	outer.position = field_center
	outer.rotation.y = yaw
	_graphics.add_child(outer)
	_ring = _annulus(radius - (0.2 if kind == 1 else 0.24), radius, gap)
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
		mark.position = field_center + Vector3(sin(angle + yaw), 0.0, cos(angle + yaw)) * (radius - 0.3) + Vector3.UP * 0.02
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
			edge.position = field_center + Vector3(sin(angle), 0.0, cos(angle)) * radius * 0.5 + Vector3.UP * 0.03
			edge.rotation.y = angle
			_graphics.add_child(edge)


func _annulus(inner: float, outer: float, gap: float) -> MeshInstance3D:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 96:
		var a := gap + (TAU - gap * 2.0) * float(i) / 96.0
		var b := gap + (TAU - gap * 2.0) * float(i + 1) / 96.0
		var points := [Vector3(sin(a) * inner, 0, cos(a) * inner),
			Vector3(sin(a) * outer, 0, cos(a) * outer),
			Vector3(sin(b) * outer, 0, cos(b) * outer),
			Vector3(sin(b) * inner, 0, cos(b) * inner)]
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


static func _tone(release: bool) -> AudioStreamWAV:
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
	return stream
