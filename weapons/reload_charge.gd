class_name ReloadCharge
extends Node3D
## A thrown magazine whose fuse starts on launch. Damage uses the physics world, never
## actor groups; blast() also supplies the shield's stationary pulse.

signal exploded(origin: Vector3, effect: Node3D)

const FUSE_TIME := 1.5
const THROW_SPEED := 24.0
const UPWARD_SPEED := 3.0
const GRAVITY := 9.0
const ACCENT := Color(1.0, 0.42, 0.08)
const MAX_QUERY_RESULTS := 256
const TRAIL_POINTS := 8
const FULL_DAMAGE_RADIUS := 1.0
const EDGE_DAMAGE_SCALE := 0.5
const SHIELD_WAVE_REACH_TIME := 0.48
const SHIELD_WAVE_FADE_AT := 0.62
const SHIELD_WAVE_LIFETIME := 0.82

static var _blast_sound: AudioStreamWAV
static var _shield_sound: AudioStreamWAV

var shooter: CollisionObject3D
var damage := 0.0
var radius := 3.5
var velocity := Vector3.ZERO
var fuse_remaining := FUSE_TIME
var exploded_once := false

var _model: Node3D
var _trail := ImmediateMesh.new()
var _trail_points: Array[Vector3] = []
var _trail_material: StandardMaterial3D


static func spawn(parent: Node, origin: Vector3, direction: Vector3,
		p_shooter: CollisionObject3D, p_damage: float, p_radius: float = 3.5) -> Node3D:
	var charge := ReloadCharge.new()
	charge.name = "ReloadCharge"
	charge.shooter = p_shooter
	charge.damage = p_damage
	charge.radius = p_radius
	var forward := direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	charge.velocity = forward * THROW_SPEED + Vector3.UP * UPWARD_SPEED
	parent.add_child(charge)
	charge.global_position = origin
	charge._trail_points.append(origin)
	return charge


## Applies damage synchronously, then returns a short-lived visual/audio node.
## A Health with several overlapping head/body hitboxes takes one BODY hit.
## metadata "targets_hit" records how many Health components lost health.
static func blast(parent: Node, origin: Vector3, p_shooter: CollisionObject3D,
		p_damage: float, p_radius: float, accent: Color = ACCENT,
		distance_falloff: bool = false) -> Node3D:
	var effect := Node3D.new()
	effect.name = "BlastPulse"
	parent.add_child(effect)
	effect.global_position = origin
	var blast_radius := maxf(p_radius, 0.05)
	var shape := SphereShape3D.new()
	shape.radius = blast_radius
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = Transform3D(Basis.IDENTITY, origin)
	query.collision_mask = CollisionLayers.HITBOXES
	query.collide_with_areas = false
	query.collide_with_bodies = true
	var world := effect.get_world_3d().direct_space_state
	var targets: Dictionary = {}
	var source: Node = p_shooter if is_instance_valid(p_shooter) else null
	for result: Dictionary in world.intersect_shape(query, MAX_QUERY_RESULTS):
		var hitbox := result.get("collider") as Hitbox
		if hitbox == null or not is_instance_valid(hitbox.health) or hitbox.health.is_dead():
			continue
		var health := hitbox.health
		if health.get_parent() == source:
			continue
		if source != null and "team" in source and health.team == int(source.get("team")):
			continue
		var center := _hitbox_center(hitbox)
		var distance := origin.distance_to(center)
		# Shape overlap alone can include a hitbox whose centre is outside
		# the advertised radius. Use that same centre for range and sight.
		if distance > blast_radius:
			continue
		if not origin.is_equal_approx(center):
			var sight := PhysicsRayQueryParameters3D.create(origin, center, CollisionLayers.WORLD)
			sight.hit_from_inside = true
			if not world.intersect_ray(sight).is_empty():
				# A blocked head must not suppress an exposed torso of the same
				# actor, so deduplication only happens after visibility succeeds.
				continue
		var scale := damage_scale(distance, blast_radius) if distance_falloff else 1.0
		# Resolve every exposed hitbox before dealing damage. A closer visible
		# body part wins without headshot multipliers or duplicate damage.
		targets[health] = maxf(float(targets.get(health, 0.0)), scale)
	var hits := 0
	if p_damage > 0.0:
		for health: Health in targets:
			if health.apply_damage(p_damage * float(targets[health]), Hitbox.BodyPart.BODY, source) > 0.0:
				hits += 1
	effect.set_meta("targets_hit", hits)
	effect.set_meta("blast_radius", blast_radius)
	effect.set_meta("distance_falloff", distance_falloff)
	_show_blast(effect, blast_radius, accent, distance_falloff)
	return effect


