#!/usr/bin/env python3
"""verdict_R4.py -- R4 D1 判读脚本 (零算力; 判据全部来自 PREREG_R4.md, 阈值写死在下方常量, 改了就要改 MANIFEST, 审查会看见).
用法:
  python3 verdict_R4.py analyze <R4_run_目录>... --inputs <D1v2/inputs> --out <结果目录>   # 对每个 build 的 prod xtc 跑 analyzer (分体系参数), 写 series/<b>.csv
  python3 verdict_R4.py judge   <结果目录>                                               # 读 series + gate.json -> runs.tsv / cells.tsv / VERDICT.json
冻结读数 (同 R3): ncl, wind (尾连通), wpol (水/头基连通秩), Cz (头珠 z 向层状对比度). npol 只作起点闸; 面内水通道 = 辅助读数, 不进任何判据.
分体系参数 (预注册): 头珠 DOPE/DOPC=PO4, MC3/MC3H=GLA; polar = 'name NH3 NC3 PO4 GL0 GL1 GL2 CNO or resname W CL NA'; 尾 ^[CD][0-9][AB]$; cutoff 0.75; polar cutoff 0.8.
"""
import argparse, glob, json, os, re, subprocess, sys, csv
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, 'tools')); sys.path.insert(0, os.path.join(HERE, 'gate'))
# ---------------- 预注册常量 (PREREG_R4.md §3) ----------------
CZ_MAX, HII_PERSIST_NS = 0.5, 20.0          # 主事件 (R3 冻结): wpol==1 且 Cz<=0.5 持续 >=20 ns
T_EVAL_MIN_NS = 400.0                        # 无事件的 run 要计入 "0 事件", 须观测 >=400 ns (否则 TRUNC, 不可评估)
N_PER_CELL = 3
DOPE_MIN_EVENTS = 2                          # 正尺: DOPE >=2/3 出事件
DOPC_MAX_EVENTS = 0                          # 负尺: DOPC 0/3
CZ_WIN_NS = 100.0                            # MC3 对比读数: 每重复 rho = (prod 末 100 ns Cz 中位数) / (builder start.gro 的 Cz, 同 analyzer 同参数)
DELTA_RHO = 0.2                              # 方向写死: min(rho_MC3H) - max(rho_MC3) >= 0.2 => MC3H 比中性 MC3 保留更多片层序 = PASS; 反向 >=0.2 => REVERSE
DELTA_CZ_ABS = 0.4                           # 只描述 (不判): 绝对 Cz 差. 不用作判据: builder 起点 MC3 w06 Cz 1.516 vs MC3H 1.990 (Lz 不同, 见 proof/cz_builder_baseline.tsv), 绝对 Cz 跨体系不可比
HEAD = {'DOPE': 'PO4', 'DOPC': 'PO4', 'MC3H': 'GLA', 'MC3': 'GLA'}
POLAR = 'name NH3 NC3 PO4 GL0 GL1 GL2 CNO or resname W CL NA'
NAME = re.compile(r'^R4_(DOPE|DOPC|MC3H|MC3)_(h\d\d\d)_lam_s(\d+)$')
# R3 冻结的持续判定函数, 从 tools/collect_R3_frozen.py 逐字复制 (该文件模块级会解析 argv, 不能 import)
def sustained(t, m, persist):
    n = len(t); k = 0
    while k < n:
        if not m[k]: k += 1; continue
        j = k
        while j + 1 < n and m[j + 1]: j += 1
        if t[j] - t[k] >= persist - 1e-9 and (j > k or persist <= 0): return float(t[k])
        k = j + 1
    return None

