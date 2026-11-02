# R4N5 · 片层起点 DOPE/DOPC 对照包 (11-02 晚 → 11-03 06:50, UTC+8)
预注册: PREREG_N5.md (白话 5 行: PREREG_N5_K.md); 自审: REVIEW_N5.md; 自检: SELFCHECK_N5.md; 判读: verdict_N5_wrap.py (内部调用冻结 verdict_R4_3day.py, sha 4fd49504).
来源: K 2026-11-02 13:16 决定「今晚换层状起点，DOPE 和 DOPC 都从层状开始」. **本包只是作业包, 没有起跑任何东西; 起跑由调度方按下文做.**
**v2 (K 11-02 13:46):** 加 MC3H/中性 MC3 片层 n=3 (各机排在尺子之后) + 半夜分支 a/b/c (开关文件 `$HOME/R4N5/BRANCH`, 见 PREREG_N5 §8-§10). 包内同时带好 T360/T330 分支输入.

## 1 做什么
- k03: DOPE 片层 ×3 (supp_k03: s501 s502 s503; 替补 spares_k03: s504). k04: DOPC 片层 ×3 (supp_k04: s501 s502 s503; 替补 s504).
- 每条: relax 15 ns → L2 片层闸门 → prod_lam 1200 ns 单段 (c-rescale semiiso τp=4, 第 1 晚冻结加压段). 起点 = 第 1 晚 lam 构建逐字节 (只换 relax 速度种子 + prod nsteps).
- 主链 k0x_A/B、ext_*、fill_* 为空 (只有注释); 两个槽从同一条补跑队列按序领.
- 槽位: **B 槽只在 MPS 可用时领新条** (own/own_started/own_restarted/join_main), 否则 B 槽停、A 槽单槽跑完 (PREREG_N5 §4). 想强制 1 槽: 加 `X_MPS=off`.
- 不自动续跑; 余量怎么用由 K 定.

## 2 起跑 (今晚无主包 → WAIT_MAIN=none; 永远 NEW_RUN=1, 不用 APPEND_TO)
解包目录 `~/R4N5_pkg/R4N5`; 输出 J 默认 `~/R4N5` (不设 J). 两台的 CHECK 串行跑.
```
cd ~/R4N5_pkg/R4N5 && sha256sum -c MANIFEST_sha256.txt | grep -v ': OK$'    # 须无输出
COMMON="WAIT_MAIN=none FILL=0 K_C2_3SYS=no K_PR_SALT=none K_VOID_FIX_N3=off X_MPS_JOIN=off NEW_RUN=1 GATE_PY=$HOME/R4N5_pkg/R4N5/gatewrap/gate_py_container.sh"
env CHECK=1 $COMMON bash run_R4N5.sh k04    # 须 ALL OK (k04 = DOPC)
env DRY=1   $COMMON bash run_R4N5.sh k04    # 看队列: 3 supp + 1 替补, 均 FITS
mkdir -p ~/R4N5 && nohup env $COMMON bash run_R4N5.sh k04 > ~/R4N5/k04.nohup 2>&1 &
# k03 (DOPE): k04 的 CHECK 结束后, 同上把 k04 换成 k03
```
DEADLINE 默认已是 `2026-11-03 06:50 +0800` (lib), 不用另设. 起跑前 CHECK 会: 核对每条 prod_lam.mdp 6 个加压键 = 档 5 (LAMSEMI)、relax 加压段 = R; 闸门正/负自检 (负自检帧 proof/neg_selftest_bridged.gro 本包已带上); 机上不得有 R4N2_/R4N4_/R4N5_ 等残留容器、不得有残留 MPS 进程.

## 3 收集
- [v2] 11-02 ~20:30 与 11-03 ~01:00 中途 (分支检查点): `COLLECT=0 bash ~/R4N5_pkg/R4N5/xfer_small/collect_small.sh $HOME/R4N5/R4N5_run_<机>_<TS>` (也跑冻结 collect + INTERIM 判读, 带每 run series csv). 02:00 那次取消.
- [v2] 分支: 检查点后按 PREREG_N5 §9 在两机写 `echo a > $HOME/R4N5/BRANCH` (或 b / c); 运行器下次领作业时生效. 两槽已结束则 `NEW_RUN=1 BRANCH=x ONLY="<分支格名>" bash run_R4N5.sh <机>` 新起 (先 CHECK).
- 11-03 07:00 收尾: `COLLECT=1 bash ~/R4N5_pkg/R4N5/xfer_small/collect_small.sh $HOME/R4N5/R4N5_run_<机>_<TS>` (另跑冻结 collect + N5 判读草稿 judge_N5.log)
- 产物 `~/R4N5/xfer/<tag>.tar.gz` (+ .sha256); 上传照旧流程 (k04 经 k03).
- box 上正式判读: `python3 verdict_N5_wrap.py judge <collect 输出目录>` (读 runs_status.tsv) → VERDICT_N5.{json,md}, runs_N5.tsv.

## 4 取包 (k03 有外网; k04 经 k03)
仓库 zzz36913/lnp-md-transport, 目录 `r4n5/` 见下方 commit; 用 `@<commit>` 的 jsdelivr 链接 (不要 @master, 有缓存). 镜像顺序 ghproxy.net > ghfast.top > fastly.jsdelivr.
`cat R4N5_pkg.tar.gz.p_* > R4N5_pkg.tar.gz && sha256sum -c R4N5_pkg.tar.gz.sha256 && mkdir -p ~/R4N5_pkg && tar -C ~/R4N5_pkg -xzf R4N5_pkg.tar.gz`
