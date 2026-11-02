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

## §7 收集
- 11-03 02:00 中途: `COLLECT=0 bash xfer_small/collect_small.sh $HOME/R4N5/R4N5_run_<机>_<TS>` (只收状态/日志/末帧).
- 11-03 07:00 收尾: `COLLECT=1 ...` (另跑冻结 collect + verdict_N5_wrap judge 草稿); 正式判读在 box 上 `python3 verdict_N5_wrap.py judge <out>` 再跑一遍.
