# R4N4 独立复核 —— 结论: 没有放松任何闸门
按"只看文件、不信说明"复核 (脚本输出见 review_raw.txt):
1. run_R4N4.sh / lib_R4N4.sh 对 R4N3 的 run_R4N2.sh / lib_R4N2.sh 做 diff: 新增/改动行全部属于 [R4N4] 范围 (输出目录/锁/容器前缀/MPS 根改名、等 R4N3 空槽、MPS 加入、档位核对、WAIT_MAIN 防呆、DEADLINE 06:50)。删除行里唯一带"GATE"字样的是运行元数据 env 打印行 (换成同样打印 + 本包 sha)。没有改选帧、闸门调用、maxwarn、VOID 判定、替补逻辑。
2. gate/ (7 文件)、gatewrap/、tools/l1_scan.sh、verdict_R4_3day.py、PREREG_R4_3day.md、FROZEN_sha256.txt、D1v2_lam_runs.tsv: 与 R4N3 包逐字节相同。冻结 sha 5/5 OK。
3. 阈值: L2 max|dL/L0| ≤ 0.30, wpol==1, n_tube==4; RETAIN ≥ 0.80 / LOST ≤ 0.20; N_PER 3; 窗 100 ns; 最短 400 ns —— 原文未动。
4. mdp: 48 个派生 mdp 与 R4N3 源逐键比较, relax 只差 gen_seed, prod 只差 gen_seed + 6 个加压键; 0 越界。起点/拓扑/索引/expect.env 逐字节相同 → L2 的 BOX0 参照不变。
5. 判读包装只改条件格、种子映射、按档分开、规则 3 借用; 测试 T10/T11 断言冻结文件 sha 与"包装里无阈值字面量"。
6. 新增判据: 无。盒形只作描述, 不进判读 (PREREG_N4 §4)。
复核局限: 本复核由出包同一执行方以脚本完成 (未另起独立的人/代理); GPU 上的 PR 档速度未实测。

## v2 复审处理 (2026-11-01 UTC+8)
- 复审必改 1 处 (docker ps 行注释吞代码) 已修, 负测试见 selfcheck/NEG_dockerps.txt; 同类扫描见 selfcheck/SCAN_inline_comments.txt。其余 v2 改动见 SELFCHECK.md "v2" 节。
