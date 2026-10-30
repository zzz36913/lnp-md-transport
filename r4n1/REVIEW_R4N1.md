# REVIEW_R4N1: R4 第 1 晚 (R4N1) 发车包独立审查
审查人: Grok Bot (独立审查, 非打包人)。时间: 2026-10-30 12:15 (+0800)。
对象: R4N1_full.tar.gz (sha 62d7d847…9cc7)、R4N1_reduced.tar.gz (sha 42ccd16c…a62e)。两个 sha 已复核, 与 TARBALL_sha256.txt 一致。
依据: PREREG_R4_3day.md (sha eb00fa93…b1a9), PLAN_R4_3day.md, RUNBOOK.md, 先例 REVIEW_D1v2 / R2a。
方式: 解包到 /tmp 只读审查。没有改包、没有上传、没有碰 Spark、没有发消息。下文行号均为包内文件的行号。

## 结论: **PASS-WITH-FIXES**
机械层面全部通过: 完整性、PREREG 常量、闸门、mdp、MPS、GLM 隔离、幂等, 判据也没有放宽。
有 3 个必修项, 都应在发车前处理:
- M1、M2 涉及判读与替补机制, 改了要重冻 sha;
- M3 是包外清单的修改。
M1 若由 K 书面裁定以 PREREG §5 为准, 可以不改代码。
完整版能否 19:30 发车, 见 §4 时间预算。

## 1. 逐项核对
| # | 项 | 结果 |
|---|---|---|
| 1 | tarball / MANIFEST | 两个 tarball 的 sha 都对; `sha256sum -c` 全 OK (full 共 1445 条)。FROZEN_sha256 与 verdict、PREREG、D1v2_lam_runs.tsv 的 sha 一致。包内 PREREG、PLAN 与 workspace 版本逐字节相同。hardlink 计数 full 64、reduced 48, 与清单一致。full 和 reduced 只差 MANIFEST、VARIANT、chains/ 和 16 个 h100_T320_hii 输入目录 |
| 2 | PREREG 常量 | verdict_R4_3day.py 中的 N_PER=3, WIN=100, WIN_MIN_FRAMES=99, T_EVAL=400, 0.80/0.20, LAM_RETURN 0.6, Cz 0.5/20 ns, 合并 5 ns, 规则 2 / 0&2 / 0, Δ=2 均与 PREREG §3/§5/§9 一致 |
| 3 | 判读逻辑 | frame_cls (L66–68)、judge_hii_run (L83–109)、judge_lam_run、select_cell (L213–231, 替补只顶 VOID)、RULER / Δ / F1–F4 / 主条件优先级 C1>C3>C2>C4 都对。**例外是 phase_class 的双 VOID 情形, 见 M1** |
| 4 | 单元测试 | `python3 tests/test_verdict.py`: 17 个测试全部 OK (只有 ResourceWarning)。test L89 断言的是双 VOID→NEITHER, 也就是把 M1 的不一致固化进了测试 |
| 5 | 350 K mdp | 126 个文件的 ref_t / gen_temp / tau_t 全 OK (proof/mdp_temp_check.tsv)。prod: τp=4 ≥ 25·5·0.02=2.5; relax: τp=1 ≥ 0.75, 符合 gmx 2026 规则。rlist 固定 1.35, verlet-buffer-tolerance=-1; 350 K 下自动 rlist 为 1.292 (4×4) / 1.368 (1×1), 见 proof/verlet_buffer_350K_info.txt, 所以 1.35 足够 (1×1 差 0.018 nm, 实际 GPU 用的是 4×4/8×8 列表)。prod mdp 第 1 行注释还写着 "R4 D1 prod 500 ns lam", 不影响运行 |
| 6 | H_II 构建 | Lz 按 PREREG §2 冻结规则取 (a_w 最接近 0.60): tools/build_R4N1.py L5, L70–78。h100 盒子 19.06×16.51×6.16 nm, r_water 3.47; h050 盒子 12.72×11.01×10.97, r_water 1.84。L2 闸门在 gate/t0_gate_hii.py L4, L22–23: wpol==1、n_tube==4、盒子三边变化 ≤30%、组成正确。物理上的局限见 K1 |
| 7 | 运行安全 | DEADLINE 写死为 "2026-10-31 07:30 +0800" (lib L16)。输出用 mkdir 原子创建, attempt_NNN 只增不改, 续跑用 -noappend (lib L258–259), ALL_RECORDS 只追加。MPS 每次用全新 $HOME/mps_R4N1/<机>_<TS>, 只 quit 自己的 pipe。launch_guard 遇到 MPS 残留只认人并判 FAIL (run L61–62); tools/mps_residue.sh 只有在 QUIT=1、owner 是自己、pipe 在 $HOME/mps_R4*、且无 gmx 时才 quit, 从不 kill 也不删目录。trap 只停本脚本前缀的容器 (run L138–139)。脚本里没有任何 8888/18888、GLM 容器或 vLLM 的字样。SHA256_out 在每个 prod attempt 内生成 (lib L275)。gatewrap 容器 --network none, 不挂 GPU, 只挂 $HOME 和 /tmp |
| 8 | 删除动作 | lib L212 和 L238 会 `rm -f` 本函数刚生成的逐帧 json 和非选中帧 .gro (trr、frames.tsv、各帧 json 都保留)。这与 D1v2 lib_R4.sh L43 相同, D1v2 审过并实跑过, 按先例不列为必修, 见 S5 |
| 9 | relax 时长上限 | lib L176 把 relax 的 maxh 封顶为 1 h。D1v2 实测 relax 5123–9932 ns/day, 跑 15 ns 约 2–4 min, 没有问题 |

