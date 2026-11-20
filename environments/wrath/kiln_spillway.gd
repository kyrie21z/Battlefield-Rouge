extends Node3D
## Firebox and overflow channels. All surfaces are scenery outside the combat routes.

const MELT := preload("res://assets/materials/wrath_kiln_melt.gdshader")
const RING_SIDES := 20

var _melt := ShaderMaterial.new()
var _iron := StandardMaterial3D.new()
var _stone := StandardMaterial3D.new()
var _flow_time := 0.0
var _bounce_lights: Array[OmniLight3D] = []


func _ready() -> void:
	_melt.shader = MELT
	_iron.albedo_color = Color("473a3b")
	_iron.roughness = 0.81
	_stone.vertex_color_use_as_albedo = true
	_stone.roughness = 0.84
	_build_firebox()
	_build_overflow()


func set_deprivation(active: bool) -> void:
	_melt.set_shader_parameter("heat", 0.0 if active else 1.0)
	for light in _bounce_lights:
		light.visible = not active
	set_process(not active)


func _process(delta: float) -> void:
	_flow_time += delta
	_melt.set_shader_parameter("flow_time", _flow_time)


func _build_firebox() -> void:
	var hearth := Node3D.new()
	hearth.name = "SplitFirebox"
	hearth.position = Vector3(-13.35, 9.0, -26.60)
	hearth.rotation = Vector3(-0.045, 0.10, -0.095)
	add_child(hearth)
	# Stagger the joints. Two missing outer blocks leave a broken shoulder.
	var masonry := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	_course(masonry, 2.6, 3.16, 0.80, 18, 0.02, Color("9f6650"))
	_course(masonry, 3.21, 4.31, 1.06, 17, 0.17, Color("c5a38c"))
	_course(masonry, 4.40, 5.42, 0.61, 13, -0.07, Color("8c7370"), [0, 1])
	masonry.generate_normals()
	_install_mesh(hearth, masonry.commit(), _stone)
	# The recessed upper chamber broadens into a molten lip at the bottom.
	_cast_flow(hearth, PackedVector3Array([
		Vector3(0, 2.79, -0.99), Vector3(0, 2.05, -0.99), Vector3(0, 0.8, -0.99),
		Vector3(0, -0.8, -0.99), Vector3(0, -2.0, -0.81), Vector3(-0.1, -2.79, 0.3),
		Vector3(-0.16, -2.91, 1.6), Vector3(-0.25, -3.16, 2.0), Vector3(-0.32, -5.18, 2.18),
		Vector3(-0.63, -5.28, 2.62), Vector3(-0.72, -5.73, 2.75), Vector3(-0.53, -5.86, 2.88),
	]), PackedFloat32Array([0.9, 3.8, 5.25, 5.25, 3.9, 2.26, 1.91, 1.65, 1.55, 1.9, 1.65, 2.0]), Vector3.RIGHT)
	# Cast-iron receiver catches the main pour above the back wall. The liquid
	# crowns above the rim where the cascade lands and spreads out into the cup.
	var cup := CylinderMesh.new()
	cup.top_radius = 1.72
	cup.bottom_radius = 1.09
	cup.height = 1.38
	cup.radial_segments = 16
	cup.rings = 0
	_install_mesh(hearth, cup, _iron).position = Vector3(-0.52, -6.55, 2.68)
	var rim := TorusMesh.new()
	rim.inner_radius = 1.58
	rim.outer_radius = 1.85
	rim.rings = 24
	rim.ring_segments = 6
	_install_mesh(hearth, rim, _iron).position = Vector3(-0.52, -5.83, 2.68)
	_cast_flow(hearth, PackedVector3Array([Vector3(-0.52,-5.89,1.19), Vector3(-0.52,-5.84,1.80),
		Vector3(-0.52,-5.81,2.70), Vector3(-0.52,-5.86,3.64), Vector3(-0.52,-5.91,4.16)]),
		PackedFloat32Array([0.20, 2.42, 3.07, 2.33, 0.18]), Vector3.RIGHT)
	for index in range(-2, 3):
		var x := index * 0.85
		var top := sqrt(6.95 - x * x)
		_beam(hearth, Vector3(x, top, -0.04), Vector3(x - 0.20, -top + 0.52, 0.13), 0.24, 0.28)
	_beam(hearth, Vector3(-2.65, 0.48, 0.25), Vector3(2.67, 0.30, 0.23), 0.26, 0.27)
	for sign_x: float in [-1.0, 1.0]:
		_beam(hearth, Vector3(sign_x * 1.32, -2.50, 0.37), Vector3(sign_x * 1.11, -2.99, 1.86), 0.34, 0.44)
		_beam(hearth, Vector3(sign_x * 3.95, -2.4, -0.3), Vector3(sign_x * 4.65, -7.95, -0.47), 0.67, 0.87)
		_beam(hearth, Vector3(sign_x * 3.95, -3.2, -0.28), Vector3(sign_x * 2.0, -6.15, -0.52), 0.22, 0.36)
	# Low, warm bounce on the ceramic throat, alongside the scorched side of the gate.
	_bounce(hearth, Vector3(0, -1.4, 2.7), 9.0)


