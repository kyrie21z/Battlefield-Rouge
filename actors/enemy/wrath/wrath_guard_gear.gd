extends RefCounted
## Original outfits and forged blades. Every guard of the same variant shares
## these immutable meshes. Charge and windup materials stay with the actor.

const HIDE := Color("653d32")
const SOOT := Color("352e34")
const OXBLOOD := Color("883d3a")
const SUEDE := Color("c8a98c")
const IRON := Color("493f46")
const STEEL := Color("b1a398")
const BRASS := Color("bf8652")
static var _meshes := {}
static var _leather: StandardMaterial3D
static var _forged: StandardMaterial3D


static func garment(kind: int, upper: bool) -> ArrayMesh:
	var key := "habit_%d_%d" % [kind, int(upper)]
	if _meshes.has(key):
		return _meshes[key]
	var cloth := SurfaceTool.new()
	cloth.begin(Mesh.PRIMITIVE_TRIANGLES)
	cloth.set_smooth_group(-1)
	# Each panel overlaps the next at the shoulder or belt. Its notch, folded
	# ridge and colored underside stay readable even when seen from below.
	var panels := 10 if upper else 8
	for i in panels:
		var start := TAU * (float(i) - 0.44) / panels
		var end := TAU * (float(i) + 0.48) / panels
		var angle := (start + end) * 0.5
		var front := cos(angle)
		var left := -sin(angle)
		var top_y := 1.65 if upper else 1.055
		var drop: float
		if kind == 0:
			drop = 0.20 + 0.20 * maxf(left, 0.0) if upper else 0.18 + 0.31 * maxf(-front, 0.0)
		elif kind == 1:
			drop = 0.20 + 0.09 * maxf(-front, 0.0) if upper else 0.32 + 0.22 * absf(front)
		else:
			drop = 0.12 + 0.14 * maxf(-front, 0.0) if upper else 0.13 + 0.22 * absf(sin(angle))
		var neck := Vector2(0.145, 0.14) if upper else Vector2(0.245, 0.17)
		var outer := Vector2(0.37, 0.225) if upper else Vector2(0.30, 0.23)
		var flare := 1.0 + 0.035 * sin(i * 4.5)
		var a := _point(start, neck, top_y)
		var b := _point(end, neck, top_y)
		var c := _point(end, outer, top_y - drop * 0.64)
		var d := _point(start, outer, top_y - drop * 0.67)
		var middle := _point(angle, outer * 1.07, top_y - drop * 0.60)
		var point := _point(angle + 0.11, outer * flare, top_y - drop)
		var base := HIDE if kind == 1 else (OXBLOOD if kind == 0 else SOOT)
		var dye := base.darkened(0.045 * (i % 3))
		_tri(cloth, a, b, middle, dye)
		_tri(cloth, b, c, middle, dye.darkened(0.16))
		_tri(cloth, a, middle, d, dye.lightened(0.035))
		_tri(cloth, d, middle, point, dye)
		_tri(cloth, middle, c, point, dye.darkened(0.12))
		var trim := SUEDE if upper or kind == 1 else BRASS
		_tri(cloth, d, point, d.lerp(middle, 0.18) + Vector3.DOWN * 0.003, trim)
		_tri(cloth, c, c.lerp(middle, 0.11) + Vector3.DOWN * 0.003, point, trim.darkened(0.18))
	var mesh := _finish(cloth, false)
	_meshes[key] = mesh
	return mesh


static func _point(angle: float, radii: Vector2, y: float) -> Vector3:
	return Vector3(sin(angle) * radii.x, y, -cos(angle) * radii.y)


