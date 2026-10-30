# PRE_REG_AMENDMENT_R4N1_02 — PREREG_R4_3day.md 第 2 号修订 (R4N1x 追加包)

- 时间: 2026-10-30 约 13:30 (+0800) 写定。**零数据**: R4N1 主包 (commit 04e94e52) 约 14:30 才发车；R4N1x 一条都没跑；没有任何 R4N1/R4N1x 结果被看过。
- 依据: 10-30 12:42 的 R4N1x 规格与 12:44 的分段闭环要求 (手动接入时点 + ONLY 列表 + 包外 interim_pull.sh)，二者都由主控转述；K 原话只是“用满机时、全量规划 (含替补与潜在方案)、分段闭环、每天至少更新一次的仪表盘”。§2 的裁剪序是主控按这些要求做的排程选择，**不是 K 原话**；与 K“每格四条同跑”的关系见 §2 末条。
- v3 修订 (2026-10-30 约 13:45 +0800，独立审查，仍零数据): 只改措辞、归属与覆盖范围的说明；判据阈值、读法分支、降级范围的机算规则都不变。
- 性质: **加条目，不改任何已有判据**。PREREG §5 的 RULER 规则 1–3、内标相类与 Δ、F1–F4、条件优先级、时间稳健性 (撤回规则)、AMENDMENT_01 全部原样。冻结 verdict_R4_3day.py (sha 4fd49504…) 不改一个字节。

## 1 新增条目
| 臂 | 条件 | 体系 × 起点 | n | 时长 | 判据 |
|---|---|---|---|---|---|
| **L 臂 (优先)** | 320 K, h050 | DOPE_hiiL、DOPC_hiiL (长盒 H_II 起点) | 3 主 + 1 替补 / 格 | 400 ns | 本修订 §3 (描述量与阈值 = hii 臂) |
| C4 | 350 K, h100 | DOPE/DOPC/MC3H/MC3 × hii/lam | 3 主 + 1 替补 / 格 | 400 ns | PREREG §5 原判据 (冻结 verdict 原样) |

- 长盒几何 (SYSTEM.txt, L1 40/40 PASS): DOPC_hiiL Lz0 = 21.93 nm (r_water0 1.84 nm, Lz0/(2π r_water0) = 1.90)；DOPE_hiiL Lz0 = 38.18 nm (r_water0 0.95 nm, 6.4)。
  - DOPC 21.93 nm 比 K 写的“Lz ≥ 约 22 nm”短 0.07 nm (0.3%)：沿用冻结的 Lz 规则 (a_w 取最接近 0.60 nm² 的格点) 把短盒 Lz 翻倍得到，不另行调整；列为已知偏差。
  - 两套标准并列写明: “约 22 nm”数值上等于 **h100** DOPC 的 2π r_water0 (2π×3.47 = 21.8 nm)；本 L 臂是 **h050**，其 2π r_water0 = 11.56 nm，长盒 21.93 nm 是它的 1.90 倍，短盒 10.97 nm 是 0.95 倍。按无黏 Rayleigh 估算最快增长波长约 9 r ≈ 16.6 nm (估算；黏性比不同时会变长)，落在短盒之外、长盒之内。所以 L 臂检验的是 h050 下的盒长效应，不直接检验 h100 (见 §3.3 覆盖范围)。
  - semiiso 控压下 Lz 会漂移；判读不读 Lz(t)，回传后另作描述 (Lz_末/Lz0)。
  - 对照短盒 (主包 C1): DOPC h050 Lz0 10.97 nm (比值 0.95)，DOPE h050 19.09 nm (3.2)。
- 种子: s1–s3 主、s4 替补，builder 种子与主包不同 (新 build)。不加 n，不加种子 (n=3 严格)。

## 2 排程与裁剪 (包的事，不改判据)
- 每槽在主包本槽 done 或闲置后接上 (或调度在指定时点手动接入)；DEADLINE 2026-10-31 07:30 (+0800)，未完成的条目记 TRUNC，第 2 晚续跑 (续跑判读按 PREREG“最终结论只用最长时长”)。
- 裁剪序 (K 12:42): 先裁 C4 内标 (MC3H/MC3)，再裁 C4 lam。按估算 (主包槽长 × 12/9.68)，今晚主链只含 L 臂 12 条中的主 6 条 (DOPE ×3 → k03，DOPC ×3 → k04) + C4 DOPE_hii ×3 + C4 DOPC_hii ×3；C4 DOPC_lam ×3、DOPE_lam ×3、内标 12 条进补跑队列 (槽有余量且放得下才跑，否则第 2 晚)。
- **C4 今晚多半判不出 RULER**: 规则 3 需要 DOPC_lam 3 条；若补跑队列未跑到，C4 记 RULER_NOT_EVALUABLE (按 PREREG §5 原文，不算 PASS)，不提前下结论。
- 同条件同臂的 MC3H/MC3 同机、成对交替 (同 AMENDMENT_01 §3 M2 补)；每格 3 主与替补同机。
- **与 K“每格四条同跑，禁止只跑 DOPE+DOPC”的关系 (须 K 拍板)**: 今晚 C4 主链只有 DOPE_hii + DOPC_hii，MC3H/MC3 在补跑队列，多半跑不到 (估算)。PLAN v2 把 K 的规矩解释为“同一晚至少一个四体系完整的格”(主包 C1–C3 今晚满足)；这是解释，不是 K 原话。若 K 按字面执行，今晚应用 ONLY=Larm 只跑 L 臂 (L 臂是方法检验，不是配方格)，C4 整格推到第 2 晚。

