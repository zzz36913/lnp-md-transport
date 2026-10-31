# R4N2 rv4 — k04 continuation package (package b, 3SYS only)

- R4N2v4_k04.tar.gz sha256: c9e73baeaa48f1f0cc8e9a2178e66431c864c8651d5aea84a081f57dae5df61a
- Verify: `sha256sum -c R4N2v4_k04.tar.gz.sha256`
- Incremental: on k04 only, extract onto the rv3 base with `tar -C ~/R4N2_pkg -k -xzf R4N2v4_k04.tar.gz` (must exit 0, no "File exists"), then check MANIFEST_sha256.txt, FROZEN_sha256.txt and MANIFEST_rv4_sha256.txt.
- k04 only (queue chains_rv4/extq_k04.txt: DOPC C4 T350 + C3 T320 hii, 400 ns -> 1.2 µs prereg -> 2/3 µs explore). K_BRANCH=3SYS; waits for rv3 k04 (lam) to finish.
- Separate from the k03 package in ../k03/ (do not mix the two in one tree).
- REVIEW_rv4_k04.md = independent review (PASS). Do not launch without the LNP MD launch order (CHECK=1 -> DRY=1 -> real run).
