#!/usr/bin/env python3
"""XG0：按 dd/22 §3 方案 B / B-alt 规则生成 HA 蛋白珠 × 可滴定溶剂（WNT/POS/DW）交叉 LJ 补丁。
用法: xg0_gen_cross.py <m3_martini.itp> <ff_titratable_dir> <protein.itp> <go_atomtypes.itp> <variant B|Balt> <out_prefix>
      [--no-samesign-dw]   不加同号 DW 保险排斥（dd/22 §6-3，默认加）
      [--keep-collision]   碰撞中性珠 WNT 行保留上游 beta 值（dd/22 §6-5，默认改成 M3.0.0）
输出: <out_prefix>.itp   只含要新写的 nonbond_params 行（不含 [ ] 头，由 xg_apply.py 拼进合并力场）
      <out_prefix>.tsv   66 个 蛋白珠×{WNT,POS,DW} 对逐对：动作、σ、ε、来源标签、依据
      <out_prefix>.override  需要从合并力场里删掉再重写的上游行（碰撞珠）
所有数值从输入 itp 读取；脚本里不写死任何 σ/ε，只写规则。
"""
import sys, re, os
args = [a for a in sys.argv[1:] if not a.startswith('--')]
flags = {a for a in sys.argv[1:] if a.startswith('--')}
m3_itp, tdir, prot_itp, goat_itp, variant, outp = args
assert variant in ('B', 'Balt')
SAMESIGN_DW = '--no-samesign-dw' not in flags
OVERRIDE_COLL = '--keep-collision' not in flags

def nb_rows(path, skip_ifdef=True):
    """返回 {frozenset(a,b): (a,b,sigma,eps)}，跳过 #ifdef 块（pH 依赖行不属于蛋白交叉项）"""
    d, inblk = {}, False
    for l in open(path):
        s = l.split(';')[0].strip()
        if s.startswith('#ifdef'): inblk = True; continue
        if s.startswith('#endif'): inblk = False; continue
        t = s.split()
        if len(t) >= 5 and t[2] == '1' and not s.startswith('['):
            if inblk and skip_ifdef: continue
            try: d[frozenset((t[0], t[1]))] = (t[0], t[1], float(t[3]), float(t[4]))
            except ValueError: pass
    return d

m3 = nb_rows(m3_itp)
up = {}
for f in ('dummy_beads.itp', 'neutral_beads.itp', 'charged_beads.itp', 'titratable_beads_self_proton.itp'):
    up.update(nb_rows(os.path.join(tdir, f)))
def g(d, a, b):
    return d.get(frozenset((a, b)))

# 蛋白真实珠类型（不含 Go 虚拟类型），同 compat_merge.py
goat = {l.split(';')[0].split()[0] for l in open(goat_itp) if l.split(';')[0].split() and not l.strip().startswith('[')}
prot, sec = {}, None
for l in open(prot_itp):
    m = re.match(r'\s*\[\s*(\w+)\s*\]', l)
    if m: sec = m.group(1); continue
    t = l.split(';')[0].split()
    if sec == 'atoms' and len(t) >= 7 and not t[0].startswith('#'):
        q = float(t[6]); prot.setdefault(t[1], set()).add((q > 0) - (q < 0))
real = sorted(set(prot) - goat)
# 电荷符号按 itp 实际电荷定（不按类型名猜）。同一类型若同时出现 +1 和 -1（martinize2 末端 BB 珠 Q5：
# N 端 +1、C 端 -1），记为 'mix'：排斥行两种号都要，WNT 行只能取一个值，按 dd/22 表取负电比例并在 TSV 标注。
def sgn(x):
    ss = prot[x] - {0}
    if not ss: return 0
    if len(ss) == 2: return 'mix'
    return ss.pop()
charge = {x: sgn(x) for x in real}
# 上游参考行（全部从文件读）
ref_neg = g(up, 'WNT', 'Q5n'); ref_pos = g(up, 'WNT', 'Q1p')
w_neg = g(m3, 'W', 'Q5n'); w_pos = g(m3, 'W', 'Q1p')
pos_rep = g(up, 'POS', 'Q1p'); pos_rep2 = g(up, 'POS', 'Q5n'); dw_rep = g(up, 'DW', 'Q1p')
assert pos_rep[2:] == pos_rep2[2:] and dw_rep[2:] == pos_rep[2:], '上游排斥行不一致'
k_neg = ref_neg[3] / w_neg[3]; k_pos = ref_pos[3] / w_pos[3]