static func damage_scale(distance: float, blast_radius: float) -> float:
	if distance > blast_radius:
		return 0.0
	var inner_radius := minf(FULL_DAMAGE_RADIUS, blast_radius)
	if distance <= inner_radius:
		return 1.0
	return lerpf(1.0, EDGE_DAMAGE_SCALE,
		clampf((distance - inner_radius) / maxf(blast_radius - inner_radius, 0.001), 0.0, 1.0))


static func _hitbox_center(hitbox: Hitbox) -> Vector3:
	for child in hitbox.get_children():
		if child is CollisionShape3D and not (child as CollisionShape3D).disabled:
			return (child as CollisionShape3D).global_position
	return hitbox.global_position


## Shared by the held view and flying projectile; no external assets are needed.
static func create_model() -> Node3D:
	var model := Node3D.new()
	var magazine := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.12, 0.26, 0.08)
	magazine.mesh = mesh
	var steel := StandardMaterial3D.new()
	steel.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	steel.albedo_color = Color(0.17, 0.2, 0.24)
	steel.metallic = 0.7
	magazine.material_override = steel
	magazine.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(magazine)
	var strip := MeshInstance3D.new()
	var strip_mesh := BoxMesh.new()
	strip_mesh.size = Vector3(0.128, 0.04, 0.088)
	strip.mesh = strip_mesh
	strip.position.y = -0.08
	strip.material_override = _glow_material(ACCENT, 1.0)
	strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(strip)
	return model


func _ready() -> void:
	_model = create_model()
	add_child(_model)
	_trail_material = _glow_material(ACCENT, 0.85)
	_trail_material.vertex_color_use_as_albedo = true
	_trail_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var trail_mesh := MeshInstance3D.new()
	trail_mesh.name = "OrangeTrail"
	trail_mesh.mesh = _trail
	trail_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(trail_mesh)
	trail_mesh.set_as_top_level(true)
	trail_mesh.global_transform = Transform3D.IDENTITY


func _physics_process(delta: float) -> void:
	if exploded_once:
		return
	var from := global_position
	velocity.y -= GRAVITY * delta
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to,
		CollisionLayers.WORLD | CollisionLayers.HITBOXES)
	query.hit_from_inside = true
	if is_instance_valid(shooter):
		var excluded: Array[RID] = [shooter.get_rid()]
		for hitbox in shooter.find_children("*", "Hitbox", true, false):
			excluded.append((hitbox as Hitbox).get_rid())
		query.exclude = excluded
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		# Keep the blast just outside the impact surface for its visibility rays.
		_detonate(hit.position + hit.normal * 0.04)
		return
	global_position = to
	_model.rotate_x(delta * 8.0)
	_model.rotate_z(delta * 11.0)
	_update_trail(to)
	fuse_remaining -= delta
	if fuse_remaining <= 0.0:
		detonate()


## Public for fixtures; repeated calls cannot deal a second explosion.
func detonate() -> Node3D:
	return _detonate(global_position)


func _detonate(point: Vector3) -> Node3D:
	if exploded_once:
		return null
	exploded_once = true
	var valid_shooter := shooter if is_instance_valid(shooter) else null
	var effect := blast(get_parent(), point, valid_shooter, damage, radius, ACCENT, true)
	exploded.emit(point, effect)
	queue_free()
	return effect


func _update_trail(point: Vector3) -> void:
	_trail_points.append(point)
	if _trail_points.size() > TRAIL_POINTS:
		_trail_points.pop_front()
	_trail.clear_surfaces()
	if _trail_points.size() < 2:
		return
	_trail.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _trail_material)
	for index in _trail_points.size():
		var tangent := _trail_points[mini(index + 1, _trail_points.size() - 1)] \
			- _trail_points[maxi(index - 1, 0)]
		var side := tangent.cross(Vector3.UP).normalized()
		if side.is_zero_approx():
			side = Vector3.RIGHT
		side *= 0.025
		_trail.surface_set_color(Color(1.0, 1.0, 1.0, float(index + 1) / _trail_points.size()))
		_trail.surface_add_vertex(_trail_points[index] - side)
		_trail.surface_add_vertex(_trail_points[index] + side)
	_trail.surface_end()


