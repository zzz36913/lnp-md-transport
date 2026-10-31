# R4N2 rv4 — k03 continuation package (package a, 3SYS only)

- R4N2v4_k03.tar.gz sha256: ba47048bc285e9581de3568c77204342d51d7c89fa888d65cf0e62cf5e1e00f4
- Verify: `sha256sum -c R4N2v4_k03.tar.gz.sha256`
- Incremental: extract onto the rv3 base with `tar -C ~/R4N2_pkg -k -xzf R4N2v4_k03.tar.gz`, then check MANIFEST_sha256.txt, FROZEN_sha256.txt and MANIFEST_rv4_sha256.txt.
- k03 only (queue chains_rv4/extq_k03.txt: DOPE C4 T350 + C3 T320 hii, 400 ns -> 1.2 µs prereg -> 2/3 µs explore). K_BRANCH=3SYS; 4SYS is rejected.
- REVIEW_rv4_k03.md = independent review (PASS). Do not launch without the LNP MD launch order (CHECK=1 -> DRY=1 -> real run).
