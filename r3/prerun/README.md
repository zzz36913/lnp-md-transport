# R3 预跑包 (prerun) — 范围只限 3 件, 无任何 G-R3 科学判读

**只写文件包; 不碰 Spark/调度/ZCode/GLM/端口/key, 不联系 agent。** 本包由 box 上生成并已用 box gmx 2025.4 做过 `bash -n` + 本地冒烟(见文末), **未在 Spark/2026.3 上跑过**。
最先读 `B1_warnings.md`(relax 的 2 条 grompp 警告原文+mdp 参数+物理影响+我的判断)。

## 三件事 ↔ 脚本
| 件 | 内容 | 脚本/阶段 | 产出 |
|---|---|---|---|
| (a) B2 | Spark gmx 2026.3, **只跑 CPU grompp, maxwarn 0**, 逐条记警告原文。覆盖 7 个构建 × {relax_literal, relax_crescale_dev, relax_hybrid_vrescaleT_berendsenP, prod_lam(HII 构建用 prod_hii)} = 28 个 mdp; prod 即 v-rescale + Parrinello-Rahman 各向异性 τp=12、nstpcouple=nsttcouple=3 | `preflight_R3.sh`(或 `run_prerun.sh` 的 preflight 阶段) | `preflight/<构建>/<mdp>/attempt_NNN/{grompp.log,warnings.txt,STATUS}` |
| (b) B3+B1 | DOPE s2,s3,s5 与 DOPC s1,s2,s3 (= release 的 t=0/L1 PASS 名单里各自前 3 个) 各跑 15 ns relax(逐字 Berendsen 各向异性 τp=1, dt 15 fs, 1e6 步); literal 的 grompp 不过(maxwarn 默认 0)时自动再跑 `relax_crescale_dev` 对照(**偏离 SI 协议的 c-rescale 半各向同性开发臂, 力场/SI 字节一致性未核**); relax 结束后在 box 上用 `t0_gate.py --level prod0`(与 t=0 同款 2/2/2/2 @0.65/0.75/0.95, v1==v2) 读起点资格 | `run_prerun.sh` relax 阶段 + `collect_prerun.py` | `relax/<构建>/<literal\|crescale>/attempt_NNN/{relax.gro,relax.cpt,relax.log,mdrun.out,...}` |
| (c) 吞吐 | 新协议 PR 各向异性 τp=12 nst=3 的 50 ns prod(2.5e6 步×20 fs), 每槽取本槽首个 relax DONE 构建的 relax.gro/.cpt 续跑, **两槽 MPS 同时跑**, 读 `Performance:` 行, 替换 15188 估算 | `run_prerun.sh` tp 阶段 | `tp/<构建>/from_<臂>/attempt_NNN/{tp.log,...}` |

## 逐步 maxwarn (写在 `run_prerun.sh` 头; 每步独立; 默认 0)
| 步 | 变量 | 默认 | 说明 |
|---|---|---|---|
| (a) 预检 | `MAXWARN_PREFLIGHT` | 0(`readonly`, 不可环境覆盖) | 目的是原样看到全部警告 |
| (b) relax literal | `MAXWARN_RELAX_LITERAL` | **0** | box 2025.4 实测 2 条警告(见 B1_warnings.md)。默认 0 ⇒ literal 在 grompp 即 FAIL_GROMPP 并记警告原文, 随后自动跑 crescale 对照。要真跑 literal 的 15 ns, 须 **K 批准 B1 路径 A** 后发车人显式设 `MAXWARN_RELAX_LITERAL=2`(只此一步) |
| (b) relax crescale | `MAXWARN_RELAX_CRESCALE` | 0 | box 2025.4 实测 0 条 |
| (c) tp prod | `MAXWARN_TP_PROD` | 0 | 2025.4 实测 0 条; 2026.3 若有警告 ⇒ 失败并记录, 不静默放行 |
所有取值写入 `META_<时刻>.txt` 与每条记录的 `maxwarn` 列。

