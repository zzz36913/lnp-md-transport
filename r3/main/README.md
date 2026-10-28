# R3 正式发车包 (R3_launch) — Open Science 方案 A 基准

状态: **未发车**. 只在 box 上写成; 未碰 Spark/GLM/端口/key/ZCode; 未上传 GitHub. 发车人: K (或 K 授权的父 agent).

## 1. 内容
`run_R3.sh <k03|k04>` 编排器 · `lib_R3.sh` 函数库 · `chains/` 链/替补/补跑队列 · `inputs/` 23 个 build (17 + 6 个 DOPE 备用, 见 §替补) 的 start.gro/sys.top/index.ndx/mdp/t0_builder.json + ff · `gate/` 起点资格闸 (原件 + 启动包装 `t0_gate_launch.py`, 判据一字未改) · `B1_warnings_expected.txt` (literal 臂 2 条警告原文) · `collect_R3.py`/`R3_contract.json` (后处理, 原样复制) · `MANIFEST_sha256.txt`.

## 2. 实验设计 (K 已拍板)
DOPE×5 + DOPC×5 片层, 960 脂 + 720 W, 320 K, 各 2 µs; PR 各向异性 tau_p=12, nstpcouple=3, v-rescale; 先 relax 15 ns → 读 t0_gate (2/2/2/2 @0.65/0.75/0.95, v1==v2) → prod. 闸门 G-R3: DOPE ≥4/5 出事件 (wpol==1 且 Cz≤0.5 持续 ≥20 ns) 且 DOPC 0/5.
槽位 (每机 2 槽, A=pin 15 / B=pin 5, NT=5, 共用用户态 MPS):
| 槽 | build (顺序 3 波) |
|---|---|
| k03_A | DOPE s2, s5, s14 |
| k03_B | DOPC s1, s3 → (第 3 波空) |
| k04_A | DOPE s3, s9 → (第 3 波空) |
| k04_B | DOPC s2, s4, s7 |
DOPE s1 已知 VOID_BUILD, 永不入队 (valid_name 拒绝).
**替补 (spares) — 2026-10-28 19:14 +0800 K 批准并入 6 个 DOPE 候选备用起点 (来源: K 在与 LNP MD 的对话中回复「按B走 并入 6 个 DOPE 备用」; 方案 spares_candidate_DOPE/PROPOSED_chains_merge.md; 并入时间约 19:28)。** 6 个均为 L1 PASS (2/2/2/2, 960/720, box gmx 2025.4 grompp 预检 maxwarn 0 通过); 并入只做"加": inputs/ 新增 6 个 build 目录, L1_summary_extra.tsv 追加 6 行, chains/spares_*.txt 被提案文件覆盖; A/B 链与 supp 未改。取用顺序即文件顺序 (100 步冒烟参考: s16/s23/s27 仍 2/2/2/2, s15/s22/s26 变 npol 3~4; 这只是 2 ps 参考筛, 实际 L2 以 15 ns relax 后读数为准)。
| 机 | spares (顺序=取用顺序) |
|---|---|
| k03 | DOPE s16, s27, s15; DOPC s8 |
| k04 | DOPE s23, s22, s26 (DOPC 无) |
DOPC s8 仅放 k03, 避免两机同取; 跨机重复由 launch_guard 拒绝。每个替补仍须满足 need+45 min 时间门槛, 且不看 prod 结果。

## 3. 发车判据 (全满足才发; `CHECK=1 bash run_R3.sh <机>` 自动查, 不满足 ABORT)
1. 上一批 (R2a/R2b/prerun) 机器日志显示 done; 2. `pgrep -a gmx` 为空且 60 s 后仍空; 3. 无 R2a/R2b/prerun/run_R3 脚本进程; 4. `docker ps` 无 `R2a_/R2b_/R3*/j009_` 容器; 5. 无 `nvidia-cuda-mps` 进程且 `~/mps_R3` 为空; 6. `sha256sum -c MANIFEST_sha256.txt` 全 OK; 7. 时间窗: 剩余 > 0, 且脚本给出"第 1 波可否跑满"提示; 8. 永不 `ALLOW_BUSY`; 9. gmx 版本 == 2026.3 (`EXPECT_GMX`); 10. 闸门依赖 (numpy/scipy/MDAnalysis) 可导入且自检 PASS (或 `GATE_MODE=manual`); 11. 开关一致性 (见 §4); 12. 输出目录不存在; 13. 链/替补/补跑里没有 A3/E1d/DOPE_s1 等禁用名, 无重复; 14. 磁盘 ≥5 GiB.
先 `DRY=1 bash run_R3.sh k03` 看计划与每条预计起止, 再 `CHECK=1`, 再正式. 两机各发一次 (k03、k04).

