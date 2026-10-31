# REVIEW rv4 — k04 分包（包 b）独立审查

- 对象：`R4N2v4_k04.tar.gz`（54,168 B，sha256 `c9e73baeaa48f1f0cc8e9a2178e66431c864c8651d5aea84a081f57dae5df61a`），共 55 个新文件。解到 k04 上 rv3 的底包 `~/R4N2_pkg/R4N2` 上（`tar -k`）。
- 时间：2026-10-31 15:45 SGT（新加坡时间）
- 结论：**PASS**

## 1. 冻结与底包
- 在 /tmp 把 rv3 tar 和本包一起干净解开，三份清单都过了 `sha256sum -c`：rv3 `MANIFEST_sha256.txt`、`FROZEN_sha256.txt`、`MANIFEST_rv4_sha256.txt`。
- 冻结文件 verdict 4fd49504、PREREG 19622358、amendment 5b850f29 逐字节不变。
- I1：`-k` 解包 0 冲突，rv3 文件逐字节不变。

## 2. 与 k03 包（包 a，commit 9e11fbc6）的隔离（专项）
- **仓库**：本包只新增 `r4n2/pkg_rv4/k04/*`。上传后核对 `r4n2/pkg_rv4/k03/` 的 6 个 blob，与 9e11fbc6 完全相同（见第 7 节）。
- **两包内容对比**：
  - 共同的执行代码逐字节相同：`run_R4N2v4.sh`、`lib_R4N2v4.sh`、`inputs_rv4/*`、`tools_rv4/*`、`tests_rv4/mock/*`、`test_ext`、`test_mps`、`VARIANT_rv4`。
  - 不同的文件只有按机生成的几个：`FILES_rv4.txt`、`MANIFEST_rv4_sha256.txt`、`README_rv4.md`（k04 那一行写了 3 µs 段）、队列（k03 包只有 `extq_k03.txt`，k04 包只有 `extq_k04.txt`）。
  - 另有两个测试脚本不同：`test_check_dry` 的 rv4file 负自检改为篡改 lib，k04 起点改为 19:30；`test_orch` 的 O3 扩展到 3 µs。这两个只在 box 上运行。
- **机上**：两台机器各有自己的 `~/R4N2_pkg`，本包只发往 k04。模拟误操作，先在同一棵树上解 k03 包，再用 `-k` 解 k04 包，结果：
  - tar 返回 rc=2，报 "Cannot open: File exists"；
  - k03 包的 `MANIFEST_rv4` 和 `extq_k03.txt` 的 sha 都没变，没有覆盖。
  - 发车令已写明：rc≠0 或出现 "File exists" 就停下。
- **分包守护**：I2 用真实包树验证，在 k04 上 CHECK 结果 ALL OK，在 k03 上 CHECK FAIL（缺队列）。

## 3. 队列与源（k04 上只有 DOPC）
- 共 18 行，全部是 DOPC：
  - C4 h100 T350 hii s1–3，源 `~/R4N1x/R4N1x_run_k04_1030_145916`
  - C3 h100 T320 hii s1–3，源 `~/R4N1/R4N1_run_k04_1030_141353`
  - 两个源目录都是第 1 晚 400 ns prod DONE，laststep 20,000,000。第 5 列写的是字面 `~/`。
- 排序：C4 @1200（prereg）→ C4 @2000 → C3 @1200 → C3 @2000 → C4 @3000 → C3 @3000。除 C4 @1200 外都是 explore，在 07:15 截断。
- 不跳段：O3 模拟 s1 的 ext1200 FAIL，结果 ext2000 和 ext3000 都记 EXT_LOWER_NOT_DONE，不建目录；其余 15 段 DONE；3000 段的源是 ext2000。
- 本文件没有 main 行，k04 上的 rv3 只作为等待对象。
- `K_BRANCH=4SYS` 被硬拒（C2 和 O2 都验证过）。

## 4. 等待与边界
- `WAIT_MAIN=$HOME/R4N2/R4N2_run_k04_1031_145709`，等待范围是整机：要求没有 rv3 容器，并且 rv3 `orchestrator.log` 已写 `== machine k04 done` 或锁已释放（O5 验证）。之后再等 rv3 MPS 退净，最多 600 s，期间不 kill（T10–T12）。
- 守护规则不匹配 GLM 容器，不碰 8888/18888 端口，只 stop 自己的 `R4N2v4_k04_<pid>_*`。
- DEADLINE 的硬上限是 07:30 +0800。

## 5. 自检（box，MODE=local + mock gmx）
- ext E0–E11：ALL PASS
- mps T1–T12：ALL PASS
- orch O1–O6：ALL PASS
- check_dry：ALL PASS，内容包括：
  - C1：k03、k03done、k04 三种情况
  - C2：10 条负自检
  - D1：两台机器各 3 个情景，k04 起点 19:30
  - I1、I2（用本 tar）

## 6. 时长（估算；起点 19:30 = rv3 lam 补跑预计结束，按 14:57 发车推算）
DOPC 每 800 ns 段：模型 1.78 h，实测 MPS 1.52 h，无 MPS 5.3 h。

| 情景 | C4 DOPC 1.2 µs s1、s2 完 | s3 完（预注册 3 条全完） | C4 2 µs | C3 1.2/2 µs | 3 µs |
|---|---|---|---|---|---|
| 模型 14258 ns/day | 21:17 | 23:04 | 00:51 | 04:26 / 06:13 | C4 s1、s2 截断约 2465 ns，其余跳过 |
| 实测 MPS 16900 | 21:01 | 22:32 | 00:04 | 03:06 / 04:38 | C4 s1、s2 06:31 完，其余跳过 |
| 无 MPS 4600 | 00:49 | 06:09 | s1 06:09 完；s2、s3 截断约 1363 ns | 不起 | 不起 |

## 7. 剩余风险（不阻断）
1. 无 MPS 时预注册的 s3 余量很小。prereg 要求剩余时间 ≥ need + 0.75 h；若 lam 比约 20:05 更晚结束，s3 会降级为 prereg_trunc（记 PREREG_NO_FULL_FIT，不作 1.2 µs 判读）。有 MPS 时余量充足。
2. 真实的 `convert-tpr` 加 `-cpi -noappend` 还没在 Spark 上实跑过。起跑后 15 min 要看到步数 >20,000,000 且速度 ≥10000 ns/day。
3. tar 里文件的 mtime 是 10-31 16:00，16:00 前解包会有 "in the future" 警告，无害。
