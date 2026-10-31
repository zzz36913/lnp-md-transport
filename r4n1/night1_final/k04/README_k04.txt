R4N1 night1 final k04 (packed: 2026-10-31 06:27:31 +0800 / 2026-10-31 06:27:32 +0800)
check: sha256sum -c SHA256_files_k04.txt
restore (P=main|x): cd $P; cat R4N1_n1_${P}_k04.tar.c16_* > R4N1_n1_${P}_k04.tar; sha256sum -c full_${P}_k04.sha; mkdir r; tar -xf R4N1_n1_${P}_k04.tar -C r; cd r; sha256sum -c ../SHA256_out_${P}_k04.txt
no trr/cpt/edr/gro