## 4. maxwarn 与 B1 路径 (逐步变量, 默认全 0)
| 步骤 | 变量 | 默认 | 说明 |
|---|---|---|---|
| relax grompp | `MAXWARN_RELAX` | 0 | `RELAX_ARM=crescale_dev` (默认, 开发臂: c-rescale semiisotropic tau_p=1 nstpcouple=2, **偏离 SI 协议, 报告必须标注**) 时必须 0. `RELAX_ARM=literal` 须同时 `MAXWARN_RELAX=2` + `K_APPROVED_LITERAL=yes`, 且 grompp 警告须与 `B1_warnings_expected.txt` 逐字一致 (忽略路径前缀与空白), 恰 2 条, 否则 `WARN_MISMATCH` + HALT |
| prod grompp | `MAXWARN_PROD` | 0 | 非 0 一律 ABORT (prod 的警告必须看见; 2026.3 的 PR/nstpcouple 已按 ≤3 满足) |
| 其它 | — | — | 无任何步骤隐式加 maxwarn; grompp 失败不重试不降级, 连续 2 次同类失败 HALT |

## 5. 流水线与不覆写
`run_build`: relax(15 ns, 0.75× prod 速率估时; lam 臂 relax 派生 mdp 多写 trr) → **select (末 5 ns 逐帧闸门, 取最后合格帧; [TRR-AMEND])** → gate (对选中帧复判) → prod. 目录 `R3_run_<机>_<TS>/builds/<build>/{relax,gate,prod}/attempt_NNN/` (mkdir 原子, STATUS 只写一次, 旧 attempt 永不改). 总账 `ALL_RECORDS.tsv` (19 列: ts, machine, slot, stage, build, role, arm_or_mdp, attempt_dir, state, gmx_version, maxwarn, grompp_rc, n_warn, mdrun_rc, laststep, performance_ns_day, remaining_h, need_h, note), 只 `>>`.
闸门结论: `PASS`(lam 2/2/2/2) / `NA_HII`(HII 臂豁免) / `VOID_L2`(不合格: **VOID_BUILD, 不是事件也不是删失**, 不进 prod, 进 `ledger/void`) / `GATE_TIMEOUT`(manual 模式没人给结论) / `GATE_ERROR`(执行错误 → HALT 整机).
prod: lam 臂 `SEL_RULE=1` (默认) 时 `-c <select 选中帧 selected.gro>` 且**不带 -t** (见 `PRE_REG_AMENDMENT_R3_trr.md`); 无选帧 (hii / SEL_RULE=0 / SEL_SKIP) 时旧行为 `-c relax.gro -t relax.cpt`. `-maxh=剩余−0.25 h`, 外层 `timeout rem+600`, 超时 `docker stop -t 120`. 被截断/中断后同 OUT 续跑 (`APPEND_TO=<OUT>`): 新 attempt `-s 旧 tpr -cpi 最新 cpt -noappend`.
主批: 剩余 < 0.6 h 的 build 记 `SKIP_NO_TIME`; 闸门后剩余 < 0.5 h 记 `SKIP_NO_TIME_PROD` (relax+gate 保留). 主批 build 若剩余不足 2 µs 所需, 会被 `-maxh` 截断 (`TRUNC`), 不会伪装成 DONE.

