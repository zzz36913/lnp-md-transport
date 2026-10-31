# R4N2 — R4N1 三晚扫描第 2 晚运行包 (10-31 14:00 → 11-01 07:30 北京时间, 07:30 收数)

**状态: 已备包, 未上传 GitHub, 未发车.** 上传等 K 定 token 换不换; 发车等 K 批准算力.
写于 2026-10-31 08:3x 北京时间.

> **[rv2, 10-31 08:4x 北京时间]（已被下面 rv3 取代，勿用）** 原发车用 `pkg/R4N2_rv2.tar`** sha256 `4b434b46ecc7e10a23625ef5336f776286264fec2ed7933fefd0ef4b2f532020` (MANIFEST sha256 `8b37fb9060519358eabaf40b39225c97413e1a39ad8deb821269c70248c58123`, 784 文件). rv2 = rv1 (独立审查修正, 见 REVIEW_N2_independent.md §4) + C4 MC3H/MC3 lam s1 从 supp_k03 移到 supp_k04 (与同格 s4 替补同机). 冻结文件与原包逐字节相同. 下面 §1 表里的 tar/MANIFEST 是原包 (仅留档), §2/§4/§5 已按 rv2 改. 改前原文备份 `README_N2_pre_rv2.md`.

> **[rv3, 10-31 09:2x 北京时间] 发车用 `pkg/R4N2_rv3.tar`** sha256 `e6b263c23a2d7fba5a8b5082d5223f4e053ed3217ba2337238b6836e5586357e`（另存 `pkg/R4N2_rv3.tar.sha256`；830 条目 / 784 文件，顶层目录仍是 `R4N2/`）。**本块优先于下文 §2/§4/§5 的 rv1/rv2 内容**（那些保留作历史）。依据 K 10-31 09:14 决定：
> 1. **C2 整格延后**：`chains/ext_k0{3,4}_{A,B}.txt` 和 `fill_k0{3,4}.txt` 的全部条目加前缀 `#rv3-C2延后# `（链为空，第 3 晚恢复时去前缀即可）；命令里 `K_C2_3SYS=no FILL=0`。两层都挡：即使误填 K_C2_3SYS=yes 或 FILL=1，也没有可领的 C2 条目（CHECK 已测）。第 2 晚只跑 C4 补跑。
> 2. **PR / 盐**：第 2 晚不生效，`K_PR_SALT=none`。修订草稿在 `D2/amend/PRE_REG_AMENDMENT_N3_aniso_draft.md`、`PRE_REG_AMENDMENT_N3_salt150_draft.md`。
> 3. **修起点**：第 3 晚；方案 + 预注册草稿在 `D2/N3_plan/`（不是可执行包）。`K_VOID_FIX_N3=off`。
>
> **C4 14 条补跑的分配**（条目与 rv2 相同，只加了注释）：k03 = MC3H/MC3 hii s1–s3（6 条）+ 替补 hii s4 ×2；k04 = DOPE lam s2/s3 + MC3H/MC3 lam s1–s3（8 条）+ 替补 DOPE/MC3H/MC3 lam s4。已经是约束下最平：修订 02 要求同条件同臂 MC3H/MC3 同机成对、每格 3 主与替补同机，可搬的单位只有 hii 对 6.95、lam 对 6.95、DOPE lam 1.89 slot·h，怎么放都是 6.95 / 8.84。
>
> **结束时间（估算，14:00 准时起跑）**
> | 情景 | k03 | k04 |
> |---|---|---|
> | 基准 f=1.0 | 10-31 17:30（6.9 slot·h） | 10-31 18:26（8.8） |
> | MC3 全 VOID | 16:39（4.7） | 17:36（6.6） |
> | f=0.7 | 18:40（9.3） | 19:55（11.8） |
> | f≈0.33 | 23:04（18.0） | 11-01 01:25（22.7） |
> 四种情景 14 条都跑得完，无 SKIP、无截短（C2 续跑拿掉后 rv2 里 f=0.33 的 TRUNC 问题不再存在）。空闲 slot·h 和 3 个填空选项见 `FILL_OPTIONS_rv3.md`（**rv3 一个都没装，等 K 选**）：基准两机共空 ≈ 54 slot·h。
>
> **rv3 自测（box，mock gmx/MPS，在最终包的硬链接副本里跑）**：test_mps_n2 ALL PASS、test_ext_n2 ALL PASS、test_verdict OK、test_verdict_Larm OK、审查反例 cx.sh CX1–CX7 与 rv2 一致（唯一变化：CX1 中 K_C2_3SYS 为空/乱填不再 FAIL，因为本包已无 C2 条目，guard 判“本机无 C2 续跑条目”）；CHECK=1 k03/k04 **ALL OK**（GATE_PY=/workspace/venv_gate），DRY=1 两机 rc=0，14 条全部 FITS。日志：`review_rv1/est_rv3/`。冻结文件 FROZEN_sha256 与 R4N2 原包逐字节相同；rv2 的 MANIFEST 仍校验通过（rv3 用硬链接建，改动文件都是原子替换）。
>
> **rv3 发车命令**（替代 §5；先 k04 再 k03；每台 CHECK=1 → DRY=1 → 正式）：
> 解包：`echo 'e6b263c23a2d7fba5a8b5082d5223f4e053ed3217ba2337238b6836e5586357e  R4N2_rv3.tar' | sha256sum -c` → `mkdir -p ~/R4N2_pkg && tar -C ~/R4N2_pkg -xf R4N2_rv3.tar && cd ~/R4N2_pkg/R4N2 && sha256sum -c --quiet MANIFEST_sha256.txt && sha256sum -c --quiet FROZEN_sha256.txt && grep verdict FROZEN_sha256.txt`（应为 4fd49504…；`~/R4N2_pkg/R4N2` 若已有旧版先改名）。自检：`grep -c '^R4N1' chains/supp_k03.txt chains/supp_k04.txt chains/ext_k0*_?.txt chains/fill_k0*.txt` 应为 6 / 8 / 其余全 0。
> ```
> cd ~/R4N2_pkg/R4N2
> DEADLINE="2026-11-01 07:30 +0800" START_AT="2026-10-31 14:00 +0800" PRIO=raised X_MPS=auto X_MPS_MAX_START=3 WAIT_MAIN=none K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off FILL=0 SUPP=1 NEW_RUN=1 GATE_PY=gatewrap/gate_py_container.sh PRIOR_RUNS="$HOME/R4N1/R4N1_run_k04_* $HOME/R4N1x/R4N1x_run_k04_*" CHECK=1 bash run_R4N2.sh k04
> # 同上 CHECK=1 换 DRY=1；再去掉 CHECK/DRY 正式跑。k03 同上，所有 k04 换 k03。
> ```
> EXT_SRC_RUNS 不再需要（无续跑条目）。PRIOR_RUNS 每项必须命中已有目录，否则 CHECK FAIL；两项都要保留（第 1 晚 C4 的 R4N1x 树在里面：k04 有 DOPE lam s1，k03 有 DOPE hii / DOPC lam，查重靠它）。
> **仍需 K 定**：C4 的中性 MC3 若起点级全 VOID，C4 也只有三体系；按 K 对 C2 的口径，C4 是否仍出结论要 K 定（rv3 照规则四体系同跑，MC3 VOID 由闸门截停，每条约 0.3 h）。


