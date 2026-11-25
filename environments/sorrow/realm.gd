class_name SorrowRealm
extends Node3D
const FLOODED_COURT := preload("res://environments/sorrow/flooded_court.gd")
const FLOODED_SKY := preload("res://environments/sorrow/flooded_sky.gdshader")
const WHIRLPOOL_RADIUS := 2.6
const WHIRLPOOL_DEPTH := 0.60
const WHIRLPOOL_INTERVAL := 5.0
const WHIRLPOOL_DURATION := 15.0
const WHIRLPOOL_LIMIT := int(WHIRLPOOL_DURATION / WHIRLPOOL_INTERVAL)
const WHIRLPOOL_PULL_SPEED := 11.0
const WHIRLPOOL_CORE_RADIUS := 0.80
const WHIRLPOOL_JITTER := 0.35
## Clear patches of water with enough room to form a full funnel.
const WHIRLPOOL_SITES := [
	Vector2(-14, 8), Vector2(-11, 15), Vector2(8, 8), Vector2(1, 10),
	Vector2(-10, 0), Vector2(-1, 4), Vector2(14, -3), Vector2(1, -5),
	Vector2(-13, -9), Vector2(0, -14), Vector2(-15, -16), Vector2(12, -15), Vector2(5, -18),
]

@export var boss_arena := false
@export_range(0, 1) var chamber_style := 0
var deprived := false
var water_level := 0.14
var water: MeshInstance3D
var water_material: ShaderMaterial
var rain: GPUParticles3D
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
const RIPPLE_CAPACITY := 32
var _ripples := PackedVector4Array()
var _rain_motion: ShaderMaterial
var _walkers: Dictionary = {}
var _tears: Dictionary = {}
var movement_ripple_count := 0
var shot_ripple_count := 0
var tear_ripple_count := 0
var _white: StandardMaterial3D
var _court: FLOODED_COURT
var _basin_floor_visual: MeshInstance3D
var _whirlpool_rng: RandomNumberGenerator
var _whirlpools: Array[Vector4] = [] # x/z center, radius, birth time
var _next_whirlpool_at := 0.0
var mirror_environment: Environment
var void_fall: RealmVoid

func _ready() -> void:
	_white = StandardMaterial3D.new()
	_white.albedo_color = Color(0.75, 0.82, 0.84)
	_white.roughness = 0.62
	var floor_body := _block("BasinFloor", Vector3(0,-0.5,0), Vector3(40,1,48))
	var banks: Array[StaticBody3D] = []
	for side in [-1.0,1.0]:
		banks.append(_block("Boundary", Vector3(side*20,2,0), Vector3(0.5,4,48)))
	for z in [-24.0,24.0]:
		banks.append(_block("Boundary", Vector3(0,2,z), Vector3(40,4,0.5)))
	for pos in [Vector3(-7,0.3,6),Vector3(7,0.3,-5),Vector3(-7,0.6,-13),Vector3(8,0.6,14)]:
		platforms.append(_block("DrowningPlatform",pos,Vector3(4, pos.y*2,4)))
	if provides_stage_lighting():
		_court = FLOODED_COURT.new()
		_court.name = "FloodedCourt"
		add_child(_court)
		_court.dress_basin(floor_body, banks, platforms)
		_basin_floor_visual = floor_body.get_child(1) as MeshInstance3D
		# The opaque water can dip below its walking collision without the dry-floor mesh clipping it.
		_basin_floor_visual.position.y = -WHIRLPOOL_DEPTH
		_build_basin_ruins()
	else:
		for side in [-1.0,1.0]:
			for i in 4:
				_column(Vector3(side*15,0,-18+i*11))
	water = MeshInstance3D.new()
	water.name = "MirrorWater"
	var plane := PlaneMesh.new()
	plane.size = Vector2(39.6,47.6)
	if is_instance_valid(_court):
		plane.subdivide_width = 95
		plane.subdivide_depth = 115
		water.extra_cull_margin = WHIRLPOOL_DEPTH
	water.mesh = plane
	water_material = ShaderMaterial.new()
	water_material.shader = preload("res://environments/sorrow/water_mirror.gdshader")
	for i in RIPPLE_CAPACITY:
		_ripples.append(Vector4(0,0,-100,0))
	water_material.set_shader_parameter("ripples",_ripples)
	water.material_override = water_material
	add_child(water)
	set_water_level(water_level)
	_rain()
	splash = AudioStreamPlayer3D.new()
	splash.stream = _splash_sound()
	splash.volume_db = SorrowSoundBank.MOTION_VOLUME_DB
	splash.max_distance = 25
	add_child(splash)
	var world := WorldEnvironment.new()
	world.environment = preload("res://environments/default_env.tres").duplicate() as Environment
	mirror_environment = world.environment
	world.environment.background_mode = Environment.BG_COLOR
	world.environment.background_color = Color(0.035,0.075,0.105)
	world.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	world.environment.ambient_light_color = Color(0.62,0.80,0.92)
	world.environment.ambient_light_energy = 0.75
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.glow_enabled = true
	world.environment.ssr_enabled = true
	world.environment.ssr_max_steps = 128
	world.environment.ssr_fade_in = 0.1
	world.environment.ssr_fade_out = 4.0
	world.environment.ssr_depth_tolerance = 0.25
	if is_instance_valid(_court):
		var overcast := ShaderMaterial.new()
		overcast.shader = FLOODED_SKY
		var sky := Sky.new()
		sky.radiance_size = Sky.RADIANCE_SIZE_128
		sky.sky_material = overcast
		world.environment.background_mode = Environment.BG_SKY
		world.environment.sky = sky
		world.environment.ambient_light_color = Color("b3cde0")
		world.environment.ambient_light_energy = 0.63
		world.environment.fog_enabled = true
		world.environment.fog_light_color = Color("6c899d")
		world.environment.fog_density = 0.0042
		world.environment.fog_sky_affect = 0.13
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-60,-25,0)
	sun.light_color = Color(0.76,0.87,1)
	sun.light_energy = 1.5
	sun.shadow_enabled = true
	if is_instance_valid(_court):
		sun.rotation_degrees = Vector3(-36, 46, 0)
		sun.light_color = Color("d5e5ed")
		sun.light_energy = 1.62
		sun.directional_shadow_max_distance = 74.0
	add_child(sun)
	Events.enemy_registered.connect(_register_walker)
	Events.gunshot.connect(_on_gunshot)
	get_tree().node_added.connect(_on_node_added)
	# A realm can be inserted after actors (standalone benches / restored rooms).
	_scan_existing(get_parent())
	_install_void()

