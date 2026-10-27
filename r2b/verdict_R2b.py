#!/usr/bin/env python3
"""R2b 读数 (= verdict_R2a.py 的派生: 名字/目录兼容 R2a_* 与 R2b_*, 判据与臂规则逐字沿用, 只在末尾加 n=3 合并读法; 须放在 /workspace/lnp-md/scan/R2b/ 下运行, 与 R2a 同约定)。
R2a 读数 (dd/56 预注册; 不改冻结的 verdict_j009.py, 只 import 它的 frame_class/inplane/analyse 与常数)。用 /workspace/viz-venv/bin/python。
体系名: R2a_<DOPE|DOPC|MC3H>_<lam|hii>_s<1|2>。
每条 run: 取【可得轨迹最后 20% 的帧】(窗), 每帧用 verdict_j009.frame_class (W 珠 64³ CIC→水簇连通/卷绕, 与轴无关) 分 LAM/HII/NET/OTHER:
  H_II  = HII 帧占比 >= 0.8 且同一轴 且 面内有序 (S1>=25, 衬度>=8) 占比 >= 0.8 且 d_NN 与 a_pred 偏差<=15% 占比 >= 0.8   (= j009 'HII' 判据, 常数取自 verdict_j009 TOPO_SURV 等)
  LAM   = LAM 帧占比 >= 0.8
  OTHER = 其余 (HII_TOPO_ONLY / NET / DISORDERED / MIXED 细分写在 end 字段)
  UNREADABLE = 任一帧 BOXCOLLAPSE(<2.2 nm) 或 BOXDEFORM(最长/最短边>3);  TOO_SHORT = 可得时长 < 目标的 50% 或窗内 < 5 帧 (被 -maxh/deadline 截断且不足一半 → 不判)
起点检查: 首帧类别须与起点一致 (lam→LAM, hii→HII) 否则 BADSTART。
臂规则 (预注册, dd/56 §P3): DOPE_lam: 通过=H_II; DOPE_hii: 通过=H_II(留在 H_II); DOPC_lam: 通过=LAM(任何 H_II=假阳性); DOPC_hii(保守读法 A): 通过=LAM(塌成片层); H_II 留住=假阳性; OTHER=未定. 读法 B(备查, 不入门): DOPC_hii 不设约束.
门: 四臂(DOPE/DOPC × lam/hii) × n=2: 全部 2/2 通过 → PASS; 任一 DOPC 条出 H_II(假阳性) 或 任一 DOPE 臂 0/2 → FAIL; 其余 → UNDECIDED. MC3H_lam 单独报告, 不入门.
用法: verdict_R2a.py --selftest | --dir <含 <name>/out/prod.xtc+prod.tpr 的目录> | --run <name>=<W珠多帧.gro> [...] [--json out.json]
"""
import argparse, glob, json, os, re, subprocess, sys, tempfile
import numpy as np
HERE = os.path.dirname(os.path.abspath(__file__)); SC = os.path.dirname(HERE); sys.path.insert(0, SC); sys.path.insert(0, os.path.join(SC, 'ana'))
import verdict_j009 as V9
import omega_sq as O
TOPO, ORD, DNN = V9.TOPO_SURV, V9.N10_SURV, V9.DNN_TOL
WIN_FRAC = 0.20; MIN_COVER = 0.5; MIN_FR = 5
TARGET_NS = {'lam': 2000.0, 'hii': 1000.0}
NAME = re.compile(r'^R2[ab]_(DOPE|DOPC|MC3H)_(lam|hii)_s(\d)$')
def window_verdict(ts, R, geom):
    tgt = TARGET_NS[geom] * 1000.0
    if not ts: return dict(verdict='TOO_SHORT', why='无帧')
    cover = ts[-1] / tgt
    if cover < MIN_COVER: return dict(verdict='TOO_SHORT', why='可得 %.0f ns = 目标的 %.0f%% < %.0f%%' % (ts[-1] / 1000, 100 * cover, 100 * MIN_COVER), cover=cover)
    t0 = ts[0]; t1 = ts[-1]; lo = t1 - WIN_FRAC * (t1 - t0); k = [i for i, t in enumerate(ts) if t >= lo]; W = [R[i] for i in k]
    if len(W) < MIN_FR: return dict(verdict='TOO_SHORT', why='窗内仅 %d 帧' % len(W), cover=cover)
    fr = {c: float(np.mean([x['cls'] == c for x in W])) for c in ('LAM', 'HII', 'NET', 'OTHER')}
    ax = [x['axis'] for x in W if x['cls'] == 'HII']; same = len(set(ax)) <= 1
    ordf = float(np.mean([x['cls'] == 'HII' and x['strong'] for x in W])); dnf = float(np.mean([x['cls'] == 'HII' and x['dNN_dev'] <= DNN for x in W]))
    d = dict(frac=fr, ord_frac=ordf, dnn_ok_frac=dnf, nwin=len(W), win_ns=[round(W[0] and ts[k[0]] / 1000, 1), round(t1 / 1000, 1)], cover=round(cover, 3), start_cls=R[0]['cls'],
             edge_end=[round(v, 2) for v in W[-1]['box']], ncl_end=W[-1]['ncl'], truncated=bool(cover < 0.99))
    if any(x['edge_min'] < V9.RC_BOX for x in R) or any(x['edge_ratio'] > V9.BOXDEFORM for x in R): d['verdict'] = 'UNREADABLE'; d['why'] = '盒形异常'; return d
    if R[0]['cls'] != {'lam': 'LAM', 'hii': 'HII'}[geom]: d['verdict'] = 'BADSTART'; d['why'] = '首帧 %s' % R[0]['cls']; return d
    if fr['HII'] >= TOPO and same and ordf >= ORD and dnf >= TOPO: v, e = 'H_II', 'HII'
    elif fr['LAM'] >= TOPO: v, e = 'LAM', 'LAM'
    elif fr['HII'] >= TOPO and same: v, e = 'OTHER', 'HII_TOPO_ONLY'
    elif fr['NET'] + fr['OTHER'] >= 0.5 and fr['HII'] < 0.2 and fr['LAM'] < 0.2: v, e = 'OTHER', 'DISORDERED'
    else: v, e = 'OTHER', 'MIXED'
    d['verdict'] = v; d['end'] = e; d['why'] = 'LAM=%.2f HII=%.2f NET=%.2f OTHER=%.2f 有序=%.2f d_ok=%.2f' % (fr['LAM'], fr['HII'], fr['NET'], fr['OTHER'], ordf, dnf); return d