## 1. 包与校验
| 项 | 值 |
|---|---|
| 包目录 | `/workspace/lnp-md/scan/R4_recipe/D2/N2/pkg/R4N2` (783 文件, 28 builds) |
| tar | `/workspace/lnp-md/scan/R4_recipe/D2/N2/pkg/R4N2.tar` sha256 `3d33990d3e163cb8e6dc9c0f7d8ac24cb1f14efb46db52e151cab1d68ae6b137` |
| MANIFEST_sha256.txt | sha256 `4772bc9e5f405e56b8f7917f8ef8feeb3bd929975afdec667983fb6c28b3afd7` (`sha256sum -c` 全 OK) |
| 源 git | `/workspace/lnp-md/scan/R4_recipe/D2/N2/src` HEAD `8e254e4` (57993e0 base → c55ef3c → 7ef5794 MPS 修复 → b8236b5 → 784be81 → 8e254e4) |
| 冻结 (FROZEN_sha256.txt) | verdict_R4_3day.py `4fd49504…08b2`; PREREG_R4_3day.md `19622358…`; AMENDMENT_01 `5b850f29…`; AMENDMENT_02 `74a409fd…`; D1v2_lam_runs.tsv `65f35f79…`. 已逐个比对 N1/N1x 包, **全部逐字节相同**, 预注册与 verdict 未改 |
| 打包 | `bash src/tools/make_package_n2.sh <out>` (目标已存在则拒绝; verdict sha≠4fd49504 则拒绝) |

