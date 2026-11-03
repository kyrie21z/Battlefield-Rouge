# -*- coding: utf-8 -*-
"""SUPERHOT 红晶体敌人 -> Godot 可用 glTF(GLB) 导出。

输出三份：
  1. red_crystal_enemy_rigged.glb  骨骼 + 蒙皮（Skeleton3D，可动画）
  2. red_crystal_enemy_static.glb  合并成单网格（绑定姿势烘焙，无骨骼）
  3. red_crystal_enemy_parts.glb   11 个刚体部件，各自以主骨为枢轴（碎裂/断肢用）

坐标：Unity 左手 Y-up +Z 前 -> glTF/Godot 右手 Y-up -Z 前（z 取反，三角环绕反向）。
单位：米（骨骼世界矩阵本身已是米，网格绑定姿势由 bindpose 负责换算）。

用法：
    python tools/crystal_enemy/export_crystal_to_glb.py --root <SH_Data 目录>
    SUPERHOT_DATA=<SH_Data 目录> python tools/crystal_enemy/export_crystal_to_glb.py

依赖：UnityPy（实测 1.25.4）、numpy。`unitymesh` / `glb_writer` 是本目录里的纯 Python 实现，
不进 pip。重导出的 GLB 与仓库内文件逐字节一致，可以用 `tools/crystal_enemy/check_glb.py` 复核。
"""
import argparse
import json
import math
import os
import sys
from pathlib import Path

import numpy as np
import UnityPy
import unitymesh as um
from glb_writer import Writer

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]


def parse_args(argv=None):
    p = argparse.ArgumentParser(description="从 Unity 版 SUPERHOT 导出红晶体敌人（EnemyMimic）为 glTF/GLB。")
    p.add_argument("--root", default=os.environ.get("SUPERHOT_DATA", ""),
                   help="SH_Data 目录（含 resources.assets），或设环境变量 SUPERHOT_DATA。")
    p.add_argument("--out", default=str(REPO / "assets" / "models" / "characters"),
                   help="GLB 输出目录，默认本仓库的 assets/models/characters。")
    p.add_argument("--report-dir", default=str(HERE / "_out"),
                   help="内部校验文件（_joint_expect.json / _export_report.json）输出目录，默认本目录 _out。")
    return p.parse_args(argv)


ARGS = parse_args()
ROOT = ARGS.root
OUT_DIR = ARGS.out
REPORT_DIR = ARGS.report_dir
if not ROOT:
    sys.exit("需要 --root <SH_Data 目录>，或设环境变量 SUPERHOT_DATA")
os.makedirs(OUT_DIR, exist_ok=True)
os.makedirs(REPORT_DIR, exist_ok=True)

env = UnityPy.load(os.path.join(ROOT, "resources.assets"))
OBJ = {o.path_id: o for o in env.objects}

def nm(x):
    try:
        return x.peek_name()
    except Exception:
        return None

def comps(go):
    out = []
    for cp in go.m_Component:
        c = getattr(cp, "component", cp)
        try:
            out.append(c.deref())
        except Exception:
            pass
    return out

def go_name(go_oreader):
    return nm(go_oreader)

_WORLD = {}
def world_matrix(tr_o):
    """4x4 世界矩阵（缓存，按链上溯）。"""
    if tr_o.path_id in _WORLD:
        return _WORLD[tr_o.path_id]
    t = tr_o.read()
    lp, lq, ls = t.m_LocalPosition, t.m_LocalRotation, t.m_LocalScale
    local = um._trs_to_matrix((lp.x, lp.y, lp.z), (lq.x, lq.y, lq.z, lq.w),
                              (ls.x, ls.y, ls.z))
    if t.m_Father.m_PathID == 0:
        M = local
    else:
        M = world_matrix(t.m_Father.deref()) @ local
    _WORLD[tr_o.path_id] = M
    return M

