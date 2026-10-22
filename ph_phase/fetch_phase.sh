#!/usr/bin/env bash
# k03 拉取 ph_phase 全套并逐文件 sha256 校验。用法: bash fetch_phase.sh [tag]   -> 目标 ~/ph_phase，结果 ~/ph_phase/FETCH.txt
TAG=${1:-j004-v2}; R=zzz36913/lnp-md-transport; D=$HOME/ph_phase
mkdir -p "$D/ff" "$D/mdp"; cd "$D" || exit 1; : > FETCH.txt
cat > SHA256SUMS <<'SUMS'
df6a199bdde085bd7000e1a48089efd53df140fecbec9f015c4e6b1d55167cf7  ./build_phase.sh
c0fb90fdda5b90e73285016857536f9b544a0a48909e1557510752bd134cdad3  ./ff/MC3.itp
ebeedf2430a489dceee47d4bf30a8ae9c21ef5b73f7f25d0ee0ae1a88823b9a4  ./ff/MC3H.itp
497c06ba81b47e28b95125e9bc56272f77b15f3df9acd53cc7e22339a0cc2bb2  ./ff/martini_v3.0.0_phospholipids_PE_v2.itp
98f868d024a4f4cf4c7d83508f171bac5c2d47a79085239a894e30ea21cc4351  ./ff/martini_v3.0.0_phospholipids_PI_v2.itp
b6af8cefb4bf4e91bea5caec37bac23b2fd6b2a334603902cce2915950fedd55  ./ff/martini_v3.0.0_phospholipids_PS_v2.itp
5a93fec7afe3ee1083c24a0574501962b93a333e7c58f224c075bc80fc1b807f  ./ff/mol_CHOL.gro
e7c12d2138c097136fdbeda9325312ebb45386f7d0dfae616df55e5e83274f66  ./ff/mol_CL.gro
df2bc755bb7cf4812ab721fed153f9ac6941cb34ee6d9089890419fc9108b693  ./ff/mol_DOPC.gro
b7a65ce38a27e24b576b91b888b0091a28776f7bb8b43cc449b0d8c471100e5a  ./ff/mol_DOPE.gro
053d65ae6e50674f9b2ab6eeb7c33338e5e9fd719539e140baec4bd3ad18f4df  ./ff/mol_DOPS.gro
682e0a78d0455aed7347919f4a0745929a6fc5004e240deee149ac4951f1e595  ./ff/mol_DSPC.gro
533c7218de98eb7b99bdd5a8ce97ff5a01e16719d64063cc82bb83579791640b  ./ff/mol_MC3.gro
1304af14cf828b483024bc54cbd4766f785c6a644b93d4cf76fe7a039461f23e  ./ff/mol_MC3H.gro
30fe908dd2dfb5dc7e2b23efdbf824b7befbe341784aa3a8228f957182d511a1  ./ff/mol_NA.gro
4b18d39d0ba2b32526719d7dc5f30dd23e668e04f877b64d084ddc855a9b4c17  ./ff/mol_POPC.gro
c0e5c398e9845311b9cf9f0b14fc15742251c2a0ef24e4896daf5b5e1d6d463d  ./ff/mol_POPE.gro
e676c7da0d972667df616982325ec8d1c9d0c26fa32f3a9340f86575c86b1c38  ./ff/mol_POPI.gro
053e5a6e35ae8bbaafe7193efc4c0d8865be9e0daf8dd23002a58bc087450dc7  ./ff/mol_POPS.gro
9678b64da7fe0c97bca622b4d9bedf58e8a8261467714f7f810f8df757772b9c  ./ff/mol_W.gro
ab33d25ae667c3941bb5eb26044e4ead01e23fc6d99064623f774ace98075eaf  ./mdp/em.mdp
10369201d2a25f125776f7647bf65624d1498dd752ef8954d8d0c8ab8c0a4f53  ./mdp/eq1.mdp
fc3dd313c13704ef4abb7162435201f1c01ae06f46f5737de89cc64cfc41948f  ./mdp/eq2.mdp
33b24bb5202d5be5c6e14dc1e2fdab5386f60efd2f5dc4946041b183a1511116  ./mdp/prod.mdp
40c398a22d940fe84b7c71f48a8486e5578fb422d5aea0b9b93c28c64543452b  ./phase_common.sh
b99f4ee3a3c9fffecb1bc3c2c38ab25180e5313689baa4fafbd9db96634ac156  ./phase_counts.py
d953a39ec5e157fa26f06f4d1448a6eb9232b6f54973bab6013d010b004efd5b  ./phase_sq.py
b65ea64a37d823d00a4eb8c689d17e48cb6d70f55c46057e9618b420e5222ddd  ./run_phase.sh
78139a34f748b985fc7d023247a8299df71bcefbac8898007e4417e02ba357a4  ./topol.template.top
SUMS
fail=0
while read -r sha f; do f=${f#./}
  if [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sha" ]; then echo "HAVE $f" >> FETCH.txt; continue; fi
  got=""
  for u in "https://fastly.jsdelivr.net/gh/$R@$TAG/ph_phase/$f" "https://ghproxy.net/https://raw.githubusercontent.com/$R/$TAG/ph_phase/$f" \
           "https://cdn.jsdelivr.net/gh/$R@$TAG/ph_phase/$f" "https://gcore.jsdelivr.net/gh/$R@$TAG/ph_phase/$f" "https://ghfast.top/https://raw.githubusercontent.com/$R/$TAG/ph_phase/$f"; do
    curl -sS -L --connect-timeout 15 --max-time 120 -o "$f" "$u" 2>/dev/null
    got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
    [ "$got" = "$sha" ] && { echo "OK $f $(echo "$u" | cut -d/ -f3)" >> FETCH.txt; break; }
  done
  [ "$got" = "$sha" ] || { echo "FAIL $f got=$got" >> FETCH.txt; fail=1; }
done < SHA256SUMS
chmod +x *.sh *.py 2>/dev/null
if [ $fail = 0 ] && sha256sum -c --quiet SHA256SUMS; then echo "FETCH ALL OK ($(wc -l < SHA256SUMS) files)" | tee -a FETCH.txt; else echo "FETCH FAILED (见 ~/ph_phase/FETCH.txt)" | tee -a FETCH.txt; exit 1; fi
