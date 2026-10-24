#!/usr/bin/env bash
# J006 波 1：k03 一条命令 = 拉取 ph_phase_j006 全套 + 逐文件 sha256 校验 + scp 到 k04 + k04 侧 sha256sum -c。
# 用法: bash fetch_j006_wave1.sh [tag]   (默认 j006-wave1-v1)    结果 ~/ph_phase_j006/FETCH.txt，末行 FETCH J006 OK / SUMS_OK k04
TAG=${1:-j006-wave1-v1}; R=zzz36913/lnp-md-transport; D=${PH_DIR:-$HOME/ph_phase_j006}; K4=${K4:-k04@10.0.0.2}
mkdir -p "$D"; cd "$D" || exit 1; : > FETCH.txt
cat > SHA256SUMS <<'SUMS'
589544c200c74696014962248de57211d4f695472c2b4be4ab5476de8502ee85  ./build_phase.sh
b5553ebc2ad717e196089cee92402b621c8870d8f227faae1cae5ce2c6ef3cb3  ./build_preasm.py
557280951c1cd18fd8d8b18e75f72d9c15c5177963538a132d57d09a57ba0de4  ./fetch_j005.sh
b48acf0449ee3470081938319eb7a0c4ddeb4aab22cd2987cfa10d08d07239fb  ./fetch_phase.sh
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
82e85acb5dab4acc9eb8b5fbc0938035617171b1b63fce5a9ada2480f13aeabc  ./j005/close_j005.sh
b5940a839ac57d7e30f0582991f8b8aab6cd29f86b527dfa15123fdac5190921  ./j005/up_j005.sh
b7eaf14b628d6474a0b378eaa18e5fd01456d5956fb39ce8aebe45d37f52c340  ./j006/README.md
efd293455125f541e81f85d919e1a88dfb41a63b8cf40e6a6d9c12c6b5af52bc  ./j006/close_j006.sh
a6f8838356766637ba0afe9acc9014f4811e6a6a4fd2fff62e4a475ef838d78e  ./j006/smoke_box.sh
3cc41e3f2a5e84889166f0dcf5a17740708080203cc5b0851df5cd79f88ecf7c  ./j006/start_wave1.sh
1522f9c7349e3e3b0fa7231941fb09e32741c993cd9763e16aa0330af5b9c152  ./j006/up_j006.sh
9532f8ecf15ef51edf3cf9f5d042fdaadad2a017151b80fb1013889d380e9f0a  ./j006/wave2_hook.sh
ac2cfc8db160f3e6e43d2dc06592354e3231c386e3c5d8966dea822bb5c4aec0  ./j006/wt_for_nw.py
ab33d25ae667c3941bb5eb26044e4ead01e23fc6d99064623f774ace98075eaf  ./mdp/em.mdp
8d671a5e9962181023df6890e73a04f6ac5770e6c15dfd94c849a71c46945278  ./mdp/eq1.mdp
71d3ba0b34caa252de452d6033c27a4e9688af96698984bc651f35d5574c3e66  ./mdp/eq2.mdp
3e619df39052d839ca45a74d7595581b19c3c33aace717d156e06a86c387c20c  ./mdp/prod.mdp
dbde1c9785d82de3ee146d662be112bb9ad3c1b110c16559d4f445784ba45d96  ./phase_common.sh
b99f4ee3a3c9fffecb1bc3c2c38ab25180e5313689baa4fafbd9db96634ac156  ./phase_counts.py
d30c4a0a60f630320d4f0833fa5cc622bb37a1eb158a17fb9fb8314f77973764  ./phase_sq.py
b9a93111bf6bae45381a56d6340b7c3f47481c4e7e96b63c7e4d60c03670ec33  ./queue_k03.txt
a10ebc3106490586afe1513ba6ac712a17124b43ec110c05add53a4e884b0c0c  ./queue_k04.txt
a23c58d16e67594f4b2d95345131c531906fbef1b7ebd30bf72eb6c7f1cce92b  ./run_phase.sh
78139a34f748b985fc7d023247a8299df71bcefbac8898007e4417e02ba357a4  ./topol.template.top
14cc741f2ef106eec6d0ed429f5359f799c6d051dc579a76f291feb0c84078ea  ./w2/queue_A01_k03.txt
1b4de6f8d291bb70184d9ac9dfe5d5a2da9d49d7fbd31f99562ac12dbeb8606a  ./w2/queue_A01_k04.txt
e9454b2f9c5aa31ff2c189f6c06f452e976a2d2e3bb999092d7eac8edca53549  ./w2/queue_A12_k03.txt
7223580d4a18542a3bf3216b699f3c97909a45eb0269019a4dceeeef13d6db5c  ./w2/queue_A12_k04.txt
3b05cd40909211a4d2585174028eb2a5539aa42e57024021d888e2c1bd4ed36f  ./w2/queue_A23_k03.txt
ee0ae71c30a9f6407a9d11fee5f99f2494947567254e4375151697783ddfbebb  ./w2/queue_A23_k04.txt
9ef63abf483839980330ae20a5fb5eb9c5693bfc7bedd1b3b5daa682f1c3b3db  ./w2/queue_A34_k03.txt
e95f816cd1d4ba559e23b499bf8d38ee2e50de25bd5f6913d4f84cef23157038  ./w2/queue_A34_k04.txt
f09c9b6d1a0ad6209db9bda5d534d05279a8e51fa46c3a7cc57f4d6c3c24a4ae  ./w2/queue_ALLMELT_k03.txt
4aa281633e29a0db7ab811537d0474a93a352289f6439cace5c90fdf903589d0  ./w2/queue_ALLMELT_k04.txt
8b69708a7d23c2f8e84355f60a9d3c697deb1f8f4f8321623bfe29f144d70c98  ./w2/queue_ALLSURV_k03.txt
a9c7da9026543bb4aa64d76d76b927964ea85cd4523e8b37a8d25e1dc3c1f639  ./w2/queue_ALLSURV_k04.txt
b9a93111bf6bae45381a56d6340b7c3f47481c4e7e96b63c7e4d60c03670ec33  ./w2/queue_EXT_k03.txt
a10ebc3106490586afe1513ba6ac712a17124b43ec110c05add53a4e884b0c0c  ./w2/queue_EXT_k04.txt
SUMS
fail=0
while read -r sha f; do f=${f#./}; mkdir -p "$(dirname "$f")"
  if [ -f "$f" ] && [ "$(sha256sum "$f" | cut -d' ' -f1)" = "$sha" ]; then echo "HAVE $f" >> FETCH.txt; continue; fi
  got=""
  for u in "https://ghproxy.net/https://raw.githubusercontent.com/$R/$TAG/j006/w1/$f" "https://ghfast.top/https://raw.githubusercontent.com/$R/$TAG/j006/w1/$f" \
           "https://fastly.jsdelivr.net/gh/$R@$TAG/j006/w1/$f" "https://cdn.jsdelivr.net/gh/$R@$TAG/j006/w1/$f" "https://gcore.jsdelivr.net/gh/$R@$TAG/j006/w1/$f" \
           "https://raw.githubusercontent.com/$R/$TAG/j006/w1/$f"; do
    curl -sS -L --connect-timeout 15 --max-time 120 -o "$f" "$u" 2>/dev/null
    got=$(sha256sum "$f" 2>/dev/null | cut -d' ' -f1)
    [ "$got" = "$sha" ] && { echo "OK $f $(echo "$u" | cut -d/ -f3)" >> FETCH.txt; break; }
  done
  [ "$got" = "$sha" ] || { echo "FAIL $f got=$got" >> FETCH.txt; fail=1; }
done < SHA256SUMS
chmod +x *.sh *.py j006/*.sh 2>/dev/null
if [ $fail = 0 ] && sha256sum -c --quiet SHA256SUMS; then echo "FETCH J006 OK ($(wc -l < SHA256SUMS) files) tag=$TAG" | tee -a FETCH.txt
else echo "FETCH J006 FAILED (见 $D/FETCH.txt)" | tee -a FETCH.txt; exit 1; fi
# 同步到 k04（k04 只能从 k03 ssh 过去）并校验
if [ "${NO_K4:-0}" != 1 ]; then
  ssh -o BatchMode=yes $K4 "mkdir -p ph_phase_j006" && tar -C "$D" -cf - . | ssh -o BatchMode=yes $K4 "tar -C ph_phase_j006 -xf -" \
   && ssh -o BatchMode=yes $K4 "cd ph_phase_j006 && sha256sum -c --quiet SHA256SUMS && echo SUMS_OK k04 \$(hostname) \$(date '+%F %T')" | tee -a FETCH.txt \
   || { echo "K4 SYNC FAILED" | tee -a FETCH.txt; exit 2; }
fi
