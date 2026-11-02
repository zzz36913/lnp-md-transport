# REVIEW_N5 — R4N5 对 R4N4 的独立自审清单 (2026-11-02, box)
方法: `diff -rq D4/pkg/R4N4 D5/pkg/R4N5` + `diff <(sed s/R4N4/R4N5/g run_R4N4.sh) run_R4N5.sh` (lib 同); 每处改动逐条列出. 未列出的文件 = 逐字节相同.

## A 逐字节未改 (sha256 与 R4N4 同)
- [x] verdict_R4_3day.py / PREREG_R4_3day.md / PRE_REG_AMENDMENT_R4N1_01,02.md / FROZEN_sha256.txt (`sha256sum -c FROZEN_sha256.txt` OK)
- [x] gate/ (去掉 __pycache__), gatewrap/gate_py_container.sh, mdp/ (模板), merge_status_x.py, verdict_Larm.py, tools/mps_residue.sh, tools/check_mdp_temp.py, inputs/ff/*.itp, inputs/D1v2_lam_runs.tsv
- [x] 闸门阈值、relax 协议 (relax_crescale_dev.mdp: 每条 build 只 gen_seed 不同)、prod_lam 加压段 6 键、dt 0.02、输出频率

## B 改动清单
| # | 文件 | 改动 | 为什么 | 风险/核对 |
|---|---|---|---|---|
| 1 | lib_R4N5.sh | 全局 R4N4→R4N5 (perl, 不碰 "[R4N4 v2]" 标记): J=$HOME/R4N5, 输出 R4N5_run_<机>_<TS>, flock .R4N5_<机>.flock, 容器前缀 R4N5_, MPS 根 $HOME/mps_R4N5, R4N5_perf_override.env, /tmp/R4N5_check_/dry_ | 与 R4N4 隔离 | grep 后剩 R4N4 字样只在注释 |
| 2 | lib_R4N5.sh | DEADLINE 默认 2026-11-02 06:50 → **2026-11-03 06:50 +0800** | 今晚收尾 | DRY 显示 deadline 正确 |
| 3 | lib_R4N5.sh | level_sig 加 `5) c-rescale\|semiisotropic\|4.0\|1.0 1.0\|3e-4 3e-4\|5` | 档 5 = LAMSEMI = 第 1 晚 prod_lam 原加压段 | CHECK「档位核对完成: 4 L5」×2 机 |
| 4 | run_R4N5.sh | 档位核对读 `prod_$(arm_of $b).mdp` (原写死 prod_hii.mdp) | 本包是 lam 臂 | 同上; hii 臂行为不变 |
| 5 | run_R4N5.sh | 新增 slot_mps_ok: B 槽每次领补跑前 x_mps_pick, 非 own*/join_main/local 即停领; 停领写 slots/R4N5_slotB_stop.log | K 规则: 2 槽只在 MPS 确认时 | tests/test_slotB_mps.sh ALL_OK (17 例); A 槽不受影响 |
| 6 | run_R4N5.sh | docker 冲突正则加回 R4N4_ (全局替换把它变成 R4N5_ 了) | 防 R4N4 残留容器同跑 | 正则含 R4N4_\|R4N5_ |
| 7 | run_R4N5.sh | PRIOR_RUNS 加 $HOME/R4N3/R4N2_run_<机>_* 与 $HOME/R4N4/R4N4_run_<机>_* (只读查重) | 新名字 s50x 本就不重, 多一道保险 | DRY OK |
| 8 | run/lib 头注释 | 加 R4N5 说明, 旧注释保留 | 可追溯 | — |
| 9 | chains/* | k0x_A/B、ext_*、fill_* 只留注释; supp_k03 = DOPE s501-503, spares_k03 = s504; supp_k04 / spares_k04 = DOPC 同 | 设计 §2 | DRY 队列正确 |
| 10 | inputs/R4N1_*_lam_s50{1..4} (8 个) | 第 1 晚 D2/N1x/inputs lam_s{1..4} 逐字节复制; relax gen_seed 新; prod_lam nsteps 2e7→6e7 + gen_seed + 1 行头注释 | 设计 §2 | tools/derive_R4N5.py 断言 6 加压键 = 档 5 且 dt==0.02; DERIVED.txt 记源 sha; grompp 16/16 rc=0 0 warning |
| 11 | inputs/L1_summary.tsv | 换成 8 行改名后的源 L1 行 (全 PASS); inputs/R4N5_builds.tsv 新 | 冻结 collect 读此表 | — |
| 12 | proof/neg_selftest_bridged.gro | **新增** (取自 D2/N2/pkg/R4N2/proof, sha d696d495…) | **R4N4 包缺此文件, 其闸门负自检因文件不存在 rc≠0 而「假通过」** | 本包实测该帧被闸门判不合格 (rc=3, 读数 1/3/3/2) |
| 13 | verdict_N5_wrap.py | 新 (取代 verdict_N4_wrap.py): 种子 50x→1..4, CONDS=C4r, 满窗 TRUNC_N5, 规则 P/N, 总判 | PREREG_N5 §5 | tests/test_verdict_N5.py 8 例 ALL_OK |
| 14 | xfer_small/collect_small.sh | 换成 R4N4 fix1101 版 (repo r4n4/xfer_small, sha 6644f573…) 再改: R4N4→R4N5, verdict_N4→N5, PKG 默认 = 上一级, collect 后跑 N5 judge | 时刻表 02:00 COLLECT=0 / 07:00 COLLECT=1 | bash -n OK; 未在 Spark 上实跑 |
| 15 | 删 | verdict_N4_wrap.py, PREREG_N3/N4, PLAN_N4, README_R4N4, REVIEW_N4, SELFCHECK, R4N4 hii inputs, R4N4_builds.tsv, tests/ 旧件, proof/grompp_box | 本包不用 | — |
| 16 | VARIANT | night5_lam_ctrl (v2: night5_lam_ctrl_v2_mc3_branch) | 标识 | — |
| 17 | tests/ | 新: test_verdict_N5.py, test_slotB_mps.sh; 从 R4N4 复制 mock/ 并 R4N4→R4N5 改名得 test_mps_n2_onN5.sh, test_mps_wait_n4_onN5.sh (证明 MPS 逻辑改名后行为不变) | 回归 | 4 个全过, 见 SELFCHECK_N5 |
| 18 | chains/supp_k0{3,4}, spares_k0{3,4} | [v2] supp: 尺子 s501-503 后接 MC3H(k03)/MC3(k04) s501-503; spares 加 MC3H/MC3/T360/T330 的 s504 | K 13:46 加 MC3 | 尺子仍先领; 替补只顶 VOID |
| 19 | chains/branch_{a,b,c}_k0{3,4}.txt | [v2] 新: 分支队列 (a: MC3H/MC3 s505-507; b: T360 DOPE/DOPC s501-503; c: T330 同) | PREREG §9 | 默认不领 |
| 20 | run_R4N5.sh | [v2] branch_now/branch_q/brall; claim_supp 在 supp 之后接 $(branch_q) (每次领取现读 $J/BRANCH, 否则 env BRANCH); CHECK 各核对循环含全部分支 build; DRY 列分支队列 | 同上 | BRANCH 未设 = v1 行为 |
| 21 | inputs/ +30 build | [v2] tools/derive_R4N5v2.py 派生 (种子/ref_t/gen_temp/EXP_TEMP, 断言); 76 次 grompp rc=0 0 警告 | 同上 | 只改温度/种子 |
| 22 | verdict_N5_wrap.py | [v2] 多档 T350/T360/T330 同规则; MC3 Δ_lam (冻结 DELTA_SEP=2, 尺子 CONTRAST_PASS 才判); s505-507 只描述; N5_INTERIM 标记 | PREREG §8-§9 | 冻结脚本 sha 不变 |
| 23 | xfer_small/collect_small.sh | [v2] COLLECT=0 也尽力跑冻结 collect + INTERIM 判读 (series csv); 时刻表 20:30/01:00/07:00 | K 要求实时迭代 | 失败只记 FAIL |
| 24 | tests/test_verdict_N5.py | [v2] +8 例 (Δ 三向/尺子未过/MC3 全 VOID/加种子不进门/T360/T330) | — | 16/16 OK |
## C 刻意没改
- 冻结判读/闸门/阈值; MAXWARN 0/0; MINRUN/SUPP_MARGIN/PROD_MIN; MPS 起停逻辑 (只在 B 槽领取前加判断); WAIT_MAIN=none 时「机上有 ^R4N2_ 容器 FAIL」照旧.
- 不自动续跑, 不加 ext/fill.

## D 已知风险
1. 规则 P 是新加的更严规则 (冻结 PREREG 里 DOPE 片层不设门) — 已预注册, 结果前定.
2. 2 槽时 B 槽 build 若跑到一半 MPS 死了, 该条不会被本包自动重启 (继承 R4N4 行为); B 槽之后不再领新条.
3. 吞吐数字是估计 (按珠数从 14258 ns/day@15420 珠折算); 2 槽 MPS 下每槽吞吐未在本体系实测.
4. collect_small 的 N5 judge 在容器里跑, 只作草稿; 正式判读在 box 上重跑.
5. 第 1 晚 DOPE lam 只跑了 s1 (s2–s4 NOT_RUN), 所以 DOPE s502–s504 的起点构建虽过 L1, 从未跑过 relax/L2; 若 L2 VOID, 替补只有 1 个.

### D-v2 新增风险
- 中性 MC3 片层: D1v2 (320 K) 10/10 VOID_L2; 本档若同样 → MC3 格 VOID, Δ NOT_EVALUABLE.
- 中途 collect 读正在写的 xtc, 末帧可能残缺 → 那次 collect FAIL (小包照出).
- 分支 a 的种子复用 s1-s3 起点结构 (只换速度), 只描述.
- 两槽结束后才选分支 → 需 NEW_RUN=1 BRANCH=x ONLY=... 新起.
- 时间是 PERF_NOM 估计; 2 槽 MPS 下单槽速率若明显下降, MC3 末几条会被 supp_fits 跳过.
