# PRE_REG_AMENDMENT_R4_supp — R4 D1v2 补充重复 (s4/s5) 为探索性, 不进预注册闸

- 日期: 2026-10-30 约 01:00 +0800 (Asia/Singapore). 写入人: LNP MD (box). 适用包: R4 D1v2 (基线 commit f83810c4, MANIFEST c39e00b0…).
- 原因: k03/k04 跑完主链后空闲 (k03 00:23:23 收尾; k04 约 01:00–02:00 收尾, 估算); 队列里没有其它已审查的作业。
- 授权依据: K 2026-10-29 17:37 批准 R4 四晚扫描、MD 可提优先级; 本修订不改任何判据, 只增加不进闸的描述性数据。

## 改了什么 (只改 chains/*.txt)
| 文件 | 改前 | 改后 |
|---|---|---|
| `chains/supp_k03.txt` | 空 | DOPE_h050_s4, DOPC_h050_s4, DOPE_h100_s4, DOPC_h100_s4, MC3H_h050_s4, MC3H_h100_s4 |
| `chains/supp_k04.txt` | 空 | DOPE_h050_s5, DOPC_h050_s5, DOPE_h100_s5, DOPC_h100_s5, MC3H_h050_s5 |
| `chains/spares_k03.txt` | 8 条 s4 | 只留 MC3_h050_s4, MC3_h100_s4 (k03 上已作替补用掉, 均 VOID_L2) |
| `chains/spares_k04.txt` | 8 条 s5 | 只留 MC3H_h100_s5 (已在 k04 作 MC3H_h100_s1 的 prereg 替补领取), MC3_h050_s5, MC3_h100_s5 |

- 40 个 build 的总集合不变, 各文件之间无重复 (CHECK 的跨文件去重照常生效)。
- 不跑中性 MC3 (层状起点已知不可行, box 预跑 0/67, Spark 上主跑+替补全部 VOID_L2)。
- 没动: mdp, ff, inputs, gate, gatewrap, lib_R4.sh, run_R4.sh, verdict_R4.py, 阈值, PREREG_R4.md。

## 判读规则 (预注册闸照旧, 补充重复一律剔除)
1. supp 队列里领取的 run 在 `ALL_RECORDS.tsv` 的 role 列 (第 6 列) = `supplement`, note = `queue=supp_k0X.txt`。prereg 的 run role 是 `primary` (主链) 或 `replacement` (L2 替补)。
2. `verdict_R4.py judge` 按 seed 顺序取每格前 3 个可评估重复, **不看 role**。如果直接对全部 build 判读, s4 可能挤掉 prereg 替补 (例: MC3H_h100 的 prereg 集合是 s2, s3 + 替补 s5; 不剔除时会取 s2, s3, s4)。所以**不改 verdict_R4.py**, 在读数时过滤:
   - 照常跑 `verdict_R4.py analyze` (全部 build)。
   - 预注册判读: 把 `results/series/` 复制到 `results_prereg/series/`, 删掉 role==supplement 的 build 对应的 `<build>.src.json` (`judge` 只按 `*.src.json` 列 build), 再跑 `verdict_R4.py judge results_prereg`。只有这一份 VERDICT.json 用于菜谱判定和晨报结论。
   - role==supplement 的 build 名单从两台 `ALL_RECORDS.tsv` 读 (`awk -F'\t' '$6=="supplement"{print $5}' | sort -u`), 并与 `chains/supp_k0X.txt` 核对一致; 不一致就停, 报告。
3. 补充重复只作描述: 单条 run 的事件/ρ/3D 图可以展示, 必须标「补充重复, 探索性, 不进闸」。不能用它把任何格从 NOT_EVALUABLE 变成可评估, 也不能改变 PASS/FAIL。
4. `SUMMARY.tsv` 里的 L2 void_rate 和 UNRESOLVED_VOID 行会把补充 build 的闸门也算进去 (例如补充 build VOID 时会出现 `NO_SPARE` / `UNRESOLVED_VOID`): 预注册的起点合格率只按 role∈{primary, replacement} 从 `ALL_RECORDS.tsv` 重算。
5. 补充 run 若被 `-maxh` 截断 (TRUNC), 照实记录, 不续跑到 08:00 之后。

## 运行方式
同机 `APPEND_TO=<原 run 目录>` 续跑 (主链已 DONE/VOID 的 build 自动跳过, 账本沿用, 已领取的替补不会再领), `SUPP=1`, DEADLINE 不变 `2026-10-30 07:30 +0800`。必须先过 `CHECK=1`。
