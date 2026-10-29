# REVIEW_D1 — R4 D1 运行包独立审查

审查时间 2026-10-29 18:4x +0800 (box `date`)。审查对象: 本目录 (MANIFEST 见 `MANIFEST_sha256.txt`)。判据: `PREREG_R4.md` (sha256 1e2c95d9…, 与 `../PREREG_R4.md` 相同)。

## 结论: **PASS-WITH-FIXES**
包本身可发车 (机械检查全部通过, 修复已在包内完成)。但有一条必须让 K 发车前知道的科学风险: **box 上 DOPC w06 的 relax 在 1.6 ns 后尾区桥连且不恢复, 末 5 ns 0/67 帧合格 → 按冻结规则 Spark 上 DOPC_w06 大概率 VOID_L2, w06 水合点大概率判 NOT_EVALUABLE**。w12 没有这个问题。闸门未放宽, 也不应放宽。

## 1. 已核实 (本次实测, 可复现)
| 项 | 结果 | 证据 |
|---|---|---|
| MC3 参数 | `ff/MC3_MC3H.itp` sha256 797d2cfe…34e011a5 = M3_Ionizable_Lipids commit 9954b0f 原文件; D1/ff、inputs/ff、40 个 build 全部一致。MC3: N1 TN3a q=0; MC3H: NP TQ2p q=+1 | MANIFEST, README |
| builder 闸 L1 | 40/40 PASS (2/2/2/2 @0.65/0.75/0.95), 最小分子间距 0.320–0.391 nm | `inputs/L1_summary.tsv` |
| grompp -maxwarn 0 | 80/80 rc=0, 0 warning, 各 1 note (verlet-buffer-pressure-tolerance 被忽略, 无害) | `proof/grompp_box/grompp_maxwarn0.tsv` |
| mdp | 40 个 build 的 mdp 与 `mdp/` 只差 gen_seed (每 build 唯一); prod dt 0.02, 25,000,000 步 = 500 ns, xtc 1 ns, c-rescale semiiso τp 4 (满足 τp ≥ 25·nstpcouple·dt) | 逐文件 diff |
| 链覆盖 | 4 条主链各 6 条 = 24, 8 格 × s1–s3 各恰好一次; 替补 k03 = s4 ×8, k04 = s5 ×8; 两机无重复 build (launch_guard 也查) | `chains/` |
| 全流程冒烟 | box 副本 MODE=local NT=1 NSTEPS=1000: launch_guard ALL OK (含 MANIFEST、闸门正/负自检、trjconv、双槽 grompp) → relax → select → gate → prod → summary 全部 rc=0。第一次因跨机重复 build 被 guard 拦下 (guard 正常工作), 改冒烟副本后通过 | `/tmp/r4smoke_J/R4_run_k03_1029_180212` (box, 不入包) |
| 闸门负自检 | 人工桥连帧必须判失败: 判失败 ✓ | `proof/neg_selftest_bridged.*` |
| 判读单测 | 8/8 PASS (PASS / FAIL_RULER×2 / REVERSE / NO_SEPARATION×2 / 截断 / VOID) — 本次复跑仍 8/8 | `tests/test_verdict_unit.py` |
| 判读在冒烟输出上 | 全部 TRUNC → NOT_EVALUABLE (正确, 1000 步不够 400 ns) | — |
| polar 选择 | DOPE/DOPC 与 R3 原闸门逐字等价; 不把 MC3 头/酯珠计入 polar (中性 MC3 头入油区是测量对象) | `proof/polar_choice.txt` |
| MC3 对比改为 ρ | builder 起点 Cz 本身就不同 (MC3_w06 均值 1.447 vs MC3H_w06 2.007), 绝对 Cz 差会把起点差当结果; 改为 ρ = 末 100 ns Cz 中位 / 本 build 起点 Cz, min ρ(MC3H) − max ρ(MC3) ≥ 0.2 判 PASS | `proof/cz_builder_baseline.tsv`, PREREG §3 |

## 2. DOPC 起点资格 (box relax, 每水合 N=1)
同包输入、同 relax mdp (只加 nstxout=nstvout=5000, 与 Spark SEL 规则相同的 75 ps 取帧), gmx 2025.4, 15 ns 全程每 75 ps 用包内闸门判一帧:

