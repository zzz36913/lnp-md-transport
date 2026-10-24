#!/usr/bin/env python3
"""J005 预组装起点构建器（纯标准库，宿主机无 numpy 也能跑）。
  lam : 立方盒内 NBIL 层平行双层堆叠(多层 L_alpha 起点)，各层组分随机混、上下叶均分；水/离子填层间水槽。
  hii : 倒六角柱 H_II 起点：矩形盒 Lx=NX*a, Ly=NY*a*sqrt3, Lz，2*NX*NY 根水柱(轴沿 z)，脂质头朝柱心径向排布。
分子数一律来自 counts.txt（phase_counts.py 按等体积立方盒算，与 J004 同口径），本脚本只负责放置。
放完做分子间最近邻检查(cell list)：任一对分子间珠距 < --dmin(默认 0.30 nm) 即非零退出。
用法: build_preasm.py --geom lam --counts counts.txt --tmpl ff/ --box 20 --nbil 3 --seed 1 -o sys.gro
      build_preasm.py --geom hii --counts counts.txt --tmpl ff/ --hii-a 7.5 --nx 2 --ny 1 --lz 14 --seed 1 -o sys.gro
"""
import argparse, math, random, sys, json

WATERLIKE = ('W', 'NA', 'CL')
RHO_W = 8.36   # W 珠/nm^3（Martini 水 ~ 4 水分子/珠，1 g/cm3 折算，估算）

def read_tmpl(path):
    L = open(path).read().splitlines()
    n = int(L[1].strip()); at = []
    for l in L[2:2 + n]:
        at.append((l[5:10].strip(), l[10:15].strip(), float(l[20:28]), float(l[28:36]), float(l[36:44])))
    return at

def tmpl_local(at):
    """返回 (resname, [(atomname, u, lx, ly)])：u=沿分子轴距头珠(最高 z)的距离(>=0)，lx/ly=相对 xy 质心的侧向偏移。"""
    zt = max(a[4] for a in at); cx = sum(a[2] for a in at) / len(at); cy = sum(a[3] for a in at) / len(at)
    return at[0][0], [(a[1], zt - a[4], a[2] - cx, a[3] - cy) for a in at]

