# R4N1 Spark 上需核实的事项 (box 上做不了; 交调度)
版本: AMENDMENT_01 后 (REVIEW_R4N1 M3 补齐, K 10-30 12:14 批)。条目按时间顺序排: A 发车前 → B 发车 → C 运行中 → D 收尾。

## A 发车前 (每台机器各做一遍)
1. **GLM 已停**: 本地助理确认 GLM "已停、显存已清空" (RUNBOOK L691, 审查报告引), 并留记录。没有这条确认不发车。
2. **GLM 现场快照 (发车前)**: 记下 `ss -ltnp | grep -E ':(8888|18888)\b'` 与 `docker ps -a --format '{{.Names}} {{.Status}} {{.Image}}' | grep -i glm` 的输出 (存到 $J/glm_before_<机>.txt)。本包不碰 8888/18888, 不碰 GLM 容器; 这一步只是留底, 收尾时对比 (第 15 条)。
3. gmx 版本: 容器里 `gmx --version` 应为 2026.3 (EXPECT_GMX 默认 2026.3)。box 上只验了 2025.4。
4. 解包与完整性: 包放在 $HOME 下 (gate_py_container 只挂 $HOME 和 /tmp; launch_guard 现在会显式检查包与 $J 都在 $HOME 下)。`sha256sum -c MANIFEST_sha256.txt --quiet` 无输出; `stat -c %h inputs/ff/martini_v3.0.0.itp` full 包 = 64, reduced 包 = 48; 包 tar 的 sha 与 TARBALL_sha256.txt 一致。
5. grompp (2026.3): 抽查各类 mdp 是否 0 warning, 包括 relax/prod × hii/lam × 320/350 K、h100, 以及 hii 臂由 TRR-AMEND 派生出的 relax mdp。launch_guard 自带两槽 grompp 自检, 但只测 REFH/REFL 两条。350 K 下 rlist=1.35、verlet-buffer-tolerance=-1 时, 看 grompp/mdrun 有无 buffer 提示。
6. 闸门依赖: `GATE_PY=gatewrap/gate_py_container.sh`, 容器内 numpy/scipy/MDAnalysis 能否导入, t0_gate_hii.py 能否运行。launch_guard 的 H_II 正自检 (L2 PASS) 和负自检 (片层起点 rc=3) 必须全 ok。
7. MPS: 先 `bash tools/mps_residue.sh` 只读查看 (owner/pid/etime/pipe)。确认是自己的残留才 `QUIT=1`; 别人的报 K。**不 kill, 不删目录**。独占显存或重启须 K 批。
8. GPU/CPU 占用: nvidia-smi、docker ps 里有无别的作业 (launch_guard 查 R4N1_ 前缀和 gmx 进程)。两槽 pin 15/5、NT=5 与机器核数是否相容。
9. 磁盘: AMENDMENT_01 起 SEL_KEEP_FRAMES 默认 1 (不删帧), 每台机器比 D1v2 多占约 3 GB (估算, 审查报告); launch_guard 磁盘门槛已从 5 GiB 调到 10 GiB。每条 relax 写 trr (每 75 ps 一帧, 15 ns 约 200 帧), 再加 prod xtc。
10. trjconv 读 hii 的 trr、逐帧抽帧 (含速度), 在 2026.3 上是否正常 (launch_guard 的 trjconv stdin 自检只测了组号)。

## B 发车 (顺序固定, 每台机器一个实例)
11. **选版本**: 19:30 (+0800) 前 `CHECK=1` 的 launch_guard **全部 OK** 才用 full; 不只看钟点。launch_guard 有硬门槛: VARIANT=full 在 2026-10-30 19:30 +0800 之后新启动直接 FAIL, 提示改用 R4N1_reduced (APPEND_TO 续跑不受限)。DEADLINE 为 2026-10-31 07:30 +0800。
12. **发车顺序**: 在包目录里依次
    ```
    GATE_PY=$PWD/gatewrap/gate_py_container.sh CHECK=1 bash run_R4N1.sh <机>     # 必须 ALL OK
    GATE_PY=$PWD/gatewrap/gate_py_container.sh DRY=1   bash run_R4N1.sh <机>     # 看计划与时间判断
    GATE_PY=$PWD/gatewrap/gate_py_container.sh setsid nohup bash run_R4N1.sh <机> > $HOME/R4N1_<机>_launch.log 2>&1 &
    ```
    k03、k04 各起一个实例, 不在同一台机器上起第二个 (幂等: 已有 R4N1_run_<机>_* 时默认 ABORT)。
13. **速率核对 (估算待实测)**: 350 K 与 H_II 盒形 (h100 的 Lz 6.16 nm 扁盒) 的 ns/day 没测过。**拿第 1 条 prod 开头 15–20 min 的 ns/day** (prod.log 的 performance, 或 THROUGHPUT.tsv 里 stage=prod 的行) 与 PERF_NOM=14258 @15420 珠比。**不要拿 relax 比**: PERF_NOM 是 prod 速率, D1v2 实测 relax 只有 5123–9932 ns/day (约 5–10k, THROUGHPUT.tsv), 拿 relax 比一定会误判"偏低"。prod 确实明显偏低时, 用 $J/R4N1_perf_override.env 下调, 并报 K 重新判断 full/reduced。 **补充**: 包内两个时间估算不一致, 按运行器估算最长槽约 12 h, 所以完整版必须尽早发车; 目标 14:30 前后发车。

## C 运行中
14. **运行中不改 chains/ 和包内任何文件** (MANIFEST 会失配, 续跑的 launch_guard 会 FAIL)。

## D 收尾
15. **07:30 收数, 08:00 前交还 GLM** (RUNBOOK L910, 审查报告引)。收尾后确认: `pgrep -c nvidia-cuda-mps` = 0、`docker ps --filter name=R4N1_ -q | wc -l` = 0、`pgrep -c gmx` = 0。再做一次第 2 条的 GLM 快照 (存 $J/glm_after_<机>.txt), 与发车前对比, 8888/18888 与 GLM 容器应未被动过。
16. 回传: 每条的 prod.xtc + prod.tpr + gate/select 记录 + ALL_RECORDS.tsv + RUN_META, 在 Spark 上生成 SHA256_out.txt。不回传 trr。
17. **第 2 晚 APPEND_TO 之前先备份 RUN_META** (RUNBOOK L993, 审查报告引): `cp -p RUN_META RUN_META.bak_<TS>`。
18. convert-tpr (2026.3 写法) 留到第 2 晚, 本晚不用。

## E 补充
19. **发车前核对 `hostname` 与传给 run_R4N1.sh 的 k03/k04 参数一致** (内标按机器绑定, 机器参数错会让 MC3/MC3H 对比混入机器差异)。
20. **紧急停车**: 在运行目录 ($OUT) 里放一个 `HALT` 文件 (`touch $OUT/HALT`), 脚本支持 (lib_R4N1.sh `halted()`): 当前步骤退出后不再起新条, 等它自行停下。不 kill MPS, 不删目录。
