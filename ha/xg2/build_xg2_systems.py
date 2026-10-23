#!/usr/bin/env python3
"""XG2 起始构型（box 上生成，产物随包发；机器端不重建，只核 sha）。
把普通 M3 水 W（单珠）换成可滴定水：每个 W -> WNA(WN=WNT, DN=DW) + 一个 H+(POS)，
几何照上游 fgrunewald/titratable_martini_tools convert_gro_to_titratable.py（-bead water）：
  WN 在原 W 位置，DN = r - 0.17*v，POS = r + 0.17*v，v 为随机单位向量（这里固定种子以便可复现）。
每个 WNA 配一个 H+ → 溶剂整体电中性；蛋白不含可滴定位点，净电荷用 NA（ff_titratable/ion.itp，Q1p，+1）中和。
用法:
  build_xg2_systems.py pre  <ha2box.gro> <n_na> <out.gro>
      取 ha2box 里的蛋白(HA_pre)；保留前 n_na 个 NA 原位作反离子；其余 NA、全部 CL 的位置改成水（保持密度）。
  build_xg2_systems.py post <solvated.gro> <n_na> <out.gro> [min_dist_nm=1.0]
      solvated.gro = 蛋白 + W（gmx solvate 结果）；从离蛋白 >= min_dist 的 W 里按固定种子挑 n_na 个换成 NA。
输出顺序: 蛋白, WNA*N, NA*n_na, H+*N（与 top 的 [molecules] 一致）。
"""
import sys, random, math
random.seed(20261023)
def rd(p):
    L = open(p).read().splitlines(); n = int(L[1]); at = []
    for l in L[2:2+n]:
        at.append((l[5:10].strip(), l[10:15].strip(), float(l[20:28]), float(l[28:36]), float(l[36:44])))
    return at, L[2+n]
def uv():
    while True:
        x, y, z = (random.gauss(0, 1) for _ in range(3)); r = math.sqrt(x*x+y*y+z*z)
        if r > 1e-6: return x/r, y/r, z/r
mode, gin, nna, gout = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
at, box = rd(gin)
prot = [a for a in at if a[0] not in ('W', 'NA', 'CL')]
if mode == 'pre':
    ions = [a for a in at if a[0] == 'NA']
    na = ions[:nna]
    wat = [a for a in at if a[0] == 'W'] + ions[nna:] + [a for a in at if a[0] == 'CL']
elif mode == 'post':
    md = float(sys.argv[5]) if len(sys.argv) > 5 else 1.0
    bx = [float(v) for v in box.split()[:3]]
    W = [a for a in at if a[0] == 'W']
    def far(w):
        for p in prot:
            d2 = 0
            for k in range(3):
                d = w[2+k]-p[2+k]; d -= bx[k]*round(d/bx[k]); d2 += d*d
            if d2 < md*md: return False
        return True
    idx = list(range(len(W))); random.shuffle(idx); pick = []
    for i in idx:
        if far(W[i]): pick.append(i)
        if len(pick) == nna: break
    assert len(pick) == nna, 'not enough far waters'
    ps = set(pick); na = [W[i] for i in sorted(pick)]; wat = [w for i, w in enumerate(W) if i not in ps]
else: sys.exit('mode pre|post')
out = []; resi = 0
def put(res, name, x, y, z):
    out.append('%5d%-5s%5s%5d%8.3f%8.3f%8.3f' % ((resi % 100000), res, name, (len(out)+1) % 100000, x, y, z))
L = open(gin).read().splitlines()
for l in L[2:2+len(at)]:
    if l[5:10].strip() not in ('W', 'NA', 'CL'): out.append(l[:44])  # 蛋白行原样
protons = []
for w in wat:
    resi += 1; v = uv(); x, y, z = w[2:5]
    put('WNA', 'WN', x, y, z); put('WNA', 'DN', x-0.17*v[0], y-0.17*v[1], z-0.17*v[2])
    protons.append((x+0.17*v[0], y+0.17*v[1], z+0.17*v[2]))
for a in na:
    resi += 1; put('ION', 'Q1', *a[2:5])  # 名字同 ff_titratable/ion.itp 的 NA 分子（ION/Q1，Q1p）
for p in protons:
    resi += 1; put('H+', 'POS', *p)
# 重写原子序号
out = [o[:15] + '%5d' % ((i+1) % 100000) + o[20:] for i, o in enumerate(out)]
with open(gout, 'w') as f:
    f.write('XG2 %s titratable water: prot %d + WNA %d + NA %d + H+ %d\n%d\n' % (mode, len(prot), len(wat), len(na), len(protons), len(out)))
    f.write('\n'.join(out) + '\n' + box + '\n')
print('%s prot=%d WNA=%d NA=%d H+=%d total=%d box=%s' % (mode, len(prot), len(wat), len(na), len(protons), len(out), box.strip()))
