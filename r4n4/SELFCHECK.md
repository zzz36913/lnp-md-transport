# R4N4 自查 (2026-11-01 15:1x UTC+8; box, gmx 2026.3-conda_forge, MODE=local)
| # | 项 | 结果 | 证据 |
|---|---|---|---|
| 1 | 24 个 build 由 R4N3 C4 起点派生, start/top/ndx/expect.env 逐字节相同 | OK (越界 0) | review_raw.txt R5; 每 build DERIVED.txt |
| 2 | mdp 只改 gen_seed + prod 段 6 个加压键; relax 只改 gen_seed | OK (48 个 mdp, 越界 0) | review_raw.txt R5 |
| 3 | grompp maxwarn 0: 24 relax + 24 prod | 48/48 rc=0, 0 警告 | pkg proof/grompp_box.tsv |
| 4 | 档位落到 tpr | OK: AX=C-rescale Semiiso (zz 压缩率 0); PR=Parrinello-Rahman Aniso nstpcouple 2 tau 12 (zz 0); ISO=C-rescale Iso | proof/level_dump/ |
| 5 | 被排除的配置确实不可用 | c-rescale aniso grompp ERROR; PR nstpcouple 5 WARNING | proof/neg/ |
| 6 | CPU 冒烟 50 ps relax + 50 ps prod 每档 | 3/3 rc=0; AX/PR prod Lz 不变 (9.692/9.617) | proof/smoke/ |
| 7 | L1 构建门 | 24/24 PASS | inputs/L1_summary.tsv |
| 8 | CHECK=1 k04 / k03 | ALL OK / ALL OK (档位核对 4×L2 4×L3 4×L4 每机) | CHECK_local_k0x.txt |
| 9 | DRY=1 k04 / k03 | rc=0; 队列 AX→PR→ISO, 替补在前; DOPC 2.823 h、DOPE 2.267 h/条 | DRY_local_k0x.txt |
| 10 | 防呆负测试 | WAIT_MAIN 空/auto → FAIL; 改 1 条 L3 prod 为 semi → FAIL (MANIFEST 与档位核对各拦一次); 改 relax tau_p → FAIL | NEG_guard.txt |
| 11 | 等槽 + MPS 加入 (mock) | 14 PASS (J1–J6, W1–W6); 继承的自起 MPS 测试 ALL PASS | test_mps_wait_n4.txt, test_mps_n2_on_lib_R4N4.txt |
| 12 | 判读包装 | 11/11 PASS + 端到端 PASS | test_verdict_N4.txt |
| 13 | 冻结文件 sha | 5/5 OK; verdict/PREREG 母本/FROZEN 表与 R4N3 逐字节相同 | review_raw.txt R2/R3 |
| 14 | 闸门代码 gate/ gatewrap/ tools/l1_scan.sh | 与 R4N3 逐字节相同 | review_raw.txt R2 |
| 15 | 阈值常量 | N_PER 3, WIN_NS 100, T_EVAL_MIN_NS 400, RETAIN/LOST 0.80/0.20, L2 0.30 —— 未改 | review_raw.txt R4 |
自查中发现并修好 1 处: lib 里"加入 R4N3 MPS"一行, 行内注释吞掉了后面读取 pipe 的语句 (加入永远失败、退回不用 MPS)。已修, J1 验证通过。
不适用: tests/test_ext_n2.sh (本包无续跑段, 依赖第 2 晚 inputs; 未改未跑)。
