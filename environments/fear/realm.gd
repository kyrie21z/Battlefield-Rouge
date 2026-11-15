class_name FearRealm
extends Node3D
## Falling players lose a fixed amount of HP and return to stable bridge ground.
@export var boss_arena := false
@export var warnings_enabled := true
@export_range(0,1) var chamber_style := 0
var sanctum: FearSanctum
var tiles: Array[FearFlipTile] = []
var abyss: Area3D
var scan_lights: Array[Node3D] = []
var scan_time := 0.0
var deprivation := false
var _falling: Array[WeakRef] = []
const FALL_HEIGHT := -12.0
var _player: WeakRef
const FALL_DAMAGE := 30.0
var _safe_position := Vector3.INF
var _safe_check_left := 0.0
var _recover_pending := false
var _recover_cooldown := 0.0

func set_player(value: Player) -> void:
	_player = weakref(value)
	_safe_position = global_position + player_spawn() + Vector3.UP*0.12
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
	_build_void()
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

func _build_void() -> void:
	abyss = Area3D.new()
	abyss.name = "FatalAbyss"
	abyss.collision_layer = 0
	abyss.collision_mask = CollisionLayers.ACTORS | CollisionLayers.ENEMIES
	abyss.position = Vector3(0, -15, 0)
	var collision := CollisionShape3D.new()
	var volume := BoxShape3D.new()
	volume.size = Vector3(180, 6, 180)
	collision.shape = volume
	abyss.add_child(collision)
	add_child(abyss)
	abyss.body_entered.connect(_on_abyss_entered)

func _on_abyss_entered(body: Node3D) -> void:
	if body is Player:
		_queue_recovery(body as Player)
		return
	_falling.append(weakref(body))
	_fatal_fall(body)

func _queue_recovery(player: Player) -> void:
	if _recover_pending or _recover_cooldown > 0.0 or player.health.is_dead():
		return
	_recover_pending = true
	_recover_cooldown = 0.3
	player.cancel_forced_movement()
	_recover_player.call_deferred(weakref(player))

func _recover_player(reference: WeakRef) -> void:
	var player := reference.get_ref() as Player
	if is_instance_valid(player) and not player.health.is_dead():
		var landing := _safe_position
		if landing == Vector3.INF or not _landing_clear(landing):
			landing = global_position + player_spawn() + Vector3.UP*0.12
			for offset in [Vector3.ZERO,Vector3(-2,0,0),Vector3(2,0,0),Vector3(0,0,-2),Vector3(0,0,2),Vector3(-2,0,-2),Vector3(2,0,-2),Vector3(-2,0,2),Vector3(2,0,2)]:
				var candidate: Vector3 = global_position+player_spawn()+offset+Vector3.UP*0.12
				if _landing_clear(candidate):
					landing = candidate
					break
		player.recover_from_fall(landing)
		player.health.apply_damage(FALL_DAMAGE,Hitbox.BodyPart.BODY,null,
			{"environmental_penalty":true,"true_damage":true,"tag":&"abyss"})
	_recover_pending = false

func _landing_clear(point: Vector3) -> bool:
	var support := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.2,point-Vector3.UP*0.5,CollisionLayers.WORLD)
	var ground := get_world_3d().direct_space_state.intersect_ray(support)
	if ground.is_empty() or not ground.collider is StaticBody3D or ground.normal.y < 0.8:
		return false
	var shape := CapsuleShape3D.new()
	shape.radius = 0.35
	shape.height = 1.8
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform.origin = point + Vector3.UP*0.9
	query.collision_mask = CollisionLayers.WORLD | CollisionLayers.ENEMIES
	return get_world_3d().direct_space_state.intersect_shape(query,1).is_empty()

func _remember_safe_floor(player: Player) -> void:
	if not player.is_on_floor():
		return
	# Stable floors only, with support around the whole capsule rather than an edge.
	for offset in [Vector3.ZERO,Vector3(0.6,0,0),Vector3(-0.6,0,0),Vector3(0,0,0.6),Vector3(0,0,-0.6)]:
		var point: Vector3 = player.global_position + offset
		var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*0.3,point-Vector3.UP*0.5,CollisionLayers.WORLD)
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if hit.is_empty() or not hit.collider is StaticBody3D or hit.normal.y < 0.8:
			return
	_safe_position = player.global_position + Vector3.UP*0.12

func _fatal_fall(body: Node3D) -> void:
	var hp := body.get_node_or_null("Health") as Health
	if hp != null and not hp.is_dead():
		hp.apply_damage(hp.max_health + hp.health + hp.shield_points + 1000.0, Hitbox.BodyPart.BODY, null,
			{"environmental_fatal": true, "true_damage": true, "tag": &"abyss"})

func _physics_process(delta: float) -> void:
	_recover_cooldown = maxf(0.0,_recover_cooldown-delta)
	_safe_check_left -= delta
	# A height boundary also catches fast dashes and falls beyond the Area's box.
	var player := _player.get_ref() as Player if _player != null else null
	if is_instance_valid(player) and player.global_position.y <= global_position.y + FALL_HEIGHT:
		_queue_recovery(player)
	elif is_instance_valid(player) and _safe_check_left <= 0.0:
		_safe_check_left = 0.15
		_remember_safe_floor(player)
	scan_time += delta
	for i in scan_lights.size():
		var pivot := scan_lights[i]
		pivot.look_at(global_position + Vector3(sin(scan_time * 0.15 + i * PI) * 9, 0, cos(scan_time * 0.19) * 14))
	for index in range(_falling.size() - 1, -1, -1):
		var body := _falling[index].get_ref() as Node3D
		if not is_instance_valid(body) or body.global_position.y > -12:
			_falling.remove_at(index)
		else:
			_fatal_fall(body)

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
	return [Vector3(-7, 0, 8), Vector3(7, 0, 8), Vector3(-7, 0, -8), Vector3(7, 0, -8)]

func player_spawn() -> Vector3:
	return Vector3(0, 0, 16)

func exit_position() -> Vector3:
	return Vector3(0, 0, -20)
