# -*- coding: utf-8 -*-
"""Unity Mesh reader (raw m_VertexData + channels) + skinned bind-pose evaluation.

Unity channel formats:
 0 Float32, 1 Float16, 2 UNorm8, 3 SNorm8, 4 UNorm16, 5 SNorm16,
 6 UInt8, 7 SInt8, 8 UInt16, 9 SInt16, 10 UInt32, 11 SInt32
Vertex channel meaning (index -> name): 0 pos, 1 normal, 2 color, 3 uv0, 4 uv1,
 5 tangent, 6 uv2, 7 uv3, 8 uv4, 9 uv5, 10 uv6, 11 uv7, 12 blendweight, 13 blendindex
"""
import numpy as np

FMT = {0: ("f4", 1), 1: ("f2", 1), 2: ("u1", 1 / 255.0), 3: ("i1", 1 / 127.0),
       4: ("u2", 1 / 65535.0), 5: ("i2", 1 / 32767.0), 6: ("u1", 1), 7: ("i1", 1),
       8: ("u2", 1), 9: ("i2", 1), 10: ("u4", 1), 11: ("i4", 1)}

CH_NAMES = {0: "pos", 1: "normal", 2: "color", 3: "uv0", 4: "uv1", 5: "tangent",
            6: "uv2", 7: "uv3", 8: "uv4", 9: "uv5", 10: "uv6", 11: "uv7",
            12: "blendweight", 13: "blendindex"}


def _itemsize(fmt):
    return np.dtype(fmt).itemsize


def read_mesh(md):
    """md = mesh typetree dict. Returns dict of numpy arrays + submeshes."""
    vd = md["m_VertexData"]
    n = vd["m_VertexCount"]
    chans = vd["m_Channels"]
    data = bytes(vd["m_DataSize"])

    # group channels per stream and compute stride
    streams = {}
    for ci, ch in enumerate(chans):
        dim = ch.get("dimension", 0)
        if not dim:
            continue
        streams.setdefault(ch["stream"], []).append((ci, ch["offset"], ch["format"], dim))

    # Unity stores streams back to back; stride = aligned max(offset+size)
    stride = {}
    for s, items in streams.items():
        end = max(off + dim * _itemsize(FMT[fmt][0]) for _, off, fmt, dim in items)
        stride[s] = (end + 3) & ~3  # align 4

    # Unity 每个顶点流块的起点按 16 字节对齐（实测 m.head: 24+12+4 字节/顶点，
    # 数据总长比 n*(24+12+4) 多出 8 字节就是这一次对齐造成的）
    base = {}
    acc = 0
    for s in sorted(streams):
        acc = (acc + 15) & ~15
        base[s] = acc
        acc += stride[s] * n

    out = {}
    for s, items in streams.items():
        for ci, off, fmt, dim in items:
            dt, mul = FMT[fmt]
            arr = np.empty((n, dim), dtype=np.float64)
            esz = _itemsize(dt)
            raw = np.frombuffer(data, dtype=np.uint8)
            for v in range(n):
                start = base[s] + v * stride[s] + off
                vals = np.frombuffer(data[start:start + esz * dim], dtype=dt).astype(np.float64)
                arr[v] = vals
            if mul != 1:
                arr *= mul
            out[CH_NAMES.get(ci, "ch%d" % ci)] = arr

    # --- 兼容两种索引缓冲形态（新版本 UnityPy 给 bytearray，旧版给 list） ---
    ib = md["m_IndexBuffer"]
    if isinstance(ib, (bytes, bytearray)):
        ib_bytes = bytes(ib)
    else:
        ib_bytes = bytes((x & 0xFF) for x in ib)
    dt = np.uint16 if md.get("m_IndexFormat", 0) == 0 else np.uint32
    idx = np.frombuffer(ib_bytes, dtype=dt)

    subs = []
    for sm in md["m_SubMeshes"]:
        first = sm["firstByte"] // (2 if dt is np.uint16 else 4)
        cnt = sm["indexCount"]
        subs.append({"start": int(first), "count": int(cnt),
                     "topology": sm["topology"], "baseVertex": sm["baseVertex"]})
    return {"n": n, "attrs": out, "idx": idx, "subs": subs}


def _trs_to_matrix(pos, quat, scale):
    x, y, z, w = quat
    xx, yy, zz = x * x, y * y, z * z
    xy, xz, yz = x * y, x * z, y * z
    wx, wy, wz = w * x, w * y, w * z
    m = np.array([
        [1 - 2 * (yy + zz), 2 * (xy - wz), 2 * (xz + wy), 0.0],
        [2 * (xy + wz), 1 - 2 * (xx + zz), 2 * (yz - wx), 0.0],
        [2 * (xz - wy), 2 * (yz + wx), 1 - 2 * (xx + yy), 0.0],
        [0.0, 0.0, 0.0, 1.0]])
    m[:3, 0] *= scale[0]
    m[:3, 1] *= scale[1]
    m[:3, 2] *= scale[2]
    m[:3, 3] = pos
    return m


def matrix_from_typetree(m):
    """Unity 4x4: e00..e33 row-major (rows are e00..e03, e10..e13, ...)."""
    return np.array([[m["e%d%d" % (r, c)] for c in range(4)] for r in range(4)],
                    dtype=np.float64)
