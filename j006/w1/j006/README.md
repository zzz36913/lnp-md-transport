# J006 波 1 包（PNAS Philipp 2023 MC3:CHOL 3:1 H_II × MC3H 比例 α 扫描）
- 文档: box /workspace/lnp-md/dd/26_pnas_mc3_alpha_scan_prereg.md（物理再核、对照、预期表、波 2 决策树）。
- 体系: H<α×100>w<nW>_HII，7 条（k03 3 槽: H000w12 H050w12 H100w12；k04 4 槽: H025w12 H075w12 H100w07 H000w07）。每槽 NT_SLOT=5（-ntomp 5）；k03 另有 1 槽被 T100_rep2 填充占用(~/ph_j006_fill)。
- 发车（每台）: HT=k03|k04 bash ~/ph_phase_j006/j006/start_wave1.sh
- 波 2: 22:30 判读后写 ~/ph_phase_j006/WAVE2_BRANCH（分支名，如 EXT/…）；不写则 25 min 后自动 EXT。
- 收尾导出: bash ~/ph_phase_j006/j006/close_j006.sh（MID=1 为不停机中期快照）。
- 重现烟测(box CPU): FF=<itp 目录> WORK=<目录> bash j006/smoke_box.sh queue_k03.txt queue_k04.txt