def analyze(a):
    os.makedirs(os.path.join(a.out, 'series'), exist_ok=True); AN = os.path.join(HERE, 'gate', 'stalk_topology_analyzer.py')
    for root in a.runs:
        for bd in sorted(glob.glob(os.path.join(root, 'builds', 'R4_*'))):
            b = os.path.basename(bd); m = NAME.match(b)
            if not m: continue
            xtcs = sorted(glob.glob(os.path.join(bd, 'prod', 'attempt_*', 'prod*.xtc')))
            gates = sorted(glob.glob(os.path.join(bd, 'gate', 'attempt_*', 'gate.json')))
            rec = dict(build=b, run_root=root, xtcs=xtcs, gate_json=gates[-1] if gates else None)
            sg = os.path.join(a.inputs, b, 'start.gro'); ob = os.path.join(a.out, 'series', f'{b}.builder.csv')
            subprocess.run([sys.executable, AN, sg, sg, '--out', ob, '--summary', ob + '.json', '--po4', HEAD[m.group(1)], '--polar-select', POLAR,
                            '--cutoff', '0.75', '--polar-cutoff', '0.8'], check=True, capture_output=True)
            rec['Cz_builder'] = float(list(csv.DictReader(open(ob)))[0]['Cz'])
            parts = []
            for i, x in enumerate(xtcs):
                o = os.path.join(a.out, 'series', f'{b}.part{i}.csv')
                subprocess.run([sys.executable, AN, os.path.join(a.inputs, b, 'start.gro'), x, '--out', o, '--summary', o + '.json',
                                '--po4', HEAD[m.group(1)], '--polar-select', POLAR, '--cutoff', '0.75', '--polar-cutoff', '0.8'], check=True, capture_output=True)
                parts.append(o)
            rows, hdr, seen = [], None, set()
            for p in parts:
                R = list(csv.reader(open(p))); hdr = R[0]
                for r in R[1:]:
                    if r[0] not in seen: seen.add(r[0]); rows.append(r)
            if rows:
                rows.sort(key=lambda r: float(r[0]))
                with open(os.path.join(a.out, 'series', f'{b}.csv'), 'w') as f: f.write(','.join(hdr) + '\n' + '\n'.join(','.join(r) for r in rows) + '\n')
            json.dump(rec, open(os.path.join(a.out, 'series', f'{b}.src.json'), 'w'), indent=1)
            print(b, len(xtcs), 'xtc', len(rows), 'frames')

def run_record(out, b):
    m = NAME.match(b); s = os.path.join(out, 'series', f'{b}.csv'); src = json.load(open(os.path.join(out, 'series', f'{b}.src.json')))
    gate = json.load(open(src['gate_json'])) if src.get('gate_json') and os.path.exists(src['gate_json']) else None
    g = (gate or {}).get('verdict')
    r = dict(build=b, prim=m.group(1), w=m.group(2), seed=int(m.group(3)), start_gate=g or 'NO_GATE')
    if not os.path.exists(s): r.update(status='NO_PROD'); return r
    R = list(csv.DictReader(open(s))); t = np.array([float(x['t_ns']) for x in R]); col = lambda c: np.array([float(x[c]) for x in R])
    ncl, wd, wpol, Cz = col('ncl'), col('wind'), col('wpol'), col('Cz'); t = t - t[0]
    deg = bool(np.all(Cz < 1e-3)); hii = (wpol == 1) & (Cz <= CZ_MAX) & (not deg)
    t_hii = sustained(t, hii, HII_PERSIST_NS); T = float(t[-1])
    r.update(T_obs_ns=round(T, 1), n_frames=len(t), t0_reading='/'.join(str(int(x)) for x in (ncl[0], wd[0], col('npol')[0], wpol[0])),
             t_hii=t_hii, t_merge=sustained(t, ncl == 1, 5.0), t_wind3=sustained(t, wd == 3, 5.0), cz_degenerate=deg,
             Cz_builder=round(src['Cz_builder'], 3), Cz_t0=round(float(Cz[0]), 3), Cz_med_last100=round(float(np.median(Cz[t >= T - CZ_WIN_NS])), 3),
             rho_t0=round(float(Cz[0]) / src['Cz_builder'], 3), rho=round(float(np.median(Cz[t >= T - CZ_WIN_NS])) / src['Cz_builder'], 3),
             wpol_last=int(wpol[-1]), ncl_last=int(ncl[-1]),
             sens=';'.join(f'{c}/{q}:{sustained(t, (wpol == 1) & (Cz <= c) & (not deg), q)}' for c in (0.4, 0.5, 0.6) for q in (10.0, 20.0, 30.0)))   # 敏感性, 只描述
    if g != 'PASS': r['status'] = 'START_NOT_QUALIFIED'
    elif deg: r['status'] = 'CZ_DEGENERATE'
    elif t_hii is not None: r['status'] = 'EVENT'
    elif T >= T_EVAL_MIN_NS: r['status'] = 'NO_EVENT'
    else: r['status'] = 'TRUNC'
    r['evaluable_event'] = r['status'] in ('EVENT', 'NO_EVENT'); r['evaluable_cz'] = r['status'] in ('EVENT', 'NO_EVENT') and T >= T_EVAL_MIN_NS
    return r

