# R3_relaxsel_pre — "取起点规则"小预跑 (只 relax + 选帧 + 闸门读数, 无 prod)
**发给调度/发车人; 我不发车, 不碰 Spark.** 与主包 `R3_launch` 用同一份 `lib_R3.sh` (逐字相同, 看 MANIFEST 里 sha), 所以这次预跑测的就是正式发车要用的选帧代码. 规则全文/时序声明: `PRE_REG_AMENDMENT_R3_trr.md` (本规则在看过预跑 0/6 与诊断之后加; 闸门阈值与判据未改; DOPC 可能没有合格起点).

## 6 个起点 (relax 起点 = 与第一轮预跑同一批 start.gro)
DOPE s2, s3, s5 · DOPC s1, s2, s3. `RELAX_ARM=crescale_dev` (maxwarn 0), 15 ns, 派生 mdp 多写 `nstxout=nstvout=5000` (75 ps/帧), 末 5 ns (~67 帧) 逐帧同一 t0_gate (prod0 lam 960/720, 0.65/0.75/0.95, 极性 0.8, 2/2/2/2, v1==v2), 选最后合格帧.

## 用法 (Spark k03, 单机, 只用 gmx 2026.3 容器; 闸门 python 走容器包装)
```
cd R3_relaxsel_pre && sha256sum -c MANIFEST_sha256.txt                 # 全 OK
mkdir -p $HOME/R3_gatewrap && cp gatewrap/gate_py_container.sh $HOME/R3_gatewrap/ && chmod +x $HOME/R3_gatewrap/gate_py_container.sh
export GATE_PY=$HOME/R3_gatewrap/gate_py_container.sh
DRY=1 bash run_relaxsel.sh            # 只打印计划
CHECK=1 bash run_relaxsel.sh          # 自检: gmx 2026.3 / 容器内 trjconv 经 stdin 取组号 / 闸门 python 依赖 / 无占卡冲突 / 磁盘
bash run_relaxsel.sh 2>&1 | tee relaxsel_stdout.txt      # 默认两槽并行 (A=DOPE x3 pin 15, B=DOPC x3 pin 5, 一个用户态 MPS); SEQ=1 则单槽顺序 6 个
```
输出 `$J/R3_relaxsel_k03_<TS>/` (`J` 默认 `$HOME/R3_relaxsel`). 跑完自动出 `SUMMARY.md|tsv`. 估时(估算): 每槽约 25–40 min. 磁盘: 6 个 relax.trr ≈ 1.2 GB.

## 产出 (每个 build, 目录 `builds/<b>/`)
- `relax/attempt_001/`: relax.gro/.cpt/.trr/.log, `Performance` (同时进 `THROUGHPUT.tsv`), 派生 mdp 与 `mdp_diff_trr.txt`.
- `select/attempt_001/`: `SELECTED_FRAME.txt` (n_frames_window / n_qualified / qualified_fraction / selected_t_ps / sha), `frames.tsv` (每帧 t_ps, 闸门退出码, verdict, 0.65 读数), `gate_frames/f*.json`, `selected.gro` (SEL_OK 时), STATUS=SEL_OK|SEL_NONE|SEL_SKIP.
- `gate/attempt_001/`: 对选中帧 (SEL_NONE 时对末帧, 必然 VOID_L2) 再判一次, `gate.json` 读数.
- `SUMMARY.md/tsv`: 合格帧比例 / 选中 t_ps / 末帧读数 (与旧 0/6 同口径) / 逐帧合格串 / Performance.
- 回传: `bash pack_return.sh <输出目录>` (排除 relax.trr/.cpt/.tpr/.edr 的 tar.gz, 含 selected.gro 与全部 json/tsv/日志) + `relaxsel_stdout.txt`.

## 注意
- 未在 Spark/gmx 2026.3 上跑过 (box 只有 2025.4 + 本地模式): 新依赖是**容器内 trjconv 经 stdin (`docker run -i`)**, CHECK 先测它; 失败请回报 `$W/trj.log`, 不要改脚本凑过.
- 容器名前缀 `R3RS_<机>_<pid>_*`, 退出/中断只停这些容器. 不 rm 任何东西, attempt 不覆写.
- 并行时闸门 python 限 2 线程 (包装脚本内), 不抢 mdrun 的 CPU.
- 目录里没有 prod 步骤; 预跑结果不是 R3 数据, 只用于判断选帧规则在 DOPE/DOPC 上给出多少合格起点 (DOPC 可能一个都没有, 如实报告).
