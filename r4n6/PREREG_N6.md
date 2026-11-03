# PREREG_N6 — 第 6 包「Q1 ANISO + Q2a h050@T350」+ 补位 (11-03 晚 → 11-04 06:50, Asia/Singapore UTC+8)

- 写于 2026-11-03 14:xx UTC+8 (box), 任何 R4N6 作业起跑之前. 来源: K 11-03 13:37 批准 Q1+Q2a 并行; 13:44 追加 (替补 2 个/格, 起点 box 预检, 补位规则, 利用率); 13:47 改补位优先级 (XEXT 第一).
- 冻结件逐字节沿用: `verdict_R4_3day.py` (sha256 4fd49504721b8b47e6b651ac6c9828e4104f0600a9c0023cbd639a1ce49908b2), `PREREG_R4_3day.md`, `PRE_REG_AMENDMENT_R4N1_01/02.md`, `gate/`, `inputs/D1v2_lam_runs.tsv` (`sha256sum -c FROZEN_sha256.txt` OK). 新逻辑只在 `verdict_N6_wrap.py` 包装层.
- 本包沿用 PREREG_N5 §2–§7 (流程/闸门/MPS 槽位规则/判定/证伪) 原文 (`PREREG_N5.md` 留在包内作被引用件); 本文件只新增, 不放宽任何阈值、闸门或负对照. 标「估算」的数都是估算, 不是测量.

## §1 两组 (每组一个旋钮; 互不合并)
| 组 | 假设 (PREREG_QUEUE) | 唯一旋钮 | 其余 | 档 / 种子 |
|---|---|---|---|---|
| **Q1 ANISO** | 半各向同性把 x=y 绑死, 给片层→管加几何代价 | prod 加压段: Parrinello-Rahman **anisotropic**, tau_p 12, ref_p 1 1 1 0 0 0, compressibility 3e-4 3e-4 3e-4 0 0 0 (z 放开, 盒角不变). 伴随技术改动声明: nstpcouple 5→2 (D4 实测 PR τp12 需 2 才无警告) | 350 K, h100 (DOPE 3624 W / DOPC 7800 W), relax 不动 | 档 6; s601–s603 主, s604 spare1, s605 spare2 |
| **Q2a H050** | 15.1 水/脂太湿 | 水珠数 h050 (DOPE 1812 W = 7.55 水/脂; DOPC 3900 W = 16.25 水/脂) | 350 K, 档 5 LAMSEMI 加压 (第 1 晚冻结 prod_lam), relax 不动 | 档 5; s501–s503 主, s504 spare1, s505 spare2 |

- 起点: ANISO s601–604 = D2/N1x `R4N1_*_h100_T350_lam_s1..s4` (与 R4N5 T350 同结构, 新速度种子); s605 = D1v2 `R4_*_h100_lam_s5` (N1x 无 s5; 同组成, 已过 L1). H050 = D1v2 `R4_*_h050_lam_s1..s5`, 只派生 ref_t/gen_temp 320→350 + expect.env. 每个 build 的来源与 sha 见 `inputs/<b>/DERIVED.txt`; 派生脚本 `tools/derive_R4N6.py` 断言除旋钮与 gen_seed (20301030+cksum(name)%100000) 外逐键与冻结 mdp 相同.
- 每体系 DOPE (阳性) + DOPC (阴性), n=3. 机器: k03 = DOPE, k04 = DOPC; 每机 ≤2 槽且 2 槽须 MPS (PREREG_N5 §4); NEW_RUN only. 队列 ANISO/H050 交替领, 两组同步推进.
- 流程同 PREREG_N5 §2: relax 15 ns → L2 闸门 (prod0 2/2/2/2) → prod_lam 1200 ns 单段 (dt 0.02, 1 帧/ns).

## §2 替补顺序 (13:44: 1 → 2)
- 每格替补 2 条, **只顶起点级 VOID** (VOID_BUILD / VOID_L2 / RELAX_FAIL / VOID_SEL_MISMATCH), 不加 n. 顺序固定: **spare1 先, spare2 后** — ANISO s604 → s605; H050 s504 → s505; NEXT s504 → s505.
- 判读: 包装层令 `V.SPARE_SEEDS=(4,5)`, 冻结 select_cell 按此顺序逐个顶 VOID (冻结文件不改).
- 运行: 机上 L2 闸门判 VOID 后, 同格替补立即排到本机队列最前 (chains/spares_<机>.txt 文件顺序 = 替补顺序).

