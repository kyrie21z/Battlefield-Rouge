class_name SlothWorksite
extends Node3D
## The foreground repair yard. Visible obstacles use the same WORLD geometry
## the player and enemies move around. The broken span beyond the arena is scenic.
const GEAR_RADIUS := 2.33
const GEAR_INNER := 1.37
const GEAR_DEPTH := 0.72
const BRIDGE_START := -15.68
const BRIDGE_END := -19.07
const BRIDGE_RISE := 0.87
const BRIDGE_WIDTH := 2.72

var gear: StaticBody3D
var beam: StaticBody3D
var bridge_ramp: StaticBody3D
var broken_span: Node3D
var bridge_z := 0.0
var _stone: Material
var _ash: StandardMaterial3D
var _brass: StandardMaterial3D
var _iron: StandardMaterial3D
var _rivet: StandardMaterial3D
var _plates := Dictionary()


func build(chamber: int, boss: bool, limestone: Material) -> void:
	_stone = limestone
	_ash = SlothRealm.material(Color("aba18e"), 0.06, 0.77)
	_brass = SlothRealm.material(Color("96754f"), 0.47, 0.58)
	_iron = SlothRealm.material(Color("514438"), 0.33, 0.73)
	_rivet = SlothRealm.material(Color("be9c65"), 0.54, 0.47)
	if boss:
		_debris(Vector3(-12.5, 0, 9.3), 0.42)
		_debris(Vector3(12.8, 0, 6.0), -0.81)
		_lay_out_details()
		return
	_build_gear(-0.55 if chamber == 0 else 1.14)
	_build_suspended_beam(-7.70 if chamber == 0 else -5.40)
	_build_broken_bridge(-2.13 if chamber == 0 else 1.87)
	_debris(Vector3(-4.20, 0, 6.40), 0.24)
	_debris(Vector3(5.30, 0, 3.42), -0.63)
	_debris(Vector3(-7.65, 0, -10.30), 0.81)
	_lay_out_details()


func _build_gear(z: float) -> void:
	gear = _body("BrokenGear", Vector3(-4.83, 0.19, z))
	gear.rotation = Vector3(-0.13, -0.21, -0.10)
	var segment_count := 12
	var start := -0.16
	var opening := 2.93
	for index in segment_count:
		var a := start + opening * index / segment_count
		var b := start + opening * (index + 1) / segment_count
		_arc_piece(gear, a, b, GEAR_INNER, GEAR_RADIUS, GEAR_DEPTH, _iron, true)
		_arc_piece(gear, a + 0.007, b - 0.007, GEAR_INNER + 0.11, GEAR_RADIUS - 0.10,
			GEAR_DEPTH + 0.040, _brass, false)
		_arc_piece(gear, a, b, GEAR_RADIUS - 0.22, GEAR_RADIUS - 0.15,
			GEAR_DEPTH + 0.068, _rivet, false)
		var angle := (a + b) * 0.5
		var radial := Vector3(cos(angle), sin(angle), 0)
		var facing := Basis(Vector3.BACK, angle - PI * 0.5)
		if index != 3 and index != 10:
			var tip := radial * (GEAR_RADIUS + 0.12)
			_add_box_collision(gear, tip, Vector3(0.29, 0.30, 0.64), facing)
			_plate(gear, tip, Vector3(0.29, 0.30, 0.64), _brass, facing)
			_plate(gear, tip + radial * 0.14, Vector3(0.22, 0.055, 0.53), _rivet, facing)
		_rivet_at(gear, radial * (GEAR_INNER + 0.27) + Vector3.BACK * 0.425, 0.072)
	# The original hub and a bent spoke are still bolted to the floor cradle.
	var hub := Vector3(-0.47, 0.37, 0)
	_add_box_collision(gear, hub, Vector3(1.4, 0.85, 1.06))
	_plate(gear, hub, Vector3(1.4, 0.85, 1.06), _ash)
	_plate(gear, hub + Vector3.UP * 0.46, Vector3(1.44, 0.10, 1.12), _brass)
	_rivet_at(gear, hub + Vector3.BACK * 0.63, 0.34)
	_rod(gear, hub, Vector3(-0.91, 1.69, -0.01), 0.29, _iron)


func _arc_piece(parent: StaticBody3D, start: float, end: float, inner: float, outer: float,
		depth: float, mat: Material, solid: bool) -> void:
	var points := PackedVector3Array()
	for edge: float in [-depth * 0.5, depth * 0.5]:
		for detail: Vector2 in [Vector2(start, inner), Vector2(start, outer),
				Vector2(end, outer), Vector2(end, inner)]:
			points.append(Vector3(cos(detail.x) * detail.y, sin(detail.x) * detail.y, edge))
	var part := SurfaceTool.new()
	part.begin(Mesh.PRIMITIVE_TRIANGLES)
	part.set_smooth_group(-1)
	for index in [0, 1, 2, 0, 2, 3, 4, 6, 5, 4, 7, 6,
			0, 4, 5, 0, 5, 1, 1, 5, 6, 1, 6, 2,
			2, 6, 7, 2, 7, 3, 3, 7, 4, 3, 4, 0]:
		part.add_vertex(points[index])
	part.generate_normals()
	_mesh(parent, part.commit(), mat)
	if solid:
		var hull := ConvexPolygonShape3D.new()
		hull.points = points
		_add_collision(parent, hull, Vector3.ZERO)


