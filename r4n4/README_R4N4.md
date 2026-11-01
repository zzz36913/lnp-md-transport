# R4N4 · 加压方式扫描包 (11-01 晚 → 11-02 06:50, UTC+8)
预注册: PREREG_N4.md; 算力/时间估算: PLAN_N4.md; 判读: verdict_N4_wrap.py (内部调用冻结 verdict_R4_3day.py, sha 4fd49504)。

## 1 做什么
DOPE (阳性) + DOPC (阴性) × 3 个 prod 加压档 (AXFIX / PRXY / ISO) × n=3 (+每档每体系 1 替补), 起点 = R4N3 包现成的 C4 H_II 起点, relax/闸门/判读与 R4N3 相同, 只换 prod 段 6 个加压键 (见 PREREG_N4 §2)。
- k04 只跑 DOPC (supp_k04: s211 s212 s213 → s311 s312 s313 → s411 s412 s413; 替补 spares_k04: s214 s314 s414)。
- k03 只跑 DOPE (supp_k03: s212 s213 s218 → s312 s313 s318 → s412 s413 s418; 替补 spares_k03: s219 s319 s419)。
- 主链 k0x_A/B、ext_*、fill_* 为空 (只有注释): 两个槽都在等到 R4N3 同槽空出后, 从同一条补跑队列按顺序领。

## 2 等槽机制 (读 R4N3 的 lib_R4N2.sh 后的设计)
R4N3 的实现 (只读了解, 本包不改它): 每台机一个编排进程, 今晚 J=`$HOME/R4N3`: 持排他 flock `$HOME/R4N3/.R4N2_<机>.flock`; 输出 `$HOME/R4N3/R4N2_run_<机>_<TS>/`; 两个槽 A/B 各一个子进程, 固定 CPU pin (PINA/PINB), 容器名 `R4N2_<机>_<pid>_<机>_<槽>_…`; 槽日志 `slots/<机>_<槽>.log` 以 "== slot start" 开始、"== slot end" 结束, 整机结束写 "== machine <机> done"; 补跑/替补靠 `ledger/` 目录里 mkdir 原子 claim。
本包 (R4N4) 是**另一个独立进程**:
- 自己的锁 `$HOME/R4N4/.R4N4_<机>.flock`、输出 `$HOME/R4N4/R4N4_run_<机>_<TS>/`、自己的账本 `ledger/`、容器前缀 `R4N4_`、MPS 根 `$HOME/mps_R4N4/`。**从不读写 R4N3 的 ledger/claim**, 不 quit/kill/改名 R4N3 的任何东西 (tests/test_mps_wait_n4.sh J6 逐字节核对)。
- 仍是两个槽 A/B, 用与 R4N3 相同的 pin (A 接 R4N3 的 A, B 接 R4N3 的 B) → **不开第 3 槽**: 本包槽 X 只在 R4N3 槽 X 空了之后才起。
- 槽 X 判"空"(任一): MAIN_DONE (R4N3 槽 X 日志最后一个槽标记是 "== slot end", 或其编排日志有 "== machine <机> done") | MAIN_GONE (R4N3 的 flock 可拿到 = 编排已退) | MAIN_IDLE (槽日志 ≥ 1200 s 没更新且无其容器) | 人工放 `$OUT/slots/<机>_<X>.GO` 文件 (放置 ≥ 120 s 且期间没见过 R4N3 容器)。
- **硬条件 (不可绕过):** 起跑那一刻, 机上不得有 `^R4N2_<机>_<数字>_<机>_<X>_` 容器; 判空后 5 s 再复查一次。
- WAIT_MAIN **必须显式**给 R4N3 今晚的 OUT 目录 (`$HOME/R4N3/R4N2_run_<机>_<TS>`, 该目录须含 orchestrator.log; [v2] 另硬校验: 父目录须 = MAIN_J (默认 `$HOME/R4N3`)、锁 `dirname(WAIT_MAIN)/.R4N2_<机>.flock` 须存在、orchestrator.log mtime 须在今天, 任一不满足 FAIL —— 路径写错时锁文件不在, 等待逻辑会误判 R4N3 已退出而立刻起跑, 所以必须拦); 不给或给 auto → CHECK 直接 FAIL (auto 会撞到第 2 晚的同名目录)。
- R4N3 槽 X 结束后又领了替补 (例如 MC3H s14): R4N3 的槽日志那时还没写 "slot end" → 本包继续等, 不抢。
- 等待中到"剩余 < 一条所需"自动放弃该槽 (WAIT_GAVE_UP); 放 `$OUT/HALT` 立即放弃。

