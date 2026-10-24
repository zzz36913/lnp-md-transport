#!/usr/bin/env python3
"""J006: 求 phase_counts 的 --water-wt，使【水珠 W】数 = nW/4 × (MC3+MC3H 总数)，即 nW 个水分子/MC3（1 W 珠=4 水，Martini 约定；离子不计入 nW）。
用法: wt_for_nw.py --alpha 0.5 --nw 12 --box <等体积立方盒边长> --dens 700 --ff <含 sterols/solvents/ions 的目录>
phase_counts 的 water-wt 是 水+离子 质量分数，离子会挤占 W 珠，所以必须二分求解而不能直接按 nW 换算。"""
import argparse, subprocess, sys, os
ap = argparse.ArgumentParser()
ap.add_argument('--alpha', type=float, required=True); ap.add_argument('--nw', type=float, required=True)
ap.add_argument('--box', type=float, required=True); ap.add_argument('--dens', type=float, default=700.0)
ap.add_argument('--comp', default='MC3:75,CHOL:25'); ap.add_argument('--salt', type=float, default=0.15)
ap.add_argument('--ff', required=True)
a = ap.parse_args(); here = os.path.dirname(os.path.abspath(__file__)); ph = os.path.dirname(here)
itps = [ph + '/ff/MC3.itp', ph + '/ff/MC3H.itp'] + [a.ff + '/' + f for f in ('martini_v3.0.0_sterols_v1.itp', 'martini_v3.0.0_solvents_v1.itp', 'martini_v3.0.0_ions_v1.itp')]
def ratio(wt):
    o = subprocess.run([sys.executable, ph + '/phase_counts.py', '--comp', a.comp, '--alpha', str(a.alpha), '--box', str(a.box), '--water-wt', '%.5f' % wt,
                        '--dens', str(a.dens), '--salt', str(a.salt), '--itp'] + itps, capture_output=True, text=True, check=True).stdout
    c = {l.split()[0]: int(l.split()[1]) for l in o.splitlines() if l.strip() and not l.startswith('#')}
    return 4.0 * c['W'] / (c.get('MC3', 0) + c.get('MC3H', 0)), c
lo, hi = 0.02, 0.5
for _ in range(60):
    m = (lo + hi) / 2
    r, c = ratio(m)
    if r < a.nw: lo = m
    else: hi = m
r, c = ratio((lo + hi) / 2)
print('WATER_WT=%.5f nW_actual=%.2f counts=%s' % ((lo + hi) / 2, r, c))