func _build_basin_ruins() -> void:
	var points := [Vector2(-4.8, 0.7), Vector2(4.6, 4.2), Vector2(-4.6, -9.9),
		Vector2(5.0, -12.0), Vector2(-12.8, -3.9), Vector2(10.7, 0.3)]
	var sizes := [Vector3(1.68, 3.6, 1.56), Vector3(1.76, 2.85, 1.60),
		Vector3(1.55, 2.55, 1.60), Vector3(1.96, 3.38, 1.65), Vector3(3.85, 1.30, 1.02), Vector3(2.75, 1.24, 0.95)]
	var ruins: Array[StaticBody3D] = []
	for i in points.size():
		var size: Vector3 = sizes[i]
		var block := _block("BasinRuin%d" % (i + 1), Vector3(points[i].x, size.y * 0.5, points[i].y), size)
		block.rotation.y = [0.17, -0.31, 0.24, 0.11, 0.51, -0.35][i]
		ruins.append(block)
	_court.dress_ruins(ruins)

func provides_stage_lighting() -> bool:
	return chamber_style == 1 and not boss_arena

func start_whirlpools(run_seed: int, room_index: int) -> void:
	if not is_instance_valid(_court):
		return
	_whirlpool_rng = RandomNumberGenerator.new()
	_whirlpool_rng.seed = run_seed ^ ((room_index + 1) * 0x47B9A13D)
	_whirlpools.clear()
	_next_whirlpool_at = clock
	water_material.set_shader_parameter("whirlpool_lifetime", WHIRLPOOL_DURATION)
	water_material.set_shader_parameter("whirlpool_depth", WHIRLPOOL_DEPTH)
	_tick_whirlpools()


func _tick_whirlpools() -> void:
	if _whirlpool_rng == null or clock + 0.00001 < _next_whirlpool_at:
		return
	var clear_sites := WHIRLPOOL_SITES.filter(func(site: Vector2) -> bool:
		for funnel in _whirlpools:
			if site.distance_to(Vector2(funnel.x, funnel.y)) < 2.0 * WHIRLPOOL_RADIUS + WHIRLPOOL_JITTER * 2.0:
				return false
		return true)
	var center: Vector2 = clear_sites[_whirlpool_rng.randi_range(0, clear_sites.size() - 1)]
	center += Vector2(_whirlpool_rng.randf_range(-WHIRLPOOL_JITTER, WHIRLPOOL_JITTER),
		_whirlpool_rng.randf_range(-WHIRLPOOL_JITTER, WHIRLPOOL_JITTER))
	if _whirlpools.size() == WHIRLPOOL_LIMIT:
		_whirlpools.pop_front()
	_whirlpools.append(Vector4(center.x, center.y, WHIRLPOOL_RADIUS, _next_whirlpool_at))
	_next_whirlpool_at += WHIRLPOOL_INTERVAL
	var shader_funnels := PackedVector4Array(_whirlpools)
	shader_funnels.resize(WHIRLPOOL_LIMIT)
	water_material.set_shader_parameter("whirlpools", shader_funnels)