## §3 起点预检 (13:44)
- box 上能检的已检: 35 个 build (30 新 + 5 XEXT) 的 start.gro 全部 L1 PASS (2/2/2/2 @ 0.65/0.75/0.95; inputs/L1_summary.tsv), 70/70 grompp rc=0 0 warning (selfcheck/grompp/SUMMARY.tsv).
- box 上检不了的 = L2 (relax 后的片层闸门, 需在机上 relax 15 ns): 运行器 relax 结束即判, VOID 立刻换 §2 替补, 不等其他槽.

## §4 判定 (冻结规则, 两组各自判)
- 单跑: EVENT = wpol==1 且 Cz≤0.5 持续 ≥20 ns; NO_EVENT 还须 T_obs≥1199 ns, 否则 TRUNC_N6 (不可评估). CZ_DEGENERATE 同冻结.
- 规则 P: DOPE n_eval≥3 且 EVENT≥2 → PASS; ≤1 → FAIL. 规则 N: DOPC 任一 EVENT → FAIL (METHOD_OVERDRIVEN); 3 满窗 NO_EVENT → PASS.
- 总判: CONTRAST_PASS / NO_TRANSITION_IN_WINDOW / METHOD_OVERDRIVEN / NOT_EVALUABLE (同 PREREG_N5 §5). 描述 (不进门): t_event, t_merge (ncl==1 ≥5 ns), wpol_final.
- ANISO 与 H050 结论互不影响; 不合并成一档. MC3/MC3H 只在某组尺子 CONTRAST_PASS 后另行预注册.

## §5 证伪
- Q1: DOPE ≤1/3 且 DOPC 干净 → 「耦合类型不是瓶颈」; DOPC 出事件 → 各向异性过驱或拉变形, METHOD_OVERDRIVEN, 不救.
- Q2a: DOPE ≤1/3 且 DOPC 干净 → 「350 K 半各向同性下水合不是瓶颈」; DOPC 出事件 → 该水合压垮负尺, 作废, 不放宽.
- 不因结果改阈值、换视界、换种子或补跑非替补种子.

## §6 时间与槽位 (估算; DRY 名义速度 PERF_NOM 14258 ns/day 按珠数缩放, 非实测)
- 单条 need (含 relax+闸门+prod 1200 ns): ANISO DOPE 2.27 h / DOPC 2.82 h (PR+nstpcouple 2 可能更慢, box 无实测); H050 DOPE 2.03 h / DOPC 2.30 h. 每次领取另留 0.75 h 余量 (SUPP_MARGIN_H).
- 主两组 (每机 6 条) 槽时: k03 ≈ 12.9 槽·h, k04 ≈ 15.4 槽·h (估算). 15:00 起跑 2 槽: 约 21:30 (k03) / 22:45 (k04) 跑完; 即便 ANISO 慢 25% 或 17:00 才起也在 06:50 前 (selfcheck/sim_util_N6.txt). **不需要裁剪**, 不减种子.
- 1 槽 (无 MPS) 时 (估算): k03 6 条 ≈ 12.9 h, 15:00 起约 03:55 完, 放得下; k04 6 条 ≈ 15.4 h, 第 6 条 (H050 DOPC s503) 约 04:05 领取时 now+2.30+0.75 h 超 06:50 → 运行器不领 → H050 DOPC n_eval=2 → H050 NOT_EVALUABLE (除非出事件). 最小裁剪 (只列出, 不由我裁): 1 槽时 k04 放弃 H050 DOPC 第 3 条或 ANISO DOPC 第 3 条之一 —— 都会让该组不可评; 不减种子的唯一办法是确保 k04 有 MPS 2 槽. 由 K 定.

## §7 收集
- `xfer_small/collect_small.sh` (本包版): 每 build 起点帧 + 0/200/…/1200 ns 帧 + 分析表; 先完成先打小包, 小包在前大包在后 (UPLOAD_ORDER.txt). 中途快照标 INTERIM.
- 正式判读: `python3 verdict_N6_wrap.py judge <collect 目录>` (ANISO/H050/NEXT); `python3 tools/collect_xext.py …` + `python3 verdict_N6_wrap.py judge_xext <目录>` (XEXT).

