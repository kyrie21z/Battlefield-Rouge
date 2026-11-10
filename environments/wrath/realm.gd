class_name WrathRealm
extends Node3D
## White porcelain plates split around hot fissures; all walking geometry is explicit.
@export var boss_arena := false
var deprived := false
var lava: Array[MeshInstance3D] = []
var steam: Array[CPUParticles3D] = []
var walls: Array[StaticBody3D] = []
var ambience: AudioStreamPlayer3D
var _white: StandardMaterial3D
var _hot: StandardMaterial3D

func _ready() -> void:
	_white = _mat(Color(0.83, 0.80, 0.77), 0.7)
	_hot = _mat(Color(1.0, 0.10, 0.015), 0.25)
	_hot.emission_enabled = true
	_hot.emission = Color(1.0, 0.17, 0.025)
	_hot.emission_energy_multiplier = 3.0
	_block("WalkableKiln", Vector3(0, -0.6, 0), Vector3(40, 1.2, 48), true)
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := -20.0 + i * 9.0
			var wall := _block("TiltedFracture", Vector3(side * 19.3, 2.4, z), Vector3(1.6, 5.5, 7.4), true)
			wall.rotation.z = side * 0.14
			walls.append(wall)
			_spike(Vector3(side * 16.8, 0, z), Vector3(0.8, 3.5 + i % 2, 1.4), side * 0.25)
	for z in [-23.8, 23.8]:
		walls.append(_block("EndWall", Vector3(0, 1.4, z), Vector3(40, 3, 0.5), true))
	for side in [-1.0, 1.0]:
		for i in 4:
			var pos := Vector3(side * (5.0 + i * 2.4), 0.025, -16.0 + i * 9.0)
			var crack := _mesh(pos, Vector3(0.20, 0.025, 8.0), _hot)
			crack.rotation.y = side * (0.4 + i * 0.11)
			lava.append(crack)
			_vent(pos)
	if not boss_arena:
		for pos in [Vector3(-8, 0.7, 1), Vector3(8, 0.7, -10)]:
			var cover := _block("BrokenCover", pos, Vector3(3, 1.4, 3), true)
			cover.rotation.z = 0.12
	var world := WorldEnvironment.new()
	world.environment = preload("res://environments/default_env.tres").duplicate() as Environment
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.16, 0.095, 0.085)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.86, 0.78, 0.72)
	world.environment.ambient_light_energy = 0.65
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color(1.0, 0.87, 0.76)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	add_child(sun)
	ambience = AudioStreamPlayer3D.new()
	ambience.stream = _kiln_sound()
	ambience.position = Vector3(0, 1, -3)
	ambience.volume_db = -24.0
	ambience.max_distance = 70
	add_child(ambience)
	ambience.play()

func set_deprivation(active: bool) -> void:
	deprived = active
	if _hot == null:
		return
	_hot.emission_energy_multiplier = 0.15 if active else 3.0
	_hot.albedo_color = Color(0.10, 0.085, 0.08) if active else Color(1.0, 0.10, 0.015)
	for particles in steam:
		particles.emitting = not active
	if is_instance_valid(ambience):
		if active:
			ambience.stop()
		else:
			ambience.play()

func _block(label: String, pos: Vector3, size_value: Vector3, solid: bool) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.collision_layer = CollisionLayers.WORLD if solid else 0
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	add_child(body)
	body.position = pos
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	shape.shape = box
	body.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = _white
	body.add_child(visual)
	return body

func _mesh(pos: Vector3, size_value: Vector3, mat: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = mat
	add_child(visual)
	visual.position = pos
	return visual

func _spike(pos: Vector3, size_value: Vector3, tilt: float) -> void:
	var visual := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0
	mesh.bottom_radius = size_value.x
	mesh.height = size_value.y
	mesh.radial_segments = 4
	visual.mesh = mesh
	visual.material_override = _white
	visual.position = pos + Vector3.UP * size_value.y * 0.5
	visual.rotation.z = tilt
	add_child(visual)

func _vent(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.amount = 18
	p.lifetime = 1.2
	p.direction = Vector3.UP
	p.spread = 16
	p.initial_velocity_min = 1.8
	p.initial_velocity_max = 3.2
	p.gravity = Vector3(0, 0.7, 0)
	p.scale_amount_min = 0.06
	p.scale_amount_max = 0.15
	p.color = Color(0.86, 0.75, 0.66, 0.18)
	var mesh := SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 6
	mesh.rings = 3
	p.mesh = mesh
	var mat := _mat(Color(0.8, 0.74, 0.7, 0.18), 1.0)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	p.material_override = mat
	p.position = pos
	add_child(p)
	steam.append(p)

func _mat(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	return mat

func _kiln_sound() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(rate * 4 * 2)
	for i in rate * 4:
		var t := float(i) / rate
		var hiss := sin(t * 17431.0) * sin(t * 12883.0) * 0.10
		var pulse := 0.5 + 0.5 * sin(t * TAU * 0.75)
		var metal := sin(t * TAU * 530.0) * sin(t * TAU * 0.25) * 0.045
		data.encode_s16(i * 2, int(clampf(hiss * pulse + metal, -1, 1) * 32767))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = rate
	audio.data = data
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_end = rate * 4
	return audio

func _exit_tree() -> void:
	if is_instance_valid(ambience):
		ambience.stop()
		ambience.stream = null