| build | 全程 PASS 帧 | 末 5 ns (10–15 ns) PASS 帧 | 最后 PASS 时刻 | 末 5 ns 主要读数 @0.65 (ncl/wind/npol/wpol) |
|---|---|---|---|---|
| R4_DOPC_w06_lam_s1 | 17/201 | **0/67** | 1.575 ns | 1/3/2/2 (37), 1/3/3/2 (25), 1/3/4/2 (4), 1/3/5/2 (1) |
| R4_DOPC_w12_lam_s1 | 69/201 | **21/67** | 14.400 ns | 2/2/2/2 (21), 2/2/3/2 (22), 2/2/4/2 (19), 2/2/5/2 (5) |

- w06: ncl=1 = 两层尾区连成一体 (桥连), 1.6 ns 后一直不恢复。builder 层面的"去桥连"已解决 (L1 40/40), 但**动力学上 w06 的 DOPC 会重新桥连, 这个问题在 w06 没有解决**。按冻结规则: 末 5 ns 无合格帧 → VOID_L2 → 用替补 → 替补也 VOID → DOPC_w06 N<3 → w06 判 NOT_EVALUABLE。
- w12: 尾区始终 2 层 (ncl=2); 不合格帧来自 npol>2 (水层出现分离的小水团), 末 5 ns 仍有 21 帧合格 → 选择规则可取到合格起点。
- 局限: N=1/水合, box 与 Spark 的 gmx 版本、线程数不同, 轨迹不会逐位相同; 这是预测, 不是 Spark 结果。
- 代价 (估算): VOID_L2 只花 relax (约 15 ns, 每条 ≲0.3 h) 就让出槽位, 不跑 prod, 不会拖垮整晚。
- 证据: `proof/relax_box/*_relax_scan.tsv|log`, `*_SOURCE.txt` (原始 trr sha256), `*_relax.mdp`。

## 3. 审查中做的修复 (都已在包内)
1. `PREREG_R4.md` 复制进 D1 (README 引用的副本之前不存在)。
2. `gate/__pycache__` 移到 `/tmp/r4_pycache_*` (运行产物, 不入包, 没有删除)。
3. `run_R4.sh` 第 108 行提示文字改为 "PREREG_R4 NOT_EVALUABLE/n<3" (只改文字)。
4. `verdict_R4.py` 不再 import `collect_R3_frozen.py` (那个文件 import 时会执行 argparse), 改为逐字复制 `sustained()`。
5. 敏感性分析 (Cz {0.4,0.5,0.6} × 持续 {10,20,30} ns) 之前 PREREG 有、代码没有, 已补上 (只做描述, 不进判定)。
6. 重新生成 MANIFEST, 并用 `sha256sum -c` 验证。

## 4. 剩余风险 (不阻塞发车, 发车前告知 K)
- **DOPC_w06 大概率 VOID → w06 NOT_EVALUABLE** (见 §2)。处理方式要 K 决定, 包内不改: (a) 按原样发车, 让 Spark 结果说话 (默认); (b) D2 换水合或 APL (例如 ~0.65) 再试。不放宽闸门。
- DOPE 正尺: R3 里 DOPE 5/5 按 Cz 仍是片层, 水是平面内通道 (RUNBOOK 13:40)。如果 R4 重复这个现象, 主事件 (wpol==1 且 Cz≤0.5 持续 ≥20 ns) 可能不出现 → FAIL_RULER。平面内水通道按 K 的要求只作辅助读数, 不进判定。
- 阈值 0.2 (ρ 对比) 是预设值, 没有标定; 一个格 N=3, Fisher 最小 p=0.100, 所以只能当放行门, 不能当显著性检验。
- 速率 PERF_NOM 是估算; 每条链最后一条可能被 07:30 截断 (例如 k03_A 最后的 DOPC_w12_s3), 截断后不到 400 ns 的无事件运行记 TRUNC。
- R2a 旧 `MC3H.itp` (sha d5a41620…) 和仓库任何文件都对不上; R4 不用它, R2a 结果与 R4 不可直接对比。

## 5. 发车须知 (未发车)
最晚发车 (估算): 23:32 (f=1.0) / 21:59 (f=0.8) +0800; 收数 2026-10-30 07:30, 08:00 前停机。GLM 已停 → 可用 `PRIO=raised`; 独占显存/重启须 K 批准。