## 目录与不可变约定
- 输出 `$J/R3_prerun_<TS>/`(`J` 默认 `$HOME/R3_prerun`), **TS 由脚本运行时生成**; 目录已存在 ⇒ 报错退出(已冒烟验证: 同秒冲突被拒)。
- 每个步骤每次尝试 = 新建 `attempt_NNN`(`mkdir` 原子, 编号=现有最大+1), **不覆写、不删除旧 attempt**; `STATUS` 用 noclobber 只写一次; 汇总 `ALL_RECORDS.tsv` 只 `>>` 追加。
- 重试: `APPEND_TO=$J/R3_prerun_<TS> STAGES="relax tp" bash run_prerun.sh` — 已 DONE 的步骤跳过, 未 DONE 的新增 attempt(已冒烟: literal 先 maxwarn 0 失败 → attempt_001 FAIL_GROMPP, 再 maxwarn 2 → attempt_002 DONE, 001 一字未动)。
- 记录列(`ALL_RECORDS.tsv`): ts, stage, build, arm_or_mdp, attempt_dir, state, gmx_version, maxwarn, grompp_rc, n_warn, mdrun_rc, nsteps_run, performance_ns_day, **input_gro, input_mdp, input_top, grompp_log, warnings_txt, mdrun_log, perf_log, t0_readout_rel**(起点资格读数 JSON 的相对路径, 由 box 上的 collect 写到 collect 输出目录的 `t0/`)。
- 不触碰: 脚本只调用 gmx(docker 镜像 `ghcr.io/novomcp/gromacs-md:spark`, 与 run_R2a.sh 同款包装)与用户态 MPS(同 R2a_machine.sh, MPSROOT 须为空, 只关自己起的); 容器名前缀 `R3PRE_<目录名>`, 中断/退出时只 stop 这些容器; 无任何 GLM/ZCode/端口/key/模型名。
- 起动前自检: `sha256sum -c MANIFEST_sha256.txt`(包被改 ⇒ 中止)、gmx 版本须以 `2026.3` 开头(否则中止; box 冒烟用 `EXPECT_GMX=any`)。

## 预跑槽位·小时估算(估算, 未实测; 见 `estimate_prerun.py` / `estimate_prerun_output.txt`)
假设: 12240 珠(960 脂+720 W); prod 吞吐 15188 ns/day/槽(**估算**: R2a 实测 14343–16290 取 15000, 按珠数线性缩放; 新协议未测, 本预跑正是要替换它); relax dt 15 fs ⇒ 吞吐=0.75×prod(估算); 每个 grompp+mdrun 步骤开销 0.03 h(假设); 吞吐系数 f=1.0/0.8/0.5。
| f | 单个 relax | 单个 50 ns tp | 名义(6 relax+2 tp) | 最坏(12 relax+2 tp) |
|---|---|---|---|---|
| 1.0 | 0.032 槽·h | 0.079 | 0.59 槽·h(墙钟≈0.29 h) | 0.96(≈0.48 h) |
| 0.8 | 0.040 | 0.099 | 0.67(≈0.34 h) | 1.09(≈0.55 h) |
| 0.5 | 0.063 | 0.158 | 0.94(≈0.47 h) | 1.49(≈0.75 h) |
目标 ≤ 约 4 槽·h: 全部满足, 无需缩构建数/prod 长度。最坏总计 ≈ 0.538/f + 0.42 槽·h, 仅当实测 f < 约 0.15(估算)才超 4; 届时每格 3→2 个构建或 tp 50→20 ns(并在回报里写明)。预检为 CPU grompp(28 个, 估算数分钟, 不占 GPU 槽)。

## 发车判据(全部满足才发; 发车人=调度方, 我不发车)
1. 拷到 Spark 后 `cd <包> && sha256sum -c MANIFEST_sha256.txt` 全 OK。
2. K 已确认 GLM 停、两台机器可用(父 agent 16:52 转述); 发车人自行确认目标 GPU 无外来作业(脚本不做外部检查)。
3. 镜像内 `gmx --version` 为 2026.3(脚本自检, 不符即中止)。
4. 已决定 `MAXWARN_RELAX_LITERAL`: 0(只出 literal 的警告记录 + crescale 对照 relax) 或 2(K 批准 B1 路径 A)。
5. `$J` 下无同名 `R3_prerun_<TS>`(脚本自检)。
建议命令: 先 `DRY=1 bash run_prerun.sh`; 全流程 `MAXWARN_RELAX_LITERAL=<0|2> bash run_prerun.sh 2>&1 | tee prerun_stdout.txt`(tee 文件放在输出目录之外或其内新文件均可)。

