class_name SorrowRealm
extends Node3D
@export var boss_arena := false
var deprived := false
var water_level := 0.14
var water: MeshInstance3D
var water_material: ShaderMaterial
var rain: CPUParticles3D
var platforms: Array[StaticBody3D] = []
var columns: Array[Node3D] = []
var player: Player
var audio_managed := false
var splash: AudioStreamPlayer3D
var ripple_count := 0
var footstep_count := 0
var clock := 0.0
var _foot_left := 0.0
var _last_step := Vector3.INF
var _ripples := PackedVector3Array()
var _white: StandardMaterial3D

func _ready() -> void:
	_white = StandardMaterial3D.new()
	_white.albedo_color = Color(0.75, 0.82, 0.84)
	_white.roughness = 0.62
	_block("BasinFloor", Vector3(0,-0.5,0), Vector3(40,1,48))
	for side in [-1.0,1.0]:
		_block("Boundary", Vector3(side*20,2,0), Vector3(0.5,4,48))
	for z in [-24.0,24.0]:
		_block("Boundary", Vector3(0,2,z), Vector3(40,4,0.5))
	for pos in [Vector3(-7,0.3,6),Vector3(7,0.3,-5),Vector3(-7,0.6,-13),Vector3(8,0.6,14)]:
		platforms.append(_block("DrowningPlatform",pos,Vector3(4, pos.y*2,4)))
	for side in [-1.0,1.0]:
		for i in 4:
			_column(Vector3(side*15,0,-18+i*11))
	water = MeshInstance3D.new()
	water.name = "MirrorWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(39.6,47.6)
	water.mesh = plane
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://environments/sorrow/water.gdshader")
	for i in 8:
		_ripples.append(Vector3(0,0,-10))
	water_material.set_shader_parameter("ripples",_ripples)
	water.material_override = water_material
	add_child(water)
	set_water_level(water_level)
	_rain()
	splash = AudioStreamPlayer3D.new()
	splash.stream = _splash_sound()
	splash.volume_db = -13
	splash.max_distance = 25
	add_child(splash)
	var world := WorldEnvironment.new()
	world.environment = Environment.new()
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.035,0.075,0.105)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.62,0.80,0.92)
	world.environment.ambient_light_energy = 0.75
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	world.environment.ssr_enabled = true
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-25,0)
	sun.light_color = Color(0.76,0.87,1)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	add_child(sun)

## Room audio owns splashes in production; standalone geometry keeps fallback.
func set_audio_managed(active: bool) -> void:
	audio_managed = active
	if active and is_instance_valid(splash): splash.stop()

func set_player(value: Player) -> void:
	player = value

func set_water_level(value: float) -> void:
	water_level = clampf(value,0.0,1.7)
	if is_instance_valid(water):
		water.position.y = water_level

func set_deprivation(active: bool) -> void:
	deprived = active
	if is_instance_valid(water):
		water.visible = not active
	if is_instance_valid(rain):
		rain.emitting = not active
	if active and is_instance_valid(splash):
		splash.stop()
	if _white != null:
		_white.albedo_color = Color(0.72,0.69,0.66) if active else Color(0.75,0.82,0.84)

func add_ripple(point: Vector3) -> void:
	if deprived:
		return
	_ripples[ripple_count % 8] = Vector3(point.x,point.z,clock)
	ripple_count += 1
	water_material.set_shader_parameter("ripples",_ripples)

func _physics_process(delta: float) -> void:
	if deprived:
		return
	clock += delta
	water_material.set_shader_parameter("clock",clock)
	_foot_left -= delta
	if not is_instance_valid(player) or player.health.is_dead():
		return
	var point := player.global_position
	if point.y > water_level or not player.is_on_floor():
		return
	if _last_step == Vector3.INF:
		_last_step = point
	if _foot_left <= 0 and point.distance_to(_last_step) > 0.5:
		_last_step = point
		_foot_left = 0.3
		add_ripple(point)
		if not audio_managed:
			splash.global_position = point
			splash.play()
		footstep_count += 1

func _block(label: String, pos: Vector3, size_value: Vector3) -> StaticBody3D:
	var node := StaticBody3D.new()
	node.name = label
	node.collision_layer = CollisionLayers.WORLD
	node.collision_mask = 0
	node.add_to_group("navigation_geometry")
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size_value
	shape.shape = box
	node.add_child(shape)
	var visual := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size_value
	visual.mesh = mesh
	visual.material_override = _white
	node.add_child(visual)
	add_child(node)
	node.position = pos
	return node

func _column(pos: Vector3) -> void:
	var root := Node3D.new()
	add_child(root)
	root.position = pos
	columns.append(root)
	for tier in 6:
		var mesh := CylinderMesh.new()
		mesh.radial_segments = 7
		mesh.top_radius = 0.48 + tier * 0.04
		mesh.bottom_radius = 0.6 + (5-tier)*0.11
		mesh.height = 0.9
		var part := MeshInstance3D.new()
		part.mesh = mesh
		part.material_override = _white
		part.position = Vector3(sin(tier*0.7)*0.30,tier*0.76+0.4,0)
		part.rotation.z = sin(tier)*0.10
		root.add_child(part)
	for i in 4:
		var melt := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.08
		cone.bottom_radius = 0.3
		cone.height = 2.3+i*0.3
		cone.radial_segments = 5
		melt.mesh = cone
		melt.material_override = _white
		melt.position = Vector3(sin(i*1.7)*0.7,cone.height*0.5,cos(i*1.7)*0.6)
		root.add_child(melt)

func _rain() -> void:
	rain = CPUParticles3D.new()
	rain.amount = 450
	rain.lifetime = 1.8
	rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	rain.emission_box_extents = Vector3(19,0.2,23)
	rain.position.y = 13
	rain.direction = Vector3.DOWN
	rain.spread = 1
	rain.initial_velocity_min = 8
	rain.initial_velocity_max = 11
	rain.gravity = Vector3.ZERO
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.012,0.38,0.012)
	rain.mesh = mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.67,0.82,0.9,0.35)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rain.material_override = material
	add_child(rain)

func _splash_sound() -> AudioStreamWAV:
	var rate := 22050
	var data := PackedByteArray()
	data.resize(int(rate*0.2)*2)
	for i in int(rate*0.2):
		var t := float(i)/rate
		var value := sin(t*18934)*sin(t*9753)*exp(-t*24)*0.35 + sin(t*TAU*(230-t*650))*exp(-t*35)*0.14
		data.encode_s16(i*2,int(value*32767))
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = rate
	sound.data = data
	return sound

func _exit_tree() -> void:
	if is_instance_valid(splash):
		splash.stop()
		splash.stream = null
