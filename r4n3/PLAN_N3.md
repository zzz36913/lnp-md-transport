# PLAN_N3 · R4 第 3 晚执行计划 (只准备, 不上传, 不发车)
时间都是北京时间 (UTC+8)。窗口 11-01 14:25 (避开 13:50–14:20) → 11-02 06:50 MD 收尾 → 07:00 收 → 07:45 交回。判据见 PREREG_N3.md (A1–A4)。

## 1 选择与一句话理由
- **MC3H**: C4r = 用 BOX0_r 重建 H_II 起点 (A1)。一句话: 第 2 晚 4/4 VOID 都是几何型 (盒形门拦, 4 管完整), 起点盒改成体系自己弛豫到的盒是单变量修正。
- **中性 MC3**: **真实水合 h022** (A2), 不用 NVT。一句话: NVT 让盒形门恒过 (门形同虚设) 而且固定面积 0.75 ns 内就桥连; 塌缩是组成 (含水量) 驱动, h022 ≈ 7 水/脂与文献 H_II 含水一致, 只改一个变量。
- 不用 C4a (各向异性 C-rescale 在 2026.3 grompp 报错, proof/NEG_C4a_aniso.txt)。n=3 + 1 替补; DOPE/DOPC 尺随跑 (C4r), DOPC_lam 用第 1 晚结果 (A4)。

## 2 槽位分配 (chains/, runner 一字不改)
| 机器 | supp (主, 按序) | spares (只顶 VOID) | fill (FILL=1 才跑, → 2000 ns) |
|---|---|---|---|
| k03 | MC3_h022 s11, MC3H_h022 s11, DOPE s12, MC3_h022 s12, MC3H_h022 s12, DOPE s13, MC3_h022 s13, MC3H_h022 s13, DOPE s18 | MC3_h022 s14, MC3H_h022 s14, DOPE s19 | HYD 两体系 s11–13 |
| k04 | DOPC s11, MC3H_h100 s11, DOPC s12, MC3H_h100 s12, DOPC s13, MC3H_h100 s13 | DOPC s14, MC3H_h100 s14 | DOPC + MC3H_h100 s11–13 |
k0x_A/B、ext_* 链都是空的 (runner 先跑 ext, 这晚没有 ext)。

## 3 吞吐与时长 (**估算**; 吞吐只引 QUEUE 实测 Performance)
- 引用的实测值: DOPE h100 prod 14199 ns/day (k03, QUEUE); DOPC h100 prod 12413.695 ns/day (k04, QUEUE, 取 DOPC 实测最低值)。
- 推出值 (估算, 非实测): MC3H h100 (20280 珠) = 12414 × 19320/20280 ≈ 11826 ns/day; h022 体系 (13236/14196 珠, 比 DOPE 小) 保守按 14199; relax dt 15 fs 按 prod 的 0.75 倍。
- 单 run (relax 15 ns + prod 1200 ns + 0.25 h 搭建/EM/闸门开销, 估算): DOPE ≈ 2.31 h; DOPC ≈ 2.61 h; MC3H h100 ≈ 2.73 h; h022 ≈ 2.31 h。VOID 约耗 0.3 h。fill (+800 ns): DOPC ≈ 1.65 h, MC3H h100 ≈ 1.72 h, h022 ≈ 1.45 h。
| 机器 (2 槽) | 主 slot·h | 主完成 ≈ | + fill slot·h | 含 fill 完成 ≈ | 窗口容量 | 余量 (顶替补用) |
|---|---|---|---|---|---|---|
| k03 | 9 × 2.31 = 20.8 | 00:50 | + 8.7 = 29.5 | 05:10 | 16.4 h × 2 = 32.8 | 3.3 |
| k04 | 3 × 2.61 + 3 × 2.73 = 16.0 | 22:25 | + 10.1 = 26.1 | 03:30 | 32.8 | 6.7 |
(以上全部是估算; 实际 Performance 每晚有 ±5% 波动。DEADLINE 06:50 由 runner 硬截断, 超时段记 TRUNC。)

