"""Original flat-shaded mineral weapons, generated and exported by real Blender.

blender --background --python tools/epic1_models/generate.py
Source axes: muzzle/tip -Y, Z up. A temporary export-only 180deg Z rotation
converts source -Y to Blender +Y, which Blender's glTF Y-up export maps to -Z.
Source .blend files retain the requested -Y authoring orientation.
"""
from pathlib import Path
import hashlib
import json
import math
import struct
import sys

import bpy
import bmesh
from mathutils import Matrix, Vector

HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
OUT = ROOT / "assets/models/weapons"
OUT.mkdir(parents=True, exist_ok=True)


def material(name, color, emission=None):
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    if mat.node_tree is None:
        mat.use_nodes = True
    node = mat.node_tree.nodes.get("Principled BSDF")
    node.inputs["Base Color"].default_value = (*color, 1)
    node.inputs["Roughness"].default_value = 0.25
    node.inputs["Metallic"].default_value = 0.3
    if emission:
        node.inputs["Emission Color"].default_value = (*emission, 1)
        node.inputs["Emission Strength"].default_value = 1.5
    return mat


def source_point(v):
    # Canonical game coordinates -> Blender source, before export-only rotation.
    return Vector((-v[0], v[2], v[1]))


def add_mesh(name, vertices, faces, parent, mat, extra_slots=(), face_slots=()):
    points = [source_point(v) for v in vertices]
    low = Vector([min(v[i] for v in points) for i in range(3)])
    high = Vector([max(v[i] for v in points) for i in range(3)])
    pivot = (low + high) * 0.5
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([v - pivot for v in points], [], faces)
    mesh.materials.append(mat)
    for slot in extra_slots:
        mesh.materials.append(slot)
    for poly, slot in zip(mesh.polygons, face_slots):
        poly.material_index = slot
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    for poly in mesh.polygons:
        poly.use_smooth = False
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    obj.parent = parent
    obj.location = pivot
    obj["source_polygons"] = len(mesh.polygons)
    obj["shading"] = "flat"
    return obj


def ring_solid(rings, split_sides=()):
    n = len(rings[0])
    vertices = rings[0] + rings[1]
    faces = []
    # Caps are authored triangles, never n-gons.
    for i in range(1, n - 1):
        faces.append((0, i + 1, i))
        faces.append((n, n + i, n + i + 1))
    for i in range(n):
        j = (i + 1) % n
        if i in split_sides:
            faces.extend([(i, j, n + j), (i, n + j, n + i)])
        else:
            faces.append((i, j, n + j, n + i))
    return vertices, faces


def scene(name):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.scale_length = 1.0
    root = bpy.data.objects.new(name, None)
    bpy.context.collection.objects.link(root)
    root["origin"] = "grip_center"
    root["source_forward"] = "-Y"
    root["source_up"] = "+Z"
    return root


def cap_faces(indices):
    """Tile a convex cap with authored quads and one final triangle if needed."""
    faces = []
    i = 1
    while i + 1 < len(indices):
        stop = min(i + 3, len(indices))
        faces.append(tuple([indices[0]] + indices[i:stop]))
        i += 2
    return faces


def loft(rings, cap_start=True, cap_end=True):
    n = len(rings[0])
    vertices = [v for ring in rings for v in ring]
    faces = []
    if cap_start:
        faces.extend(cap_faces(list(reversed(range(n)))))
    for k in range(len(rings) - 1):
        for i in range(n):
            j = (i + 1) % n
            face = (k * n + i, k * n + j, (k + 1) * n + j, (k + 1) * n + i)
            a, b, c, d = [Vector(vertices[v]) for v in face]
            # A quad is one plane. Author two triangles when the mineral cut
            # changes slope, so Shade Flat never hides a twisted polygon.
            if abs((b - a).cross(c - a).normalized().dot(d - a)) > 0.000001:
                faces.extend([(face[0], face[1], face[2]), (face[0], face[2], face[3])])
            else:
                faces.append(face)
    if cap_end:
        faces.extend(cap_faces(list(range((len(rings) - 1) * n, len(rings) * n))))
    return vertices, faces


