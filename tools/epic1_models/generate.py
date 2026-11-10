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


def add_mesh(name, vertices, faces, parent, mat):
    points = [source_point(v) for v in vertices]
    low = Vector([min(v[i] for v in points) for i in range(3)])
    high = Vector([max(v[i] for v in points) for i in range(3)])
    pivot = (low + high) * 0.5
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([v - pivot for v in points], [], faces)
    mesh.materials.append(mat)
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


def mineral_cuts(vertices, faces):
    """Raise selected long side facets by 1mm; retain silhouette extrema."""
    result = []
    for face in faces:
        points = [Vector(vertices[i]) for i in face]
        normal = (points[1] - points[0]).cross(points[2] - points[0]).normalized()
        span = max(max(p[axis] for p in points) - min(p[axis] for p in points) for axis in [1, 2])
        centre = sum(points, Vector()) / len(points)
        if len(face) == 4 and abs(normal.x) > .45 and span > .06 and abs(centre.x) > .008:
            centre = points[0] * .18 + points[1] * .25 + points[2] * .32 + points[3] * .25
            centre.x += .0011 if centre.x > 0 else -.0011
            index = len(vertices)
            vertices.append(tuple(centre))
            for i in range(4):
                result.append((face[i], face[(i + 1) % 4], index))
        else:
            result.append(face)
    return vertices, result


def inlay(obj, vertices, faces, mat):
    """Gold stays on its owning rock during bloom; still exactly four objects."""
    mesh = obj.data
    points = [tuple(v.co) for v in mesh.vertices]
    polygons = [tuple(p.vertices) for p in mesh.polygons]
    materials = list(mesh.materials)
    indices = [p.material_index for p in mesh.polygons]
    append_geometry(points, polygons, [tuple(source_point(v) - obj.location) for v in vertices], faces)
    replacement = bpy.data.meshes.new(obj.name + "_inlay")
    replacement.from_pydata(points, [], polygons)
    for material in materials:
        replacement.materials.append(material)
    material_index = len(materials)
    replacement.materials.append(mat)
    for i, polygon in enumerate(replacement.polygons):
        polygon.material_index = indices[i] if i < len(indices) else material_index
        polygon.use_smooth = False
    bm = bmesh.new()
    bm.from_mesh(replacement)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    bm.to_mesh(replacement)
    bm.free()
    obj.data = replacement
    bpy.data.meshes.remove(mesh)
    low = Vector([min(v.co[i] for v in replacement.vertices) for i in range(3)])
    high = Vector([max(v.co[i] for v in replacement.vertices) for i in range(3)])
    offset = (low + high) * .5
    for vertex in replacement.vertices:
        vertex.co -= offset
    obj.location += offset
    obj["source_polygons"] = len(replacement.polygons)