## 2. 包内容 (对应任务 1–4)
1. **MPS 修复 (lib_R4N2.sh x_mps_pick / x_mps_stop; 逻辑改动, 须 K/LNP MD 批准 + 审查)**
   - x_mps_pick 判 own 前先做 3 项活检: 控制守护 pid 在且其 CUDA_MPS_PIPE_DIRECTORY 对得上; pipe socket/fifo 在; `get_server_list` 通.
   - env 在但守护死 → env 改名 `x_mps.env.dead_<TS>` (不 rm), 重起 (结果 `own_restarted`) 或降级不用 MPS (`none_dead_budget` / `none_start_fail`); 每次都写 `$OUT/slots/x_mps_events.log`.
   - **新增 (挂死自家守护)**: 本 OUT 自己起的守护 pid 还活着但 pipe 不通 → 只对这个自家 pipe 发 `quit` (输出 `x_mps_quit_dead_<TS>.txt`), 事件 `dead_own_quit`, 然后按上一条走. 不 kill, 不删目录, 不碰别人的 MPS.
   - `X_MPS_MAX_START` 默认 3 (含首次起与 APPEND_TO 续跑重起). 机上有别人的 MPS → `none_mps_present` (不起, 不 quit, 只写认人报告).
   - x_mps_stop: 对自家 pipe quit 后把 env 改名 `x_mps.env.stopped_<TS>` (旧代码留着 env → 第 1 晚 C4 误判 own、实际无 MPS, 速度约 1/3 的根因).
2. **C4 (h100/T350) 补跑**: 依据第 1 晚 QUEUE 06:4x 战报 — C4 已 DONE: DOPE hii s1-3 (k03), DOPC lam s1-3 (k03), DOPC hii s1-3 (k04), DOPE lam s1 (k04).
   - `supp_k03` [rv2]: MC3H/MC3 成对交错 hii s1, s2, s3 (6 条); 替补 `spares_k03`: MC3H/MC3 hii s4.
   - `supp_k04` [rv2]: DOPE lam s2, s3, 然后 MC3H/MC3 lam s1, s2, s3 (8 条); 替补 `spares_k04`: DOPE lam s4, MC3H/MC3 lam s4. 现在每条 supp 的同格替补都在本机 (替补只顶本机 VOID).
   - **相对 06:xx 草案的改动 (负载均衡)**: 原 supp_k03 12 条里 lam s2/s3 两对 (4 条) 和 lam s4 替补移到 k04. 理由: 原分配 k03 18.2 slot·h / k04 10.3; MPS 若仍失效 (≈1/3 速) k03 跑不完. 这 4 条第 1 晚本就在 k04 supp 里 (SUPP_SKIP_NO_TIME, 未起跑), 移回后 k04 本机账本查重天然覆盖.
3. **C2 (h050/T350) H_II 续跑 400 ns → 1.2 µs, 9 条** (60M 步, convert-tpr -nsteps 60000000, `mdrun -deffnm ext -s ext.tpr -cpi src.cpt -noappend`; 源须 STATUS DONE + laststep≥20000000 + cpt/tpr sha 与 SHA256_out.txt 一致):
   - k03_A: DOPC s1, s4; k03_B: DOPC s3
   - k04_A: MC3H s1, DOPE s1, MC3H s3; k04_B: MC3H s2, DOPE s2, DOPE s3
   - fill (FILL=1 才跑, 续到 2 µs): k03 3 条, k04 6 条; 只在本 OUT 的 1.2 µs 段 DONE 后才领.
4. **K 三个未决只给开关, 不改判据**: `K_C2_3SYS=yes|no` (必填, 空→FAIL; no→9 条续跑+fill 全 SKIP); `K_PR_SALT=none` (其他值→FAIL, 本包无内容); `K_VOID_FIX_N3=off` (on→FAIL, 第 3 晚另包); `FILL=1` 需 `K_C2_3SYS=yes`.

