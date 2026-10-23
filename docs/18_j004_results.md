# dd/18 J004 结果：MC3:CHOL:DSPC 50:40:10 固定质子化 α 滴定（Martini 3）判相

日期：2026-10-23（SGT）。全部分析在 box 上完成（只读用 GitHub 回传数据，未碰 ZCode / Spark）。
所有数值后括号内为来源文件；「估算」= 非实测。

## 0. 数据来源与完整性
- 回传：zzz36913/lnp-md-transport@master sha a3b88666684aa254b13cc7c32e3bc4b63750761b → `/workspace/lnp-md/j004/out/`
  - SUMMARY.txt sha256 b3b09a2a…；j004_phase.tsv sha256 f5b3af98…（全量 sha 见 RUNBOOK §44）
  - TSV 相列全 NA（主机无 numpy，`out/SUMMARY.txt`），本轮在 box venv 重跑。
- 末帧：无 prod.gro，由 xtc 末帧导出且**不含水珠**（`out/SUMMARY.txt` trjconv 组计数）：
  POS t=797000 ps，T67 370000，T67_rep2 364500，T33 422000，T100 429000 ps（`out/SUMMARY.txt`）。
- 组分核对（`out/j004_*_last_nonW.gro` 计数）：T67 MC3 848 + MC3H 1696、CHOL 2036、DSPC 509（50:40:10，α=0.667）；T33 MC3 1696 + MC3H 848；T100 MC3H 2544；POS DOPE 1212、CHOL 303（80:20）。
  phase_counts.py 依赖核心 Martini itp（不在仓库，在机器 ~/lnp_ff）→ 未能重跑，改用 gro 计数核对。
- 末盒边长 nm（gro 末行）：POS 13.55449，T67 18.98726，T67_rep2 18.98350，T33 19.13557，T100 18.84926。
- prod Performance（`/home/box/agent-data/lnp-md-spark/QUEUE.md` 调度 bot 回写）：POS 2417.370 ns/day（797.0 ns），T67 1140.675（370.4），T67_rep2 1127.156（364.9），T33 1307.616（422.2），T100 1329.658（429.1）。
- T0（α=0 阴性参照）四次失败，**无数据**；T0_rep2 / T100_rep2 / T33_rep2 SKIPPED_SHORT（`out/SUMMARY.txt`）。

## 1. 方法
1. phase_sq.py（sha256 d953a39e…，与 `ph_phase/SHA256SUMS` 一致）：CIC 64³ + FFT，阈值 frac 0.08、对比度 8×壳层均值、smin 25、qmax 2π/1.5 nm；模板 LAM / HII / Pn3m / Im3m / Ia3d，SVD 判维度。
   因末帧无水，`--sel W` 不可用，改三种代理选择：heads `NP,N1,NC3,PO4,NH3,ROH`；tails `C4A,C4B,D3A,D3B`；ions `CL`；均 `--conn`。输出 `/workspace/lnp-md/j004/sq/{sys}_{heads,tails,ions}.{json,sq}`。
2. 独立几何交叉验证 `/workspace/lnp-md/j004/geo_check.py` → `j004/geo/geo_check.json`：
   脂质珠 CIC 64³ + 高斯 σ=0.5 nm；密度最低的 f_w 体积分数体素 = 水域，f_w=(N_W+N_ion)/N_total（按珠数比，**估算**；±0.05 敏感性测试结论不变）；
   周期连通簇（≥2% 水体积）+ 卷绕轴；周期体素复形欧拉示性数 χ=V−E+F−C；界面法向张量（|∇ρ| 加权、梯度前 30%）本征值。
3. **单帧**分析（每体系仅末帧），无时间平均。

## 2. 逐体系结果
| 体系 | α | phase_sq heads / tails / ions | 径向 S(q) 最高壳层（tails） | 水域簇（卷绕） | χ | 法向张量本征值 | 读数 |
|---|---|---|---|---|---|---|---|
| POS | — | LAM(single-order) / DISORDERED / DISORDERED | q 1.16 nm⁻¹，S 36.1 | 1（y,z） | −4 | 0.407/0.36/0.233 | 有孔洞的二轴水层/网络，非 H_II |
| T33 | 0.33 | DISORDERED ×3 | q 0.16（盒尺度壳层），S 499.4 | 2：91%+8%（无） | +3 | 0.337/0.334/0.329 | 单一大闭合水池（盒尺度） |
| T67 | 0.67 | DISORDERED ×3 | q 0.83，S 70.0 | 5：26/23/21/20/10%（无） | +5 | 0.364/0.352/0.285 | 多个孤立水池 |
| T67_rep2 | 0.67 | DISORDERED ×3 | q 0.50 (57.8)、0.83 (54.1) | 4：35/33/20/11%（无） | +6 | 0.385/0.372/0.243 | 多个孤立水池（与 T67 复现） |
| T100 | 1.00 | DISORDERED ×3 | q 1.17，S 32.7 | 2：90%+10%（x,y,z） | −2 | 0.425/0.306/0.269 | 三维连通水网络，无 Bragg 序 |