## 2. 必修项 (发车前处理)
**M1 phase_class 双 VOID 与 PREREG §9 第 7 条不符 (同 D1v2 那类"配方与原文不一致")**
- 代码: verdict_R4_3day.py L275 `if (Hl or hv) and (Le or lv): return 'NEITHER'`。
- 实测: phase_class(VOID, VOID) 返回 'NEITHER'; tests/test_verdict.py L89 也断言 MC3 的结果是 'NEITHER'。
- PREREG: L155 (§9 第 7 条) 写的是"某体系在某条件下两臂都 VOID 时，相类记 NOT_EVALUABLE 并附说明"; 但 L99 (§5) 写"NEITHER：两个起点都 LOST 或 VOID"。PREREG 内部本身矛盾, 代码选了 §5 的读法。
- 影响: 预计 MC3 的片层臂在 C1/C3 为 VOID (D1v2 10/10)。如果 H_II 臂也 VOID, 报告里会写 "NEITHER" 而不是 NOT_EVALUABLE。不影响 RULER、Δ 或主条件判定 (Δ 已在 L307–308 处单独记 NOT_EVALUABLE 和 MC3_note), 只影响相类标签。
- 修法 (二选一):
  - (a) 在 L275 前加 `if hv and lv: return 'NOT_EVALUABLE'` (说明保留 MC3_note), 同步改 test L89, 重冻 FROZEN_sha256 和 MANIFEST, 重打 tarball;
  - (b) K 书面裁定以 §5 为准, 记入 PREREG 附注。
  建议选 (a), 因为 §9 是"实现澄清"层, 更具体。
- 单臂 VOID 加另一臂 LOST 记 NEITHER, 与 §5 一致, 不用改。

**M2 替补按机器记账, 15 个格子的 s3 主种子"有替补却够不着"**
- 代码: tools/make_chains.py 的替补规则 (docstring 第 6 行, 以及 plan() 末尾的 spares 分配): s4 放在该格主种子较多的那台机器上。run_R4N1.sh L97–105 的 claim_supp 只看本机账本里的 void 和本机的 spares 文件。
- 实测 (full 版): 15 个有替补的格子, s3 都在另一台机器上 (DOPE/DOPC 的 s3 在 k04, 替补在 k03; MC3/MC3H 反过来)。DOPC_h050_T350_hii 本来就没有替补 (s4 已顶为主)。合计 18/48 条主 build 一旦 VOID 就没有可用替补。
  - 这包括 C1、C2、C3 全部尺子格的 s3。只要其中一条 VOID_L2 或 RELAX_FAIL, 该格 n=2, 该条件就是 RULER_NOT_EVALUABLE, 而对应的 s4 一直闲置。
  - 第 2 晚用 APPEND_TO 续跑也救不回来, 因为账本仍按机器分开。
