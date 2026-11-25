class_name PsycheShardMesh
extends RefCounted
## Deterministic flat-faceted crystal geometry for PsycheShardPickup.
##
## Every face owns its vertices and carries a hard normal, so
## crystal_optics.gdshaderinc sees crisp planar facets from every angle.
## No RNG and no wall-clock: the same build runs identically in every replay.
## All meshes are cached and shared by the four realms.

const SIDES := 6
const GOLDEN := 2.399963229728653

static var _core: ArrayMesh
static var _blades: Array[ArrayMesh] = []
static var _splinter: ArrayMesh
static var _bezel: ArrayMesh


static func core_mesh() -> ArrayMesh:
	if _core == null:
		_core = _build_core()
	return _core


static func mantle_blade_mesh(variant: int) -> ArrayMesh:
	var index := posmod(variant, 3)
	while _blades.size() <= index:
		_blades.append(null)
	if _blades[index] == null:
		_blades[index] = _build_blade(index)
	return _blades[index]


static func splinter_mesh() -> ArrayMesh:
	if _splinter == null:
		_splinter = _build_splinter()
	return _splinter


static func base_ring_mesh() -> ArrayMesh:
	if _bezel == null:
		_bezel = _build_bezel()
	return _bezel


# --- shared primitives -------------------------------------------------------

static func _tool() -> SurfaceTool:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	return surface


## Adds one triangle with a hard outward normal and Godot front-facing clockwise
## winding: (v2 - v0) x (v1 - v0) agrees with the outward normal.
static func _face(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, hint: Vector3) -> void:
	var normal := (b - a).cross(c - a)
	if normal.length_squared() < 0.000000000001:
		return
	if normal.dot(hint) < 0.0:
		var swap := b
		b = c
		c = swap
		normal = -normal
	normal = normal.normalized()
	surface.set_normal(normal)
	surface.add_vertex(a)
	surface.add_vertex(c)
	surface.add_vertex(b)


static func _quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, hint: Vector3) -> void:
	_face(surface, a, b, c, hint)
	_face(surface, a, c, d, hint)


# --- core ---------------------------------------------------------------------

## Stepped six-sided crown over a long lower point, leaning off-axis so no two
## silhouettes match. The rings share one winding offset, so every side band is
## a planar prism facet: 48 hard triangles over 24 bold planes.
static func _build_core() -> ArrayMesh:
	var surface := _tool()
	var rings: Array[Dictionary] = [
		{"y": 0.212, "r": 0.030, "twist": 0.40, "off": Vector3(0.014, 0.0, -0.004)},
		{"y": 0.178, "r": 0.064, "twist": 0.40, "off": Vector3(0.010, 0.0, -0.002)},
		{"y": 0.078, "r": 0.100, "twist": 0.40, "off": Vector3(0.0, 0.0, 0.002)},
		{"y": -0.070, "r": 0.070, "twist": 0.40, "off": Vector3(-0.006, 0.0, 0.004)},
	]
	var ring_points: Array[PackedVector3Array] = []
	for ring_index in rings.size():
		var ring: Dictionary = rings[ring_index]
		var points := PackedVector3Array()
		for side in SIDES:
			var angle := float(side) * TAU / float(SIDES) + float(ring["twist"])
			var breathe := 1.0 + 0.09 * sin(float(side) * GOLDEN)
			var radius := float(ring["r"]) * breathe
			var offset: Vector3 = ring["off"]
			points.append(Vector3(cos(angle) * radius, float(ring["y"]), sin(angle) * radius * 0.86) + offset)
		ring_points.append(points)

	var apex := Vector3(0.022, 0.284, -0.010)
	var tip := Vector3(-0.016, -0.278, 0.012)

	for side in SIDES:
		var next := (side + 1) % SIDES
		var a := ring_points[0][side]
		var b := ring_points[0][next]
		_face(surface, apex, a, b, Vector3(0.0, 0.24, 0.0) + (a + b) * 0.5)

	for ring_index in rings.size() - 1:
		var upper := ring_points[ring_index]
		var lower := ring_points[ring_index + 1]
		for side in SIDES:
			var next := (side + 1) % SIDES
			var a := upper[side]
			var b := upper[next]
			var c := lower[next]
			var d := lower[side]
			var axis_center := Vector3(0.0, (a.y + c.y) * 0.5, 0.0)
			_quad(surface, a, b, c, d, (a + b + c + d) * 0.25 - axis_center)

	var bottom := ring_points[rings.size() - 1]
	for side in SIDES:
		var next := (side + 1) % SIDES
		var a := bottom[side]
		var b := bottom[next]
		_face(surface, a, b, tip, (a + b) * 0.5 + Vector3(0.0, -0.24, 0.0))

	return surface.commit()


# --- mantle blades ------------------------------------------------------------

