"""Author faceted palm and finger shapes against the game's actual prop axes.

Run with Blender in background mode. Shape coordinates are millimetres in
Godot's grip frame. Pistol depth is measured parallel to the slanted grip
face. The editable file keeps the individual digits and prop references.
"""

import json
import math
from pathlib import Path

import bmesh
import bpy
from mathutils import Matrix, Vector


HERE = Path(__file__).resolve().parent
ROOT = HERE.parent.parent
MODELS = ROOT / "assets/models"
OUTPUT = MODELS / "characters/protagonist_hands.glb"
CALIBRATION = json.loads((HERE / "calibration.json").read_text())

# Each station has a centre and two section half-widths. The narrower tips
# and the intermediate rings create visible knuckles in the flat silhouette.
RIGHT_PALM = [
    ((25, -17, 78), 25, 25),
    ((28, -8, 57), 27, 29),
    ((25, 2, 39), 25, 33),
    ((23, 2, 30), 21, 28),
]
RIGHT_DIGITS = [
    # Thumb over the back of the grip.
    [((12, 23, 46), 12, 10), ((2, 30, 42), 10, 9),
     ((-15, 31, 33), 9, 7), ((-24, 26, 13), 7, 6), ((-23, 18, 5), 3, 4)],
    # The index runs beside the frame, clear of the other fingers.
    [((36, 24, 35), 11, 10), ((30, 34, 15), 8, 9),
     ((25, 38, -8), 7, 8), ((24, 39, -35), 7, 6), ((22, 37, -48), 4, 4)],
    [((35, 12, 33), 10, 9), ((24, 15, 9), 9, 8),
     ((24, 15, -20), 8, 8), ((14, 15, -37), 8, 8), ((-7, 14, -37), 5, 6)],
    [((36, -5, 35), 10, 9), ((25, -4, 11), 8, 8),
     ((24, -3, -19), 8, 8), ((12, -3, -36), 8, 7), ((-9, -4, -36), 5, 5)],
    [((35, -21, 36), 9, 9), ((23, -21, 10), 7, 7),
     ((22, -20, -18), 7, 7), ((10, -20, -32), 7, 6), ((-8, -21, -31), 4, 5)],
]
LEFT_PALM = [
    ((-32, -24, 85), 25, 26),
    ((-36, -31, 61), 25, 28),
    ((-31, -28, 36), 17, 29),
    ((-25, -30, 16), 15, 26),
]
LEFT_DIGITS = [
    [((-36, -8, 43), 11, 10), ((-27, 3, 25), 10, 9),
     ((-24, 13, 6), 9, 7), ((-23, 22, -12), 8, 6), ((-22, 24, -24), 4, 4)],
    [((-31, -11, 26), 11, 8), ((-31, -8, 5), 10, 8),
     ((-27, -8, -25), 9, 8), ((-18, -9, -40), 9, 7), ((-3, -9, -43), 5, 5)],
    [((-30, -27, 24), 10, 9), ((-28, -26, 1), 9, 8),
     ((-24, -25, -23), 8, 8), ((-14, -24, -39), 8, 7), ((5, -24, -41), 5, 5)],
    [((-30, -42, 27), 10, 8), ((-27, -41, 6), 9, 7),
     ((-20, -39, -22), 8, 7), ((-9, -39, -34), 7, 7), ((9, -38, -34), 5, 5)],
    [((-27, -55, 30), 8, 7), ((-21, -54, 9), 7, 6),
     ((-14, -54, -12), 7, 6), ((-3, -53, -24), 6, 5), ((12, -48, -22), 4, 4)],
]
BLADE_PALM = [
    ((0, -13, 48), 26, 26),
    ((9, -19, 33), 27, 25),
    ((15, -19, 13), 23, 23),
    ((15, -16, -6), 16, 20),
]
BLADE_THUMB = [
    ((13, -20, -14), 12, 10), ((5, -20, -28), 10, 8),
    ((-7, -15, -33), 8, 7), ((-13, -5, -30), 7, 6), ((-12, 3, -24), 4, 4),
]


def blade_digit(z, width):
    return [
        ((16, -19, z + 6), width + 2, 9), ((19, -2, z + 3), width + 1, 8),
        ((10, 15, z), width, 8), ((-3, 17, z - 2), width, 7),
        ((-11, 10, z - 2), width - 3, 5),
    ]