def pistol():
    root = scene("ObsidianPistol")
    black = material("Obsidian_Mineral", (0.017, 0.021, 0.028))
    dark = material("Muzzle_Interior", (0.002, 0.003, 0.004))
    gold = material("Amber_Core", (0.11, 0.052, 0.012), (0.32, 0.115, 0.012))
    # Six-sided mineral barrel with an intentional lowered rear step. The
    # transition is authored geometry, never three overlapping cuboids.
    def hex_section(z, half_width, bottom, top):
        mid = bottom + (top - bottom) * .48
        return [(-half_width * .65, bottom, z), (half_width * .65, bottom, z),
                (half_width, mid, z), (half_width * .64, top, z),
                (-half_width * .64, top, z), (-half_width, mid, z)]
    rings = [hex_section(-.17, .014, .050, .083),
             hex_section(-.098, .016, .051, .083),
             hex_section(-.091, .014, .052, .077),
             hex_section(-.045, .014, .052, .077)]
    vertices, faces = loft(rings, cap_start=False)
    vertices, faces = mineral_cuts(vertices, faces)
    outer = rings[0]
    mouth = [(x * .61, .066 + (y - .066) * .61, z) for x, y, z in outer]
    bottom = [(x * .50, .066 + (y - .066) * .50, z + .010) for x, y, z in outer]
    rim_vertices, rim_faces = loft([outer, mouth, bottom], cap_start=False)
    dark_first = len(faces) + 6
    append_geometry(vertices, faces, rim_vertices, rim_faces)
    barrel = add_mesh("barrel_block", vertices, faces, root, black)
    barrel.data.materials.append(dark)
    for face in barrel.data.polygons:
        if face.index >= dark_first:
            face.material_index = 1
    barrel["muzzle_recess_depth_m"] = .010
    # Elevated rear slide: distinct upper step, swept rear bevel, hex waist.
    vertices, faces = loft([hex_section(-.0435, .0155, .051, .085),
                            hex_section(.025, .0155, .051, .085),
                            hex_section(.039, .012, .055, .072)])
    vertices, faces = mineral_cuts(vertices, faces)
    slide = add_mesh("slide_block", vertices, faces, root, black)
    # A slanted grip with a chamfered heel. The changing taper produces large
    # planar mineral facets instead of a rectangular handle with painted lines.
    section = [(-.010, -.025), (.010, -.025), (.016, -.002),
               (.010, .024), (-.010, .024), (-.016, .002)]
    rings = []
    for y, z, scale in [(.050, -.014, .92), (.035, -.011, 1.0),
                         (-.041, .0284, .90), (-.050, .0296, .85)]:
        rings.append([(x * scale, y, depth * scale + z) for x, depth in section])
    vertices, faces = loft(rings)
    vertices, faces = mineral_cuts(vertices, faces)
    grip = add_mesh("grip_block", vertices, faces, root, black)
    # Fine dark-gold seams stay inlaid in their owning mineral block. The fourth
    # independently blooming object is the small physical core crystal.
    for sign in [-1, 1]:
        inlay(barrel,
              [(sign * .0095, .0508, -.163), (sign * .0095, .0515, -.163),
               (sign * .0102, .0527, -.046), (sign * .0102, .052, -.046)], [(0, 1, 2, 3)], gold)
        inlay(slide,
              [(sign * .0102, .052, -.0442), (sign * .0102, .0527, -.0442),
               (sign * .0101, .0517, .025), (sign * .0101, .051, .025)], [(0, 1, 2, 3)], gold)
        inlay(barrel,
              [(sign * .0146, .053, -.0449), (sign * .0146, .072, -.0449),
               (sign * .0146, .072, -.0442), (sign * .0146, .053, -.0442)], [(0, 1, 2, 3)], gold)
        inlay(grip,
              [(sign * .0101, .031, .014), (sign * .0108, .031, .014),
               (sign * .0097, -.041, .050), (sign * .0090, -.041, .050)], [(0, 1, 2, 3)], gold)
    core = add_mesh("core_crystal",
                    [(-.006, .052, -.045), (.006, .052, -.045), (0, .064, -.043), (0, .051, -.061)],
                    [(0, 1, 2), (0, 3, 1), (1, 3, 2), (2, 3, 0)], root, gold)
    core["seam_width_m"] = .0007
    origin = grip.location.copy()
    for obj in root.children:
        obj.location -= origin
    muzzle_source = source_point((0, .066, -.17)) - origin
    muzzle_game = [-muzzle_source.x, muzzle_source.z, muzzle_source.y]
    return root, {"muzzle_game": muzzle_game, "grip_height_m": .100,
                  "target_dimensions_m": [.032, .135, .220], "muzzle_recess_depth_m": .010,
                  "budget_policy": "quality-first; source polygons and render triangles reported separately"}


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


reports = []
for builder, name in [(pistol, "obsidian_pistol")]:
    root, detail = builder()
    reports.append(export(root, name, detail))
(HERE / "manifest.json").write_text(json.dumps({"models": reports}, indent=2) + "\n", encoding="utf-8")
for report in reports:
    print("EPIC1_MODEL", report["file"], report["source_polygons"], "polygons", report["glb_triangles"], "triangles", report["bounds_game"])
