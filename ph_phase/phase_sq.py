#!/usr/bin/env python3
"""phase_sq.py — 三维结构因子 S(q) 判介观相（仅依赖 numpy）。

输入: 多帧或单帧 .gro（xtc 先用 `gmx trjconv -f prod.xtc -s prod.tpr -o frames.gro -dt 10000` 转；
      若装了 MDAnalysis 也可直接读 xtc：--top prod.gro --traj prod.xtc）。
选择: --sel W（默认，按 resname 选水珠）或 --names C4A,C4B（按珠名选尾端）等。
方法: 每帧把所选珠子用 CIC 撒到 n^3 网格 -> FFT -> |F(G)|^2/N，G = 2π(h/Lx,k/Ly,l/Lz)，帧平均。
判相(主): 取强峰(>= frac·最强峰，且峰/同|q|壳均值 >= contrast)，
   ① 强峰方向的维数(SVD 秩)：层状=1，六方(HII)=2，立方=3；
   ② 峰位比 q/q1 与模板匹配：LAM 1:2:3；HII 1:√3:2；Pn3m √2:√3:2；Im3m √2:2:√6；Ia3d √6:√8。
判相(辅): 平滑密度阈值化后水域连通性（周期边界下的连通簇数、最大簇沿 x/y/z 是否卷绕）。
   双连续立方：水 1–2 个簇且都三向卷绕；HII：多个水簇各沿 1 轴卷绕；层状(与盒轴对齐)：水簇各沿 2 轴卷绕。
无强峰 -> DISORDERED（各向同性/无长程序，可能是胶束/海绵相/未成相）。
自测: python3 phase_sq.py --selftest
"""
import argparse, json, math, sys
import numpy as np

TEMPL = {  # 峰位比（相对各自第一峰）
    'LAM': [1, 2, 3, 4],
    'HII': [1, math.sqrt(3), 2, math.sqrt(7), 3],
    'Pn3m': [x / math.sqrt(2) for x in (math.sqrt(2), math.sqrt(3), 2, math.sqrt(6), math.sqrt(8), 3)],
    'Im3m': [x / math.sqrt(2) for x in (math.sqrt(2), 2, math.sqrt(6), math.sqrt(8), math.sqrt(10), math.sqrt(12))],
    'Ia3d': [x / math.sqrt(6) for x in (math.sqrt(6), math.sqrt(8), math.sqrt(14), math.sqrt(16), math.sqrt(20), math.sqrt(22))],
}
DIMS = {'LAM': 1, 'HII': 2, 'Pn3m': 3, 'Im3m': 3, 'Ia3d': 3}

# ---------------- 读入 ----------------
def read_gro_frames(fn):
    with open(fn) as f:
        while True:
            title = f.readline()
            if not title: return
            n = int(f.readline())
            lines = [f.readline() for _ in range(n)]
            box = np.array(f.readline().split()[:3], float)
            res = np.array([l[5:10].strip() for l in lines]); name = np.array([l[10:15].strip() for l in lines])
            xyz = np.array([[float(l[20:28]), float(l[28:36]), float(l[36:44])] for l in lines])
            yield res, name, xyz, box

def frames(args):
    if args.traj:
        import MDAnalysis as mda  # 可选依赖
        u = mda.Universe(args.top, args.traj)
        res = np.array(u.atoms.resnames); name = np.array(u.atoms.names)
        for i, ts in enumerate(u.trajectory[args.begin::args.stride]):
            yield res, name, u.atoms.positions / 10.0, ts.dimensions[:3] / 10.0
    else:
        for i, fr in enumerate(read_gro_frames(args.gro)):
            if i >= args.begin and (i - args.begin) % args.stride == 0: yield fr

# ---------------- 核心 ----------------
def cic(xyz, box, n):
    g = np.zeros((n, n, n))
    s = (xyz / box) % 1.0 * n
    i0 = np.floor(s).astype(int); f = s - i0
    for dx in (0, 1):
        wx = f[:, 0] if dx else 1 - f[:, 0]
        for dy in (0, 1):
            wy = f[:, 1] if dy else 1 - f[:, 1]
            for dz in (0, 1):
                wz = f[:, 2] if dz else 1 - f[:, 2]
                np.add.at(g, ((i0[:, 0] + dx) % n, (i0[:, 1] + dy) % n, (i0[:, 2] + dz) % n), wx * wy * wz)
    return g