def append_geometry(vertices, faces, more_vertices, more_faces):
    offset = len(vertices)
    vertices.extend(more_vertices)
    faces.extend(tuple(i + offset for i in face) for face in more_faces)


# Authoring stations are in millimetres in game axes (+Y up, -Z forward).
PISTOL_SPEC = {
    "dimensions": (38, 142, 200),
    "muzzle": (0, 72, -166),
    "muzzle_recess": 12,
    # z, half width, bottom, top. The shroud and slide share the split section.
    "crown": [
        (-166, 14.6, 59, 87), (-160, 19, 55, 91), (-142, 19, 55, 91),
        (-122, 19, 55, 91), (-103, 19, 55, 91), (-88, 19, 55, 91),
        (-62, 19, 55, 91), (-43, 19, 55, 91), (-23, 19, 55, 91),
        (-4, 19, 55, 91), (14, 19, 55, 91), (27, 19, 55, 91),
        (34, 15.3, 59, 87),
    ],
    "slide_split": -62,
    "slide_pocket_end": -30,
    "dust_cover": [
        (-160, 12.8, 43, 57), (-152, 16, 39, 57), (-133, 16, 39, 57),
        (-113, 16, 39, 57), (-93, 16, 39, 57), (-73, 16, 39, 57),
        (-53, 16, 39, 55), (-32, 16, 39, 55), (-12, 16, 39, 55),
        (7, 16, 39, 55), (16, 15, 44, 55), (26, 11.5, 48, 54.5),
    ],
    # (y, z) loops for the guard's exterior and opening.
    "guard": (
        [(42, -84), (36, -83), (28, -77), (25, -64),
         (25, -48), (29, -38), (36, -30), (42, -30)],
        [(39, -79), (37, -79), (31, -74), (29, -63),
         (29, -49), (32, -42), (37, -35), (39, -35)],
    ),
    "trigger": [(32, -57, -54, 1.4), (34, -59, -54, 2.3),
                (38, -55, -49, 2.6), (43, -53, -46, 2.4)],
    "front_sight": [(-158, 2.1, 90, 91.8), (-155, 2.3, 90, 93),
                    (-148, 2.3, 90, 93), (-145, 1.8, 90, 91.8)],
    "rear_sight": [(20, 2.4, 90, 92.2), (23, 3, 90, 94),
                   (28, 3, 89, 94), (31, 2.4, 88, 92)],
    # x and slanted depth. The central supporting planes carry both hand poses.
    "grip_slant": .30,
    "grip_contact": [(-10, -25), (10, -25), (16, -3.4), (16, -.6),
                     (10, 24), (-10, 24), (-16, 3.4), (-16, .6)],
    # y, x scale, depth scale. The top tenon ends inside the lower frame.
    "grip": [(-48, .86, .8), (-44, .96, .84), (-39, 1, .88),
             (-28, 1, 1), (28, 1, 1), (34, 1, .89),
             (40, .94, .82), (44, .80, .79), (48, .62, .768)],
    "core": [(-61.7, 71, 0, 0), (-55, 70, 9.8, 9.2),
             (-43, 71, 10.6, 10.7), (-34, 72, 0, 0)],
}


BOON_STRIP_SLOT = 2
BOON_STRIP_HEIGHT = 2.4


def split_patch(vertices, face, distance):
    """Tile the two sides of a planar face cut, reusing exact edge points."""
    negative, positive = [], []
    for a, b in zip(face, (*face[1:], face[0])):
        da, db = distance(vertices[a]), distance(vertices[b])
        if da <= 0:
            negative.append(a)
        if da >= 0:
            positive.append(a)
        if da * db < 0:
            # Traverse the same shared edge in the same order from either face.
            lo, hi = sorted((a, b))
            t = da / (da - db) if lo == a else db / (db - da)
            edge = len(vertices)
            vertices.append(tuple(Vector(vertices[lo]).lerp(Vector(vertices[hi]), t)))
            negative.append(edge)
            positive.append(edge)
    return negative, positive


