extends Node3D
## Scenery for the two campaign basins. Only the owning realm builds colliders.

const STONE := preload("res://environments/sorrow/flooded_stone.gdshader")
const FALL := preload("res://environments/sorrow/flooded_fall.gdshader")
const LIMESTONE := Color("aec4cc")
const SLATE := Color("526a7a")
const BASALT := Color("364b5c")
const BRONZE := Color("667c80")

var _stone := ShaderMaterial.new()
var _stone_surfaces: Array[ShaderMaterial] = [_stone]
var _fall := ShaderMaterial.new()
var _cascades: Node3D


func _ready() -> void:
	_stone.shader = STONE
	_fall.shader = FALL
	var masonry := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	masonry.set_smooth_group(-1)
	_build_banks(masonry)
	_build_broken_walkway(masonry)
	_build_memorial(masonry)
	_build_horizon(masonry)
	masonry.generate_normals()
	_install_mesh(self, "Masonry", masonry.commit(), _stone)
	_cascades = Node3D.new()
	_cascades.name = "Spillways"
	add_child(_cascades)
	var reservoir := PlaneMesh.new()
	reservoir.size = Vector2(172, 172)
	var calm_water := StandardMaterial3D.new()
	calm_water.albedo_color = Color("283e4f")
	calm_water.metallic = 0.20
	calm_water.roughness = 0.32
	var lower_water := _install_mesh(_cascades, "LowerReservoir", reservoir, calm_water)
	lower_water.position = Vector3(0, -3.58, -34)
	lower_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_falls()


func dress_basin(floor_body: StaticBody3D, banks: Array[StaticBody3D], platforms: Array[StaticBody3D]) -> void:
	var basin_finish := _stone.duplicate() as ShaderMaterial
	basin_finish.set_shader_parameter("base_tint", Color("718791"))
	(floor_body.get_child(1) as MeshInstance3D).material_override = basin_finish
	var bank_finish := _stone.duplicate() as ShaderMaterial
	bank_finish.set_shader_parameter("base_tint", Color("506571"))
	for wall in banks:
		(wall.get_child(1) as MeshInstance3D).material_override = bank_finish
	var deck_finish := _stone.duplicate() as ShaderMaterial
	deck_finish.set_shader_parameter("base_tint", Color("9caeb5"))
	_stone_surfaces.append_array([basin_finish, bank_finish, deck_finish])
	var trims := SurfaceTool.new()
	trims.begin(Mesh.PRIMITIVE_TRIANGLES)
	trims.set_smooth_group(-1)
	for deck in platforms:
		(deck.get_child(1) as MeshInstance3D).material_override = deck_finish
		# Coping occupies the outer face of the existing slab. Its walking top is unobstructed.
		var edge_y := deck.position.y * 2.0 - 0.11
		for side: float in [-1.0, 1.0]:
			_box(trims, Vector3(deck.position.x + side * 2.014, edge_y, deck.position.z),
				Vector3(0.045, 0.13, 4.0), LIMESTONE)
			_box(trims, Vector3(deck.position.x, edge_y, deck.position.z + side * 2.014),
				Vector3(4.0, 0.13, 0.045), LIMESTONE)
	trims.generate_normals()
	_install_mesh(self, "BasinCoping", trims.commit(), _stone)


func dress_ruins(ruins: Array[StaticBody3D]) -> void:
	var finish := _stone.duplicate() as ShaderMaterial
	finish.set_shader_parameter("base_tint", Color("6d8894"))
	_stone_surfaces.append(finish)
	var masonry := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	masonry.set_smooth_group(-1)
	for i in ruins.size():
		var ruin := ruins[i]
		var visual := ruin.get_child(1) as MeshInstance3D
		var size := (visual.mesh as BoxMesh).size
		visual.material_override = finish
		var cap := ruin.position + Vector3.UP * (size.y * 0.5 - 0.06)
		if size.y > 2.0:
			_box(masonry, cap, Vector3(size.x + 0.14, 0.14, size.z + 0.12), LIMESTONE, ruin.basis)
		else:
			for stone in 3:
				var top := cap + ruin.basis * Vector3((stone - 1) * size.x / 3.0, 0.033 * (stone % 2), 0)
				_box(masonry, top, Vector3(size.x * 0.318, 0.16, size.z + 0.10),
					LIMESTONE if stone != 1 else SLATE, ruin.basis * Basis(Vector3.UP, (stone - 1) * 0.055))
		_box(masonry, ruin.position + Vector3.UP * (0.29 - size.y * 0.5),
			Vector3(size.x + 0.16, 0.25, size.z + 0.18), BASALT, ruin.basis)
		for side: float in [-1.0, 1.0]:
			var rib := ruin.basis * Vector3(side * size.x * 0.29, 0, size.z * 0.5 + 0.025)
			_box(masonry, ruin.position + rib, Vector3(0.16, size.y * 0.75, 0.095), BRONZE, ruin.basis)
		if size.y > 2.0:
			for shoulder: float in [-1.0, 1.0]:
				var edge := ruin.basis * Vector3(shoulder * (size.x * 0.5 + 0.03), size.y * 0.22, 0)
				_box(masonry, ruin.position + edge, Vector3(0.13, 0.20, size.z * 0.96), LIMESTONE, ruin.basis)
		var chip := ruin.basis * Vector3(size.x * (0.42 if i % 2 == 0 else -0.40), 0.07 - size.y * 0.5, size.z * 0.74)
		_box(masonry, ruin.position + chip, Vector3(0.58, 0.15, 0.43), SLATE,
			ruin.basis * Basis(Vector3.UP, i * 0.81))
	masonry.generate_normals()
	_install_mesh(self, "RuinTrim", masonry.commit(), _stone)