- 这样运行违背 PREREG §4 (L80) "每格 3 主 + 1 替补" 的本意。
- 修法 (任选一种):
  - (a) claim_supp 接受一个包外文件 $J/R4N1_ext_void.txt (由人从另一台机器的 SUMMARY 里抄 UNRESOLVED_VOID), 把其中的 build 当作本机 void 写入 replfor 账本, 并在 ALL_RECORDS 里记上来源;
  - (b) 在 SPARK_CHECKLIST 里写明手工跨机替补的流程, 并由 K 书面接受"第 1 晚 s3 VOID 不可替";
  - (c) 重排链, 让尺子格 (DOPE/DOPC) 的 3 个主种子和 s4 都放在同一台机器 (A/B 两槽, 其中一槽放 2 条)。
  改了包就要重打包、重审。

**M3 SPARK_CHECKLIST.md (包外, 13 条) 缺项, 而且第 8 条会误导操作**
- 第 8 条 (L9) 让人拿"头 1–2 条 relax 的 performance"和 PERF_NOM=14258 比。但 PERF_NOM 是 **prod** 速率; D1v2 实测 relax 只有 5123–9932 ns/day (THROUGHPUT.tsv)。照这一条做, 一定会判成"明显偏低", 进而错误地写低 F_THR。应改为比较第 1 条 prod 前 15–20 min 的 ns/day (prod.log 或 THROUGHPUT.tsv 的 stage=prod 行), 或者给出 relax 的参照值 5–10k。
- 需要补上的条目:
  - 发车前提: 本地助理确认 GLM "已停、显存已清空" (RUNBOOK L691), 再按 CHECK=1 → DRY=1 → `setsid nohup bash run_R4N1.sh <机> &` 的顺序发车, 两台机器各一个实例。
  - 发车前后都要确认 GLM 的 8888/18888 和 GLM 容器没被动过 (本包不碰, 但要有记录)。
  - 07:30 收数, 08:00 前交还 GLM (RUNBOOK L910)。收尾后确认 nvidia-cuda-mps=0、R4N1_ 容器=0、pgrep gmx=0。
  - 运行中不改 chains/ 和包内文件 (MANIFEST 会失配)。
  - 第 2 晚 APPEND_TO 之前先备份 RUN_META (RUNBOOK L993)。
  - 第 12 条: 应写成"19:30 前 launch_guard 全 OK 才用 full", 不只是看钟点。

## 3. 须 K 知情 (不阻挡发车)
**K1 H_II 的管长短于水通道直径, Rayleigh–Plateau 珠串模式被排除 (估算, 定性)**
- h100: Lz=6.16 nm, r_water=3.47 nm, 不稳定波长下限 2πr≈21.8 nm, 远大于 Lz。
- h050: Lz=10.97 nm, 2πr≈11.6 nm, 也略大于 Lz。
- 周期性边界使水管成为"无限长", 但波长大于 Lz 的起伏和珠串都被禁掉了。这会让结果偏向 H_II RETAIN:
  - 规则 2 (DOPC 须 LOST ≥2/3) 更难过, 尤其在 C3。这偏向尺子 FAIL, 方向是保守的, 不会造成假 PASS;
  - MC3 和 MC3H 两边同受影响, 但 Δ 的灵敏度会下降。
- Lz 是 PREREG §2 冻结的规则, 本包照做, 不是包的错。但 full 比 reduced 多出来的正是 C3, K 选 full 时应当知道这一点。报告里应写明这是解读局限。

## 4. 时间预算 (19:30 发车, 估算)
- 可用时间: 19:30 → 07:30 共 12 h, 扣掉 TAIL_H 0.25 h, 约 11.75 h。
- PLAN_ESTIMATE 的最长槽 k04_B 为 9.71 h (f=1.0, 基于 D1v2 实测 prod 速率; 350 K 和 H_II 盒形尚未实测)。

