class_name FearSanctum
extends Node3D
## A vaulted castle built around the playable bridges. Only the balconies and cover
## own collision. The dark crypt below is empty and never joins navigation.
const STONE := preload("res://environments/fear/castle_stone.gdshader")
const GLASS := preload("res://environments/fear/castle_glass.gdshader")

var chamber := 0
var boss_room := false
var landing_height := 0.0
var environment: Environment
var scenery: Node3D
var combat: Node3D
var walk_stone: ShaderMaterial
var decor_instances := 0
var ghosts: Array[Node3D] = []
var _ghost_routes: Array[Curve3D] = []
var _ghost_time := 0.0
var _batches: Dictionary[Material, SurfaceTool] = {}
var _unit_box := BoxMesh.new()
var _wall: ShaderMaterial
var _ashlar: ShaderMaterial
var _frame: StandardMaterial3D
var _metal: StandardMaterial3D
var _brass: StandardMaterial3D
var _glass: ShaderMaterial
var _medallion: ShaderMaterial
var _flame: StandardMaterial3D
var _rim: StandardMaterial3D

func _ready() -> void:
	var preset := MonumentOptics.realm_preset("fear")
	var wall_cfg: Dictionary = (preset["wall"] as Dictionary).duplicate()
	wall_cfg["stone_albedo"] = Color("6b6380")
	_wall = MonumentOptics.make_stone_material(wall_cfg, false)
	_ashlar = MonumentOptics.make_stone_material(preset["wall"], false)
	walk_stone = MonumentOptics.make_stone_material(preset["floor"], true)
	_frame = MonumentOptics.make_obsidian_material(Color("221a33"))
	_metal = MonumentOptics.make_obsidian_material(preset["obsidian_color"])
	_brass = MonumentOptics.make_trim_material(preset["trim_color"])
	_flame = _material(Color("efad79"), 0.62, 1.15)
	_rim = _material(Color("ad8cc7"), 0.71, 0.40)
	_glass = ShaderMaterial.new()
	_glass.shader = GLASS
	_glass.set_shader_parameter("tint_shift", float(chamber) * 2.0)
	_medallion = _glass.duplicate() as ShaderMaterial
	_medallion.set_shader_parameter("medallion", 1.0)
	scenery = Node3D.new()
	scenery.name = "CastleArchitecture"
	scenery.add_to_group("fear_scenery")
	add_child(scenery)
	combat = Node3D.new()
	combat.name = "SideBalconies"
	add_child(combat)
	_build_environment()
	_vault()
	_chancel()
	_bridge_details()
	_crypt()
	if not boss_room:
		_balconies()
	_ghosts()
	_commit_architecture()

