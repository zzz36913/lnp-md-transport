# R2b 兜底包 B (对照门补第 3 个重复, n=2→3) — 4 条 / 6 µs — 零 GPU 已验, 未在 Spark 上试跑
来源: /workspace/lnp-md/scan/R2b (box 生成)。**不上传、不连 Spark、不写 QUEUE.md**, 由调度/K 决定。预注册见 dd/56_R2a_prereg.md (本包不改门)。

## 目的
R2a 对照门四臂 (DOPE/DOPC × 片层/H_II 起点, 3 w/l) 目前每臂 n=2。R2b 每臂各补 1 条新种子 (s3), 凑 n=3。R2a 链结束后接着跑, 不抢 R2a。MC3H 不含。

## 预注册门 (继承 R2a 对照门, 不新增阈值)
- DOPC 任一条出现 H_II = 假阳性 = 失败 (DOPC_lam 与 DOPC_hii 均如此; DOPC_hii 保守读法 A: 通过=塌成片层)。
- DOPE 片层应出 H_II (DOPE_lam 通过=H_II; DOPE_hii 通过=留在 H_II)。
- 每条的 LAM / H_II / OTHER 判据、截断规则 (<99% 目标的 LAM 读数算未定; <50% 不判) 逐字沿用 verdict_R2a.py。
- **n=3 的表述只许写 "一致 / 不一致"** (每臂 s1,s2,s3 状态是否全同); n=3 仍不足以做统计结论, 不写显著性/概率/置信度。

## 内容 (解压到 $HOME/R2b)
- starts/R2b_{DOPE,DOPC}_{lam,hii}_s3 : sys.gro sys.top index.ndx em/eq1/eq2/prod.mdp itps SYSTEM.txt counts.txt preasm.json
- scripts/run_R2b.sh (单 run: EM→eq1→eq2→prod), R2b_slot.sh (一个槽按 chain 顺序), R2b_machine.sh (起 MPS + 两槽并行)。相对 R2a 只有: R2a→R2b 改名; machine 加两道守卫 (MPSROOT 含 mps_R2a 则 ABORT; 有 gmx 进程则 ABORT, ALLOW_BUSY=1 可覆盖); run 加 taup_check (tau_p>=25*nstpcouple*dt, eq1/eq2/prod 不满足即 ABORT)。
- chains/{k03,k04}_{A,B}.txt ; JOBLIST_R2b.tsv (估算) ; DIFF_vs_R2a_patched.txt (mdp 逐项 diff 证据) ; TAUP_TABLE.tsv (tau_p 规则逐阶段表) ; MANIFEST_sha256.txt
- 读数脚本不在包内 (只在 box 跑): /workspace/lnp-md/scan/R2b/verdict_R2b.py

## 与 R2a 的差异 (diff 证明: DIFF_vs_R2a_patched.txt)
对象 = R2a 包 mdp 经 patch_np5.sh (nstpcouple 20→5) 后的版本。R2b 的 em/eq1/eq2/prod.mdp 与同臂 R2a s1、s2 逐文件 diff: **只有第 1 行注释 (R2a→R2b 标签) 与 eq1/eq2/prod 的 gen_seed 不同**; nstpcouple 在 12 个 mdp 中均直接为 5; nsteps 与 R2a 相同 (lam prod 1e8 步=2000 ns, H_II prod 5e7 步=1000 ns; em 5e4; eq1 1e5; eq2 2e5)。itp 力场文件与 R2a 字节相同。

## 种子 (新; 与 R2a 的 10 个种子无重复)
builder 种子 = gen_seed (同 R2a: seed = 20271027 + cksum(名) % 100000; 只有 eq1 gen_vel=yes)。
| 体系 | gen_seed | builder_seed | 起点 | prod | 位置 |
|---|---|---|---|---|---|
| R2b_DOPE_lam_s3 | 20353468 | 20353468 | 片层 | 2000 ns | k03 槽A |
| R2b_DOPC_hii_s3 | 20290838 | 20290838 | H_II | 1000 ns | k03 槽B |
| R2b_DOPC_lam_s3 | 20357126 | 20357126 | 片层 | 2000 ns | k04 槽A |
| R2b_DOPE_hii_s3 | 20317996 | 20317996 | H_II | 1000 ns | k04 槽B |

