"""Deterministic faceted obsidian geode and cut-crystal core for the talent orb.

    blender --background --python tools/talent_orb/generate.py

Authored in Godot coordinates: Y up, mouth facing -Z. Blender's glTF Y-up
export maps Blender +Y onto Godot -Z, so a game point (x, y, z) is authored as
(x, -z, y). Every piece is a closed solid, flat shaded, with recalculated
outward normals, exported at the glTF scene root and pivoted on its own centre
so TalentOrb.scatter() tumbles it there. No RNG: every radius, tilt and offset
is closed form, so the same build produces the same bytes.
"""
from pathlib import Path
import hashlib
import json
import math
import struct

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = ROOT / "objects/talent_orb"
TAU = math.tau
GOLDEN = 2.399963229728653

# Outer shell radius the plates sit on, and the aperture that frames the core.
SHELL_RADIUS = 0.532
APERTURE_INNER = 0.318
APERTURE_OUTER = 0.524
LIP_FRONT_Z = -0.200
LIP_OUTER_Z = -0.085


def game(x, y, z):
	return Vector((x, -z, y))


def polar(phi, theta, radius):
	"""Point `radius` from the origin at polar angle `theta` off the -Z mouth."""
	d = Vector((math.sin(theta) * math.cos(phi), math.sin(theta) * math.sin(phi), -math.cos(theta)))
	return d * radius


def bearing(phi, radius, z):
	return Vector((math.cos(phi) * radius, math.sin(phi) * radius, z))


def beveled_plate(girdle, normal, thickness, inset=0.74):
	"""Closed chamfered slab: widest girdle ring, inset table above and below."""
	count = len(girdle)
	center = sum(girdle, Vector()) / count
	table = [center + (p - center) * inset + normal * (thickness * 0.5) for p in girdle]
	under = [center + (p - center) * inset - normal * (thickness * 0.5) for p in girdle]
	points = list(girdle) + table + under
	faces = []
	for i in range(count):
		j = (i + 1) % count
		faces.append((i, j, count + j, count + i))
		faces.append((j, i, 2 * count + i, 2 * count + j))
	faces.append(tuple(range(count, 2 * count)))
	faces.append(tuple(range(2 * count, 3 * count)))
	return points, faces


def ring_band(r_in, r_out, z_in, z_out, thick, sides=8, phase=0.0):
	"""Closed eight-sided step ring; the -Z face is the visible concave one."""
	def ring(radius, z):
		return [bearing(phase + s * TAU / sides, radius, z) for s in range(sides)]
	front_out, front_in = ring(r_out, z_out), ring(r_in, z_in)
	back_out, back_in = ring(r_out, z_out + thick), ring(r_in, z_in + thick)
	points = front_out + front_in + back_out + back_in
	faces = []
	for i in range(sides):
		j = (i + 1) % sides
		faces.append((i, j, sides + j, sides + i))
		faces.append((2 * sides + i, 3 * sides + i, 3 * sides + j, 2 * sides + j))
		faces.append((i, 2 * sides + i, 2 * sides + j, j))
		faces.append((sides + j, 3 * sides + j, 3 * sides + i, sides + i))
	return points, faces


def ridge(stations, spread, sink):
	"""Crest fin: a sharp ridge line with two flanks falling to a flat base."""
	crest, left, right = [], [], []
	for theta, radius, phi in stations:
		crest.append(polar(phi, theta, radius))
		left.append(polar(phi - spread, theta, radius - sink))
		right.append(polar(phi + spread, theta, radius - sink))
	points = crest + left + right
	n = len(crest)
	last = n - 1
	faces = []
	for k in range(last):
		faces.append((k, n + k, n + k + 1, k + 1))
		faces.append((k, k + 1, 2 * n + k + 1, 2 * n + k))
		faces.append((n + k, 2 * n + k, 2 * n + k + 1, n + k + 1))
	faces.append((0, 2 * n, n))
	faces.append((last, n + last, 2 * n + last))
	return points, faces


