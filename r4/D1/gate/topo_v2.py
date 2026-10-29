#!/usr/bin/env python3
"""analyzer_v2 核心库（零算力验证用）。只读输入，不改任何旧文件。
与旧读出器的区别（全部可单测，见 unit_tests_v2.py）：
  1. 卷绕秩：对每个连通分量，用"晶格平移整数向量"沿 BFS 树累加偏移，非树边给出卷绕向量，取其整数秩 (0-3) 及方向/法向；
     不再用 wrap_axes（"簇与自身沿某轴平移的像相连"）的轴计数近似。
  2. 完整盒矩阵：按 box 向量矩阵 H（行=a,b,c）在分数坐标里找 27 个晶格像，不假设正交；
     边的晶格偏移是整数向量，不经浮点 round。
  3. 不截断簇表（旧 phase_sq.connectivity 取 big[:8]）；
  4. 管阵对称性（六方/正方）由面内 S(q) 峰角度判定，不只靠 d_NN/a_pred 的 15% 容差。
旧实现原样导入做对照（不复制、不修改）：
  - Claude Science tools/stalk_topology_analyzer.py:tail_topology（正交盒）
  - scan/tx/ph_phase/phase_sq.py:cic/smooth/plabel/connectivity + scan/verdict_j009.py:frame_class（wrap_axes）
"""
import itertools, math, sys, importlib.util
import numpy as np
from scipy.spatial import cKDTree
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components, breadth_first_order

CS_ANALYZER = '/workspace/review_cs/Claude Science Review/tools/stalk_topology_analyzer.py'
PHASE_SQ_DIR = '/workspace/lnp-md/scan/tx/ph_phase'
SCAN_DIR = '/workspace/lnp-md/scan'

def load_cs_analyzer():
    spec = importlib.util.spec_from_file_location('cs_stalk', CS_ANALYZER); m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m); return m

def load_phase_sq():
    sys.path.insert(0, PHASE_SQ_DIR); import phase_sq; return phase_sq

# ------------------------------------------------------------------ 卷绕秩（通用，边带整数晶格偏移）
def _prim(v):
    v = np.asarray(v, dtype=np.int64); g = int(np.gcd.reduce(np.abs(v)));  v = v // max(g, 1)
    for x in v:
        if x != 0:
            if x < 0: v = -v
            break
    return tuple(int(x) for x in v)

def component_winding(n, ei, ej, ek, root):
    """边 i->j 附晶格偏移 k（j 位于 i 所在元胞 + k）。返回 (size, rank, key)：
    rank = 该分量（含 root）卷绕向量的整数秩；key = rank1 时原始方向（素向量），rank2 时法向（素向量），其余 None。"""
    ei = np.asarray(ei); ej = np.asarray(ej); ek = np.asarray(ek, dtype=np.int64).reshape(-1, 3)
    if len(ei) == 0: return 1, 0, None
    src = np.concatenate([ei, ej]); dst = np.concatenate([ej, ei]); sh = np.concatenate([ek, -ek])
    # 去重图供 scipy BFS 求前驱
    G = coo_matrix((np.ones(len(src)), (src, dst)), shape=(n, n)).tocsr()
    order, pred = breadth_first_order(G, root, directed=False, return_predecessors=True)
    size = len(order)
    key = src.astype(np.int64) * n + dst; srt = np.argsort(key, kind='stable'); ks = key[srt]
    off = np.zeros((n, 3), dtype=np.int64)
    # 树边偏移：每个非根结点 v 取 (pred[v], v) 的第一条边
    v = order[1:]; p = pred[v]
    pos = np.searchsorted(ks, p.astype(np.int64) * n + v); s_tree = sh[srt[pos]]
    o0 = [0] * n; o1 = [0] * n; o2 = [0] * n
    s0 = s_tree[:, 0].tolist(); s1 = s_tree[:, 1].tolist(); s2 = s_tree[:, 2].tolist(); vl = v.tolist(); pl = p.tolist()
    for t in range(len(vl)):
        a = vl[t]; b = pl[t]; o0[a] = o0[b] + s0[t]; o1[a] = o1[b] + s1[t]; o2[a] = o2[b] + s2[t]
    off = np.stack([np.array(o0), np.array(o1), np.array(o2)], axis=1)
    inc = np.zeros(n, bool); inc[order] = True; sel = inc[ei]          # 同分量的边（ei 在分量内则 ej 也在）
    w = off[ei[sel]] + ek[sel] - off[ej[sel]]
    w = w[np.any(w != 0, axis=1)]
    if len(w) == 0: return size, 0, None
    W = np.unique(w, axis=0); rank = int(np.linalg.matrix_rank(W.astype(float)))
    if rank == 1: return size, 1, _prim(W[0])
    if rank == 2:
        for a in range(len(W)):
            for b in range(a + 1, len(W)):
                c = np.cross(W[a], W[b])
                if np.any(c != 0): return size, 2, _prim(c)
    return size, rank, None