func _ground_current(point: Vector3) -> Vector4:
	if deprived or not is_inside_tree() or not _over_water(point):
		return Vector4.ZERO
	var local := to_local(point)
	for funnel in _whirlpools:
		var toward := Vector2(funnel.x - local.x, funnel.y - local.z)
		var distance := toward.length()
		if distance >= funnel.z:
			continue
		var age := clock - funnel.w
		var strength := smoothstep(0.0, 0.55, age) * smoothstep(0.0, 0.55, WHIRLPOOL_DURATION - age)
		var in_core := distance <= WHIRLPOOL_CORE_RADIUS and age >= 0.15 and age < WHIRLPOOL_DURATION
		# Slow down at the center so the current settles the player without oscillating.
		var falloff := minf(distance / WHIRLPOOL_CORE_RADIUS, 1.0) * (1.0 - smoothstep(0.70, 1.0, distance / funnel.z))
		var flow := toward.normalized() * WHIRLPOOL_PULL_SPEED * falloff * strength
		var world_flow := global_basis * Vector3(flow.x, 0.0, flow.y)
		return Vector4(world_flow.x, world_flow.y, world_flow.z, 1.0 if in_core else 0.0)
	return Vector4.ZERO

## 坠落边界：玩家掉出去扣 30 点生命并回到上次稳定平台，敌人掉出去直接死。
func player_spawn() -> Vector3:
	return Vector3(0, 0, 16)


