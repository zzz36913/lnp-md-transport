#!/usr/bin/env python3
"""R3 事件/闸门收集器。输入: Claude stalk_topology_analyzer 的 series CSV (t_ns,Lx..Cz,npol,wpol)。零算力。
子命令:
  run  SERIES.csv --name N --prim DOPE|DOPC --arm lam|hii [--persist-ns 5] [--hii-persist-ns 20] [--cz-max 0.5] -> JSON(事件/删失/t0)
  agg  RUN.json... -> 闸门判定 (DOPE lam >=4/5 且 DOPC lam 0/5 (每格 n=5, 父 agent 16:32 裁决; 4/5 vs 0/5 Fisher 双侧 p=0.0476, power_calc_output.txt); 数值 QC 另见 contract)
读出定义(预注册, 见 contract/R3_contract.json):
  t0 : 第 0 帧 ncl/wind/npol/wpol 必须 2/2/2/2(lam), 否则 VOID_BUILD(不是事件, 不是删失)
  t_merge/t_wind3 : ncl==1 / wind==3 持续>=persist-ns (沿用 Claude 定义; dd/61: DOPE 与 DOPC 都出, 不能判别 H_II, 仅作次级报告)
  [v2 2026-10-28 17:xx] 主判据(冻结于任何结果读出之前): wpol==1 且 Cz<=0.5 持续>=20 ns —— 阈值与持续窗均为「执行者从 R2 观测所选, 非文献值」。
  敏感性读数(预注册, 仅描述, 不进 agg 的 verdict): t_hii 在 Cz{0.4,0.5,0.6} x 持续{10,20,30} ns 网格; 次级 ncl==1 持续{10,20,30} ns。
  t_hii(目标事件) : wpol==1 且 Cz<=cz-max 同时持续>=hii-persist-ns; 无事件 => 右删失于最后一帧(不是'未发生')
帧不独立: 只用事件时刻/存活, 不用帧占比算自由能."""
import argparse, csv, json, math, sys
import numpy as np
def sustained(t, m, persist):
    n = len(t); k = 0
    while k < n:
        if not m[k]: k += 1; continue
        j = k
        while j + 1 < n and m[j + 1]: j += 1
        if t[j] - t[k] >= persist - 1e-9 and (j > k or persist <= 0): return float(t[k])
        k = j + 1
    return None
def run(a):
    R = list(csv.DictReader(open(a.series))); t = np.array([float(r['t_ns']) for r in R])
    g = lambda c: np.array([float(r[c]) for r in R]); ncl, wd, npol, wpol, Cz = g('ncl'), g('wind'), g('npol'), g('wpol'), g('Cz')
    t0 = [int(ncl[0]), int(wd[0]), int(npol[0]), int(wpol[0])]
    void = (a.arm == 'lam' and t0 != [2, 2, 2, 2])
    dt = float(np.median(np.diff(t))) if len(t) > 1 else None
    cz_degenerate = bool(np.all(Cz < 1e-3))  # PO4 缺失(如 MC3H 需 --po4 NP)时 Cz 恒为 0, 会造成假 H_II 事件
    hii_mask = (wpol == 1) & (Cz <= a.cz_max) & (not cz_degenerate)
    out = dict(name=a.name, prim=a.prim, arm=a.arm, series=a.series, n_frames=len(t), frame_dt_ns=dt, T_obs_ns=float(t[-1] - t[0]), t0_reading=t0,
               t0_gate=('N/A_HII_ARM' if a.arm == 'hii' else ('VOID_BUILD' if void else 'PASS')),
               persist_ns=a.persist_ns, hii_persist_ns=a.hii_persist_ns, cz_max=a.cz_max,
               t_merge=sustained(t, ncl == 1, a.persist_ns), t_wind3=sustained(t, wd == 3, a.persist_ns),
               t_hii=sustained(t, hii_mask, a.hii_persist_ns), Cz_last=float(Cz[-1]), wpol_last=int(wpol[-1]), npol_last=int(npol[-1]),
               Cz_median_last_persist=float(np.median(Cz[t >= t[-1] - a.hii_persist_ns])),
               cz_degenerate=cz_degenerate, resolution_warning=(dt is not None and dt > a.persist_ns / 2.0 and 'frame_dt %.1f ns > persist/2: 事件时刻只是上界' % dt))
    # --- 预注册敏感性读数 (descriptive_only; 不改变 status/verdict) ---
    sens = {}
    for cz in (0.4, 0.5, 0.6):
        for pn in (10.0, 20.0, 30.0):
            m = (wpol == 1) & (Cz <= cz) & (not cz_degenerate); sens['hii_cz%.1f_p%d' % (cz, pn)] = sustained(t, m, pn)
    for pn in (10.0, 20.0, 30.0): sens['ncl1_p%d' % pn] = sustained(t, ncl == 1, pn)
    out['sensitivity'] = dict(descriptive_only=True, note='预注册敏感性读数; 不影响 G-R3 判定; 值=首次持续时刻(ns)或 null', values=sens)
    out['primary_criterion'] = dict(def_='wpol==1 and Cz<=%.2f sustained>=%.0f ns' % (a.cz_max, a.hii_persist_ns), origin='执行者从 R2 观测所选, 非文献值', frozen_before_readout=True)
    out['hii_event'] = out['t_hii'] is not None and not void
    out['censored'] = (out['t_hii'] is None) and not void
    out['status'] = 'VOID_BUILD' if void else ('EVENT' if out['hii_event'] else 'RIGHT_CENSORED')
    s = json.dumps(out, ensure_ascii=False); print(s)
    if a.out: open(a.out, 'w').write(s + '\n')
