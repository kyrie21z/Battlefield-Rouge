# -*- coding: utf-8 -*-
"""纯 Python 校验 GLB：解析节点层次、比较关节世界矩阵、按 glTF 蒙皮公式重算顶点位置。"""
import json, struct, sys
import numpy as np

def load_glb(path):
    with open(path, "rb") as f:
        data = f.read()
    magic, ver, total = struct.unpack("<III", data[:12])
    assert magic == 0x46546C67
    off = 12
    js = None
    binchunk = None
    while off < total:
        ln, ty = struct.unpack("<II", data[off:off + 8])
        chunk = data[off + 8: off + 8 + ln]
        if ty == 0x4E4F534A:
            js = json.loads(chunk.decode("utf-8"))
        elif ty == 0x004E4942:
            binchunk = chunk
        off += 8 + ln
    return js, binchunk

CT = {5120: np.int8, 5121: np.uint8, 5122: np.int16, 5123: np.uint16,
      5125: np.uint32, 5126: np.float32}
NC = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16}

def read_accessor(g, blob, i):
    acc = g["accessors"][i]
    bv = g["bufferViews"][acc["bufferView"]]
    off = bv.get("byteOffset", 0) + acc.get("byteOffset", 0)
    dt = CT[acc["componentType"]]
    nc = NC[acc["type"]]
    n = acc["count"]
    raw = blob[off: off + np.dtype(dt).itemsize * nc * n]
    arr = np.frombuffer(raw, dtype=dt).reshape(n, nc)
    return arr

def trs_matrix(node):
    if "matrix" in node:
        return np.array(node["matrix"], dtype=np.float64).reshape(4, 4).T
    t = np.array(node.get("translation", [0, 0, 0]), dtype=np.float64)
    q = np.array(node.get("rotation", [0, 0, 0, 1]), dtype=np.float64)
    s = np.array(node.get("scale", [1, 1, 1]), dtype=np.float64)
    x, y, z, w = q / max(np.linalg.norm(q), 1e-12)
    R = np.array([
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)]])
    M = np.eye(4)
    M[:3, :3] = R * s[None, :]
    M[:3, 3] = t
    return M

def world_matrices(g):
    glob = {}
    def walk(i, parent):
        node = g["nodes"][i]
        M = parent @ trs_matrix(node)
        glob[i] = M
        for c in node.get("children", []):
            walk(c, M)
    for r in g["scenes"][g.get("scene", 0)]["nodes"]:
        walk(r, np.eye(4))
    return glob

def main(path_glb, path_expect):
    g, blob = load_glb(path_glb)
    W = world_matrices(g)
    print("nodes=%d meshes=%d skins=%d" % (len(g["nodes"]), len(g["meshes"]), len(g.get("skins", []))))
    exp = json.load(open(path_expect, encoding="utf-8"))["joints"]

    worst = 0.0
    worst_name = None
    for key, info in exp.items():
        node_i = info["node"]
        err = np.abs(W[node_i] - np.array(info["matrix"])).max()
        if err > worst:
            worst, worst_name = err, key
    print("关节世界矩阵最大误差 = %.6g  (%s)" % (worst, worst_name))

    if g.get("skins"):
        sk = g["skins"][0]
        joints = sk["joints"]
        ibm = read_accessor(g, blob, sk["inverseBindMatrices"]).astype(np.float64).reshape(-1, 4, 4)
        ibm = np.transpose(ibm, (0, 2, 1))   # glTF 是列主序
        jw = np.stack([W[j] for j in joints])
        skinmats = jw @ ibm                   # (J,4,4)
        lo = np.full(3, 1e9); hi = np.full(3, -1e9)
        tot = 0
        for mi, mesh in enumerate(g["meshes"]):
            for prim in mesh["primitives"]:
                P = read_accessor(g, blob, prim["attributes"]["POSITION"]).astype(np.float64)
                J = read_accessor(g, blob, prim["attributes"]["JOINTS_0"]).astype(int)
                Wt = read_accessor(g, blob, prim["attributes"]["WEIGHTS_0"]).astype(np.float64)
                vh = np.concatenate([P, np.ones((len(P), 1))], axis=1)
                out = np.zeros((len(P), 3))
                for k in range(J.shape[1]):
                    w = Wt[:, k]
                    for jj in np.unique(J[:, k]):
                        sel = J[:, k] == jj
                        if not sel.any():
                            continue
                        out[sel] += w[sel, None] * (vh[sel] @ skinmats[jj][:3, :].T)
                lo = np.minimum(lo, out.min(0)); hi = np.maximum(hi, out.max(0))
                tot += len(out)
        print("蒙皮重算 bbox min=%s max=%s size=%s  (verts=%d)" % (
            np.round(lo, 4).tolist(), np.round(hi, 4).tolist(), np.round(hi - lo, 4).tolist(), tot))

    # 静态 bbox（直接读 POSITION）
    for mi, mesh in enumerate(g["meshes"]):
        P = read_accessor(g, blob, mesh["primitives"][0]["attributes"]["POSITION"]).astype(np.float64)
        nd = [n for n in g["nodes"] if n.get("mesh") == mi]
        if mi < 3:
            print("  mesh[%d] %-28s verts=%-5d bboxMin=%s bboxMax=%s nodeTrs=%s" % (
                mi, mesh.get("name", "?"), len(P),
                np.round(P.min(0), 3).tolist(), np.round(P.max(0), 3).tolist(),
                ([round(x, 3) for x in nd[0].get("translation", [])] if nd else None)))
    # 合并静态 bbox（含节点变换）
    lo = np.full(3, 1e9); hi = np.full(3, -1e9)
    for mi, mesh in enumerate(g["meshes"]):
        P = read_accessor(g, blob, mesh["primitives"][0]["attributes"]["POSITION"]).astype(np.float64)
        for nd in [n for n in g["nodes"] if n.get("mesh") == mi]:
            M = W[g["nodes"].index(nd)]
            Pw = (np.concatenate([P, np.ones((len(P), 1))], axis=1) @ M.T)[:, :3]
            lo = np.minimum(lo, Pw.min(0)); hi = np.maximum(hi, Pw.max(0))
    print("节点变换后 bbox min=%s max=%s size=%s" % (
        np.round(lo, 4).tolist(), np.round(hi, 4).tolist(), np.round(hi - lo, 4).tolist()))

if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
