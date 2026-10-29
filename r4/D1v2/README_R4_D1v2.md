# R4 D1v2 运行包 — 4 体系 × 2 相对水合档 (h050/h100) × N=3 片层基线 (2 台 DGX Spark, 4 槽)

**D1v2 改动 (K 2026-10-29 18:52 拍板)**: 水合度从绝对 w06/w12 (6/12 水/脂) 改为相对水合度 = 各脂自身完全水合值 nW_full 的 50% / 100% (`HYDRATION_R4.md`: DOPC 32.5, DOPE 15.1 [H_II, 320 K 内插], MC3/MC3H 32.5 = DOPC 代理, 无实验锚点; 1 W 珠 = 4 水)。理由: D1 的 w06 对 DOPC 只有 18% 相对水合, R3/D1 box relax 里低水 DOPC 尾链桥连 (ncl=1)。体系变大 (13332–20280 珠) → prod 500 → **400 ns** (= T_EVAL_MIN_NS, 阈值未改), 以便 24 条在 07:30 前跑完。D1 (`../D1/`, GitHub r4/D1/) 原样保留未动。

判据: `PREREG_R4.md` (v2: 在 D1 版上只改水合定义与 prod 长度, 阈值全部未改) · 水合: `HYDRATION_R4.md` · 判读: `verdict_R4.py` · 审查: `REVIEW_D1v2.md` · 校验: `MANIFEST_sha256.txt`

## 内容
| 路径 | 作用 |
|---|---|
| `run_R4.sh`, `lib_R4.sh` | 编排 (R3 MPS 双槽框架改写): 每机 A 槽 pin 15 / B 槽 pin 5, NT=5; relax 15 ns → 末 5 ns 逐帧闸门选起点 → prod 400 ns; DEADLINE 2026-10-30 07:30 +0800 |
| `chains/k0{3,4}_{A,B}.txt` | 主链 (每槽 6 条, 4 体系交错); `spares_k03` = s4, `spares_k04` = s5 (L2 VOID 时按格替补); `supp_*` 空 |
| `inputs/R4_<体系>_<h050|h100>_lam_s<1-5>/` | 40 个 build: start.gro, sys.top, index.ndx, 两个 mdp, expect.env, SYSTEM.txt, t0_builder.json |
| `inputs/L1_summary.tsv` | 40/40 builder 闸 PASS (2/2/2/2) |
| `ff/`, `inputs/ff/` | Martini 3.0.0 + PC_v2/PE_v2 + `MC3_MC3H.itp` (M3_Ionizable_Lipids 9954b0f) + `lk_v1_macros.itp` |
| `gate/` | R3 冻结闸门 (t0_gate.py 只改 polar 选择, 理由 `proof/polar_choice.txt`) |
| `verdict_R4.py` | `analyze` (逐 xtc 跑 analyzer) + `judge` (runs.tsv / VERDICT.json); 阈值写死 |
| `tests/test_verdict_unit.py` | 判读单测 10/10 (含 D1v2 400.0/399.5 ns 边界) |
| `proof/` | grompp -maxwarn 0 全量 (80/80, 另 prod 400 ns 版 40/40 重做: `grompp_box/grompp_prod400_maxwarn0.tsv`), 负自检帧, polar 选择证据, builder Cz 基线, box relax 起点资格证据 (`relax_box/`: 每体系每档 s1 一条 15 ns relax, 末 5 ns 逐帧闸门) |
| `tools/` | build_R4.py (造 build, `--tier 50|75|100|150`), l1_scan.sh, relax_scan.py (`--t-min-ns`), collect_R3_frozen.py (R3 读数参照), make_manifest.sh |

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
PERF_NOM 13800 ns/day/槽 @12240 珠 (R3 实测附近), 按珠数线性缩放; relax 速率 ×0.75; 每条 +0.25 h 闸门/开销。每条 (relax 15 ns + prod 400 ns) 估算: DOPC h100 1.40 h, h050 1.17; DOPE h100 1.15, h050 1.05; MC3 h100 1.40, h050 1.17; MC3H h100 1.46, h050 1.23。
每槽 6 条链长 7.40–7.71 h (f=1.0) / 8.88–9.26 h (f=0.8)。全部 24 条跑满的最晚发车 = 07:30 − 链长 − 0.25 h:
**23:32 (f=1.0) / 21:59 (f=0.8), 均为估算**。22:00 发车 → f=1.0 约 05:42 完, f=0.8 约 07:15 完 (估算)。替补每条另需 1.05–1.46 h (估算)。
若赶不上: 先保 h100 档 12 条 (K 优先), 不放宽任何闸门/阈值。

## box 起点资格预跑 (每体系每档 s1 一条, 15 ns relax, 末 5 ns 67 帧逐帧用包内闸门; box gmx 2025.4, 不是 Spark 结果)
| build | 合格帧/67 | 最后合格 | ncl=1 帧 | 末帧盒子 Lx×Lz nm | 预测 |
|---|---|---|---|---|---|
| DOPC_h050_s1 | 18 | 13.875 ns | 0 | 12.67×10.62 | SEL_OK |
| DOPC_h100_s1 | 13 | 13.575 ns | 0 | 12.75×13.49 | SEL_OK |
| DOPE_h050_s1 | 20 | 13.275 ns | 0 | 12.16×9.67 | SEL_OK |
| DOPE_h100_s1 | 23 | 14.625 ns | 0 | 12.52×10.53 | SEL_OK |
| MC3H_h050_s1 | 18 | 14.475 ns | 0 | 12.90×9.27 | SEL_OK |
| MC3H_h100_s1 | 4 | 15.000 ns | 0 | 13.29×11.38 | SEL_OK |
| MC3_h050_s1 | 0 | – | 0 | 3.13×165.5 | VOID_L2 |
| MC3_h100_s1 | 0 | – | 0 | 3.15×211.6 | VOID_L2 |

- DOPC 两档都不桥连 (末 5 ns 67 帧中 ncl=1 的帧为 0), 所以不需要改到 75%/150% 档。不合格帧全是 npol=3–6 (个别 W 珠离开水层被算成单独极性组分), 闸门照原样判, 未放宽。
- 中性 MC3 两档都 0/67: 半各向同性 c-rescale 下盒子侧向塌缩 (Lx 11.5 → 3.1 nm, Lz → 165–212 nm)。诊断 (不进包判据): 固定面积 relax 下 0.75 ns 内就尾区桥连 (ncl=1), 见 `proof/relax_box/DIAG_MC3_h050_fixedarea_scan.tsv`。预测: Spark 上 MC3 主跑与替补都 VOID_L2 → MC3 对比 NOT_EVALUABLE → 两档菜谱判定都是 NOT_EVALUABLE; DOPE/DOPC 两把尺与 MC3H 仍可评估。VOID 的条不跑 prod, 不拖时间。是否改 MC3 起点/协议须 K 决定 (要新的预注册修订), 本包不改。
- 证据文件: `proof/relax_box/RELAX_BOX_SUMMARY.tsv`, `*_relax_scan_last5ns.tsv`, `*_SOURCE.txt` (trr sha256, seed, 命令), `RELAX_BOX_DIMS.tsv`。
