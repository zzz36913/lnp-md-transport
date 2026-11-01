# PREREG_N4 · R4 加压方式扫描 (第 4 包; 2026-11-01 晚 → 11-02 06:50, 北京时间 UTC+8)

> **K 原话 (2026-11-01 14:50 UTC+8, authorized_by pt522u)：**
> 「你不用这样去干。既然你能发现这个特征，现在要做的就是按现有的闸门，把模拟的特征跑出来。你应该把加压方式做成一个扫描菜谱，然后把这个实验开展起来。」
>
> 14:55 (UTC+8) 改期: 今晚 (11-01) 就跑; R4N3 今晚只跑 MC3/MC3H, DOPE/DOPC 的槽给本包; 优先 DOPE+DOPC × 各加压档 × n=3, 起点用现成 C4 H_II 起点, 判读规则不变; MC3 内标放第二阶段; 放不下就削档, 不削 n; 闸门一个都不放松。

状态: 本文件随包冻结 (sha 进 pkg/R4N4/MANIFEST_sha256.txt)。母本 PREREG_R4_3day.md + PRE_REG_AMENDMENT_R4N1_01/02.md + PREREG_N3.md 原样继承 (前三份逐字节, sha 见 FROZEN_sha256.txt; 冻结判读 verdict_R4_3day.py sha256 4fd49504…49908b2, 逐字节不改)。
**本文件只新增一个扫描维 = prod 段的加压方式 (档位 L)。母本的描述符、判据、阈值、闸门、阴性对照、n 一字不改; 不新增任何"盒子压扁"类判据——盒形只作描述性记录, 不进判读。**

## 1 要回答的问题
第 2 晚 C4 格 DOPC 在半各向同性 (semiisotropic, z 独立) 加压下 Lz 7.1 → 3.2 nm "压扁", DOPC_hii RETAIN 3/3, 规则 2 (命门) FAIL。
本包问: **换一种加压方式 (只换 prod 段加压, 其他全同), 冻结尺子 (规则 1–3) 能否 PASS?** 每一档是一张"菜谱", 用同一把冻结尺子判。

## 2 扫描维: 加压档位 (prod 段; relax 段一律与 R4N3 相同)
| 档 | 名 | pcoupl | pcoupltype | tau_p (ps) | ref_p (bar) | compressibility (bar⁻¹) | nstpcouple | 物理含义 |
|---|---|---|---|---|---|---|---|---|
| L2 | AXFIX | c-rescale | semiisotropic | 4.0 | 1.0 1.0 | 3e-4 0 | 5 | xy 等比耦合, **z (管轴) 长度锁定** |
| L3 | PRXY | Parrinello-Rahman | anisotropic | 12.0 | 1.0 1.0 1.0 0 0 0 | 3e-4 3e-4 0 0 0 0 | 2 | x、y 各自独立耦合, z 锁定, 盒角不变 |
| L4 | ISO | c-rescale | isotropic | 4.0 | 1.0 | 3e-4 | 5 | 三向等比 (盒形比例不变, 不能单向压扁) |

- 每个 build 的 prod_hii.mdp = R4N3 同起点 prod_hii.mdp 逐字, 只改上表 6 键 + gen_seed (工具 tools/derive_R4N4.py, 每键断言恰好 1 行); runner 发车前按种子百位逐字核对 6 键 (launch_guard [R4N4] 段), 不符即 FAIL。
- relax 15 ns (c-rescale semiisotropic tau_p 1, nstpcouple 2) 与 R4N3 相同 → **L2 闸门的输入与 R4N3 完全同型**。
- 已证伪/不用: c-rescale anisotropic (GROMACS 2026.3 grompp rc=1, proof/neg/); PR 用 nstpcouple 5 (grompp WARNING: tau_p 须 ≥ 200 × nstpcouple × dt) → 取 nstpcouple 2。
- 不在今晚: 半各向同性在 BOX0_r 起点的同晚对照 (第 2 晚 semi 是旧起点); LONG (2× Lz, 需 1920 脂、改 builder); 各档下的 DOPC 片层臂。均列为 K 待定项。

## 3 体系、起点、种子 (n)
- 条件格只有 C4r (T350, h100, BOX0_r 起点); 体系 DOPE (阳性尺) + DOPC (阴性尺)。
- 起点 = R4N3 包里现成的 C4 H_II 起点, 逐字节复制 (start.gro/sys.top/index.ndx/expect.env, sha 逐条记在每个 build 的 DERIVED.txt; 清单 inputs/R4N4_builds.tsv sha256 前 16 位 87fc2a546bcd6e2b):
  - DOPE: 起点 s12 s13 s18 主 + s19 替补; DOPC: s11 s12 s13 主 + s14 替补 (同 R4N3 A3 的种子表)。
  - 新名字 R4N1_<体系>_h100_T350_hii_s<L><起点号> (例 s312 = PRXY 档、DOPE 起点 s12)。relax 速度种子 gen_seed = 20301030 + cksum(新名字) % 100000 (同 builder 规则), 所以同一起点在不同档是独立的 relax 实现。