## 3 L 臂判据 (看数据前写定)
### 3.1 单 run 与格
- 单 run: 冻结 verdict 的 judge_hii_run 原样 (判定窗 = 末 100 ns、≥99 帧；RETAIN f_HII ≥ 0.80；LOST f_HII ≤ 0.20；≥ 400 ns；否则 TRUNC/WINDOW_INCOMPLETE)。hiiL 一律按 hii 判。
- 格: 冻结 verdict 的 select_cell / hii_cell 原样 (3 主，VOID 由同格 s4 顶；可评估 n<3 → NOT_EVALUABLE)。
- 实现: N1x/verdict_Larm.py 只调用冻结模块的函数，运行时仅把名字正则多认 hiiL，冻结文件不动；单元测试 tests/test_verdict_Larm.py 11 项 (v3 加 1 项: h100 不被放行) + 原 19 项全过。

### 3.2 预写读法 (K1: 短盒 Lz < 2π r_water 是否抑制 DOPC 塌管)
- 比较时长 H_cmp = 长盒 DOPC 格与短盒 (C1) DOPC 格所用 run 的最短观测时长；须 ≥ 400 ns，否则 NOT_EVALUABLE。两边都截到 H_cmp 判，**决定性读法只看 H_cmp**；400 与 max 两个时长只描述。
- 记 L = 长盒 DOPC_hiiL 格，S = 短盒 C1 DOPC_hii 格。
  - L 的 LOST ≥ 2/3 且 S 的 LOST < 2/3 → **SHORT_BOX_ARTIFACT**：短盒伪影成立，按 §3.3 降级。
  - L 与 S 都 LOST ≥ 2/3 → CONSISTENT_LOST (未见盒长伪影)。
  - L 与 S 都 RETAIN ≥ 2/3 → CONSISTENT_RETAIN：在 h050、Lz0 约 22 nm、H_cmp 内未见盒长效应。只能说 K1 在这个范围里没有得到支持；更长波长或更慢的失稳没有排除，也不覆盖 h100 (§3.3)。
  - S 的 LOST ≥ 2/3 而 L 没有 → LONG_BOX_RETAINS_MORE：方向与 K1 相反，只报告，不降级也不升级。
  - 其余 → MIXED，不下读法；任一格不可评估 → NOT_EVALUABLE。
- DOPE 长盒是阳性对照: DOPE_hiiL RETAIN ≥ 2/3 → POS_OK，否则 POS_FAIL (POS_FAIL 时 SHORT_BOX_ARTIFACT 照报，但另行注明“长盒下阳性对照也不保持，长盒读出本身可疑”)。
- 长盒尺子 (规则 1 用 DOPE_hiiL、规则 2 用 DOPC_hiiL) 只作描述，**不替代 RULER(C1)，不改 C1 的判定**。

### 3.3 降级的范围与含义
- 范围 (从 SYSTEM.txt 机算): 所有 Lz0 < 2π r_water0 的 H_II 起点构型 (Rayleigh–Plateau: 盒长短于 2π r 时轴向不稳定模式放不进盒子)。按现有 build: DOPC/MC3H/MC3 h050 (比值 0.95)、DOPC/MC3H/MC3 h100 (约 0.28)；DOPE h050 (3.2) 与 DOPE h100 (1.07) 不在范围。
- 含义: 范围内 H_II 臂的 RETAIN 读数降级为“可能被盒长伪影抑制”，不作 H_II 偏好证据 (包括内标相类里的 HII_PREF/HYST，以及 R2a 以 H_II 保持为据的 MC3H 解释)。
- 覆盖范围: L 臂只在 h050 做。h100 的 DOPC/MC3H/MC3 短盒 (比值约 0.28) 没有长盒对照，不论 L 臂读成什么 (包括 CONSISTENT_RETAIN / CONSISTENT_LOST)，它们的 H_II RETAIN 读数都只标注“盒长未检验”，不因 L 臂结果而被放行 (verdict_Larm.py 输出 not_covered_by_Larm)。这是标注，不改任何 RULER 判定。
- **不放宽**: 各条件 RULER 判定、F1–F4 原样输出；不把任何 FAIL 改成 PASS；不重判已出的 verdict，只在其后附降级说明。

## 4 包与守卫的改动 (认出并排除，不是放宽)
- 主包运行时，追加包的 launch_guard 会看到主包的 gmx/容器/MPS。它不再像主包那样把“任何其它 gmx/MPS”判 FAIL，而是先**认出**主包的 (gmx 进程的 cgroup 属于 `R4N1_<本机>_<pid>_` 容器；MPS 进程的 CUDA_MPS_PIPE_DIRECTORY 在 `$HOME/mps_R4N1/` 下)，把它们排除后，剩下的照旧：只要有认不出的 gmx 或 MPS → FAIL。主包的 run_R4N1.sh 只作提示。
- 追加包不起 MPS，除非主包锁已释放、机上没有任何 MPS 进程；起的话只用自己的管道 `$HOME/mps_R4N1x/`，收尾只对自己的管道发 quit，从不 kill。
- 每槽开跑前必须本槽没有主包容器，这一条没有任何开关可以绕过 (GO 文件与 START_AT 只能“更早/更晚允许”，不能越过它)。
- 其它沿用主包: $HOME 规则、HALT 只认本包 `$OUT/HALT`、账本幂等续跑、SHA256_out、DEADLINE 截断。

## 5 不变的
- PREREG_R4_3day.md (sha 19622358…)、AMENDMENT_01 (sha 5b850f29…)、verdict_R4_3day.py (sha 4fd49504…)、tests/test_verdict.py、mdp 5 个与 gate/ 逐字同主包。