def add_piece(name, points, faces, material):
	verts = [game(p.x, p.y, p.z) for p in points]
	index, unique = {}, []
	remap = []
	for vertex in verts:
		key = (round(vertex.x, 7), round(vertex.y, 7), round(vertex.z, 7))
		if key not in index:
			index[key] = len(unique)
			unique.append(vertex)
		remap.append(index[key])
	tris = []
	for face in faces:
		welded = tuple(dict.fromkeys(remap[i] for i in face))
		if len(welded) >= 3:
			tris.append(welded)
	low = Vector((min(v.x for v in unique), min(v.y for v in unique), min(v.z for v in unique)))
	high = Vector((max(v.x for v in unique), max(v.y for v in unique), max(v.z for v in unique)))
	pivot = (low + high) * 0.5
	mesh = bpy.data.meshes.new(name)
	mesh.from_pydata([tuple(v - pivot) for v in unique], [], tris)
	mesh.materials.append(material)
	bm = bmesh.new()
	bm.from_mesh(mesh)
	open_edges = [edge for edge in bm.edges if len(edge.link_faces) != 2]
	assert not open_edges, (name, len(open_edges))
	bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
	bm.to_mesh(mesh)
	bm.free()
	mesh.update()
	for poly in mesh.polygons:
		poly.use_smooth = False
	obj = bpy.data.objects.new(name, mesh)
	bpy.context.collection.objects.link(obj)
	obj.location = pivot
	obj["shading"] = "flat"
	obj["pivot"] = "piece_centre"
	obj["game_forward"] = "-Z"
	obj["game_up"] = "+Y"
	return obj


def material(name, color, metallic, roughness, emission=None):
	mat = bpy.data.materials.new(name)
	mat.use_nodes = True
	node = mat.node_tree.nodes.get("Principled BSDF")
	node.inputs["Base Color"].default_value = (*color, 1.0)
	node.inputs["Metallic"].default_value = metallic
	node.inputs["Roughness"].default_value = roughness
	if emission is not None:
		node.inputs["Emission Color"].default_value = (*emission, 1.0)
		node.inputs["Emission Strength"].default_value = 1.6
	return mat


def begin():
	bpy.ops.wm.read_factory_settings(use_empty=True)
	bpy.context.preferences.filepaths.save_version = 0
	bpy.context.scene.unit_settings.system = "METRIC"
	bpy.context.scene.unit_settings.scale_length = 1.0


def export(name):
	bpy.context.view_layer.update()
	objects = [o for o in bpy.context.collection.objects if o.type == "MESH"]
	assert all(o.parent is None for o in objects), name
	assert all(not p.use_smooth for o in objects for p in o.data.polygons), name
	bpy.ops.object.select_all(action="DESELECT")
	for obj in objects:
		obj.select_set(True)
	bpy.context.view_layer.objects.active = objects[0]
	path = OUT / (name + ".glb")
	bpy.ops.export_scene.gltf(
		filepath=str(path), export_format="GLB", use_selection=True, export_yup=True,
		export_apply=True, export_extras=True, export_cameras=False,
		export_lights=False, export_animations=False,
	)
	raw = path.read_bytes()
	length, kind = struct.unpack_from("<II", raw, 12)
	assert kind == 0x4E4F534A
	gltf = json.loads(raw[20:20 + length])
	names = [node.get("name", "") for node in gltf["nodes"]]
	assert sorted(names) == sorted(o.name for o in objects), (name, names)
	assert all("children" not in node for node in gltf["nodes"]), name
	triangles = sum(gltf["accessors"][p["indices"]]["count"] // 3
		for mesh in gltf["meshes"] for p in mesh["primitives"])
	low = [min((o.matrix_world @ v.co)[i] for o in objects for v in o.data.vertices) for i in range(3)]
	high = [max((o.matrix_world @ v.co)[i] for o in objects for v in o.data.vertices) for i in range(3)]
	game_bounds = {"min": [low[0], low[2], -high[1]], "max": [high[0], high[2], -low[1]]}
	print("TALENT_ORB", name, len(objects), "pieces", triangles, "triangles",
		"game_bounds", game_bounds, "sha256", hashlib.sha256(raw).hexdigest()[:16])
	return len(objects)


