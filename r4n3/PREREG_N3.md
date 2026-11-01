# PREREG_N3 · R4 第 3 晚 (2026-11-01 14:25 → 11-02 06:50, 北京时间 UTC+8)
状态：**草案，待 K 批；批后冻结 (sha 进 pkg/R4N3/MANIFEST_sha256.txt)**。母本：PREREG_R4_3day.md + PRE_REG_AMENDMENT_R4N1_01/02.md (三份逐字节照搬，sha 见 FROZEN_sha256.txt)。
**本文件只新增 4 条修订 A1–A4。母本里的判据、阈值、闸门、阴性对照一字不改；凡与母本不同之处都在下面逐条标【修订】。**

## 1 描述符与阈值 (照母本, 不改)
- L1 构建门 (t0_gate_hii); relax 15 ns → **L2 逐帧门** (末 5 ns, 67 帧): wpol==1, n_tube==4, max|L/L0−1| ≤ 0.30 (L0 = 该 build 的 expect.env BOX0), composition_ok; 取最后一个合格帧进 prod。0 合格帧 = VOID_L2 (起点级, 不计结果、不算删失, 由同格替补顶)。
- 每 run 判读: 判定窗帧上 f_HII ≥ 0.80 = RETAIN, ≤ 0.20 = LOST, 其间 PARTIAL; 可评估资格 prod 观测 ≥ 400 ns 且窗口帧 ≥ 99 (冻结 verdict_R4_3day.py)。
- 尺子 (每条件格): 规则 1 DOPE_hii RETAIN ≥ 2/3; 规则 2 (命门) DOPC_hii RETAIN 0/3 且 LOST ≥ 2/3; 规则 3 DOPC_lam 事件 0/3。三条全 PASS 才判内标。
- 内标: Δ = n_RETAIN(MC3) − n_RETAIN(MC3H); |Δ| ≥ DELTA_SEP = 2 判分离。失败分支 F1–F4 照母本。
- n = 3 主 + 1 替补 / 格 / 体系; 替补只顶同格 VOID。

## 2 阴性对照 (照母本, 不改, 都随跑)
- DOPE 阳性尺、DOPC 阴性尺与 MC3H/MC3 同晚同条件跑 (C4r 格)。DOPC_lam 用第 1 晚同条件结果 (A4)。
- 闸门负自检 (launch_guard 内建): 已知桥连帧 (R3 DOPC relax 末帧) 必须判不合格; 每台机发车前必过。
- 新增 (只加不放宽): C4a 配置的阴性自检: 各向异性 C-rescale 在 GROMACS 2026.3 grompp 必须报错 (实测 rc=1 "C-rescale does not support pressure coupling type Anisotropic yet") → C4a 作废, 本晚不用。

## 3 修订
### 【修订 A1】C4r: 用 BOX0_r 重建 DOPE / DOPC / MC3H 的 h100 T350 H_II 起点
- 原因: 第 2 晚 MC3H h100 T350 hii 4/4 VOID_L2 都是"盒形 30% 门"拦下的几何型 VOID (4 管完整, wpol==1, n_tube==4, dL/L0 中位 0.48–0.51)。
- BOX0_r 规则 (固定, 不按结果挑): 每个种子取 relax 末 5 ns 里 wpol==1 且 n_tube==4 的帧 → Lx/Ly/Lz 各取中位 → 再取种子间中位。只用 relax 段数据, 不看任何 prod。脚本 box0r/derive_box0r.py, 结果 box0r/BOX0_r.tsv。
  - DOPE 13.785 × 11.938 × 10.344 nm; DOPC 19.145 × 16.580 × 7.117; MC3H 16.115 × 13.956 × 9.198。种子间最大偏差 ≤ 0.029。
  - 注: 与 10-31 未冻结草稿 (D2/N3_plan) 的"全部帧均值"不同; 本条用"合格帧中位", 理由是 VOID 前的塌缩帧不该进参考盒。
- **【修订 A1(b), 改动母本 §2 的一条构建规则, 须 K 明批】** 母本 §2 要求 a_w ∈ [0.50, 0.70], 否则 VOID_BUILD。BOX0_r 建盒时 a_w 只记录不作门: DOPE 0.562, DOPC 0.648, **MC3H 0.744 (超出 0.70)**。理由: BOX0_r 就是这个体系在 4 管完整时自己弛豫到的盒, 0.744 是其实测头基面积, 不是 builder 的猜测。**K 若不批 A1(b), MC3H C4r 就按母本记 VOID_BUILD, C4r 只剩尺子。**
- L2 门的 L0 = 新 expect.env 里的 BOX0_r (阈值 0.30 不改)。
- 证伪: C4r 的 MC3H 若 ≥ 3/4 仍被 L2 盒形门拦 → "VOID 是起点盒不匹配" 这一假设被证伪, 回报, 不再调盒。
- 不混 n: C4r 只用本晚 run dir; 第 1/2 晚 C4 的 hii run 不并入 (wrapper 只读本晚 runs_status 的 hii 行)。

