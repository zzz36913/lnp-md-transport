R4N1 night1 interim k04: interim_2100_1030_200657.tar (315217920 B) split -b 16M
restore: sha256sum -c SHA256_parts.txt; cat interim_2100_1030_200657.tar.p16_* > interim_2100_1030_200657.tar; sha256sum -c FULL_TAR.sha256; (或 sha256sum -c interim_2100_1030_200657.tar.sha256 同时核 files/builds.tsv)
then: tar -xf interim_2100_1030_200657.tar; 见 interim_pull.sh 头注释
