# 自检汇总 · R4N3 包 (2026-11-01, 北京时间 UTC+8, 全部在 box 上本地跑, 没有上传)
| 项 | 结果 | 文件 |
|---|---|---|
| launch_guard CHECK=1 MODE=local k03 / k04 (GATE_PY=venv_gate, MDAnalysis 2.7.0) | **ALL OK / ALL OK** (含 MANIFEST、H_II 正自检、已知桥连帧负自检、trjconv、两槽 grompp) | CHECK_local_k03_v2.txt, CHECK_local_k04_v2.txt |
| 旧版 CHECK (v1, 未写 MANIFEST、GATE_PY 缺依赖) | 3 项 FAIL, 已由 v2 消除 (原因: MANIFEST 未生成; 系统 python 没 MDAnalysis) | CHECK_local_k0x.txt |
| 20 个 build grompp (relax+prod 各一, 箱子/拓扑/mdp) | 40/40 rc=0, 0 warning; prod 1200 ns 重 grompp 20/20, dump 确认 nsteps 6e7、Semiisotropic、tau-p 4 | pkg/R4N3/proof/grompp_box.tsv |
| C4a 阴性 (各向异性 C-rescale) | rc=1, 按预期拒绝 | pkg/R4N3/proof/NEG_C4a_aniso.txt |
| verdict_N3_wrap 单测 | 10/10 PASS; 真实 I/O 冒烟 rc=0 (第 1 晚 DOPC_lam s1–s3 NO_EVENT) | test_verdict_N3_wrap.txt |
| 冻结 verdict_R4_3day.py sha | 未变 (测试 T10) | — |
| runner ext/MPS 测试 (R4N2 原测) | ALL PASS (ext 测需叠旧 fixture, 只是测试数据依赖) | test_ext_n2_overlay.txt, test_mps_n2.txt |
| xfer_small mock (19 DONE + 1 RUNNING) | 4.1 MB tar.gz, RUNNING 未碰 | xfer_small_mock.txt |
| PEG 闸门草案自检 | ALL PASS; N3 (中性 MC3 历史 272 帧) 0 帧放行 | ../peg_timing/peg_gate_selftest.txt |
| MANIFEST_sha256.txt | 918 文件, sha256sum -c 全 OK | pkg/R4N3/MANIFEST_sha256.txt |
| 包 | R4N3_pkg.tar.gz + .sha256 (D3/) | — |
没有做的: 真机 gmx/容器/MPS/磁盘检查 (MODE=local 跳过, 要在 k03/k04 上 CHECK=1 才算数); 任何 MD 实跑。