### 【修订 A2】HYD: 中性 MC3 用真实水合 h022 (= 32.5 × 0.22 ≈ 7.15 水/脂), MC3H 同档对照
- 选 "真实水合" 而不选 "NVT 固定盒", 理由: (1) NVT 让 L2 盒形门恒过, 等于把门关掉; (2) D1v2v2 固定面积诊断里中性 MC3 0.75 ns 内就桥连, 固定盒压不住; (3) 塌缩是组成驱动 (借了 DOPC 的水量, 中性 MC3 吸不了这么多水), Martini 3 LNP 论文与 Philipp et al. PNAS 2023 (10.1073/pnas.2310491120) 给低 pH H_II ≈ 7–12 水/脂, Soft Matter d5sm00666j 给 MC3 H_II 含水 24.7 ± 1.0% 且随 pH 不变; (4) 只改一个变量 (水量)。
- MC3H 也在 h022 跑, Δ 在同水合下比 (格名 HYD = (T350, h022))。
- 尺子借用: HYD 格的 DOPE/DOPC (hii 与 lam) 判定借 C4r 格 (同温; 尺子校的是协议, 不是水量)。HYD 本身不跑 DOPE/DOPC。
- 中性 MC3 HYD ≥ 2/3 VOID → Δ NOT_EVALUABLE (母本规则, 冻结代码原样给出)。
- 风险 (写在这, 不作判据): 文献报告中性 (高 pH) MC3 为反胶束立方相 (Fd3m), 酸性才是 H_II, 所以中性 MC3 的 H_II 可能本来就不稳; LOST 是可接受的物理结果, 不是协议失败。

### 【修订 A3】种子、prod 长度、判读包装
- 种子 s11 起, 与旧 s1–s4 不重名; 名字仍用 R4N1_ 前缀 (runner NAMERE 要求)。
- 种子表 (预先固定, 按种子号顺序, builder 失败的跳过, 前 3 个成功的 = 主, 第 4 个 = 替补): DOPE C4r: s11 s14 s15 s16 s17 builder VOID (2 珠 < dmin 0.30, place_forced 8; 存 pkg/R4N3/proof/build_void/) → 主 s12 s13 s18, 替补 s19。其余每格 主 s11–s13, 替补 s14 (全部 builder 成功)。
- prod 一段跑 **1200 ns** (nsteps 6e7; 原 400 ns + 续跑)。判读 horizon 报 **400、1200、max**; F4 照母本 (400 与长 horizon 不一致时以长者为准并写撤回)。FILL=1 时 1200 → 2000 ns 续跑, 只作描述性 horizon。
- 判读用 verdict_N3_wrap.py: 导入冻结 verdict_R4_3day.py (逐字节不改), 只替换 CONDS = {C4r, HYD}、种子映射、HYD 借尺。测试 tests/test_verdict_N3_wrap.py 10/10 PASS。

### 【修订 A4】规则 3 (DOPC_lam) 用第 1 晚 C4 同条件结果
- 本晚不跑片层臂 (BOX0 问题只在 H_II 臂)。规则 3 的 DOPC_lam 格 = 第 1 晚 R4N1_DOPC_h100_T350_lam_s1–s3 (D2/N1_final/verdict/OUTALL/runs_status.tsv, 3/3 NO_EVENT), 由 wrapper 的 --lam-src 读入。只读 lam 行, 不读任何旧 hii 行。没有 --lam-src 时规则 3 = NOT_EVALUABLE (不默认 PASS; 测试 T8)。

## 4 必须预先写明的已知风险 (不改判据)
- **规则 2 很可能 FAIL**: 第 1 晚 C4 (原 BOX0) 规则 2 已 FAIL (DOPC_hii RETAIN 3/3); DOPC 原 BOX0 与 BOX0_r 只差 ≤ 0.03, C4r 的 DOPC 大概率还是 RETAIN → C4r 尺子 FAIL → HYD 借尺也 FAIL → Δ = NOT_JUDGED。这是母本规则下的正确结果, 不因此改尺子。到时 Δ 只能作描述性数字报。
- 第 2 晚 DOPC 3 µs 续跑的判读还没出 (无 xtc 回传), 规则 2 在长 horizon 下是否翻转未知。

## 5 证伪 / 失败口径 (预先写死)
- A1 证伪: 见上。A2: 中性 MC3 h022 ≥ 2/3 VOID → "水量是塌缩主因" 被证伪 (至少在 h022 档)。
- 任何 VOID 不得在发车后改阈值重判; 所有修订后的数字与母本数字并列报告。