class Facets:
    """Build flat shells from millimetre sections and weld shared patch edges."""

    def __init__(self):
        self.vertices = []
        self.faces = []
        self.materials = []

    def add(self, vertices, faces, material=0):
        append_geometry(self.vertices, self.faces, vertices, faces)
        self.materials.extend([material] * len(faces))

    def skin(self, rings, *, start=True, end=True, closed=False, material=0, flanks=False,
             strip_from=None, strip_wrap=False):
        vertices = [point for ring in rings for point in ring]
        n = len(rings[0])
        faces = cap_faces([0, *range(n - 1, 0, -1)]) if start else []
        strip_faces = []
        for row in range(len(rings) if closed else len(rings) - 1):
            next_row = (row + 1) % len(rings)
            for column in range(n):
                following = (column + 1) % n
                a, b, c, d = (row * n + column, row * n + following,
                              next_row * n + following, next_row * n + column)
                pa, pb, pc, pd = (Vector(vertices[i]) for i in (a, b, c, d))
                alternate = (row + column) % 2
                if flanks and column in (2, 6):
                    # Offset only the interior point of each broad side panel.
                    phase = (row + (3 if column == 6 else 0)) % 7
                    across = (.34, .55, .71, .28, .58, .44, .72)[phase]
                    along = (.63, .37, .58, .73, .29, .42, .48)[phase]
                    cut = pa.lerp(pb, across).lerp(pd.lerp(pc, across), along)
                    cut.x -= math.copysign(1.1 + .1 * ((row + column) % 4), cut.x)
                    center = len(vertices)
                    vertices.append(tuple(cut))
                    facets = [(a, b, center), (b, c, center), (c, d, center), (d, a, center)]
                    if strip_from is None or pd.z <= strip_from:
                        faces.extend(facets)
                        continue
                    low, high = min(pa.y, pb.y), min(pc.y, pd.y)
                    slope = (high - low) / (pd.z - pa.z)
                    for facet in facets:
                        band, body = split_patch(vertices, facet, lambda v:
                                                 v[1] - low - (v[2] - pa.z) * slope - BOON_STRIP_HEIGHT)
                        faces.extend(cap_faces(body))
                        if pa.z < strip_from and len(band) >= 3:
                            front, band = split_patch(vertices, band, lambda v: v[2] - strip_from)
                            faces.extend(cap_faces(front))
                        strip_faces.extend(cap_faces(band))
                elif abs((pb - pa).cross(pc - pa).normalized().dot(pd - pa)) > .000001:
                    faces.extend([(a, b, d), (b, c, d)] if alternate else [(a, b, c), (a, c, d)])
                else:
                    faces.append((a, b, c, d))
        if end:
            # Added interior points are never part of a cap.
            cap = list(range((len(rings) - 1) * n, len(rings) * n))
            if strip_wrap:
                base = vertices[cap[2]][1]
                lower, upper = split_patch(vertices, cap, lambda v: v[1] - base)
                band, upper = split_patch(vertices, upper, lambda v: v[1] - base - BOON_STRIP_HEIGHT)
                faces.extend(cap_faces(lower))
                faces.extend(cap_faces(upper))
                strip_faces.extend(cap_faces(band))
            else:
                faces.extend(cap_faces(cap))
        self.add(vertices, faces, material)
        if strip_faces:
            self.add(vertices, strip_faces, BOON_STRIP_SLOT)

    def mesh(self, name, root, slots):
        indices = {}
        remap = [indices.setdefault(point, len(indices)) for point in self.vertices]
        points = [tuple(v * .001 for v in point) for point in indices]
        faces = [tuple(remap[index] for index in face) for face in self.faces]
        obj = add_mesh(name, points, faces, root, slots[0], slots[1:], self.materials)
        assert all(face.area > 1e-12 for face in obj.data.polygons), name
        return obj