## 3. 自测 (box, mock gmx / mock MPS; 全部在最终包内重跑)
- `tests/test_mps_n2.sh` T1–T9 **ALL PASS** (活检、死守护改名重起、挂死自家 quit、预算耗尽降级、他人 MPS 不碰、stop 改名).
- `tests/test_ext_n2.sh <pkg>` E0–E11 **ALL PASS** (含 E0: 先前 run 树逐字节不变).
- `tests/test_verdict*.py` OK.
- CHECK=1, k03/k04 × FILL=0/1, K_C2_3SYS=yes: **ALL OK**. 假第 1 晚树 `/tmp/n2fake` (9 条 C2 prod DONE).
- 反例全按预期 FAIL: K_C2_3SYS 空; K_PR_SALT=salt; K_VOID_FIX_N3=on; FILL=1+K_C2_3SYS=no; 源 STATUS 无 laststep; 新起 build 在第 1 晚账本已 DONE (`prod_DONE@…` → FAIL). K_C2_3SYS=no → ALL OK, 9 条显示 SKIP.
- DRY=1 两机输出见 §4 need_h.
- **未在 Spark 上测** (box 无 gmx/GPU): 真 `gmx convert-tpr`/`gmx dump` 解析、真 nvidia-cuda-mps-control 行为、容器内 GATE_PY. 机上 CHECK=1 会再测 gmx/容器/MPS/磁盘.

## 4. 算力估算 (估算, 非实测)
依据: PERF_NOM=14258 ns/day/槽 @15420 珠 (2 槽/机 MPS), 按珠数线性缩放 (DRY 内置). 第 1 晚 MPS 2 槽实测 C2: DOPC 13892–14589, DOPE 15222, MC3H ~13699 ns/day; 第 1 晚 h100 T320 DOPC (MPS) 12859–13498 ns/day — 模型对 h100 偏保守. 第 1 晚 C4 无 MPS 实测 3681–7671 (2 槽 3681–5459) ns/day.
单条 need_h (DRY): C2 ext 800 ns — DOPC 1.447 h, MC3H 1.530, DOPE 1.264; C4 新起 (relax+闸+400 ns) — MC3H 1.180, MC3 1.136, DOPE 0.944. VOID 在闸门截停, 每条约 0.3 h.

[rv2 重算] 方法: 每机 2 槽, 14:00 起; 槽先跑本槽 ext 链, 再按 run_R4N2.sh claim_supp 的顺序领活 (先本机同格替补, 再 supp 队列); 单条时长用 lib need_h / need_h_ext 在 F_THR=f 下的值 (DRY 同一函数); VOID 条只算 relax+闸门+开销 (f=1 时 0.29 h, f=0.33 时 0.38 h). "所需结束" = 不受 DEADLINE 限制时末槽结束; "实际停" = 套用 supp_fits (剩余 ≥ need+0.75 h) 与 ext -maxh=剩余−0.25 h 后. 脚本 `review_rv1/est_rv2/` (估算, 非实测).

| 情景 | k03 slot·h | k03 所需结束 | k03 实际停 | k04 slot·h | k04 所需结束 | k04 实际停 |
|---|---|---|---|---|---|---|
| 基准 f=1.0, 全过闸 | 11.3 | 10-31 20:02 | 同左 | 17.2 | 10-31 22:41 | 同左 |
| f=1.0, MC3 全 VOID (历史如此; 各用掉 1 个 MC3 s4 替补, 也 VOID) | 9.0 | 18:39 | 同左 | 15.0 | 21:39 | 同左 |
| f=0.7 全过闸 | 15.4 | 22:09 | 同左 | 23.5 | 11-01 01:50 | 同左 |
| f=0.33 (MPS 再失效) 全过闸 | 30.5 | 11-01 06:03 | 同左 (全部跑完) | 46.9 | 11-01 13:39 ✗ | 11-01 04:51; MC3H/MC3 lam s1–s3 共 6 条 SUPP_SKIP_NO_TIME |
| f=0.33, MC3 全 VOID | 23.3 | 11-01 01:48 | 同左 | 39.6 | 11-01 10:34 ✗ | 11-01 04:51; 同上 6 条 SKIP |
| FILL=1 额外 (f=1.0, 未随 rv2 重算) | +4.3 | | | +8.4 | (k04 约 +4.2 h → 约 02:5x) | |

