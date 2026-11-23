extends Node3D
## Scenic kiln shell. The stage owns the floor and the only combat colliders.

const PORCELAIN := preload("res://assets/materials/wrath_kiln_glaze.gdshader")
const LINING := preload("res://assets/materials/wrath_kiln_lining.gdshader")
const SPILLWAY := preload("res://environments/wrath/kiln_spillway.gd")
const HIDE_TOWERS := preload("res://environments/wrath/hide_towers.gd")

var _glaze: ShaderMaterial
var _ash: ShaderMaterial
var _soot: StandardMaterial3D
var _iron: StandardMaterial3D
var _oxidised: StandardMaterial3D
var _panel: ArrayMesh
var _bricks := ShaderMaterial.new()
var spillway := SPILLWAY.new()


func _ready() -> void:
	_glaze = _porcelain("d9cbbd", 0.48)
	_ash = _porcelain("b5a397", 0.60)
	_soot = _material("302527", 0.86)
	_iron = _material("4d3534", 0.74)
	_oxidised = _material("705145", 0.72)
	_panel = _make_panel()
	_bricks.shader = LINING
	_build_mouth()
	_build_chamber()
	_build_exit()
	spillway.name = "Spillway"
	add_child(spillway)
	var towers := HIDE_TOWERS.new()
	towers.name = "HideTowers"
	add_child(towers)


func dress_banks(banks: Array[StaticBody3D]) -> void:
	for wall in banks:
		(wall.get_child(1) as MeshInstance3D).material_override = _bricks
		var inward := -signf(wall.position.x)
		# Capstone and keyed foot follow the tilt of the existing masonry.
		_tile(wall, Vector3(inward * 0.80, 2.55, 0), Vector3(7.38, 0.32, 0.23),
			Vector3(0, PI * 0.5, 0), _ash)
		for z: float in [-2.65, 2.63]:
			_tile(wall, Vector3(inward * 0.85, -1.17, z), Vector3(0.82, 2.58, 0.46),
				Vector3(-0.05, PI * 0.5, 0.05), _iron)


func _build_mouth() -> void:
	_tile(self, Vector3(-2.9, 5.65, 16.45), Vector3(18, 9.8, 1.5), Vector3(1.49, 0.04, -0.06), _soot)
	_tile(self, Vector3(-5.45, 4.9, 10.4), Vector3(6.4, 3.8, 1.35), Vector3(-0.13, -0.19, -0.16), _soot)
	_tile(self, Vector3(5.4, 5.35, 11.0), Vector3(5.4, 3.7, 1.05), Vector3(-0.05, 0.21, 0.19), _iron)
	_tile(self, Vector3(-4.72, 4.35, 10.98), Vector3(4.0, 1.95, 0.35), Vector3(-0.13, -0.19, -0.16), _ash)
	_tile(self, Vector3(4.75, 4.65, 11.55), Vector3(3.4, 1.75, 0.25), Vector3(-0.05, 0.21, 0.19), _ash)
	for index in 3:
		var p := Vector3(-3.1 + index * 3.05, 4.79, 15.7)
		_tile(self, p, Vector3(0.44, 7.4, 0.25), Vector3(PI * 0.5, 0, 0), _oxidised)
	for side in [-1.0, 1.0]:
		for index in 4:
			var brace := Vector3(side * (3.9 + index * 0.42), 3.32 + index * 0.37, 11.13 + index * 0.07)
			_tile(self, brace, Vector3(0.31, 1.37, 0.24), Vector3(-0.02, side * 0.13, side * -0.41), _iron)


