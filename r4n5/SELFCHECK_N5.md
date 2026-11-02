# SELFCHECK_N5 — box 本地自检结果 (2026-11-02, Asia/Singapore)
全部在 box 上跑, 未碰 Spark / ZCode / GLM, 未启动任何模拟.

## 1 grompp 干跑 (gmx 2026.3-conda_forge, 本机已有, 未安装)
- 8 个 build × (relax_crescale_dev, prod_lam) = 16 次 grompp, **16/16 rc=0, 0 warning, 各 1 note** (prod 的 note = verlet-buffer-pressure-tolerance 被忽略, 与第 1 晚相同).
- nsteps: relax 1000000 @ dt 0.015 (=15 ns); prod 60000000 @ dt 0.02 (=1200 ns). 明细 selfcheck/grompp/SUMMARY.tsv + 每步日志.

## 2 单元测试
| 测试 | 结果 | 文件 |
|---|---|---|
| tests/test_verdict_N5.py (8 个人造场景: PASS/FAIL/过驱/不可评/满窗截断/替补) | ALL_OK | selfcheck/test_verdict_N5.txt |
| tests/test_slotB_mps.sh (B 槽 MPS 规则, 17 例) | ALL_OK | selfcheck/test_slotB_mps.txt |
| tests/test_mps_n2_onN5.sh (R4N4 MPS 测试改名后跑 lib_R4N5) | ALL PASS | selfcheck/test_mps_n2_onN5.txt |
| tests/test_mps_wait_n4_onN5.sh (同上) | ALL PASS | selfcheck/test_mps_wait_n4_onN5.txt |

## 3 闸门负自检 (真测)
proof/neg_selftest_bridged.gro 直接喂闸门: rc=3, 读数 1/3/3/2 → 判不合格. 说明 run_R4N5.sh 里「闸门负自检」这一条现在是真测.
(R4N4 包没有这个文件, 其同一条检查因文件缺失 rc≠0 而空过.)

## 4 launch_guard CHECK / DRY (MODE=local, 模拟 k03 / k04)
环境: HOME=/tmp/n5home MODE=local GMX_LOCAL=gmx2026.3 EXPECT_GMX=any WAIT_MAIN=none NEW_RUN=1 FILL=0 X_MPS_JOIN=off K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off.
- CHECK (写完 MANIFEST 之后重跑): 见 selfcheck/CHECK_local_k03.txt, CHECK_local_k04.txt (结论行在文件末尾).
- DRY: deadline 2026-11-03 06:50 +0800; k03 队列 DOPE s501-503 (+s504 只作 L2 替补), k04 队列 DOPC 同; 每条 FITS.
  DRY 的 need (DOPE 2.267 h, DOPC 2.823 h) 用的是包内名义速度 14258 ns/day 加 0.75 h 余量 —— 估计, 不是实测.
- 唯一 warn: WAIT_MAIN=none (按设计: R4N3/R4N4 已结束才用).

## 5 未做 (需在 Spark 上做, 本任务禁止)
- 真机 CHECK (MODE=docker, 真 MPS, 真容器). 启动前按 README_R4N5 先跑 CHECK=1.

## v2 自检 (2026-11-02, box 本地, 未起跑任何东西)
- grompp: 38 build × (relax_crescale_dev, prod_lam) = 76 次, 全部 rc=0, 0 WARNING, 1 NOTE (verlet-buffer-pressure-tolerance ignored); ref_t: T330 ×16, T350 ×44, T360 ×16 (selfcheck/grompp/SUMMARY.tsv).
- tests: test_verdict_N5 16/16 OK (含 8 个 v2 例); test_slotB_mps ALL_OK; test_mps_n2_onN5 / test_mps_wait_n4_onN5 ALL PASS (selfcheck/test_*.txt).
- 本地 launch-guard CHECK k03/k04 (MODE=local) 与 DRY (BRANCH 未设 / BRANCH=b) 输出: selfcheck/v2_check_k0?.txt, selfcheck/v2_dry*_k0?.txt. 真机 CHECK 尚未跑.
