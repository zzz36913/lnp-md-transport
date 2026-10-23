#!/usr/bin/env python3
"""把 XG0 补丁拼进 compat_merge.py 产出的合并力场。
用法: xg_apply.py <merged_base.itp> <patch.itp> <patch.override> <out.itp> [--drop A:B ...] [--zero A:B ...]
  - .override 列出的上游行（只在 #ifdef 块外）先删掉，再由补丁重写；删不到就报错。
  - 补丁里每一对在删除后的合并力场中都不能已存在（防重复定义 / grompp 覆盖警告）。
  - --drop / --zero 只给阴性对照用：删掉补丁里某对 / 把某对 ε 置 0。
"""
import sys
a = sys.argv[1:]
base, patch, ovf, out = a[:4]
drop, zero = set(), set()
i = 4
while i < len(a):
    k, v = a[i], frozenset(a[i + 1].split(':')); i += 2
    (drop if k == '--drop' else zero).add(v)
ov = {frozenset(l.split()) for l in open(ovf) if l.strip()}
lines, inblk, removed, have = open(base).read().split('\n'), False, set(), set()
keep = []
for l in lines:
    s = l.split(';')[0].strip()
    if s.startswith('#ifdef'): inblk = True
    if s.startswith('#endif'): inblk = False
    t = s.split()
    if len(t) >= 5 and t[2] == '1' and not inblk:
        p = frozenset(t[:2])
        if p in ov: removed.add(p); continue
        have.add(p)
    keep.append(l)
miss = ov - removed
if miss: sys.exit('override 行未找到: %s' % [sorted(x) for x in miss])
add = ['; ==== XG0 patch: %s ====' % patch]
n = 0
for l in open(patch):
    t = l.split(';')[0].split()
    if len(t) < 5: continue
    p = frozenset(t[:2])
    if p in have: sys.exit('补丁对已存在于合并力场: %s' % sorted(p))
    if p in drop: add.append('; [NEG-CONTROL dropped] ' + l.rstrip()); continue
    if p in zero: t[4] = '0.000000E+00'; add.append(' '.join(t) + ' ; [NEG-CONTROL eps=0]'); n += 1; continue
    add.append(l.rstrip()); n += 1
while keep and keep[-1] == '': keep.pop()
open(out, 'w').write('\n'.join(keep + add) + '\n')
print('removed_override=%d patch_rows_written=%d dropped=%d zeroed=%d -> %s' % (len(removed), n, len(drop), len(zero), out))
