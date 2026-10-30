R4N1 night1 interim k03: interim_2100_1030_200510.tar (251504640 B) split -b 16M
restore: sha256sum -c SHA256_parts.txt; cat interim_2100_1030_200510.tar.p16_* > interim_2100_1030_200510.tar; sha256sum -c FULL_TAR.sha256; (或 sha256sum -c interim_2100_1030_200510.tar.sha256 同时核 files/builds.tsv)
then: tar -xf interim_2100_1030_200510.tar; 见 interim_pull.sh 头注释
