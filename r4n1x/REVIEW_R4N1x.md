# REVIEW_R4N1x — 追加包 R4N1x 与 interim_pull.sh 独立审查 (2026-10-30 约 13:00–13:35 +0800, box)

审查人没有参与建包。只在 box 上做：没有上传，没有碰 Spark，没有对外发消息，也没有删除任何东西（作废件用 mv/cp 到 `_superseded_1030_R4N1x_v2/`）。
过程说明：在 /tmp/rx 执行过一次 `rm -rf u`（当时目录不存在，没有删掉任何东西）；此后没有再用 rm。

## 结论: **PASS-WITH-FIXES** (M 级 3 项已修，见 §2；另有 1 项须 K 拍板，见 §3)

最终包: `pkg/R4N1x.tar.gz` sha256 = `1bcc0a371425473d89d555faec572dd6f7f16d5c165b2384fa5b679d626d4992`（已写入 TARBALL_sha256_R4N1x.txt）
旧包 v2 (c1bf8ca1…0b30d) → `pkg/_superseded_1030_R4N1x_v2/`。主包 R4N1_full.tar.gz (1b632a5d…) 没动。

## 1 逐点审查 (改前 v2)
1. **科学**
   - 长盒: DOPC_hiiL Lz0 21.93 nm，比值 Lz0/2πr_w = 1.90；DOPE_hiiL 38.18 nm，比值 6.4。短盒 C1 的 DOPC 是 10.97 nm（0.95），DOPE 是 19.09 nm（3.2）。
   - **要点**：“约 22 nm”这个数，正好是 **h100** DOPC 的 2πr_w（2π×3.47 = 21.8 nm）。L 臂做的是 **h050**，它的阈值是 11.56 nm。21.93 对 22 只差 0.3%，在 h050 下无关紧要；最快增长波长按无黏 Rayleigh 估算约 16.6 nm（估算），落在短盒之外、长盒之内，所以这个检验在 h050 是有效的。
   - **但 L 臂不检验 h100**（比值 0.28，K1 原本指的正是 h100）。v2 里 CONSISTENT_RETAIN 写成“K1 不支持”，会把 h100 短盒也一并放行，属于过度解读 → 已修（M2）。
   - 判据在看数据前已写定（AMENDMENT_02 §3），verdict_Larm.py 只调用冻结函数；H_cmp 截断正确（floor(min(T_obs))，两边都截到 H_cmp，只有 H_cmp 算决定性）。阳性对照是 DOPE_hiiL（POS_OK/POS_FAIL）；POS_FAIL 时照报 SHORT_BOX_ARTIFACT 并注明，这样降级方向是保守的，可以接受。
   - 阴性对照：短盒 C1 是比较臂，不是严格意义上的阴性对照，这一点如实说明。n=3 严格，s4 只作替补。C4 的 4 体系 × 2 臂 build 齐全。
   - 建议：回传后描述 Lz(t)（semiiso 控压会漂移），已写进修订书，作为描述项，不进判据。
2. **不放宽闸门**: 阈值常量全部来自冻结的 verdict_R4_3day.py（sha 4fd49504… 校验 OK）；RETAIN≥0.80、LOST≤0.20、看末 100 ns、≥400 ns、≥99 帧都没改。尺子规则 1+2 对长盒只作描述，不替代 C1。|Δ|≥2 的内标规则原样（C4 用冻结 verdict 判）。mdp ×5、gate/、gatewrap、test_verdict.py 与主包逐字相同。
3. **同机规则**: 每格 3 主 + s4 替补同机；MC3H/MC3 同机且成对交替。k03 = DOPE 系 + DOPC_lam；k04 = DOPC 系 + DOPE_lam + 内标。DRY 列出 40 条且无重复（主链 12、补跑 18、替补 10）。
4. **与主包共存**（详见 §4）: 硬条件“本槽没有主包容器”能挡住大部分情况，但挡不住**主包闸门空档**：gate_py_container.sh 用的是随机名容器，主槽在 relax→闸门→prod 之间可能有几分钟没有带名容器。在这个空档里，GO（120 s 静默）和 MAIN_IDLE（1200 s）都可能放行，随后主包起 prod，就会同槽同 pin 双开。MAIN_DONE 本身还有一个隐患：主包若用 APPEND_TO 续跑，同一个日志里旧的“== slot end”会误放行 → 已修（M1）。
   - HALT：只认本包的 $OUT/HALT，不认主包的 → 紧急停车要两边都 touch。
   - 磁盘 ≥10 GiB 只在 launch 时查一次，不在接入时复查。
   - $HOME 规则沿用主包。DEADLINE 2026-10-31 07:30 (+0800)：-maxh 与 TRUNC 逻辑同主包（run_build 与主包相比只有 wait/MPS/guard/ONLY 的改动）。
5. **复跑**: MANIFEST 967 行全 OK；test_verdict 19/19；test_verdict_Larm 10/10（v3 为 11/11）。CHECK 中包相关项全 ok，FAIL 都来自 box 没有 gmx/docker/MDAnalysis。DRY 两机 rc=0，k03 12 条、k04 28 条，共 40 条，无重复。
6. **interim_pull.sh**（包外）
   - 只读：box 上实测，运行目录 size+mtime 快照前后一致。
   - 只打 DONE 条目（最新 attempt 的 STATUS=DONE）。SHA256_out 在 STATUS 之前写，所以先读到 DONE 时 SHA 已经在。
   - OUTDIR 在运行目录内会被拒绝（rc=2，且不会在里面建目录）；输出不覆盖；打包前后对比快照，有变化就改名 .VOID。
   - 6785 B 含中文，不能一段贴进 xterm → 已另做 `interim/xterm_paste_interim_pull.txt`：gzip+base64，分 0–4 段，每行 ≤1524 字符、纯 ASCII，最后一段做 sha 校验。box 上往返测试 OK。
   - 注意：OUTDIR 不要取成 `$HOME/R4N1/R4N1_run_<机>_*` 这种形式，否则追加包 WAIT_MAIN=auto 会认到 2 个主 run 目录而一直等。建议 `OUTDIR=$HOME/R4_interim`，并用 `nice -n19 ionice -c3` 跑。

