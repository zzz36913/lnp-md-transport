# R4N2 rv4 — 第 2 晚续跑增量包（rv3 跑完后接手，DEADLINE 2026-11-01 07:30 +0800）

**按机分包（2026-10-31 15:29 改）**：k03、k04 各一个 tar，各自只含本机队列 `chains_rv4/extq_<本机>.txt`；在另一台机上 CHECK 会因缺队列 FAIL。代码相同。**只做 3SYS**（4SYS 已废止：调度 15:28 回报 k03 rv3 C4 MC3H/MC3 hii 补跑全 VOID_L2）。

**增量包**：只含新增文件，解到机上已有的 rv3 底包 `~/R4N2_pkg/R4N2` 上（`tar -k`，不覆盖任何 rv3 文件）。
rv3 的文件、冻结文件（verdict 4fd49504、PREREG 19622358、amendment 5b850f29）逐字节不变；`launch_guard` 每次核三份清单：
`MANIFEST_rv4_sha256.txt`（rv4 新文件）、`MANIFEST_sha256.txt`（rv3 底包）、`FROZEN_sha256.txt`（冻结）。

## 1. 做什么
- 只续跑（ext），不新起 build、不 grompp、不过闸门。每段：`gmx convert-tpr -s src.tpr -nsteps N -o ext.tpr` →
  `gmx mdrun -deffnm ext -s ext.tpr -cpi src.cpt -noappend`（dt 0.02 ps：1.2 µs = 60,000,000 步，2 µs = 100,000,000 步，3 µs = 150,000,000 步）。
  源 tpr/cpt 先 `cp` 进本 OUT 的 attempt 目录（源树只读，sha 记在 `EXT_SRC.txt`）。
- **从 400 ns 终点续，不从头**。1.2 µs 段源 = 第 1 晚（prior）或 rv3 本晚（main）的 400 ns prod DONE；2 µs 段源 = 本 OUT 的 ext1200 DONE；3 µs 段源 = 本 OUT 的 ext2000 DONE（不跳段）。
- **预注册判读在 1.2 µs**（规则 2 只在 1.2 µs 判）：队列类 `prereg`，须整段放得下（剩余 ≥ need + 0.75 h）才领；放不下但够 1 h 探索 →
  降级 `prereg_trunc` 照跑到 DL−0.25 h（记 `PREREG_NO_FULL_FIT`，该条不作 1.2 µs 判读）。
- **1.2 µs 之后续到 ≈2 µs（剩余时间再到 3 µs）= 探索**（类 `explore`，写进每段 `EXT_CLASS.txt`）：只记录何时失去 H_II，不改任何判据；剩余 ≥ 1 h + 0.25 h 即领，到点 `-maxh` 截断（TRUNC，能跑多长跑多长）。
- C3（320 K / h100）DOPC、DOPE hii n=3：探索，填空槽；在源所在机上跑（C3 DOPE 在 k03，C3 DOPC 在 k04）。

## 2. 队列（`chains_rv4/extq_<机>.txt`，文件顺序 = 优先级，两槽动态领取）
行格式：`<build> <目标ns> <prereg|explore> <prior|main> [源 run 目录]`（第 5 列只给 prior；`~` = `$HOME`；给了就只在该目录找源，防同名 build 多处 DONE 时取错）。

| 机 | 顺序 | 源（机器:目录，只读） |
|---|---|---|
| k03（包 a） | C4 DOPE T350 s1–3 @1200 prereg → @2000 explore → C3 DOPE T320 s1–3 @1200 → @2000 → C4 DOPE @3000 → C3 DOPE @3000（均 explore） | k03:`~/R4N1x/R4N1x_run_k03_1030_145609`（C4）、k03:`~/R4N1/R4N1_run_k03_1030_141205`（C3） |
| k04（包 b） | DOPC C4 s1–3 @1200 prereg → @2000 explore → C3 DOPC s1–3 @1200 → @2000 | k04:`~/R4N1x/R4N1x_run_k04_1030_145916`（C4）、k04:`~/R4N1/R4N1_run_k04_1030_141353`（C3） |

优先级 DOPC > DOPE > MC3H：DOPC 的 400 ns checkpoint 全在 k04，DOPE 全在 k03；**MC3H 无可续条目**（第 1 晚 C3 MC3H h100 hii 全 VOID_L2，C4 MC3H 第 1 晚未跑，rv3 本晚 k03 补跑全 VOID_L2），MC3 记 VOID。
k03 队列无 main 行（rv3 本晚 k03 无 prod 可续）。