def sq_of(grid, npart):
    F = np.fft.rfftn(grid - grid.mean())
    return (np.abs(F) ** 2) / max(npart, 1)

def qvectors(box, n):
    h = np.fft.fftfreq(n, 1.0 / n); l = np.fft.rfftfreq(n, 1.0 / n)
    H, K, L = np.meshgrid(h, h, l, indexing='ij')
    Q = 2 * np.pi * np.stack([H / box[0], K / box[1], L / box[2]], -1)
    return np.stack([H, K, L], -1).astype(int), Q

def radial(S, Qn, dq):
    b = np.floor(Qn / dq).astype(int)
    m = Qn > 0
    cnt = np.bincount(b[m], minlength=b.max() + 1); tot = np.bincount(b[m], S[m], minlength=b.max() + 1)
    with np.errstate(invalid='ignore', divide='ignore'):
        I = tot / cnt
    return (np.arange(len(I)) + 0.5) * dq, I, b

def classify(S, HKL, Q, box, frac=0.08, contrast=8.0, qmax=None, tol=0.04, smin=25.0):
    Qn = np.linalg.norm(Q, axis=-1)
    dq = 2 * np.pi / max(box)
    qs, I, b = radial(S, Qn, dq)
    shell_mean = np.where(Qn > 0, I[np.minimum(b, len(I) - 1)], np.inf)
    qmax = qmax or 2 * np.pi / 1.5  # 只看 d > 1.5 nm 的介观尺度峰
    ok = (Qn > 0) & (Qn < qmax)
    smax = S[ok].max()
    strong = ok & (S >= frac * smax) & (S >= contrast * shell_mean) & (S >= smin)  # smin: 理想气体 S~1(指数分布)，25 排除噪声峰
    idx = np.argwhere(strong)
    peaks = sorted([(float(Qn[tuple(i)]), float(S[tuple(i)]), tuple(int(x) for x in HKL[tuple(i)]), Q[tuple(i)]) for i in idx],
                   key=lambda p: -p[1])
    out = {'n_strong': len(peaks), 'smax': float(smax)}
    if not peaks:
        out.update(phase='DISORDERED', reason='无满足强度/衬度阈值的 Bragg 峰'); return out, (qs, I)
    q1 = min(p[0] for p in peaks)
    out['q1'] = q1; out['d1_nm'] = 2 * np.pi / q1
    # 方向维数（只用低阶峰 q<2.05 q1，避免高阶谐波噪声）
    V = np.array([p[3] / p[0] for p in peaks if p[0] < 2.05 * q1])
    sv = np.linalg.svd(np.vstack([V, -V]), compute_uv=False)
    dims = int((sv / sv[0] > 0.35).sum())
    out['dims'] = dims; out['sv'] = [round(float(x), 3) for x in sv]
    # 去重峰位比
    rat = sorted(set(round(p[0] / q1, 3) for p in peaks))
    out['ratios'] = rat
    out['peaks_top'] = [{'q': round(p[0], 3), 'S': round(p[1], 2), 'hkl': p[2]} for p in peaks[:12]]
    scores, errs = {}, {}
    for name, t in TEMPL.items():
        e = [min(abs(r - x) / x for x in t) for r in rat]
        miss = [x for x in e if x > tol]                                   # 观测比值不在模板里
        need = t[1:2] if len(rat) > 1 else []                             # 有多峰时要求模板第二峰出现
        lack = [x for x in need if min(abs(r - x) / x for r in rat) > tol]
        scores[name] = len(miss) + len(lack) + (0 if DIMS[name] == dims else 2)
        errs[name] = sum(min(x, tol) for x in e)
    out['template_penalty'] = scores
    best = min(scores, key=lambda k: (scores[k], errs[k]))
    if len(rat) == 1:   # 只有一阶峰：只能靠方向维数
        out['phase'] = {1: 'LAM', 2: 'HII', 3: 'CUBIC'}.get(dims, 'UNASSIGNED') + '(single-order)'
    elif scores[best] == 0:
        out['phase'] = best
    elif dims == 3:
        out.update(phase='CUBIC(unassigned)', best_guess=best, reason='三维强峰但峰位比与 Pn3m/Im3m/Ia3d 模板不完全符合')
    else:
        out.update(phase='UNASSIGNED', best_guess=best, reason='有强峰但与模板不符（共存/过渡/晶胞与盒子不匹配）')
    out['nonlamellar'] = out['phase'].split('(')[0] not in ('LAM', 'DISORDERED')
    return out, (qs, I)

