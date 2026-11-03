# -*- coding: utf-8 -*-
"""法线/缠绕一致性检查：每个三角形几何法线（由缠绕算）与顶点法线均值是否同向。
一致率接近 0 = 该网格整体内外翻；形状正确时应该是 1.000。

非蒙皮网格先乘上用它的那个节点的世界变换（`parts` 的顶点在骨骼局部空间，节点带旋转和
非均匀缩放，不换到同一空间比较会误报）；蒙皮网格的顶点本身就在绑定姿势空间，直接用。
"""
import os
import sys
import numpy as np
from check_glb import load_glb, read_accessor, world_matrices


def check(path):
    g, blob = load_glb(path)
    world = world_matrices(g)
    # 非蒙皮网格：网格下标 -> 引用它的节点下标
    node_of_mesh = {}
    for i, nd in enumerate(g["nodes"]):
        if "mesh" in nd and "skin" not in nd:
            node_of_mesh.setdefault(nd["mesh"], i)

    print("\n==", os.path.basename(path))
    for mi, mesh in enumerate(g["meshes"]):
        prim = mesh["primitives"][0]
        attrs = prim["attributes"]
        if "NORMAL" not in attrs:
            continue
        P = read_accessor(g, blob, attrs["POSITION"]).astype(np.float64)
        N = read_accessor(g, blob, attrs["NORMAL"]).astype(np.float64)
        I = read_accessor(g, blob, prim["indices"]).astype(np.int64).reshape(-1, 3)

        space = "binding-pose"
        ni = node_of_mesh.get(mi)
        if ni is not None:
            M = world[ni][:3, :3]
            P = P @ M.T + world[ni][:3, 3]
            N = N @ np.linalg.inv(M)          # 法线用逆转置：行向量右乘 M⁻¹
            space = "world"

        a, b, c = P[I[:, 0]], P[I[:, 1]], P[I[:, 2]]
        gn = np.cross(b - a, c - a)
        ln = np.linalg.norm(gn, axis=1)
        ok = ln > 1e-12
        gn = gn[ok] / ln[ok, None]
        vn = (N[I[ok, 0]] + N[I[ok, 1]] + N[I[ok, 2]]) / 3.0
        vnl = np.linalg.norm(vn, axis=1)
        vn = vn / np.maximum(vnl, 1e-12)[:, None]
        dot = (gn * vn).sum(1)
        agree = (dot > 0).mean()
        print("  %-26s tris=%-5d 一致率=%.3f  dot均值=%+.3f  退化三角形=%d  (%s)" % (
            mesh.get("name", "?"), len(ok), agree, dot.mean(), (~ok).sum(), space))


for p in sys.argv[1:]:
    check(p)