func set_clock(seconds: float) -> void:
	_fall.set_shader_parameter("water_clock", seconds)


func set_deprivation(active: bool) -> void:
	_cascades.visible = not active
	for finish in _stone_surfaces:
		finish.set_shader_parameter("wetness", 0.0 if active else 1.0)


func _build_banks(st: SurfaceTool) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * 20.65
		_box(st, Vector3(x, 4.02, 0), Vector3(2.25, 0.42, 47.8), LIMESTONE)
		_box(st, Vector3(x, 3.31, 0), Vector3(2.13, 0.21, 46.9), BRONZE)
		# A rhythm of clear openings above the retaining walls frames the distant rain.
		for bay in 5:
			var z := 16.4 - bay * 8.45
			_box(st, Vector3(x, 5.52, z), Vector3(1.7, 3.20, 1.42), SLATE)
			_box(st, Vector3(x, 4.46, z), Vector3(2.10, 0.68, 1.92), BASALT)
			_box(st, Vector3(x, 7.00, z), Vector3(2.14, 0.37, 1.86), LIMESTONE)
			for face: float in [-1.0, 1.0]:
				_box(st, Vector3(x - side * 0.88, 5.58, z + face * 0.33),
					Vector3(0.22, 2.20, 0.14), LIMESTONE)
			if bay < 4 and not (side > 0 and bay == 2):
				_arch(st, Vector3(x, 6.92, z - 4.225), PI * 0.5, 3.52, 2.75, 0.70, 1.10, 11)
		# The shade at the entrance opens onto the broad, bright basin.
		_box(st, Vector3(side * 20.68, 8.21, 22.15), Vector3(3.15, 7.35, 1.68), BASALT)
		_box(st, Vector3(side * 11.91, 8.77, 21.50), Vector3(16.90, 1.03, 2.15), SLATE)
		_box(st, Vector3(side * 14.8, 8.12, 20.32), Vector3(11.0, 0.33, 1.0), LIMESTONE)


func _build_memorial(st: SurfaceTool) -> void:
	var axis := Vector3(0.0, 7.3, -27.1)
	_arch(st, axis, 0.0, 4.25, 5.50, 0.76, 2.22, 13)
	_arch(st, axis + Vector3(0, 0.13, -0.58), 0.0, 5.06, 6.15, 0.84, 1.82, 13)
	_arch(st, axis + Vector3(0, 0.31, -1.58), 0.0, 6.22, 6.78, 0.62, 1.40, 15)
	for side: float in [-1.0, 1.0]:
		for tier in 4:
			var y := 0.42 + tier * 1.89
			_box(st, Vector3(side * 5.07, y, -26.77),
				Vector3(2.24 - tier * 0.15, 1.82, 2.90 - tier * 0.15), SLATE if tier % 2 else LIMESTONE)
		_box(st, Vector3(side * 7.13, 4.25, -27.79), Vector3(2.72, 8.20, 3.1), BASALT)
		_box(st, Vector3(side * 7.13, 8.43, -27.79), Vector3(3.05, 0.49, 3.42), LIMESTONE)
		for i in 3:
			_box(st, Vector3(side * (8.16 + i * 2.16), 3.78, -24.08),
				Vector3(1.81, 0.21, 0.22), LIMESTONE)
		# Pilasters and a broken lintel at eye level link the route to the high arch.
		_box(st, Vector3(side * 2.82, 1.42, -23.77), Vector3(0.69, 2.85, 0.72), BASALT)
		_box(st, Vector3(side * 2.80, 2.90, -23.73), Vector3(1.12, 0.37, 0.76), LIMESTONE)
		_box(st, Vector3(side * 1.88, 3.59, -23.75), Vector3(2.68, 0.70, 0.63), SLATE,
			Basis.from_euler(Vector3(0, 0, side * 0.15)))
	# A narrow suspended shard sits above the clear gate sightline.
	_box(st, Vector3(0.0, 8.71, -29.22), Vector3(1.15, 4.34, 1.10), BRONZE,
		Basis.from_euler(Vector3(0.12, 0.72, 0.21)))
	_box(st, Vector3(0, 4.13, -24.17), Vector3(15.20, 0.28, 0.83), LIMESTONE)