def octagon(z, width, bottom, top, bevel, x=0):
    return [(x + dx, y, z) for dx, y in [
        (-width + bevel, bottom), (width - bevel, bottom),
        (width, bottom + bevel), (width, top - bevel), (width - bevel, top),
        (-width + bevel, top), (-width, top - bevel), (-width, bottom + bevel),
    ]]


def sight(mesh, stations, center=0):
    mesh.skin([octagon(z, width, bottom, top, .7, center)
               for z, width, bottom, top in stations])


def build_barrel_chassis(root, slots, spec, shroud):
    mesh = Facets()
    mesh.skin(shroud, start=False, flanks=True, strip_from=-158)
    _, bore_y, muzzle_z = spec["muzzle"]
    rim = octagon(muzzle_z, 9, bore_y - 10, bore_y + 10, 4.5)
    throat = octagon(muzzle_z + 2.5, 7.1, bore_y - 8, bore_y + 8, 3.7)
    floor = octagon(muzzle_z + spec["muzzle_recess"], 6.5, bore_y - 7, bore_y + 7, 3.4)
    mesh.skin([shroud[0], rim, throat], start=False, end=False)
    mesh.skin([throat, floor], start=False, material=1)

    dust = [octagon(z, w, low, high, 3.1) for z, w, low, high in spec["dust_cover"]]
    mesh.skin(dust, flanks=True)

    outer, inner = spec["guard"]
    guard = [[(x, y + (iy - y) * t, z + (iz - z) * t)
              for (y, z), (iy, iz) in zip(outer, inner)]
             for x, t in [(-7.2, .24), (-5.8, 0), (5.8, 0), (7.2, .24),
                          (7.2, .76), (5.8, 1), (-5.8, 1), (-7.2, .76)]]
    mesh.skin(guard, start=False, end=False, closed=True)
    mesh.skin([[(x, y, z) for x, z, _ in octagon(0, w, front, back, 1)]
               for y, front, back, w in spec["trigger"]])
    sight(mesh, spec["front_sight"])
    obj = mesh.mesh("barrel_block", root, slots)
    obj["muzzle_recess_depth_m"] = spec["muzzle_recess"] * .001


def build_slide(root, slots, spec, rings):
    mesh = Facets()
    mesh.skin(rings, start=False, flanks=True, strip_from=spec["slide_split"], strip_wrap=True)
    # A blind pocket opens at the split. The shroud closes it at rest.
    pocket = [octagon(z, 12, 57, 85, 3.8)
              for z in (spec["slide_split"], spec["slide_pocket_end"])]
    mesh.skin([rings[0], *pocket], start=False)
    for sign in (-1, 1):
        sight(mesh, spec["rear_sight"], sign * 7.5)
    mesh.mesh("slide_block", root, slots)


def build_grip(root, slots, spec):
    mesh = Facets()
    rings = [[(x * width, y, depth * scale - spec["grip_slant"] * y)
              for x, depth in spec["grip_contact"]]
             for y, width, scale in spec["grip"]]
    mesh.skin(rings)
    return mesh.mesh("grip_block", root, slots)


def build_core_crystal(root, slots, spec):
    mesh = Facets()
    front, first, second, rear = spec["core"]
    rings = [[(width * math.cos(i * math.tau / 8 + offset),
               y + height * math.sin(i * math.tau / 8 + offset), z)
              for i in range(8)]
             for (z, y, width, height), offset in [(first, math.pi / 8), (second, 0)]]
    points = [*rings[0], *rings[1], (0, front[1], front[0]), (0, rear[1], rear[0])]
    faces = []
    for i in range(8):
        next_i = (i + 1) % 8
        faces.extend([(16, i, next_i), (i, i + 8, next_i),
                      (next_i, i + 8, next_i + 8), (17, next_i + 8, i + 8)])
    mesh.add(points, faces)
    mesh.mesh("core_crystal", root, slots)


