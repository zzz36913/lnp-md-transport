#!/usr/bin/env python3
"""[R4 D1 版, 由 R3 t0_gate.py 改 3 处: 脂质残基名增 MC3/MC3H; polar 选择增反离子 CL NA, MC3/MC3H 的头/酯珠 (NP N1 GLA) 有意不计入 polar (中性 MC3 头基会进入尾区, 这正是被测量; 计入会让 MC3 起点 npol=37~43 假 VOID, 见 proof/polar_choice.txt) (DOPE/DOPC 体系无 CL/NA, 对它们与 R3 逐字等价); composition 增 CL 计数。阈值/判据/退出码一字未改]
t=0 硬闸门 (父 agent 指令 16:2x): 起点帧读数必须 ncl/wind/npol/wpol = 2/2/2/2, 否则该 build 作废(VOID_BUILD)。lam 臂适用; hii 臂不适用(预期 1/3/4/1, dd/61)。
同时用旧读出器(Claude tail_topology) 与 v2(winding 秩/完整盒矩阵) 读, 并在 0.65/0.75/0.95 三个 cutoff 上读, 三者须一致。
用法: t0_gate.py FRAME.gro|TOP.gro TRAJ.xtc? --level {builder,prod0} [--frame 0] [--json out.json]; 退出码 0=PASS, 3=VOID(lam), 0=n/a(hii)"""
import argparse, json, os, re, sys
import numpy as np, MDAnalysis as mda
sys.path.insert(0, '/workspace/lnp-md/scan/R3_remediation/analyzer_v2')
import topo_v2 as T
ap = argparse.ArgumentParser(); ap.add_argument('gro'); ap.add_argument('xtc', nargs='?'); ap.add_argument('--frame', type=int, default=0)
ap.add_argument('--level', default='builder'); ap.add_argument('--arm', default='lam'); ap.add_argument('--json'); ap.add_argument('--expect-lipids', type=int); ap.add_argument('--expect-w', type=int); a = ap.parse_args()
CS = T.load_cs_analyzer(); u = mda.Universe(a.gro, a.xtc) if a.xtc else mda.Universe(a.gro); ts = u.trajectory[a.frame]
rx = re.compile(r'^[CD][0-9][AB]$'); tails = u.atoms[[i for i, n in enumerate(u.atoms.names) if rx.match(n)]]
polar = u.select_atoms('name NH3 NC3 PO4 GL0 GL1 GL2 CNO or resname W CL NA'); H = T.box_matrix_from_dims(ts.dimensions); box = ts.dimensions[:3] / 10.0
res = {}
for c in (0.65, 0.75, 0.95):
    o = CS.tail_topology(tails.positions / 10.0, box, c); p = CS.tail_topology(polar.positions / 10.0, box, 0.8)
    n = T.topology_v2(tails.positions / 10.0, H, c); q = T.topology_v2(polar.positions / 10.0, H, 0.8)
    res[str(c)] = dict(v1=[o[0], o[2], p[0], p[2]], v2=[n[0], n[2], q[0], q[2]])
comp = dict(n_lipid_res=int(sum(1 for r in u.residues if r.resname in ('DOPE', 'DOPC', 'MC3', 'MC3H'))), n_W=int(sum(1 for r in u.residues if r.resname == 'W')), n_CL=int(sum(1 for r in u.residues if r.resname == 'CL')))
comp_ok = (a.expect_lipids is None or comp['n_lipid_res'] == a.expect_lipids) and (a.expect_w is None or comp['n_W'] == a.expect_w)
ok = comp_ok and all(r['v1'] == [2, 2, 2, 2] and r['v2'] == [2, 2, 2, 2] for r in res.values())
out = dict(file=a.gro, level=a.level, frame=a.frame, arm=a.arm, readings=res, composition=comp, composition_expected=dict(lipids=a.expect_lipids, W=a.expect_w), composition_ok=comp_ok, gate='ncl/wind/npol/wpol=2/2/2/2 @ cutoff 0.65/0.75/0.95 (polar 固定 0.8, 同 Claude 分析器默认) 且 v1==v2', applicable=(a.arm == 'lam'),
           verdict=('PASS' if ok else 'VOID_BUILD') if a.arm == 'lam' else 'N/A_HII_ARM')
print(json.dumps(out, ensure_ascii=False)); 
if a.json: json.dump(out, open(a.json, 'w'), indent=1)
sys.exit(0 if (ok or a.arm != 'lam') else 3)
