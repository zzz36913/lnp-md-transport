# R4 D1 运行包 — 4 体系 × 2 水合 × N=3 片层基线 (2 台 DGX Spark, 4 槽)

判据: `PREREG_R4.md` (= `../PREREG_R4.md` 的副本, sha 见 MANIFEST) · 判读: `verdict_R4.py` · 审查: `REVIEW_D1.md` · 校验: `MANIFEST_sha256.txt`

## 内容
| 路径 | 作用 |
|---|---|
| `run_R4.sh`, `lib_R4.sh` | 编排 (R3 MPS 双槽框架改写): 每机 A 槽 pin 15 / B 槽 pin 5, NT=5; relax 15 ns → 末 5 ns 逐帧闸门选起点 → prod 500 ns; DEADLINE 2026-10-30 07:30 +0800 |
| `chains/k0{3,4}_{A,B}.txt` | 主链 (每槽 6 条, 4 体系交错); `spares_k03` = s4, `spares_k04` = s5 (L2 VOID 时按格替补); `supp_*` 空 |
| `inputs/R4_<体系>_<w06|w12>_lam_s<1-5>/` | 40 个 build: start.gro, sys.top, index.ndx, 两个 mdp, expect.env, SYSTEM.txt, t0_builder.json |
| `inputs/L1_summary.tsv` | 40/40 builder 闸 PASS (2/2/2/2) |
| `ff/`, `inputs/ff/` | Martini 3.0.0 + PC_v2/PE_v2 + `MC3_MC3H.itp` (M3_Ionizable_Lipids 9954b0f) + `lk_v1_macros.itp` |
| `gate/` | R3 冻结闸门 (t0_gate.py 只改 polar 选择, 理由 `proof/polar_choice.txt`) |
| `verdict_R4.py` | `analyze` (逐 xtc 跑 analyzer) + `judge` (runs.tsv / VERDICT.json); 阈值写死 |
| `tests/test_verdict_unit.py` | 判读单测 8/8 |
| `proof/` | grompp -maxwarn 0 全量 (80/80), 负自检帧, polar 选择证据, builder Cz 基线, box relax 起点资格证据 |
| `tools/` | build_R4.py (造 build), l1_scan.sh, relax_scan.py, collect_R3_frozen.py (R3 读数参照), make_manifest.sh |

## 发车 (K 批准后; 本包不自行发车)
```bash
# Spark 上 (k03 与 k04 各一次), 包解到 ~/R4_pkg:
cd ~/R4_pkg && sha256sum -c --quiet MANIFEST_sha256.txt   # launch_guard 也会再查一次
CHECK=1 bash run_R4.sh k03          # 只跑 launch_guard, 不起 MPS/容器
PRIO=raised nohup setsid bash run_R4.sh k03 > ~/R4_k03.nohup 2>&1 &   # GLM 已停 → raised; 共机 → PRIO=low (默认)
# k04 同上
```
- 不改闸门/阈值; 速率实测后可在 `$HOME/R4/R4_perf_override.env` 写 `F_THR=0.9` 或 `PERF_NOM=...` (包外, 只影响补跑/替补的时间判断)。
- 收数 07:30 +0800 (prod `-maxh` 按剩余时间截断), 08:00 前机器停。
- 判读: `python3 verdict_R4.py analyze ~/R4/R4_run_k03_* ~/R4/R4_run_k04_* --inputs inputs --out results && python3 verdict_R4.py judge results`

## 容量 (估算)
PERF_NOM 13800 ns/day/槽 @12240 珠 (R3 实测附近), 按珠数线性缩放; relax 速率 ×0.75; 每条 +0.25 h 闸门/开销。
每槽 6 条链长 7.64–7.71 h (f=1.0) / 9.17–9.26 h (f=0.8)。全部 24 条 (每格 N=3) 跑满的最晚发车 = 07:30 − 链长 − 0.25 h:
**23:32 (f=1.0) / 21:59 (f=0.8), 均为估算**。替补需要额外 1.2–1.4 h/条。