func _build_overflow() -> void:
	# The upper chute feeds a fall against the inside of the east retaining wall.
	var spout := Node3D.new()
	spout.name = "EastTap"
	spout.position = Vector3(18.40, 0, -10.65)
	add_child(spout)
	var channel := PackedVector3Array([
		Vector3(4.8, 7.6, -0.4), Vector3(2.0, 7.2, -0.29), Vector3(0.1, 6.72, -0.2),
		Vector3(-0.51, 6.39, -0.14), Vector3(-0.46, 3.45, -0.06), Vector3(-0.54, 3.30, 0.0),
		Vector3(-0.87, 3.24, 0.19), Vector3(-0.96, 3.03, 0.24), Vector3(-0.85, 2.18, 0.34),
	])
	_cast_flow(spout, channel, PackedFloat32Array([1.3, 1.6, 1.46, 1.30, 0.99, 1.20, 1.32, 1.07, 0.92]), Vector3.BACK)
	# A small strand separates from the torn lip, fattens and rejoins the ledge.
	_cast_flow(spout, PackedVector3Array([
		Vector3(-0.44, 6.63, 0.28), Vector3(-0.64, 6.32, 0.46), Vector3(-0.72, 5.41, 0.49),
		Vector3(-0.67, 4.70, 0.52), Vector3(-0.77, 3.49, 0.45), Vector3(-0.63, 3.36, 0.32),
	]), PackedFloat32Array([0.22, 0.29, 0.16, 0.21, 0.14, 0.31]), Vector3.BACK)
	for edge: float in [-1.0, 1.0]:
		_beam(spout, Vector3(4.9, 7.75, edge * 0.99 - 0.4), Vector3(-0.53, 6.68, edge * 0.91 - 0.17), 0.34, 0.48)
		_beam(spout, Vector3(-0.46, 6.47, edge * 0.97), Vector3(1.85, 4.15, edge * 0.97), 0.32, 0.41)
		_beam(spout, Vector3(0.58, 3.49, edge * 0.85), Vector3(-0.98, 3.30, edge * 0.82 + 0.19), 0.22, 0.31)
	# An iron-lipped gutter carries the melt through the next gap, off the slab.
	_beam(spout, Vector3(-1.37, 2.17, -0.65), Vector3(-1.14, 2.06, 3.83), 0.18, 0.40)
	_cast_flow(spout, PackedVector3Array([
		Vector3(-0.64, 2.19, -0.68), Vector3(-0.64, 2.18, 0.33), Vector3(-0.55, 2.09, 2.9),
		Vector3(-0.35, 2.04, 3.71), Vector3(0.15, 1.96, 4.04), Vector3(1.24, 1.89, 4.25),
		Vector3(2.85, 1.34, 4.47), Vector3(3.00, -0.83, 4.49),
	]), PackedFloat32Array([0.98, 1.36, 1.15, 1.22, 1.13, 0.96, 0.81, 0.58]), Vector3.ZERO)
	for z: float in [-0.46, 1.47, 3.43]:
		_beam(spout, Vector3(-1.22, 2.02, z), Vector3(0.48, 1.90, z), 0.25, 0.20)
		_beam(spout, Vector3(-1.02, 1.94, z), Vector3(0.56, 1.08, z), 0.15, 0.18)
	_bounce(spout, Vector3(-0.8, 3.1, 0.3), 6.0)


func _course(surface: SurfaceTool, inner: float, outer: float, depth: float, count: int,
		offset: float, clay: Color, missing: Array = []) -> void:
	for i in count:
		if i in missing:
			continue
		var a := TAU * float(i) / count + offset + 0.013
		var b := TAU * float(i + 1) / count + offset - 0.013
		var middle := (a + b) * 0.5
		var z := depth + 0.13 * sin(2.37 * i)
		var tint := clay.darkened(0.06 + 0.15 * (0.5 + 0.5 * sin(i * 7.3))).srgb_to_linear()
		surface.set_smooth_group(-1)
		# Each voussoir has a flat fired face, bevel and deep, dark revealed edges.
		var raw := PackedVector3Array()
		var face := PackedVector3Array()
		for bearing in [a, middle, b]:
			raw.append(Vector3(cos(bearing) * inner, sin(bearing) * inner, z - 0.16))
			face.append(Vector3(cos(bearing) * (inner + 0.09), sin(bearing) * (inner + 0.09), z))
		for bearing in [b, middle, a]:
			raw.append(Vector3(cos(bearing) * outer, sin(bearing) * outer, z - 0.16))
			face.append(Vector3(cos(bearing) * (outer - 0.11), sin(bearing) * (outer - 0.11), z))
		_quad(surface, face[0], face[1], face[4], face[5], tint)
		_quad(surface, face[1], face[2], face[3], face[4], tint)
		for j in 6:
			var k := (j + 1) % 6
			_quad(surface, raw[j], raw[k], face[k], face[j], tint.lightened(0.032))
			_quad(surface, raw[j] - Vector3.BACK * 1.35, raw[k] - Vector3.BACK * 1.35,
				raw[k], raw[j], tint.darkened(0.48))