## 6. 补跑队列 (主批 10 条后, 空槽按优先级接; 只补 3 类, **不补 A3/E1d**)
1. **L2 替补轮**: 本机有 `VOID_L2` 的格 → 取 `spares_<机>.txt` 同格未用 build → relax+gate+prod (替补只看起点读数, 不看 prod 结果; 替补自己也可能 VOID, 再取下一个, 用尽则 `NO_SPARE`/`UNRESOLVED_VOID`).
2. **R3-H-DOPE 3×1µs** (HII 臂, `prod_hii`, 起点闸 N/A): `supp_k03`: DOPE_hii_s1, s3; `supp_k04`: DOPE_hii_s2.
3. **R3-H-DOPC 3×1µs**: `supp_k03`: DOPC_hii_s2; `supp_k04`: DOPC_hii_s1, s3.
**时间判断 (脚本里实现, `supp_fits`)**: 仅当 `剩余墙钟 ≥ 该作业 need_h + 0.75 h(45 min)` 且 `now + need_h < DEADLINE(2026-10-29 07:30 +0800)` 才领取; 否则记 `SUPP_SKIP_NO_TIME` 并看下一个候选 (更短的可能放得下). need_h = relax(15 ns/0.75P) + GATE_H 0.15 + prod(ns/P) + OVH_H 0.1; 名义 P=15188 ns/day/槽 (**未实测**), lam 约 3.44 h, hii 约 1.86 h. 补跑领取用 `ledger/claim` mkdir 原子互斥; `SUPP=0` 关闭补跑. 补跑只在本机内分摊 (跨机替补须人工).

## 7. 吞吐 f 的读取位置 (预跑结果出来后在这里改, 无需改脚本)
- `perf_eff` 每次调用: 名义 `PERF_NOM`(15188) × `F_THR`(默认 1.0), 再读 `$J/R3_perf_override.env` (默认 `~/R3/R3_perf_override.env`, 不在 MANIFEST 内; 写 `F_THR=0.8` 或 `PERF_NOM=14343` 即可, 下个领取/时间判断即生效), 再取与 `THROUGHPUT.tsv` 中 prod 最小实测 `Performance` 的较小者 (`USE_OBSERVED=1`, 默认).
- 实测值落在 `R3_run_<机>_<TS>/THROUGHPUT.tsv` (ts, build, stage, perf_ns_day, laststep, slot) 与 `ALL_RECORDS.tsv` 第 16 列.
- 敏感度: f=1.0 → 一条 lam ≈3.4 h; f=0.8 → ≈4.2 h; f=0.5 → ≈6.7 h (3 波 ≈10.2/12.7/20 h; 在 07:30 前 f≈0.8 起第 3 波会被 MAXH 截断).

## 8. 回收清单 (跑完/中止后)
1. `tail ALL_RECORDS.tsv`, `SUMMARY.tsv`, `UNRESOLVED_VOID` 行, `HALT` 文件是否存在; 2. 每 build 的 `prod/attempt_*/prod*.xtc|gro|cpt|log` 与 `gate/attempt_*/gate.json` (含 L2 读数) 打包; 3. `collect_R3.py` 用法见其头部; 4. 记录 `RUN_META.txt` (env+sha256); 5. 确认无残留: `pgrep gmx`, `docker ps | grep R3_`, `pgrep -a nvidia-cuda-mps`, `ls ~/mps_R3` (脚本 trap 会 stop 本脚本容器与自己起的 MPS); 6. 不 rm 任何 attempt; 7. 报告里写明 relax 臂 (crescale_dev 偏离 SI) 和任何 SKIP/TRUNC/VOID.