# ---------------- 找 EnemyMimic ----------------
root_go = None
for o in env.objects:
    if o.type.name == "GameObject" and nm(o) == "EnemyMimic":
        root_go = o
        break
assert root_go is not None, "EnemyMimic not found"

def transform_of(go_o):
    for c in comps(go_o.read()):
        if c.type.name in ("Transform", "RectTransform"):
            return c
    return None

root_tr = transform_of(root_go)
root_inv = np.linalg.inv(world_matrix(root_tr))

parts = []   # (go_name, transform_o, smr_o)
def walk(tr_o):
    go = tr_o.read().m_GameObject.deref()
    for c in comps(go.read()):
        if c.type.name == "SkinnedMeshRenderer":
            parts.append((go_name(go), tr_o, c))
    t = tr_o.read()
    for ch in t.m_Children:
        walk(ch.deref())
walk(root_tr)
print("parts:", len(parts))

# ---------------- 关节（骨骼）采集 ----------------
joint_trs = []           # Transform ObjectReader 顺序表
joint_index = {}         # path_id -> 索引
joint_bind = {}          # path_id -> bindpose 4x4（未镜像）

def reg_joint(tr_o):
    if tr_o.path_id not in joint_index:
        joint_index[tr_o.path_id] = len(joint_trs)
        joint_trs.append(tr_o)

part_data = []
for gname, tr_o, smr in parts:
    r = smr.read()
    mesh_o = r.m_Mesh.deref()
    md = mesh_o.read_typetree()
    m = um.read_mesh(md)
    bones = [b.deref() for b in r.m_Bones]
    bps = [um.matrix_from_typetree(bp) for bp in md["m_BindPose"]]
    for i, b in enumerate(bones):
        reg_joint(b)
        if b.path_id not in joint_bind and i < len(bps):
            joint_bind[b.path_id] = bps[i]
    part_data.append({"name": gname, "mesh_name": md["m_Name"], "mesh_pid": mesh_o.path_id,
                      "md": md, "m": m, "bones": bones, "bps": bps, "tr": tr_o})
    print("  %-14s mesh=%-14s v=%-5d tris=%-5d bones=%s" % (
        gname, md["m_Name"], m["n"], len(m["idx"]) // 3,
        [nm(b.read().m_GameObject.deref()) for b in bones]))

# 关节父链补全（保证节点树完整：rig/root/Hips 等中间节点也要进节点表）
extra_chain = []
for b in joint_trs:
    cur = b
    chain = []
    while True:
        t = cur.read()
        if t.m_Father.m_PathID == 0:
            break
        par = t.m_Father.deref()
        # 到 EnemyMimic 根为止
        pgo = par.read().m_GameObject.deref()
        if pgo.path_id == root_go.path_id:
            break
        if par.path_id not in joint_index:
            chain.append(par)
        cur = par
    for c in reversed(chain):
        extra_chain.append(c)
for c in extra_chain:
    reg_joint(c)
print("joints:", len(joint_trs))

# ---------------- 镜像（z 反号）----------------
S4 = np.diag([1.0, 1.0, -1.0, 1.0])

def mirror_mat(M):
    return S4 @ M @ S4

def local_trs(tr_o):
    t = tr_o.read()
    lp, lq, ls = t.m_LocalPosition, t.m_LocalRotation, t.m_LocalScale
    return np.array([lp.x, lp.y, lp.z]), np.array([lq.x, lq.y, lq.z, lq.w]), np.array([ls.x, ls.y, ls.z])

def mirror_trs(p, q, s):
    p2 = np.array([p[0], p[1], -p[2]])
    q2 = np.array([q[0], q[1], -q[2], -q[3]])
    n = np.linalg.norm(q2)
    if n > 1e-8:
        q2 = q2 / n
    s2 = np.array([s[0], s[1], s[2]])
    return p2, q2, s2