## §8 补位规则 (13:44 新增; 13:47 改优先级) — 发车时 NEXT_FILL=1 才生效, 默认关; 需 K 确认
- **总则**: 本机主两组 supp 队列全部领走后, 空槽**只能跑排队的下一条假设**, 按下列优先级; 原有各组的 n 与判据都不变; 补位数据**单独判读**, 不进 ANISO/H050 结论, 不替代任何主跑. 领取同样须 now+need+0.75 h ≤ 06:50. 每条 = 一个单槽块 (一个槽从头跑到尾, 不跨槽).
- **§8.1 第一优先 XEXT**: R4N5 360 K 五条已 DONE 的跑从 1200 ns 续到 3000 ns — k03: DOPE s501, s502, s504; k04: DOPC s502, s503 (chains/xext_<机>.txt).
  - 源 = 同机 `$HOME/R4N5/R4N5_run_<机>_*/builds/<b>/prod/attempt_001/{prod.tpr,prod.cpt}`, 须 STATUS DONE laststep≥6e7 且 sha256 与同目录 SHA256_out.txt 相符; 续跑 = `convert-tpr -nsteps 150000000` + `mdrun -cpi prod.cpt -noappend` (lib run_ext). 源缺/不符 → 记 XEXT_NO_SRC, **不从头重跑**, 该槽退到 §8.2.
  - 判读: 冻结 P/N/总判, 视界 3000 ns, NO_EVENT 须 T_obs≥2999 ns (否则 TRUNC_N6). 选中跑 = R4N5 原 s1–s3 + 替补按 R4N5 记录 (DOPE s503 VOID_L2 → s504 顶; DOPC s501/s504 VOID_L2 无替补).
  - **已知限制**: DOPC 只有 2 条可评 (n_eval≤2) → 规则 N 只能 FAIL (有事件) 或 NOT_EVALUABLE, XEXT 总判**不可能 CONTRAST_PASS**; 结论最多是「DOPE 在 3 µs 内是否转变 + DOPC 两条是否仍干净」. 不补新种子 (不在预注册).
  - 描述列 (13:47 加; 不进门): 搭桥 ncl — ncl_t0, ncl_min, ncl_min_1200_3000, frac_ncl1_1200_3000; Cz 下降 — Cz_0_50, Cz_1150_1200, Cz_last50, dCz_ext (= Cz_last50 − Cz_1150_1200), Cz_min_20ns (20 ns 滑动均值最小值) 与其时刻. 1200 ns 时基线 (R4N5 实测, box 已算): DOPE s504 Cz_1150_1200 = 0.69, s501 1.10, s502 1.24; DOPC s502 1.25, s503 1.26.
- **§8.2 第二优先 NEXT = Q2a+ h050@T360** (Q2a 的下一档温度): DOPE/DOPC 各 s501–s503 + 替补 s504→s505, 起点同 Q2a (D1v2 h050), 只派生 ref_t/gen_temp → 360. 冻结规则、1200 ns 视界、单独判读 (wrap 的 NEXT 块).
- **原 Q3 (VOIDFIX) 状态**: 需新建宿主稀释结构 + 过 L1 + K 批准, 今晚不可跑. 13:47 所说「断点不在就退回 Q3」在本包落实为退到 §8.2 (原 Q3 位置的、已预审可跑的下一条). Q3d (承认纯中性 MC3 片层格判不出, 改读法不改门槛) 不需机时, 待 K 批.
- 不得在空槽跑任何未在本节列出的作业.

## §9 利用率 (估算; tools/sim_util_N6.py, 贪心模拟领取顺序, 名义速度, 无 VOID)
| 起跑 | ANISO 慢速 | XEXT 源在 | k03 | k04 | 合计 |
|---|---|---|---|---|---|
| 15:00 | 1.00 | 在 | 89% | 88% | 88% |
| 15:00 | 1.25 | 在 | 94% | 87% | 91% |
| 15:00 | 1.00 | 不在 | 60% | 70% | 65% |
| 17:00 | 1.00 | 在 | 87% | 84% | 86% |
- 源在时约 86–91% (估算), 贴近 90% 目标; 尾段损失来自 0.75 h 余量 + 最后一块放不下. 源不在时只剩 NEXT 3 条, 约 65–81%, 达不到 90% —— 要补足只能再预注册下一条假设 (例如 Q2b 或 h050@T330), 不在本包.
