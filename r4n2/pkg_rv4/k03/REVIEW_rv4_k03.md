# REVIEW rv4 — k03 分包（包 a）独立审查

- 对象：`R4N2v4_k03.tar.gz`（54,117 B，sha256 `ba47048bc285e9581de3568c77204342d51d7c89fa888d65cf0e62cf5e1e00f4`），55 个新文件，解到 rv3 底包 `~/R4N2_pkg/R4N2` 上（`tar -k`）
- 时间：2026-10-31 15:40 SGT（新加坡时间）
- 结论：**PASS**（见第 7 节的剩余风险，都不阻断发车）

## 1. 冻结与底包
- 在 /tmp 用 rv3 tar 加本包做了一次干净解包：`MANIFEST_sha256.txt`（rv3）、`FROZEN_sha256.txt`、`MANIFEST_rv4_sha256.txt` 三份全部 `sha256sum -c` 通过。冻结三件 verdict 4fd49504、PREREG 19622358、amendment 5b850f29 逐字节不变。
- I1：`tar -k` 0 冲突，rv3 文件逐字节不变。

## 2. 分包与分支
- tar 里只有 `chains_rv4/extq_k03.txt`，没有 k04 的队列。I2：用真包树在 k03 上 CHECK 结果 ALL OK；在 k04 上 CHECK 报 FAIL（缺队列），所以不会误装到 k04 上跑。
- `K_BRANCH=4SYS` 被 launch_guard 硬拒（C2 branch4sys 和 O2 都验证了，没有起任何条目）。空值或其他值同样 FAIL。只接受 3SYS。

## 3. 队列与源（k03 上只有 DOPE）
- 共 18 行，DOPE T350（C4）和 T320（C3）的 s1–3 各 3 段（1200/2000/3000）。只有 C4 @1200 是 prereg，其余都是 explore。
- 第 5 列的源全部写成字面量 `~/`（审查中发现并修正：生成时一度被展开成 /home/box/，CHECK 当场 FAIL，已改回）。
  - C4 源：`~/R4N1x/R4N1x_run_k03_1030_145609`
  - C3 源：`~/R4N1/R4N1_run_k03_1030_141205`
  - 两处都是第 1 晚 400 ns prod DONE（laststep 20,000,000）。
- MC3H/MC3 不进队列：第 1 晚 C3 MC3H/MC3 h100 hii 全部 VOID_L2；C4 MC3H 第 1 晚没跑；本晚 rv3 在 k03 的补跑也全部 VOID_L2（调度 15:28）。DOPC 的 checkpoint 都在 k04，归包 b。
- 不跳段：2000 段以本 OUT 的 ext1200 DONE 为源，3000 段以 ext2000 DONE 为源（E7、E8、O1、O3 已验证）。
- 1.2 µs = 60M 步，2 µs = 100M 步，3 µs = 150M 步（dt 0.02 ps），E1/E8 用 convert-tpr dump 复核过。

## 4. 机器与资源边界
- 输出目录、锁、容器名前缀、MPS 根都用 `R4N2v4` 这套名字，和 rv3 分开。
- WAIT_SCOPE=machine：等 rv3 整机 done 或锁释放后才起（O5）。rv3 的 MPS 最多等 600 s 退净，超时也不 kill（T10–T12）。
- 守护的正则不匹配 GLM 容器，也不碰 8888/18888 端口。只会 stop 自家的 `R4N2v4_k03_<pid>_*` 容器。
- DEADLINE 硬上限是 07:30 +0800，设得更晚会 FAIL。explore 段在 DL−0.25 h 截断。

## 5. 自检（box，MODE=local + mock gmx）
- test_ext_rv4 E0–E11：ALL PASS
- test_mps_rv4 T1–T12：ALL PASS
- test_orch_rv4 O1–O6：ALL PASS（O1 = k03 实况，18 段 DONE，没有 MC3x）
- test_check_dry_rv4：ALL PASS
  - C1：k03 / k03done / k04 三种情况
  - C2：10 条负自检
  - D1：DRY 3 情景
  - I1、I2：见上

## 6. 时长（估算，DRY 起点 SIM_START=16:45；以 15:20 起 k03 已空闲计）
| 情景 | prereg C4 DOPE 1.2 µs ×3 完成 | 2 µs（C4+C3） | 3 µs（6 条） |
|---|---|---|---|
| 模型 14258 ns/day | 19:35 | 01:17 | 06:32 全完 |
| 实测 MPS 16900 | 19:10 | 00:02 | 04:31 全完 |
| 无 MPS 4600 | 01:08 | C4 2 µs 05:20 完；C3 1.2 µs 截断约 762 ns | 跳过 |

三种情景下 prereg 都能跑满 1.2 µs。

## 7. 剩余风险（不阻断）
1. 真实 `convert-tpr` 加 `-cpi -noappend` 还没在 Spark 上实跑过。发车后 15 min 内须确认 `ext.part0002.log` 的步数超过 20,000,000，且 Performance 不低于 10000 ns/day。
2. tar 内文件的 mtime 统一是 2026-10-31 16:00（为了产出确定的 tar）。16:00 前解包 tar 会报 "in the future" 警告，无害。
3. 3000 段是新加的探索段，只用剩余时间，不进任何判据。