## 2 已修 (M 级，v3)
- **M1 lib_R4N1x.sh L328**：MAIN_DONE 只认**最后一个**标记：槽日志里最后一个 `== slot start/end` 是 end，或 orchestrator.log 最后一个 `OUT=` 之后出现 machine done。box 单测 (/tmp/rx/v3h/t_done.sh) 全部符合预期（续跑后旧 end 不再放行）。
- **M2 AMENDMENT_02 + verdict_Larm.py**
  - CONSISTENT_RETAIN 改为“在 h050、Lz0≈22 nm、H_cmp 内未见盒长效应；不排除更长波长或更慢的失稳，不覆盖 h100”。
  - 新增 §3.3 覆盖范围：h100 短盒的 H_II RETAIN 一律标注“盒长未检验”，不因 L 臂结果被放行（JSON 字段 not_covered_by_Larm，md 同步提示）。这只是标注，不改任何 RULER，判据和阈值都不变。
  - 新增测试 test_scope_h100_not_covered。
- **M3 AMENDMENT_02 如实性**
  - 12:42/12:44 的规格改记为“主控转述”；裁剪序注明“不是 K 原话”。
  - 22 nm（h100 的 2πr）与 h050 的 2πr=11.56 两套标准并列写明。
  - 写明与 K“每格四条同跑”的冲突须由 K 拍板。
- README §3：写入“今晚只用 MAIN_DONE”的建议和闸门空档风险；测试数 10→11。
- 同步到包外源：N1x/{lib_R4N1x.sh, verdict_Larm.py, README_R4N1x.md, tests/test_verdict_Larm.py} 与 D2/PRE_REG_AMENDMENT_R4N1_02.md。改前副本放在 `_superseded_1030_R4N1x_v2/{N1x_src,D2_src}`。
- 包内 FROZEN 的 AMENDMENT_02 行更新为 b4942d43…0aa8；MANIFEST 已重建（967 行）。D2 根目录的 FROZEN_sha256.txt 原本就没有 AMENDMENT_02 这一行，没有改。

## R2 第二轮自查 (v3)
- tar 解包后与 pkg/R4N1x 完全一致；MANIFEST 全 OK；FROZEN sha256sum -c 全 OK；冻结 verdict 仍是 4fd49504…。
- test_verdict 19/19；test_verdict_Larm 11/11；bash -n 两个脚本均 OK。
- CHECK k03/k04：包相关项全 ok（含 MANIFEST、WAIT_MAIN=auto 认到主 run 目录、gmx/MPS 归属、磁盘）；FAIL 仍只来自 box 环境。DRY 两机 rc=0，40 条无重复。
- 与 v2 的差异只有 7 个文件：FROZEN、MANIFEST、AMEND02、README、lib、verdict_Larm、test_verdict_Larm。tools/ref_main 与主包逐字一致。D2 里找不到对旧 sha（c1bf8ca1/5bdab12f）的引用。
- 这些修复不改判据阈值、读法分支或排程；lib 只改了一行判定。

## 3 须 K 拍板 (不改包)
- K 的规矩是“每格四条同跑，禁止只跑 DOPE+DOPC”。今晚 C4 主链只有 DOPE_hii + DOPC_hii，MC3H/MC3 在补跑队列里，多半跑不到（估算）。PLAN v2 把规矩解释为“每晚至少一个四体系完整的格”，这是主控的解释，不是 K 的原话。
  - K 若按字面执行：今晚用 `ONLY=Larm`（L 臂是方法检验，不是配方格），C4 整格推到第 2 晚；代价是每槽约空出 3–4 h（估算）。
  - K 若接受 PLAN 的解释：按现包全跑。

## 4 今晚推荐接入
- 只用 MAIN_DONE（主包崩时再加 MAIN_GONE）：`WAIT_IDLE_S=86400`，不放 GO，不设 WAIT_MAIN=none，START_AT 不设（或只作下限）。
- 主包发车并稳定后（约 15:00），在白天就起追加包，让它挂起等待。这样 launch_guard 在 Spark 上第一次做 cgroup/environ 归属识别时，即使失败也还有时间排查。
- 已知代价：MAIN_DONE 接入时，主包另一槽通常还在跑 MPS，本包这条不用 MPS，两者分时片共卡，直到主包整机结束（估算 10–15 min）。若 GPU 是 EXCLUSIVE_PROCESS，本包这条会起不来（rc 会记录下来）。

## 5 遗留风险
- cgroup/environ/docker 名字格式、MPS 与非 MPS 能否共卡，都没在 Spark 上实测。
- 速率与可用机时都是估算；主包若动用替补，本包接入会推迟，补跑队列可能一条也跑不到。
- C4 今晚多半记 RULER_NOT_EVALUABLE。
- DOPC 长盒只有约 1.9 个 2πr，最快增长模勉强放得下；400 ns 内看不到失稳，不等于不会失稳。
- 磁盘只在 launch 时查（建议发车时可用 ≥20 GiB，估算）。
- HALT 两边分开，要各放一个。
- 主包若在另一个新 run 目录重启（不是 APPEND_TO），auto 会认到 2 个目录而一直等（方向安全，但会空等）；显式指定 WAIT_MAIN 时，旧目录又会误报 MAIN_DONE → 主包一旦重启，必须人工重设追加包。
