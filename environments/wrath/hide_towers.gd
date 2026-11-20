extends Node3D
## Two rows of straight kiln towers, with pelts draped over all four shoulders.

const FUR_SHADER := preload("res://assets/materials/wrath_kiln_fur.gdshader")
const SHAFT := Color("685254")
const COURSE := Color("a58b79")
const CLAY := Color("ccb7a3")
const LEATHER := Color("52352c")
const IRON := Color("886954")
const FACES := 4
const LOCKS := 14


func _ready() -> void:
	var stone := StandardMaterial3D.new()
	stone.vertex_color_use_as_albedo = true
	stone.roughness = 0.88
	var fur := ShaderMaterial.new()
	fur.shader = FUR_SHADER
	var tall := _tower_mesh(9.3, 1.82, stone, fur)
	var low := _tower_mesh(6.7, 1.39, stone, fur)
	for side: float in [-1.0, 1.0]:
		for bay in 5:
			var tower := MeshInstance3D.new()
			tower.name = ("West" if side < 0 else "East") + str(bay + 1)
			tower.mesh = tall if bay == 2 else low
			tower.position = Vector3(side * 20.05, 2.7, -20.0 + bay * 9.0)
			tower.rotation.y = 0.065 * side + PI * 0.5 * ((bay + int(side + 1.0)) % 4)
			add_child(tower)


func _tower_mesh(height: float, r: float, stone: Material, fur: Material) -> ArrayMesh:
	var masonry := SurfaceTool.new()
	var pelts := SurfaceTool.new()
	masonry.begin(Mesh.PRIMITIVE_TRIANGLES)
	pelts.begin(Mesh.PRIMITIVE_TRIANGLES)
	masonry.set_smooth_group(-1)
	pelts.set_smooth_group(-1)
	# Straight shaft, projecting cornice and four squared merlons above the mantle.
	_course(masonry, r, 0.0, r, height - 0.60, SHAFT)
	_course(masonry, r * 1.05, 1.55, r * 1.05, 1.87, COURSE)
	_course(masonry, r * 1.02, height - 1.09, r * 1.14, height - 0.77, COURSE)
	_course(masonry, r * 1.14, height - 0.77, r * 1.14, height - 0.54, CLAY)
	_course(masonry, r * 1.06, height - 0.54, r * 1.06, height - 0.23, SHAFT)
	for face in FACES:
		var outward := Vector3(sin(PI * 0.5 * face), 0, cos(PI * 0.5 * face))
		var along := Vector3(outward.z, 0, -outward.x)
		_block(masonry, outward * r * 0.77 + along * r * 0.77 + Vector3.UP * height,
			Vector3(r * 0.69, 0.73, r * 0.69), COURSE)
		# Vertical dressed stone quoins anchor the base below the heavy hide.
		_block(masonry, (outward + along) * r * 0.89 + Vector3.UP * height * 0.29,
			Vector3(0.44, height * 0.56, 0.44), COURSE)
		var shoulder := height - 1.43
		_pelt(pelts, outward, along, r, shoulder, height * 0.46, face, false)
		_pelt(pelts, outward, along, r, shoulder + 0.09, height * 0.21, face, true)
	# The raised straps pass over the pelts and turn each corner with them.
	_course(masonry, r * 1.22, height - 1.62, r * 1.22, height - 1.39, LEATHER)
	for face in FACES:
		var outward := Vector3(sin(PI * 0.5 * face), 0, cos(PI * 0.5 * face))
		var along := Vector3(outward.z, 0, -outward.x)
		var clasp := outward * (r * 1.22 + 0.04) + Vector3.UP * (height - 1.51)
		_block(masonry, clasp, Vector3(0.34, 0.33, 0.34), IRON)
		for side: float in [-1.0, 1.0]:
			var pin := clasp + along * r * 0.40 * side
			_block(masonry, pin, Vector3(0.13, 0.13, 0.13), CLAY)
			if height > 8.0:
				var socket := outward * (r + 0.47) + along * (r * 0.56 * side)
				socket.y = height - 2.72 + socket.x * 0.15 - socket.z * 0.09
				_tusk(masonry, socket, outward, along * side)
	if height > 8.0:
		_cross_belt(masonry, height - 2.72, r + 0.50)
	masonry.generate_normals()
	pelts.generate_normals()
	var mesh := masonry.commit()
	mesh.surface_set_material(0, stone)
	pelts.commit(mesh)
	mesh.surface_set_material(1, fur)
	return mesh


func _cross_belt(s: SurfaceTool, y: float, r: float) -> void:
	var rim := [Vector2(-0.79,1), Vector2(0.79,1), Vector2(1,0.79), Vector2(1,-0.79),
		Vector2(0.79,-1), Vector2(-0.79,-1), Vector2(-1,-0.79), Vector2(-1,0.79)]
	for j in rim.size():
		var a: Vector2 = rim[j] * r
		var b: Vector2 = rim[(j + 1) % rim.size()] * r
		var p := Vector3(a.x, y + a.x * 0.15 - a.y * 0.09, a.y)
		var q := Vector3(b.x, y + b.x * 0.15 - b.y * 0.09, b.y)
		var band := Vector3.UP * 0.31
		_quad(s, p, p + band, q + band, q, LEATHER)
		_quad(s, p + band, p + band * 1.13, q + band * 1.13, q + band, IRON)