def shell():
	begin()
	obsidian = material("Obsidian_Geode", (0.008, 0.010, 0.016), 0.34, 0.032)
	inlay = material("Realm_Inlay", (0.05, 0.05, 0.07), 0.10, 0.10, (0.85, 0.55, 0.18))

	# Concave interior bowl: flat octagonal steps sinking to a back cap, then
	# eight throat panels that carry the aperture wall forward to the lip.
	add_piece("SHELL_backcap", *beveled_plate(
		[Vector((math.cos(k * TAU / 8 + 0.2) * 0.125, math.sin(k * TAU / 8 + 0.2) * 0.125, 0.262))
			for k in range(8)], Vector((0.0, 0.0, 1.0)), 0.055, 0.78), obsidian)
	steps = [(0.100, 0.190, 0.268, 0.238), (0.180, 0.258, 0.244, 0.200),
		(0.248, 0.312, 0.206, 0.140), (0.302, 0.350, 0.146, 0.058)]
	for k, (r_in, r_out, z_in, z_out) in enumerate(steps):
		add_piece("SHELL_under_%d" % k,
			*ring_band(r_in, r_out, z_in, z_out, 0.042, phase=k * 0.19), obsidian)
	for k in range(8):
		phi = k * TAU / 8 + 0.19
		quad = [bearing(phi, 0.344, 0.062), bearing(phi + TAU / 8, 0.344, 0.062),
			bearing(phi + TAU / 8, 0.366, -0.092), bearing(phi, 0.366, -0.092)]
		normal = (quad[0] + quad[2] - quad[1] - quad[3]).normalized() * -1.0
		add_piece("SHELL_band_%d" % k, *beveled_plate(quad, normal, 0.044, 0.80), obsidian)

	# Iris lip: eight beak plates around the aperture, staggered forward so the
	# opening reads as a stepped iris instead of a flat ring.
	for k in range(8):
		a = k * TAU / 8 + 0.024
		b = (k + 1) * TAU / 8 - 0.024
		z_in = LIP_FRONT_Z - (0.014 if k % 2 else 0.0)
		quad = [bearing(a, APERTURE_INNER, z_in), bearing(b, APERTURE_INNER, z_in),
			bearing(b, APERTURE_OUTER, LIP_OUTER_Z), bearing(a, APERTURE_OUTER, LIP_OUTER_Z)]
		normal = Vector((quad[0].x + quad[1].x + quad[2].x + quad[3].x, 0.0,
			quad[0].z + quad[1].z + quad[2].z + quad[3].z))
		add_piece("SHELL_lip_%d" % k, *beveled_plate(quad, normal.normalized(), 0.056, 0.76), obsidian)

	# Eight shroud crests bridging the lip rim to the plate field.
	for k in range(8):
		phi = k * TAU / 8 + TAU / 16
		stations = [(1.360, 0.508, phi), (1.500, 0.546, phi),
			(1.680, 0.548, phi), (1.860, 0.516, phi)]
		add_piece("SHROUD_%d" % k, *ridge(stations, 0.080, 0.030), obsidian)

	# Plate field: 8 columns of 3 thick beveled slabs tiling flanks and rear,
	# each one slowly stepping in radius so the silhouette stays chipped.
	bands = [(1.360, 1.836), (1.862, 2.416), (2.442, 3.040)]
	for column in range(8):
		phi_a = column * TAU / 8 + 0.019
		phi_b = (column + 1) * TAU / 8 - 0.019
		for layer, (th_a, th_b) in enumerate(bands):
			radius = SHELL_RADIUS + 0.010 * math.sin(1.7 * column + 0.9 * layer + 0.4)
			quad = [polar(phi_a, th_a, radius), polar(phi_b, th_a, radius),
				polar(phi_b, th_b, radius), polar(phi_a, th_b, radius)]
			normal = sum(quad, Vector()).normalized()
			add_piece("PLATE_%d_%d" % (column, layer),
				*beveled_plate(quad, normal, 0.050, 0.78), obsidian)

	# Glowing inlays: a prism in every lip notch, and a lamp rod down every
	# plate seam so the fracture gaps read as lit cracks.
	for k in range(8):
		phi = k * TAU / 8
		quad = [bearing(phi - 0.020, APERTURE_INNER - 0.016, LIP_FRONT_Z - 0.004),
			bearing(phi + 0.020, APERTURE_INNER - 0.016, LIP_FRONT_Z - 0.004),
			bearing(phi + 0.020, 0.404, -0.126), bearing(phi - 0.020, 0.404, -0.126)]
		normal = Vector((quad[0].x + quad[2].x, 0.0, quad[0].z + quad[2].z + 0.5))
		add_piece("INSET_%02d" % k, *beveled_plate(quad, normal.normalized(), 0.030, 0.66), inlay)
		rod = [polar(phi - 0.016, 1.250, 0.474), polar(phi + 0.016, 1.250, 0.474),
			polar(phi + 0.016, 2.820, 0.474), polar(phi - 0.016, 2.820, 0.474)]
		rod_normal = sum(rod, Vector()).normalized()
		add_piece("SHROUD_lamp_%d" % k, *beveled_plate(rod, rod_normal, 0.030, 0.72), inlay)
	return export("orb_shell")