def pistol():
    root = scene("ObsidianPistol")
    black = material("Obsidian_Mineral", (0.007, 0.009, 0.014))
    strip = black.copy()
    strip.name = "Boon_Strip"
    gold = material("Amber_Core", (0.19, 0.074, 0.012), (0.32, 0.082, 0.009))
    dark = material("Muzzle_Interior", (0.0003, 0.0004, 0.0005))
    dark_node = dark.node_tree.nodes.get("Principled BSDF")
    for socket, value in [("Roughness", 1), ("Metallic", 0), ("Specular IOR Level", 0)]:
        dark_node.inputs[socket].default_value = value
    spec = PISTOL_SPEC
    split = next(i for i, station in enumerate(spec["crown"]) if station[0] == spec["slide_split"])
    crown = [octagon(z, w, low, high, 5) for z, w, low, high in spec["crown"]]
    slots = (black, dark, strip)
    build_barrel_chassis(root, slots, spec, crown[:split + 1])
    build_slide(root, slots, spec, crown[split:])
    grip = build_grip(root, (black,), spec)
    build_core_crystal(root, (gold,), spec)
    assert grip.location.length < .00001, tuple(grip.location)
    return root, {"muzzle_game": [v / 1000 for v in spec["muzzle"]],
                  "grip_height_m": .096, "grip_slant": spec["grip_slant"],
                  "target_dimensions_m": [v / 1000 for v in spec["dimensions"]],
                  "muzzle_recess_depth_m": spec["muzzle_recess"] * .001,
                  "budget_policy": "500–950 source polygons; 800–1600 GLB triangles"}


def blade():
    root = scene("MindBlade")
    black = material("Obsidian_Blade", (0.017, 0.021, 0.028))
    gold = material("Spine_Energy", (.11, .052, .012), (.38, .15, .018))
    # Sharp Tanto shoulders and twin planar bevels meet along the side ridges.
    # Width is exactly 40mm; thickness is 15mm including the narrow gold inlay.
    def diamond(z, half_thickness, top, bottom):
        return [(0, top, z), (half_thickness, 0, z),
                (0, bottom, z), (-half_thickness, 0, z)]
    rings = [diamond(-.060, .005, .017, -.017),
             diamond(-.076, .0075, .020, -.020),
             [(0, .018, -.295), (.006, 0, -.303),
              (0, -.020, -.300), (-.006, 0, -.303)]]
    vertices, faces = loft(rings, cap_end=False)
    tip = len(vertices)
    vertices.append((0, .014, -.340))
    for i in range(4):
        faces.append((8 + i, 8 + (i + 1) % 4, tip))
    add_mesh("blade", vertices, faces, root, black)
    # No guard: an octagonal crystal grip joins the blade directly, ending in a
    # shallow chamfered cap rather than the pointed end of a second blade.
    section = [(-.0045, -.010), (.0045, -.010), (.0065, -.007), (.0065, .007),
               (.0045, .010), (-.0045, .010), (-.0065, .007), (-.0065, -.007)]
    rings = [[(x, y, z) for x, y in section] for z in [-.060, .054]]
    rings.append([(x * .78, y * .78, .060) for x, y in section])
    vertices, faces = loft(rings)
    add_mesh("grip", vertices, faces, root, black)
    # The two thin inlays sit on the raised ridge and follow its taper. Keeping
    # the seam narrower than one millimetre preserves the black silhouette.
    vertices, faces = [], []
    for sign in [-1, 1]:
        append_geometry(vertices, faces,
                        [(sign * .0075, -.0004, -.078), (sign * .0075, .0004, -.078),
                         (sign * .00603, .0004, -.299), (sign * .00603, -.0004, -.299)], [(0, 1, 2, 3)])
    add_mesh("spine_energy", vertices, faces, root, gold)
    return root, {"blade_length_m": .28, "grip_to_tip_m": .34, "overall_length_m": .40,
                  "target_dimensions_m": [.015, .040, .400],
                  "budget_policy": "quality-first; source polygons and render triangles reported separately",
                  "game_forward": "-Z", "game_thickness_axis": "X", "game_cutting_edge": "-Y"}