def mesh_arrays(pd):
    m = pd["m"]
    pos = m["attrs"]["pos"].astype(np.float64)
    nrm = m["attrs"].get("normal")
    nrm = nrm.astype(np.float64) if nrm is not None else None
    W = m["attrs"].get("blendweight")
    I = m["attrs"].get("blendindex")
    n = len(pos)
    if W is None and I is not None:
        W = np.ones((n, I.shape[1]), dtype=np.float64)
    idx = m["idx"].astype(np.int64)
    return pos, nrm, W, I, idx, n

def tri_indices(pd, idx):
    """只支持 topology 0（三角面）。多子网格顺序拼接。"""
    out = []
    for sm in pd["m"]["subs"]:
        assert sm["topology"] == 0, "unsupported topology"
        out.append(idx[sm["start"]:sm["start"] + sm["count"]])
    cat = np.concatenate(out)
    # 镜像后环绕反向
    tri = cat.reshape(-1, 3)[:, ::-1]
    return tri.reshape(-1).astype(np.uint32)

# 绑定姿势下发顶点（用于 static/parts 版本）
def skinned_vertices(pd):
    pos, nrm, W, I, idx, n = mesh_arrays(pd)
    skin = []
    for i, b in enumerate(pd["bones"]):
        # 顺序：先到模型空间(root_inv)，再骨骼世界，再 bindpose
        skin.append(root_inv @ world_matrix(b) @ pd["bps"][i])
    v = np.concatenate([pos, np.ones((n, 1))], axis=1)
    out = np.zeros((n, 3))
    nout = np.zeros((n, 3))
    wsum = np.zeros(n)
    for k in range(W.shape[1]):
        w = W[:, k]
        ii = np.clip(I[:, k].astype(int), 0, len(skin) - 1)
        for bi in np.unique(ii):
            sel = ii == bi
            if not sel.any():
                continue
            M = skin[bi]
            out[sel] += w[sel, None] * (v[sel] @ M[:3, :].T)
            if nrm is not None:
                R = M[:3, :3]
                try:
                    NT = np.linalg.inv(R).T
                except np.linalg.LinAlgError:
                    NT = R
                nout[sel] += w[sel, None] * (nrm[sel] @ NT.T)
            wsum[sel] += w[sel]
    bad = wsum < 1e-4
    if bad.any():
        out[bad] = pos[bad]
        if nrm is not None:
            nout[bad] = nrm[bad]
    if nrm is not None:
        ln = np.linalg.norm(nout, axis=1, keepdims=True)
        nout = np.divide(nout, np.maximum(ln, 1e-9))
    return out, nout, tri_indices(pd, idx)

# ---------------- 材质 ----------------
def srgb_to_linear(c):
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

mats = {}
for o in env.objects:
    if o.type.name == "Material":
        n = nm(o)
        if n in ("MAIN RedCrystalNuEnemyMaterial",
                 "MAIN RedCrystalNuEnemyMaterial FOVINDEPENDENT",
                 "MAIN RedCrystalNuEnemyMaterial GLOWING"):
            md = o.read_typetree()
            cols = {}
            for it in md.get("m_SavedProperties", {}).get("m_Colors") or []:
                k = it.get("first") if isinstance(it, dict) else it[0]
                v = it.get("second") if isinstance(it, dict) else it[1]
                cols[k] = v
            mats[n] = cols

base = mats.get("MAIN RedCrystalNuEnemyMaterial", {})
c_color = base.get("_Color", {"r": 0.72, "g": 0.0, "b": 0.0, "a": 1.0})
c_emis = base.get("_EmissionColor", {"r": 0.52, "g": 0.0, "b": 0.0, "a": 1.0})
c_spec = base.get("_SpecColor", {"r": 1.0, "g": 0.186, "b": 0.0, "a": 1.0})

# Unity 颜色是 gamma 空间(_Color 直接当 sRGB 用)，glTF baseColorFactor 需要线性
base_lin = [srgb_to_linear(c_color["r"]), srgb_to_linear(c_color["g"]),
            srgb_to_linear(c_color["b"]), 1.0]