static func _blade_outline(variant: int) -> PackedVector2Array:
	match variant:
		0:
			return PackedVector2Array([
				Vector2(-0.045, -0.240), Vector2(0.000, -0.270),
				Vector2(0.055, -0.020), Vector2(0.035, 0.240),
				Vector2(0.005, 0.270), Vector2(-0.040, 0.060),
			])
		1:
			return PackedVector2Array([
				Vector2(-0.065, -0.200), Vector2(0.010, -0.240),
				Vector2(0.075, -0.020), Vector2(0.050, 0.160),
				Vector2(0.015, 0.220), Vector2(-0.055, 0.100),
				Vector2(-0.080, -0.020),
			])
		_:
			return PackedVector2Array([
				Vector2(0.000, -0.250), Vector2(0.060, -0.050),
				Vector2(0.035, 0.160), Vector2(0.000, 0.250),
				Vector2(-0.045, 0.120), Vector2(-0.060, -0.060),
			])


## Bevel-girdled plate: a single flat table facet on each face, full-size
## girdle, and hard bevel strips around the rim. The four plates ring the core
## at 0.22 m with open air between them, so the bright opaque core reads
## through the split mantle.
static func _build_blade(variant: int) -> ArrayMesh:
	var outline := _blade_outline(variant)
	var centroid := Vector2.ZERO
	for point in outline:
		centroid += point
	centroid /= float(outline.size())

	var girdle := PackedVector3Array()
	var front := PackedVector3Array()
	var back := PackedVector3Array()
	for point in outline:
		var inset := centroid + (point - centroid) * 0.72
		girdle.append(Vector3(point.x, point.y, 0.0))
		front.append(Vector3(inset.x, inset.y, 0.030))
		back.append(Vector3(inset.x, inset.y, -0.030))

	var front_center := Vector3(centroid.x, centroid.y, 0.044)
	var back_center := Vector3(centroid.x, centroid.y, -0.044)
	var surface := _tool()
	var count := outline.size()
	for index in count:
		var next := (index + 1) % count
		var radial := Vector3(
			girdle[index].x + girdle[next].x - centroid.x * 2.0,
			girdle[index].y + girdle[next].y - centroid.y * 2.0,
			0.0
		)
		_quad(surface, girdle[index], girdle[next], front[next], front[index], radial + Vector3(0.0, 0.0, 0.02))
		_quad(surface, girdle[next], girdle[index], back[index], back[next], radial + Vector3(0.0, 0.0, -0.02))
		_face(surface, front_center, front[index], front[next], Vector3(0.0, 0.0, 0.1))
		_face(surface, back_center, back[next], back[index], Vector3(0.0, 0.0, -0.1))

	return surface.commit()


# --- splinter -----------------------------------------------------------------

## Miniature five-sided bipyramid, ~45 mm tall, for the orbiting motes.
static func _build_splinter() -> ArrayMesh:
	var surface := _tool()
	var top := Vector3(0.0, 0.0225, 0.0)
	var bottom := Vector3(0.0, -0.0225, 0.0)
	var ring := PackedVector3Array()
	for index in 5:
		var angle := float(index) * TAU / 5.0 + 0.3
		ring.append(Vector3(cos(angle) * 0.0115, 0.0, sin(angle) * 0.0115 * 0.7))
	for index in 5:
		var next := (index + 1) % 5
		_face(surface, top, ring[index], ring[next], (ring[index] + ring[next]) * 0.5 + Vector3(0.0, 0.05, 0.0))
		_face(surface, bottom, ring[next], ring[index], (ring[index] + ring[next]) * 0.5 + Vector3(0.0, -0.05, 0.0))
	return surface.commit()


# --- ground bezel -------------------------------------------------------------

## Eight-sided faceted bezel, outer radius 0.58 m, inner radius 0.50 m,
## 45 mm tall. It grounds the floating crystal against the ground halo.
static func _build_bezel() -> ArrayMesh:
	var surface := _tool()
	var sides := 8
	var profile := [
		Vector2(0.580, 0.000),
		Vector2(0.556, 0.045),
		Vector2(0.516, 0.045),
		Vector2(0.500, 0.010),
	]
	var rings: Array[PackedVector3Array] = []
	for side in sides:
		var angle := float(side) * TAU / float(sides)
		var points := PackedVector3Array()
		for point: Vector2 in profile:
			points.append(Vector3(cos(angle) * point.x, point.y, sin(angle) * point.x))
		rings.append(points)

	for side in sides:
		var next := (side + 1) % sides
		var middle := (float(side) + 0.5) * TAU / float(sides)
		var outward := Vector3(cos(middle), 0.0, sin(middle))
		_quad(surface, rings[side][0], rings[next][0], rings[next][1], rings[side][1], outward)
		_quad(surface, rings[side][1], rings[next][1], rings[next][2], rings[side][2], Vector3.UP)
		_quad(surface, rings[side][2], rings[next][2], rings[next][3], rings[side][3], -outward)
		_quad(surface, rings[side][3], rings[next][3], rings[next][0], rings[side][0], Vector3.DOWN)

	return surface.commit()
