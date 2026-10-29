# REVIEW_D1v2_supp — 独立对抗复审 (R4 D1v2 补充重复 s4/s5)

- 日期: 2026-10-30 00:4x +0800。复审人: LNP MD executor, 在改动完成后另起一遍, 只看证据, 不信改动说明。
- 对比基线: GitHub zzz36913/lnp-md-transport `r4/D1v2/` @ f83810c4e70d7859355171007fa2a3340f25ea6f, 其 MANIFEST sha256 c39e00b0… (由 gh api 拉回并复算一致)。

## 结论: **PASS** (附 3 条操作要求, 见文末, 不涉及改包)

## 1. 改动范围 (用基线 MANIFEST 对本地包 `sha256sum -c`)
- 412 个基线文件 OK, 仅 4 个 FAILED: `chains/spares_k03.txt`, `chains/spares_k04.txt`, `chains/supp_k03.txt`, `chains/supp_k04.txt`。
- 新增: `PRE_REG_AMENDMENT_R4_supp.md`, `REVIEW_D1v2_supp.md` (本文件); 删除: 无。`MANIFEST_sha256.txt` 重生成。
- 因此 mdp / ff / inputs / gate / gatewrap / lib_R4.sh / run_R4.sh / verdict_R4.py / PREREG_R4.md / 阈值 逐字节未变。✔

## 2. 链文件内容
- 改前改后 40 个 build 的总集合完全相同 (排序后 diff 为空); 跨文件无重复 (box CHECK 两机都报「无同一 build 重复」)。✔
- supp_k03 = DOPE/DOPC h050 → DOPE/DOPC h100 → MC3H h050 → MC3H h100 (全 s4); supp_k04 同序, 少 MC3H_h100_s5。顺序符合要求。✔
- 不含中性 MC3。MC3 s4/s5 留在 spares。✔
- 已消耗核对 (依据 QUEUE.md 00:31 巡检): k03 用掉 MC3_h050_s4, MC3_h100_s4 (均 VOID, 仍在 spares); k04 用掉 MC3H_h100_s5 (prereg 替补, 留在 spares, 未进 supp)。非 MC3 的 s4/s5 两机都未被领取 (两机非 MC3 的 VOID 只有 k04 MC3H_h100_s1, 已由 s5 补)。✔
- 12 条均在 `inputs/L1_summary.tsv` 为 PASS 2/2/2/2。✔
- spares_k04 中 MC3_h050_s5 的行序移到 MC3H_h100_s5 之后: 替补按格 grep 取用, 跨格行序不影响领取。✔

## 3. 领取/重复领取 (读 run_R4.sh claim_supp + lib_R4.sh 账本)
- 账本是 run 目录内 mkdir 原子目录 `ledger/claim/<build>`; 用 `APPEND_TO=<原目录>` 续跑时沿用, 已领的替补 (含 MC3H_h100_s5) `ledger_has claim` → 不会再领。supp 循环同样先查 `ledger_has claim`。✔
- 用包内 claim_supp 原函数 + 假账本模拟 (/tmp/sim_claim.sh): k03 依次领 6 条 supplement; k04 领 5 条 supplement; k04 最坏情形 (MC3_h100_s3 VOID 尚未补) 先领 MC3_h100_s5 (replacement) 再领 5 条 supp; MC3H_h100_s5 从未被重领。✔
- 续跑时主链: prod DONE → 跳过; gate VOID_L2 → 跳过; 不会重跑。✔
- flock + launch_guard (pgrep gmx / docker ps / MPS) 保证同机不会双开。✔

## 4. 判读是否会混入补充重复 —— **会** (所以写了修订, 未改 verdict)
- `verdict_R4.py judge` 每格按 seed 顺序取前 3 个可评估 run, 不看 role。例: MC3H_h100 prereg 集合 = s2, s3 + 替补 s5; 不过滤会取 s2, s3, s4。
- 对策 (PRE_REG_AMENDMENT_R4_supp.md §判读规则): 按 ALL_RECORDS.tsv 第 6 列 role==supplement 从 judge 输入里剔除 `.src.json` 后判 prereg。role 由 claim_supp 写 (`CLAIM_ROLE=supplement`), 已核对代码。✔

## 5. box 本地 CHECK / DRY (box gmx 2025.4, MODE=local, 不是 Spark 结果)
- `CHECK=1 MODE=local ... bash run_R4.sh k03|k04`: 两机 `launch_guard: ALL OK`, 含 MANIFEST 全 OK、跨机去重 OK、闸门正/负自检、两槽 grompp 自检。日志 /tmp/R4_supp_CHECK_box_k0{3,4}.log。
- `DRY=1` (00:35, 剩 6.9 h): 两机全部 supp 作业 FITS (need 1.05–1.47 h, 估算, 加 0.75 h 余量)。

## 6. 发现的风险 (不改包, 由发车步骤处理)
1. **k04 仍在跑时不得改它的 ~/R4_pkg**: claim_supp 每次现读 chains 文件; 运行中替换会让旧进程在未过 CHECK、RUN_META 记旧 sha 的情况下领新 supp。必须等 `== machine k04 done` 再换文件。
2. **APPEND_TO 会覆写 `$OUT/RUN_META.txt`** (run_R4.sh 用 `>`), gpchk/ 自检产物也会被重写。续跑前先 `cp -p RUN_META.txt RUN_META_main.txt` 和 `cp -a gpchk gpchk_main` 留底 (只复制, 不删)。
3. k03 00:31 巡检时 MPS 残留 1 个进程; launch_guard 若报「已有 MPS 进程」或「MPSROOT 非空」→ 停, 报 LNP MD, 不自行 kill/清目录。
