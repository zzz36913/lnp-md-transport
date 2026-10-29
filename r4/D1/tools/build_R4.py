#!/usr/bin/env python3
"""R4 D1 起点构建器 (box 上只做 EM; 不发车)。由 R3_pkg/scripts/build_R3.py 改写, 流程不变:
单层 builder(build_lam_rect.py, 原样引用) -> EM1(1000 步) -> genconf 沿 z 复制 x2 -> EM2 -> start.gro (全部片层起点, 规则3)。
改动: (1) --prim 增 MC3H(+1, 每脂配 1 个 CL) 与 MC3(中性, 无离子); MC3/MC3H 参数逐字取自 M3_Ionizable_Lipids
    Case_studies/Quantifying_stalk_formation/ff_itps/MC3_MC3H.itp (sha256 797d2cfe…11a5, repo commit 9954b0f8), 键/角宏取 lk_v1_macros.itp;
    (2) --nw 每单层 W 珠数 (1 W = 4 水; w/l = 4*nw/nl), 名字 R4_<prim>_w<WL>_lam_s<k>; (3) mdp 模板取 D1/mdp; (4) seed 基数 20291029。
用法: build_R4.py --prim DOPE|DOPC|MC3H|MC3 --wl 6|12 --seed-id N -o DIR"""
import argparse, glob, json, math, os, re, shutil, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__)); PKG = os.path.dirname(HERE)
R2A = '/workspace/lnp-md/scan/R2a'; BUILDER = R2A + '/gen/build_lam_rect.py'; TMPL = R2A + '/tmpl'
BOX_GMX = '/workspace/ha_src/gmxenv/bin/gmx'
ap = argparse.ArgumentParser(); ap.add_argument('--prim', required=True, choices=['DOPE', 'DOPC', 'MC3H', 'MC3'])
ap.add_argument('--wl', type=int, required=True, help='真实水/脂 (整数); 每单层 W 珠 = wl*nl/4')
ap.add_argument('--seed-id', type=int, required=True); ap.add_argument('-o', required=True); ap.add_argument('--gmx', default=BOX_GMX); ap.add_argument('--ntomp', type=int, default=4)
ap.add_argument('--nl', type=int, default=480); ap.add_argument('--apl', type=float, default=0.55); ap.add_argument('--dens', type=float, default=700.0)
a = ap.parse_args(); d = os.path.abspath(a.o); os.makedirs(d, exist_ok=True)
assert (a.wl * a.nl) % 4 == 0; NW = a.wl * a.nl // 4; NL = a.nl; NCL = NL if a.prim == 'MC3H' else 0
name = 'R4_%s_w%02d_lam_s%d' % (a.prim, a.wl, a.seed_id)
def cksum(s): return int(subprocess.run('printf %%s %s | cksum' % repr(s), shell=True, capture_output=True, text=True).stdout.split()[0])
seed = 20291029 + cksum(name) % 100000
FF = ['martini_v3.0.0.itp', 'martini_v3.0.0_ffbonded_v2.itp', 'martini_v3.0.0_phospholipids_PC_v2.itp', 'martini_v3.0.0_phospholipids_PE_v2.itp',
      'lk_v1_macros.itp', 'MC3_MC3H.itp', 'martini_v3.0.0_solvents_v1.itp', 'martini_v3.0.0_ions_v1.itp']
def masses(files):
    M, cur, sec = {}, None, None
    for fn in files:
        for raw in open(fn):
            l = raw.split(';')[0].strip()
            if not l or l.startswith('#'): continue
            m = re.match(r'\[\s*(\w+)\s*\]', l)
            if m: sec = m.group(1); continue
            if sec == 'moleculetype': cur = l.split()[0]; M[cur] = 0.0; sec = 'mt_done'
            elif sec == 'atoms' and cur:
                f = l.split(); M[cur] += float(f[7]) if len(f) >= 8 else (36.0 if f[1].startswith('T') else 54.0 if f[1].startswith('S') else 72.0)
    return M
M = masses([PKG + '/ff/' + f for f in FF])
def run(cmd, log, cwd=d):
    r = subprocess.run(cmd, shell=True, cwd=cwd, capture_output=True, text=True); open(log, 'w').write(r.stdout + r.stderr)
    if r.returncode: sys.exit('FAIL %s (见 %s)' % (cmd[:80], log))
