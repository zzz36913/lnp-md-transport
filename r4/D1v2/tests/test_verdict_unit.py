#!/usr/bin/env python3
"""verdict_R4.py judge 单测 (合成序列, 只写 /tmp): D1v2: 默认 T=400 ns (= prod 全长 = T_EVAL_MIN_NS) + 400.0/399.5 边界; 覆盖 RECIPE PASS / FAIL_RULER / REVERSE / NO_SEPARATION / TRUNC / START_NOT_QUALIFIED. 退出码 0=全过."""
import json, os, subprocess, sys, tempfile
import numpy as np
D1 = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def mk(out, b, cz_end, event=False, T=400.0, gate='PASS', czb=2.0):
    os.makedirs(os.path.join(out, 'series'), exist_ok=True); g = os.path.join(out, 'g_' + b + '.json'); json.dump(dict(verdict=gate), open(g, 'w'))
    json.dump(dict(build=b, gate_json=g, Cz_builder=czb), open(os.path.join(out, 'series', b + '.src.json'), 'w'))
    t = np.arange(0, T + 1e-9, 0.5); cz = np.linspace(czb, cz_end, len(t)); wpol = np.full(len(t), 2)
    if event: cz[t >= 100] = 0.3; wpol[t >= 100] = 1
    with open(os.path.join(out, 'series', b + '.csv'), 'w') as f:
        f.write('t_ns,Lx,Ly,Lz,alpha,beta,gamma,ncl,n_largest,wind,Cx,Cy,Cz,npol,wpol\n')
        for i in range(len(t)): f.write(f'{t[i]},11,11,9,90,90,90,2,3840,2,0.2,0.2,{cz[i]},2,{wpol[i]}\n')
def run(case):
    out = tempfile.mkdtemp(prefix='r4vt_'); w = 'h050'
    for s in (1, 2, 3):
        mk(out, f'R4_DOPE_{w}_lam_s{s}', 0.3, event=case['dope'][s - 1]); mk(out, f'R4_DOPC_{w}_lam_s{s}', 1.9, event=case['dopc'][s - 1])
        mk(out, f'R4_MC3H_{w}_lam_s{s}', case['mc3h'][s - 1] * 2.0, czb=2.0); mk(out, f'R4_MC3_{w}_lam_s{s}', case['mc3'][s - 1] * 1.5, czb=1.5,
                                                                                T=case.get('T_mc3', 400.0), gate=case.get('gate_mc3', 'PASS'))
    subprocess.run([sys.executable, os.path.join(D1, 'verdict_R4.py'), 'judge', out], check=True, capture_output=True)
    return json.load(open(os.path.join(out, 'VERDICT.json')))['hydration'][w]
F, T_ = False, True; ok = True
cases = [
 ('recipe PASS', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55]), 'PASS'),
 ('DOPC 1 事件 -> FAIL_RULER', dict(dope=[T_, T_, T_], dopc=[F, T_, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55]), 'FAIL_RULER'),
 ('DOPE 1/3 -> FAIL_RULER', dict(dope=[T_, F, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55]), 'FAIL_RULER'),
 ('反向 -> REVERSE', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.5, 0.6, 0.55], mc3=[0.95, 0.9, 0.92]), 'FAIL_CONTRAST(REVERSE)'),
 ('重叠 -> NO_SEPARATION', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.7, 0.92], mc3=[0.5, 0.6, 0.75]), 'FAIL_CONTRAST(NO_SEPARATION)'),
 ('差 0.19 -> NO_SEPARATION', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.79], mc3=[0.5, 0.6, 0.6]), 'FAIL_CONTRAST(NO_SEPARATION)'),
 ('MC3 截断 300ns -> NOT_EVALUABLE', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55], T_mc3=300.0), 'NOT_EVALUABLE'),
 ('MC3 起点闸 VOID -> NOT_EVALUABLE', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55], gate_mc3='VOID'), 'NOT_EVALUABLE'),
 ('D1v2 MC3 恰 400.0 ns (prod 全长) -> 可评估 PASS', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55], T_mc3=400.0), 'PASS'),
 ('D1v2 MC3 399.5 ns (差最后一帧) -> NOT_EVALUABLE', dict(dope=[T_, T_, F], dopc=[F, F, F], mc3h=[0.95, 0.9, 0.92], mc3=[0.5, 0.6, 0.55], T_mc3=399.5), 'NOT_EVALUABLE'),
]
for name, c, want in cases:
    got = run(c)['recipe']; good = got == want; ok &= good; print(('PASS ' if good else 'FAIL ') + f'{name}: got {got} want {want}')
sys.exit(0 if ok else 1)