# ---------------- 辅判据：周期连通性 ----------------
def smooth(grid, box, sigma):
    n = grid.shape[0]
    kx = np.fft.fftfreq(n, box[0] / n) * 2 * np.pi; ky = np.fft.fftfreq(n, box[1] / n) * 2 * np.pi; kz = np.fft.rfftfreq(n, box[2] / n) * 2 * np.pi
    KX, KY, KZ = np.meshgrid(kx, ky, kz, indexing='ij')
    return np.fft.irfftn(np.fft.rfftn(grid) * np.exp(-0.5 * sigma ** 2 * (KX ** 2 + KY ** 2 + KZ ** 2)), s=grid.shape, axes=(0, 1, 2))

def plabel(mask):
    """周期边界连通标记（6 邻接），标签传播。"""
    lab = np.where(mask, np.arange(mask.size).reshape(mask.shape), -1).astype(np.int64)
    BIG = mask.size + 1
    while True:
        cur = np.where(mask, lab, BIG)
        new = cur.copy()
        for ax in range(3):
            for s in (1, -1):
                new = np.minimum(new, np.roll(cur, s, ax))
        new = np.where(mask, new, BIG)
        if np.array_equal(new, cur): break
        lab = np.where(mask, new, -1)
    return np.where(mask, lab, -1)

def connectivity(grid, box, sigma=0.5, thr=1.0):
    g = smooth(grid, box, sigma)
    mask = g > thr * g.mean()
    out = {'water_vox_frac': round(float(mask.mean()), 3)}
    lab = plabel(mask)
    ids, cnt = np.unique(lab[lab >= 0], return_counts=True)
    order = np.argsort(-cnt)
    big = [(ids[i], cnt[i]) for i in order if cnt[i] >= 0.02 * mask.sum()]
    out['n_clusters'] = len(big)
    wraps = []
    for ax in range(3):
        m2 = np.concatenate([mask, mask], axis=ax); l2 = plabel(m2)
        n = mask.shape[ax]
        a = np.take(l2, range(n), axis=ax); bb = np.take(l2, range(n, 2 * n), axis=ax)
        wraps.append((a == bb) & (a >= 0))
    out['clusters'] = []
    for cid, c in big[:8]:
        sel = lab == cid
        out['clusters'].append({'vox': int(c), 'wrap_axes': [ 'xyz'[ax] for ax in range(3) if wraps[ax][sel].any()]})
    return out

# ---------------- 主程序 ----------------
# J005：追踪预组装起始晶格的指定反射(hkl 以当前盒为基，盒形变时指数不变)。背景 = 同 |q| 壳层除去所列反射(及其 -hkl)的均值。
# v1 classify 在小盒(2×1 六方胞)里因 6 个等价 (10) 峰占满壳层而判 DISORDERED；此项只回答「起始反射是否仍在」，不做全局搜峰，故不会引入盒相称假峰。
def track_hkl(S, HKL, Q, box, spec, frac=0.08, contrast=8.0, smin=25.0):
    Qn = np.linalg.norm(Q, axis=-1); dq = 2 * np.pi / max(box); b = np.floor(Qn / dq).astype(int)
    n = S.shape[0]; want = [tuple(int(x) for x in t.split(',')) for t in spec.split(';') if t.strip()]
    def idx(h, k, l):
        if l < 0: h, k, l = -h, -k, -l
        if l >= S.shape[2]: return None
        return (h % n, k % n, l)
    sel = [idx(*w) for w in want]; mask = np.zeros(S.shape, bool)
    for w in want:   # 反射与其 -hkl 都排除出背景（l=0 平面上二者是 rfft 网格中不同的点）
        for t in (idx(*w), idx(-w[0], -w[1], -w[2])):
            if t is not None: mask[t] = True
    ok = (Qn > 0) & (Qn < 2 * np.pi / 1.5); smax = float(S[ok].max()); res = []
    for w, t in zip(want, sel):
        if t is None: res.append({'hkl': w, 'error': 'out of grid'}); continue
        sh = (b == b[t]) & (Qn > 0) & ~mask
        bg = float(S[sh].mean()) if sh.sum() else float('nan')
        sv = float(S[t]); c = sv / bg if bg > 0 else float('inf')
        res.append({'hkl': w, 'q': round(float(Qn[t]), 3), 'S': round(sv, 2), 'bg': round(bg, 2), 'contrast': round(c, 1),
                    'n_bg': int(sh.sum()), 'strong': bool(sv >= smin and sv >= frac * smax and c >= contrast)})
    return {'reflections': res, 'n_strong': sum(r.get('strong', False) for r in res), 'n': len(res), 'smax': round(smax, 2)}

