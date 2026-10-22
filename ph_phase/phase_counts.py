#!/usr/bin/env python3
"""按目标盒体积/密度/水质量分数/组成/α 推算各分子数（纯标准库）。
用法: phase_counts.py --comp MC3:50,CHOL:40,DSPC:10 --alpha 0.5 --box 14 --water-wt 0.30 --dens 602 --salt 0.15 --itp a.itp b.itp ...
输出: 每行 '<molname> <count>'（插入顺序：脂质 -> W -> CL -> NA），并在 stderr 打印汇总。
质量取 itp [atoms] 第 8 列；缺省按珠型 T*=36、S*=54、其余 72（Martini 3 约定）。虚位点质量 0 照计。"""
import argparse, re, sys

def masses(files):
    M, nb, cur, sec = {}, {}, None, None
    for fn in files:
        for raw in open(fn):
            l = raw.split(';')[0].strip()
            if not l or l.startswith('#'): continue
            m = re.match(r'\[\s*(\w+)\s*\]', l)
            if m:
                sec = m.group(1)
                continue
            if sec == 'moleculetype':
                cur = l.split()[0]; M[cur] = 0.0; nb[cur] = 0; sec = 'mt_done'
            elif sec == 'atoms' and cur:
                f = l.split()
                if len(f) >= 8: mass = float(f[7])
                else:
                    t = f[1]; mass = 36.0 if t.startswith('T') else 54.0 if t.startswith('S') else 72.0
                M[cur] += mass; nb[cur] += 1
    return M, nb

ap = argparse.ArgumentParser()
ap.add_argument('--comp', required=True); ap.add_argument('--alpha', type=float, default=0.0)
ap.add_argument('--box', type=float, default=14.0); ap.add_argument('--water-wt', type=float, default=0.30)
ap.add_argument('--dens', type=float, default=602.0); ap.add_argument('--salt', type=float, default=0.15)
ap.add_argument('--itp', nargs='+', required=True)
a = ap.parse_args()
M, NB = masses(a.itp)
comp = [(k, float(v)) for k, v in (x.split(':') for x in a.comp.split(','))]
tot = sum(v for _, v in comp); comp = [(k, v / tot) for k, v in comp]
for k, _ in comp + [('W', 0), ('NA', 0), ('CL', 0)]:
    if k not in M: sys.exit('moleculetype %s 不在给定 itp 中' % k)
if not 0 <= a.alpha <= 1: sys.exit('alpha 必须在 [0,1]')
if a.alpha > 0 and 'MC3' not in dict(comp): sys.exit('alpha>0 但组成里没有 MC3')
V = a.box ** 3; Mtot = V * a.dens
ML, MW = (1 - a.water_wt) * Mtot, a.water_wt * Mtot
mbar = sum(x * M[k] for k, x in comp)
Nlip = round(ML / mbar)
cnt = []
for k, x in comp:
    n = round(x * Nlip)
    if k == 'MC3':
        nh = round(a.alpha * n)
        if n - nh: cnt.append(('MC3', n - nh))
        if nh: cnt.append(('MC3H', nh))
    elif n: cnt.append((k, n))
nmc3h = dict(cnt).get('MC3H', 0)
NWtot = round(MW / M['W'])
npair = round(a.salt * NWtot * 4 / 55.5)
nW = NWtot - 2 * npair - nmc3h
if nW <= 0: sys.exit('水珠数 <= 0，检查 water-wt/salt')
cnt += [('W', nW), ('CL', npair + nmc3h), ('NA', npair)]
for k, n in cnt: print(k, n)
beads = sum(NB[k] * n for k, n in cnt)
q = nmc3h + npair - (npair + nmc3h)
lm = sum(M[k] * n for k, n in cnt if k not in ('W', 'NA', 'CL'))
wm = sum(M[k] * n for k, n in cnt if k in ('W', 'NA', 'CL'))
print('# box=%.2fnm V=%.0fnm3 Nlip=%d beads=%d lipid:water(mass)=%.1f:%.1f netq=%d MC3H=%d NaCl=%d'
      % (a.box, V, sum(n for k, n in cnt if k not in ('W', 'NA', 'CL')), beads, 100 * lm / (lm + wm), 100 * wm / (lm + wm), q, nmc3h, npair), file=sys.stderr)
