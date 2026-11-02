# PREREG_N5 — R4N5「片层起点 DOPE/DOPC 对照」(第 5 包, 11-02 晚 → 11-03 06:50 UTC+8)

- 写于 2026-11-02 13:3x UTC+8 (box), 在任何 R4N5 作业起跑之前. 来源: K 2026-11-02 13:16 决定「今晚换层状起点，DOPE 和 DOPC 都从层状开始」.
- 冻结件逐字节沿用: `verdict_R4_3day.py` (sha256 4fd49504…908b2), `PREREG_R4_3day.md`, `PRE_REG_AMENDMENT_R4N1_01/02.md`, `gate/`, `FROZEN_sha256.txt` (包内 `sha256sum -c FROZEN_sha256.txt` OK).
- 本文件只**新增**规则; 不放宽任何已冻结的阈值或闸门. 凡标「估计」的数字都是估计, 不是测量.

## §1 问题
从**片层 (层状) 起点**出发, DOPE 会不会自己卷成管 (H_II 方向的事件), 而 DOPC 保持片层? 这是方法的阳性/阴性对照: DOPE 有负自发曲率、应能转; DOPC 不应转.

## §2 设计
| 项 | 值 |
|---|---|
| 条件格 | C4 = 350 K, h100 (同 R4N3/R4N4) |
| 体系 | DOPE 960 脂 + 3624 W (15144 珠); DOPC 960 脂 + 7800 W (19320 珠) — 第 1 晚 lam 构建原样 (R4 水合) |
| 起点 | `R4N1_{DOPE,DOPC}_h100_T350_lam_s{1..4}` (D2/N1x/inputs) 逐字节复制 → 改名 `..._lam_s50{1..4}` (百位 5 = 档 L5 LAMSEMI); start.gro/sys.top/index.ndx/itp 不变 |
| 与第 1 晚的差别 | 只有 (a) relax `gen_seed` 新值 (20301030 + cksum(name) % 100000; 速度另起, 轨迹独立于第 1 晚); (b) prod_lam `nsteps` 20 000 000 → 60 000 000 (400 → 1200 ns). prod `gen_seed` 也换了但 prod `gen_vel=no`, 不起作用 |
| n | 每种脂 3 个主种子 (s501–s503) + 1 个替补 (s504, 只顶起点级 VOID: VOID_BUILD / VOID_L2 / RELAX_FAIL / VOID_SEL_MISMATCH; 冻结 select_cell) |
| 机器 | k03 = DOPE ×3 (+替补), k04 = DOPC ×3 (+替补) |
| 流程 | relax 15 ns (relax_crescale_dev: c-rescale semiiso τp=1, nstpcouple 2, gen_vel yes, dt 0.015) → L2 片层闸门 (prod0 2/2/2/2, relax 末 5 ns 逐帧, 取最后合格帧) → prod_lam 1200 ns 单段 (dt 0.02, 每 1 ns 一帧) |
| 起点闸门 (冻结) | L1 builder 2/2/2/2 @ 0.65/0.75/0.95 (第 1 晚已过, L1_summary 全 PASS); L2 如上 |

## §3 加压方式 (prod) 与理由
`pcoupl = c-rescale, pcoupltype = semiisotropic, tau_p = 4.0, ref_p = 1.0 1.0, compressibility = 3e-4 3e-4, nstpcouple = 5` — 第 1 晚 / D1v2 冻结 prod_lam 原样 (包内 `level_sig 5`, 起跑前逐条核对).
理由: (1) 片层膜标准无张力系综 (膜面内与法向各自 1 bar); (2) 两向都可压, 片层 → 管状转变时盒子形状能跟着变, 不人为挡住转变; (3) 与第 1 晚 DOPC lam 3/3 NO_EVENT、DOPE lam s1 NO_EVENT (均 400 ns, 同加压) 直接可比; 本包唯一实质变化是时长 ×3. 不用 R4N4 的 AXFIX/PRXY/ISO 档 (那是管状起点的扫描).