def arm_pass(lip, geom, v, truncated=False):
    """返回 (pass|fail|undecided|false_positive)"""
    if v in ('TOO_SHORT', 'UNREADABLE', 'BADSTART', 'ERROR'): return 'undecided'
    if truncated and v == 'LAM' and (lip == 'DOPE' or geom == 'lam'): return 'undecided'   # 评审: dd/56 P2 '截断的片层读数仍是 LAM 不算强证据' (<99% 目标)
    if lip == 'DOPE': return 'pass' if v == 'H_II' else ('undecided' if v == 'OTHER' else 'fail')
    if lip == 'DOPC' and geom == 'lam': return 'false_positive' if v == 'H_II' else ('pass' if v == 'LAM' else 'undecided')
    if lip == 'DOPC' and geom == 'hii': return 'false_positive' if v == 'H_II' else ('pass' if v == 'LAM' else 'undecided')
def gate(res):
    arms = {}; fp = False; dope_zero = False
    for lip in ('DOPE', 'DOPC'):
        for geom in ('lam', 'hii'):
            st = [arm_pass(lip, geom, r['verdict'], r.get('truncated', False)) for n, r in res.items() if NAME.match(n) and NAME.match(n).group(1) == lip and NAME.match(n).group(2) == geom]
            arms['%s_%s' % (lip, geom)] = st; fp |= 'false_positive' in st
            if lip == 'DOPE' and len(st) == 2 and st.count('pass') == 0 and 'undecided' not in st: dope_zero = True
    allpass = all(len(s) == 2 and s.count('pass') == 2 for s in arms.values())
    return dict(arms=arms, status='PASS' if allpass else 'FAIL' if (fp or dope_zero) else 'UNDECIDED', false_positive=fp, dope_arm_0of2=dope_zero)
def merge3(res):
    """n=3 合并: 每臂列出 s1,s2,s3 的 arm_pass 状态; 全同且无 undecided → 一致, 否则 不一致 (缺条/未定 → 不一致(缺或未定))。不下统计结论。"""
    arms = {}; dopc_hii = False; dope_lam = 0
    for lip in ('DOPE', 'DOPC'):
        for geom in ('lam', 'hii'):
            per = {}
            for n, r in sorted(res.items()):
                m = NAME.match(n)
                if m and m.group(1) == lip and m.group(2) == geom: per['s' + m.group(3)] = arm_pass(lip, geom, r['verdict'], r.get('truncated', False))
                if m and lip == 'DOPC' and m.group(1) == 'DOPC' and r['verdict'] == 'H_II': dopc_hii = True
                if m and lip == 'DOPE' and geom == 'lam' and m.group(1) == 'DOPE' and m.group(2) == 'lam' and r['verdict'] == 'H_II': dope_lam += 1
            vals = list(per.values()); ok = len(vals) == 3 and len(set(vals)) == 1 and 'undecided' not in vals
            arms['%s_%s' % (lip, geom)] = dict(per_run=per, consistency='一致' if ok else ('不一致' if len(vals) == 3 and 'undecided' not in vals else '不一致(缺条或有未定)'))
    return dict(arms=arms, dopc_any_HII=dopc_hii, dope_lam_HII=dope_lam)
