class_name WrathRealm
extends Node3D
## White porcelain plates split around hot fissures; all walking geometry is explicit.
const KILN_SHELL := preload("res://environments/wrath/cracked_kiln.gd")
const KILN_FLOOR := preload("res://assets/materials/wrath_kiln_floor.gdshader")
const KILN_SKY := preload("res://assets/materials/wrath_kiln_sky.gdshader")
const LAVA_POOLS := preload("res://environments/wrath/lava_pools.gd")

@export var boss_arena := false
@export_range(0, 1) var chamber_style := 0
var deprived := false
var audio_managed := false
var lava: Array[MeshInstance3D] = []
var steam: Array[CPUParticles3D] = []
var walls: Array[StaticBody3D] = []
var ambience: AudioStreamPlayer3D
var _white: StandardMaterial3D
var _hot: StandardMaterial3D
var _kiln_shell: KILN_SHELL
var lava_pools: LAVA_POOLS
var player: Player
var void_fall: RealmVoid

func _ready() -> void:
	_white = _mat(Color(0.83, 0.80, 0.77), 0.7)
	_hot = _mat(Color(1.0, 0.10, 0.015), 0.25)
	_hot.emission_enabled = true
	_hot.emission = Color(1.0, 0.17, 0.025)
	_hot.emission_energy_multiplier = 3.0
	var cracked_kiln := provides_stage_lighting()
	var floor := _block("WalkableKiln", Vector3(0, -0.6, 0), Vector3(40, 1.2, 48), true)
	if cracked_kiln:
		var porcelain := ShaderMaterial.new()
		porcelain.shader = KILN_FLOOR
		(floor.get_child(1) as MeshInstance3D).material_override = porcelain
	for side in [-1.0, 1.0]:
		for i in 5:
			var z := -20.0 + i * 9.0
			var wall := _block("TiltedFracture", Vector3(side * 19.3, 2.4, z), Vector3(1.6, 5.5, 7.4), true)
			wall.rotation.z = side * 0.14
			walls.append(wall)
			if not cracked_kiln:
				_spike(Vector3(side * 16.8, 0, z), Vector3(0.8, 3.5 + i % 2, 1.4), side * 0.25)
	for z in [-23.8, 23.8]:
		walls.append(_block("EndWall", Vector3(0, 1.4, z), Vector3(40, 3, 0.5), true))
	for side in [-1.0, 1.0]:
		for i in 4:
			var pos := Vector3(side * (5.0 + i * 2.4), 0.025, -16.0 + i * 9.0)
			if not cracked_kiln:
				var crack := _mesh(pos, Vector3(0.20, 0.025, 8.0), _hot)
				crack.rotation.y = side * (0.4 + i * 0.11)
				lava.append(crack)
			_vent(pos)
	if not boss_arena:
		if cracked_kiln:
			var entry_cover := _block("KilnEntryCover", Vector3(8, 1.05, 7.1), Vector3(5.1, 2.1, 2.9), true)
			entry_cover.rotation.y = -0.12
			var exit_cover := _block("KilnExitCover", Vector3(10.8, 1.15, -7.8), Vector3(4.7, 2.3, 2.8), true)
			exit_cover.rotation.y = 0.23
			_kiln_shell = KILN_SHELL.new()
			_kiln_shell.name = "CrackedKilnScenery"
			add_child(_kiln_shell)
			_kiln_shell.dress_banks(walls.slice(0, -2))
			_kiln_shell.dress_cover(entry_cover)
			_kiln_shell.dress_cover(exit_cover)
			_kiln_shell.dress_end_wall(walls[-2])
			_build_kiln_floor_details()
			_kiln_shell.spillway.set_deprivation(deprived)
		else:
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
	if cracked_kiln:
		var kiln_air := ShaderMaterial.new()
		kiln_air.shader = KILN_SKY
		var sky := Sky.new()
		sky.sky_material = kiln_air
		sky.radiance_size = Sky.RADIANCE_SIZE_64
		world.environment.sky = sky
		world.environment.background_mode = Environment.BG_SKY
		world.environment.ambient_light_color = Color("d5c3c8")
		world.environment.ambient_light_energy = 0.39
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58, -28, 0)
	sun.light_color = Color(1.0, 0.87, 0.76)
	sun.light_energy = 1.6
	sun.shadow_enabled = true
	if cracked_kiln:
		sun.rotation_degrees = Vector3(-51, -26, 0)
		sun.light_color = Color("fff0de")
		sun.light_energy = 1.4
	add_child(sun)
	ambience = AudioStreamPlayer3D.new()
	ambience.stream = _kiln_sound()
	ambience.position = Vector3(0, 1, -3)
	ambience.volume_db = -24.0
	ambience.max_distance = 70
	add_child(ambience)
	if not audio_managed and not deprived:
		ambience.play()
	_install_void()