## §4 时长与槽位 (估计)
- 每条 prod = 1200 ns. 起跑约 14:45, 收尾 06:50 (DEADLINE 写死在 lib 默认, 剩约 16 h).
- 单编排 MPS 实测吞吐 10669–13853 ns/day (旧包数据); 按珠数折算 (估计): DOPC 一条 1200 ns + relax + 闸门 ≈ 2.35–3.0 h, DOPE 更短.
- 槽位: 每机最多 2 槽, **2 槽只在 MPS 可用时**: B 槽每领新条前跑 x_mps_pick, 结果不是 own/own_started/own_restarted/join_main → B 槽不再领, A 槽照跑 (=1 槽). `X_MPS=off` → 只 1 槽.
- 估计: 2 槽 → 第 1、2 条约 17:15–17:45 完, 第 3 条约 19:35–20:45 完; 1 槽 → 三条约 7–9 h, 约 00:00 完. 两种都在 06:50 前. 余量很大; 是否把余量用来续跑 (例如再延长) 是 K 的决定, **不在本包内**, 本包不自动续跑.
- 时间判断 (冻结 lib): 补跑条只在 剩余 ≥ need + 0.75 h 且 now + need < DEADLINE 时领; 闸门后 prod 可用 < 0.5 h 不起.

## §5 读数与判定
单跑 (冻结 judge_lam_run, 不改): EVENT = wpol==1 且 Cz ≤ 0.5 连续 ≥ 20 ns (任何时刻); NO_EVENT = 无事件且 T_obs ≥ 400 ns; 其余 TRUNC; Cz 全 < 1e-3 → CZ_DEGENERATE (不可评估).
本包加一条 (只更严): 在 1200 ns 视界, NO_EVENT 还要 T_obs ≥ 1199 ns, 否则记 TRUNC_N5 (不可评估). EVENT 一旦成立就算 (时长单调).
格 (冻结 lam_cell_from_runs): n_eval ≥ 3 → EVALUABLE, 否则 NOT_EVALUABLE.

| 规则 | 内容 | 状态 |
|---|---|---|
| P 阳性 (新增) | DOPE 片层 EVALUABLE 且 EVENT ≥ 2/3 → PASS; EVALUABLE 且 ≤ 1/3 → FAIL; 否则 NOT_EVALUABLE | 冻结 PREREG 里 DOPE 片层不设门; 本条是新预注册的更严规则 |
| N 阴性 (= 冻结规则 3, DOPC_LAM_EVENTS_MAX = 0) | DOPC 选中跑里任一 EVENT → FAIL (不必等满 3 条); 否则 EVALUABLE (3 条满窗 NO_EVENT) → PASS; 否则 NOT_EVALUABLE | 原阈值不动 |

总判 (只用 1200 ns 视界; 400 ns 视界只作与第 1 晚对照的描述, 不进门):
- **CONTRAST_PASS**: P PASS 且 N PASS → 方法能分开 DOPE 与 DOPC (片层起点下 DOPE 自发成管, DOPC 不成).
- **NO_TRANSITION_IN_WINDOW**: P FAIL 且 N PASS → 片层起点在 1.2 µs 内不出管; 阴性对照干净, 但阳性对照没过.
- **METHOD_OVERDRIVEN**: N FAIL (不论 P) → 条件把 DOPC 也推成管, 方法过驱, DOPE 结果不解读.
- **NOT_EVALUABLE**: 其余 (任一格 n_eval < 3 且没触发 N FAIL).
描述读数 (不进门): 每条 t_event、t_merge (ncl==1 连续 ≥ 5 ns)、wpol_final; 400 ns 视界事件数.

## §6 证伪条件
- DOPE 0–1/3 事件 (满窗) → 「片层起点 1.2 µs 内能自发成管」被否.
- DOPC 任一事件 → 「本条件下 DOPC 保持片层」被否 → 方法不可信.
- 两者同时 → 方法失败.
- 不因结果改阈值、换视界、换种子或补跑非替补种子. 替补只按冻结 select_cell 顶起点级 VOID.

## §7 收集 (v2 改: 去掉 02:00, 改两个中途检查点)
- 11-02 ~20:30 与 11-03 ~01:00 中途 (分支检查点, §9): `COLLECT=0 bash xfer_small/collect_small.sh $HOME/R4N5/R4N5_run_<机>_<TS>` — 收状态/日志/末帧, 并尽力跑冻结 collect + `verdict_N5_wrap.py judge` (标 INTERIM; 未满 1200 ns 的跑一律 TRUNC, 不成立结论). 小包含每 run 相描述量时间序列 `collect/series/<build>.csv` (t_ns,ncl,wind,wpol,n_tube,Cz,C_max). 正在写的 xtc 末帧可能残缺 → 那次 collect 记 FAIL, 小包照出.
- 11-03 07:00 收尾: `COLLECT=1 ...` (冻结 collect + verdict_N5_wrap judge 草稿); 正式判读在 box 上 `python3 verdict_N5_wrap.py judge <out>` 再跑一遍.

---
# 增补 v2 (K 11-02 13:46 提出, 起跑前冻结; 不改 §1-§6 任何门槛)

