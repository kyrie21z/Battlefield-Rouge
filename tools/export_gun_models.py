"""Normalise the two gun props into first-person models for Godot.

Sources live in `tools/gun_sources/` (with a `.gdignore`, so Godot never scans
them). Run in Blender:

    blender --background --python tools/export_gun_models.py

Every export lands in the same frame the melee props use, so the view scenes are
plain instances with no compensating rotation:

  * origin  = the grip (where the trigger hand goes)
  * -Z      = grip -> muzzle (Godot forward). glTF is Y-up, so in Blender the
              gun has to run along +Y for that to come out right.
  * +Y      = up (in Blender +Z)
  * length  = a sane first-person size per gun (see TARGET_LENGTH)

Which end is the muzzle is decided from the shape, not assumed: the barrel end is
much narrower than the stock end, the same "narrow end" rule the melee exporter
uses for the grip. `grip_fraction` is where the trigger hand sits, measured from
the stock end.
"""

import json
import os

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(ROOT, "tools", "gun_sources")
OUT_DIR = os.path.join(ROOT, "assets", "models", "weapons")

JOBS = [
    {
        "name": "shotgun",
        "source": "Shotgun.fbx",
        "object": "Shotgun",
        "target_length": 0.88,
        "grip_fraction": 0.26,
        # This kit puts the muzzle at +X (the AK does too). The geometric
        # narrow-end guess gets a pump shotgun backwards: its butt is slimmer than
        # the barrel-plus-magazine front, so the muzzle is stated here and the
        # number is checked against the guess (see `muzzle_guess` in the report).
        "muzzle": "max",
    },
    {
        "name": "sniper",
        "source": "Sniper_2.fbx",
        "object": "Sniper_2",
        "target_length": 1.08,
        "grip_fraction": 0.26,
        "muzzle": "max",
        # Without this the scope ends up under the receiver: PCA leaves the up
        # eigenvector's sign free, and for this model it comes out inverted.
        "flip_up": True,
    },
]


def log(message):
    print("GUN " + str(message))


def load_mesh(source, wanted):
    """Import the source and return one mesh with its world transform baked in."""
    if source.endswith((".gltf", ".glb")):
        bpy.ops.import_scene.gltf(filepath=source)
    else:
        bpy.ops.import_scene.fbx(filepath=source)
    bpy.context.view_layer.update()
    found = bpy.data.objects.get(wanted)
    if found is None:
        candidates = [o for o in bpy.data.objects if o.type == "MESH"]
        if not candidates:
            raise RuntimeError("no mesh in %s" % source)
        found = max(candidates, key=lambda o: len(o.data.vertices))
    mesh = found.data.copy()
    mesh.transform(found.matrix_world)
    baked = bpy.data.objects.new("Baked_" + found.name, mesh)
    bpy.context.collection.objects.link(baked)
    return baked, found


def principal_axes(mesh):
    """Longest-to-shortest axes of the vertex cloud, with their spreads."""
    import numpy as np

    points = [v.co.copy() for v in mesh.vertices]
    centre = sum(points, Vector()) / len(points)
    cloud = np.array([[p.x, p.y, p.z] for p in points])
    values, vectors = np.linalg.eigh(np.cov(cloud.T))
    order = np.argsort(values)[::-1]
    return centre, [(Vector(vectors[:, i].tolist()).normalized(), float(values[i]) ** 0.5) for i in order]


def end_radius(relative, axis, t_lo, t_hi):
    """Widest distance from the long axis inside one slab of the prop."""
    widest = 0.0
    for offset in relative:
        along = offset.dot(axis)
        if t_lo <= along <= t_hi:
            widest = max(widest, (offset - axis * along).length)
    return widest


