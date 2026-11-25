class_name FearRealm
extends Node3D
## Falling players lose a fixed amount of HP and return to stable bridge ground.
@export var boss_arena := false
@export var warnings_enabled := true
@export_range(0,1) var chamber_style := 0
const STAIR_START := -12.20
const STAIR_END := -24.40
const STAIR_WIDTH := 10.8
const LANDING_WIDTH := 12.8
const LANDING_HEIGHT := 2.90
var sanctum: FearSanctum
var tiles: Array[FearFlipTile] = []
var abyss: Area3D
var void_fall: RealmVoid
var deprivation := false

func set_player(value: Player) -> void:
	if is_instance_valid(void_fall):
		void_fall.setup(value)
	if is_instance_valid(sanctum):
		value.view_camera.environment = sanctum.environment

func provides_stage_lighting() -> bool:
	return true

func _ready() -> void:
	sanctum = FearSanctum.new()
	sanctum.name = "VioletCastle"
	sanctum.chamber = chamber_style
	sanctum.boss_room = boss_arena
	sanctum.landing_height = LANDING_HEIGHT
	add_child(sanctum)
	var stone := sanctum.walk_stone
	_floor("Entry", Vector3(0, -0.3, 17.35), Vector3(9, 0.6, 11.0), stone)
	_build_exit_stair(stone)
	# Fixed gaps coincide exactly with rotating slabs. Side routes stay connected.
	for segment in [[10.0, 4.0], [7.45, 1.1], [2.5, 1.2], [-2.5, 1.2], [-10.5, 7.2], [-15.5, 3.0]]:
		_floor("Bridge", Vector3(0, -0.225, segment[0]), Vector3(4, 0.45, segment[1]), stone)
	for z in [5.0, 0.0, -5.0]:
		var tile := FearFlipTile.new()
		tile.position = Vector3(0, -0.225, z)
		tile.stone_material = stone
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

func _build_exit_stair(stone: Material) -> void:
	var run := STAIR_START - STAIR_END
	var angle := atan2(LANDING_HEIGHT, run)
	var basis := Basis(Vector3.RIGHT, angle)
	var thickness := 0.25
	var middle := Vector3(0, LANDING_HEIGHT * 0.5, (STAIR_START + STAIR_END) * 0.5)
	var ramp := _floor("ExitSlope", middle - basis.y * thickness * 0.5,
		Vector3(STAIR_WIDTH, thickness, sqrt(run * run + LANDING_HEIGHT * LANDING_HEIGHT)), null)
	ramp.rotation.x = angle
	var landing_edge := STAIR_END + 0.015
	var landing_back := -28.0
	_floor("Exit", Vector3(0, LANDING_HEIGHT - 0.3, (landing_edge + landing_back) * 0.5),
		Vector3(LANDING_WIDTH, 0.6, landing_edge - landing_back), stone)
	var back_wall := _floor("ChancelBackWall", Vector3(0, 6.0, -28.30), Vector3(35.4, 28.0, 0.60), null)
	back_wall.set_meta("walkable_surface", false)
	sanctum.dress_stairs(STAIR_START, STAIR_END, STAIR_WIDTH)


func _floor(label: String, pos: Vector3, size: Vector3, mat: Material) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = pos
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	body.set_meta("walkable_surface", true)
	if mat != null:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = size
		mesh.mesh = box
		mesh.material_override = mat
		# Shared collision stays flush. Separate only the visible tops where slabs overlap.
		match label:
			"Entry", "Exit": mesh.position.y = -0.006
			"Island": mesh.position.y = -0.010
			"Crossing": mesh.position.y = -0.015
			"SideBridge": mesh.position.y = -0.020
			"OculusDais": mesh.position.y = 0.006
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
		Vector3(0, 0, -11.5), Vector3(0, _stair_height(-15.5), -15.5),
	]

func _stair_height(z: float) -> float:
	return LANDING_HEIGHT * clampf(inverse_lerp(STAIR_START, STAIR_END, z), 0.0, 1.0)


func player_spawn() -> Vector3:
	return Vector3(0, 0, 17.5)

func exit_position() -> Vector3:
	return Vector3(0, LANDING_HEIGHT, -25.8)