# ------------------------------------------------------------------ 点图（完整盒矩阵）
def box_matrix_from_dims(dims_A):
    """MDAnalysis dimensions(Å: a,b,c,alpha,beta,gamma) -> H(nm)，行为 a,b,c（GROMACS 约定 a 沿 x，b 在 xy 面）。"""
    a, b, c, al, be, ga = [float(x) for x in dims_A]; al, be, ga = map(math.radians, (al, be, ga))
    ax = np.array([a, 0, 0]); bx = np.array([b * math.cos(ga), b * math.sin(ga), 0])
    cx = c * math.cos(be); cy = c * (math.cos(al) - math.cos(be) * math.cos(ga)) / math.sin(ga)
    cz = math.sqrt(max(c * c - cx * cx - cy * cy, 0.0))
    return np.array([ax, bx, [cx, cy, cz]]) / 10.0

def perp_heights(H):
    V = abs(np.linalg.det(H)); return np.array([V / np.linalg.norm(np.cross(H[(i + 1) % 3], H[(i + 2) % 3])) for i in range(3)])

def point_edges(pos_nm, H, cutoff):
    """分数坐标折回后，在 14 个晶格像里找截断内的对；返回 (ei, ej, ek) ，边 i->j 附整数偏移 k。要求盒已约化且截断 < 最小垂直高度/2。"""
    H = np.asarray(H, float); hmin = perp_heights(H).min()
    if cutoff >= hmin / 2: raise ValueError('cutoff %.3f >= 半个最小垂直高度 %.3f，27 像不够' % (cutoff, hmin / 2))
    s = np.asarray(pos_nm, float) @ np.linalg.inv(H); s -= np.floor(s); p = s @ H
    t0 = cKDTree(p); ei = []; ej = []; ek = []
    for k in [(0, 0, 0)] + [k for k in itertools.product((-1, 0, 1), repeat=3) if k > (0, 0, 0)]:
        tk = cKDTree(p + np.array(k, float) @ H); M = t0.sparse_distance_matrix(tk, cutoff, output_type='ndarray')
        i = M['i']; j = M['j']
        if k == (0, 0, 0):
            m = i < j; i = i[m]; j = j[m]
        else:
            if np.any(i == j): raise ValueError('自像距离 < cutoff，盒太小')
        ei.append(i); ej.append(j); ek.append(np.tile(np.array(k), (len(i), 1)))
    return np.concatenate(ei), np.concatenate(ej), np.concatenate(ek)

def topology_v2(pos_nm, H, cutoff):
    """(ncl, 最大分量大小, 最大分量卷绕秩) —— 与旧 tail_topology 同含义，但用完整盒矩阵与整数晶格偏移。"""
    n = len(pos_nm); ei, ej, ek = point_edges(pos_nm, H, cutoff)
    if len(ei) == 0: return n, 1, 0
    ncl, lab = connected_components(coo_matrix((np.ones(len(ei)), (ei, ej)), shape=(n, n)), directed=False)
    sizes = np.bincount(lab); big = int(np.argmax(sizes)); root = int(np.where(lab == big)[0][0])
    size, rank, key = component_winding(n, ei, ej, ek, root)
    return int(ncl), int(sizes[big]), rank

# ------------------------------------------------------------------ 体素网格（周期 6 邻接）
def grid_edges(mask):
    n = mask.shape; idx = -np.ones(n, np.int64); m = int(mask.sum()); idx[mask] = np.arange(m)
    ei = []; ej = []; ek = []
    for ax in range(3):
        nb = np.roll(mask, -1, axis=ax); both = mask & nb
        i = idx[both]; j = np.roll(idx, -1, axis=ax)[both]
        coord = np.indices(n)[ax][both]; k = np.zeros((len(i), 3), np.int64); k[:, ax] = (coord == n[ax] - 1)
        ei.append(i); ej.append(j); ek.append(k)
    return idx, m, np.concatenate(ei), np.concatenate(ej), np.concatenate(ek)

def grid_clusters_v2(mask, min_frac=0.02, truncate=None):
    """所有 >= min_frac*mask.sum() 的簇：[{'vox','rank','key'}]，按体素数降序。truncate=None 不截断（旧法=8）。"""
    idx, m, ei, ej, ek = grid_edges(mask)
    if m == 0: return []
    ncl, lab = connected_components(coo_matrix((np.ones(len(ei)), (ei, ej)), shape=(m, m)), directed=False)
    sizes = np.bincount(lab, minlength=ncl); order = np.argsort(-sizes)
    out = []
    for c in order:
        if sizes[c] < min_frac * m: break
        root = int(np.where(lab == c)[0][0]); size, rank, key = component_winding(m, ei, ej, ek, root)
        out.append(dict(vox=int(size), rank=rank, key=key))
        if truncate and len(out) >= truncate: break
    return out

