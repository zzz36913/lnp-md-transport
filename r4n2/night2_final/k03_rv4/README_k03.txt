R4N2v4 (rv4) night2 final k03 (packed: 2026-11-01 12:49:02 +0800 n=194 parts=56 sha=e2d41831f8f3b896159554c7375bef123170dac31047d24e4113160cc7b4cb20 runs=R4N2v)
check: sha256sum -c SHA256_files_k03.txt
restore: cat R4N2v4_n2_k03.tar.c16_* > R4N2v4_n2_k03.tar; sha256sum -c full_k03.sha; mkdir r; tar -xf R4N2v4_n2_k03.tar -C r; cd r; sha256sum -c ../SHA256_out_k03.txt
m_<run>_*: plain copies of THROUGHPUT/SUMMARY/ALL_RECORDS/RUN_META/x_mps_events (also inside tar); ext*/attempt_*/ext.part*.{xtc,log,edr,gro} included; no trr/cpt/src.*