来源：`j004/sq/*_tails.sq`、`j004/sq/*.json`、`j004/geo/geo_check.json`。径向分箱 dq=2π/L。所有 MC3 体系三种选择均 0 个强峰。
- POS heads 唯一判 LAM 的依据：q1 1.854 nm⁻¹（hkl 0,±4,0），d1 3.39 nm，仅 2 个强峰、单阶（`j004/sq/POS_heads.json`）——弱证据。
- POS 全脂质珠逐 hkl：(0,2,0) q 0.927 S 349.1；(1,±1,1) q 0.803 S 258.8/234.1；(0,0,2) S 186.9；比值 0.927/0.803=1.155，但都是盒内仅 2 个周期的盒相称峰，不可指标化（box 内交互检查，脚本因多方向同时强、壳层均值抬高而拒绝）。无 √3 二维峰、无单轴水柱 → **无 H_II 信号**。

## 3. 预注册闸门判定
1. 阳性对照 POS 须出非层状相：**未通过**（无 H_II / 立方信号；脚本 heads 判弱 LAM 单阶，几何为不规则水网络）。→ 按预注册，**整批不下结论**。
2. 主闸门 α*（首个出现非层状相的 α）：在 {0.33, 0.67, 1.00} 中**不存在**（全部 DISORDERED）。即便 POS 通过，此结论也仅为 n=1（T67 n=2）方向性。
3. 立方相（Pn3m/Im3m/Ia3d）：**未检出**（单列报告）。
4. **无 α=0 参照**（T0 四次失败）。

一句话闸门：阳性对照 POS 未形成非层状相，按预注册 J004 整批不下结论；且全部 α 无 Bragg 有序相、无 α*、无立方相、缺 α=0 参照。

## 4. 方向性观察（不是结论）
α 升高时，水域形貌从单一大水池（T33，χ+3）→ 多个孤立水池（T67 / rep2，χ+5/+6）→ 三维连通网络（T100，χ−2）。与「亲水界面面积随 α 增加」一致，但这是相关不是机理，也不是相变：n=1、单帧、随机混合起始、365–429 ns 可能动力学受困、T33 水池受盒尺寸限制、f_w 阈值为估算。

## 5. 图
- `/workspace/lnp-md/figs/j004/figJ004_phase_overview.png`（300 dpi，sha256 45659fc8…）/ `.pdf` / `figJ004_provenance.json`；脚本 `figs/j004/fig_j004.py`（调用 sim-paper-figures simviz，未改 skill）。
- A：五体系末帧盒中心截面 3D（MC3 / MC3H⁺ / CHOL / DSPC / DOPE 分色，Cl⁻ 作水域标记；MC3→S1D、MC3H→S12 仅内存映射用于着色）；B：tails 单帧 S(q)；C：判相表。图中文字为英文（skill 规定不得替换字体，捆绑字体无 CJK）。
- 诊断：`j004/geo/quicklook_slices.png`。

## 6. 下一步（估算均标注）
1. POS 修复（闸门前置）：14 nm 盒可能与 H_II 晶格不相称。改 20 nm 盒（约 75k 珠）或预组装 H_II 起始，跑 ≥1 µs。按实测同尺寸 ~1130–1330 ns/day，1 µs ≈ 18–21 h/槽（估算）；保留 14 nm 盒继续到 1.5 µs ≈ 再 7 h（按 2417 ns/day，估算）。
2. T0 今晚：预组装双层（不再随机混合）起始，20 nm 盒约 75k 珠，400 ns ≈ 7–8.5 h/槽（估算，按 1130–1330 ns/day）。
3. NEG DOPC:CHOL（层状阴性对照）：14 nm 盒约 24k 珠，800 ns ≈ 8 h（估算，按 POS 2417 ns/day）；400 ns ≈ 4 h。
4. 补 T33/T100 rep2；末帧导出须带水（或保存 prod.gro），并做多帧平均 S(q)。
5. 按 Small 2026 提示后续加阴离子脂（见 RUNBOOK §43）。