def ndx(gro, out):
    L = open(gro).read().splitlines(); n = int(L[1]); sol = []; rest = []
    for i, l in enumerate(L[2:2 + n], 1): (sol if l[5:10].strip() in ('W', 'CL', 'NA') else rest).append(i)
    def blk(nm, ids):
        s = '[ %s ]\n' % nm
        for k in range(0, len(ids), 15): s += ' '.join(map(str, ids[k:k + 15])) + '\n'
        return s
    open(out, 'w').write(blk('System', list(range(1, n + 1))) + blk('Solvent', sol) + blk('Rest', rest))
def top(path, mols, title):
    with open(path, 'w') as o:
        for f in FF: o.write('#include "%s"\n' % f)
        o.write('\n[ system ]\n%s\n\n[ molecules ]\n' % title)
        for m, n in mols: o.write('%s %d\n' % (m, n))
cnt = [(a.prim, NL), ('W', NW)] + ([('CL', NCL)] if NCL else [])
open(d + '/counts.txt', 'w').write(''.join('%s %d\n' % kv for kv in cnt))
V = sum(M[m] * n for m, n in cnt) / a.dens
Lxy = math.sqrt(a.apl * NL / 2.0); Lz = V / Lxy ** 2
os.environ['GMXLIB'] = PKG + '/ff'
run('python3 %s --counts counts.txt --tmpl %s --seed %d --dmin 0.30 --info preasm.json -o built.gro --geom lam --box %.4f --lz %.4f --nbil 1' % (BUILDER, TMPL, seed, Lxy, Lz), d + '/build.log')
for f in FF: shutil.copy(PKG + '/ff/' + f, d + '/' + f)   # 构建时用的 ff 副本 (发车用 inputs/ff, 字节相同, MANIFEST 核)
top(d + '/built.top', cnt, name); ndx(d + '/built.gro', d + '/built.ndx')
G = a.gmx; mdp = PKG + '/mdp'
def grompp_em(mdpn, gro, tp, ndxf, tag):
    run('%s grompp -f %s/%s.mdp -c %s -p %s -n %s -o %s.tpr -po %s_out.mdp -maxwarn 0' % (G, mdp, mdpn, gro, tp, ndxf, tag, tag), d + '/%s_grompp.log' % tag)
    run('%s mdrun -deffnm %s -ntmpi 1 -ntomp %d -nb cpu -pin off' % (G, tag, a.ntomp), d + '/%s_mdrun.log' % tag)
grompp_em('em1', 'built.gro', 'built.top', 'built.ndx', 'em1')
run('%s genconf -f em1.gro -nbox 1 1 2 -o rep.gro' % G, d + '/genconf.log')
top(d + '/sys.top', cnt + cnt, name + ' prim=%s arm=lam wl=%d T=320' % (a.prim, a.wl))
ndx(d + '/rep.gro', d + '/index.ndx'); grompp_em('em2', 'rep.gro', 'sys.top', 'index.ndx', 'em2')
shutil.copy(d + '/em2.gro', d + '/start.gro')
for k in ('relax_crescale_dev', 'prod_lam'):
    t = open('%s/%s.mdp' % (mdp, k)).read().replace('@SEED@', str(seed)); open('%s/%s.mdp' % (d, k), 'w').write(t)
info = json.load(open(d + '/preasm.json')); nat = int(open(d + '/start.gro').read().splitlines()[1])
open(d + '/expect.env', 'w').write('EXP_LIP=%d\nEXP_W=%d\nEXP_CL=%d\nEXP_ATOMS=%d\n' % (2 * NL, 2 * NW, 2 * NCL, nat))
open(d + '/SYSTEM.txt', 'w').write('%s prim=%s arm=lam seed_id=%d T=320 nlip=%d W=%d CL=%d wl_real=%.3f beads=%d builder_seed=%d builder_min_intermol=%s forced=%s gmx_used=%s\n'
    % (name, a.prim, a.seed_id, 2 * NL, 2 * NW, 2 * NCL, 4.0 * NW / NL, nat, seed, info.get('min_intermol_nm'), info.get('place_forced'), G))
print(open(d + '/SYSTEM.txt').read().strip())