## §8 加 MC3H (全质子化) 与中性 MC3 片层起点
- 配方与尺子逐字相同: 片层起点 (同 R4N1 lam start.gro/sys.top), 350 K, h100, relax 15 ns semi c-rescale + 同一 L2 闸门, prod_lam.mdp 档 5 (LAMSEMI) 1200 ns 单段. 每体系 n=3 (s501-503) + 替补 s504 (只顶 VOID). 由 `tools/derive_R4N5v2.py` 从 D2/N1x/inputs 派生, 只改种子 (gen_seed=20301030+cksum(name)%100000) 与温度相关三处 (ref_t, gen_temp, expect.env EXP_TEMP), 均断言.
- 队列 (每机, 顺序=优先级): k03 = DOPE s501-503 → MC3H s501-503; k04 = DOPC s501-503 → MC3 s501-503. 尺子先跑.
- 判读 (冻结 §5 Δ 规则移到片层臂, 同一阈值 DELTA_SEP=2): Δ_lam = n_EVENT(MC3) − n_EVENT(MC3H) (选中跑 = s1-3 + 替补, 冻结 select_cell). ≥+2 SEP_EXPECTED, ≤−2 SEP_REVERSE, 其余 NO_SEP.
  **只在 T350 尺子总判 = CONTRAST_PASS 且两格都 EVALUABLE 时判**; 尺子未过 → NOT_JUDGED, MC3 结果只作描述. 不新设阈值.
- 已知风险: D1v2 中性 MC3 片层 (320 K) 10/10 VOID_L2; 本档若同样全 VOID → 格 VOID → Δ NOT_EVALUABLE (照实报, 不改闸门).

## §9 半夜迭代分支 (检查点 ~20:30 与 ~01:00; 只换下一批跑什么, 不改任何门槛)
依据: 检查点的 INTERIM 判读 (§7). 选定后调度在各机写文件 `$HOME/R4N5/BRANCH` (内容 a|b|c), 运行器每次领新作业时现读; 分支队列排在主补跑队列之后. 默认无分支.
- (a) T350 尺子已出 CONTRAST_PASS (或 INTERIM 下 DOPE ≥2/3 EVENT 且 DOPC 0 事件): 加 MC3 种子 — k03 MC3H s505-507, k04 MC3 s505-507. 起点复用 lam_s1..s3 结构, 只换速度种子 (**不是新起点结构**). 只作描述 (事件比例); §8 的 Δ 仍只用 n=3 主格.
- (b) DOPE 无转变 (INTERIM: 已过 ≥400 ns 的 DOPE 跑都无事件) 且 DOPC 干净: 加压一档 **360 K** (DOPE+DOPC 对, 各 n=3 + 替补 s504; k03 DOPE, k04 DOPC). 理由: +10 K 是最小的一步加驱动 (与 330 档对称取小步); 只换温度, 加压/闸门/时长不变.
- (c) DOPC 出事件 (METHOD_OVERDRIVEN): 降一档 **330 K** (DOPE+DOPC 对, 各 n=3 + 替补). 理由: −20 K 明确降驱动, Martini 水在 330 K 远离冻结.
- 分支档用同一 P/N/总判规则单独判 (verdict_N5_wrap.py 输出 T360/T330 块), 只回答「该档尺子是否成立」, 不改 T350 结论, 不回头改 §5.
- 全部分支输入已在包里, 76 次 grompp (38 build × relax/prod) rc=0、0 警告 (selfcheck/grompp/SUMMARY.tsv).
- 若选分支时某机两槽已结束 (估计约 23:00 后): 用 `NEW_RUN=1 BRANCH=x ONLY="<分支格名, 如 DOPE_h100_T360_lam>" bash run_R4N5.sh <机>` 新起一次 (照常 CHECK 先过). 同一晚只选一个分支; 选择与时刻写进 RUNBOOK.

## §10 时间 (估计, DRY 按 PERF_NOM 珠数缩放, 非实测; 假设 14:45 起跑)
- 单条 need (含 relax+闸门+prod, 估计): DOPE 2.27 h, DOPC 2.82 h, MC3 2.82 h, MC3H 2.95 h; 每次领取另留 0.75 h 余量.
- 2 槽: k03 尺子约 19:20 跑完, MC3H 约 23:00 跑完; k04 尺子约 20:25, MC3 约 23:15. 06:50 前有约 7.5 h × 2 槽可给分支.
- 1 槽兜底: 尺子先跑, MC3 由 supp_fits 逐条判断能否在 06:50 前跑完, 估计每机只能再跑 2 条 MC3 → MC3 格 n=2 → Δ NOT_EVALUABLE (只描述).