func _build_broken_walkway(st: SurfaceTool) -> void:
	# The fractured upper gallery pulls in from the west without crossing the main sightline.
	var rotation_basis := Basis.from_euler(Vector3(0.075, -0.28, -0.19))
	var base := Vector3(-15.0, 8.32, 1.9)
	for bay in 4:
		var anchor := base + rotation_basis * Vector3((bay - 1.7) * 2.71, 0, 0)
		_box(st, anchor, Vector3(2.61, 0.49, 3.8), SLATE, rotation_basis)
		for side: float in [-1.0, 1.0]:
			_box(st, anchor + rotation_basis * Vector3(0, -0.03, side * 1.91),
				Vector3(2.57, 0.82, 0.30), LIMESTONE, rotation_basis)
			if bay < 3:
				_box(st, anchor + rotation_basis * Vector3(0.87, 0.78, side * 1.65),
					Vector3(0.38, 1.02, 0.42), BASALT, rotation_basis)
				_box(st, anchor + rotation_basis * Vector3(0, 1.31, side * 1.66),
					Vector3(2.83, 0.23, 0.48), LIMESTONE, rotation_basis)
	_box(st, Vector3(-8.0, 6.06, 4.75), Vector3(2.62, 0.39, 1.36), SLATE,
		Basis.from_euler(Vector3(0.23, -0.37, -0.43)))
	_box(st, Vector3(-9.73, 5.24, 5.79), Vector3(1.78, 0.38, 1.30), BASALT,
		Basis.from_euler(Vector3(-0.34, 0.44, 0.24)))


func _build_horizon(st: SurfaceTool) -> void:
	var piers := [
		Vector3(-19.1, 22.4, -40.0), Vector3(-30.0, 28.0, -52.1), Vector3(-44.1, 33.4, -69.6),
		Vector3(21.7, 25.2, -47.0), Vector3(37.2, 19.4, -57.4), Vector3(52.8, 32.8, -75.8),
		Vector3(3.7, 28.6, -76.0), Vector3(-7.0, 34.7, -94.0),
	]
	for i in piers.size():
		var p: Vector3 = piers[i]
		var width := 3.90 + (i % 3) * 0.95
		var tower_basis := Basis.from_euler(Vector3(0, -0.17 + i * 0.047, 0.0))
		_box(st, Vector3(p.x, p.y * 0.47 - 3.0, p.z), Vector3(width, p.y, width * 0.79), SLATE, tower_basis)
		_box(st, Vector3(p.x, p.y - 3.4, p.z), Vector3(width * 1.19, 0.73, width), LIMESTONE, tower_basis)
		_box(st, Vector3(p.x, p.y - 1.46, p.z), Vector3(width * 0.50, 4.40, width * 0.57), BASALT, tower_basis)
		for inset in [-1.0, 1.0]:
			_box(st, Vector3(p.x + inset * width * 0.30, p.y * 0.54 - 1.6, p.z + width * 0.40),
				Vector3(0.29, p.y * 0.77, 0.63), LIMESTONE, tower_basis)
	for bank: float in [-1.0, 1.0]:
		var source := Color("6c8493")
		for tier in 3:
			_box(st, Vector3(bank * (29.6 + 7.1 * tier), 0.3 + 1.6 * tier, -38.5 - 10.0 * tier),
				Vector3(20.9, 7.1 + 3.9 * tier, 13.7), source.darkened(tier * 0.06),
				Basis.from_euler(Vector3(0, bank * 0.19, 0.0)))


func _falls() -> void:
	# Off the navigable footprint. Each falling sheet bends into its own basin lip.
	_cascade("WestOverflow", Vector3(-25.2, 0, -9.4), PI * 0.50, 4.5, 9.0)
	_cascade("EastOverflow", Vector3(24.7, 0, -6.8), -PI * 0.50, 5.6, 10.3)
	_cascade("MemorialOverflow", Vector3(9.66, 0, -30.0), 0.09, 3.15, 8.4)