## 9. 需要 K 决定的开关
| 开关 | 默认 | 备注 |
|---|---|---|
| B1: `RELAX_ARM` | `crescale_dev` | 要 literal Berendsen 须 K 明确批准: `RELAX_ARM=literal MAXWARN_RELAX=2 K_APPROVED_LITERAL=yes` |
| 起点闸执行 | `GATE_MODE=host` (Spark 宿主 python 需 numpy/scipy/MDAnalysis, `GATE_PY=`) | 依赖缺 → `GATE_MODE=manual` (人在 `manual_gate/<build>.PASS|.VOID` 给结论) |
| `DEADLINE` | 2026-10-29 07:30 +0800 | 改了会同时改补跑/截断判断 |
| `SUPP` | 1 | 0=不补跑 |
| `REPLACE_ON_RELAX_FAIL` | 1 | relax 崩溃是否也当 VOID 换替补 |
| 发车时间 | — | 现在 (10-28 约 18:00) 到 deadline 约 13.5 h; 3 波名义 10.2 h 够, 晚到 ~21:00 后第 3 波可能放不下 → `DRY=1` 看 |
| DOPE 替补 | — | 每机 3 个 DOPE 备用 (k03 s16,s27,s15; k04 s23,s22,s26); 用尽后仍 void → 该格 n<5, 报告按 NOT_EVALUABLE; 再加 build 须 K 批 + box 上新建 |

## 9b. [TRR-AMEND 2026-10-28] 取起点规则 (增补; 判据阈值一个未改)
`SEL_RULE=1|0` (默认 1, 仅 lam) `SEL_NSTOUT=5000` (relax 的 nstxout=nstvout, 75 ps/帧) `SEL_WIN_PS=5000` (只看末 5 ns ≈ 67 帧) `SEL_KEEP_FRAMES=0` (prod 前删非选中帧 .gro). 输出 `builds/<b>/select/attempt_NNN/{SELECTED_FRAME.txt,frames.tsv,selected.gro,gate_frames/}`; STATUS=SEL_OK|SEL_NONE(0 合格 → VOID_L2)|SEL_SKIP(回退旧行为). 全文见 `PRE_REG_AMENDMENT_R3_trr.md` (含"看过 0/6 与诊断后才加"的声明与 DOPC 可能无合格起点的预期). 每个 lam build 的选帧闸门多耗约 4-6 min (67 帧 x ~3-5 s), 与 `GATE_H=0.15`(9 min, 2026-10-28 复审后由 0.1 上调, 仅影响 need_h 估计, 无超时用途) 同量级. 容器内 `trjconv` 经 stdin (`docker run -i`) 与 gmx 2026.3 未在 Spark 验证: `launch_guard` 5b 与小预跑 `../R3_relaxsel_pre` 先测. 测试: `tests/test_SEL_smoke.sh` (端到端) `tests/test_SEL_unit.sh` (假 trr 四种情形).

## 10. 未在 Spark / gmx 2026.3 上验证 (box 烟测只覆盖逻辑, gmx 为 box 2025.4, MODE=local, nsteps=100, NT=2)
- `MODE=docker` 全分支 (`docker run --gpus all`, `-u`, GMXLIB, `docker stop`), MPS 启停与 pin 偏移 (沿用 R2b 写法, 未再跑);
- gmx 2026.3 的 grompp 警告条数/文本 (literal 臂的 2 条警告在 2025.4 上与原文一致, 2026.3 未验证; c-rescale 开发臂 2026.3 grompp 未验证); `prod_hii` 在 2026.3 上未跑;
- Spark 宿主 python 依赖 (闸门) 未知; 闸门判据本身已在 box 上与原脚本比对 JSON 逐字相同 (builder 级), prod0 级在 relax 100 步帧上跑过 PASS;
- `-noappend` 续跑在真实 2 µs 截断上未验证 (box 只验证了逻辑与 attempt 不改);
- 真实吞吐 f、relax 耗时 (0.75× 为假设)、GPU 实际 `-nb gpu -update cpu` 性能;
- `GATE_MODE=host` 的 VOID 路径用 hii 起点冒充 lam 验证 (rc=3 → VOID_L2 → ledger/void); 真实 relax 后的 void 率未知.