func _build_chamber() -> void:
	# Tilted outer banks leave the central sky slot open above the exit.
	for side in [-1.0, 1.0]:
		for index in 5:
			var z := 7.0 - index * 7.1
			var x: float = side * (27.6 + (index % 2) * 2.4)
			var y: float = 8.5 + index * 0.51
			var yaw: float = side * (0.23 - index * 0.11)
			var roll: float = side * (-0.22 + index * 0.10)
			_tile(self, Vector3(x, y, z), Vector3(6.9, 9.8, 1.3), Vector3(-0.16, yaw, roll), _iron)
			_tile(self, Vector3(x - side * 1.05, y + 0.8, z + 1.06), Vector3(5.2, 7.1, 0.52),
				Vector3(-0.16, yaw, roll), _glaze if index % 2 == 0 else _ash)
			var rim := Vector3(x - side * 2.61, y - 0.65, z + 1.55)
			for rib in 3:
				_tile(self, rim + Vector3(side * 0.31 * rib, 0.16 * rib, 0.04 * rib), Vector3(0.21, 3.3, 0.22),
					Vector3(-0.16, yaw, roll + side * 0.10), _oxidised)
	# Visible floating porcelain volumes all clear head height and carry no physics.
	_tile(self, Vector3(-10.9, 12.25, -1.4), Vector3(12.2, 4.6, 1.2), Vector3(0.62, -0.29, -0.34), _glaze)
	_tile(self, Vector3(-14.0, 8.7, -11.8), Vector3(7.5, 3.7, 0.75), Vector3(0.44, -0.58, -0.36), _ash)
	_tile(self, Vector3(12.25, 10.35, -9.5), Vector3(9.8, 5.5, 1.1), Vector3(0.49, 0.38, 0.38), _glaze)
	_tile(self, Vector3(8.8, 15.0, -18.2), Vector3(5.8, 3.7, 0.62), Vector3(0.26, -0.36, 0.48), _ash)
	_tile(self, Vector3(10.48, 8.49, -8.15), Vector3(4.9, 1.30, 0.64), Vector3(0.62, 0.37, 0.34), _ash)
	_tile(self, Vector3(-11.1, 10.77, -0.73), Vector3(6.2, 1.10, 0.52), Vector3(0.75, -0.29, -0.30), _oxidised)
	for index in 8:
		var x := float(index) * 9.1 - 33.4
		var y := 10.0 + float((index * 3) % 5) * 2.3
		_tile(self, Vector3(x, y, -44.0 - (index % 3) * 7.0), Vector3(8.0, 22, 2.9),
			Vector3(-0.10, -0.21 + index * 0.071, -0.19 + float(index % 4) * 0.095), _soot if index % 3 else _iron)
	# Upright furnace flues break the skyline behind the towers.
	for chimney: Vector3 in [Vector3(-23, 23, -42), Vector3(-18, 18, -46), Vector3(16, 21, -49)]:
		var h := chimney.y
		var pipe := BoxMesh.new()
		pipe.size = Vector3(2.65, h, 2.35)
		var flue := MeshInstance3D.new()
		flue.position = Vector3(chimney.x, h * 0.5, chimney.z)
		flue.mesh = pipe
		flue.material_override = _soot
		add_child(flue)
		for course in 3:
			var crown := Vector3(chimney.x, h - 1.45 + course * 0.67, chimney.z)
			_tile(self, crown, Vector3(3.3 - course * 0.15, 0.39, 2.7), Vector3(0, 0.25, 0.03), _oxidised)