emis_lin = [srgb_to_linear(c_emis["r"]), srgb_to_linear(c_emis["g"]),
            srgb_to_linear(c_emis["b"])]
print("baseColor(linear) =", [round(x, 4) for x in base_lin])
print("emissive(linear)  =", [round(x, 4) for x in emis_lin])

# =====================================================================
# 1) rigged
# =====================================================================
w = Writer("superhot-crystal-rig-extract 1.0")
mat_idx = w.add_material("MI_RedCrystal", base_lin, metallic=0.0, roughness=0.22,
                         emissive=emis_lin, emissive_strength=1.0)

# 节点：根 -> EnemyBody -> (部件..., rig -> root -> 骨骼链)
node_of_tr = {}
def build_subtree(tr_o, parent_node):
    p, q, s = local_trs(tr_o)
    p, q, s = mirror_trs(p, q, s)
    go = tr_o.read().m_GameObject.deref()
    name = nm(go) or ("node_%d" % tr_o.path_id)
    idx = w.add_node(name, translation=p, rotation=q, scale=s)
    node_of_tr[tr_o.path_id] = idx
    if parent_node is not None:
        w.nodes[parent_node].setdefault("children", []).append(idx)
    return idx

part_node = {}
root_node = w.add_node("RedCrystal_Enemy")
w.scene_nodes = [root_node]

# EnemyBody
body_tr = None
for ch in root_tr.read().m_Children:
    t = ch.deref()
    go = t.read().m_GameObject.deref()
    if nm(go) == "EnemyBody":
        body_tr = t
if body_tr is None:
    body_tr = root_tr
body_node = build_subtree(body_tr, root_node)

# 骨骼链（从 rig 开始，逐层）——只保留"是关节或关节祖先"的节点，剪掉粒子挂点等杂物
needed = set()
for b in joint_trs:
    cur = b
    while True:
        needed.add(cur.path_id)
        t = cur.read()
        if t.m_Father.m_PathID == 0:
            break
        par = t.m_Father.deref()
        if par.path_id == root_tr.path_id:
            break
        cur = par

def build_chain(tr_o, parent_node):
    idx = build_subtree(tr_o, parent_node)
    for ch in tr_o.read().m_Children:
        ct = ch.deref()
        if ct.path_id not in needed:
            continue
        build_chain(ct, idx)
    return idx

for ch in body_tr.read().m_Children:
    t = ch.deref()
    go = t.read().m_GameObject.deref()
    if nm(go) == "rig":
        build_chain(t, body_node)

# 关节表 -> 节点索引
joint_nodes = [node_of_tr[b.path_id] for b in joint_trs]

# IBM（镜像）
ibms = []
for b in joint_trs:
    B = joint_bind.get(b.path_id)
    if B is None:
        B = np.linalg.inv(root_inv @ world_matrix(b))
    ibms.append(mirror_mat(B))
ibm_arr = np.array(ibms, dtype=np.float32)             # (J,4,4) -> 展平 MAT4