## 3 MPS (X_MPS_JOIN=off 今晚默认 | main)
- R4N3 编排还在 (其 flock 被占) 且 X_MPS_JOIN=main: 读 R4N3 的 `slots/x_mps.env`, 验活其守护 (控制进程在、pipe 在、get_server_list 通), 且机上还有 R4N3 容器 → 作为**客户端**加入 (只连); 任何一条不满足 → 本条不用 MPS (none_main_running, 两个上下文时间片共享 GPU)。
- R4N3 编排已退且机上没有任何 MPS 进程 → 本包起自己的 MPS (`$HOME/mps_R4N4/…`), 本包结束时只 quit 自己起的。
- **风险 (待 K 知悉):** 加入后若 R4N3 恰好收尾 quit 守护, 本包正在跑的这条会掉成非 MPS (实测类比 10-30 事故: 两槽合计约 4700 ns/day, 正常约 14000) 或报错; 本包不会自动重启该条。**今晚默认 X_MPS_JOIN=off** (避免此风险), 代价是与 R4N3 同时跑的那段时间里两个 CUDA 上下文时间片共享 GPU (本包和 R4N3 那一槽都可能变慢)。
- 自检: tests/test_mps_wait_n4.sh (14 PASS: J1–J6, W1–W6) 与 tests/test_mps_n2.sh (ALL PASS, 本包自起 MPS 的继承逻辑)。
- 本包修了一处从 R4N3 继承改写时引入的行内注释吞语句问题 (加入 R4N3 守护那一行), 修后 J1 通过。

## 4 运行顺序 (今晚只跑 L2=AXFIX + L3=PRXY, **不跑 L4=ISO**; 先 k04 后 k03)
解包目录统一 `~/R4N4_pkg/R4N4`; 输出 J 用默认 `~/R4N4` (不设 J)。R4N3 今晚 J=`~/R4N3`, 所以 WAIT_MAIN=`$HOME/R4N3/R4N2_run_<机>_<TS>` (不是 ~/R4N2)。
**两台的 CHECK 必须串行跑** (k04 的 CHECK 跑完再跑 k03 的, 反之亦然): 旧版进程匹配会把调度机上 "ssh k04 … run_R4N4.sh" 的命令行当成同机在跑的 run_R4N4.sh。v2 已收紧为只认 bash/sh 直接跑的本脚本 (负测试 selfcheck/NEG_procs.txt), 但串行规定照旧保留。
```
# --- k04 (DOPC; L2=AXFIX, L3=PRXY) ---
cd ~/R4N4_pkg/R4N4
WAIT_MAIN=$HOME/R4N3/R4N2_run_k04_<TS>   # R4N3 今晚 k04 的 OUT
COMMON="WAIT_MAIN=$WAIT_MAIN FILL=0 K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off X_MPS_JOIN=off GATE_PY=$HOME/R4N4_pkg/R4N4/gatewrap/gate_py_container.sh"
env CHECK=1 $COMMON ONLY="DOPC_h100_T350_hii_L2,DOPC_h100_T350_hii_L3" bash run_R4N4.sh k04   # 须 ALL OK
env DRY=1   $COMMON ONLY="DOPC_h100_T350_hii_L2,DOPC_h100_T350_hii_L3" bash run_R4N4.sh k04   # 看队列: L4 全部 (跳过)
nohup env   $COMMON ONLY="DOPC_h100_T350_hii_L2,DOPC_h100_T350_hii_L3" bash run_R4N4.sh k04 > ~/R4N4/k04.nohup 2>&1 &
# --- k03 (DOPE; L2=AXFIX, L3=PRXY) --- k04 的 CHECK 结束后再跑
cd ~/R4N4_pkg/R4N4
WAIT_MAIN=$HOME/R4N3/R4N2_run_k03_<TS>   # R4N3 今晚 k03 的 OUT
COMMON="WAIT_MAIN=$WAIT_MAIN FILL=0 K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off X_MPS_JOIN=off GATE_PY=$HOME/R4N4_pkg/R4N4/gatewrap/gate_py_container.sh"
env CHECK=1 $COMMON ONLY="DOPE_h100_T350_hii_L2,DOPE_h100_T350_hii_L3" bash run_R4N4.sh k03
env DRY=1   $COMMON ONLY="DOPE_h100_T350_hii_L2,DOPE_h100_T350_hii_L3" bash run_R4N4.sh k03
nohup env   $COMMON ONLY="DOPE_h100_T350_hii_L2,DOPE_h100_T350_hii_L3" bash run_R4N4.sh k03 > ~/R4N4/k03.nohup 2>&1 &
```
(`mkdir -p ~/R4N4` 若 nohup 日志目录还不存在; 档位 = 种子百位: L2=AXFIX, L3=PRXY, L4=ISO。)
ONLY 外的条目 (L4) 记 SKIP_NOT_ONLY, 不进账本 claim; 替补只顶本次跑过的 VOID 主种子 (L4 替补也不会起)。
CHECK 或 DRY 任一不 ALL OK → 不发正式, 报 LNP MD。CHECK 会核对: MANIFEST 全 OK、冻结 sha、每个 build 的 prod 6 键与种子百位档位逐字一致、relax 与 R4N3 相同、闸门负自检、两槽同时 grompp 0 警告。
中途小包: `bash xfer_small/collect_small.sh <本包 OUT>` (默认存 `$HOME/R4N4/xfer`)。

## 5 判读
先 `python3 verdict_N4_wrap.py collect …` (同冻结版用法) 得到 `<out>/runs_status.tsv`, 再 `python3 verdict_N4_wrap.py judge <out> --d1v2-lam inputs/D1v2_lam_runs.tsv --lam-src <第1晚 runs_status.tsv> --horizons 1200,max`: 按种子百位分档, 每档单独调用冻结尺子 (条件格 C4r), 写 `level_L<档>/` 与 `VERDICT_N4_levels.json`。规则 3 借第 1 晚 semi 片层臂, 每档报告标注。