func _build_exit() -> void:
	var rear_z := -27.0
	_tile(self, Vector3(-7.1, 5.9, rear_z), Vector3(7.9, 14.9, 3.4), Vector3(0.04, -0.13, -0.22), _iron)
	_tile(self, Vector3(6.5, 6.2, rear_z - 0.45), Vector3(7.0, 15.5, 2.9), Vector3(-0.08, 0.28, 0.24), _soot)
	_tile(self, Vector3(-5.7, 6.17, rear_z + 1.26), Vector3(5.4, 12.9, 0.95), Vector3(0.04, -0.13, -0.22), _glaze)
	_tile(self, Vector3(5.19, 6.7, rear_z + 0.96), Vector3(4.6, 12.5, 0.79), Vector3(-0.08, 0.28, 0.24), _ash)
	_tile(self, Vector3(-1.26, 10.6, rear_z + 0.4), Vector3(11.1, 4.2, 1.7), Vector3(0.05, -0.1, -0.15), _glaze)
	_tile(self, Vector3(2.7, 13.0, rear_z - 1.5), Vector3(8.4, 3.0, 1.4), Vector3(0.20, 0.13, 0.14), _ash)
	for index in 5:
		_tile(self, Vector3(-2.18 + index * 1.08, 6.95, rear_z + 0.1), Vector3(0.28, 3.1, 0.45),
			Vector3(-0.035, 0.12, -0.1), _oxidised)
	# Recessed courses terminate behind the physical end wall.
	for side in [-1.0, 1.0]:
		for course in 4:
			var point := Vector3(side * (3.7 + course * 0.17), 1.06 + course * 0.92, -24.46 - 0.10 * course)
			_tile(self, point, Vector3(1.5 + course * 0.25, 0.91, 0.96),
				Vector3(-0.05, side * 0.16, side * 0.12), _ash if course % 2 == 0 else _iron)
	for course in 3:
		_tile(self, Vector3(-0.6 + course * 0.42, 4.80 + course * 0.65, -24.78 - 0.24 * course),
			Vector3(7.4 - course * 0.72, 0.75, 0.84), Vector3(0.03, -0.11, -0.075 + 0.06 * course),
			_glaze if course != 1 else _oxidised)


func dress_end_wall(wall: StaticBody3D) -> void:
	(wall.get_child(1) as MeshInstance3D).material_override = _iron
	for side in [-1.0, 1.0]:
		for index in 5:
			var x: float = side * (2.6 + 0.67 * index)
			_tile(wall, Vector3(x, 0.48 - index * 0.06, 0.26), Vector3(0.49, 1.15 - index * 0.1, 0.055),
				Vector3(0.0, 0.0, side * 0.17), _ash)
		_tile(wall, Vector3(side * 10.0, 0.62, 0.26), Vector3(6.25, 1.13, 0.062),
			Vector3(0, 0, side * -0.13), _oxidised)


func dress_cover(cover: StaticBody3D) -> void:
	var block := cover.get_child(1) as MeshInstance3D
	var size := (block.mesh as BoxMesh).size
	block.material_override = _soot
	for side in [-1.0, 1.0]:
		for i in 3:
			var x: float = (i - 1) * size.x / 3.0
			var face := Vector3(x, (0.11 if i == 1 else -0.01), side * size.z * 0.5)
			_tile(cover, face, Vector3(size.x * 0.346, size.y * 0.93, 0.11),
				Vector3(0, 0.035 * side * (i - 1), 0.085 * (i - 1)), _glaze if i != 1 else _ash)
			_tile(cover, face + Vector3(0.09, -size.y * 0.27, side * 0.063),
				Vector3(size.x * 0.23, 0.12, 0.06), Vector3(0, 0, -0.05), _oxidised)
		_tile(cover, Vector3(side * size.x * 0.499, -0.04, 0), Vector3(size.z * 1.02, size.y * 0.91, 0.12),
			Vector3(0, PI * 0.5, -0.035 * side), _ash)
	_tile(cover, Vector3(0, size.y * 0.5, 0), Vector3(size.x * 1.01, size.z, 0.09),
		Vector3(PI * 0.5, 0, -0.05), _glaze)
	# Iron kiln staples hold the end plates under compression.
	for side: float in [-1.0, 1.0]:
		for z: float in [-0.28, 0.25]:
			var clasp := Vector3(side * (size.x * 0.5 + 0.09), size.y * 0.20, size.z * z)
			_tile(cover, clasp, Vector3(0.42, 0.16, 0.07), Vector3(0, PI * 0.5, 0), _iron)
			_tile(cover, clasp + Vector3(0.025 * side, 0.045, 0.025),
				Vector3(0.18, 0.20, 0.09), Vector3(0, PI * 0.5, 0.08), _oxidised)