def core():
	begin()
	crystal = material("Talent_Crystal", (0.85, 0.66, 0.30), 0.10, 0.14, (0.95, 0.78, 0.45))
	heart = material("Talent_Heart", (1.0, 0.86, 0.58), 0.06, 0.10, (1.0, 0.90, 0.62))

	# Stepped eight-sided bipyramid: a broad crown over a hard lower point, each
	# ring twisted and offset so no two silhouettes repeat.
	rings = [
		(0.205, 0.032, 0.006, 0.0, -0.006),
		(0.166, 0.079, 0.008, 0.0, -0.003),
		(0.055, 0.150, 0.0, 0.0, 0.002),
		(-0.075, 0.112, -0.008, 0.0, 0.004),
	]
	sides = 8
	ring_points = []
	for y, radius, ox, oy, oz in rings:
		row = []
		for s in range(sides):
			angle = s * TAU / sides + 0.45
			breathe = 1.0 + 0.085 * math.sin(s * GOLDEN)
			row.append(Vector((math.cos(angle) * radius * breathe + ox,
				y + oy, math.sin(angle) * radius * breathe * 0.88 + oz)))
		ring_points.append(row)
	points = [p for row in ring_points for p in row]
	apex, tip = len(points) + 0, len(points) + 1
	points.append(Vector((0.020, 0.226, -0.012)))
	points.append(Vector((-0.014, -0.224, 0.010)))
	faces = []
	for s in range(sides):
		j = (s + 1) % sides
		faces.append((apex, s, j))
	for layer in range(len(rings) - 1):
		up = layer * sides
		low = (layer + 1) * sides
		for s in range(sides):
			j = (s + 1) % sides
			faces.append((up + s, up + j, low + j, low + s))
	last = (len(rings) - 1) * sides
	for s in range(sides):
		j = (s + 1) % sides
		faces.append((tip, last + j, last + s))
	add_piece("CORE_crystal", points, faces, crystal)

	# Compact octahedral heart, the charged seed the shell closed around.
	heart_points = [Vector((0.0, 0.100, 0.0)), Vector((0.072, 0.0, 0.0)),
		Vector((0.0, 0.0, 0.066)), Vector((-0.072, 0.0, 0.0)),
		Vector((0.0, 0.0, -0.066)), Vector((0.0, -0.100, 0.0))]
	heart_faces = [(0, 1, 2), (0, 2, 3), (0, 3, 4), (0, 4, 1),
		(5, 2, 1), (5, 3, 2), (5, 4, 3), (5, 1, 4)]
	add_piece("CORE_heart", heart_points, heart_faces, heart)

	# Six detached razor bladelets catching specular glints as the core tumbles.
	for k in range(6):
		phase = k * GOLDEN
		radius = 0.228 + 0.020 * math.sin(k * 2.1)
		centre = Vector((math.cos(phase) * radius, math.sin(k * 1.7) * 0.062,
			math.sin(phase) * radius))
		quad = [Vector((-0.011, 0.0, -0.040)), Vector((0.011, 0.0, -0.034)),
			Vector((0.007, 0.0, 0.038)), Vector((-0.009, 0.0, 0.031))]
		turn = Matrix.Rotation(phase * 1.3, 4, "Z") @ Matrix.Rotation(
			math.sin(k * 1.1) * 0.9, 4, "X") @ Matrix.Rotation(
			math.cos(k * 1.9) * 0.7, 4, "Y")
		placed = [turn @ p + centre for p in quad]
		normal = (turn @ Vector((0.0, 1.0, 0.0))).normalized()
		add_piece("CORE_shard_%d" % k, *beveled_plate(placed, normal, 0.014, 0.62), crystal)
	return export("orb_core")


OUT.mkdir(parents=True, exist_ok=True)
shell_pieces = shell()
core_pieces = core()
print("TALENT_ORB_TOTAL", shell_pieces + core_pieces, "pieces in", OUT)