## 时间 (全是估算, 非实测)
- 速率 (估算): 15000 ns/天/槽 = 调度当前估算; 8100 = R2a 包原假设 (非本体系实测)。eq+em 0.22 h/条 (R2a 估算沿用)。
- 15000: lam ≈ 3.2 h + 0.22 = 3.42 h; H_II ≈ 1.6 h + 0.22 = 1.82 h。两机各: 槽A lam 3.42 h ∥ 槽B H_II 1.82 h → 每机墙钟 ≈ 3.4 h, 槽时合计 ≈ 5.24 h (两机相同)。
- 8100: lam ≈ 6.15 h, H_II ≈ 3.18 h。
- 完整跑完的最晚发车 (估算): 15000 → lam 约 03:55 前 (JOBLIST: 04:00 发车 lam 仅被截 2%); 8100 → lam 约 01:15 前, 02:00 发车 lam 约 87%。表见 JOBLIST_R2b.tsv。
- 截止 2026-10-28 07:30 +0800 (SGT); 07:30 后须已 checkpoint 退出。-maxh = min(99, 余时-0.35 h); 余时 <0.6 h 的条目跳过 (SKIP_NO_TIME)。

## 发车 (每机一次; MPS 目录 $HOME/mps_R2b 必须不存在或为空; R2a 全部结束后)
  cd $HOME/R2b && sha256sum -c MANIFEST_sha256.txt
  pgrep -a gmx | wc -l                # 必须 0 (R2a 已全部结束); 非 0 则脚本也会 ABORT
  pgrep -a nvidia-cuda-mps            # 记录; 应无 R2a 遗留的 MPS (若有: 先报告, 不要自动杀)
  ls -A $HOME/mps_R2b 2>/dev/null     # 必须无输出
  DRY=1 MPSROOT=$HOME/mps_R2b bash scripts/R2b_machine.sh k03     # 干跑 (含 taup_check)
  MPSROOT=$HOME/mps_R2b nohup bash scripts/R2b_machine.sh k03 > R2b_k03.log 2>&1 &      # k04 机把 k03→k04
  (发车后) pgrep -a gmx | wc -l       # 预期 2 (每机 2 槽); 状态: $HOME/R2b/slots/<机>_{A,B}.tsv
不碰 GLM/端口/密钥; 脚本无 rm (docker run --rm 只清自己的容器); 幂等: out/.done_<步> / .failed_<步> 沿用 R2a, 失败须人工确认后才删标记重跑。

## 与 R2a 合并读 (在 box 上)
1. 把 R2a 与 R2b 的各 <name>/out/ (含 prod.xtc、prod.tpr) 放进同一目录 <D>/ (R2a_*/ 与 R2b_*/)。
2. cd /workspace/lnp-md/scan/R2b && /workspace/viz-venv/bin/python verdict_R2b.py --dir <D> --json R2b_merged.json
3. 输出: (a) 每条 verdict; (b) 仅 R2a_* 的预注册 n=2 门 (原样); (c) n=3 合并: 每臂 s1,s2,s3 状态与 "一致/不一致", 及 "DOPC 任一条 H_II" 与 DOPE_lam 出 H_II 的条数。n=3 不下统计结论。

## 未核 / 风险
1. 脚本只在 box 上 DRY/语法/守卫负面测试过, 未在 Spark+MPS+docker 上跑 (未核)。
2. grompp/EM 在 box gmx 2025.2-Debian 验; Spark 镜像是 gmx 2026.3, tau_p 规则在 box 上不强制 (故手算 TAUP_TABLE.tsv), 2026.3 行为未核。
3. 速率 15000/8100 均为估算; 实际 R2a 链结束时刻 (调度估 02:00–03:00) 决定 R2b 能否跑满, R2a 包自带 JOBLIST 里 MC3H 链排到约 07:30, 与该估计不一致 (未核)。
4. verdict_R2b.py 是 verdict_R2a.py 的派生, 仅用 --selftest (EM 后起点) 验过, 没有真实 prod 轨迹验过。
5. 4 个新起点的 em/eq 结构自检只做了 EM 后 (Fmax<100 收敛) 与 eq1 2000 步 CPU 烟测, 未跑完整 eq1/eq2。
