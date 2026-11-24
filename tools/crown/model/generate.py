"""Build the original A3 crown with Blender 5.2, then export its Godot GLB.

Run with blender --background --factory-startup --python-exit-code 1 --python generate.py.
Geometry uses +X right, +Y up and -Z forward before conversion to Blender axes.
"""

import hashlib
import json
import math
import struct
from pathlib import Path

import bpy
from mathutils import Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
OUT = ROOT / "assets/models/crown"
INNER_X = 0.067
INNER_Z = 0.080
PEAK_HEIGHTS = {0: 0.082, 2: 0.065, 4: 0.052, 6: 0.046, 8: 0.052, 10: 0.065}
VALLEY_HEIGHTS = {1: 0.015, 3: 0.013, 5: 0.011, 7: 0.011, 9: 0.013, 11: 0.015}
SECTORS = 12


def crown_geometry():
    wall_mid = 0.0095
    wall_base = 0.007
    crest_thick = 0.0022
    rings = [[] for _ in range(6)]
    for sector in range(SECTORS):
        angle = math.tau * sector / SECTORS
        peak = sector in PEAK_HEIGHTS
        top = PEAK_HEIGHTS[sector] if peak else VALLEY_HEIGHTS[sector]
        bottom = -0.012 if peak else -0.009
        middle = bottom + (top - bottom) * (0.24 if peak else 0.42)
        upper = bottom + (top - bottom) * (0.64 if peak else 0.74)
        flare = 1.08 if peak else 0.99
        middle_wall = wall_mid * (1.06 if peak else 0.92)
        upper_wall = wall_mid * (0.62 if peak else 0.68)
        # Each section follows the closed profile from base to outer facets,
        # crest, and inner bevel. The tallest crest faces forward.
        profile = (
            (wall_base * 0.45, 1.0, bottom),
            (middle_wall, 1.015 if peak else 0.995, middle),
            (upper_wall, flare, upper),
            (crest_thick, flare * 1.01 if peak else 1.0, top),
            (0.0, 1.02 if peak else 0.995, upper),
            (0.0, 1.0, middle),
        )
        for ring, (wall, scale, height) in zip(rings, profile):
            ring.append(Vector((
                math.sin(angle) * (INNER_X + wall) * scale,
                height,
                -math.cos(angle) * (INNER_Z + wall) * scale,
            )))

    vertices = [point for ring in rings for point in ring]
    triangles = []
    for ring in range(len(rings)):
        current = ring * SECTORS
        following = (ring + 1) % len(rings) * SECTORS
        for sector in range(SECTORS):
            next_sector = (sector + 1) % SECTORS
            a, b = current + sector, current + next_sector
            c, d = following + next_sector, following + sector
            triangles.extend(((a, b, c), (a, c, d)))

    signed_volume = sum(vertices[a].dot(vertices[b].cross(vertices[c]))
                        for a, b, c in triangles)
    assert signed_volume != 0.0
    if signed_volume < 0.0:
        triangles = [(a, c, b) for a, b, c in triangles]
    return vertices, triangles


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.unit_settings.system = "METRIC"
    vertices, triangles = crown_geometry()
    mesh = bpy.data.meshes.new("PrideCrown_A3")
    mesh.from_pydata([(x, -z, y) for x, y, z in vertices], [], triangles)
    mesh.update()
    crown = bpy.data.objects.new("PrideCrown_A3", mesh)
    bpy.context.collection.objects.link(crown)
    crown.select_set(True)
    bpy.context.view_layer.objects.active = crown

    # The Godot shader is applied at runtime. Give the authoring mesh a gold preview.
    material = bpy.data.materials.new("Golden Crystal")
    material.diffuse_color = (0.88, 0.64, 0.16, 1.0)
    material.metallic = 0.22
    material.roughness = 0.06
    mesh.materials.append(material)

    source = HERE / "pride_crown.blend"
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(source), compress=True)
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / "pride_crown.glb"
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB", use_selection=True,
                             export_yup=True, export_animations=False)

    raw = path.read_bytes()
    length, kind = struct.unpack_from("<II", raw, 12)
    assert kind == 0x4E4F534A
    gltf = json.loads(raw[20:20 + length])
    primitive, = gltf["meshes"][0]["primitives"]
    accessors = gltf["accessors"]
    triangle_count = accessors[primitive["indices"]]["count"] // 3
    assert len(gltf["meshes"]) == 1 and triangle_count == len(triangles) == 144
    position = accessors[primitive["attributes"]["POSITION"]]
    low, high = position["min"], position["max"]
    report = {
        "file": path.relative_to(ROOT).as_posix(),
        "source": source.relative_to(ROOT).as_posix(),
        "design": "A3",
        "blender_version": bpy.app.version_string,
        "glb_triangles": triangle_count,
        "flat_faces": all(not face.use_smooth for face in mesh.polygons),
        "bounds_game_m": {
            "min": low,
            "max": high,
            "size": [upper - lower for lower, upper in zip(low, high)],
        },
        "inner_width_m": INNER_X * 2,
        "inner_depth_m": INNER_Z * 2,
        "game_forward": "-Z",
        "game_up": "+Y",
        "sha256": hashlib.sha256(raw).hexdigest(),
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
    }
    (HERE / "manifest.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8", newline="\n")
    print("CROWN_MODEL", report)


if __name__ == "__main__":
    main()