func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	for point in [a, b, c, a, c, d]:
		surface.set_color(color)
		surface.add_vertex(point)


## Sweep a closed elliptical section down the channel. Both banks, the belly
## and the underside are real mesh surfaces with independent lighting normals.
func _cast_flow(parent: Node3D, spine: PackedVector3Array, widths: PackedFloat32Array, across: Vector3) -> void:
	var solid := SurfaceTool.new()
	solid.begin(Mesh.PRIMITIVE_TRIANGLES)
	var row := 0
	var distance := 0.0
	for i in spine.size() - 1:
		var delta := spine[i + 1] - spine[i]
		var length_m := delta.length()
		var steps := ceili(length_m / 0.24)
		var start_tangent := _tangent(spine, i)
		var end_tangent := _tangent(spine, i + 1)
		for step in range(0 if i == 0 else 1, steps + 1):
			var t := float(step) / steps
			var center := spine[i].lerp(spine[i + 1], t)
			var width := lerpf(widths[i], widths[i + 1], t)
			var tangent := start_tangent.slerp(end_tangent, t)
			var lateral := Vector3.UP.cross(tangent) if across == Vector3.ZERO else across.slide(tangent)
			lateral = lateral.normalized()
			var outward := tangent.cross(lateral).normalized()
			var travel := distance + length_m * t
			var half_width := width * (0.5 + 0.027 * sin(travel * 4.3))
			var depth := clampf(width * 0.29, 0.055, 0.48)
			for j in RING_SIDES:
				var angle := TAU * j / RING_SIDES
				var side := cos(angle)
				var rise := sin(angle)
				var lobe := 1.0 + 0.17 * cos(side * 10.0 + 0.8 * sin(travel * 1.9))
				var crown := depth * (lobe if rise > 0.0 else 0.74)
				solid.set_normal((lateral * side / half_width + outward * rise / crown).normalized())
				solid.set_uv(Vector2(0.5 + 0.5 * side, travel))
				solid.set_uv2(Vector2(width, rise))
				solid.add_vertex(center + lateral * half_width * side + outward * crown * rise)
				if row > 0:
					var a := (row - 1) * RING_SIDES + j
					var b := (row - 1) * RING_SIDES + (j + 1) % RING_SIDES
					for corner in [a, a + RING_SIDES, b + RING_SIDES, a, b + RING_SIDES, b]:
						solid.add_index(corner)
			row += 1
		distance += length_m
	for j in range(1, RING_SIDES - 1):
		var end := (row - 1) * RING_SIDES
		for corner in [0, j, j + 1, end, end + j + 1, end + j]:
			solid.add_index(corner)
	_install_mesh(parent, solid.commit(), _melt)


func _tangent(spine: PackedVector3Array, i: int) -> Vector3:
	var incoming := (spine[i] - spine[maxi(0, i - 1)]).normalized()
	var outgoing := (spine[mini(i + 1, spine.size() - 1)] - spine[i]).normalized()
	return (incoming + outgoing).normalized()


func _beam(parent: Node3D, a: Vector3, b: Vector3, width: float, depth: float) -> void:
	var bar := BoxMesh.new()
	bar.size = Vector3(width, depth, a.distance_to(b))
	var mesh := _install_mesh(parent, bar, _iron)
	mesh.position = (a + b) * 0.5
	var axis := (b - a).normalized()
	mesh.basis = Basis.looking_at(axis, Vector3.FORWARD if absf(axis.y) > 0.9 else Vector3.UP)


func _install_mesh(parent: Node3D, mesh: Mesh, finish: Material) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = finish
	parent.add_child(node)
	return node


func _bounce(parent: Node3D, at: Vector3, reach: float) -> void:
	var light := OmniLight3D.new()
	light.position = at
	light.light_color = Color("ff834d")
	light.light_energy = 1.65
	light.light_specular = 0.28
	light.omni_range = reach
	light.omni_attenuation = 1.1
	parent.add_child(light)
	_bounce_lights.append(light)