def analyze(args):
    acc = None; nf = 0; boxes = []; gacc = None
    for res, name, xyz, box in frames(args):
        if args.names: m = np.isin(name, args.names.split(','))
        else: m = np.isin(res, args.sel.split(','))
        p = xyz[m]
        g = cic(p, box, args.grid)
        s = sq_of(g, len(p))
        acc = s if acc is None else acc + s
        gacc = g if gacc is None else gacc + g
        boxes.append(box); nf += 1
    if not nf: sys.exit('没有读到帧')
    box = np.mean(boxes, 0); S = acc / nf
    HKL, Q = qvectors(box, args.grid)
    out, (qs, I) = classify(S, HKL, Q, box, args.frac, args.contrast)
    out.update(frames=nf, box_nm=[round(float(x), 3) for x in box], npart=int(m.sum()), selection=args.names or args.sel)
    if args.hkl: out['hkl_track'] = track_hkl(S, HKL, Q, box, args.hkl, args.frac, args.contrast)
    if args.conn: out['connectivity'] = connectivity(gacc / nf, box)
    if args.sq_out:
        np.savetxt(args.sq_out, np.c_[qs, I], header='q(1/nm) S(q) radial average', fmt='%.5f')
    return out

def synth(kind, L=14.0, n_part=60000, seed=1):
    rng = np.random.default_rng(seed)
    pts = rng.uniform(0, 1, (n_part * 4, 3)) * L
    k = 2 * np.pi
    if kind == 'LAM':      # 水层，周期 L/3 沿 z
        d = L / 3; keep = np.cos(k * pts[:, 2] / d) > 0.4; box = np.array([L, L, L])
    elif kind == 'LAMtilt':  # 层法向 (1,1,0)
        d = L / 3 / math.sqrt(2); keep = np.cos(k * (pts[:, 0] + pts[:, 1]) / (L / 3)) > 0.4; box = np.array([L, L, L])
    elif kind in ('HII', 'HIIsmall'):    # 水柱沿 z，六方晶格 a，矩形盒 Lx=3a, Ly=2*sqrt3*a；HIIsmall = J005 POS_HII 的 2×1 胞(a=8)
        if kind == 'HII': a = L / 3; box = np.array([3 * a, 2 * math.sqrt(3) * a, L])
        else: a = 8.0; box = np.array([2 * a, math.sqrt(3) * a, 12.3])
        pts = rng.uniform(0, 1, (n_part * 4, 3)) * box
        x, y = pts[:, 0], pts[:, 1]; r2 = np.full(len(pts), 1e9)
        for i in range(-1, 5):
            for j in range(-1, 5):
                for (ox, oy) in ((0, 0), (a / 2, a * math.sqrt(3) / 2)):
                    cx, cy = i * a + ox, j * a * math.sqrt(3) + oy
                    r2 = np.minimum(r2, (x - cx) ** 2 + (y - cy) ** 2)
        keep = r2 < (0.3 * a) ** 2
    elif kind in ('Im3m', 'Pn3m', 'Ia3d'):  # 双连续：水在节面两侧(两套通道)，脂在节面附近
        a = L / 2; X, Y, Z = (k * pts / a).T; box = np.array([L, L, L])
        if kind == 'Im3m': f = np.cos(X) + np.cos(Y) + np.cos(Z); t = 0.9
        elif kind == 'Pn3m': f = (np.sin(X) * np.sin(Y) * np.sin(Z) + np.sin(X) * np.cos(Y) * np.cos(Z) + np.cos(X) * np.sin(Y) * np.cos(Z) + np.cos(X) * np.cos(Y) * np.sin(Z)); t = 0.45
        else: f = np.sin(X) * np.cos(Y) + np.sin(Y) * np.cos(Z) + np.sin(Z) * np.cos(X); t = 0.6
        keep = np.abs(f) > t
    else:
        keep = np.ones(len(pts), bool); box = np.array([L, L, L])
    p = pts[keep][:n_part]
    return p + rng.normal(0, 0.15, p.shape), box