def W_from_run(name, d, tmp):
    o = os.path.join(d, name, 'out'); xtc = os.path.join(o, 'prod.xtc'); tpr = os.path.join(o, 'prod.tpr'); out = os.path.join(tmp, name + '_W.gro')
    subprocess.run(['gmx', 'trjconv', '-s', tpr, '-f', xtc, '-o', out], input='W\n', text=True, capture_output=True)
    if not os.path.exists(out): raise RuntimeError('trjconv 失败 ' + name)
    return out
def selftest():
    """零 GPU 校准 (dd/56 §P5): (1) 冻结 verdict_j009 的 J005 真数据自证 (POS_HII→HII, NEG/T100_bil→LAM ...); (2) R2a 自己的 EM 后起点: lam→LAM, hii→HII (H_II 起点还须 强有序+d_NN 吻合 → H_II)。"""
    ok = V9.selftest(); lines = []
    for n in sorted(glob.glob(os.path.join(HERE, 'emchk', 'R2b_*', 'em.gro'))):
        nm = n.split('/')[-2]; m = NAME.match(nm); ts, R = V9.analyse(n); geom = m.group(2)
        exp = {'lam': 'LAM', 'hii': 'HII'}[geom]; r = R[0]; good = r['cls'] == exp and (geom == 'lam' or (r['strong'] and r['dNN_dev'] <= DNN)); ok &= good
        lines.append('%-18s EM后 期望 %-3s 实得 %-3s %s → %s' % (nm, exp, r['cls'], ('S1=%.0f 衬度=%.0f dNN=%.2f a_pred=%.2f' % (r['S1'], r['contrast'], r['dNN'], r['a_pred'])) if r['cls'] == 'HII' else '', 'PASS' if good else 'FAIL'))
    print('\n'.join(lines)); print('R2A_SELFTEST', 'PASS' if ok else 'FAIL'); return ok
def main():
    ap = argparse.ArgumentParser(); ap.add_argument('--selftest', action='store_true'); ap.add_argument('--dir'); ap.add_argument('--run', nargs='*'); ap.add_argument('--json')
    a = ap.parse_args()
    if a.selftest: sys.exit(0 if selftest() else 1)
    tmp = tempfile.mkdtemp(prefix='r2av_'); items = []; res0 = {}
    if a.dir:
        for p in sorted(glob.glob(os.path.join(a.dir, 'R2[ab]_*', 'out', 'prod.xtc'))):
            n = p.split('/')[-3]
            try: items.append((n, W_from_run(n, a.dir, tmp)))
            except Exception as e: res0[n] = dict(verdict='ERROR', why='读轨迹失败: %s' % e)   # 评审: 缺 prod.tpr 等不得让整个脚本崩
    for g in a.run or []: n, p = g.split('=', 1); items.append((n, p))
    res = dict(res0)
    for n, gro in items:
        m = NAME.match(n)
        if not m: res[n] = dict(verdict='ERROR', why='名字不合'); continue
        try: ts, R = V9.analyse(gro); res[n] = window_verdict(ts, R, m.group(2)); res[n]['t_end_ns'] = ts[-1] / 1000 if ts else None
        except Exception as e: res[n] = dict(verdict='ERROR', why='分析失败: %s' % e)
    for n, r in res.items(): print('%-20s %-10s %s' % (n, r['verdict'], r.get('why', '')))
    res2a = {n: r for n, r in res.items() if n.startswith('R2a_')}; G = gate(res2a); print('\nGATE(DOPE/DOPC 四臂 n=2, 仅 R2a_* 条, 预注册原门)=%s  臂=%s  假阳性=%s' % (G['status'], G['arms'], G['false_positive']))
    merged = merge3(res)
    print('\nR2b 合并读 (R2a s1,s2 + R2b s3; n=3 仍不足以做统计结论, 只报 一致/不一致):')
    for arm, v in merged['arms'].items(): print('  %-10s %s  → %s' % (arm, v['per_run'], v['consistency']))
    print('  DOPC 任一 run 出 H_II(假阳性, 继承门=失败): %s ; DOPE_lam 出 H_II 的条数: %s' % (merged['dopc_any_HII'], merged['dope_lam_HII']))
    mc = {n: r['verdict'] for n, r in res.items() if '_MC3H_' in n}; print('MC3H 片层臂(单独报告, 不入门)=%s' % mc)
    if a.json: json.dump(dict(runs=res, gate_R2a_only_n2=G, merged_n3=merged, mc3h=mc), open(a.json, 'w'), indent=1, ensure_ascii=False, default=float)
if __name__ == '__main__': main()