func _build_suspended_beam(z: float) -> void:
	var rest := _body("BeamRest", Vector3(4.31, 0.57, z + 0.18))
	var size := Vector3(1.65, 1.14, 1.87)
	_add_box_collision(rest, Vector3.ZERO, size)
	_plate(rest, Vector3.ZERO, size, _stone)
	_plate(rest, Vector3(0, -0.40, 0), Vector3(1.71, 0.12, 1.93), _ash)
	_plate(rest, Vector3(0, 0.49, 0), Vector3(1.71, 0.10, 1.93), _brass)
	_plate(rest, Vector3(0, 0.07, 0.947), Vector3(1.30, 0.16, 0.06), _iron)

	beam = _body("SuspendedStoneBeam", Vector3(6.76, 2.45, z))
	beam.rotation = Vector3(0.06, 0.07, 0.36)
	var dimensions := Vector3(6.25, 0.70, 1.18)
	_add_box_collision(beam, Vector3.ZERO, dimensions)
	_plate(beam, Vector3.ZERO, dimensions, _stone)
	_plate(beam, Vector3(0, 0.04, 0.608), Vector3(5.78, 0.15, 0.052), _ash)
	for x: float in [-2.44, -1.31, 1.91, 2.68]:
		_plate(beam, Vector3(x, 0, 0), Vector3(0.19, 0.75, 1.24), _brass)
		_rivet_at(beam, Vector3(x, 0.0, 0.65), 0.083)
	var gantry := Node3D.new()
	gantry.name = "AbandonedHoist"
	add_child(gantry)
	var lifting_point := Vector3(9.24, 8.36, z - 0.14)
	var elbow := Vector3(13.02, 8.58, z + 0.33)
	var base := Vector3(16.99, 7.8, -7.0)
	_rod(gantry, base, elbow, 0.78, _ash)
	_rod(gantry, elbow, lifting_point, 0.73, _stone)
	_rod(gantry, base + Vector3.DOWN * 0.79, elbow + Vector3.DOWN * 0.39, 0.18, _brass)
	_plate(gantry, lifting_point + Vector3.UP * 0.04, Vector3(1.09, 0.66, 1.16), _iron)
	_plate(gantry, elbow, Vector3(0.98, 0.84, 0.95), _brass)
	for side: float in [-1.0, 1.0]:
		_rivet_at(gantry, lifting_point + Vector3.BACK * 0.61 + Vector3.RIGHT * side * 0.27, 0.16)
		var hook := beam.to_global(Vector3(2.48, 0.34, side * 0.49))
		_chain(gantry, lifting_point + Vector3.BACK * side * 0.43, to_local(hook))


func _build_broken_bridge(z: float) -> void:
	bridge_z = z
	var run := BRIDGE_START - BRIDGE_END
	var slope := -atan2(BRIDGE_RISE, run)
	var rotation := Basis(Vector3.BACK, slope)
	var thickness := 0.28
	var middle := Vector3((BRIDGE_START + BRIDGE_END) * 0.5,
		SlothRealm.TERRACE_HEIGHT + BRIDGE_RISE * 0.5, z)
	bridge_ramp = _body("BrokenBridgeApproach", middle - rotation.y * thickness * 0.5)
	bridge_ramp.basis = rotation
	_add_box_collision(bridge_ramp, Vector3.ZERO, Vector3(Vector2(run, BRIDGE_RISE).length(), thickness, BRIDGE_WIDTH))
	for step in 5:
		var step_size := run / 5.0
		var top := SlothRealm.TERRACE_HEIGHT + BRIDGE_RISE * (float(step) + 0.5) / 5.0
		var x := BRIDGE_START - (float(step) + 0.5) * step_size
		_plate(self, Vector3(x, top - 0.30, z), Vector3(step_size + 0.012, 0.60, BRIDGE_WIDTH), _stone)
		_plate(self, Vector3(x - step_size * 0.36, top - 0.062, z), Vector3(0.073, 0.10, BRIDGE_WIDTH + 0.026), _brass)
	broken_span = Node3D.new()
	broken_span.name = "FloatingBridgeRemnant"
	broken_span.position = Vector3(-24.3, 2.75, z - 0.24)
	broken_span.rotation = Vector3(0.12, -0.20, -0.14)
	add_child(broken_span)
	_plate(broken_span, Vector3(-0.54, -0.25, 0), Vector3(3.22, 0.86, 2.69), _stone)
	_plate(broken_span, Vector3(-1.67, 0.37, 0), Vector3(0.43, 0.91, 2.94), _ash)
	_plate(broken_span, Vector3(0.97, -0.47, 0), Vector3(0.71, 0.51, 1.06), _ash,
		Basis.from_euler(Vector3(0.10, 0.30, -0.32)))
	for side: float in [-1.0, 1.0]:
		var edge := z + side * (BRIDGE_WIDTH * 0.5 + 0.03)
		_rod(self, Vector3(-16, 1.24, edge), Vector3(-18.78, 1.83, edge), 0.17, _ash)
		_plate(self, Vector3(-18.91, 1.98, edge - side * 0.17), Vector3(0.46, 0.41, 0.52), _ash,
			Basis.from_euler(Vector3(side * 0.32, side * 0.21, -0.16)))
		_plate(broken_span, Vector3(0.14, 0.19, side * 1.29), Vector3(2.22, 0.24, 0.27), _brass)
	_plate(self, Vector3(-21.03, 1.57, z + 0.37), Vector3(1.04, 0.29, 0.83), _stone,
		Basis.from_euler(Vector3(0.22, 0.21, -0.28)))