def classify_v2(cl):
    """与旧 frame_class 同类别名，但依据 (秩, 方向/法向)。"""
    if not cl: return 'OTHER'
    if any(c['rank'] == 3 for c in cl): return 'NET'
    if all(c['rank'] == 2 for c in cl) and len({c['key'] for c in cl}) == 1: return 'LAM'
    if len(cl) >= 2 and all(c['rank'] == 1 for c in cl) and len({c['key'] for c in cl}) == 1: return 'HII'
    return 'OTHER'

# ------------------------------------------------------------------ 旧法（wrap_axes），逐字等价于 phase_sq.connectivity 在 mask 上的部分
def grid_clusters_v1(mask, P):
    lab = P.plabel(mask); ids, cnt = np.unique(lab[lab >= 0], return_counts=True); order = np.argsort(-cnt)
    big = [(ids[i], cnt[i]) for i in order if cnt[i] >= 0.02 * mask.sum()]
    wraps = []
    for ax in range(3):
        m2 = np.concatenate([mask, mask], axis=ax); l2 = P.plabel(m2); n = mask.shape[ax]
        a = np.take(l2, range(n), axis=ax); bb = np.take(l2, range(n, 2 * n), axis=ax); wraps.append((a == bb) & (a >= 0))
    return [dict(vox=int(c), wrap_axes=['xyz'[ax] for ax in range(3) if wraps[ax][lab == cid].any()]) for cid, c in big[:8]], len(big)

def classify_v1(cl):
    """verdict_j009.frame_class 的分类逻辑（逐字对应 L30-39）。"""
    wr = [frozenset(c['wrap_axes']) for c in cl]
    if not cl: return 'OTHER'
    if any(len(w) == 3 for w in wr): return 'NET'
    if all(len(w) == 2 for w in wr) and len(set(wr)) == 1: return 'LAM'
    if len(cl) >= 2 and all(len(w) == 1 for w in wr) and len(set(wr)) == 1: return 'HII'
    return 'OTHER'

# ------------------------------------------------------------------ 面内对称性（管阵：六方 vs 正方）
def inplane_symmetry(proj, H2, ang_tol=6.0, rel=0.35):
    """proj: n×n 面内投影（分数网格，轴0沿 a，轴1沿 b）；H2: 2×2 面内盒向量（行=a,b, nm）。
    取第一 |q| 壳（最强非零峰所在壳 ±5%）内 S >= rel*S1 的峰，把方向角 mod 180° 聚类；3 个方向且间隔≈60° → HEX，2 个方向且≈90° → SQUARE，其余 OTHER。"""
    n = proj.shape[0]; F = np.fft.fft2(proj - proj.mean()); S = np.abs(F) ** 2
    Bt = 2 * np.pi * np.linalg.inv(H2).T                      # 行 = 倒格向量 b1*, b2*
    h = np.fft.fftfreq(n, 1.0 / n); HH, KK = np.meshgrid(h, h, indexing='ij')
    Q = HH[..., None] * Bt[0] + KK[..., None] * Bt[1]; Qn = np.linalg.norm(Q, axis=-1)
    ok = (Qn > 0) & (Qn < 2 * np.pi / 1.5)
    if not ok.any(): return 'OTHER', None, []
    idx = np.unravel_index(np.argmax(np.where(ok, S, 0)), S.shape); q1 = Qn[idx]; s1 = S[idx]
    shell = ok & (np.abs(Qn - q1) < 0.05 * q1) & (S >= rel * s1)
    ang = np.degrees(np.arctan2(Q[..., 1][shell], Q[..., 0][shell])) % 180.0
    dirs = []
    for a in sorted(ang):
        if not dirs or min(abs(a - d) for d in dirs) > ang_tol: dirs.append(a)
    if len(dirs) > 1 and abs((dirs[0] + 180.0) - dirs[-1]) <= ang_tol: dirs.pop()
    dirs = sorted(dirs); gaps = [(dirs[(i + 1) % len(dirs)] - dirs[i]) % 180.0 for i in range(len(dirs))] if dirs else []
    if len(dirs) == 3 and all(abs(g - 60) <= ang_tol for g in gaps): sym = 'HEX'
    elif len(dirs) == 2 and all(abs(g - 90) <= ang_tol for g in gaps): sym = 'SQUARE'
    else: sym = 'OTHER'
    return sym, float(q1), [round(d, 1) for d in dirs]