| f | 最长槽 (估算) | 预计结束 |
|---|---|---|
| 1.0 | 9.7 h | 约 05:15 (+0800) |
| 0.9 | 10.8 h | 约 06:20 (+0800) |
| ≈0.83 | 约 11.7 h | 收支平衡 |
| 0.8 | 约 12.1 h | 超出 |

- f<0.83 时会发生什么:
  - 主批只要剩余 ≥ MINRUN_H 0.6 h 就开新条 (lib L281), prod 的 -maxh 取剩余减 0.25 h (lib L254)。所以各槽最后一条会被截成 TRUNC: 这一晚不可评估, 也不用替补顶 (符合 PREREG §9), 第 2 晚可以用 APPEND_TO 加 -noappend 续跑。
  - k04 两条链的末尾正好是 C3 的尺子 s3 (k04_A DOPE_h100_T320_hii_s3, k04_B DOPC_h100_T320_hii_s3), 倒数第二条是 C2 的尺子 s3。所以速率一偏低, 最先丢的就是 C3、C2 的尺子, 见 S1。
- 替补只在本槽主链跑完后才领取, 而且要求剩余 ≥ need + 0.75 h (run L95–96, 约 1.5 h)。f=1 时 k03 约 05:00 结束, 还剩约 2.5 h, 每槽大约能跑 1 条替补; f≤0.9 时基本跑不上。

## 5. 建议项 (不阻挡)
- **S1** tools/make_chains.py docstring 第 4 行定的轮内顺序是 C1>C2>C3, 尺子先跑。结果 k04 链尾全是 C3/C2 的尺子 s3, 而 k03 链尾是 MC3/MC3H。建议让两台机器的链尾都放 MC3/MC3H 的 s3, 或按 PREREG 的优先级 C1>C3>C2 排, 这样速率偏低时先丢 Δ 而不是丢尺子。
- **S2** run_R4N1.sh L42–44 的时间估算只打印 [info]。建议 VARIANT=full 时加硬判据: 最长槽 need > 剩余 − TAIL_H 就 FAIL, 并提示改用 reduced。
- **S3** launch_guard 缺一条显式的"$HERE 和 $J 都在 $HOME 下"检查。现在只是间接靠 gate 自检失败兜底 (gatewrap 只挂 $HOME 和 /tmp)。
- **S4** VOID 的格子可以考虑在本槽内立刻跑替补, 而不是等主链跑完, 这样替补不会被链尾的时间判断挤掉。
- **S5** lib L45 SEL_KEEP_FRAMES 默认为 0, 与 K "不删除" 的字面要求有张力 (删的是自产中间帧, 可以从 trr 重建)。先例 D1v2 lib_R4.sh L43 同样如此。如果 K 要字面执行, 可设 SEL_KEEP_FRAMES=1; 估算每台机器多占约 3 GB, launch_guard 的磁盘门槛 5 GiB (run L65) 也要同步调高。
- **S6** 外观问题: prod mdp 第 1 行旧注释; run L126 的 DRY 输出两臂都写成 prod_lam; gatewrap 的头注释还写着 R3; lib L23 PERF_NOM 线性按珠数缩放, 对小体系 DOPE h050 约偏乐观 8% (估算)。
- **S7** F1 (verdict) 要求所有已跑条件的规则 2 都是 "FAIL"; 只要有 NOT_EVALUABLE 就不触发 F1。PREREG "都不满足规则 2" 的措辞两种读法都可以, 建议在报告里写明采用的是哪种。

## 6. 审查过程说明
12:09 (+0800) 我在 /tmp 的解包副本里, 误用一条 `sed …/e` 命令打印 lib 的行号, 结果把 lib 的 L140–290 当作 sh 片段执行了。
- 因为变量都为空, 所有写入都指向 / 而被拒 (Permission denied); box 上没有 docker 和 gmx。
- 事后复核:
  - 解包副本的 `sha256sum -c MANIFEST` 全 OK;
  - 两个 tarball 的 sha 未变;
  - /builds、/frames 都不存在。
- 没有影响任何包或 Spark。

---

## §R2 复审 (修订后的包, 2026-10-30 12:35 +0800)