func _debris(point: Vector3, turn: float) -> void:
	var orientation := Basis(Vector3.UP, turn)
	_plate(self, point + Vector3(0, 0.075, 0), Vector3(1.32, 0.15, 0.69), _ash,
		orientation * Basis(Vector3.RIGHT, -0.11))
	_plate(self, point + orientation * Vector3(0.70, 0.062, 0.50), Vector3(0.70, 0.12, 0.32), _stone,
		orientation * Basis(Vector3.UP, 0.24))
	for index in 3:
		var link := point + orientation * Vector3(-0.9 + index * 0.27, 0.067, -0.46)
		_link(self, link, orientation * Basis(Vector3.UP, index * 0.19), 0.12)


func _chain(parent: Node3D, a: Vector3, b: Vector3) -> void:
	_rod(parent, a, b, 0.075, _iron)
	var links := ceili(a.distance_to(b) / 0.27)
	for index in links:
		var point := a.lerp(b, (float(index) + 0.5) / links)
		_link(parent, point, Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.UP, PI * 0.5 * (index % 2)), 0.13)


func _link(parent: Node3D, point: Vector3, orientation: Basis, radius: float) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius * 0.56
	mesh.outer_radius = radius
	mesh.rings = 10
	mesh.ring_segments = 5
	var link := _mesh(parent, mesh, _iron, point)
	link.basis = orientation * Basis.from_scale(Vector3(1.40, 1.0, 0.74))


func _rivet_at(parent: Node3D, point: Vector3, radius: float) -> void:
	var head := CylinderMesh.new()
	head.height = 0.12
	head.top_radius = radius * 0.87
	head.bottom_radius = radius
	head.radial_segments = 8
	_mesh(parent, head, _rivet, point).rotation.x = PI * 0.5


func _rod(parent: Node3D, a: Vector3, b: Vector3, width: float, mat: Material) -> void:
	var direction := (a - b).normalized()
	var up := Vector3.FORWARD if absf(direction.y) > 0.98 else Vector3.UP
	_plate(parent, (a + b) * 0.5, Vector3(width, width, a.distance_to(b)), mat,
		Basis.looking_at(direction, up))


func _body(label: String, at: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.name = label
	body.position = at
	body.collision_layer = CollisionLayers.WORLD
	body.collision_mask = 0
	body.add_to_group("navigation_geometry")
	add_child(body)
	return body


func _add_box_collision(parent: StaticBody3D, point: Vector3, size: Vector3, transform_basis := Basis.IDENTITY) -> void:
	var box := BoxShape3D.new()
	box.size = size
	_add_collision(parent, box, point, transform_basis)


func _add_collision(parent: StaticBody3D, shape: Shape3D, point: Vector3, transform_basis := Basis.IDENTITY) -> void:
	var hit := CollisionShape3D.new()
	hit.shape = shape
	hit.transform = Transform3D(transform_basis, point)
	parent.add_child(hit)


func _plate(parent: Node3D, point: Vector3, size: Vector3, mat: Material, orientation := Basis.IDENTITY) -> void:
	if not _plates.has(parent):
		_plates[parent] = {}
	var materials: Dictionary = _plates[parent]
	if not materials.has(mat):
		materials[mat] = []
	materials[mat].append(Transform3D(orientation * Basis.from_scale(size), point))


func _lay_out_details() -> void:
	var box := BoxMesh.new()
	for parent in _plates:
		for material in _plates[parent]:
			var transforms: Array = _plates[parent][material]
			var batch := MultiMesh.new()
			batch.transform_format = MultiMesh.TRANSFORM_3D
			batch.mesh = box
			batch.instance_count = transforms.size()
			for index in transforms.size():
				batch.set_instance_transform(index, transforms[index])
			var mesh := MultiMeshInstance3D.new()
			mesh.multimesh = batch
			mesh.material_override = material
			parent.add_child(mesh)
	_plates.clear()


func _mesh(parent: Node3D, shape: Mesh, mat: Material, point := Vector3.ZERO) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	mesh.mesh = shape
	mesh.material_override = mat
	mesh.position = point
	parent.add_child(mesh)
	return mesh