func _build_kiln_floor_details() -> void:
	var centers := [Vector2(-4.8, 3.7), Vector2(3.85, 3.5), Vector2(-5.2, -6.2), Vector2(5.9, -11.5)]
	var sizes := [Vector3(1.65, 3.8, 1.62), Vector3(1.58, 2.65, 1.54),
		Vector3(1.73, 3.35, 1.75), Vector3(1.65, 4.1, 1.80)]
	for i in centers.size():
		var size: Vector3 = sizes[i]
		var pillar := _block("KilnPillar%d" % (i + 1), Vector3(centers[i].x, size.y * 0.5, centers[i].y), size, true)
		pillar.rotation.y = [-0.19, 0.26, 0.07, -0.23][i]
		_kiln_shell.dress_pillar(pillar, i)
	lava_pools = LAVA_POOLS.new()
	lava_pools.name = "LavaPools"
	lava_pools.player = player
	add_child(lava_pools)
	lava_pools.set_deprivation(deprived)

func provides_stage_lighting() -> bool:
	return chamber_style == 1 and not boss_arena

## 坠落边界：玩家掉出去扣 30 点生命并回到上次稳定平台，敌人掉出去直接死。
func set_player(value: Player) -> void:
	player = value
	if is_instance_valid(lava_pools):
		lava_pools.player = value
	if is_instance_valid(void_fall):
		void_fall.setup(value)


func player_spawn() -> Vector3:
	return Vector3(0, 0, 16)


## Legacy five first, then flat kiln floor clear of lava beds, pillars, covers
## and the tilted outer walls in both chamber styles.
func spawn_points() -> Array[Vector3]:
	return [
		# 第一点固定分给穿刺者（variant = i % 3 落在 i=0）：后移到约 23 米外，
		# 避免玩家一进场就被冲锋。其余点保持上游的多波次布局。
		Vector3(-8, 0.1, -6), Vector3(8, 0.1, -4), Vector3(0, 0.1, -12),
		Vector3(-11, 0.1, -12), Vector3(11, 0.1, -14),
		Vector3(-13, 0.1, 6), Vector3(13, 0.1, 12),
		Vector3(-13, 0.1, -17), Vector3(3, 0.1, -18),
	]


func exit_position() -> Vector3:
	return Vector3(0, 0, -20)


func _install_void() -> void:
	void_fall = RealmVoid.new()
	void_fall.name = "VoidFall"
	void_fall.spawn_fallback = player_spawn()
	add_child(void_fall)
	if is_instance_valid(player):
		void_fall.setup(player)


func set_audio_managed(active: bool) -> void:
	audio_managed = active
	if not is_instance_valid(ambience):
		return
	if active or deprived:
		ambience.stop()
	elif is_inside_tree():
		ambience.play()

func set_deprivation(active: bool) -> void:
	deprived = active
	if _hot == null:
		return
	_hot.emission_energy_multiplier = 0.15 if active else 3.0
	_hot.albedo_color = Color(0.10, 0.085, 0.08) if active else Color(1.0, 0.10, 0.015)
	if is_instance_valid(_kiln_shell):
		_kiln_shell.spillway.set_deprivation(active)
	if is_instance_valid(lava_pools):
		lava_pools.set_deprivation(active)
	for particles in steam:
		particles.emitting = not active
	if is_instance_valid(ambience):
		if active or audio_managed:
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