**结论: PASS (无必修项)。** M1/M2/M3 都已按报告落实。采纳的 6 条建议没有引入阻挡发车的新问题, 修订文书也没有放宽任何判据。下面列 5 条建议 (R2-S1…S5) 和 1 条须 K 知情事项 (R2-K1), 都不阻挡发车。Spark 上的事项照 SPARK_CHECKLIST 核。

### R2.0 完整性 (只在 /tmp/rev2 的解包副本上做)
- tarball sha: full 1b632a5d…c2c9, reduced 8a19062f…9e74, 与 TARBALL_sha256.txt 一致。复审结束后再核一次, 未变。
- 两包 `sha256sum -c MANIFEST_sha256.txt` 全 OK。FROZEN: verdict 4fd49504…, PREREG 19622358…, AMENDMENT_01 5b850f29…, 与实际文件一致; D1v2_lam_runs.tsv 未变。
- ff 硬链接数 64 / 48。
- full 与 reduced 只差 MANIFEST、VARIANT、chains/ (含 supp 头注释) 和 h100 inputs。
- 所有 mdp 改动都只在注释里: 逐 build 去掉注释后比对, 无差异。proof/grompp_box_amend01.tsv 共 126 行, 全部 rc=0、0 warning。

### R2.1 M1/M2/M3 落实情况
- **M1 已落实。**
  - verdict L270: `if hv and lv: return 'NOT_EVALUABLE'`, 先于 L276 的 NEITHER 分支。
  - PREREG L99 已改, 与 §9.7 一致。
  - tests L89 改为断言 NOT_EVALUABLE; 新增 PhaseClassAmend01 两项 (双 VOID → NOT_EVALUABLE, 一 VOID 一 LOST → NEITHER)。
  - full/reduced 的测试都是 19 项, 全过。
- **M2 已落实**, 走的是报告的 (a) 方案:
  - make_chains.py 整格同机, 替补随格走。
  - 重算覆盖 (按机账本, 见 R2.4): 暴露的主种子 0 条 (上一版 18/48)。
- **M3 已落实**: SPARK_CHECKLIST.md 共 18 条, 详见 R2.6。
  - 第 13 条已改为拿 prod 速率与 PERF_NOM 比, 并写明不要拿 relax 比。

### R2.2 采纳的建议是否带来新问题
- **内标放链尾 (S1):** 实现正确。截断时先丢的是内标的 s3 对, 尺子在前, 不受影响。顺序问题见 R2-S2。
- **19:30 拒跑 (S2):** FULL_CUTOFF 写死在 lib L17 (+0800), 不读 env。在副本上实测:
  - 门槛改到 12:00 → `[FAIL] 完整版只允许在…之前新启动`;
  - 在 TZ=America/Los_Angeles 下同样 FAIL (不依赖时区);
  - 设了 APPEND_TO → 不拦;
  - VARIANT=reduced → 不拦;
  - 用 env 设 FULL_CUTOFF → 被忽略。
  - 漏洞: APPEND_TO 只查目录存在 (lib L97), 见 R2-S1。
- **$HOME 检查 (S3):** run L51–52。
  - docker 模式下, 包不在 $HOME 时 [FAIL], 已实测;
  - MODE=local 下只打印 [info], 已实测;
  - $HOME 本身做包目录也能匹配。
- **SEL_KEEP_FRAMES=1 (S5):** lib L46 默认值改为 1; L238 的清理只在等于 0 时执行。CHECK 输出里显示 (SEL_KEEP_FRAMES=1)。
- **重试不再删旧 json (S5):** lib L213–216。每次重试写独立的 f<i>_try<n>.json/.out, v 和 r65 只从本次的 $fj 读。
  - 上一轮担心的"本次没写 json, 却读到旧 json"不会发生, 比原来的 rm 方案更稳。
  - 全包 grep 过, 没有别处读旧名 f$i.json。
- **磁盘门槛 10 GiB:** run L73。不删帧后每台机多占约 3 GB (估算), 10 GiB 足够。

