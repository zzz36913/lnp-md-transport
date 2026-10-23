# HA-XG2：HA2 pre/post 在可滴定水里的 EM→NVT→NPT 稳定性预跑（方案 B 交叉 LJ）

目的：在正式 pH 扫描之前，确认 HA2 pre（3HMG，4983 珠，qtot −24）和 post（1HTM，1211 珠，qtot −25）在 G2020 可滴定 Martini 水（WNA = WN + DN，H+ = POS）里，配上方案 B 补丁（dd/22），pH 5.00 和 7.00 下能稳定跑完 EM → NVT → NPT。

## 依赖
- 先完成 HA-ENV-01。需要 ~/ha_env/ha_common.sh、compat/、systems/{pre,post}/martini.itp（由 setup 生成）和 venv。
- 本包放在 ~/ha_env/xg2/。HA_ENV 默认取本目录的上一级。

## 运行
    setsid bash ~/ha_env/xg2/run_xg2.sh </dev/null >/dev/null 2>&1 &
结果：run/XG2_SUMMARY.txt，末行为 `XG2 OVERALL PASS|FAIL|YIELD|REFUSED`；每个组合另有 run/<sys>_pH<x>/RESULT.txt。
默认参数：SYSTEMS="pre post"，PHS="5.00 7.00"，NT=6，ELEC=rf，NVT_STEPS=100000（1 ns），NPT_STEPS=500000（5 ns），REF_T=310。
重跑会跳过已经 PASS 的组合，mdrun 从 -cpi 断点续跑。

## 让路（不抢 J005 GPU）
- 启动前：有其他 gmx mdrun，或 GPU 利用率 >10%，就拒绝启动（REFUSED）。
- 运行中：每 60 s 看一次 mdrun 数，>1 就 docker stop 本容器，写 .yield，末行 YIELD。下次重跑从断点继续。
- 不碰 GLM / 8888 / 18888 / key，不用 sudo，不做 docker 镜像操作。k04 无外网，只能从 k03 scp。

## 流程与门槛（门槛为拍定值）
1. `sha256sum -c SHA256SUMS`。
2. 力场：xg0_gen_cross.py 重新生成方案 B 补丁，要和包内 patch/ 逐字节一致；再 compat_merge.py + xg_apply.py 合并，merged 的 sha 要和 box 一致（写死在 run_xg2.sh 的 MSHA 里）。
   - pre 的补丁比 post 多 SP2a：23 类型 / 69 对。WNT×SP2a = M3 W–SP2a（0.425 nm / 3.83 kJ/mol），POS/DW×SP2a = 0。
3. grompp：EM/NVT/NPT 都要 0 WARNING，且 qtot = 0。体系只用 NA（Q1p）中和，不加盐。
4. xg1_check：读 EM tpr 的 dump，核对实际生效的 LJ。不通过就不跑 mdrun。
5. EM 走 CPU，Fmax < 1000。NVT（posres，sd，10 fs，310 K）和 NPT（无 posres，C-rescale 各向同性，τ_p 3）跑在 GPU 上，要求 0 LINCS 警告、0 nan。
6. NPT 后半段平均 T 在 310 ± 3 K 以内；密度和 Epot 用 60–80% 窗口对比 80–100% 窗口，漂移 < 1%；BB RMSD 单帧跳变 < 0.3 nm，最大值 < 1.5 nm。

## 来源与偏离
- 静电：RF，eps_r 6，rc 1.1。Chiariello 2023 SI 写明 eps_r 6；滴定模拟用 RF 是推断；ha2box 本身也是 RF。
  - 不用 PME：box 实测 PME 下 grompp 报 ERROR，原因是 GōMartini 的 BB–BB 排除对距离达到 1.168 nm，超过 rc 1.1。ELEC=pme 只作对照，预计 grompp 不过。
- 积分器 sd、10 fs、lincs 8/2，按教程 mdp 设置。
- 压浴：Chiariello 用 PR 各向同性 τ_p 3。本包改用 C-rescale 各向同性 τ_p 3，因为起始密度没平衡过。compressibility 3e-4，同 ha2box。
  - Chiariello 提醒半各向同性压浴会让盒子变形，所以这里用各向同性。
- 温度 310 K，跟 HA 环境一致（Chiariello 用 298 K）。
- 体系由 box 建好（build_xg2_systems.py，seed 20261023）。机器上不重建，只核对 sha。
  - pre：ha2box 去掉多余离子后，W → WNA + H+。
  - post：1HTM 加 2 nm 盒，用教程标准水溶剂化，在离蛋白 ≥1.0 nm 处放 25 个 NA。

## box 冒烟（2026-10-23 17:49–18:01 SGT，gmx 2025.2，CPU 8 核，MODE=local，NVT 2000 步 / NPT 20000 步）
- 四个组合全部 PASS：grompp 0 警告、qtot 0、XG1 PASS，EM Fmax 约 90，nvt/npt 0 LINCS 警告、0 nan。
- 短跑里 NPT 体积在 200 ps 内收缩 4–8%。正式的 5 ns 由漂移门槛把关。
- EM 早期有 LINCS 警告（steep 大步长，最终 Fmax 收敛），不计入门槛。
- box CPU 吞吐：post 约 500–550 ns/day，pre 约 230–270 ns/day。

## 估算耗时
24 ns（4 × 6 ns）。单 GPU 槽按 330–800 ns/day（估算，dd/21）计，约 0.7–1.7 h；加上 EM 和分析，合计约 1–3 GPU·h（估算）。

## 回写
- XG2_SUMMARY.txt 全文和 4 份 RESULT.txt；
- 每段 ns/day；
- FETCH.txt 末行；
- 有 FAIL 时附对应 *.out 或 log 的末 30 行。