## 4 发车草稿 (每台机, 在 $HOME/R4N3 下; **不由我执行**)
```bash
# 0) 包: R4N3_pkg.tar.gz + .sha256 (D3/), 解到 $HOME/R4N3, sha256sum -c MANIFEST_sha256.txt
cd $HOME/R4N3 && sha256sum -c MANIFEST_sha256.txt
export J=$HOME/R4N3 NEW_RUN=1 PRIOR_RUNS=none DEADLINE="2026-11-02 06:50 +0800" PRIO=low SUPP=1 \
       K_PR_SALT=none K_VOID_FIX_N3=off GATE_PY=<该机 MDAnalysis venv 的 python>
M=k03; export EXT_SRC_RUNS="$HOME/R4N3/R4N2_run_${M}_*"     # k04 同理
# 1) 自检 (必须先过, 含闸门负自检 + 双 grompp):
CHECK=1 FILL=0 K_C2_3SYS=no bash run_R4N2.sh $M
# 2) 演练:
DRY=1  FILL=0 K_C2_3SYS=no bash run_R4N2.sh $M
# 3) 正式 (14:25 后): 默认 FILL=0; K 批 fill 才改成 FILL=1 K_C2_3SYS=yes
FILL=0 K_C2_3SYS=no nohup bash run_R4N2.sh $M > run_k03.log 2>&1 &
```
闸门点: CHECK (MANIFEST、闸门正负自检、trjconv、双 grompp) → 每 build L1 (t0) → relax 末 5 ns L2 逐帧门 → prod → 06:50 DEADLINE。

## 5 需要 K 决定的事
1. 批不批 PREREG_N3 的 A1–A4。**特别是 A1(b)**: MC3H BOX0_r 的 a_w = 0.744 超出母本 [0.50, 0.70]; 不批就记 VOID_BUILD, C4r 只剩尺子。
2. FILL: runner 只在 K_C2_3SYS=yes 时允许 FILL=1 (这晚没有 C2 三体系, 这个开关名字对不上用途, 只是个门)。默认 FILL=0 (1200 ns 已够 400/1200 两个 horizon)。
3. K_VOID_FIX_N3 必须设 off (runner 守卫; 本晚的 BOX0_r 不走那条路径)。
4. DOPC 尺: 第 1 晚 C4 规则 2 已 FAIL (RETAIN 3/3), 本晚大概率重复 → HYD Δ = NOT_JUDGED。还跑吗 (按 task 保留)? 能不能把 Δ 降成描述性数字报?
5. 独占显存 / 重启 / 删除: 本计划都不需要; 用到就先问。

## 6 02:00 小包回传 (xfer_small/collect_small.sh)
- `bash xfer_small/collect_small.sh <OUT> [DEST]` (env PKG GATE_PY GMX COLLECT): 每 build 只取最新一段且已结束 (DONE/TRUNC/NUMERIC) 的 last.gro + STATUS + md log 末 60 行 + relax 合格帧表; RUNNING 的只记状态不碰。再加 ledger、slots、runs.tsv、RUN_META, 可选跑冻结 collect 出 series tsv (删 xtc), 打 tar.gz + sha256。不碰 token, 不上传。
- 顺序: **谁先完成先传谁**。估算 k04 主段 22:25 完, 02:00 先收 k04; k03 主段 00:50 完, 02:00 收 k03 的 DONE prod (fill 在跑的记 RUNNING); 06:50 后两台各再收一次全量。
- 体积 (估算): mock (19 DONE + 1 RUNNING, 无 series) 4.1 MB; series ≈ 144 kB/run → **每台 ≈ 5–8 MB**。
- 07:00 收 → 用 `verdict_N3_wrap.py judge <out> --d1v2-lam inputs/D1v2_lam_runs.tsv --lam-src <N1_final>/runs_status.tsv --horizons 400,1200,max` 出判读 → 07:45 交回。

## 7 PEG 早/晚到预跑: **顺延** (D3/peg_timing/PEG_PRERUN_DRAFT.md)。没写 QUEUE.md, 没标 READY。