## 回传清单
整个 `R3_prerun_<TS>/`(至少: `ALL_RECORDS.tsv`、`META_*.txt`、每个 attempt 的 `STATUS`、`grompp.log`、`warnings.txt`、`mdrun.out`、`relax.log`/`tp.log`、`relax.gro`、`relax.cpt`)+ 终端输出 `prerun_stdout.txt`。随后在 box: `python3 collect_prerun.py <回传目录>` ⇒ `<回传目录>_collect_<TS>/prerun_summary.md|.tsv`、`t0/*.json`、`preflight_warnings_unique.txt`; 内容只有: 能否过 preflight / relax 后合格率 / 实际 ns/day(含对 15188 的比值)。

## 独立快审要点
1. **路径**: 全部输入在 `inputs/`(6 个构建+1 个 HII 构建的 start.gro/sys.top/index.ndx/mdp, 来自 `R3_pkg/release/`, 逐字拷贝, relax_hybrid 仅把 `@SEED@` 换成该构建 relax_literal 的 gen_seed); 力场 itp 在 `inputs/ff/`(经 `GMXLIB` 指向, 不依赖 Spark 上的其它路径); 输出只在 `$J/R3_prerun_<TS>/`。
2. **覆盖**: preflight 28 mdp(含 relax 三种 + PR 各向异性 prod_lam/prod_hii); relax 6 构建(DOPE s2,s3,s5; DOPC s1,s2,s3 — 与 `release/` 的 L1 PASS 名单前 3 个核对); 起点资格用原件 `R3_pkg/scripts/t0_gate.py`(依赖 `analyzer_v2/topo_v2.py`), 与 t=0 同款; tp 两槽同时。
3. **逐步 maxwarn**: `run_prerun.sh` 头 4 个变量, `grep -n maxwarn run_prerun.sh preflight_R3.sh` 核对每个 grompp 调用用的是各自变量, 无硬编码 `-maxwarn 2`。
4. **不碰 GLM**: `grep -niE 'glm|zcode|key|token|port|ssh|scp|curl|wget' *.sh` 应只命中注释里的"不碰"声明; 唯一的外部命令是 `docker run/stop`(仅 R3PRE_ 前缀容器)、`nvidia-cuda-mps-control`(仅自起)、`nvidia-smi --query-gpu`(只读)。
5. **不可变**: `grep -n 'mkdir\|noclobber\|>>' lib_prerun.sh run_prerun.sh` — 无 `rm`、无 `>` 覆写旧 attempt 文件(`>` 只写本 attempt 内新文件)。
6. **只做三件、无科学判读**: `collect_prerun.py` 的输出段只有 (1)(2)(3)。
7. 注意: 用词上本包不使用「复现 Pedersen」; crescale 对照臂=偏离 SI 协议的开发臂; 力场与 SI 字节一致性未核。(父 agent 16:52 指令里的"Pedersen 版/不是 Pedersen 复现"字样与此前第 8 条禁用措辞冲突, 本包按禁用措辞改写。)

## 已做验证(box, gmx 2025.4, MODE=local, EXPECT_GMX=any; 全是冒烟, 不是 Spark 结果)
- `bash -n` 三个 .sh 通过; `python3 -m py_compile collect_prerun.py` 通过; `DRY=1 MODE=local bash run_prerun.sh|preflight_R3.sh` 只打印计划。
- 完整本地流程(preflight 28 mdp → relax 6 构建 200 步 → tp 100–200 步 → collect): 流程、attempt 追加、APPEND 重试跳过、同秒目录冲突拒绝、版本检查均按设计工作。box 2025.4 预检读数: relax_literal 2 条警告(7/7), relax_hybrid 1 条(7/7), relax_crescale_dev 与 prod_lam/prod_hii 0 条。**冒烟的 ns/day(box CPU、100–200 步)与 relax 资格率(200 步)无任何参考价值, 不得引用。**
- 未验证: docker/MPS 分支(box 无 docker/MPS, 仅 `bash -n`; 命令行抄自 run_R2a.sh/R2a_machine.sh 的同款写法)、2026.3 的实际警告。
