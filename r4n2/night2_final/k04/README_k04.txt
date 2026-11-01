R4N2_rv3 night2 final k04 (packed: 2026-11-01 12:26:26 +0800 n=1479 parts=5 sha=93c25771fda29581ed728ad88cc3f1d145454843fa8078f03f99dd59488e15c1 runs=R4N2_)
check: sha256sum -c SHA256_files_k04.txt
restore: cat R4N2_n2_k04.tar.c16_* > R4N2_n2_k04.tar; sha256sum -c full_k04.sha; mkdir r; tar -xf R4N2_n2_k04.tar -C r; cd r; sha256sum -c ../SHA256_out_k04.txt
m_<run>_*: plain copies of THROUGHPUT/SUMMARY/ALL_RECORDS/RUN_META/x_mps_events (also inside tar); no trr/cpt/edr/gro
