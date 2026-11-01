R4N2_rv3 night2 final k03 (packed: 2026-11-01 12:24:30 +0800 n=1174 parts=1 sha=5dbf8d11f0e4ec3fae6dd1996652bf5d95e6cab7bd6616ba6839bafc9b12164b runs=R4N2_)
check: sha256sum -c SHA256_files_k03.txt
restore: cat R4N2_n2_k03.tar.c16_* > R4N2_n2_k03.tar; sha256sum -c full_k03.sha; mkdir r; tar -xf R4N2_n2_k03.tar -C r; cd r; sha256sum -c ../SHA256_out_k03.txt
m_<run>_*: plain copies of THROUGHPUT/SUMMARY/ALL_RECORDS/RUN_META/x_mps_events (also inside tar); no trr/cpt/edr/gro