# 每部件：网格 + 蒙皮
jmap_global = {b.path_id: joint_index[b.path_id] for b in joint_trs}
for pd in part_data:
    pos, nrm, W, I, idx, n = mesh_arrays(pd)
    # 位置镜像
    pos_m = pos * np.array([1, 1, -1])
    nrm_m = nrm * np.array([1, 1, -1]) if nrm is not None else None
    # 关节索引映射到全局关节表
    remap = np.array([jmap_global[b.path_id] for b in pd["bones"]], dtype=np.int64)
    Ii = I.astype(np.int64).copy()
    Ii = remap[np.clip(Ii, 0, len(remap) - 1)]
    # 补齐到 4 影响
    def pad4(a, fill=0):
        if a.shape[1] >= 4:
            return a[:, :4]
        return np.concatenate([a, np.full((a.shape[0], 4 - a.shape[1]), fill, a.dtype)], axis=1)
    J4 = pad4(Ii).astype(np.uint16)
    W4 = pad4(W.astype(np.float64), 0.0).astype(np.float32)
    # 归一化权重
    s = W4.sum(1, keepdims=True)
    W4 = np.divide(W4, np.maximum(s, 1e-9)).astype(np.float32)

    a_pos = w.add_accessor(pos_m.astype(np.float32), type_str="VEC3", target=34962, minmax=True)
    prim = {"attributes": {"POSITION": a_pos}, "indices": None, "material": mat_idx, "mode": 4}
    if nrm_m is not None:
        prim["attributes"]["NORMAL"] = w.add_accessor(nrm_m.astype(np.float32), type_str="VEC3", target=34962)
    prim["attributes"]["JOINTS_0"] = w.add_accessor(J4, comp_type=5123, type_str="VEC4", target=34962)
    prim["attributes"]["WEIGHTS_0"] = w.add_accessor(W4, type_str="VEC4", target=34962)
    prim["indices"] = w.add_accessor(tri_indices(pd, idx), comp_type=5125, type_str="SCALAR", target=34963)
    mesh_i = w.add_mesh("MESH_%s" % pd["name"].replace(".", "_"), [prim])

    p, q, s2 = local_trs(pd["tr"])
    p, q, s2 = mirror_trs(p, q, s2)
    node = w.add_node("GEO_%s" % pd["name"].replace(".", "_"), translation=p, rotation=q,
                      scale=s2, mesh=mesh_i, skin=0)
    w.nodes[body_node].setdefault("children", []).append(node)

ibm_acc = w.add_accessor(
    np.transpose(ibm_arr, (0, 2, 1)).reshape(len(joint_trs), 16),   # glTF 矩阵列主序
    type_str="MAT4")
w.skins.append({
    "name": "Skeleton3D",
    "joints": joint_nodes,
    "inverseBindMatrices": ibm_acc,
    "skeleton": joint_nodes[0],
})
rep1 = w.save(os.path.join(OUT_DIR, "red_crystal_enemy_rigged.glb"), "RedCrystal_Enemy")
print("rigged:", rep1)

# 期望的关节世界矩阵（镜像后），用于外部校验 GLB 节点层次自洽
expect = {}
for b in joint_trs:
    Wu = root_inv @ world_matrix(b)
    Wm = mirror_mat(Wu)
    gname = nm(b.read().m_GameObject.deref()) or ("t%d" % b.path_id)
    expect["%s#%d" % (gname, b.path_id)] = {
        "node": node_of_tr[b.path_id],
        "matrix": np.round(Wm, 6).tolist(),
        "parent": (nm(b.read().m_Father.deref().read().m_GameObject.deref())
                   if b.read().m_Father.m_PathID else None),
    }
with open(os.path.join(REPORT_DIR, "_joint_expect.json"), "w", encoding="utf-8") as f:
    json.dump({"joints": expect,
               "joint_order": [nm(b.read().m_GameObject.deref()) for b in joint_trs]},
              f, ensure_ascii=False, indent=1)

# =====================================================================
# 2) static（合并单网格、绑定姿势烘焙）
# =====================================================================
w2 = Writer("superhot-crystal-static 1.0")
mat2 = w2.add_material("MI_RedCrystal", base_lin, metallic=0.0, roughness=0.22,
                       emissive=emis_lin, emissive_strength=1.0)
allpos, allnrm, alltri = [], [], []
off = 0
stats = []
for pd in part_data:
    v, nn, tri = skinned_vertices(pd)
    allpos.append(v)
    allnrm.append(nn)
    alltri.append(tri + off)
    off += len(v)
    stats.append((pd["name"], len(v), len(tri) // 3,
                  np.round(v.min(0), 3).tolist(), np.round(v.max(0), 3).tolist()))
