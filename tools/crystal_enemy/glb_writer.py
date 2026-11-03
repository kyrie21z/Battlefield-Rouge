# -*- coding: utf-8 -*-
"""Minimal but spec-correct glTF 2.0 / GLB writer (numpy in, .glb out).

Only what we need: POSITION / NORMAL / JOINTS_0 / WEIGHTS_0, indices, skins,
PBR materials. Handedness: caller supplies already-converted (right-handed) data.
"""
import json
import struct
import numpy as np

COMP = {np.float32: 5126, np.uint32: 5125, np.uint16: 5123, np.uint8: 5121,
        np.int16: 5122, np.int8: 5120}
NCOMP = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}


class Writer:
    def __init__(self, generator="bfr-crystal-export"):
        self.generator = generator
        self.blob = bytearray()
        self.buffer_views = []
        self.accessors = []
        self.meshes = []
        self.nodes = []
        self.skins = []
        self.materials = []
        self.scenes = []
        self.extensions_used = []

    # ---------- low level ----------
    def _pad4(self):
        while len(self.blob) % 4:
            self.blob.append(0)

    def add_buffer_view(self, data, target=None):
        self._pad4()
        off = len(self.blob)
        self.blob.extend(data)
        bv = {"buffer": 0, "byteOffset": off, "byteLength": len(data)}
        if target:
            bv["target"] = target
        self.buffer_views.append(bv)
        return len(self.buffer_views) - 1

    def add_accessor(self, arr, comp_type=None, type_str=None, target=None,
                     minmax=False, normalized=False, byte_stride=None):
        arr = np.ascontiguousarray(arr)
        if comp_type is None:
            comp_type = COMP[arr.dtype.type]
        if type_str is None:
            type_str = {1: "SCALAR", 2: "VEC2", 3: "VEC3", 4: "VEC4", 16: "MAT4"}[
                arr.shape[1] if arr.ndim > 1 else 1]
        data = arr.tobytes()
        bv = self.add_buffer_view(data, target)
        acc = {"bufferView": bv, "componentType": comp_type,
               "count": int(arr.shape[0]), "type": type_str}
        if normalized:
            acc["normalized"] = True
        if minmax:
            mn = arr.min(axis=0) if arr.ndim > 1 else np.array([arr.min()])
            mx = arr.max(axis=0) if arr.ndim > 1 else np.array([arr.max()])
            acc["min"] = [float(x) for x in np.atleast_1d(mn)]
            acc["max"] = [float(x) for x in np.atleast_1d(mx)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def add_node(self, name, translation=None, rotation=None, scale=None,
                 mesh=None, skin=None, children=None, extras=None):
        n = {"name": name}
        if translation is not None:
            n["translation"] = [float(x) for x in translation]
        if rotation is not None:
            n["rotation"] = [float(x) for x in rotation]
        if scale is not None:
            n["scale"] = [float(x) for x in scale]
        if mesh is not None:
            n["mesh"] = mesh
        if skin is not None:
            n["skin"] = skin
        if children:
            n["children"] = list(children)
        if extras:
            n["extras"] = extras
        self.nodes.append(n)
        return len(self.nodes) - 1

    def add_material(self, name, base_color, metallic=0.0, roughness=0.25,
                     emissive=None, emissive_strength=None, double_sided=False,
                     alpha_mode="OPAQUE", extra_pbr=None):
        m = {"name": name,
             "pbrMetallicRoughness": {
                 "baseColorFactor": [float(x) for x in base_color],
                 "metallicFactor": float(metallic),
                 "roughnessFactor": float(roughness)},
             "doubleSided": bool(double_sided)}
        if extra_pbr:
            m["pbrMetallicRoughness"].update(extra_pbr)
        if emissive:
            m["emissiveFactor"] = [float(x) for x in emissive]
            if emissive_strength:
                m.setdefault("extensions", {})["KHR_materials_emissive_strength"] = {
                    "emissiveStrength": float(emissive_strength)}
                if "KHR_materials_emissive_strength" not in self.extensions_used:
                    self.extensions_used.append("KHR_materials_emissive_strength")
        if alpha_mode != "OPAQUE":
            m["alphaMode"] = alpha_mode
        self.materials.append(m)
        return len(self.materials) - 1

    # ---------- save ----------
    def save(self, path, scene_name="Scene"):
        gltf = {
            "asset": {"version": "2.0", "generator": self.generator},
            "scene": 0,
            "scenes": [{"name": scene_name, "nodes": self.scene_nodes}],
            "nodes": self.nodes,
            "meshes": self.meshes,
            "accessors": self.accessors,
            "bufferViews": self.buffer_views,
            "buffers": [{"byteLength": 0}],
        }
        if self.materials:
            gltf["materials"] = self.materials
        if self.skins:
            gltf["skins"] = self.skins
        if self.extensions_used:
            gltf["extensionsUsed"] = list(self.extensions_used)
        self._pad4()
        gltf["buffers"][0]["byteLength"] = len(self.blob)

        js = json.dumps(gltf, ensure_ascii=False, separators=(",", ":")).encode("utf-8")
        while len(js) % 4:
            js += b" "
        bin_chunk = bytes(self.blob)
        total = 12 + 8 + len(js) + 8 + len(bin_chunk)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(js), 0x4E4F534A))
            f.write(js)
            f.write(struct.pack("<II", len(bin_chunk), 0x004E4942))
            f.write(bin_chunk)
        return {"path": path, "bytes": total, "nodes": len(self.nodes),
                "meshes": len(self.meshes), "accessors": len(self.accessors)}

    def add_mesh(self, name, primitives):
        self.meshes.append({"name": name, "primitives": primitives})
        return len(self.meshes) - 1
