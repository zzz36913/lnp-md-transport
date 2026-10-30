R4N1 night1 VOID 文本记录 (2026-10-30 20:30:07 +0800); 只文本, 无 xtc/trr/tpr/gro/edr/cpt
VOID 判定: ledger/void/<b> 存在 或 最新 STATUS 含 RELAX_FAIL/VOID_*/SEL_NONE; 清单 VOID_LIST_all.tsv
relax/*/relax.log.tail50 = tail -n 50; select 不含 frames/ 与 selected.gro; 全部 STATUS 见 <run>/STATUS_ALL.tsv
check: sha256sum -c void_txt_1030_202953.tar.gz.sha256; tar -xzf; cd void_txt_1030_202953/k03; sha256sum -c MANIFEST_k03.sha256 (k04 同)