P = np.concatenate(allpos) * np.array([1, 1, -1])
N = np.concatenate(allnrm) * np.array([1, 1, -1])
T = np.concatenate(alltri).astype(np.uint32)

a_pos = w2.add_accessor(P.astype(np.float32), type_str="VEC3", target=34962, minmax=True)
a_nrm = w2.add_accessor(N.astype(np.float32), type_str="VEC3", target=34962)
a_idx = w2.add_accessor(T, comp_type=5125, type_str="SCALAR", target=34963)
mesh2 = w2.add_mesh("MESH_RedCrystal_Enemy", [{
    "attributes": {"POSITION": a_pos, "NORMAL": a_nrm},
    "indices": a_idx, "material": mat2, "mode": 4}])
n_root = w2.add_node("RedCrystal_Enemy", mesh=mesh2)
w2.scene_nodes = [n_root]
rep2 = w2.save(os.path.join(OUT_DIR, "red_crystal_enemy_static.glb"), "RedCrystal_Enemy")
print("static:", rep2)

# =====================================================================
# 3) parts（每件以主骨为枢轴，刚体）
# =====================================================================
w3 = Writer("superhot-crystal-parts 1.0")
mat3 = w3.add_material("MI_RedCrystal", base_lin, metallic=0.0, roughness=0.22,
                       emissive=emis_lin, emissive_strength=1.0)
n3_root = w3.add_node("RedCrystal_Enemy_Parts")
w3.scene_nodes = [n3_root]
part_report = []
for pd in part_data:
    pos, nrm, W, I, idx, n = mesh_arrays(pd)
    b0 = pd["bones"][0]
    M0 = root_inv @ world_matrix(b0)
    B0 = pd["bps"][0]
    # 顶点进入骨骼局部空间，再做 z 镜像（v' = S·v），节点变换 = S·M0·S
    v = np.concatenate([pos, np.ones((n, 1))], axis=1) @ B0.T
    v = v[:, :3] * np.array([1, 1, -1])
    # 法线用逆转置：行向量右乘 M⁻¹（不是 M⁻ᵀ）。这里写错不会报错，只是明暗整体反掉，
    # 表现是 parts 版比 static 版暗一档，check_normals.py 的一致率掉到 0.3 左右。
    nt = nrm @ np.linalg.inv(B0[:3, :3]) if nrm is not None else None
    if nt is not None:
        nt = nt * np.array([1, 1, -1])
        nt = nt / np.maximum(np.linalg.norm(nt, axis=1, keepdims=True), 1e-9)
    # 节点变换 = 骨骼世界矩阵（镜像后）
    Mm = mirror_mat(M0)
    t = Mm[:3, 3]
    R = Mm[:3, :3].copy()
    sx = np.linalg.norm(R[:, 0]); sy = np.linalg.norm(R[:, 1]); sz = np.linalg.norm(R[:, 2])
    R = R / np.array([sx, sy, sz])
    # 正交化（Gram-Schmidt）
    c0 = R[:, 0]
    c1 = R[:, 1] - c0 * np.dot(c0, R[:, 1])
    c2 = np.cross(c0, c1)
    Rn = np.stack([c0, c1 / np.linalg.norm(c1), c2 / np.linalg.norm(c2)], axis=1)
    tr = np.trace(Rn)
    if tr > 0:
        s = math.sqrt(tr + 1.0) * 2
        qw = 0.25 * s
        qx = (Rn[2, 1] - Rn[1, 2]) / s
        qy = (Rn[0, 2] - Rn[2, 0]) / s
        qz = (Rn[1, 0] - Rn[0, 1]) / s
    elif Rn[0, 0] > Rn[1, 1] and Rn[0, 0] > Rn[2, 2]:
        s = math.sqrt(1.0 + Rn[0, 0] - Rn[1, 1] - Rn[2, 2]) * 2
        qw = (Rn[2, 1] - Rn[1, 2]) / s
        qx = 0.25 * s
        qy = (Rn[0, 1] + Rn[1, 0]) / s
        qz = (Rn[0, 2] + Rn[2, 0]) / s
    elif Rn[1, 1] > Rn[2, 2]:
        s = math.sqrt(1.0 + Rn[1, 1] - Rn[0, 0] - Rn[2, 2]) * 2
        qw = (Rn[0, 2] - Rn[2, 0]) / s
        qx = (Rn[0, 1] + Rn[1, 0]) / s
        qy = 0.25 * s
        qz = (Rn[1, 2] + Rn[2, 1]) / s
    else:
        s = math.sqrt(1.0 + Rn[2, 2] - Rn[0, 0] - Rn[1, 1]) * 2
        qw = (Rn[1, 0] - Rn[0, 1]) / s
        qx = (Rn[0, 2] + Rn[2, 0]) / s
        qy = (Rn[1, 2] + Rn[2, 1]) / s
        qz = 0.25 * s
    # 顶点留在骨骼局部空间（已镜像），世界位置交给节点变换 —— 不要再乘一次 Mm
    vw = v
    nw = nt

    a_pos = w3.add_accessor(vw.astype(np.float32), type_str="VEC3", target=34962, minmax=True)
    prim = {"attributes": {"POSITION": a_pos}, "indices": None, "material": mat3, "mode": 4}
    if nw is not None:
        prim["attributes"]["NORMAL"] = w3.add_accessor(nw.astype(np.float32), type_str="VEC3", target=34962)
    prim["indices"] = w3.add_accessor(tri_indices(pd, idx), comp_type=5125, type_str="SCALAR", target=34963)
    mi = w3.add_mesh("MESH_%s" % pd["name"].replace(".", "_"), [prim])
    w3.add_node("GEO_%s" % pd["name"].replace(".", "_"), translation=t, rotation=(qx, qy, qz, qw),
                scale=(sx, sy, sz), mesh=mi)
    part_report.append({"name": pd["name"], "verts": n, "tris": len(idx) // 3,
                        "pivot": [round(float(x), 4) for x in t]})