def judge(a):
    builds = sorted(os.path.basename(p)[:-9] for p in glob.glob(os.path.join(a.out, 'series', '*.src.json')))
    runs = [run_record(a.out, b) for b in builds]; cells = {}
    for r in runs: cells.setdefault((r['prim'], r['w']), []).append(r)
    W = sorted({r['w'] for r in runs}); res = dict(prereg='PREREG_R4.md', constants=dict(CZ_MAX=CZ_MAX, HII_PERSIST_NS=HII_PERSIST_NS, T_EVAL_MIN_NS=T_EVAL_MIN_NS,
               N=N_PER_CELL, DOPE_MIN_EVENTS=DOPE_MIN_EVENTS, DOPC_MAX_EVENTS=DOPC_MAX_EVENTS, CZ_WIN_NS=CZ_WIN_NS, DELTA_RHO=DELTA_RHO, DELTA_CZ_ABS_descriptive=DELTA_CZ_ABS), hydration={})
    for w in W:
        ev = lambda p: [r for r in cells.get((p, w), []) if r['evaluable_event']][:N_PER_CELL]   # 按 seed 顺序取前 3 个可评估重复 (替补按链顺序补入)
        cz = lambda p: [r for r in cells.get((p, w), []) if r['evaluable_cz']][:N_PER_CELL]
        h = {}
        for p in ('DOPE', 'DOPC', 'MC3H', 'MC3'):
            e = ev(p); h[p] = dict(n_eval=len(e), n_event=sum(r['status'] == 'EVENT' for r in e), runs=[r['build'] for r in e])
        dope, dopc = h['DOPE'], h['DOPC']
        h['ruler_DOPE'] = 'NOT_EVALUABLE' if dope['n_eval'] < N_PER_CELL else ('PASS' if dope['n_event'] >= DOPE_MIN_EVENTS else 'FAIL')
        h['ruler_DOPC'] = 'NOT_EVALUABLE' if dopc['n_eval'] < N_PER_CELL else ('PASS' if dopc['n_event'] <= DOPC_MAX_EVENTS else 'FAIL')
        A, B = cz('MC3H'), cz('MC3')
        if len(A) < N_PER_CELL or len(B) < N_PER_CELL: c = dict(verdict='NOT_EVALUABLE', n_MC3H=len(A), n_MC3=len(B))
        else:
            a_, b_ = [r['rho'] for r in A], [r['rho'] for r in B]
            d = min(a_) - max(b_); rev = min(b_) - max(a_)
            v = 'PASS' if d >= DELTA_RHO else ('REVERSE' if rev >= DELTA_RHO else 'NO_SEPARATION')
            c = dict(verdict=v, rho_MC3H=a_, rho_MC3=b_, delta_rho=round(d, 3), reverse_delta_rho=round(rev, 3),
                     descriptive=dict(rho_t0_MC3H=[r['rho_t0'] for r in A], rho_t0_MC3=[r['rho_t0'] for r in B],
                                      Cz_last100_MC3H=[r['Cz_med_last100'] for r in A], Cz_last100_MC3=[r['Cz_med_last100'] for r in B],
                                      events_MC3H=sum(r['status'] == 'EVENT' for r in A), events_MC3=sum(r['status'] == 'EVENT' for r in B)))
        h['MC3_contrast'] = c
        rul = (h['ruler_DOPE'], h['ruler_DOPC'])
        if 'NOT_EVALUABLE' in rul or c['verdict'] == 'NOT_EVALUABLE': h['recipe'] = 'NOT_EVALUABLE'
        elif rul != ('PASS', 'PASS'): h['recipe'] = 'FAIL_RULER'
        else: h['recipe'] = 'PASS' if c['verdict'] == 'PASS' else 'FAIL_CONTRAST(' + c['verdict'] + ')'
        res['hydration'][w] = h
    keys = ['build', 'prim', 'w', 'seed', 'start_gate', 'status', 'T_obs_ns', 'n_frames', 't0_reading', 't_hii', 't_merge', 't_wind3', 'Cz_builder', 'Cz_t0', 'Cz_med_last100', 'rho_t0', 'rho', 'wpol_last', 'ncl_last', 'cz_degenerate', 'sens']
    with open(os.path.join(a.out, 'runs.tsv'), 'w') as f:
        f.write('\t'.join(keys) + '\n'); [f.write('\t'.join(str(r.get(k, '')) for k in keys) + '\n') for r in runs]
    json.dump(res, open(os.path.join(a.out, 'VERDICT.json'), 'w'), indent=1, ensure_ascii=False); print(json.dumps(res, indent=1, ensure_ascii=False))

if __name__ == '__main__':
    ap = argparse.ArgumentParser(); sp = ap.add_subparsers(dest='cmd', required=True)
    x = sp.add_parser('analyze'); x.add_argument('runs', nargs='+'); x.add_argument('--inputs', required=True); x.add_argument('--out', required=True)
    y = sp.add_parser('judge'); y.add_argument('out')
    a = ap.parse_args(); analyze(a) if a.cmd == 'analyze' else judge(a)