def export(root, name, detail):
    bpy.context.view_layer.update()
    objects = [o for o in root.children if o.type == "MESH"]
    stats = {}
    for obj in objects:
        obj.data.calc_loop_triangles()
        stats[obj.name] = {"polygons": len(obj.data.polygons), "triangles": len(obj.data.loop_triangles),
                          "triangles_authored": sum(len(p.vertices) == 3 for p in obj.data.polygons),
                          "quads_authored": sum(len(p.vertices) == 4 for p in obj.data.polygons),
                          "flat_faces": all(not p.use_smooth for p in obj.data.polygons),
                          "pivot_source": list(obj.location)}
        assert all(len(p.vertices) in (3, 4) for p in obj.data.polygons)
    poly_count = sum(s["polygons"] for s in stats.values())
    tri_count = sum(s["triangles"] for s in stats.values())
    assert poly_count > 0 and tri_count >= poly_count
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / (name + ".blend")))
    # Only this exported copy gets the axis correction; authoring originals remain -Y forward.
    turn = Matrix.Rotation(math.pi, 4, "Z")
    for obj in objects:
        obj.data.transform(turn)
        obj.location = turn @ obj.location
    bpy.context.view_layer.update()
    vertices = [obj.matrix_world @ v.co for obj in objects for v in obj.data.vertices]
    # Now Blender +Y is the gun's forward; convert bounds to standard glTF Y-up.
    game = [Vector((v.x, v.z, -v.y)) for v in vertices]
    low = [min(v[i] for v in game) for i in range(3)]
    high = [max(v[i] for v in game) for i in range(3)]
    for axis, expected in enumerate(detail["target_dimensions_m"]):
        assert abs(high[axis] - low[axis] - expected) < .00001, (name, axis, low, high, expected)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for obj in objects:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = root
    path = OUT / (name + ".glb")
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_yup=True, export_apply=True, export_extras=True,
                             export_cameras=False, export_lights=False, export_animations=False)
    raw = path.read_bytes()
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(raw[20:20 + length])
    exported_triangles = sum(gltf["accessors"][p["indices"]]["count"] // 3
                             for mesh in gltf["meshes"] for p in mesh["primitives"])
    assert exported_triangles == tri_count
    return {"file": str(path.relative_to(ROOT)).replace("\\", "/"), "source": "tools/epic1_models/" + name + ".blend",
            "blender_version": bpy.app.version_string, "source_polygons": poly_count,
            "glb_triangles": exported_triangles, "objects": stats,
            "bounds_game": {"min": low, "max": high, "size": [high[i] - low[i] for i in range(3)]},
            "source_forward": "-Y", "export_correction": "180 degrees about Blender Z, baked before Y-up export",
            "game_forward": "-Z", "game_up": "+Y", "sha256": hashlib.sha256(raw).hexdigest(), **detail}


manifest = HERE / "manifest.json"
pistol_only = "--pistol-only" in sys.argv
root, detail = pistol()
reports = [export(root, "obsidian_pistol", detail)]
if pistol_only:
    reports.append(next(model for model in json.loads(manifest.read_text(encoding="utf-8"))["models"]
                        if model["file"] == "assets/models/weapons/mind_blade.glb"))
else:
    root, detail = blade()
    reports.append(export(root, "mind_blade", detail))
manifest.write_text(json.dumps({"models": reports}, indent=2) + "\n",
                    encoding="utf-8", newline="\n")
for report in reports:
    print("EPIC1_MODEL", report["file"], report["source_polygons"], "polygons",
          report["glb_triangles"], "triangles", report["bounds_game"])