w3.nodes[n3_root]["children"] = list(range(1, len(w3.nodes)))
rep3 = w3.save(os.path.join(OUT_DIR, "red_crystal_enemy_parts.glb"), "RedCrystal_Enemy_Parts")
print("parts:", rep3)

print("\n=== static 各部件（绑定姿势，米）===")
for name, v, t, mn_, mx in stats:
    print("  %-14s v=%-5d tris=%-5d min=%s max=%s" % (name, v, t, mn_, mx))
print("\n=== 总体 bbox (glTF 右手, 米) ===")
print("  min =", np.round(P.min(0), 4).tolist())
print("  max =", np.round(P.max(0), 4).tolist())
print("  size=", np.round(P.max(0) - P.min(0), 4).tolist())
print("  verts=%d tris=%d" % (len(P), len(T) // 3))

with open(os.path.join(REPORT_DIR, "_export_report.json"), "w", encoding="utf-8") as f:
    json.dump({
        "source": "SuperHOT/SH_Data/resources.assets",
        "prefab": "EnemyMimic/EnemyBody",
        "material": {"name": "MAIN RedCrystalNuEnemyMaterial",
                     "color_unity": vars(c_color) if hasattr(c_color, "__dict__") else dict(c_color),
                     "baseColorFactor_linear": base_lin,
                     "emissiveFactor_linear": emis_lin},
        "coords": "Unity LH Y-up -> glTF RH Y-up, z negated, winding reversed, meters",
        "bbox_min": P.min(0).tolist(), "bbox_max": P.max(0).tolist(),
        "verts": int(len(P)), "tris": int(len(T) // 3),
        "parts": [{"name": s[0], "verts": s[1], "tris": s[2]} for s in stats],
        "files": {"rigged": rep1, "static": rep2, "parts": rep3},
    }, f, ensure_ascii=False, indent=1)
print("\nDONE ->", OUT_DIR)