- **n = 3 主 / 档 / 体系, 每档每体系 1 个替补 (只顶同档同体系的 VOID_L2)。档与档之间不合并 n、不互借替补。** 替补也 VOID 或没时间跑 → 该档该体系 n < 3 → 该档判不出 (NOT_EVALUABLE), 不凑数。

## 4 描述符与闸门 (照母本, 不改)
- L1 构建门: 起点是 R4N3 已过 L1 的同一批 (本包对 24 个派生目录重跑 tools/l1_scan.sh: 24/24 PASS, inputs/L1_summary.tsv)。
- L2 逐帧门 (relax 末 5 ns): wpol==1、n_tube==4、max|L/L0−1| ≤ 0.30 (L0 = expect.env 的 BOX0)、组成正确; 取最后一个合格帧进 prod; 0 合格帧 = VOID_L2。
- prod 1200 ns 单段 (nsteps 60000000), T 350 K。
- 每 run 判读 (冻结 verdict_R4_3day.py): 最后 100 ns 判定窗 f_HII ≥ 0.80 = RETAIN, ≤ 0.20 = LOST; prod 观测 ≥ 400 ns 且窗口帧 ≥ 99 才可评估。
- 描述性 (不进判读): 每帧 Lx/Ly/Lz、Lz/Lz0, 只用于出图与解释。

## 5 判读规则与阴性对照 (照母本, 不改)
- 规则 1 (阳性尺): DOPE_hii RETAIN ≥ 2/3。
- 规则 2 (命门, 阴性尺): DOPC_hii RETAIN 0/3 且 LOST ≥ 2/3。
- 规则 3 (片层臂阴性): DOPC_lam 事件 0/3。**本包不跑片层臂; 规则 3 借第 1 晚 T350 h100 DOPC_lam 结果 (semi 加压下跑的), 每档报告里标"R3 借用 (第1晚 semi lam)"**。不给借用来源 → 规则 3 NOT_EVALUABLE → 该档尺子 RULER_NOT_EVALUABLE (冻结行为, 不默认 PASS)。
- 闸门负自检 (launch_guard 内建): 已知桥连帧必须判不合格; 每台机发车前必过。
- MC3/MC3H 内标 Δ: 本包不跑 → NOT_EVALUABLE (第二阶段)。
- 判读包装 verdict_N4_wrap.py: 只做 (B1) 按档分开判、(B2) 种子映射、(B3) 条件格 = C4r、(B4) 规则 3 借用; 不碰阈值、逐帧判据、条件判定函数 (测试 tests/test_verdict_N4_wrap.py T10/T11)。

## 6 一个菜谱 (档) 怎样算"通过"
- 档 L **通过** ⇔ 该档在最长判定窗 (1.2 µs) 冻结尺子 = PASS (规则 1、2、3 全 PASS), 且 1200 ns 判定窗 → 最长判定窗之间无撤回。
- 档 L **不通过** ⇔ 尺子 FAIL (任一规则 FAIL)。**判不出** ⇔ n 不足 / 规则 3 无来源 / 未跑。
- 多档通过: 全部如实报告, 不挑一个; 本包不排名。规则 3 是借来的 → 任何"通过"都带"R3 借用"标签, 正式定菜谱前须在同档补片层臂 (K 待定)。

## 7 证伪条件 (事先写死)
- **F-A (加压不是原因):** 跑完的每一档 (n=3 可评估) 规则 2 都 FAIL (DOPC 仍 RETAIN) → "DOPC 保留 H_II 是 semi 加压压扁造成的"这一解释被否定; 回 K, 不再在加压维上找。
- **F-B (档位过驱):** 某档规则 1 FAIL (DOPE 丢 H_II, LOST ≥ 2/3) → 该档作为菜谱作废 (把阳性也压没了)。
- **F-C (只在锁 z 时成立):** 只有 AXFIX/PRXY 通过、ISO 不通过 (或反之) → 如实记录, 不外推到别的档。
- 时间维撤回照母本: 1200 ns 窗 PASS、最长窗不 PASS → 撤回。

## 8 优先级与削档 (今晚窗口 → 06:50)
- 队列顺序 (每台机两槽共用一条队列): AXFIX ×3 → PRXY ×3 → ISO ×3; 替补优先于下一条新起。
- **削档不削 n**: 放不下的从队尾 (ISO) 开始不跑; 已开始的档如果因替补/时间只跑成 n<3, 该档判"判不出", 不降 n。
- k04 只跑 DOPC, k03 只跑 DOPE (各自接 R4N3 空出来的槽, 见 README_R4N4.md / PLAN_N4.md)。
