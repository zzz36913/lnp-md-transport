#!/usr/bin/env python3
"""XG2 单条运行判读。用法: xg2_analyze.py <rundir> <ref_T> > RESULT.txt；退出码 0=PASS 1=FAIL
读: em.log nvt.log npt.log npt_e.xvg(Temperature Density Potential Volume) rmsd.xvg grompp_*.out xg1.out
闸门阈值为 dd/22 §5 的定性判据落成的数（**拍定，非文献，K 可改**），全部列在 TH 里。
"""
import sys, re, os, math
d, T0 = sys.argv[1], float(sys.argv[2])
TH = dict(fmax_max=1000.0, dT=3.0, dens_drift=0.01, epot_drift=0.01, rmsd_step=0.3, rmsd_max=1.5)
res, ok = [], True
def gate(name, cond, msg):
    global ok
    ok &= bool(cond); res.append('%-5s %-14s %s' % ('PASS' if cond else 'FAIL', name, msg))
def rd(f):
    p = os.path.join(d, f); return open(p, errors='replace').read() if os.path.exists(p) else ''
def xvg(f):
    t, cols, leg = [], [], []
    for l in rd(f).splitlines():
        if l.startswith('@') and ' legend "' in l: leg.append(l.split('"')[1]); continue
        if not l or l[0] in '#@': continue
        v = [float(x) for x in l.split()]; t.append(v[0]); cols.append(v[1:])
    return t, list(zip(*cols)) if cols else [], leg
def mean(v): return sum(v)/len(v) if v else float('nan')
for st in ('em', 'nvt', 'npt'):
    g = rd('grompp_%s.out' % st)
    nw = len(re.findall(r'^WARNING', g, re.M)); q = re.findall(r'non-zero total charge: ([-0-9.]+)', g)
    gate('grompp_' + st, g and nw == 0 and not q and 'Fatal error' not in g, 'warnings=%d qtot=%s' % (nw, q[0] if q else '0'))
x = rd('xg1.out'); gate('xg1_check', re.search(r'^XG1 \S+ PASS', x, re.M), (x.strip().splitlines() or ['missing'])[-1][-90:])
em = rd('em.log'); m = re.search(r'Maximum force\s*=\s*([0-9.eE+-]+)', em)
fm = float(m.group(1)) if m else float('nan')
gate('em_fmax', m and math.isfinite(fm) and fm < TH['fmax_max'], 'Fmax=%s（deploy 标准水盒预跑参考 91）' % (m.group(1) if m else 'n/a'))
for st in ('nvt', 'npt'):
    L = rd(st + '.log')
    lw = len(re.findall(r'LINCS WARNING', L)); nan = len(re.findall(r'\bnan\b', L, re.I))
    fin = 'Finished mdrun' in L
    perf = re.search(r'Performance:\s+([0-9.]+)', L)
    gate(st + '_run', fin and lw == 0 and nan == 0, 'finished=%s LINCS_warn=%d nan=%d ns/day=%s' % (fin, lw, nan, perf.group(1) if perf else '?'))
t, c, leg = xvg('npt_e.xvg')
if c and len(t) > 10:
    tmax = t[-1]
    def win(i, a, b): return [c[i][k] for k in range(len(t)) if a <= t[k] < b or (b == tmax and t[k] == tmax)]
    h = tmax/2; q4 = tmax*0.8; q3 = tmax*0.6
    li = {n: i for i, n in enumerate(leg)}
    Ti = li.get('Temperature', 0); Tm = mean(win(Ti, h, tmax))
    gate('npt_T', abs(Tm - T0) < TH['dT'], 'T(后半)=%.2f K 目标 %.0f' % (Tm, T0))
    for key, lab, th in (('Density', 'npt_density', 'dens_drift'), ('Potential', 'npt_epot', 'epot_drift')):
        if key in li:
            a, b = mean(win(li[key], q3, q4)), mean(win(li[key], q4, tmax))
            r = abs(b - a)/abs(a) if a else float('nan')
            gate(lab, r < TH[th], '%s 末两窗均值 %.4g→%.4g 相对变化 %.2f%%（阈 %.0f%%）' % (key, a, b, 100*r, 100*TH[th]))
    if 'Volume' in li: res.append('INFO  npt_volume     起 %.1f 末 %.1f nm^3' % (c[li['Volume']][0], c[li['Volume']][-1]))
else: gate('npt_energy', False, 'npt_e.xvg 缺失或太短')
t, c, _ = xvg('rmsd.xvg')
if c and len(t) > 4:
    r = c[0]; n = len(r); a, b = mean(r[int(n*.6):int(n*.8)]), mean(r[int(n*.8):])
    gate('bb_rmsd', (b - a) < TH['rmsd_step'] and max(r) < TH['rmsd_max'], 'BB RMSD(NPT，对 EM 结构) 末=%.3f max=%.3f 末两窗 %.3f→%.3f nm' % (r[-1], max(r), a, b))
else: gate('bb_rmsd', False, 'rmsd.xvg 缺失')
print('\n'.join(res)); print('THRESHOLDS(拍定) ' + ' '.join('%s=%s' % kv for kv in TH.items()))
print('VERDICT %s' % ('PASS' if ok else 'FAIL')); sys.exit(0 if ok else 1)