## Legacy five first, then open basin floor clear of BasinRuins, platform
## edges and the boundary walls in both chamber styles.
func spawn_points() -> Array[Vector3]:
	return [
		Vector3(-8, 0.1, 3), Vector3(11.5, 0.1, -4), Vector3(0, 0.1, -12),
		Vector3(-11, 0.1, -12), Vector3(11, 0.1, -14),
		Vector3(-14, 0.1, 10), Vector3(14, 0.1, 8),
		Vector3(-12, 0.1, -19), Vector3(2, 0.1, 8),
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

## Room audio owns splashes in production; standalone geometry keeps fallback.
func set_audio_managed(active: bool) -> void:
	audio_managed = active
	if active and is_instance_valid(splash): splash.stop()

func set_player(value: Player) -> void:
	player = value
	if is_instance_valid(_court):
		player.realm_effects.ground_current = _ground_current
	_register_walker(value)
	# RealmStage also owns a generic WorldEnvironment; use an explicit camera
	# override so sorrow SSR cannot depend on world-environment ready order.
	player.view_camera.environment = mirror_environment
	if is_instance_valid(void_fall):
		void_fall.setup(value)

func set_water_level(value: float) -> void:
	water_level = clampf(value,0.0,1.7)
	if is_instance_valid(water):
		water.position.y = water_level
	if _rain_motion != null:
		_rain_motion.set_shader_parameter("water_level",water_level)

func set_deprivation(active: bool) -> void:
	deprived = active
	_walkers.clear()
	_last_step = Vector3.INF
	if water_material != null:
		for i in RIPPLE_CAPACITY:
			_ripples[i] = Vector4(0,0,-100,0)
		water_material.set_shader_parameter("ripples",_ripples)
		water_material.set_shader_parameter("rain_enabled",not active)
	if not active:
		_scan_existing(get_parent())
	if is_instance_valid(water):
		water.visible = not active
	if is_instance_valid(rain):
		rain.emitting = not active
		rain.visible = not active
	if active and is_instance_valid(splash):
		splash.stop()
	if _white != null:
		_white.albedo_color = Color(0.72,0.69,0.66) if active else Color(0.75,0.82,0.84)
	if is_instance_valid(_court):
		_basin_floor_visual.position.y = 0.0 if active else -WHIRLPOOL_DEPTH
		_court.set_deprivation(active)

## Presentation only. Existing dive/resurface callers and splash audio keep
## their interface. Positions are checked against this basin before allocation.
func add_ripple(point: Vector3, strength := 1.0) -> void:
	if deprived or not is_inside_tree() or get_tree().paused or not _over_water(point,0.42):
		return
	var local := to_local(point)
	_ripples[ripple_count % RIPPLE_CAPACITY] = Vector4(local.x,local.z,clock,clampf(strength,0.1,2.0))
	ripple_count += 1
	water_material.set_shader_parameter("ripples",_ripples)

func _over_water(point: Vector3, allowance := 0.04) -> bool:
	var local := to_local(point)
	return absf(local.x) < 19.75 and absf(local.z) < 23.7 and local.y >= -0.15 and local.y <= water_level + allowance

func _belongs(node: Node) -> bool:
	return is_instance_valid(node) and is_instance_valid(get_parent()) and get_parent().is_ancestor_of(node)

func _register_walker(node: Node3D) -> void:
	if not _belongs(node) or not node is CharacterBody3D:
		return
	_walkers[node.get_instance_id()] = {"ref":weakref(node),"point":node.global_position,"side":1.0}

func _on_node_added(node: Node) -> void:
	if node is TearCrystal and _belongs(node):
		# spawn_tear sets position after add_child; observe it on the next tick.
		if not _tears.has(node.get_instance_id()):
			_tears[node.get_instance_id()] = {"ref":weakref(node),"landed":false}
			node.tree_exiting.connect(_on_tear_exiting.bind(node),CONNECT_ONE_SHOT)

func _scan_existing(root: Node) -> void:
	for child in root.get_children():
		if child is Enemy or child is Player:
			_register_walker(child)
		elif child is TearCrystal:
			_on_node_added(child)
		_scan_existing(child)

func _tick_visuals() -> void:
	for key: int in _walkers.keys():
		var entry: Dictionary = _walkers[key]
		var body := entry.ref.get_ref() as CharacterBody3D
		if not is_instance_valid(body) or body.is_queued_for_deletion():
			_walkers.erase(key)
			continue
		var point := body.global_position
		var health := body.get("health") as Health
		if health == null or health.is_dead() or not _over_water(point) or not body.is_on_floor():
			entry.point = point
			continue
		var distance := point.distance_to(entry.point)
		# Teleports/resurfacing must not draw a wake across the whole room.
		if distance > 5.5:
			entry.point = point
			continue
		var fast := Vector2(body.velocity.x,body.velocity.z).length() > 10.0
		var spacing := 0.32 if fast else 0.6
		if distance < spacing:
			continue
		var origin: Vector3 = entry.point
		var count := mini(6,int(distance / spacing))
		for i in count:
			var foot: Vector3 = origin.move_toward(point,(i+1)*spacing) + body.global_basis.x * entry.side * 0.11
			add_ripple(foot,1.6 if fast else 0.8)
			movement_ripple_count += 1
			entry.side *= -1.0
		entry.point = origin.move_toward(point,count*spacing)
	for key: int in _tears.keys():
		var entry: Dictionary = _tears[key]
		var tear := entry.ref.get_ref() as TearCrystal
		if not is_instance_valid(tear):
			_tears.erase(key)
			continue
		if tear.consumed:
			_tear_ring(tear.global_position,1.8)
			_tears.erase(key)
		elif not entry.landed:
			_tear_ring(tear.global_position,0.8)
			entry.landed = true

func _on_tear_exiting(tear: TearCrystal) -> void:
	if _tears.has(tear.get_instance_id()) and tear.consumed and not is_queued_for_deletion():
		_tear_ring(tear.global_position,1.8)
	_tears.erase(tear.get_instance_id())

func _tear_ring(point: Vector3, strength: float) -> void:
	var before := ripple_count
	add_ripple(point,strength)
	if ripple_count > before:
		tear_ripple_count += 1

func _on_gunshot(point: Vector3) -> void:
	if deprived or get_tree().paused or not _belongs(player):
		return
	# A successful shot transmits its recoil to the shooter's wet feet.
	# Do not re-raycast an approximate aim direction: the weapon owns spread
	# and hit resolution. Real tear firing/pickup is observed independently.
	if player.health.is_dead() or point.distance_to(player.weapon.global_position) > 0.1:
		return
	var before := ripple_count
	if _over_water(player.global_position):
		add_ripple(player.global_position,0.65)
	shot_ripple_count += ripple_count - before

func _physics_process(delta: float) -> void:
	if deprived:
		return
	clock += delta
	_tick_whirlpools()
	if is_instance_valid(_court):
		_court.set_clock(clock)
	water_material.set_shader_parameter("clock",clock)
	_rain_motion.set_shader_parameter("clock",clock)
	_tick_visuals()
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
	rain = preload("res://environments/sorrow/rain_particles.tscn").instantiate() as GPUParticles3D
	_rain_motion = rain.process_material as ShaderMaterial
	_rain_motion.set_shader_parameter("water_level",water_level)
	add_child(rain)

func _splash_sound() -> AudioStreamWAV:
	return SorrowSoundBank.get_sound(&"water_step")

func _exit_tree() -> void:
	if Events.enemy_registered.is_connected(_register_walker):
		Events.enemy_registered.disconnect(_register_walker)
	if Events.gunshot.is_connected(_on_gunshot):
		Events.gunshot.disconnect(_on_gunshot)
	if get_tree().node_added.is_connected(_on_node_added):
		get_tree().node_added.disconnect(_on_node_added)
	_walkers.clear()
	_tears.clear()
	if is_instance_valid(splash):
		splash.stop()
		splash.stream = null
