#!/usr/bin/env python3
"""XG1：从 tpr 的 gmx dump 读出实际 LJ 矩阵（不读 itp 文本），逐对断言。
用法: xg1_check.py <tag.dump> <xg0.tsv> <pH e.g. 5.00> <pH_dep_interactions.itp> [--baseline base.dump] [--expect-fail]
断言:
  A  66 对 蛋白真实珠×{WNT,POS,DW}：TSV 里 write/override/keep_upstream 的对 c6、c12 非零且等于 4εσ^6、4εσ^12（相对误差<1e-4）；
     zero 的对 c6=c12=0。
  B  pH 宏命中：tpr 中 WNT–WNT、WNT–POS 等于 pH_dep_interactions.itp 中 #ifdef pH<pH> 块的值，且该 WNT–POS 值在 21 个块中唯一。
  C  全矩阵：所有 tpr 中出现的非 Go 虚拟类型 × WNT 不得为零（Go 虚拟类型按 GōMartini 设计与溶剂无 LJ，单列计数）。
  D  （给了 --baseline 时）除补丁涉及的对之外，矩阵每个元素与基线 tpr 完全相同。
--expect-fail：阴性对照，断言失败才算通过（退出码反转）。
"""
import sys, re
a = sys.argv[1:]
dump, tsv, ph, phf = a[:4]
base = a[a.index('--baseline') + 1] if '--baseline' in a else None
expfail = '--expect-fail' in a

def load(path):
    names, lj, atnr, cur_types = {}, [], None, []
    for l in open(path):
        if atnr is None:
            m = re.search(r'atnr=(\d+)', l)
            if m: atnr = int(m.group(1)); continue
        m = re.match(r'\s*functype\[(\d+)\]=LJ_SR, c6=\s*(\S+), c12=\s*(\S+)', l)
        if m and atnr and int(m.group(1)) < atnr * atnr:
            lj.append((float(m.group(2)), float(m.group(3)))); continue
        m = re.match(r'\s*atom\[\s*(\d+)\]=\{type=\s*(\d+)', l)
        if m:
            if m.group(1) == '0': cur_types = []
            cur_types.append(int(m.group(2))); continue
        m = re.match(r'\s*type\[\s*(\d+)\]=\{name="([^"]+)"', l)
        if m and cur_types:
            t = cur_types[int(m.group(1))]
            names.setdefault(t, set()).add(m.group(2))
    assert atnr and len(lj) == atnr * atnr, (atnr, len(lj))
    # grompp 会把参数完全相同的 atomtype 合并成一个 type 号；只允许 Go 虚拟类型（名如 HA_post_123）被合并
    for t, ns in names.items():
        if len(ns) > 1 and any(not re.search(r'_\d+$', n) for n in ns): sys.exit('非 Go 类型被合并: %s' % sorted(ns))
    idx = {}
    for t, ns in names.items():
        for n in ns:
            if idx.setdefault(n, t) != t: sys.exit('同名多 type: %s' % n)
    return atnr, lj, names, idx

atnr, lj, names, idx = load(dump)
def get(A, B, L=lj, I=idx, N=atnr): return L[I[A] * N + I[B]]
fails, info = [], []
def ok(c, msg):
    if not c: fails.append(msg)

# A
rows = [l.rstrip('\n').split('\t') for l in open(tsv) if not l.startswith('#') and not l.startswith('prot\t')]
patched = set(); nreq = nzero = 0
for p, s, q, act, sig, eps, lab, note in rows:
    sig, eps = float(sig), float(eps)
    if p not in idx or s not in idx: fails.append('A 类型不在 tpr: %s/%s' % (p, s)); continue
    c6, c12 = get(p, s)
    assert get(s, p) == (c6, c12)
    if act == 'zero':
        nzero += 1; ok(c6 == 0 and c12 == 0, 'A 设计零被误加 %s-%s c6=%g c12=%g' % (p, s, c6, c12))
    else:
        nreq += 1
        e6, e12 = 4 * eps * sig ** 6, 4 * eps * sig ** 12
        if c6 == 0 or c12 == 0: fails.append('A 缺失(零LJ) %s-%s [%s]' % (p, s, act)); continue
        ok(abs(c6 / e6 - 1) < 1e-4 and abs(c12 / e12 - 1) < 1e-4,
           'A 数值不符 %s-%s tpr σ=%.4f ε=%.4f 期望 %.4f/%.4f' % (p, s, (c12 / c6) ** (1 / 6), c6 * c6 / (4 * c12), sig, eps))
    if act in ('write', 'override'): patched.add(frozenset((p, s)))