rv1 (lam s1 在 k03) 同法: 基准 k03 13.6 / 21:10, k04 14.9 / 21:32; f=0.33 时 k03 跳过 lam s1 两条、k04 跳过 lam s2/s3 四条 —— 两版在 f=0.33 下夜 2 都补不到 MC3H/MC3 lam, rv2 只是把负载从 k03 挪到 k04 (k04 末槽 +1.1 h).
- **最长槽 (基准 f=1.0)**: k04 约 22:40, k03 约 20:00, 离 07:30 余约 8.8 h (估算).
- **f=0.33 时**: supp 由 supp_fits 自动 SUPP_SKIP_NO_TIME, 不超 DEADLINE, C4 lam (MC3H/MC3) 补不齐 → 该格 n<3 → NOT_EVALUABLE. ext 按上式估算在 f=0.33、14:00 准时起跑时**仍能跑满 1.2 µs** (k04 最长 ext 链 12.5 h, 约 02:30 结束, 余约 4.7 h). 但任何 ext 都受 `-maxh = 剩余 − 0.25 h` 约束, 07:15 前没跑完就**被截短 (TRUNC, 达不到 1.2 µs)**, 判读时当作未跑满: 估算触发条件是 f ≲ 0.24 (k04 A 槽最后一条 MC3H s3), 或 f=0.33 下 k04 晚于约 18:45 起跑, 或 MPS 中途才失效而后段速度更低. 第 1 晚 C4 无 MPS 2 槽实测 3681–5459 ns/day, 离这个阈值不远. docker timeout = 剩余 + 600 s, 所以最坏也在约 07:40 停.
- **发车顺序**: 14:00 先 k04 (6 条续跑, 链最长), 再 k03; 每台 CHECK=1 → DRY=1 → 正式跑. 起跑后约 15 min 看 `x_mps_events.log` 和首条 ext Performance; 若 <10000 ns/day 立即报.

## 5. 发车命令草稿 (机上 ~/R4N2, 只经 k03 ZCode 进机; 下列全部 env 显式写出)
解包 [rv2]: 机上文件名 `R4N2_rv2.tar`, 先核 tar 本身: `echo '4b434b46ecc7e10a23625ef5336f776286264fec2ed7933fefd0ef4b2f532020  R4N2_rv2.tar' | sha256sum -c` → `mkdir -p ~/R4N2_pkg && tar -C ~/R4N2_pkg -xf R4N2_rv2.tar && cd ~/R4N2_pkg/R4N2 && sha256sum -c --quiet MANIFEST_sha256.txt && sha256sum -c --quiet FROZEN_sha256.txt && grep verdict FROZEN_sha256.txt` (应为 4fd49504…; 解出的目录名仍是 `R4N2/`; `~/R4N2_pkg/R4N2` 若已有旧版先改名, 不要混解). 自检: `grep -c '^R4N1' chains/supp_k03.txt chains/supp_k04.txt` 应为 6 / 8.
PRIOR_RUNS / EXT_SRC_RUNS 机上先 `ls -d ~/R4N1/R4N1_run_<机>_* ~/R4N1x/R4N1x_run_<机>_*` 核实存在 (k03 主包 ~/R4N1/R4N1_run_k03_1030_141205, k04 ~/R4N1/R4N1_run_k04_1030_141353 据 QUEUE; R4N1x 目录名 box 上无记录, 用 glob). [rv1 起] PRIOR_RUNS 里每一项都必须至少命中一个已存在目录, 否则 CHECK=1 直接 FAIL; 若某机没有 R4N1x 目录, 就把那一项从 PRIOR_RUNS / EXT_SRC_RUNS 删掉, 不要留空 glob. DEADLINE 晚于 2026-11-01 07:30 +0800 也会 FAIL (硬上限).

