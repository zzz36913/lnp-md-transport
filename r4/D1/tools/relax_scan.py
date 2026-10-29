#!/usr/bin/env python3
"""box 起点资格证明: 对 relax 轨迹 (trr/xtc) 每隔 --every-ns 取一帧, 用包内 gate/t0_gate_launch.py (prod0 级, 阈值未改) 判读.
用法: relax_scan.py <start.gro> <traj> <expect.env> <out.tsv> [--every-ns 1.0]"""
import sys, os, json, subprocess, tempfile, argparse
import MDAnalysis as mda
ap = argparse.ArgumentParser(); ap.add_argument('gro'); ap.add_argument('traj'); ap.add_argument('env'); ap.add_argument('out'); ap.add_argument('--every-ns', type=float, default=1.0)
a = ap.parse_args(); E = dict(l.strip().split('=') for l in open(a.env) if '=' in l)
G = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', 'gate', 't0_gate_launch.py')
u = mda.Universe(a.gro, a.traj); last = -1e9; rows = []
with tempfile.TemporaryDirectory() as td:
    for ts in u.trajectory:
        t = ts.time / 1000.0
        if t - last < a.every_ns - 1e-6 and ts.frame != len(u.trajectory) - 1: continue
        last = t; f = os.path.join(td, 'f.gro'); u.atoms.write(f); j = os.path.join(td, 'f.json')
        rc = subprocess.run([sys.executable, G, f, '--level', 'prod0', '--arm', 'lam', '--expect-lipids', E['EXP_LIP'], '--expect-w', E['EXP_W'], '--json', j], capture_output=True).returncode
        d = json.load(open(j)); r = d['readings']; s = lambda k: '/'.join(map(str, r[k]['v1']))
        rows.append(f"{t:.3f}\t{d['verdict']}\t{rc}\t{s('0.65')}\t{s('0.75')}\t{s('0.95')}\t{ts.dimensions[0]/10:.3f}\t{ts.dimensions[2]/10:.3f}")
        print(rows[-1], flush=True)
open(a.out, 'w').write('t_ns\tverdict\trc\tncl/wind/npol/wpol@0.65\t@0.75\t@0.95\tLx_nm\tLz_nm\n' + '\n'.join(rows) + '\n')
