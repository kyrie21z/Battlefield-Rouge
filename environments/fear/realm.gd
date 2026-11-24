class_name FearRealm
extends Node3D
## Falling players lose a fixed amount of HP and return to stable bridge ground.
@export var boss_arena := false
@export var warnings_enabled := true
@export_range(0,1) var chamber_style := 0
var sanctum: FearSanctum
var tiles: Array[FearFlipTile] = []
var abyss: Area3D
var void_fall: RealmVoid
var scan_lights: Array[Node3D] = []
var scan_time := 0.0
var deprivation := false

func set_player(value: Player) -> void:
	if is_instance_valid(void_fall):
		void_fall.setup(value)
	if is_instance_valid(sanctum):
		value.view_camera.environment = sanctum.environment

func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.83, 0.82, 0.88)
	stone.roughness = 0.82
	_floor("Entry", Vector3(0, -0.3, 16), Vector3(9, 0.6, 8), stone)
	_floor("Exit", Vector3(0, -0.3, -20), Vector3(9, 0.6, 7), stone)
	# Fixed gaps coincide exactly with rotating slabs. Side routes stay connected.
	for segment in [[10.0, 4.0], [7.45, 1.1], [2.5, 1.2], [-2.5, 1.2], [-10.5, 7.2], [-15.5, 3.0]]:
		_floor("Bridge", Vector3(0, -0.225, segment[0]), Vector3(4, 0.45, segment[1]), stone)
	for z in [5.0, 0.0, -5.0]:
		var tile := FearFlipTile.new()
		tile.position = Vector3(0, -0.225, z)
		tile.warnings_enabled = warnings_enabled
		add_child(tile)
		tiles.append(tile)
	for side in [-1.0, 1.0]:
		for z in [8.0, -8.0]:
			_floor("Island", Vector3(side * 7, -0.4, z), Vector3(7, 0.8, 7), stone)
			_floor("Crossing", Vector3(side * 3.5, -0.23, z), Vector3(7, 0.46, 3), stone)
		_floor("SideBridge", Vector3(side * 7, -0.25, 0), Vector3(2.7, 0.5, 16), stone)
	if boss_arena:
		_floor("OculusDais", Vector3(0, -0.45, -8), Vector3(18, 0.9, 11), stone)
	_install_void()
	sanctum = FearSanctum.new()
	sanctum.name = "WhiteSanctum"
	sanctum.chamber = chamber_style
	sanctum.boss_room = boss_arena
	add_child(sanctum)
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * 25, 17, -10)
		add_child(pivot)
		var beam := SpotLight3D.new()
		beam.light_color = Color(0.53, 0.3, 0.96)
		beam.light_energy = 7.0
		beam.spot_range = 72.0
		beam.spot_angle = 13.0
		beam.shadow_enabled = true
		pivot.add_child(beam)
		var cone := MeshInstance3D.new()
		var shape := CylinderMesh.new()
		shape.top_radius = 0.01
		shape.bottom_radius = 10
		shape.height = 45
		shape.radial_segments = 16
		cone.mesh = shape
		cone.rotation.x = PI * 0.5
		cone.position.z = -22.5
		var mist := StandardMaterial3D.new()
		mist.albedo_color = Color(0.27, 0.16, 0.48, 0.008)
		mist.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mist.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mist.cull_mode = BaseMaterial3D.CULL_DISABLED
		cone.material_override = mist
		cone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pivot.add_child(cone)
		scan_lights.append(pivot)

func _floor(label: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	body.set_meta("walkable_surface", true)
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	body.add_child(mesh)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	collision.shape = shape
	body.add_child(collision)
	add_child(body)
	return body

## 坠落边界统一交给 RealmVoid。这里的 `abyss` 只是把组件的体积转发出去，
## 供既有诊断与测试读取；行为与其余三关完全一致（玩家 -30 血、敌人致死）。
func _install_void() -> void:
	void_fall = RealmVoid.new()
	void_fall.name = "VoidFall"
	void_fall.fall_height = -12.0
	void_fall.spawn_fallback = player_spawn()
	add_child(void_fall)
	abyss = void_fall.abyss

func _physics_process(delta: float) -> void:
	scan_time += delta
	for i in scan_lights.size():
		var pivot := scan_lights[i]
		pivot.look_at(global_position + Vector3(sin(scan_time * 0.15 + i * PI) * 9, 0, cos(scan_time * 0.19) * 14))

func flip_tile_near(point: Vector3) -> bool:
	var selected: FearFlipTile
	var distance := 6.0
	for tile in tiles:
		var next := tile.global_position.distance_to(point)
		if next < distance and tile.elapsed < 0.0:
			distance = next
			selected = tile
	return selected.trigger() if selected != null else false

func set_deprivation(active: bool) -> void:
	deprivation = active
	warnings_enabled = not active
	for tile in tiles:
		tile.set_warnings_enabled(warnings_enabled)

func spawn_points() -> Array[Vector3]:
	# Islands first (legacy single-room layout), then side bridges and the two
	# stable rear bridge segments. Never on a gap or a FearFlipTile.
	return [
		Vector3(-7, 0, 8), Vector3(7, 0, 8), Vector3(-7, 0, -8), Vector3(7, 0, -8),
		Vector3(-6.5, 0, 0), Vector3(6.5, 0, 0),
		Vector3(0, 0, -11.5), Vector3(0, 0, -15.5),
	]

func player_spawn() -> Vector3:
	return Vector3(0, 0, 16)

func exit_position() -> Vector3:
	return Vector3(0, 0, -20)
