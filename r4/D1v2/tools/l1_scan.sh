#!/bin/bash
# L1 (builder 级) 闸门扫描: 对每个 build 的 start.gro 跑 gate/t0_gate_launch.py --level builder, 期望组成读 expect.env. 输出 TSV.
# 用法: bash tools/l1_scan.sh <build 根目录> > L1_summary.tsv ; PY=python 解释器
D=$(cd "$(dirname "$0")/.." && pwd); PY=${PY:-python3}
echo -e "build\tverdict\trc\tn_lipid\tn_W\tn_CL\tr065\tr075\tr095\tbuilder_seed\tmin_intermol"
for b in "$1"/R4_*; do [ -f $b/start.gro ] || continue; . $b/expect.env; n=$(basename $b); j=$(mktemp)
  $PY $D/gate/t0_gate_launch.py $b/start.gro --level builder --arm lam --expect-lipids $EXP_LIP --expect-w $EXP_W --json $j >/dev/null 2>&1; rc=$?
  $PY - $j $n $rc $b/SYSTEM.txt <<'P'
import json,sys
d=json.load(open(sys.argv[1])); s=dict(x.split('=',1) for x in open(sys.argv[4]).read().split() if '=' in x)
r=d['readings']; f=lambda k:'/'.join(map(str,r[k]['v1']))
c=d['composition']; print('\t'.join(map(str,[sys.argv[2],d['verdict'],sys.argv[3],c['n_lipid_res'],c['n_W'],c.get('n_CL',''),f('0.65'),f('0.75'),f('0.95'),s.get('builder_seed'),s.get('builder_min_intermol')])))
P
done