func dress_pillar(pillar: StaticBody3D, index: int) -> void:
	var core := pillar.get_child(1) as MeshInstance3D
	var size := (core.mesh as BoxMesh).size
	core.material_override = _soot
	for face in 4:
		var frame := Basis(Vector3.UP, face * PI * 0.5)
		var depth := size.z if face % 2 == 0 else size.x
		var span := size.x if face % 2 == 0 else size.z
		for course in 3:
			var twist := 0.10 * sin(index * 2.7 + face * 1.4 + course * 2.1)
			var p := frame * Vector3(twist * 0.68, size.y * (-0.28 + course * 0.28), depth * 0.5 + 0.036)
			var finish: Material = _ash if (course + face + index) % 3 == 0 else _glaze
			_tile(pillar, p, Vector3(span * 0.99, size.y * 0.35, 0.12),
				Vector3(0.0, face * PI * 0.5, twist), finish)
	_tile(pillar, Vector3(0, -size.y * 0.43, 0), Vector3(size.x * 1.06, size.z * 1.06, 0.23),
		Vector3(PI * 0.5, 0, 0.03), _iron)
	_tile(pillar, Vector3(0, size.y * 0.50, 0), Vector3(size.x * 0.96, size.z * 0.96, 0.09),
		Vector3(PI * 0.5, 0, index * 0.08), _ash)


func _tile(parent: Node3D, point: Vector3, size: Vector3, angles: Vector3, finish: Material) -> void:
	var tile := MeshInstance3D.new()
	tile.mesh = _panel
	tile.set_surface_override_material(0, finish)
	tile.set_surface_override_material(1, _iron)
	tile.position = point
	tile.scale = size
	tile.rotation = angles
	parent.add_child(tile)


func _make_panel() -> ArrayMesh:
	var rim := PackedVector2Array([
		Vector2(-0.49, -0.33), Vector2(-0.31, -0.50), Vector2(0.32, -0.46),
		Vector2(0.50, -0.22), Vector2(0.42, 0.39), Vector2(0.14, 0.50), Vector2(-0.50, 0.37),
	])
	var faces := SurfaceTool.new()
	var sides := SurfaceTool.new()
	faces.begin(Mesh.PRIMITIVE_TRIANGLES)
	sides.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in rim.size():
		var a := rim[i]
		var b := rim[(i + 1) % rim.size()]
		for side in [-1.0, 1.0]:
			var z: float = side * 0.5
			var inner_a := Vector3(a.x * 0.91, a.y * 0.91, z)
			var inner_b := Vector3(b.x * 0.91, b.y * 0.91, z)
			var outer_a := Vector3(a.x, a.y, z * 0.64)
			var outer_b := Vector3(b.x, b.y, z * 0.64)
			var vertices := [Vector3(0, 0, z), inner_b, inner_a,
				inner_a, inner_b, outer_b, inner_a, outer_b, outer_a]
			if side < 0:
				vertices.reverse()
			for vertex: Vector3 in vertices:
				faces.set_uv(Vector2(vertex.x, vertex.y) + Vector2(0.5, 0.5))
				faces.add_vertex(vertex)
		var edge := [Vector3(a.x, a.y, 0.32), Vector3(b.x, b.y, 0.32), Vector3(b.x, b.y, -0.32),
			Vector3(a.x, a.y, 0.32), Vector3(b.x, b.y, -0.32), Vector3(a.x, a.y, -0.32)]
		for vertex in edge:
			sides.add_vertex(vertex)
	faces.generate_normals()
	sides.generate_normals()
	return sides.commit(faces.commit())


func _material(color: String, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.roughness = roughness
	return material


func _porcelain(color: String, firing: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = PORCELAIN
	material.set_shader_parameter("glaze", Color(color))
	material.set_shader_parameter("firing", firing)
	return material