### R2.3 内标同机、链尾成对交替 (01b)
- **chains 与生成器一致:** 在 /tmp 副本上重跑 make_chains.py, 生成的 chains_full/、chains_reduced/ 与包内 chains 逐文件一致。
- **assert 确实生效:** 在副本上做了 6 个变异:

| 变异 | 结果 |
|---|---|
| 把 MC3 挪进尺子段 | AssertionError '内标不在链尾' |
| 拆开一对到两个槽 | '内标未严格交替' |
| MC3 换机 | 01b-1 断言触发 |
| 替补放到另一台机 | M2 断言触发 |
| 配对轮次错开 | 断言触发 |
| 改 A/B 槽内先后方向 | 未触发, 见 R2-S3 |

- **排布结果:**
  - full: C1 和 C3 的内标在 k03, C2 在 k04, 与 README 和修订文书一致。
  - 每槽链尾 6 条 = 3 对, 严格交替: A 槽对内 MC3H 在前, B 槽对内 MC3 在前。
- **截断对称:**
  - 每个槽里, 两边被截掉的条数之差不超过 1。
  - 同一对在同一槽相邻, 所以截到一对中间时, 只有该对所在格少 1 条。
  - Δ 要求两边各 3 条都可评估, 少 1 条就是 NOT_EVALUABLE, 不会带进偏差。
  - TRUNC 可以在第 2 晚用 APPEND_TO 续跑。
- **结论:** 不对称不会污染 Δ。

### R2.4 替补覆盖重算 (按机账本: 主种子所在机 = 替补所在机)

| 版本 | 格 | 主种子 | 替补可达 | 无替补 | 跨机暴露 |
|---|---|---|---|---|---|
| full | 16 | 48 | 15 格 | DOPC_h050_T350_hii (s4 已顶进主链) | 0 |
| reduced | 12 | 36 | 11 格 | 同上 | 0 |

- 每格最多 1 个替补 (s4), 这是 PREREG 原样。
- DOPC_h050_T350_hii 无替补, 已写进 README L24 和 run 头注释。

### R2.5 修订文书 PRE_REG_AMENDMENT_R4N1_01 的措辞
- **"发车前、零数据":** 包内与包外都没有 R4N1 的 Spark 输出 (box_smoke 是 box 冒烟, 不是 R4N1 数据)。站得住, 但这一点只能由主控担保, 本审查无法独立验证 Spark 端。
- **"取更严读法":**
  - 选的是原 PREREG 自己的 §9.7 口径, 不是新发明的规则;
  - phase_class 只用于描述 (verdict L289/L307/L375/L386: 相类、"像谁"、表格和报告), 不进 RULER、Δ 或 F1–F4;
  - 双 VOID 时不下 NEITHER 这个实质结论, 只会让结论更少, 所以没有放宽任何判据。
  - "更严"若写成"更保守 (不下实质结论)", 意思更准确。只是措辞, 不必改。
- **§3 包修复:** 与代码逐条对得上 (行号已核)。§4 列的"不变的"也属实: 阈值、窗口、n、种子、协议、优先级都没动。
- **S4 未做、K1 不改包:** 已如实写明。

### R2.6 SPARK_CHECKLIST.md (18 条) 对照 M3
- 上一轮要求的项都在:

| 要求 | 条目 |
|---|---|
| GLM 已停的确认 | 1 |
| 8888/18888 与 GLM 的前后快照 | 2, 15 |
| 19:30 规则绑定 launch_guard 全 OK | 11 |
| CHECK → DRY → setsid nohup 的顺序 | 12 |
| prod 速率核对 | 13 |
| 运行中不改链 | 14 |
| 07:30 收数 / 08:00 前交还, 且 mps/容器/gmx 都为 0 | 15 |
| APPEND_TO 前备份 RUN_META | 17 |
| MPS 先认人再 quit, 不 kill、不删目录 | 7 |

- 18 条齐。还可以补两条, 见 R2-S4。

