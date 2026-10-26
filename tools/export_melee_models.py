"""Normalise the melee props into first-person models for Godot.

Run in Blender (4.x / 5.x), not in Godot:

    blender --background --python tools/export_melee_models.py

Sources, all kept out of the import pipeline per docs/ASSETS.md:

  * `tools/melee_sources/斧子.fbx`   -> assets/models/weapons/axe.glb
  * `tools/melee_sources/太刀.fbx`   -> assets/models/weapons/tachi.glb
  * `assets/models/characters/enemy.gltf` 里的 `Knife_1` -> assets/models/weapons/knife.glb

Every export lands in the same frame, so the runtime never has to compensate:

  * origin = middle of the grip (where the hand closes)
  * -Z     = grip -> tip, the direction Godot calls forward. glTF is Y-up, so
             the model has to run along Blender +Y for that to come out right.
  * +X     = blade thickness normal, so the flats face left / right
  * +Y     = across the blade; a chop about X sweeps the edge downwards
  * length = a sane real-world size per prop (see TARGET_LENGTH)

The two FBX files carry one embedded atlas texture; the glTF exporter writes it
inside the .glb, and Godot extracts it next to the model on import
(`<name>_Atlas_Pirate.png`).

The numbers in `weapons/melee/*.tres` assume these sizes; re-export with a
different `target_length` and the swings will look too big or too small. In
particular `blade_length` in each .tres is `(1 - grip_inset) * target_length`:
the grip sits `grip_inset` of the way in from the butt, so the tip is the rest of
it. Default inset is 12%; the axe uses 2% so no handle end hangs between the hand
and the eye.
"""

import json
import os

import bpy
from mathutils import Matrix, Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(ROOT, "assets", "models", "weapons")
SOURCES = os.path.join(ROOT, "tools", "melee_sources")

# Default inset of the grip from the narrow end, as a fraction of the length.
# Whatever sits behind the grip is *behind the hand*, i.e. between the hand and
# the eye: a 12% inset leaves 11 cm of handle sticking back at the camera, and the
# axe's rounded butt cap then hangs in the middle of the screen all through the
# down stroke. A job can override it, and the axe does: its hands go at the very
# end of the shaft, which is also how a two-handed chop is actually held.
DEFAULT_GRIP_INSET = 0.12

JOBS = [
    {
        "name": "knife",
        "source": os.path.join(ROOT, "assets", "models", "characters", "enemy.gltf"),
        "object": "Knife_1",
        "target_length": 0.46,
    },
    {
        "name": "axe",
        "source": os.path.join(SOURCES, "斧子.fbx"),
        "object": "Weapon_DoubleAxe",
        "target_length": 0.92,
        # Two hands go on the shaft, about 18 cm above the butt: that is where a
        # two-handed chop holds it, and the trim then lands in the brown part of
        # the shaft instead of cutting through the grey pommel. Whatever is left
        # behind the grip is between the hand and the eye, so it is cut off.
        "grip_inset": 0.20,
        "trim_behind_grip": True,
    },
    {
        "name": "tachi",
        "source": os.path.join(SOURCES, "太刀.fbx"),
        "object": "Weapon_Cutlass",
        "target_length": 1.00,
        # The bow guard is wider than the grip (about 19 cm against 5 cm), so the
        # narrow-end rule below picks the point of the blade, not the hand.
        "grip_at": "wide",
    },
]


def log(message):
    print("MELEE " + str(message))


def bbox(obj):
    points = [obj.matrix_world @ v.co for v in obj.data.vertices]
    lo = Vector((min(p.x for p in points), min(p.y for p in points), min(p.z for p in points)))
    hi = Vector((max(p.x for p in points), max(p.y for p in points), max(p.z for p in points)))
    return lo, hi


def load_mesh(source, wanted):
    """Import the source and return the wanted mesh with its world transform
    baked in, so the object matrix does not have to be carried around."""
    if source.endswith((".gltf", ".glb")):
        bpy.ops.import_scene.gltf(filepath=source)
    else:
        bpy.ops.import_scene.fbx(filepath=source)
    bpy.context.view_layer.update()

    found = bpy.data.objects.get(wanted) if wanted else None
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