class Cells:
    def __init__(s, box, c=0.5):
        s.box = box; s.n = [max(1, int(b // c)) for b in box]; s.c = [b / n for b, n in zip(box, s.n)]; s.d = {}
    def key(s, p): return tuple(int((p[i] % s.box[i]) // s.c[i]) % s.n[i] for i in range(3))
    def add(s, p, tag): s.d.setdefault(s.key(p), []).append((p, tag))
    def near(s, p, r, skip=None):
        k = s.key(p); r2 = r * r; B = s.box
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    kk = ((k[0] + dx) % s.n[0], (k[1] + dy) % s.n[1], (k[2] + dz) % s.n[2])
                    for q, t in s.d.get(kk, ()):
                        if skip is not None and t == skip: continue
                        d2 = 0.0
                        for i in range(3):
                            x = q[i] - p[i]; x -= B[i] * round(x / B[i]); d2 += x * x
                        if d2 < r2: return math.sqrt(d2), t
        return None
    def nearest(s, p, r, skip=None):
        k = s.key(p); best = None; B = s.box; r2 = r * r
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    kk = ((k[0] + dx) % s.n[0], (k[1] + dy) % s.n[1], (k[2] + dz) % s.n[2])
                    for q, t in s.d.get(kk, ()):
                        if t == skip: continue
                        d2 = 0.0
                        for i in range(3):
                            x = q[i] - p[i]; x -= B[i] * round(x / B[i]); d2 += x * x
                        if d2 < r2 and (best is None or d2 < best): best = d2
        return None if best is None else math.sqrt(best)

def split_even(counts, nbin, rng):
    """把每种分子的个数尽量均分到 nbin 个叶/柱，余数随机给。返回 [[mol,...] per bin]，每 bin 内随机打乱。"""
    bins = [[] for _ in range(nbin)]
    for mol, n in counts:
        q, r = divmod(n, nbin); extra = rng.sample(range(nbin), r)
        for b in range(nbin): bins[b] += [mol] * (q + (1 if b in extra else 0))
    for b in bins: rng.shuffle(b)
    return bins

def water_fill(region, box, nneed, lip_cells, rng, excl=0.40):
    """在 region(p)->bool 区域的立方格点上放 nneed 个水/离子珠；格距自 0.50 往下扫到够数。"""
    for a in [0.50, 0.48, 0.46, 0.44, 0.42, 0.40, 0.38, 0.36, 0.34]:
        nx = [int(b // a) for b in box]; sp = [b / n for b, n in zip(box, nx)]
        pts = []
        for i in range(nx[0]):
            for j in range(nx[1]):
                for k in range(nx[2]):
                    p = ((i + 0.5) * sp[0], (j + 0.5) * sp[1], (k + 0.5) * sp[2])
                    if region(p) and lip_cells.near(p, excl) is None: pts.append(p)
        if len(pts) >= nneed:
            rng.shuffle(pts); return pts[:nneed], a
    sys.exit('水区格点不够放 %d 个水/离子珠（最多 %d）：水层太薄或排除半径太大' % (nneed, len(pts)))

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--geom', choices=['lam', 'hii'], required=True)
    ap.add_argument('--counts', required=True); ap.add_argument('--tmpl', required=True); ap.add_argument('-o', required=True)
    ap.add_argument('--box', type=float, default=20.0); ap.add_argument('--nbil', type=int, default=3)
    ap.add_argument('--hii-a', type=float, default=7.5); ap.add_argument('--nx', type=int, default=2); ap.add_argument('--ny', type=int, default=1)
    ap.add_argument('--lz', type=float, default=14.0)
    ap.add_argument('--seed', type=int, default=1); ap.add_argument('--dmin', type=float, default=0.30)
    ap.add_argument('--info', default=None, help='写 JSON 摘要')
    a = ap.parse_args(); rng = random.Random(a.seed)
    counts = [(l.split()[0], int(l.split()[1])) for l in open(a.counts) if l.strip() and not l.startswith('#')]
    lipids = [(m, n) for m, n in counts if m not in WATERLIKE]; wat = [(m, n) for m, n in counts if m in WATERLIKE]
    T = {m: tmpl_local(read_tmpl('%s/mol_%s.gro' % (a.tmpl, m))) for m, _ in counts}
    nlip = sum(n for _, n in lipids); nwat = sum(n for _, n in wat)
    placed = {m: [] for m, _ in counts}          # mol -> list of bead coord lists
    pgid = {m: [] for m, _ in counts}            # 与 placed 平行：每个分子在 cell list 里的 id
    info = {'geom': a.geom, 'nlip': nlip, 'nwat_beads': nwat}
    st = {'cells': None, 'gid': 0, 'retry': 0, 'forced': 0}
    def insert(mol, mk):
        # 逐个放脂质：与已放珠的最近距 < dmin+0.02 就换转角/加小侧移重试(最多 60 次)，仍不行则放最好的那次并计 forced
        cells = st['cells']; best = None
        for t in range(60):
            j = 0.0 if t < 20 else 0.04 * (t - 19) ** 0.5
            xyz = mk(rng.uniform(0, 2 * math.pi), rng.uniform(-j, j), rng.uniform(-j, j))
            dm = min((cells.nearest(p, 0.5) or 9.0) for p in xyz)
            if best is None or dm > best[0]: best = (dm, xyz)
            if dm >= a.dmin + 0.02: break
            st['retry'] += 1
        if best[0] < a.dmin + 0.02: st['forced'] += 1
        for p in best[1]: cells.add(p, st['gid'])
        pgid[mol].append(st['gid']); st['gid'] += 1; placed[mol].append(best[1])

    if a.geom == 'lam':
        L = a.box; box = (L, L, L); nb = a.nbil; d = L / nb; st['cells'] = Cells(box)
        tw = nwat / RHO_W / (L * L * nb)            # 每层水厚(估算)
        tl = d - tw; zh = tl / 2 - 0.25              # 头珠离双层中面的距离
        umax = max(max(b[1] for b in T[m][1]) for m, _ in lipids)
        sc = min(1.0, (zh - 0.25) / umax)             # 尾端离中面 >= 0.25 nm
        info.update(d_spacing=round(d, 3), water_thick=round(tw, 3), head_z=round(zh, 3), tail_scale=round(sc, 3))
        bins = split_even(lipids, 2 * nb, rng)
        for b, mols in enumerate(bins):
            layer, up = divmod(b, 2); zc = (layer + 0.5) * d
            ns = math.ceil(math.sqrt(len(mols))); sp = L / ns
            sites = [((i + 0.5 + 0.5 * up) * sp, (j + 0.5 + 0.5 * up) * sp) for i in range(ns) for j in range(ns)]
            sites = rng.sample(sites, len(mols))
            sgn = 1 if up else -1
            for mol, (x0, y0) in zip(mols, sites):
                def mk(th, jx, jy, mol=mol, x0=x0, y0=y0, zc=zc, sgn=sgn):
                    c, s = math.cos(th), math.sin(th)
                    return [((x0 + jx + c * lx - s * ly) % L, (y0 + jy + s * lx + c * ly) % L, (zc + sgn * (zh - sc * u)) % L) for _, u, lx, ly in T[mol][1]]
                insert(mol, mk)
        info['apl_nm2'] = round(L * L * 2 * nb / nlip * 1.0, 3)
        def region(p):
            z = p[2] % d                                 # 层间水槽: 距双层中面 > zh+0.1
            return abs(z - d / 2) > zh + 0.10
    else:
        A = a.hii_a; Lx, Ly, Lz = a.nx * A, a.ny * A * math.sqrt(3), a.lz; box = (Lx, Ly, Lz); st['cells'] = Cells(box)
        centers = []
        for i in range(a.nx):
            for j in range(a.ny):
                centers.append((i * A, j * A * math.sqrt(3))); centers.append(((i + 0.5) * A, (j + 0.5) * A * math.sqrt(3)))
        ncyl = len(centers)
        rw = math.sqrt(nwat / RHO_W / (ncyl * math.pi * Lz))   # 水柱半径(估算)
        rh = rw + 0.25
        info.update(lattice_a=A, box=[round(Lx, 3), round(Ly, 3), Lz], ncyl=ncyl, r_water=round(rw, 3), r_head=round(rh, 3))
        def cell_edge(phi):   # 六角 Voronoi 胞边界(内切半径 a/2)沿 phi 方向的距离
            ph = ((phi + math.pi / 6) % (math.pi / 3)) - math.pi / 6   # 近邻柱在 0°,60°,... 方向
            return (A / 2) / math.cos(ph)
        bins = split_even(lipids, ncyl, rng)
        for (cx, cy), mols in zip(centers, bins):
            n = len(mols); nz = max(1, round(Lz / math.sqrt(2 * math.pi * rh * Lz / n))); nphi = math.ceil(n / nz)
            sites = [((k + 0.5 * (iz % 2)) * 2 * math.pi / nphi, (iz + 0.5) * Lz / nz) for iz in range(nz) for k in range(nphi)]
            sites = rng.sample(sites, n)
            for mol, (phi, z0) in zip(mols, sites):
                er = (math.cos(phi), math.sin(phi)); et = (-math.sin(phi), math.cos(phi))
                umax = max(b[1] for b in T[mol][1]); sc = min(1.0, (cell_edge(phi) - rh - 0.20) / umax)
                def mk(th, jx, jy, mol=mol, er=er, et=et, sc=sc, z0=z0, cx=cx, cy=cy):
                    c, s = math.cos(th), math.sin(th); xyz = []
                    for _, u, lx, ly in T[mol][1]:
                        t_, zz = c * lx - s * ly + jx, s * lx + c * ly + jy
                        r = rh + sc * u
                        xyz.append(((cx + r * er[0] + t_ * et[0]) % Lx, (cy + r * er[1] + t_ * et[1]) % Ly, (z0 + zz) % Lz))
                    return xyz
                insert(mol, mk)
        info['apl_head_nm2'] = round(ncyl * 2 * math.pi * rh * Lz / nlip, 3)
        def region(p):
            for cx, cy in centers:
                for ox in (-Lx, 0, Lx):
                    for oy in (-Ly, 0, Ly):
                        if (p[0] - cx - ox) ** 2 + (p[1] - cy - oy) ** 2 < rw * rw: return True
            return False

    # 水/离子与最终检查
    cells = st['cells']; gid = st['gid']; tags = {}
    info['place_retries'] = st['retry']; info['place_forced'] = st['forced']
    # 水/离子
    wpts, wsp = water_fill(region, box, nwat, cells, rng)
    info['water_lattice_nm'] = wsp
    i = 0
    for m, n in wat:
        for _ in range(n):
            placed[m].append([wpts[i]]); pgid[m].append(gid); cells.add(wpts[i], gid); tags[gid] = (m, len(placed[m]) - 1); gid += 1; i += 1
    # 全体系分子间最近邻
    dmin = 9e9; nbad = 0
    for m, _ in counts:
        for g, xyz in zip(pgid[m], placed[m]):
            for p in xyz:
                r = cells.nearest(p, 0.5, skip=g)   # 0.5 = cell 边长，邻域 3x3x3 覆盖
                if r is not None:
                    if r < dmin: dmin = r
                    if r < a.dmin: nbad += 1
    info['min_intermol_nm'] = round(dmin, 3); info['n_beads_below_dmin'] = nbad
    # 写 gro
    out = open(a.o, 'w'); nat = sum(len(T[m][1]) * len(placed[m]) for m, _ in counts)
    out.write('J005 preassembled %s seed=%d\n%d\n' % (a.geom, a.seed, nat))
    ai = 0; ri = 0
    for m, _ in counts:
        rn, beads = T[m]
        for xyz in placed[m]:
            ri += 1
            for (an, _, _, _), p in zip(beads, xyz):
                ai += 1
                out.write('%5d%-5s%5s%5d%8.3f%8.3f%8.3f\n' % (ri % 100000, rn, an, ai % 100000, p[0], p[1], p[2]))
    out.write('%10.5f%10.5f%10.5f\n' % box); out.close()
    info['beads'] = nat; info['molecules'] = {m: len(placed[m]) for m, _ in counts}
    ok = nbad == 0 and all(len(placed[m]) == n for m, n in counts)
    info['ok'] = ok
    s = json.dumps(info, ensure_ascii=False); print(s)
    if a.info: open(a.info, 'w').write(s + '\n')
    sys.exit(0 if ok else 3)

if __name__ == '__main__': main()