### R2.7 测试 / CHECK=1 / DRY (只在 /tmp/rev2 副本上跑, HOME 指向假目录 /tmp/rev2/fakehome)
- **测试:** full 和 reduced 都是 19 项, 全 OK。
- **CHECK=1 (k03、k04):**
  - 包相关各项都是 [ok]: VARIANT、MANIFEST、maxwarn、CUTOFF、chains (k03 A12/B12/spares 7, k04 A12/B12/spares 8)、跨机无重复、磁盘、SEL_KEEP_FRAMES=1。
  - 其余 [FAIL] 都是 box 环境所致: 包放在 /tmp 不在假 $HOME 下 (这正说明新检查生效)、没有 docker/gmx、没有 MDAnalysis、闸门和 trjconv 自检、grompp rc=127。与上一轮一致, 必须在 Spark 上 ALL OK。
- **DRY:**
  - 4 个组合 (full/reduced × k03/k04) 都 rc=0;
  - hii 臂现在打印 prod_hii.mdp (S6 已修);
  - 补跑队列只含本机替补。

### R2-K1 须 K 知情: 包里两套时长估算不一致 (估算)
- PLAN_ESTIMATE (make_chains 的模型) 算出 full 最长槽 9.68 h, reduced 7.11 h。
- run 自带的 need_h (DRY 用它, 补跑判断也用它) 在 f=1 时算出:
  - full: 11.66 / 12.03 / 11.78 / 11.70 h;
  - reduced: 8.46–8.56 h。
- 按 need_h, 19:30 发 full, 最长槽 k03_B 要到约 07:32 才完, 超过 07:30, 链尾最后一对内标会被 -maxh 截断。按 need_h 算, f=1 时 full 最晚应在约 19:13 发车。按 PLAN 的收支平衡点是 f≈0.82。
- 这条不改判据, 也不改 19:30 的硬门槛 (它只是上限)。但定 full/reduced 时应知道: 两种估算差约 24%, 以第 1 条 prod 的实测速率 (清单第 13 条) 为准。

### R2 建议 (不阻挡发车; 若改包须再审)
- **R2-S1 (run L46 / lib L97):** APPEND_TO 只查目录存在。19:30 之后对一个空目录, 或一个由 reduced 包建的 run 目录设 APPEND_TO, 就能绕过 full 硬门槛。建议 APPEND_TO 时要求该目录已有 RUN_META, 且其中的 VARIANT 和 machine 与当前一致。
- **R2-S2 (tools/make_chains.py L58):** 链尾按"轮次 → 条件"排序, 所以 k03_A 最末一对是 C1 的 s3。k03 一旦截断, 最先丢的是最高优先级条件 C1 的 Δ, 而不是 C3。如果希望截断先丢低优先级条件, 可以把内标对的排序改为先按条件、再按轮次 (同样满足成对交替)。现排布不会造成偏差, 只是 C1 的 Δ 可能推迟到第 2 晚才可评。
- **R2-S3 (make_chains.py L78–87):** assert 没检查"A 槽 MC3H 先、B 槽 MC3 先"这一方向规则 (变异测试未触发); assert 在 `python -O` 下会失效。chains 已冻结并入 MANIFEST, 不影响本晚。下次改包时可补方向断言, 并改用显式 raise。
- **R2-S4 (SPARK_CHECKLIST):** 建议补两条:
  - 发车时确认 hostname 与 `<机>` 参数对应 (内标的条件现在按机绑定, run 只把 hostname 记进 RUN_META, 不做校验);
  - 写明紧急停车的做法: 在 $OUT 下放 HALT 文件, 等当前步退出, 再按第 15 条核查; 不 kill MPS, 不删目录。
- **R2-S5 (lib L17):** FULL_CUTOFF 行尾挂着原 DEADLINE 的注释"显式 +0800…", 位置错了。纯外观问题。

### R2.8 过程说明
- 所有解包、变异、CHECK、DRY 都只在 /tmp/rev2 下进行。没有用 sed 的 e 命令; 只有对 /tmp/rev2/mc 副本的 lib 用 `sed -i` 改过 FULL_CUTOFF, 测完已还原, 该副本不入任何包。
- CHECK 在 /tmp 下生成了 /tmp/R4N1_check_* 临时目录, 这是 run 的设计行为。
- 包目录里只追加了本节; 没有改包, 没有上传, 没有碰 Spark, 没有发消息。