def agg(a):
    from scipy.stats import fisher_exact
    R = [json.load(open(f)) for f in a.runs]; lam = [r for r in R if r['arm'] == 'lam']
    cell = {}
    for p in ('DOPE', 'DOPC'):
        c = [r for r in lam if r['prim'] == p]; v = [r for r in c if r['status'] == 'VOID_BUILD']; u = [r for r in c if r['status'] != 'VOID_BUILD']
        ev = [r for r in u if r['status'] == 'EVENT']
        cell[p] = dict(n_builds=len(c), n_void=len(v), void_rate=(len(v) / len(c) if c else None), n_valid=len(u), n_event=len(ev),
                       exposure_ns=sum(r['T_obs_ns'] for r in u), event_times_ns=sorted(r['t_hii'] for r in ev),
                       censored_at_ns=sorted(r['T_obs_ns'] for r in u if r['status'] == 'RIGHT_CENSORED'))
    # 敏感性计数(仅描述; 不进 gate): 每格有效 build 里各读数的事件数
    for p in ('DOPE', 'DOPC'):
        u = [r for r in lam if r['prim'] == p and r['status'] != 'VOID_BUILD']; keys = sorted({k for r in u for k in r.get('sensitivity', {}).get('values', {})})
        cell[p]['sensitivity_event_counts_descriptive_only'] = {k: sum(1 for r in u if r['sensitivity']['values'].get(k) is not None) for k in keys}
    de, dc = cell['DOPE'], cell['DOPC']
    N = a.n
    gate = dict(n_required=N, DOPE_lam_pass=(de['n_valid'] >= N and de['n_event'] >= N - 1), DOPC_lam_pass=(dc['n_valid'] >= N and dc['n_event'] == 0),
                note='有效(非 VOID) build < n => NOT_EVALUABLE(不算过也不算失败); DOPE 门槛 >= n-1 个事件')
    gate['evaluable'] = de['n_valid'] >= N and dc['n_valid'] >= N
    if gate['evaluable']:
        gate['fisher_two_sided_p'] = float(fisher_exact([[de['n_event'], de['n_valid'] - de['n_event']], [dc['n_event'], dc['n_valid'] - dc['n_event']]])[1])
    gate['verdict'] = 'NOT_EVALUABLE' if not gate['evaluable'] else ('PASS' if gate['DOPE_lam_pass'] and gate['DOPC_lam_pass'] else 'FAIL')
    gate['sensitivity_note'] = '敏感性读数(Cz 0.4/0.5/0.6 x 持续 10/20/30 ns; 次级 ncl==1)只在 cells.*.sensitivity_event_counts_descriptive_only 里描述, 不参与本 verdict'
    gate['conditional_on'] = '合格起点(t=0 L1 与 relax 后 L2 均 2/2/2/2); 每格 void_rate 见 cells'
    gate['note2'] = '3v3 的 Fisher 最小双侧 p=0.100, 5v5 为 0.0079, 4/5 vs 0/5 为 0.0476 (scan/R2_remediation/power_calc_output.txt §B): 本闸门是工程放行闸, 不是速率比较'
    s = json.dumps(dict(cells=cell, gate=gate), ensure_ascii=False, indent=1); print(s)
    if a.out: open(a.out, 'w').write(s + '\n')
ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest='cmd', required=True)
r = sp.add_parser('run'); r.add_argument('series'); r.add_argument('--name', required=True); r.add_argument('--prim', required=True); r.add_argument('--arm', required=True)
r.add_argument('--persist-ns', type=float, default=5.0); r.add_argument('--hii-persist-ns', type=float, default=20.0); r.add_argument('--cz-max', type=float, default=0.5); r.add_argument('--out')
g = sp.add_parser('agg'); g.add_argument('runs', nargs='+'); g.add_argument('--out'); g.add_argument('--n', type=int, default=5)
a = ap.parse_args(); run(a) if a.cmd == 'run' else agg(a)
