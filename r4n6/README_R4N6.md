# R4N6 · Q1 ANISO + Q2a h050@T350 (11-03 晚 → 11-04 06:50, UTC+8)
预注册: PREREG_N6.md (§1-§9); 判读: verdict_N6_wrap.py (内部调用冻结 verdict_R4_3day.py, sha 4fd49504…, 未改); 自检: SELFCHECK_N6.md; 与 R4N5 的差异: DIFF_vs_R4N5.txt.
**本包只是作业包, 没有起跑、没有上传任何东西; 起跑与上传由调度方按下文做.**

## 1 做什么
- k03 = DOPE (阳性), k04 = DOPC (阴性). 每机两臂, 各 n=3, 一臂一个旋钮:
  - Q1 ANISO: T350 h100, prod 改各向异性 Parrinello-Rahman (s601 s602 s603; 替补按序 s604 → s605)
  - Q2a H050: T350 h050 (s501 s502 s503; 替补按序 s504 → s505)
- 主队列交错领 (supp_k0x.txt); 替补只顶 VOID (spares_k0x.txt). 每条 relax 15 ns → L2 闸门 → prod_lam 1200 ns.
- 补位 (PREREG_N6 §8; **须 K 确认后才设 NEXT_FILL=1**, 默认 0 = 空槽闲置): 主两档 supp 全领走后空槽按序领:
  1. XEXT (§8.1): R4N5 360 K 已 DONE 的 5 条续到 3000 ns (k03 DOPE s501 s502 s504; k04 DOPC s502 s503). 源断点清单 `xext/SPARK_SRC_LIST.tsv` (**起跑前请调度核实**). 源缺/sha 不符 → XEXT_NO_SRC, 不从头重跑, 该槽退到 2.
  2. NEXT (§8.2): h050@T360 (s501-s503, 替补 s504 → s505), 单槽块.
  - 补位数据单独判读, 不改主臂 n 和判据. XEXT DOPC 最多 n=2 → XEXT 永远到不了 CONTRAST_PASS (只能 FAIL / NOT_EVALUABLE / METHOD_OVERDRIVEN), 另有描述列 (搭桥 ncl、Cz 下降), 不进门.

## 2 起跑 (永远 NEW_RUN=1; 两台 CHECK 串行)
```
cd ~/R4N6_pkg/R4N6 && sha256sum -c MANIFEST_sha256.txt | grep -v ': OK$'    # 须无输出
COMMON="WAIT_MAIN=none FILL=0 K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off X_MPS_JOIN=off NEW_RUN=1 NEXT_FILL=0 GATE_PY=$HOME/R4N6_pkg/R4N6/gatewrap/gate_py_container.sh"
#   K 确认补位规则后把 NEXT_FILL=0 改成 NEXT_FILL=1 (XEXT 默认源 EXT_SRC_RUNS=$HOME/R4N5/R4N5_run_<机>_*; 若机上有多个同名 run 目录, 设 EXT_SRC_RUNS=<目录>)
env CHECK=1 $COMMON bash run_R4N6.sh k04    # 须 ALL OK
env DRY=1   $COMMON bash run_R4N6.sh k04    # 看队列与 FITS; NEXT_FILL=1 时会列出 xext 源是否合格
mkdir -p ~/R4N6 && nohup env $COMMON bash run_R4N6.sh k04 > ~/R4N6/k04.nohup 2>&1 &
# k03 (DOPE): k04 的 CHECK 结束后, 同上把 k04 换成 k03
```
- 起点筛查: 35 个 build 的 L1 (输入层) 已在 box 上判过 (inputs/L1_summary.tsv 35/35 PASS), 70 个 grompp 已在 box 上跑过 (selfcheck/grompp/SUMMARY.tsv). relax 后的 L2 闸门只能在机上跑: 发车后第一时间由运行器自动判, 不合格即 VOID 并按 spares 顺序领替补 (PREREG_N6 §3).

## 3 收集 (小包: 先完成先传, 小在前大在后)
```
COLLECT=0 bash ~/R4N6_pkg/R4N6/xfer_small/collect_small.sh $HOME/R4N6/R4N6_run_<机>_<TS>   # 中途
COLLECT=1 bash ~/R4N6_pkg/R4N6/xfer_small/collect_small.sh $HOME/R4N6/R4N6_run_<机>_<TS>   # 11-04 07:00 收尾 (冻结 collect + N6 判读草稿 + XEXT 收集/判读)
```
- 每 build: 起点帧 `start/selected.gro.gz` + `prod/frames/t{0,200,…,1200}.gro.gz` (XEXT: `ext3000/frames/t{1400,…,3000}.gro.gz`) + 末帧 + series csv; 分析表 `ANALYSIS.tsv`.
- 上传顺序见 `~/R4N6/xfer/<tag>.upload/UPLOAD_ORDER.txt`: 00_summary (最小) → 每 build 小 tar (按完成时刻) → 全量 `<tag>.tar.gz` (最大). 标 SAME_AS_PREV 的小 tar 与前一次内容相同, 可不再传. 上传照旧流程 (k04 经 k03).

## 4 box 上正式判读
```
python verdict_N6_wrap.py judge <collect 目录>                                 # 主两臂 → VERDICT_N6.{json,md}, runs_N6.tsv
python tools/merge_xext.py <k03 的 collect_xext> <k04 的 collect_xext> --out xext_merged
python verdict_N6_wrap.py judge_xext xext_merged                               # XEXT → VERDICT_N6_XEXT.*, runs_N6_xext.tsv (含描述列)
#   NEXT h050@T360 (若跑了) 在 judge 输出里单独一档 (NEXT), 不并入主两臂
```