def selftest():
    """必过: LAM / 倾斜LAM / HII / 随机(无序)。立方: 合成水平集模型的峰强依赖阈值，只要求判出三维非层状(维数=3)。"""
    must = {'LAM': 'LAM', 'LAMtilt': 'LAM', 'HII': 'HII', 'RAND': 'DISORDERED'}
    cubic = ['Pn3m', 'Ia3d', 'Im3m']
    ok = True
    for kind in list(must) + cubic:
        p, box = synth(kind)
        g = cic(p, box, 64); S = sq_of(g, len(p)); HKL, Q = qvectors(box, 64)
        out, _ = classify(S, HKL, Q, box)
        conn = connectivity(g, box) if kind in ('LAM', 'HII', 'Im3m') else None
        if kind in must:
            good = out['phase'].split('(')[0] == must[kind]; exp = must[kind]
        else:
            good = out.get('dims') == 3 and out['nonlamellar']; exp = 'dims=3,非层状(类型=加分)'
        ok &= good
        print('%-8s expect=%-22s got=%-18s dims=%s ratios=%s %s %s' % (kind, exp, out['phase'], out.get('dims'), out.get('ratios', [])[:6],
              'PASS' if good else 'FAIL', ('conn=' + json.dumps({'n': conn['n_clusters'], 'wrap': [c['wrap_axes'] for c in conn['clusters'][:3]]})) if conn else ''))
    for kind, want in (('HIIsmall', 3), ('RAND', 0)):   # --hkl 追踪：小盒 HII 的 (10) 族须 3/3 strong；随机须 0
        p, box = synth(kind) if kind == 'HIIsmall' else synth('RAND', L=16.0)
        g = cic(p, box, 64); S = sq_of(g, len(p)); HKL, Q = qvectors(box, 64)
        tr = track_hkl(S, HKL, Q, box, '2,1,0;2,-1,0;0,2,0'); good = tr['n_strong'] == want; ok &= good
        print('%-8s --hkl (10)族 strong=%d/3 expect=%d %s' % (kind, tr['n_strong'], want, 'PASS' if good else 'FAIL'))
    print('SELFTEST', 'PASS' if ok else 'FAIL')
    return ok

if __name__ == '__main__':
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('gro', nargs='?'); ap.add_argument('--top'); ap.add_argument('--traj')
    ap.add_argument('--sel', default='W', help='resname 列表，逗号分隔（默认 W）')
    ap.add_argument('--names', help='按珠名选，如 C4A,C4B（覆盖 --sel）')
    ap.add_argument('--grid', type=int, default=64); ap.add_argument('--begin', type=int, default=0); ap.add_argument('--stride', type=int, default=1)
    ap.add_argument('--frac', type=float, default=0.08); ap.add_argument('--contrast', type=float, default=8.0)
    ap.add_argument('--conn', action='store_true', help='同时算水域连通性（辅判据）')
    ap.add_argument('--sq-out'); ap.add_argument('--selftest', action='store_true')
    ap.add_argument('--hkl', help='追踪指定反射，如 "2,1,0;2,-1,0;0,2,0"（J005 POS_HII 起始 (10) 族）')
    a = ap.parse_args()
    if a.selftest: sys.exit(0 if selftest() else 1)
    if not (a.gro or a.traj): ap.error('需要 gro 或 --top/--traj')
    print(json.dumps(analyze(a), ensure_ascii=False, indent=1))