## 3. 分支开关 `K_BRANCH`（必填）
- 只接受 `3SYS`。`4SYS` → `launch_guard` FAIL（已废止）；未设 / 其他值 → FAIL。

## 4. 与 rv3 的关系（不抢 rv3）
- 身份全分开：输出 `$HOME/R4N2/R4N2v4_run_<机>_<TS>`、锁 `.R4N2v4_<机>.flock`、容器 `R4N2v4_<机>_<pid>_*`、MPS 根 `$HOME/mps_R4N2v4/`。
- `WAIT_SCOPE=machine`（默认）：rv3 在跑时可先发车排队；两槽都等 rv3 **整机**完（无 rv3 容器，且 rv3 orchestrator.log 末标记为 `== machine <机> done` 或 rv3 锁已释放），
  再等 rv3 MPS 进程退净（≤600 s，超时记 `MPS_DRAIN_TIMEOUT` 照起，不碰 rv3 的 MPS），然后起自家 MPS、两槽同起。也接受 `$OUT/slots/<机>_<槽>.GO` 手动放行。
- `WAIT_MAIN`：rv3 run 目录（发车令显式给）；`auto` = 恰好 1 个 `$HOME/R4N2/R4N2_run_<机>_*`。
- rv3 的进程/容器/MPS/目录一概只读；本脚本只 stop 自己的 `R4N2v4_<机>_<pid>_*` 容器、只 quit 自家 pipe 的 MPS。

## 5. 运行
```
cd ~/R4N2_pkg/R4N2
ENV='K_BRANCH=3SYS WAIT_MAIN=<rv3 run 目录> DEADLINE="2026-11-01 07:30 +0800" PRIO=raised X_MPS=auto X_MPS_MAX_START=3 GATE_PY=$HOME/R4N2_pkg/R4N2/gatewrap/gate_py_container.sh'
CHECK=1 …  bash run_R4N2v4.sh <本包机>       # launch_guard, 全 [ok] 才算过 (rv3 在跑时也能过)
DRY=1 …    bash run_R4N2v4.sh <k03|k04>    # 队列表 + 两槽事件模拟 (估算); SIM_START / SIM_PERFS 可调
…          bash run_R4N2v4.sh <k03|k04>    # 正式; 中断后 APPEND_TO=<R4N2v4_run 目录> 续 (未 fin 的领取改名到 ledger/released/, 从 ext.cpt 续)
```
GATE_PY 本包不调用（不过闸门），只按 rv3 约定核绝对路径可执行。

## 6. 输出
`$OUT/builds/<b>/ext<T>/attempt_NNN/{src.tpr,src.cpt,ext.tpr,ext.part0002.*,ext.cpt,EXT_SRC.txt,EXT_CLASS.txt,STATUS,SHA256_out.txt}`；
`$OUT/ALL_RECORDS.tsv`（每条终态）、`$OUT/SUMMARY.tsv`（含 DEAD 列表）、`$OUT/RUN_META.txt`、`$OUT/slots/*`（等待原因、MPS 事件）、末行 `== machine <机> done`。
终态：DONE / TRUNC / TRUNC_TIMEOUT / FAIL / NUMERIC_FAIL；不跑的记 EXT_NO_SRC / CELL_FULL / EXT_LOWER_NOT_DONE / SUPP_SKIP_NO_TIME / PREREG_NO_FULL_FIT（降级）。

## 7. 自检（box，MODE=local + mock gmx，只写 /tmp）
`tests_rv4/test_ext_rv4.sh`（续跑单元 E0–E11）、`test_mps_rv4.sh`（MPS T1–T12，含 rv3 MPS 认人与退净等待）、
`test_orch_rv4.sh`（整机编排 O1–O6）、`test_check_dry_rv4.sh`（CHECK k03/k03done/k04 + 10 条负自检（含 4SYS 拒）+ DRY 3 情景 + I1 tar -k 装包 + I2 分包机对/错机 CHECK）。

## 8. 未在 Spark 上实测的
真实 `convert-tpr` + `mdrun -cpi -noappend` 续跑只在 CHECK 里做 convert-tpr/dump 自检；首段起跑后 15 min 须看 `ext.part0002.log` 的步数从 20,000,000 往上走、Performance 正常。