def normalise(job):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj, original = load_mesh(os.path.join(SOURCES, job["source"]), job["object"])
    mesh = obj.data
    centre, axes = principal_axes(mesh)

    along = axes[0][0].copy()
    relative = [p.co - centre for p in mesh.vertices]
    projected = [d.dot(along) for d in relative]
    length = max(projected) - min(projected)
    lo_radius = end_radius(relative, along, min(projected) + 0.10 * length,
                           min(projected) + 0.25 * length)
    hi_radius = end_radius(relative, along, max(projected) - 0.25 * length,
                           max(projected) - 0.10 * length)
    # Which end is the muzzle: a per-job statement wins, because the geometric
    # "narrow end" guess is wrong for a pump shotgun (its butt is slimmer than the
    # barrel-plus-magazine front). The guess is still computed and reported, so a
    # disagreement shows up in the log instead of silently reversing the gun.
    guessed_max = hi_radius <= lo_radius
    wanted = job.get("muzzle", "auto")
    muzzle_at_max = guessed_max if wanted == "auto" else (wanted == "max")
    if not muzzle_at_max:
        along = -along
        projected = [-t for t in projected]

    # Which of the two remaining axes is up: the taller one. Guns are tall through
    # the stock and scope, thin through the receiver. PCA does not determine the
    # *sign* of an eigenvector, and half a turn about the barrel puts the scope
    # underneath and the magazine on top, so a per-job flag settles it. It is
    # verified by the side render in docs/proof/guns, not by the numbers.
    up = max(axes[1:], key=lambda a: a[1])[0]
    up = up - along * up.dot(along)
    if up.length < 1e-6:
        up = along.cross(Vector((1, 0, 0)))
    up.normalize()
    if job.get("flip_up", False):
        up = -up
    right = along.cross(up).normalized()

    # Rows are the canonical axes in world space, so rot @ world -> canonical.
    rot = Matrix((
        (right.x, right.y, right.z),
        (along.x, along.y, along.z),
        (up.x, up.y, up.z),
    ))
    if abs(rot.determinant() - 1.0) > 1e-4:
        rot = Matrix((
            (-right.x, -right.y, -right.z),
            (along.x, along.y, along.z),
            (up.x, up.y, up.z),
        ))
    if abs(rot.determinant() - 1.0) > 1e-4:
        raise RuntimeError("axis frame is not a rotation")

    scale = job["target_length"] / max(length, 1e-6)
    mesh.transform(Matrix.Scale(scale, 4) @ rot.to_4x4() @ Matrix.Translation(-centre))
    mesh.update()

    # Grip point: partway forward from the stock end, centred in X and Z.
    points = [v.co.copy() for v in mesh.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    grip = Vector(((lo.x + hi.x) * 0.5,
                   lo.y + job["grip_fraction"] * (hi.y - lo.y),
                   (lo.z + hi.z) * 0.5))
    mesh.transform(Matrix.Translation(-grip))
    mesh.update()

    points = [v.co.copy() for v in mesh.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return obj, {
        "name": job["name"],
        "object": original.name,
        "source": job["source"],
        "raw_length_cm": round(length * 100.0, 1),
        "scale": round(scale, 4),
        "muzzle": "max" if muzzle_at_max else "min",
        "muzzle_guess": "max" if guessed_max else "min",
        "guess_agrees": guessed_max == muzzle_at_max,
        "up_flipped": bool(job.get("flip_up", False)),
        "end_radius_cm": [round(lo_radius * 100.0, 2), round(hi_radius * 100.0, 2)],
        "bbox_cm": [round(v * 100.0, 1) for v in (hi - lo)],
        "muzzle_cm_from_grip": round(hi.y * 100.0, 1),
        "stock_cm_from_grip": round(lo.y * 100.0, 1),
        "verts": len(mesh.vertices),
        "tris": sum(len(p.vertices) - 2 for p in mesh.polygons),
        "materials": [m.name for m in mesh.materials if m],
    }


def sanitise_materials():
    """Make every material opaque.

    The FBX materials arrive with an Alpha of 0, which the glTF exporter faithfully
    turns into an alpha-blended material — the gun then renders perfectly invisible
    in Godot. Force alpha back to 1 and drop any alpha wiring.
    """
    for material in bpy.data.materials:
        if not material.use_nodes or material.node_tree is None:
            continue
        for node in material.node_tree.nodes:
            if node.type != "BSDF_PRINCIPLED":
                continue
            alpha = node.inputs.get("Alpha")
            if alpha is not None:
                for link in list(alpha.links):
                    material.node_tree.links.remove(link)
                alpha.default_value = 1.0
            base = node.inputs.get("Base Color")
            if base is not None:
                colour = base.default_value
                base.default_value = (colour[0], colour[1], colour[2], 1.0)
        try:
            material.surface_render_method = "DITHERED"
        except AttributeError:
            pass


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    reports = []
    for job in JOBS:
        source = os.path.join(SOURCES, job["source"])
        if not os.path.exists(source):
            log("MISSING %s" % source)
            continue
        obj, report = normalise(job)
        sanitise_materials()
        bpy.ops.object.select_all(action="DESELECT")
        obj.select_set(True)
        bpy.context.view_layer.objects.active = obj
        path = os.path.join(OUT_DIR, job["name"] + ".glb")
        bpy.ops.export_scene.gltf(
            filepath=path,
            export_format="GLB",
            use_selection=True,
            export_apply=True,
            export_yup=True,
        )
        report["glb"] = os.path.relpath(path, ROOT)
        report["bytes"] = os.path.getsize(path)
        reports.append(report)
        log(json.dumps(report, ensure_ascii=False))
    log("DONE %d/%d" % (len(reports), len(JOBS)))


main()