func _stone(color: Color, size: Vector2, mortar: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = STONE
	mat.set_shader_parameter("stone_color", color)
	mat.set_shader_parameter("block_size", size)
	mat.set_shader_parameter("mortar", mortar)
	return mat

func _material(color: Color, roughness: float, glow := 0.0) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	if glow > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = glow
	return mat

func _build_environment() -> void:
	var preset := MonumentOptics.realm_preset("fear")
	environment = preload("res://environments/default_env.tres").duplicate() as Environment
	MonumentOptics.configure_environment(environment, preset["env"])
	var world := WorldEnvironment.new()
	world.name = "FearEnvironment"
	world.environment = environment
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.name = "MoonKeyLight"
	MonumentOptics.configure_sun(sun, preset["sun_rot"], preset["sun_color"], preset["sun_energy"])
	add_child(sun)
	for z_pos: float in [10.0, -2.0, -14.0]:
		var nave_light := OmniLight3D.new()
		nave_light.name = "NaveLight_%d" % int(z_pos)
		nave_light.position = Vector3(0.0, 7.2, z_pos)
		nave_light.light_color = Color("d0c2ff")
		nave_light.light_energy = 4.2
		nave_light.omni_range = 24.0
		nave_light.omni_attenuation = 1.3
		nave_light.shadow_enabled = (z_pos == -2.0)
		add_child(nave_light)
	for side: float in [-1.0, 1.0]:
		MonumentOptics.add_volumetric_shaft(
			self, Vector3(side * 12.8, 7.6, 3.5), Vector3(-side * 1.5, 0.0, 1.0),
			Color("c2abff"), 11.5, 3.6, 30.0, 44.0, true
		)
	MonumentOptics.add_reflection_probe(self, Vector3(44.0, 26.0, 62.0), Vector3(0.0, 7.0, -2.0), 1.0)

func _box(point: Vector3, size: Vector3, mat: Material, orientation := Basis.IDENTITY) -> void:
	if not _batches.has(mat):
		var batch := SurfaceTool.new()
		batch.begin(Mesh.PRIMITIVE_TRIANGLES)
		_batches[mat] = batch
	_batches[mat].append_from(_unit_box, 0, Transform3D(orientation * Basis.from_scale(size), point))

func _commit_architecture() -> void:
	for mat in _batches:
		_mesh(_batches[mat].commit(), mat, Vector3.ZERO, "BatchedMasonry")
	_batches.clear()

func _mesh(mesh: Mesh, mat: Material, point: Vector3, label: String, parent: Node3D = null) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = mat
	visual.position = point
	visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	(parent if parent != null else scenery).add_child(visual, true)
	decor_instances += 1
	return visual

func _rib(start: Vector3, finish: Vector3, width: float, mat: Material) -> void:
	var direction := (start - finish).normalized()
	var up := Vector3.FORWARD if absf(direction.y) > 0.98 else Vector3.UP
	_box((start + finish) * 0.5, Vector3(width, width, start.distance_to(finish) + width * 0.20),
		mat, Basis.looking_at(direction, up))

func _vault() -> void:
	var profile: Array[Vector2] = [
		Vector2(-17, 9.35), Vector2(-13, 12.7), Vector2(-8.8, 16.3), Vector2(-4.4, 18.7), Vector2(0, 21.7),
		Vector2(4.4, 18.7), Vector2(8.8, 16.3), Vector2(13, 12.7), Vector2(17, 9.35),
	]
	for i in profile.size() - 1:
		var start := profile[i]
		var end := profile[i + 1]
		var middle := (start + end) * 0.5
		_box(Vector3(middle.x, middle.y + 0.34, -3), Vector3(start.distance_to(end) + 0.50, 0.62, 53),
			_wall, Basis(Vector3.BACK, (end - start).angle()))
	for z: float in [19.0, 8.0, -3.0, -14.0, -25.0]:
		for i in profile.size() - 1:
			var start := Vector3(profile[i].x, profile[i].y, z)
			var end := Vector3(profile[i + 1].x, profile[i + 1].y, z)
			_rib(start, end, 0.70, _ashlar)
			_rib(start + Vector3.DOWN * 0.41, end + Vector3.DOWN * 0.41, 0.17, _frame)
		for side: float in [-1.0, 1.0]:
			var x := side * 16.6
			_box(Vector3(x, -0.9, z), Vector3(2.2, 21, 1.95), _ashlar)
			_box(Vector3(x - side * 0.9, 2.0, z), Vector3(0.65, 15, 1.05), _frame)
			_box(Vector3(x - side * 0.5, 9.05, z), Vector3(2.05, 0.60, 2.65), _ashlar)
			_box(Vector3(x - side * 0.7, 8.59, z), Vector3(1.85, 0.15, 2.45), _brass)
			if z != -25.0:
				var capital := Vector3(x, 9.15, z)
				_rib(capital, Vector3(side * 8.8, 15.9, z - 5.5), 0.30, _frame)
	for side: float in [-1.0, 1.0]:
		_box(Vector3(side * 17.3, -1.4, -3), Vector3(1.0, 22.25, 54), _wall)
		for y: float in [-5.8, 1.0, 6.0]:
			_box(Vector3(side * 16.64, y, -3), Vector3(0.34, 0.18, 53), _frame)
		for bay in 4:
			var z := 13.5 - bay * 11.0
			var axis := Vector3.BACK * side
			var window := Vector3(side * 16.67, 2.25, z)
			_lancet(window - axis * 1.75, axis, 2.85, 7.0)
			_lancet(window + axis * 1.75, axis, 2.85, 7.0)
			_omni(Vector3(side * 13.2, 5.3, z), Color("a882ed"), 1.68, 12.0)

func _lancet(base: Vector3, axis: Vector3, width: float, height: float) -> void:
	var profile := PackedVector2Array([
		Vector2(-0.5, 0), Vector2(0.5, 0), Vector2(0.5, 0.63), Vector2(0.37, 0.82),
		Vector2(0, 1), Vector2(-0.37, 0.82), Vector2(-0.5, 0.63),
	])
	_pane(base, axis, Vector2(width, height), profile, _glass, Vector2(0, 0.45), "Lancet")
	var toward := axis.cross(Vector3.UP)
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var start := base + axis * a.x * width + Vector3.UP * a.y * height
		var end := base + axis * b.x * width + Vector3.UP * b.y * height
		_rib(start + toward * 0.06, end + toward * 0.06, 0.30, _metal)
		_rib(start + toward * 0.22, end + toward * 0.22, 0.088, _frame)
	_rib(base + toward * 0.10, base + Vector3.UP * height + toward * 0.10, 0.11, _metal)

func _pane(base: Vector3, axis: Vector3, size: Vector2, edge: PackedVector2Array,
		mat: Material, center: Vector2, label: String) -> void:
	var face := SurfaceTool.new()
	face.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in edge.size():
		for point: Vector2 in [center, edge[i], edge[(i + 1) % edge.size()]]:
			face.set_uv(Vector2(point.x + 0.5, point.y))
			face.add_vertex(axis * point.x * size.x + Vector3.UP * point.y * size.y)
	_mesh(face.commit(), mat, base, label)

func _chancel() -> void:
	_box(Vector3(0, 1.4, -28.3), Vector3(35.4, 40, 0.8), _wall)
	_box(Vector3(0, 1.4, 23.5), Vector3(35.4, 40, 1.0), _wall)
	var width := 13.2 if boss_room else 9.6
	var center := Vector3(0, 11.7 if boss_room else 10.4, -27.79)
	var profile := PackedVector2Array()
	for i in 48:
		var angle := TAU * float(i) / 48.0
		profile.append(Vector2(cos(angle), sin(angle) + 1.0) * 0.5)
	var glass_height := width * (0.70 if boss_room else 0.90)
	var base := center - Vector3.UP * glass_height * 0.5
	_pane(base, Vector3.RIGHT, Vector2(width, glass_height), profile, _medallion, Vector2(0, 0.5), "RoseWindow")
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var start := base + Vector3(a.x * width, a.y * glass_height, 0.15)
		var end := base + Vector3(b.x * width, b.y * glass_height, 0.15)
		_rib(start, end, 0.36, _ashlar)
		if i % 4 == 0:
			_rib(center + (start - center) * 0.29, start, 0.105, _frame)
	if boss_room:
		_rib(center + Vector3(0, -1.8, 0.29), center + Vector3(0, 1.8, 0.29), 0.20, _rim)
	for side: float in [-1.0, 1.0]:
		for index in 2:
			_lancet(Vector3(side * (8.4 + index * 3.7), 3.15, -27.78), Vector3.RIGHT, 2.15, 8.5 - index)
		var plinth := Vector3(side * 4.35, landing_height, -27.0)
		_box(plinth + Vector3.UP * 2.35, Vector3(1.25, 7.3, 1.25), _ashlar)
		_box(plinth + Vector3.UP * 5.9, Vector3(1.68, 0.44, 1.68), _frame)
		_rib(plinth + Vector3.UP * 5.9, Vector3(side * 2.25, landing_height + 7.0, -27.0), 0.6, _ashlar)
		_rib(Vector3(side * 2.25, landing_height + 7.0, -27.0), Vector3(0, landing_height + 8.3, -27.0), 0.6, _ashlar)
		_brazier(Vector3(side * 4.2, landing_height + 1.35, -25.9))
		_brazier(Vector3(side * 3.20, 1.50, 13.4))
	_omni(Vector3(0, 7.0, -24.3), Color("cf9bea"), 4.2, 13.0)
	var light := SpotLight3D.new()
	light.light_color = Color("a394d5")
	light.light_energy = 2.65
	light.spot_angle = 42.0
	light.spot_range = 31.0
	add_child(light)
	light.position = Vector3(0, 9.2, 9.0)
	light.look_at(to_global(Vector3(0, 0, -7)))
	if chamber == 1:
		_fractured_gallery()
		_torn_banner(Vector3(-11, 11.2, -15), 3.4, 6.9)
		_torn_banner(Vector3(9.5, 11.4, -10.5), 2.6, 5.1)
	else:
		for side: float in [-1.0, 1.0]:
			_torn_banner(Vector3(side * 10.1, 12.0, -20.5), 2.35, 5.9)

func _fractured_gallery() -> void:
	# The inner span has collapsed into the crypt. Both stumps end clear of the playable bridge.
	var z := -8.3
	_box(Vector3(-12.0, 6.9, z), Vector3(9.8, 0.72, 2.05), _ashlar)
	_box(Vector3(-12.1, 7.68, z), Vector3(9.6, 0.82, 0.30), _metal)
	_box(Vector3(-12.15, 8.12, z), Vector3(9.5, 0.16, 0.48), _frame)
	_rib(Vector3(-15.9, 3.9, z), Vector3(-11.8, 5.65, z), 0.62, _ashlar)
	_rib(Vector3(-11.8, 5.65, z), Vector3(-7.2, 6.52, z), 0.55, _ashlar)
	_box(Vector3(13.45, 5.85, z - 0.55), Vector3(7.1, 0.76, 2.15), _ashlar)
	_rib(Vector3(16.7, 3.55, z - 0.55), Vector3(10.0, 5.55, z - 0.55), 0.61, _ashlar)
	_box(Vector3(9.55, 5.21, z - 0.51), Vector3(1.23, 0.58, 1.32), _frame,
		Basis.from_euler(Vector3(0.35, 0.24, -0.7)))
	_box(Vector3(-6.73, 6.26, z + 0.24), Vector3(1.2, 0.58, 1.5), _frame,
		Basis.from_euler(Vector3(0.18, -0.17, 0.55)))


func _torn_banner(top: Vector3, width: float, height: float) -> void:
	var cloth := _material(Color("481f60"), 0.90)
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var previous := Vector3(-width * 0.5, 0, 0)
	var previous_hem := previous + Vector3.DOWN * height * 0.8
	for i in range(1, 11):
		var t := float(i) / 10.0
		var next := Vector3((t - 0.5) * width, 0, 0.12 * sin(t * TAU * 2.0))
		var hem := next + Vector3(0, -height * (0.74 + 0.20 * sin(t * PI) + 0.06 * cos(t * TAU * 3.0)), 0.19)
		for vertex in [previous, next, hem, previous, hem, previous_hem]:
			mesh.add_vertex(vertex)
		previous = next
		previous_hem = hem
	mesh.generate_normals()
	_mesh(mesh.commit(), cloth, top, "TornVioletBanner")
	_rib(top - Vector3.RIGHT * (width * 0.61), top + Vector3.RIGHT * (width * 0.61), 0.13, _brass)

func _brazier(point: Vector3) -> void:
	_box(point + Vector3.DOWN * 0.55, Vector3(0.48, 0.9, 0.48), _ashlar)
	var basin := CylinderMesh.new()
	basin.top_radius = 0.46
	basin.bottom_radius = 0.24
	basin.height = 0.25
	basin.radial_segments = 12
	_mesh(basin, _metal, point, "BrazierBowl")
	var ember := CylinderMesh.new()
	ember.top_radius = 0.008
	ember.bottom_radius = 0.145
	ember.height = 0.33
	ember.radial_segments = 5
	for i in 3:
		var flame := _mesh(ember, _flame, point + Vector3(0.11 * (i - 1), 0.18 + 0.04 * i, 0), "BrazierEmber")
		flame.rotation = Vector3(0.13, i * TAU / 3.0, 0.22 * (i - 1))
	_omni(point + Vector3.UP * 0.5, Color("ffc197"), 1.9, 6.2)

func _omni(point: Vector3, color: Color, energy: float, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = point
	light.light_color = color
	light.light_energy = energy
	light.omni_range = reach
	light.omni_attenuation = 1.35
	add_child(light)

func _bridge_details() -> void:
	for segment: Vector2 in [Vector2(10, 4),Vector2(7.45, 1.1),Vector2(2.5, 1.2),
			Vector2(-2.5, 1.2),Vector2(-9.6, 5.2)]:
		for side: float in [-1.0, 1.0]:
			_box(Vector3(side * 1.93, 0.014, segment.x), Vector3(0.08, 0.025, segment.y - 0.03), _rim)
	for z: float in [21.0, 19.0, 16.9, 14.8, 12.9, -26.2, -27.2]:
		var y := landing_height + 0.019 if z < -20.0 else 0.018
		for side: float in [-1.0, 1.0]:
			_rib(Vector3(0, y, z - 0.67), Vector3(side * 2.43, y, z + 0.36), 0.038, _brass)
	for side: float in [-1.0, 1.0]:
		for z: float in [-8.0, 8.0]:
			_box(Vector3(side * 7, -0.66, z), Vector3(7.12, 0.18, 7.12), _frame)
			_box(Vector3(side * 7, -1.65, z), Vector3(5.7, 1.8, 5.7), _ashlar)
			_box(Vector3(side * 7, -4.7, z), Vector3(2.3, 5.8, 2.3), _wall)

func dress_stairs(start_z: float, end_z: float, width: float) -> void:
	var count := 18
	var step_length := (start_z - end_z) / count
	for index in count:
		var top := landing_height * (index + 0.5) / count
		var z := start_z - (index + 0.5) * step_length
		var tread := BoxMesh.new()
		tread.size = Vector3(width, top + 0.44, step_length + 0.004)
		_mesh(tread, walk_stone, Vector3(0, (top - 0.44) * 0.5, z), "ChancelTread")
		var nosing := BoxMesh.new()
		nosing.size = Vector3(width + 0.06, 0.035, 0.08)
		_mesh(nosing, _frame, Vector3(0, top - 0.012, z + step_length * 0.40), "StairNosing")


func _crypt() -> void:
	for z: float in [14.0, 0.0, -14.0, -23.0]:
		var rim := [Vector3(-15, -15, z), Vector3(-8, -8.3, z), Vector3(0, -6.5, z),
			Vector3(8, -8.3, z), Vector3(15, -15, z)]
		for i in rim.size() - 1:
			_rib(rim[i], rim[i + 1], 0.83, _ashlar)
			_rib(rim[i] + Vector3.DOWN * 0.55, rim[i + 1] + Vector3.DOWN * 0.55, 0.15, _metal)
	_omni(Vector3(0, -8.8, 0), Color("8447c2"), 4.3, 20.0)

func _solid(label: String, point: Vector3, dimensions: Vector3, angles := Vector3.ZERO) -> void:
	var body := StaticBody3D.new()
	body.name = label
	body.position = point
	body.rotation = angles
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	body.set_meta("walkable_surface", label == "Balcony" or label == "Ramp")
	combat.add_child(body, true)
	var box := BoxMesh.new()
	box.size = dimensions
	_mesh(box, walk_stone if body.get_meta("walkable_surface") else _ashlar, Vector3.ZERO, label + "Mesh", body)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = dimensions
	collision.shape = shape
	body.add_child(collision)

func _balconies() -> void:
	var angle := atan(1.2 / 4.0)
	for side: float in [-1.0, 1.0]:
		_solid("Balcony", Vector3(side * 9, 1.08, 0), Vector3(3, 0.24, 6))
		for end: float in [-1.0, 1.0]:
			_solid("Ramp", Vector3(side * 9, 0.6 - cos(angle) * 0.1, end * 5),
				Vector3(3, 0.2, sqrt(17.44)), Vector3(end * angle, 0, 0))
			_box(Vector3(side * 10.36, 0.68, end * 5), Vector3(0.07, 0.038, sqrt(17.44)),
				_rim, Basis(Vector3.RIGHT, end * angle))
		_solid("Cover", Vector3(side * 7.7, 1.7, 0), Vector3(0.28, 1, 3.6))
		_box(Vector3(side * 7.7, 2.22, 0), Vector3(0.36, 0.08, 3.68), _frame)
		_box(Vector3(side * 10.36, 1.23, 0), Vector3(0.075, 0.04, 5.9), _rim)
		var z := -9.4 if chamber == 1 and side < 0.0 else 9.5
		var cover := Vector3(side * 5.28, 0.76, z)
		_solid("ReliquaryCover", cover, Vector3(1.2, 1.52, 1.48))
		_box(cover + Vector3.UP * 0.76, Vector3(1.32, 0.14, 1.63), _frame)
		_box(cover + Vector3.BACK * 0.752, Vector3(0.13, 0.75, 0.03), _brass)

func _process(delta: float) -> void:
	_ghost_time += delta
	_fly_ghosts()

func _fly_ghosts() -> void:
	for index in ghosts.size():
		var route := _ghost_routes[index % _ghost_routes.size()]
		var length := route.get_baked_length()
		var speed := 2.45 + 0.22 * (index % 3)
		var distance := fposmod(_ghost_time * speed + length * (0.11 + index * 0.147), length)
		var point := route.sample_baked(distance, true)
		var ahead := route.sample_baked(fposmod(distance + 0.52, length), true)
		var tangent := ahead - point
		var phase := _ghost_time * 1.12 + index * 1.7
		ghosts[index].position = point + Vector3.UP * (sin(phase) * 0.26)
		ghosts[index].rotation = Vector3(-0.14 * tangent.y, atan2(tangent.x, tangent.z), 0.13 * cos(phase))

func _make_ghost_route(points: Array[Vector3]) -> Curve3D:
	var route := Curve3D.new()
	route.bake_interval = 0.32
	for step in points.size() + 1:
		var index := step % points.size()
		var previous := points[posmod(index - 1, points.size())]
		var next := points[(index + 1) % points.size()]
		var tangent := (next - previous) * 0.18
		route.add_point(points[index], -tangent, tangent)
	return route

func _ghosts() -> void:
	var cloth := _material(Color(0.46, 0.31, 0.67, 0.25), 0.8, 0.44)
	cloth.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cloth.cull_mode = BaseMaterial3D.CULL_DISABLED
	var robe := SurfaceTool.new()
	robe.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in 12:
		var a := TAU * segment / 12.0
		var b := TAU * (segment + 1) / 12.0
		var top_a := Vector3(cos(a) * 0.34, 0.65, sin(a) * 0.34)
		var top_b := Vector3(cos(b) * 0.34, 0.65, sin(b) * 0.34)
		var edge_a := Vector3(cos(a) * 0.85, -0.8 - 0.32 * cos(a * 3.0), sin(a) * 0.6)
		var edge_b := Vector3(cos(b) * 0.85, -0.8 - 0.32 * cos(b * 3.0), sin(b) * 0.6)
		for vertex in [top_a, edge_a, edge_b, top_a, edge_b, top_b]:
			robe.add_vertex(vertex)
	robe.generate_normals()
	var robe_mesh := robe.commit()
	var hood := SphereMesh.new()
	hood.radius = 0.43
	hood.height = 1.14
	hood.radial_segments = 12
	hood.rings = 6
	_ghost_routes = [
		_make_ghost_route([Vector3(-11, 8.4, 13), Vector3(-12, 9.8, -5),
			Vector3(-7, 11.7, -21), Vector3(1, 13.1, -19), Vector3(0, 10.2, 3)]),
		_make_ghost_route([Vector3(10, 9.4, 10), Vector3(11, 8.3, -8),
			Vector3(7, 10.5, -23), Vector3(-2, 12.5, -15), Vector3(1, 11.0, 4)]),
		_make_ghost_route([Vector3(-7, 9.2, 14), Vector3(7, 11.4, 10),
			Vector3(10, 10.1, -6), Vector3(3, 13.3, -21), Vector3(-8, 10.4, -13)]),
	]
	for index in 6:
		var ghost := Node3D.new()
		ghost.name = "DriftingGhost"
		ghost.add_to_group("fear_ghost_scenery")
		scenery.add_child(ghost)
		ghosts.append(ghost)
		_mesh(robe_mesh, cloth, Vector3.ZERO, "Shroud", ghost).scale = Vector3(0.83, 1.40, 0.9)
		_mesh(hood, cloth, Vector3.UP * 0.83, "Hood", ghost).scale.x = 0.78
	_fly_ghosts()