static func newspaper(side: int) -> ArrayMesh:
	var key := "gazette_%d" % side
	if _meshes.has(key):
		return _meshes[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var stock := Color("e4d6b8")
	var ink := Color("463b3a")
	_print_block(st, side, Rect2(0, 0, 1, 1), stock, 0)
	_print_block(st, side, Rect2(0.06, 0.745, 0.88, 0.023), OXBLOOD, 0.0015)
	_print_block(st, side, Rect2(0.06, 0.10, 0.88, 0.014), ink, 0.0015)
	for column in 3:
		for line in 8:
			if side > 0 and column >= 1 and line >= 4:
				continue
			var width := 0.20 if (line + column) % 4 == 0 else 0.25
			_print_block(st, side, Rect2(0.07 + 0.30 * column, 0.16 + line * 0.066, width, 0.021), ink, 0.0015)
	if side > 0:
		_print_block(st, side, Rect2(0.09, 0.81, 0.76, 0.071), ink, 0.0015)
		# A small two-color woodcut of the local furnace and its stacks.
		_print_block(st, side, Rect2(0.40, 0.415, 0.53, 0.27), Color("a87964"), 0.0015)
		_print_block(st, side, Rect2(0.45, 0.43, 0.45, 0.068), ink, 0.003)
		_print_block(st, side, Rect2(0.49, 0.49, 0.08, 0.147), ink, 0.003)
		_print_block(st, side, Rect2(0.73, 0.49, 0.06, 0.104), ink, 0.003)
	var mesh := _finish(st, false)
	_meshes[key] = mesh
	return mesh


static func _print_block(st: SurfaceTool, side: int, area: Rect2, tint: Color, lift: float) -> void:
	# Split the print at the same crease as the sheet so ink never cuts through.
	var cuts := [area.position.x, area.end.x]
	if area.position.x < 0.48 and area.end.x > 0.48:
		cuts.insert(1, 0.48)
	for i in cuts.size() - 1:
		var a := _page_point(side, cuts[i], area.position.y, lift)
		var b := _page_point(side, cuts[i+1], area.position.y, lift)
		var c := _page_point(side, cuts[i+1], area.end.y, lift)
		var d := _page_point(side, cuts[i], area.end.y, lift)
		_tri(st, a, b, c, tint)
		_tri(st, a, c, d, tint)


static func _page_point(side: int, u: float, v: float, lift: float) -> Vector3:
	return Vector3(side * 0.37 * u, (v - 0.5) * 0.48 - u * 0.025,
		0.105 * maxf(0.0, u - 0.48) + u * 0.020 - lift)


static func blade(saw: bool) -> ArrayMesh:
	var key := "rip_saw" if saw else "lance_head"
	if _meshes.has(key):
		return _meshes[key]
	var outline := PackedVector2Array()
	if saw:
		outline.append_array(PackedVector2Array([Vector2(-0.24,-0.08), Vector2(0.14,-0.10),
			Vector2(0.43,-0.035), Vector2(0.55,0.14)]))
		# Back-cut teeth are part of the cutting silhouette on both faces.
		for i in 6:
			var x := 0.40 - i * 0.105
			outline.append(Vector2(x, 0.26 - 0.016 * i))
			outline.append(Vector2(x + 0.012, 0.108 - 0.008 * i))
		outline.append(Vector2(-0.24, 0.07))
	else:
		outline = PackedVector2Array([Vector2(-0.27,-0.042), Vector2(0.03,-0.093),
			Vector2(-0.12,-0.265), Vector2(0.33,-0.175), Vector2(1.10,0.012),
			Vector2(0.25,0.145), Vector2(0.07,0.115), Vector2(-0.12,0.19), Vector2(-0.05,0.064), Vector2(-0.27,0.042)])
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_smooth_group(-1)
	var triangles := Geometry2D.triangulate_polygon(outline)
	var center := Vector2(0.02, 0.012)
	var thick := 0.053 if saw else 0.068
	for sign_z: float in [-1.0, 1.0]:
		var face := PackedVector3Array()
		for p in outline:
			var inner := p.lerp(center, 0.19)
			face.append(Vector3(inner.x, inner.y, sign_z * thick))
		for i in range(0, triangles.size(), 3):
			_tri(st, face[triangles[i]], face[triangles[i + 1]], face[triangles[i + 2]], IRON)
		for i in outline.size():
			var j := (i + 1) % outline.size()
			var a := Vector3(outline[i].x, outline[i].y, sign_z * 0.006)
			var b := Vector3(outline[j].x, outline[j].y, sign_z * 0.006)
			var edge := STEEL if i % 3 else STEEL.darkened(0.22)
			_tri(st, a, b, face[j], edge)
			_tri(st, a, face[j], face[i], edge)
			if sign_z > 0:
				_tri(st, a, a - Vector3.BACK * 0.012, b, edge)
				_tri(st, b, a - Vector3.BACK * 0.012, b - Vector3.BACK * 0.012, edge)
		var spine := sign_z * (thick + 0.002)
		_tri(st, Vector3(-0.14,0.014,spine), Vector3(0.16,0.080,spine),
			Vector3(0.39 if saw else 0.78,0.018,spine), BRASS)
	var mesh := _finish(st, true)
	_meshes[key] = mesh
	return mesh


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var tint := color.srgb_to_linear()
	for point in [a, b, c]:
		st.set_color(tint)
		st.add_vertex(point)


static func _finish(st: SurfaceTool, metal: bool) -> ArrayMesh:
	if _leather == null:
		_leather = StandardMaterial3D.new()
		_leather.vertex_color_use_as_albedo = true
		_leather.cull_mode = BaseMaterial3D.CULL_DISABLED
		_leather.roughness = 0.90
		_forged = _leather.duplicate() as StandardMaterial3D
		_forged.metallic = 0.58
		_forged.roughness = 0.43
	st.generate_normals()
	var mesh := st.commit()
	mesh.surface_set_material(0, _forged if metal else _leather)
	return mesh