BLADE_DIGITS = [BLADE_THUMB] + [blade_digit(z, size) for z, size in
                                [(-15, 9), (1, 9), (17, 8), (32, 7)]]


def game_to_blender(point):
    x, y, z = point
    return Vector((x, -z, y))


def blender_to_game(point):
    x, y, z = point
    return Vector((x, z, -y))


def transform(columns):
    return Matrix(tuple((*column, float(i == 3)) for i, column in
                        enumerate(columns))).transposed()


def gun_point(point):
    x, y, depth = point
    return Vector((x, y, depth - 0.30 * y))


def sweep(stations, axis_hint, convert, sides):
    centers = [convert(center) for center, _, _ in stations]
    vertices = []
    for i, (_, radius, across) in enumerate(stations):
        tangent = (centers[min(i + 1, len(centers) - 1)] -
                   centers[max(i - 1, 0)]).normalized()
        v = (axis_hint - tangent * axis_hint.dot(tangent)).normalized()
        u = v.cross(tangent)
        for j in range(sides):
            angle = (j + 0.5) * math.tau / sides
            vertices.append(centers[i] + u * (radius * math.cos(angle))
                            + v * (across * math.sin(angle)))
    faces = [tuple(range(sides - 1, -1, -1))]
    for row in range(len(stations) - 1):
        for i in range(sides):
            a = row * sides + i
            b = row * sides + (i + 1) % sides
            faces.append((a, b, b + sides, a + sides))
    faces.append(tuple(range(len(vertices) - sides, len(vertices))))
    return vertices, faces


def build_hand(side):
    pose = CALIBRATION[side]
    palm = RIGHT_PALM if side == "Right" else LEFT_PALM
    digits = RIGHT_DIGITS if side == "Right" else LEFT_DIGITS
    pistol_from_hand = transform(pose["weapon_from_hand"])
    hand_from_pistol = pistol_from_hand.inverted()
    hand_from_blade = transform(pose["blade_from_hand"]).inverted() if side == "Left" else None
    points = []
    blade_points = []
    triangles = []
    segments = [("Palm", palm, BLADE_PALM, 8)]
    segments += [(name, finger, blade, 6) for name, finger, blade in
                 zip(("Thumb", "Index", "Middle", "Ring", "Little"), digits, BLADE_DIGITS)]
    for name, stations, blade_stations, sides in segments:
        posed, faces = sweep(stations, Vector((0, 1, 0)), gun_point, sides)
        start = len(points)
        triangles.extend(tuple(i + len(points) for i in face) for face in faces)
        points.extend(hand_from_pistol @ (point * 0.001) for point in posed)
        if name == "Palm":
            center_x, center_z = (-8, -12) if side == "Right" else (7, -3)
            for i in range(sides):
                angle = (i + 0.5) * math.tau / sides
                points[start + i] = Vector((
                    (center_x - 23 * math.cos(angle)) * 0.001,
                    -0.017,
                    (center_z + 24 * math.sin(angle)) * 0.001,
                ))
        if hand_from_blade is not None:
            hint = Vector((0, 1, 0)) if name == "Palm" else Vector((0, 0, 1))
            posed, _ = sweep(blade_stations, hint, Vector, sides)
            segment = [hand_from_blade @ (point * 0.001) for point in posed]
            # Keep the wrist seam fixed across hand poses.
            if name == "Palm":
                segment[:sides] = points[:sides]
            blade_points.extend(segment)
    return points, triangles, blade_points


def add_hand_mesh(name, points, faces, blade_points):
    mesh = bpy.data.meshes.new(name)
    mesh.from_pydata([game_to_blender(v) for v in points], [], faces)
    bm = bmesh.new()
    bm.from_mesh(mesh)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bm.to_mesh(mesh)
    bm.free()
    mesh.update()
    uv = mesh.uv_layers.new(name="UVMap")
    for face in mesh.polygons:
        for corner, loop in enumerate(face.loop_indices):
            angle = corner * math.tau / face.loop_total
            uv.data[loop].uv = (0.5 + 0.5 * math.cos(angle), 0.5 + 0.5 * math.sin(angle))
    obj = bpy.data.objects.new(name, mesh)
    bpy.context.collection.objects.link(obj)
    if blade_points:
        obj.shape_key_add(name="Basis")
        blade = obj.shape_key_add(name="BladeGrip")
        for vertex, point in zip(blade.data, blade_points):
            vertex.co = game_to_blender(point)
    return obj