static func _glow_material(accent: Color, alpha: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(accent.r, accent.g, accent.b, alpha)
	material.emission_enabled = true
	material.emission = accent
	material.emission_energy_multiplier = 1.8
	return material


static func _show_blast(effect: Node3D, blast_radius: float, accent: Color, explosive: bool) -> void:
	if explosive:
		_show_explosion(effect, blast_radius, accent)
	else:
		_show_shield_pulse(effect, blast_radius, accent)
	var audio := AudioStreamPlayer3D.new()
	if explosive:
		if _blast_sound == null:
			_blast_sound = _make_blast_sound()
		audio.stream = _blast_sound
	else:
		if _shield_sound == null:
			_shield_sound = _make_shield_sound()
		audio.name = "ShieldWhoosh"
		audio.stream = _shield_sound
	audio.unit_size = 8.0
	audio.max_distance = 45.0
	audio.volume_db = -6.0 if explosive else -5.0
	effect.add_child(audio)
	audio.play()


static func _show_explosion(effect: Node3D, blast_radius: float, accent: Color) -> void:
	# A brief hot core marks the actual blast, while a thin fading ring
	# shows its reach. No full-radius luminous sphere obscures enemies.
	var tween := effect.create_tween().set_parallel(true)
	var core := _sphere(effect, "FireFlash", Color(1.0, 0.78, 0.3), 0.88)
	core.scale = Vector3.ONE * 0.12
	var core_material := core.material_override as StandardMaterial3D
	tween.tween_property(core, "scale", Vector3.ONE * minf(blast_radius * 0.22, 0.8), 0.10) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(core_material, "albedo_color:a", 0.0, 0.18)
	var ring := MeshInstance3D.new()
	ring.name = "PressureRing"
	var torus := TorusMesh.new()
	torus.inner_radius = 0.985
	torus.outer_radius = 1.0
	torus.rings = 32
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _glow_material(accent, 0.35)
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.scale = Vector3.ONE * 0.1
	effect.add_child(ring)
	tween.tween_property(ring, "scale", Vector3.ONE * blast_radius, 0.32) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(ring.material_override, "albedo_color:a", 0.0, 0.34)
	var spark_material := _glow_material(Color(1.0, 0.56, 0.16), 1.0)
	for index in 12:
		var spark := MeshInstance3D.new()
		spark.name = "Spark%d" % index
		var spark_mesh := BoxMesh.new()
		spark_mesh.size = Vector3(0.018, 0.018, 0.11)
		spark.mesh = spark_mesh
		spark.material_override = spark_material
		spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		effect.add_child(spark)
		var angle := float(index) * TAU / 12.0
		var direction := Vector3(cos(angle), 0.25 + float(index % 3) * 0.28, sin(angle)).normalized()
		spark.look_at(effect.global_position + direction, Vector3.UP)
		var end := direction * blast_radius * (0.45 + float(index % 4) * 0.1)
		end.y -= 0.45
		tween.tween_property(spark, "position", end, 0.42).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(spark_material, "albedo_color:a", 0.0, 0.35).set_delay(0.08)
	for index in 3:
		var smoke := _sphere(effect, "Smoke%d" % index, Color(0.25, 0.23, 0.21), 0.16)
		var smoke_material := smoke.material_override as StandardMaterial3D
		smoke_material.emission_enabled = false
		smoke.scale = Vector3.ONE * 0.22
		smoke.position = Vector3((index - 1) * 0.22, 0.0, 0.0)
		var smoke_end := smoke.position + Vector3((index - 1) * 0.2, 0.65, 0.0)
		tween.tween_property(smoke, "position", smoke_end, 0.75)
		tween.tween_property(smoke, "scale", Vector3(0.7, 0.9, 0.7), 0.75)
		tween.tween_property(smoke_material, "albedo_color:a", 0.0, 0.65).set_delay(0.1)
	var light := OmniLight3D.new()
	light.name = "FlashLight"
	light.light_color = accent
	light.light_energy = 1.8
	light.omni_range = minf(blast_radius * 1.4, 5.0)
	light.shadow_enabled = false
	effect.add_child(light)
	tween.tween_property(light, "light_energy", 0.0, 0.15)
	tween.chain().tween_callback(effect.queue_free)


static func _sphere(effect: Node3D, label: String, color: Color, alpha: float) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 16
	mesh.rings = 8
	visual.mesh = mesh
	visual.material_override = _glow_material(color, alpha)
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	effect.add_child(visual)
	return visual


static func _show_shield_pulse(effect: Node3D, blast_radius: float, accent: Color) -> void:
	# An open energy wall has a readable wave front without filling the view
	# with a low-poly globe. The inside is visible to the first-person camera;
	# normal depth testing still hides the wave behind solid world geometry.
	effect.set_meta("visual_duration", SHIELD_WAVE_LIFETIME)
	var front := MeshInstance3D.new()
	front.name = "ShieldWaveFront"
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.0
	cylinder.bottom_radius = 1.0
	cylinder.height = 1.6
	cylinder.radial_segments = 96
	cylinder.cap_top = false
	cylinder.cap_bottom = false
	front.mesh = cylinder
	var front_material := _glow_material(accent, 0.14)
	front_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	front.material_override = front_material
	front.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	front.scale = Vector3(0.16, 1.0, 0.16)
	effect.add_child(front)
	var tween := effect.create_tween().set_parallel(true)
	tween.tween_property(front, "scale", Vector3(blast_radius, 1.0, blast_radius),
		SHIELD_WAVE_REACH_TIME).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(front_material, "albedo_color:a", 0.0,
		SHIELD_WAVE_LIFETIME - SHIELD_WAVE_FADE_AT).set_delay(SHIELD_WAVE_FADE_AT)
	# Unit torus radii keep the horizontal wave front at the advertised reach.
	# At seven metres the
	# main rim is 31.5 cm thick, with a second rim and two delayed inner echoes.
	var rim_specs := [
		["ShieldWaveRim", -0.62, 0.955, 1.0, 0.0, accent.lerp(Color.WHITE, 0.42), 0.96],
		["ShieldWaveUpperRim", 0.55, 0.975, 1.0, 0.0, accent, 0.65],
		["ShieldEcho0", -0.55, 0.96, 0.94, 0.07, accent, 0.55],
		["ShieldEcho1", -0.48, 0.97, 0.88, 0.14, accent.lerp(Color.WHITE, 0.2), 0.4],
	]
	for spec: Array in rim_specs:
		var ring := MeshInstance3D.new()
		ring.name = spec[0]
		var torus := TorusMesh.new()
		torus.inner_radius = spec[2]
		torus.outer_radius = 1.0
		torus.rings = 96
		torus.ring_segments = 10
		ring.mesh = torus
		var ring_material := _glow_material(spec[5], spec[6])
		ring_material.cull_mode = BaseMaterial3D.CULL_DISABLED
		ring.material_override = ring_material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.position.y = spec[1]
		ring.scale = Vector3.ONE * 0.16
		effect.add_child(ring)
		tween.tween_property(ring, "scale", Vector3.ONE * blast_radius * float(spec[3]),
			SHIELD_WAVE_REACH_TIME).set_delay(spec[4]) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(ring_material, "albedo_color:a", 0.0,
			SHIELD_WAVE_LIFETIME - SHIELD_WAVE_FADE_AT).set_delay(SHIELD_WAVE_FADE_AT)
	# Keep full-radius rims visible briefly before fading. This also gives the
	# dedicated sound enough time to finish instead of cutting its tail off.
	tween.chain().tween_callback(effect.queue_free)


static func _make_shield_sound() -> AudioStreamWAV:
	const RATE := 22050
	const LENGTH := 0.64
	var bytes := PackedByteArray()
	var count := int(LENGTH * RATE)
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 20261028
	var phase := 0.0
	var lowpass := 0.0
	for index in count:
		var time := float(index) / RATE
		var progress := time / LENGTH
		var envelope := minf(time / 0.025, 1.0) * pow(1.0 - progress, 1.2)
		var frequency := lerpf(132.0, 42.0, sqrt(progress))
		phase += TAU * frequency / RATE
		lowpass += (random.randf_range(-1.0, 1.0) - lowpass) * 0.22
		var energy := sin(phase) * 0.42 + sin(phase * 2.0) * 0.14
		var rush := lowpass * 0.72 * sin(PI * progress)
		var sample := int(clampf((energy + rush) * envelope, -1.0, 1.0) * 32767.0) & 0xFFFF
		bytes[index * 2] = sample & 0xFF
		bytes[index * 2 + 1] = (sample >> 8) & 0xFF
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = bytes
	return sound


static func _make_blast_sound() -> AudioStreamWAV:
	const RATE := 22050
	var bytes := PackedByteArray()
	var count := int(0.42 * RATE)
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 20261025
	var lowpass := 0.0
	for index in count:
		var time := float(index) / RATE
		var white := random.randf_range(-1.0, 1.0)
		lowpass += (white - lowpass) * 0.14
		var boom := sin(TAU * 72.0 * time) * exp(-time * 12.0) * 0.5
		var crack := white * exp(-time * 55.0) * 0.3
		var sample := int(clampf(boom + lowpass * exp(-time * 9.0) + crack, -1.0, 1.0) * 32767.0) & 0xFFFF
		bytes[index * 2] = sample & 0xFF
		bytes[index * 2 + 1] = (sample >> 8) & 0xFF
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = RATE
	sound.data = bytes
	return sound
