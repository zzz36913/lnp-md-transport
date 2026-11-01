R4N2v4 (rv4) night2 final k04 (packed: 2026-11-01 12:51:00 +0800 n=194 parts=74 sha=aae1a700513704d67c0392b77016a367a925f1e943b29864c5ea15ab75793f6a runs=R4N2v)
check: sha256sum -c SHA256_files_k04.txt
restore: cat R4N2v4_n2_k04.tar.c16_* > R4N2v4_n2_k04.tar; sha256sum -c full_k04.sha; mkdir r; tar -xf R4N2v4_n2_k04.tar -C r; cd r; sha256sum -c ../SHA256_out_k04.txt
m_<run>_*: plain copies of THROUGHPUT/SUMMARY/ALL_RECORDS/RUN_META/x_mps_events (also inside tar); ext*/attempt_*/ext.part*.{xtc,log,edr,gro} included; no trr/cpt/src.*