def replace_hand(arm, hand, side):
    hand_from_mesh = transform(CALIBRATION[side]["hand_from_mesh"])
    cut_axis = Vector(hand_from_mesh[1][:3])
    cut_point = cut_axis * (0.012 - hand_from_mesh[1][3])
    bm = bmesh.new()
    bm.from_mesh(arm.data)
    bmesh.ops.bisect_plane(bm, geom=[*bm.verts, *bm.edges, *bm.faces],
                          dist=0.00001, plane_co=game_to_blender(cut_point),
                          plane_no=game_to_blender(cut_axis), clear_outer=True)
    bm.to_mesh(arm.data)
    bm.free()
    arm.data.update()

    insert = hand.copy()
    insert.data = hand.data.copy()
    bpy.context.collection.objects.link(insert)
    mesh_from_hand = hand_from_mesh.inverted()
    if insert.data.shape_keys:
        coordinates = (key.data for key in insert.data.shape_keys.key_blocks)
    else:
        coordinates = (insert.data.vertices,)
    for vertices in coordinates:
        for vertex in vertices:
            vertex.co = game_to_blender(mesh_from_hand @ blender_to_game(vertex.co))
    group = insert.vertex_groups.new(name=side + "Hand")
    group.add(list(range(len(insert.data.vertices))), 1.0, "REPLACE")
    bpy.ops.object.select_all(action="DESELECT")
    arm.select_set(True)
    insert.select_set(True)
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.join()
    # Godot supplies the protagonist crystal material for the whole forearm.
    arm.data.materials.clear()
    for face in arm.data.polygons:
        face.material_index = 0
    return arm


def place_preview(obj, grip_from_hand, offset=0.0):
    mapped = Matrix.Identity(4)
    axes = [game_to_blender(grip_from_hand.to_3x3() @ blender_to_game(axis))
            for axis in (Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1)))]
    for i, axis in enumerate(axes):
        mapped.col[i] = (*axis, 0.0)
    mapped.translation = game_to_blender(grip_from_hand.translation) + Vector((offset, 0, 0))
    obj.matrix_world = mapped


def show_authoring_poses(hands):
    for obj in bpy.context.scene.objects:
        obj.hide_set(obj not in hands)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / "weapons/obsidian_pistol.glb"))
    for hand, side in zip(hands, ("Right", "Left")):
        place_preview(hand, transform(CALIBRATION[side]["weapon_from_hand"]))
    bpy.ops.import_scene.gltf(filepath=str(MODELS / "weapons/mind_blade.glb"))
    for obj in bpy.context.selected_objects:
        if obj.parent is None:
            obj.location.x += 0.23
    held_blade = hands[1].copy()
    held_blade.data = hands[1].data.copy()
    bpy.context.collection.objects.link(held_blade)
    held_blade.name = "LeftBladeGrip"
    held_blade.data.shape_keys.key_blocks["BladeGrip"].value = 1.0
    place_preview(held_blade, transform(CALIBRATION["Left"]["blade_from_hand"]), 0.23)
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type == "VIEW_3D":
                view = area.spaces.active.region_3d
                view.view_location = Vector((0.09, 0.01, 0.01))
                view.view_distance = 0.67
                view.view_rotation = Vector((-1.0, 0.70, -0.83)).to_track_quat("-Z", "Y")


def main():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=str(MODELS / "characters/red_crystal_enemy_animated.glb"))
    rig = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
    hands = []
    arms = []
    for side in ("Right", "Left"):
        points, faces, blade = build_hand(side)
        hand = add_hand_mesh(side + "Grip", points, faces, blade)
        hands.append(hand)
        arm = bpy.data.objects["GEO_m_forearm_" + side[0]]
        arms.append(replace_hand(arm, hand, side))
    bpy.ops.object.select_all(action="DESELECT")
    for obj in [rig, *hands, *arms]:
        obj.select_set(True)
    bpy.context.view_layer.objects.active = hands[0]
    bpy.ops.export_scene.gltf(filepath=str(OUTPUT), use_selection=True,
                              export_animations=False, export_morph=True)
    show_authoring_poses(hands)
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=str(HERE / "protagonist_hands.blend"), compress=True)


if __name__ == "__main__":
    main()