## 独立审查修复 (PASS-WITH-FIXES, F1/F2) 与新增
- **F1** `launch_guard` 进程扫描改为 `procs_other` (lib_R3.sh): `ps -eo pid,ppid,args`, 排除本 shell、本 shell 的全部祖先 (ssh 外层 `bash -c '...run_R3.sh...'`)、全部后代 (子 shell / `$(..)` / ps / awk), 其余 args 命中 R2a/R2b/run_prerun/preflight_R3/run_R3.sh 者才算冲突. 另加 flock 防同机双开: `$J/.R3_<机>.flock` (fd 9, 进程退出自动释放, 不需要 rm); 真发车持有, CHECK/DRY 只探测.
- **F2** 所有 docker 容器名统一经 `cn_name`: `R3_<机>_<ORCH_PID>_<SLOT_TAG>_<后缀>`; `gp()` 的后缀 = `gp_<tag>_<build>_<attempt>`, `gx` 默认名用 `$BASHPID` (旧默认 `R3_x$$` 在两槽子 shell 里同名), `gmx_version` 同样. 全部落在 cleanup 的 `^R3_<机>_<pid>_` 范围内.
- **跨机重复护栏**: guard 检查两机全部 chains/*.txt 之间不得出现同一 build (账本只按机).
- `tests/test_F1F2_unit.sh`: 无 docker/gmx 的单元测试 (F1 不自命中/仍抓外部进程/flock; F2 假 docker 两槽并发取名唯一+前缀).
- `spares_candidate_DOPE/`: 候选 DOPE 备用起点 s15..s28 (14 个, 6 个 L1 PASS; L1 结果 L1_candidates.tsv, 100 步冒烟复筛 L1p5_smoke100.tsv, 并入提案 PROPOSED_chains_merge.md). 目录本身仍**不在 MANIFEST 内**; 其中 6 个 PASS build 已于 2026-10-28 约 19:28 (+0800) 经 K 19:14 批准并入 inputs/ 与 chains/spares_*.txt, 并已重生 MANIFEST。其余 8 个 VOID_BUILD 候选 (s17-21, s24, s25, s28) 未并入。
- 仍未验证: F1 在 Spark 真机 ssh/nohup 启动下的表现 (仅在 box 用模拟 ssh 外层测过); F2 只用假 docker 测过 (真 docker 对 `--name` 字符集/长度未测, 名字最长约 70 字符, docker 上限 128 内).

## 复审修订 (2026-10-28 ~20:00, 按 R3_launch_review_trr_1945.md M1-M4; 判据/阈值/gate/ 文件一字未动)
- **M1** `step_select`: 帧级闸门 rc 只有 0=合格, 3=不合格(VOID); 其他 rc 重试 `SEL_GATE_RETRY`(默认 2) 次, 仍失败该帧记 `ERR` (frames.tsv verdict=ERR, 不计合格); ERR 帧 > `SEL_ERR_MAX`(默认 3) -> 该 build `SEL_SKIP`, 按原路径末帧判 (step_gate 判 relax.gro, 合格则 -c relax.gro -t relax.cpt). 另检查窗口帧数≈SEL_WIN_PS/(SEL_NSTOUT*dt)(=66.7, 容差 1.5) 与末帧 t≈T(容差 1 帧间距), 不符写 `select/attempt_NNN/WARN.txt` 与日志 (不改行为).
- **M2** 选中帧须带速度 (`gro_has_vel`: 所有原子行定宽>=68 且速度字段非全零); 无速度的合格帧不选, 记 `novel_frames.txt`, 回退前一个合格帧; 全无 -> `SEL_NONE`.
- **M3** `step_prod` 起点 `selected.gro` 的 sha256 必须 = SELECTED_FRAME.txt 记录 = step_gate PASS 那次 `input.txt` 的路径+sha; 不一致 -> prod attempt `VOID_SEL_MISMATCH` (记 VOID_SEL_MISMATCH.txt, ledger void, 不 grompp).
- **GATE_H** 0.1 -> 0.15. **launch_guard 5c**: CHECK/发车前两槽同时 grompp (各槽首条 build, 派生 mdp, maxwarn 同正式) 自检, 须 rc=0 且 0 warning(crescale_dev). DRY 输出的 prod 命令行改为与实际一致.
- **M4 打包**: tar 排除 `__pycache__`/pyc 与 `spares_candidate_DOPE/` (备用起点 DOPE s15,s16,s22,s23,s26,s27 与 DOPC s8 已在 `inputs/` 且在 MANIFEST; chains/spares_k03: s16,s27,s15,DOPC s8; spares_k04: s23,s22,s26).
