# REVIEW_D1v2 — R4 D1v2 (相对水合度) 发车包独立审查
审查时间 2026-10-29 20:20 SGT; 审查人: executor 子代理 (与打包者同一会话, 但换角度: 不重读 D1 审查结论, 逐项从文件/命令输出重新核对)。只在 box 上做, 未碰 Spark/GLM。

## 结论: **PASS-WITH-FIXES** (包可上传、可发车; 有 1 个须 K 知情的大问题 M1, 不阻挡发车)

## 本次审查的角度 (与 REVIEW_D1 不同)
REVIEW_D1 看的是 "包能否在 Spark 上跑通"。本审查主要问: **改成相对水合度后, 每一个数字是否能从源头追到文件里, 以及新水量下起点闸门是否真的能放行各体系** (用 box 上实跑的 relax 来回答, 而不是推理)。

## 逐项核对
| # | 检查 | 方法 | 结果 |
|---|---|---|---|
| 1 | nW_full 有出处 | HYDRATION_R4.md 每值带论文/DOI/温度; MC3/MC3H 明标 "代理, 无实验锚点" | OK |
| 2 | W 珠数 = 脂数 × nW_full × 档 / 4 | 逐 build 读 start.gro 的 W/CL 计数和 expect.env | OK: DOPC 7800/3900, DOPE 3624/1812, MC3 7800/3900, MC3H 7800/3900 (+960 CL), 40/40 build 与表一致 |
| 3 | 网格 4×2×3=24 + 替补 | chains/*.txt 去注释计数 | 主链 6+6+6+6=24, 每格恰 3 条 (s1–s3) 且分在不同槽; 替补 8+8=16 (s4@k03, s5@k04); supp 空 |
| 4 | 判据常数未改 | `diff D1/verdict_R4.py D1v2/verdict_R4.py` | 只差 NAME 正则 (w\d\d → h\d\d\d) 和一处用法注释; T_EVAL_MIN_NS=400、事件定义、尺子与对比阈值一字未改 |
| 5 | 闸门/力场/gatewrap 未改 | `diff -rq` 对 D1 | 完全一致 (gate/__pycache__ 已移出, 不进包) |
| 6 | lib/run 只改名字 | 把 D1 的 w06/w12 替换为 h050/h100 后 diff | 只剩注释与名字正则 (h[0-9]{3}); cell_of 对 40 个 build 全部解析正确, 0 个 bad |
| 7 | grompp -maxwarn 0 | proof/grompp_box/*.tsv | relax+旧 prod 80/80 rc=0、0 warning; prod 改为 400 ns 后再跑 40/40 rc=0、0 warning、nsteps=20000000 (NOTE.txt 说明) |
| 8 | prod 长度 = 400 ns | grep 40 份 inputs/*/prod_lam.mdp | nsteps 20000000 × dt 0.02 = 400 ns; 包内模板与 40 份一致 |
| 9 | 单元测试 | `tests/test_verdict_unit.py` | 10/10 PASS, 含新边界: 400.0 ns → 可评估, 399.5 ns → NOT_EVALUABLE |
| 10 | cz 起点基线 | proof/cz_builder_baseline.tsv | 40 行 + 表头 |
| 11 | DOPC 是否桥连 (K 的核心问题) | box 15 ns relax, 末 5 ns 67 帧逐帧闸门 | **不桥连**: h050 18/67、h100 13/67 合格, ncl=1 帧 0。所以维持 50/100, 不改 75/150 |
| 12 | 其它体系起点 | 同上 | DOPE h050 20/67, h100 23/67; MC3H h050 18/67, h100 4/67 (偏少但 ≥1 即可选起点) → 预测 SEL_OK |
| 13 | 中性 MC3 起点 | 同上 + 诊断 | **0/67 两档** → 预测 VOID_L2, 见 M1 |
| 14 | 容量 | README 公式, 标 估算 | 单条 1.05–1.46 h; 槽链 7.40–7.71 h (f=1.0) / 8.88–9.26 h (f=0.8); 22:00 发车约 05:42 / 07:15 完成 (估算) |

## 问题
- **M1 (大, 须 K 知情, 不阻挡发车)**: 中性 MC3 在 relax 的半各向同性 c-rescale 下 ~9 ns 内盒子侧向塌缩 (Lx 11.5 → 3.1 nm, Lz → 165/212 nm), 末 5 ns 0 合格帧。诊断性固定面积 relax (compressibility 0 3e-4, 不进包) 在 0.75 ns 内即尾区桥连 (ncl=1)。即 **中性 MC3 的片层起点在这个力场/协议下保不住**, 很可能是物理上的 (中性 MC3 本就不爱成片层), 不是包的 bug。后果: Spark 上 MC3 主跑与替补大概率都 VOID_L2 → MC3 对比 NOT_EVALUABLE → **两档菜谱判定都会是 NOT_EVALUABLE**, 但 DOPE/DOPC 两把尺和 MC3H 仍各自可评估, 这一部分正是 K 这轮要看的 "相对水合下尺子对不对"。同一问题很可能也存在于 D1 (同一压力耦合)。改 MC3 起点或协议 = 预注册修订, 须 K 决定; 本包 **不改**。VOID 条不跑 prod, 不拖整体时间。
- **F1 (已修)**: 40 份 inputs 的 prod_lam.mdp 曾是 500 ns (生成早于模板修改) → 已改 400 ns 并重跑 grompp。
- **F2 (已修)**: 包内一度出现 gate/__pycache__ (box 上导入闸门时生成) → 已移到 /tmp/v2junk, 不进 MANIFEST。
- **R1 (风险提示)**: prod = 400 ns = T_EVAL_MIN_NS, 没有余量; 任何 -maxh 截断都会让该条 TRUNC 不可评估。容量估算在 f=0.8 时 22:00 发车约 07:15 完成, 离 07:30 只有 ~15 min (估算)。若机器明显更慢, 按 README 砍范围顺序 (先保 h100 的 12 条), 不缩短 prod、不放宽闸门。
- **R2 (小)**: MC3H h100 合格帧仅 4/67, 且最后合格帧在 15.000 ns (即末帧); Spark 上不同随机性下可能 VOID, 会用替补。
- **R3 (小)**: box relax 用 gmx 2025.4, Spark 是 2026.3; 资格结果只是预测, 以 Spark 上 launch 时的 L2 为准。

## 结论
机械层面 (名字、水量、链、grompp、判据、单元测试、MANIFEST) 全部通过; 判据与闸门未放宽。**PASS-WITH-FIXES**: 可以上传并写 QUEUE READY; M1 必须写进 Pages 让 K 知道 "这轮 MC3 对比大概率出不来"。
