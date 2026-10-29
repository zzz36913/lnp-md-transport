# PREREG_R4 — R4 4 晚菜谱扫描 · 预注册 (冻结于任何 R4 产出读出之前)

写成: 2026-10-29 (box, 发车前). 依据: 2026-10-29 17:37 K 通话决策 (9 条, 见 RUNBOOK). 判读代码: `D1/verdict_R4.py` (阈值写死为常量, 已入 MANIFEST)。
任何阈值/方向/窗口在看到 R4 prod 数据后改动 = 新预注册版本, 必须在报告里并列旧版结论。

## 1. 目标
找一份 Martini 3 介观菜谱 (水合 × 压浴 × 其它), 在其中 **两把尺子都对** (DOPE 进 H_II、DOPC 保持片层), 同时读出 **MC3H (质子化, +1, 低 pH) 与中性 MC3 的相行为差别**。
规则 1: 每格都跑 DOPE(+)、DOPC(−)、MC3H、MC3 四个体系; 不允许只靠 DOPE+DOPC 定菜谱。

## 2. 体系与起点 (D1)
- 每体系 960 脂 (2 双层 × 2 单层 × 240), 起始 APL 0.55 nm², 320 K, 全部片层起点 (规则 3)。MC3H 体系另加 960 Cl⁻ 中和。
- 力场: Martini 3.0.0 + PC_v2/PE_v2 + M3 可电离脂 `MC3_MC3H.itp` (GitHub M3_Ionizable_Lipids commit 9954b0f, sha256 797d2cfe…, MC3: N1 TN3a q=0; MC3H: NP TQ2p q=+1) + `lk_v1_macros.itp`。
- D1 水合: **w06 (6 W/脂) 与 w12 (12 W/脂)** 两点, 每格 N=3 (s1–s3) + 替补 s4 (k03)、s5 (k04)。
- 协议: EM → relax 15 ns (c-rescale semiiso τp=1, nstpcouple=2, dt 15 fs; R3 crescale_dev 原样) → 起点资格闸 → prod 500 ns (dt 20 fs, c-rescale semiiso τp=4, nstpcouple=5, 满足 2026.3 规则 τp ≥ 25·nstpcouple·dt = 2.5 ps)。

## 3. 读出与判据 (阈值写死)
冻结读数 (同 R3): ncl (尾连通分量, cutoff 0.75 nm), wind (尾最大分量绕数秩), wpol (polar 网络绕数秩, 0.8 nm), Cz (头珠 z 向层状对比度, 0.25 nm bin std/mean)。npol 只用于起点闸。**面内水通道只是辅助读数, 不是闸门。**
头珠: DOPE/DOPC = PO4; MC3/MC3H = GLA (两种电荷态同一珠型 SN4a, 可直接比)。polar = `name NH3 NC3 PO4 GL0 GL1 GL2 CNO or resname W CL NA` (对 DOPE/DOPC 与 R3 等价; MC3 头/酯珠不计入, 理由见 D1/proof/polar_choice.txt)。

| 项 | 判据 (常量) |
|---|---|
| 主事件 (R3 冻结) | wpol==1 且 Cz≤0.5, 持续 ≥20 ns |
| 可评估 run | 起点闸 PASS; 有事件, 或无事件且观测 ≥400 ns (否则 TRUNC, 不计) |
| 正尺 DOPE | 3 个可评估重复中 ≥2 个出事件 (500 ns 内) |
| 负尺 DOPC (阴性对照) | 3 个可评估重复中 0 个出事件 |
| MC3 读数 (每重复) | ρ = (prod 末 100 ns Cz 中位数) / (该 build 的 builder start.gro Cz, 同 analyzer 同参数) = 片层序保留比例 |
| MC3 对比 (方向写死) | **min(ρ_MC3H) − max(ρ_MC3) ≥ 0.2** → PASS (MC3H 比中性 MC3 保留更多片层序, 3 对 3 完全分离) |
| 反方向 | min(ρ_MC3) − max(ρ_MC3H) ≥ 0.2 → REVERSE, 不算通过, 单独标红上报 |
| 为何不用绝对 Cz | builder 起点 Cz 已因体系不同 (盒高/离子层) 而不同: MC3_w06 均值 1.447 (1.348–1.553) vs MC3H_w06 2.007 (1.961–2.089), 见 `D1/proof/cz_builder_baseline.tsv`; 绝对 Cz 差 0.4 只作描述 |
| 描述 (不判) | ρ_t0 (prod 第 0 帧), 末 100 ns 绝对 Cz, MC3/MC3H 各自主事件数 |
| 格 (水合点) 菜谱判定 | 两把尺 PASS 且 MC3 对比 PASS → RECIPE_PASS; 任一尺 FAIL → FAIL_RULER (不看 MC3); 任一体系可评估 N<3 → NOT_EVALUABLE |
| 敏感性 (只描述) | Cz {0.4,0.5,0.6} × 持续 {10,20,30} ns; ncl==1 / wind==3 持续 5 ns 的时刻 |

## 4. 起点资格 (start-point qualification)
- L1 (builder): start.gro 过 `gate/t0_gate.py` 2/2/2/2 @0.65/0.75/0.95 且 v1==v2 (阈值同 R3, 一字未改)。D1 40 个 build 全部 L1 PASS (`inputs/L1_summary.tsv`)。
- L2 (relax 后): 末 5 ns relax 帧逐帧同一闸门, 取最后合格帧作 prod 起点 (R3 TRR-AMEND 规则原样); 0 合格 → VOID_L2 (不是事件也不是删失), 按链顺序取同格替补。
- **DOPC 桥连问题**: R3 在 3 W/脂 下 DOPC 0/67 合格帧。R4 用 6 与 12 W/脂; box 上 15 ns relax 的逐帧证据见 `D1/proof/relax_box/` (结论写在 REVIEW_D1.md)。若某格 3+1 个起点全 VOID → 该格 NOT_EVALUABLE, 这本身是 "该水合下片层起点不可维持" 的结果, 上报, 不改闸门。
- 闸门负自检: 已知桥连帧 (R3 k04 DOPC_lam_s2 relax 末帧, sha d696d495…) 必须判不合格; launch_guard 每次发车前跑。

## 5. 阴性对照
- DOPC 即阴性对照 (不应出 H_II 事件)。
- 起点闸负自检 (上条)。
- MC3 对比按各 build 自身 builder 起点归一 (ρ), 消除起点几何差; ρ_t0 作描述, 用来看 relax 期间是否已分离。

## 6. 证伪条件
- 某水合下 DOPC ≥1/3 出事件 → 该菜谱的事件判据在此水合下不能区分 H_II 与片层 (尺子坏), 该水合淘汰。
- 某水合下 DOPE 0/3 或 1/3 出事件 (500 ns) → 该水合对 H_II 不敏感 (厚水抑制 stalk 的已知风险, 预先承认), 淘汰或延长时间须 K 决定。
- 两把尺都对而 MC3 NO_SEPARATION 或 REVERSE (ρ 判据) → "在此菜谱下 MC3 pH 相差别未被读出"; 不得改用别的读数事后宣称 PASS。
- 若所有水合都 FAIL_RULER → D1 结论为 "仅改水合不能同时满足两把尺", 进入 D2/D3 (水合细扫/压浴)。

## 7. 统计说明
3 对 3 的 Fisher 双侧最小 p = 0.100: 尺子判据是工程放行闸, 不是显著性检验。MC3 对比的 "完全分离 + ρ 差 ≥0.2" 也是放行规则; 0.2 是预设值, 未经标定 (R4 之前没有 MC3/MC3H 同协议数据); 帧不独立, 不用帧占比。