k04 (先):
```
cd ~/R4N2_pkg/R4N2
# 1) 
DEADLINE="2026-11-01 07:30 +0800" START_AT="2026-10-31 14:00 +0800" PRIO=raised X_MPS=auto X_MPS_MAX_START=3 WAIT_MAIN=none K_C2_3SYS=<K定> K_PR_SALT=none K_VOID_FIX_N3=off FILL=0 SUPP=1 NEW_RUN=1 GATE_PY=gatewrap/gate_py_container.sh PRIOR_RUNS="$HOME/R4N1/R4N1_run_k04_* $HOME/R4N1x/R4N1x_run_k04_*" EXT_SRC_RUNS="$HOME/R4N1/R4N1_run_k04_* $HOME/R4N1x/R4N1x_run_k04_*" CHECK=1 bash run_R4N2.sh k04
# 2) 同上, CHECK=1 换成 DRY=1
# 3) 正式 (同上, 去掉 CHECK/DRY):
DEADLINE="2026-11-01 07:30 +0800" START_AT="2026-10-31 14:00 +0800" PRIO=raised X_MPS=auto X_MPS_MAX_START=3 WAIT_MAIN=none K_C2_3SYS=<K定> K_PR_SALT=none K_VOID_FIX_N3=off FILL=0 SUPP=1 NEW_RUN=1 GATE_PY=gatewrap/gate_py_container.sh PRIOR_RUNS="$HOME/R4N1/R4N1_run_k04_* $HOME/R4N1x/R4N1x_run_k04_*" EXT_SRC_RUNS="$HOME/R4N1/R4N1_run_k04_* $HOME/R4N1x/R4N1x_run_k04_*" bash run_R4N2.sh k04
```
k03: 同上三步, 所有 `k04` 换 `k03` (含 PRIOR_RUNS/EXT_SRC_RUNS glob 与末尾机名).
FILL=1 仅在 K 批 K_C2_3SYS=yes 且要续到 2 µs 时改. J 默认 $HOME/R4N2 (输出 $J/R4N2_run_<机>_<TS>). [rv2 勘误] lib_R4N2.sh L24 的 DEADLINE 默认值已经是 `2026-11-01 07:30 +0800` (原文写成第 1 晚 10-31 07:30 是错的; lib 头注释 L13 那句 10-31 是 R4N1 历史说明). 命令里仍显式写 DEADLINE, 留在日志里可查.

## 6. 审查
- **结论: PASS-WITH-FIXES → 修后 PASS (自审)**. 本 executor 无子代理工具, 审查是同一代理另起一轮对抗式自审, **不算独立审查**; 建议 LNP MD 另派一个 reviewer 对 `src` 8e254e4 / tar sha 3d33990d… 复核后再发车.
- 自审发现并已修: (a) make_package 未带 tests/mock → 包内测试跑不了 (b8236b5); (b) k03/k04 负载不均, MPS 失效时 k03 跑不完 (784be81); (c) MC3H/MC3 lam 主力在 k04 而 lam s4 替补在 k03, 本机 VOID 无替补可顶 (8e254e4). 修后全部自测重跑通过.
- 自审确认无问题: 替补按 体系_水合_温度_臂 格匹配 (不会拿 DOPE 顶 MC3); fill 排在替补/补跑之后且要求低段 DONE 且无低段在跑; 9 条 ext 源 3 重校验; 新起 build 查重第 1 晚本机账本; 两机文件间无重复 build; 冻结文件未改.

## 7. 请 K / LNP MD 决定
1. **K_C2_3SYS (必填)**: C2 无 MC3 起点, 只有 3 体系; yes=按"四体系同跑"算、9 条续跑照跑; no=9 条全部 SKIP.
2. **C4 MC3 风险**: 中性 MC3 历来全 VOID, C4 实际很可能只有 3 体系 (MC3 n=0). 本包照规则四体系同跑, MC3 VOID 由闸门截停 (每条约 0.3 h). 是否接受 C4 按 3 体系出结论, 由 K 定 (同决定 1 的口径).
3. **MPS 挂死自家 quit** 是脚本逻辑改动, 须 K/LNP MD 批准 + 独立审查.
4. 算力 (14:00–07:30 两台各 2 槽) 与 FILL=0/1.
5. 上传 GitHub 等 token 决定.

## 8. 起跑前须对最终账本确认 (box 上没有第 1 晚最终账本; guard 会在机上再查, 查不到即 FAIL)
- C2 续跑 9 条源 prod DONE 且 cpt/tpr 在, 尤其 **MC3H C2 s3** (box 上只有中期快照).
- C4 DONE 列表 (§2.2) 与机上 ALL_RECORDS 一致; supp/spares 里任何一条若第 1 晚已 DONE/VOID, guard 会 FAIL, 要从队列删掉再打包.
- R4N1x 运行目录名 (PRIOR_RUNS glob 是否命中).