rows, ov = [], []
for x in real:
    q = charge[x]
    for s in ('WNT', 'POS', 'DW'):
        have = g(up, s, x); act = sig = eps = None; lab = note = ''
        if s == 'WNT':
            w = g(m3, 'W', x)
            if w is None: sys.exit('M3 缺 W-%s' % x)
            if q == 0:
                if have and not OVERRIDE_COLL:
                    act, sig, eps, lab, note = 'keep_upstream', have[2], have[3], '上游已有·保留', 'beta 值'
                else:
                    act = 'override' if have else 'write'
                    sig, eps, lab = w[2], w[3], '抄M3.0.0 W–X'
                    note = ('覆盖上游 beta 行 %.3f/%.3f' % (have[2], have[3])) if have else 'G2020: 中性珠保留 M3 参数'
            else:
                neg = (q == 'mix' or q < 0)
                ref, k = (ref_neg, k_neg) if neg else (ref_pos, k_pos)
                if have:
                    act, sig, eps, lab, note = 'keep_upstream', have[2], have[3], '上游已有·保留', '上游按 PO4/NC3 重调的带电值'
                elif variant == 'B':
                    act, sig, eps = 'write', w[2], round(w[3] * k, 2)
                    lab = '按比例缩放·估算'
                    note = 'M3 W–%s ε %.2f × %.4f（上游 WNT–%s / M3 W–%s）' % (x, w[3], k, ref[1], ref[1])
                else:
                    act, sig, eps = 'write', w[2], ref[3]
                    lab = '抄上游带电值·估算'
                    note = 'B-alt: ε=上游 WNT–%s；σ 取 M3 W–%s' % (ref[1], x)
        else:
            if q == 0:
                act, lab, sig, eps = 'zero', '应为零', 0.0, 0.0
                note = 'G2020: %s 不与中性非滴定珠作用' % ('质子珠' if s == 'POS' else 'dummy')
                if have: sys.exit('上游竟有 %s-%s' % (s, x))
            elif have:
                act, sig, eps, lab, note = 'keep_upstream', have[2], have[3], '上游已有·保留', ''
            elif s == 'POS' or (s == 'DW' and (q == 'mix' or q > 0)):
                act, sig, eps, lab = 'write', pos_rep[2], pos_rep[3], '抄上游排斥'
                note = '上游 POS–Q1p/Q5n 排斥' if s == 'POS' else '上游 DW–Q1p（异号）'
                if q == 'mix': note += '；类型 %s 同时有 +1/-1（末端珠），排斥按必须补' % x
            else:  # DW × 负电（同号）
                if SAMESIGN_DW:
                    act, sig, eps, lab = 'write', dw_rep[2], dw_rep[3], '抄上游排斥（同号·可选）'
                    note = '上游无先例；dd/22 §6-3 建议加作保险'
                else:
                    act, lab, sig, eps, note = 'zero', '应为零（同号未加）', 0.0, 0.0, '--no-samesign-dw'
        if s == 'WNT' and q == 'mix': note += '；⚠ %s 同时有 +1/-1，单一类型只能取一个 WNT 值，按 dd/22 取负电比例' % x
        rows.append((x, s, q, act, sig, eps, lab, note))
        if act == 'override': ov.append((s, x))

with open(outp + '.tsv', 'w') as f:
    f.write('# variant=%s samesign_dw=%s override_collision=%s k_neg=%.6f k_pos=%.6f\n' % (variant, SAMESIGN_DW, OVERRIDE_COLL, k_neg, k_pos))
    f.write('prot\tsolv\tq\taction\tsigma_nm\teps_kJmol\tsource\tnote\n')
    for r in rows: f.write('%s\t%s\t%s\t%s\t%.4f\t%.4f\t%s\t%s\n' % ((r[0], r[1], r[2] if r[2] == 'mix' else '%+d' % r[2]) + r[3:]))
with open(outp + '.itp', 'w') as f:
    f.write('; XG0 自动生成：HA 蛋白珠 × WNT/POS/DW 交叉 LJ，方案 %s（dd/22 §3）。不要手改，改 xg0_gen_cross.py。\n' % variant)
    for x, s, q, act, sig, eps, lab, note in rows:
        if act in ('write', 'override'):
            f.write('%-6s %-6s 1 %.6E %.6E ; %s | %s\n' % (s, x, sig, eps, lab, note))
open(outp + '.override', 'w').write(''.join('%s %s\n' % p for p in ov))
from collections import Counter
c = Counter(r[3] for r in rows); gaps = [r for r in rows if r[3] in ('write', 'zero')]
print('variant=%s real=%d pairs=%d actions=%s gaps(write+zero)=%d write=%d zero=%d override=%d keep=%d' % (
    variant, len(real), len(rows), dict(c), len(gaps), c['write'], c['zero'], c['override'], c['keep_upstream']))