info.append('A 检查 %d 对：非零期望 %d、设计零 %d' % (len(rows), nreq, nzero))

# B
blocks, cur = {}, None
for l in open(phf):
    s = l.split(';')[0].strip()
    if s.startswith('#ifdef'): cur = s.split()[1]; blocks[cur] = {}; continue
    if s.startswith('#endif'): cur = None; continue
    t = s.split()
    if cur and len(t) >= 5: blocks[cur][frozenset(t[:2])] = (float(t[3]), float(t[4]))
key = 'pH' + ph
if key not in blocks: fails.append('B 宏 %s 在 pH 文件里不存在（可用: %s…）' % (key, ','.join(list(blocks)[:3])))
else:
    for pr in (('WNT', 'WNT'), ('WNT', 'POS')):
        sig, eps = blocks[key][frozenset(pr)]
        c6, c12 = get(*pr)
        if c6 == 0: fails.append('B %s-%s 在 tpr 中为零 → pH 宏未命中' % pr); continue
        ts, te = (c12 / c6) ** (1 / 6), c6 * c6 / (4 * c12)
        ok(abs(te / eps - 1) < 1e-4 and abs(ts / sig - 1) < 1e-4, 'B %s-%s tpr ε=%.4f ≠ %s 块 %.4f' % (pr + (te, key, eps)))
        info.append('B %s-%s tpr σ=%.4f ε=%.4f（%s 块 %.4f）' % (pr + (ts, te, key, eps)))
    wp = blocks[key][frozenset(('WNT', 'POS'))][1]
    ok(sum(1 for b in blocks.values() if b[frozenset(('WNT', 'POS'))][1] == wp) == 1, 'B WNT–POS ε 不唯一')

# C
gov = [n for n in idx if re.search(r'_\d+$', n)]  # Go 虚拟类型，如 HA_post_123
zero_real = [n for n in idx if n not in gov and n not in ('DW', 'POS') and get(n, 'WNT') == (0.0, 0.0)]
ok(not zero_real, 'C 非 Go 类型 × WNT 为零: %s' % zero_real)
info.append('C tpr LJ 类型 %d（名字 %d）：Go 虚拟类型 %d（× WNT 为零 %d，按设计），其余 × WNT 零 LJ %d' % (
    atnr, len(idx), len(gov), sum(get(n, 'WNT') == (0.0, 0.0) for n in gov), len(zero_real)))

# D
if base:
    bn, bl, bnames, bidx = load(base)
    ok(set(bidx) == set(idx), 'D 类型集合不同')
    diff = set(); nd = 0
    for x in idx:
        for y in idx:
            if get(x, y) != get(x, y, bl, bidx, bn):
                nd += 1; diff.add(frozenset((x, y)))
    extra = diff - patched
    ok(not extra, 'D 补丁外的对被改动: %s' % [sorted(p) for p in list(extra)[:10]])
    info.append('D 与基线 tpr 相比改动 %d 个无序对（补丁 %d 对；补丁外改动 %d）' % (len(diff), len(patched), len(extra)))

for i in info: print('  ' + i)
for f in fails: print('  FAIL ' + f)
res = 'PASS' if not fails else 'FAIL(%d)' % len(fails)
if expfail:
    print('NEG-CONTROL %s：检查器结果 %s → %s' % (dump, res, '对照通过(被抓住)' if fails else '对照失败(没抓住)'))
    sys.exit(0 if fails else 1)
print('XG1 %s %s' % (dump, res)); sys.exit(0 if not fails else 1)