func _tusk(s: SurfaceTool, socket: Vector3, out: Vector3, side: Vector3) -> void:
	var centers := [socket, socket + out * 0.18 - Vector3.UP * 0.21,
		socket + out * 0.43 + side * 0.10 - Vector3.UP * 0.35,
		socket + out * 0.63 + side * 0.19 - Vector3.UP * 0.17,
		socket + out * 0.71 + side * 0.23 + Vector3.UP * 0.20]
	var radii := [0.19, 0.22, 0.16, 0.095, 0.012]
	var previous := PackedVector3Array()
	for i in centers.size():
		var axis: Vector3 = (centers[mini(i+1,4)] - centers[maxi(i-1,0)]).normalized()
		var a := side.slide(axis).normalized()
		var b := axis.cross(a)
		var ring := PackedVector3Array()
		for j in 8:
			var angle := TAU * j / 8
			ring.append(centers[i] + (a * cos(angle) + b * sin(angle)) * radii[i])
		if i > 0:
			var ivory := Color("ab8464").lerp(Color("f1dec0"), float(i) / 4.0)
			for j in 8:
				var k := (j + 1) % 8
				_quad(s, previous[j], ring[j], ring[k], previous[k], ivory)
		previous = ring


func _course(s: SurfaceTool, bottom: float, y0: float, top: float, y1: float, color: Color) -> void:
	# A square with chamfered corners keeps a true tower silhouette in profile.
	var rim := [Vector2(-0.78,1), Vector2(0.78,1), Vector2(1,0.78), Vector2(1,-0.78),
		Vector2(0.78,-1), Vector2(-0.78,-1), Vector2(-1,-0.78), Vector2(-1,0.78)]
	for j in rim.size():
		var a: Vector2 = rim[j]
		var b: Vector2 = rim[(j+1)%rim.size()]
		var p := Vector3(a.x*bottom,y0,a.y*bottom)
		var q := Vector3(b.x*bottom,y0,b.y*bottom)
		var u := Vector3(a.x*top,y1,a.y*top)
		var v := Vector3(b.x*top,y1,b.y*top)
		_quad(s,p,u,v,q,color)
		_tri(s,Vector3(0,y1,0),v,u,color)
		_tri(s,Vector3(0,y0,0),p,q,color)


func _block(s: SurfaceTool, center: Vector3, size: Vector3, color: Color) -> void:
	var h := size * 0.5
	for axis in 3:
		for side: float in [-1.0, 1.0]:
			var n := Vector3.ZERO
			var a := Vector3.ZERO
			var b := Vector3.ZERO
			n[axis] = side * h[axis]
			a[(axis+1)%3] = h[(axis+1)%3] * side
			b[(axis+2)%3] = h[(axis+2)%3]
			var base := center + n
			_quad(s,base-a-b,base-a+b,base+a+b,base+a-b,color)


func _pelt(s: SurfaceTool, out: Vector3, along: Vector3, r: float, y: float,
		length_m: float, face: int, mane: bool) -> void:
	# Individual locks share their root but fan and split along the hem. Wrapped
	# corners meet behind a long side lock, concealing the joints between hides.
	var columns := LOCKS * 2
	var rows := 4
	var points := PackedVector3Array()
	var colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for row in rows:
		var v := float(row) / (rows - 1)
		for col in columns + 1:
			var u := float(col) / columns
			var x := 2.0 * u - 1.0
			var seed := sin(((col + face * columns) % (FACES * columns)) * 12.35)
			var mantle := 1.0 - absf(x) * 0.32
			var hem := (0.13 + seed * 0.075) if col % 2 else -0.065
			var drop := length_m * (v * mantle + pow(v, 4) * hem)
			var width := r * (1.10 + 0.07 * sin(v * PI) - 0.075 * v)
			var fold := 0.10 * cos(TAU * u * 3.0 + face * 0.8 + v * 1.45) + 0.06 * seed * v
			var curl := sin(v * PI) * 0.19 + (0.10 if col % 2 else -0.04) * pow(v, 3)
			var relief := r * 1.065 + fold + curl + (0.22 if mane else 0.0)
			var lateral := x * width + sin(u * 8.0 + v + face) * 0.10 * v
			var turn := smoothstep(0.72, 1.0, absf(x))
			var corner := r + curl * 0.6 + (0.16 if mane else 0.0)
			relief = lerpf(relief, corner, turn)
			lateral = lerpf(lateral, signf(x) * corner, turn)
			points.append(out * relief + along * lateral + Vector3.UP * (y - drop))
			var cream := smoothstep(0.42, 0.89, v + 0.21 * cos(x * 4.3 + face) + seed * 0.04)
			var base := Color("795248").lerp(Color("c2a182"), cream) if mane else Color("785244").lerp(Color("e0d1bb"), cream)
			if mane:
				base = base.lerp(Color("493835"), 0.40 * (1.0 - absf(x)))
			colors.append(base.darkened(0.09 * (1.0 + seed)).srgb_to_linear())
			uvs.append(Vector2(u, v))
	for row in rows - 1:
		for col in columns:
			var a := row * (columns + 1) + col
			var b := a + columns + 1
			for k in [a, a+1, b+1, a, b+1, b]:
				s.set_uv(uvs[k])
				s.set_color(colors[k])
				s.add_vertex(points[k])
	# Dark return at the ragged edge exposes the leather thickness from below.
	for col in columns:
		var i := (rows-1) * (columns+1) + col
		var a := points[i]
		var b := points[i+1]
		_quad(s,a,b,b-out*0.11+Vector3.UP*0.13,a-out*0.11+Vector3.UP*0.13,LEATHER)


func _tri(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var tint := color.srgb_to_linear()
	for point in [a,b,c]:
		s.set_uv(Vector2.ZERO)
		s.set_color(tint)
		s.add_vertex(point)


func _quad(s: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	_tri(s,a,b,c,color)
	_tri(s,a,c,d,color)