func _cascade(label: String, origin: Vector3, yaw: float, width: float, height: float) -> void:
	var root := Node3D.new()
	root.name = label
	root.position = origin
	root.rotation.y = yaw
	_cascades.add_child(root)
	var trough := SurfaceTool.new()
	trough.begin(Mesh.PRIMITIVE_TRIANGLES)
	trough.set_smooth_group(-1)
	_box(trough, Vector3(0, height - 0.44, -0.26), Vector3(width + 1.05, 0.89, 3.05), BASALT)
	for side: float in [-1.0, 1.0]:
		_box(trough, Vector3(side * (width * 0.5 + 0.20), height + 0.05, -0.29),
			Vector3(0.57, 0.72, 2.94), LIMESTONE)
		_box(trough, Vector3(side * (width * 0.5 + 0.39), height * 0.43, -0.86),
			Vector3(0.77, height * 0.93, 1.32), SLATE)
	trough.generate_normals()
	# Masonry stays in place when the water vanishes.
	var housing := _install_mesh(self, label + "Stone", trough.commit(), _stone)
	housing.transform = root.transform
	var sheet := SurfaceTool.new()
	sheet.begin(Mesh.PRIMITIVE_TRIANGLES)
	const ACROSS := 18
	const DOWN := 30
	for row in DOWN + 1:
		var v := float(row) / DOWN
		for col in ACROSS + 1:
			var u := float(col) / ACROSS
			var wet_edge := width * (0.5 + 0.064 * v + 0.035 * sin(8.0 * v))
			var ribs := sin(u * TAU * 5.0 + v * 2.4) * 0.13 + sin(u * 31.0 - v * 5.2) * 0.07
			var travel := 1.17 * (1.0 - exp(-9.0 * v)) + v * v * 0.69
			sheet.set_uv(Vector2(u, v))
			sheet.add_vertex(Vector3((u * 2.0 - 1.0) * wet_edge, height - (height + 3.6) * v, travel + ribs))
			if row < DOWN and col < ACROSS:
				var a := row * (ACROSS + 1) + col
				var b := a + ACROSS + 1
				for k in [a, a + 1, b + 1, a, b + 1, b]:
					sheet.add_index(k)
	sheet.generate_normals()
	var water_mesh := _install_mesh(root, "FallingSheet", sheet.commit(), _fall)
	water_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func _arch(st: SurfaceTool, origin: Vector3, yaw: float, half_span: float, rise: float,
		thickness: float, depth: float, stones: int) -> void:
	var rotation_basis := Basis(Vector3.UP, yaw)
	for i in stones:
		var a := PI * i / stones + 0.012
		var b := PI * (i + 1) / stones - 0.012
		var left := Vector3(cos(a) * half_span, sin(a) * rise, 0)
		var right := Vector3(cos(b) * half_span, sin(b) * rise, 0)
		var outside_left := left + Vector3(cos(a), sin(a), 0) * thickness
		var outside_right := right + Vector3(cos(b), sin(b), 0) * thickness
		var rim: Array[Vector3] = [left, right, outside_right, outside_left]
		var depth_axis := rotation_basis.z * depth * 0.5
		var face: Array[Vector3] = []
		for corner in rim:
			face.append(origin + rotation_basis * corner)
		var tint := LIMESTONE.lerp(SLATE, 0.14 + 0.46 * (0.5 + 0.5 * sin(float(i) * 2.03)))
		_quad(st, face[0] + depth_axis, face[1] + depth_axis, face[2] + depth_axis, face[3] + depth_axis, tint)
		_quad(st, face[3] - depth_axis, face[2] - depth_axis, face[1] - depth_axis, face[0] - depth_axis, tint)
		for j in 4:
			var k := (j + 1) % 4
			_quad(st, face[j] - depth_axis, face[k] - depth_axis, face[k] + depth_axis, face[j] + depth_axis, tint.darkened(0.12))


func _box(st: SurfaceTool, center: Vector3, size: Vector3, color: Color, orientation := Basis.IDENTITY) -> void:
	var half := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var normal := Vector3.ZERO
			var across := Vector3.ZERO
			var lift := Vector3.ZERO
			normal[axis] = side * half[axis]
			across[(axis + 1) % 3] = side * half[(axis + 1) % 3]
			lift[(axis + 2) % 3] = half[(axis + 2) % 3]
			var face := center + orientation * normal
			across = orientation * across
			lift = orientation * lift
			_quad(st, face - across - lift, face - across + lift, face + across + lift, face + across - lift, color)


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, tint: Color) -> void:
	var color := tint.srgb_to_linear()
	for point in [a, b, c, a, c, d]:
		st.set_color(color)
		st.add_vertex(point)


func _install_mesh(parent: Node3D, label: String, mesh: Mesh, material: Material) -> MeshInstance3D:
	var visual := MeshInstance3D.new()
	visual.name = label
	visual.mesh = mesh
	visual.material_override = material
	parent.add_child(visual)
	return visual
