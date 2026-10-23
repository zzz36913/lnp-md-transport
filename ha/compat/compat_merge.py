#!/usr/bin/env python3
"""HA-ENV-01 最小兼容性试验：把 titratable Martini（martini_sour_examples 力场）合并进 GōMartini 3 的 martini.itp。
用法: compat_merge.py <go_martini.itp> <ff_titratable_dir> <protein.itp> <go_atomtypes.itp> <out_merged.itp> <report.txt> [pH=5.00]
规则（只做语法层合并，不发明任何参数）：
  - [defaults] 用 GōMartini 侧的；titratable 侧新原子类型（WNT/POS/DW/...）追加进 [atomtypes]，已存在的标准类型跳过；
  - titratable 的 nonbond_params：至少一方是新类型才追加；两方都是标准 Martini 3 类型的行跳过并计数（避免重复定义）；
  - #ifdef pHx.xx / #endif 结构原样保留（pH_dep_interactions.itp）。
报告：蛋白真实珠类型（不含 Go 虚拟位点类型）× 溶剂侧 titratable 类型（WNT/POS/DW）中，在合并后（基础 + 选定 pH 块）
没有显式 nonbond_params 的配对数。组合规则 1 且 atomtypes c6=c12=0 → 缺失配对=零 LJ，grompp 不会报错但物理上错。
"""
import sys, os, re
go_itp, tdir, prot_itp, goat_itp, out, rep = sys.argv[1:7]
pH = sys.argv[7] if len(sys.argv) > 7 else "5.00"

def sections(lines):
    cur = None
    for l in lines:
        m = re.match(r'\s*\[\s*(\w+)\s*\]', l)
        if m: cur = m.group(1).lower(); yield cur, None; continue
        yield cur, l

base = open(go_itp).read().split('\n')
base_types, base_pairs = set(), set()
for sec, l in sections(base):
    if l is None: continue
    t = l.split(';')[0].split()
    if not t or t[0].startswith('#'): continue
    if sec == 'atomtypes': base_types.add(t[0])
    elif sec == 'nonbond_params' and len(t) >= 5: base_pairs.add(frozenset((t[0], t[1])))

# titratable 侧：martini.itp 头里的 atomtypes + 它 #include 的 nonbond 文件（按上游 martini.itp 的 include 顺序）
thead = open(os.path.join(tdir, 'martini.itp')).read().split('\n')
t_types, incs = [], []
for sec, l in sections(thead):
    if l is None: continue
    s = l.strip()
    if s.startswith('#include'): incs.append(s.split('"')[1]); continue
    t = s.split(';')[0].split()
    if sec == 'atomtypes' and t: t_types.append((t[0], l))
new_types = [(n, l) for n, l in t_types if n not in base_types]
new_names = {n for n, _ in new_types}

nb_out, skipped_std, kept = [], 0, 0
pairs_always, pairs_ph, cur_if = set(), set(), None
for inc in incs:
    nb_out.append('; ---- from ff_titratable/%s ----' % inc)
    for l in open(os.path.join(tdir, inc)).read().split('\n'):
        s = l.strip()
        if s.startswith('#ifdef'): cur_if = s.split()[1]; nb_out.append(l); continue
        if s.startswith('#endif'): cur_if = None; nb_out.append(l); continue
        if s.startswith('['): continue
        t = s.split(';')[0].split()
        if len(t) < 5: 
            if s.startswith(';') or not s: nb_out.append(l)
            continue
        a, b = t[0], t[1]
        if a not in new_names and b not in new_names: skipped_std += 1; continue
        nb_out.append(l); kept += 1
        if cur_if is None: pairs_always.add(frozenset((a, b)))
        elif cur_if == 'pH' + pH: pairs_ph.add(frozenset((a, b)))

# 写合并力场
i_nb = next(i for i, l in enumerate(base) if l.strip().startswith('[ nonbond_params'))
merged = base[:i_nb] + ['; ---- titratable Martini atomtypes (martini_sour_examples) ----'] + [l for _, l in new_types] + base[i_nb:] + ['[ nonbond_params ]'] + nb_out
open(out, 'w').write('\n'.join(merged) + '\n')

# 缺失配对统计
goat = set()
for l in open(goat_itp):
    t = l.split(';')[0].split()
    if t and not t[0].startswith('['): goat.add(t[0])
prot_types = set()
for sec, l in sections(open(prot_itp).read().split('\n')):
    if sec == 'atoms' and l:
        t = l.split(';')[0].split()
        if len(t) >= 5 and not t[0].startswith('#'): prot_types.add(t[1])
real = sorted(prot_types - goat)
have = base_pairs | pairs_always | pairs_ph
solv = [x for x in ('WNT', 'POS', 'DW') if x in new_names]
miss = [(p, s) for p in real for s in solv if frozenset((p, s)) not in have]
with open(rep, 'w') as f:
    f.write('base_types=%d titr_types=%d new_types_added=%d (%s)\n' % (len(base_types), len(t_types), len(new_types), ' '.join(sorted(new_names))))
    f.write('titr_nonbond_kept=%d skipped_std_std=%d (标准-标准行跳过，以 GōMartini/Martini 3 原值为准)\n' % (kept, skipped_std))
    f.write('protein_real_bead_types=%d go_virtual_types_excluded=%d pH_block=pH%s\n' % (len(real), len(prot_types & goat), pH))
    f.write('MISSING_PAIRS=%d of %d (蛋白珠类型 × %s 无显式 LJ → 零 LJ)\n' % (len(miss), len(real) * len(solv), '/'.join(solv)))
    for p, s in miss: f.write('  missing %s %s\n' % (p, s))
print(open(rep).read().split('\n')[3])
