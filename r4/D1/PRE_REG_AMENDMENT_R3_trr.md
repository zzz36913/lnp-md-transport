# PRE-REG AMENDMENT (R3) — 增补"取起点规则" (start-frame selection rule)   2026-10-28 (SGT)

## 0. 时序声明 (必读)
本规则是在 **看到 R3 预跑结果之后** 才加的: 预跑 (`prerun_results/R3_prerun_1028_175447`) 中 6 个起点 (DOPE s2,s3,s5 / DOPC s1,s2,s3) 经 15 ns relax 后, 用 t0 闸门 (prod0, 2/2/2/2 @0.65/0.75/0.95, 极性 0.8, v1==v2) 读 **末帧**, 合格 **0/6**; 随后的诊断 (`/workspace/r3_diag/README.txt`, `geom_all.json`) 也已看过: 结论是这不是物理上的层融合, 而是在 3 w/l 平衡态下"单个末帧"对局部 0.4 nm 尾珠接触过严 (单帧判据偶然性大). **规则是在知道这些之后设计的, 不是盲设计.** 读者应据此降低对"规则后通过率"作为独立证据的权重.

## 1. 没有改的 (一字未动)
- 闸门判据: 尾珠截距 0.65 / 0.75 / 0.95 nm, 极性 0.8, 通过 = ncl/wind/npol/wpol = 2/2/2/2, 脂 960 / 水 720, v1==v2. 闸门代码 `gate/*.py` 与主包旧版逐字相同.
- 原 `inputs/*/relax_*.mdp`、`prod_*.mdp` 一字不改, MANIFEST 中它们的 sha 不变. relax 的 mdp 仍是 `RELAX_ARM=crescale_dev` 原样, 仅在**运行时派生副本**里多追加两行输出参数 (见 §2).
- 其它发车参数 (阈值之外的所有链/时间/maxwarn/MPS/槽位) 不变; 只有 `PERF_NOM` 按预跑吞吐更新 (若已更新, 由发车人在命令行给出).
- hii 臂: 起点闸 N/A, 不走本规则, 行为不变.

## 2. 新增的规则 (仅此一条)
仅 lam 臂, `SEL_RULE=1` (默认) 时:
1. **relax 阶段**: grompp 用的是派生 mdp = 原 `relax_crescale_dev.mdp` 逐字 + 末尾追加 `nstxout = 5000`, `nstvout = 5000` (15 fs x 5000 = 75 ps 一帧; 不写 f; 其它输出 (`nstxout-compressed`/edr/log/cpt 等) 不变). 派生 mdp 与 diff 保存在 relax attempt 目录 (`relax_crescale_dev.mdp`, `mdp_diff_trr.txt`, `inputs_sha256.txt`).
2. **relax 结束后, prod 之前**: 只取 relax 最后 `SEL_WIN_PS=5000` ps (5 ns, 约 67 帧) 的 trr 帧 (`gmx trjconv -b -e -sep`, 带速度), **逐帧**用与 `step_gate` 同一命令行的 `t0_gate_launch.py --level prod0 --arm lam --expect-lipids 960 --expect-w 720` 判定 (同样的退出码语义: 0=合格).
3. **选择**: 取窗口内**最后一个**合格帧. 把"窗口帧数 / 合格帧数 / 合格比例 / 选中 t_ps / 选中 gro 的 sha256 / trr 的 sha256"写进 `builds/<b>/select/attempt_NNN/SELECTED_FRAME.txt`, 逐帧读数写进 `frames.tsv` 与 `gate_frames/f*.json`, 并在 `ALL_RECORDS.tsv` (stage=select) 与 log 里各记一行.
4. **起点**: 选中帧再用 `step_gate` 复判一次 (同一闸门) 才进 prod. prod 的 `grompp -c` = 该帧 gro (含速度), **不再传 `-t relax.cpt`** (传 -t 会覆盖 -c 的坐标/速度). 因此 prod 起点来自 3 位小数的 gro, 不带 relax 的压浴/barostat 状态 (prod 是 Parrinello-Rahman, 本来就重新开始耦合; 这是有意的).
5. **0 个合格帧** (STATUS=SEL_NONE): 回退到 relax 末帧交给原有闸门路径, 它按同一判据必然不合格 -> `VOID_L2` -> 进作废账本 (`REPLACE_ON_RELAX_FAIL` 逻辑与替补逻辑不变). **不会放宽判据去"凑"合格帧.**
6. **清理**: prod 前删除非选中帧的 `.gro` (磁盘, 每槽 trr 约 200 MB), 只保留 `selected.gro`; trr / `frames.tsv` / 各帧 json 留作审计 (`SEL_KEEP_FRAMES=1` 可全留).
7. **回退 (SEL_SKIP)**: `GATE_MODE!=host`、无 relax.trr/tpr、或 trjconv 失败时, 记录原因并回退旧行为 (relax 末帧 + `-t relax.cpt`); 这种情形不会静默当作"选过帧".

## 3. 选择只看起点读数
选择完全由起点几何读数决定, 不看任何 prod 结果; 替补逻辑仍只看起点读数, 与原 R3 预注册相同.

## 4. 需要诚实声明的预期与风险
- **DOPC 可能一个合格起点都得不到.** 预跑只有 6 个末帧读数 (全部 0/6), 没有逐帧数据, 无法预知 DOPC (或 DOPE) 的末 5 ns 里有多少帧合格; 若 DOPC 的末 5 ns 全部 67 帧均不合格, 该 build 按 §2.5 作废并在报告里如实记为"DOPC: 无合格起点, 作废 N/N", **不会**因此改判据或改窗口 (窗口 5 ns 是写在本文件里的预设值).
- 选"最后一个合格帧"意味着起点来自平衡末段中碰巧满足判据的瞬时帧; 这一选择会让通过的起点在判据所测的局部几何上偏向"最好的那一刻" (选择效应). 后续分析若涉及起点几何相关量, 须把"起点经选帧"作为条件写出.
- 窗口内合格帧比例本身是读数: 例如合格 3/67 与 60/67 含义很不同, 报告须给出而不只是"通过".
- docker 内 trjconv 经 stdin 取组号 (`docker run -i`) 与 Spark 的 gmx 2026.3 未在 Spark 上验证过 (box 只有 2025.4 + 本地模式); `launch_guard` 5b 项与小预跑 `R3_relaxsel_pre` 的 CHECK 会先做自检.

## 5. 开关与参数
`SEL_RULE=1|0`, `SEL_NSTOUT=5000`, `SEL_WIN_PS=5000`, `SEL_KEEP_FRAMES=0|1` (默认值如上; 修改它们属于偏离本增补, 须在 RUN_META 中可见 — `RUN_META.txt` 已记录 `SEL_*`). 代码位置见 `lib_R3.sh` / `run_R3.sh` 中的 `[TRR-AMEND]` 注释.