def trim_behind_grip(obj):
    """Cut the prop off at the grip plane and cap the cut.

    A first-person model is seen from the hand outward, and there is no hand
    modelled to hide the end of the shaft. Whatever sits behind the origin hangs
    between the hand and the eye at arm's length, where it is huge: the axe's
    rounded butt cap showed up as a grey ball in the middle of the screen for the
    whole down stroke. Trimming it is what a real viewmodel does.
    """
    import bmesh

    bm = bmesh.new()
    bm.from_mesh(obj.data)
    geometry = bm.verts[:] + bm.edges[:] + bm.faces[:]
    cut = bmesh.ops.bisect_plane(
        bm,
        geom=geometry,
        plane_co=(0.0, 0.0, 0.0),
        plane_no=(0.0, 1.0, 0.0),
        clear_inner=True,
    )
    edges = [e for e in cut["geom_cut"] if isinstance(e, bmesh.types.BMEdge)]
    if edges:
        bmesh.ops.holes_fill(bm, edges=edges, sides=0)
    bm.to_mesh(obj.data)
    bm.free()
    obj.data.update()


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
    """Widest distance from the long axis inside one slab of the prop. The grip
    end is the narrow one: a blade or an axe head is much wider than its handle.

    The slab starts 10% in from the end instead of at the end: a blade tapers to
    a point, and the last few centimetres of a tip are narrower than any handle,
    which would put the grip at the wrong end of a knife.
    """
    widest = 0.0
    for offset in relative:
        along = offset.dot(axis)
        if t_lo <= along <= t_hi:
            widest = max(widest, (offset - axis * along).length)
    return widest


def normalise(job):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    obj, original = load_mesh(job["source"], job["object"])
    mesh = obj.data
    points = [v.co.copy() for v in mesh.vertices]
    centre, axes = principal_axes(mesh)

    along = axes[0][0].copy()
    relative = [p - centre for p in points]
    projected = [d.dot(along) for d in relative]
    length = max(projected) - min(projected)
    lo_radius = end_radius(relative, along, min(projected) + 0.10 * length,
                           min(projected) + 0.30 * length)
    hi_radius = end_radius(relative, along, max(projected) - 0.30 * length,
                           max(projected) - 0.10 * length)
    # Which end the hand closes on. The default rule is "the narrow end": a blade
    # or an axe head is much wider than its handle. The cutlass breaks that rule
    # (its bow guard is the widest part of the hilt), so a job can say the grip
    # is at the wide end instead.
    wide_at_max = hi_radius >= lo_radius
    grip_at_max = (job.get("grip_at", "narrow") == "wide") == wide_at_max
    if grip_at_max:
        along = -along
        projected = [-t for t in projected]
    length = max(projected) - min(projected)

    # Flattest axis of the blade half: the direction the flats face.
    thin = min(axes[1:], key=lambda a: a[1])[0]
    thin = thin - along * thin.dot(along)
    if thin.length < 1e-6:
        thin = along.cross(Vector((0, 0, 1)))
    thin.normalize()

    across = thin.cross(along).normalized()
    blade = [d for d in relative if d.dot(along) > 0.45 * length]
    bulge = sum((d.dot(across) for d in blade), 0.0) / max(len(blade), 1)
    if bulge > 0.0:
        # Roll so the belly of a curved blade or an axe edge faces down, which is
        # how the weapon sits at rest. Symmetric props measure ~0 and keep it.
        thin = -thin
        across = -across

    # Rows are the canonical axes in world space, so rot @ world -> canonical.
    rot = Matrix((
        (thin.x, thin.y, thin.z),
        (along.x, along.y, along.z),
        (across.x, across.y, across.z),
    ))
    if abs(rot.determinant() - 1.0) > 1e-5:
        raise RuntimeError("axis frame is not a rotation")

    inset = float(job.get("grip_inset", DEFAULT_GRIP_INSET))
    grip = centre + along * (min(projected) + inset * length)
    scale = job["target_length"] / max(length, 1e-6)
    mesh.transform(Matrix.Scale(scale, 4) @ rot.to_4x4() @ Matrix.Translation(-grip))
    mesh.update()
    if job.get("trim_behind_grip", False):
        trim_behind_grip(obj)

    lo, hi = bbox(obj)
    return obj, {
        "name": job["name"],
        "object": original.name,
        "source": os.path.basename(job["source"]),
        "raw_length_cm": round(length * 100.0, 1),
        "scale": round(scale, 4),
        "bbox_cm": [round(v * 100.0, 1) for v in (hi - lo)],
        "grip_inset": inset,
        "trimmed": bool(job.get("trim_behind_grip", False)),
        "tip_cm": round((1.0 - inset) * job["target_length"] * 100.0, 1),
        "grip_to_top_cm": round(hi.y * 100.0, 1),
        "verts": len(mesh.vertices),
        "tris": sum(len(p.vertices) - 2 for p in mesh.polygons),
        "materials": [m.name for m in mesh.materials if m],
    }


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    reports = []
    for job in JOBS:
        if not os.path.exists(job["source"]):
            log("MISSING %s (see docs/ASSETS.md)" % job["source"])
            continue
        obj, report = normalise(job)
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
