#!/usr/bin/env bash
# HA-XG2 稳定性闸门（dd/22 §5）：HA_pre(3HMG, qtot -24) 与 HA_post(1HTM, qtot -25) 各放进可滴定水（WNA + H+，NA 中和），
# 方案 B 交叉 LJ 补丁，pH 5.00 / 7.00 各一条：EM → NVT 1 ns（sd 10 fs，POSRES）→ NPT 5 ns（sd，C-rescale 各向同性 τp 3）。
# 默认静电 RF eps_r 6 rc 1.1（box 实测：PME 下 grompp 报 ERROR——Gō 模型 BB–BB 排除对距离 1.168 nm > rc 1.1；RF 与 ha2box、Chiariello 推断设置一致）。ELEC=pme 仅供对照，预期 grompp 失败。
# **只在空闲窗口跑**：启动时有任何别的 gmx mdrun（J005/主线）或 GPU 利用率 > ${GPU_IDLE_MAX:-10}% 就拒绝；
# 运行中看门狗每 60 s 查一次，发现别的 mdrun 出现就停掉自己的容器让路（YIELD），之后重跑本脚本会从 checkpoint 续。
# 不碰 GLM / 8888 / 18888 / key，不 docker prune，不改 ~/ha_env 既有文件（只在 ~/ha_env/xg2/ 下写）。
# 用法（k03）：setsid bash ~/ha_env/xg2/run_xg2.sh </dev/null >/dev/null 2>&1 &
#   可选：SYSTEMS="pre post" PHS="5.00 7.00" NT=6 NVT_STEPS=100000 NPT_STEPS=500000 ELEC=rf
# 结果：~/ha_env/xg2/run/XG2_SUMMARY.txt（末行 "XG2 OVERALL PASS|FAIL|YIELD|REFUSED"），每条 run/<sys>_pH<ph>/RESULT.txt
D=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
export HA_ENV=${HA_ENV:-$(dirname "$D")}
source "$HA_ENV/ha_common.sh"           # 提供 MODE/IMAGE/GMX_IN/DOCKER_PFX/log/others_running/gpu_util（只读引用，不改）
SYSTEMS=${SYSTEMS:-"pre post"}; PHS=${PHS:-"5.00 7.00"}; NT=${NT:-6}; ELEC=${ELEC:-rf}
NVT_STEPS=${NVT_STEPS:-100000}; NPT_STEPS=${NPT_STEPS:-500000}; REF_T=310
PY=${PY:-$HA/venv/bin/python}; [ -x "$PY" ] || PY=python3
FT=$HA/compat/ff_titratable; R=$D/run; mkdir -p "$R" "$D/work"; S=$R/XG2_SUMMARY.txt; LOG=$R/xg2.log
declare -A NNA=([pre]=24 [post]=25)   # = -qtot(tpr 实测：pre -24，post -25)；判读里 grompp 必须报 qtot 0
# box 上生成的合并力场 sha（机器上按同样输入重生成必须逐字节一致）
declare -A MSHA=([pre]=96ac8ad6f8fd8647ac204cd504f5879fd0cac16bf187c36ac845ba63c8a40626 [post]=81587499af689699b1a8a1b8433d1c490d90ab27a7b26dac9e2f43be0476f74a)
if [ "$MODE" = docker ]; then GPUF="-nb gpu -update cpu"; else GPUF="-nb cpu"; fi
CNAME=xg2_$(id -u)
summ(){ echo "$*" | tee -a "$S" | tee -a "$LOG"; }
# run_g <dir> <name> <gpu0|1> <lines...>：同 ha_common.run_gmx，但给容器起名（看门狗要能停它）
run_g(){ local dir=$1 name=$2 gpu=$3; shift 3; local f="$dir/.$name.sh"
  { echo 'set -e'; echo "cd '$dir'"; printf '%s\n' "$@"; } > "$f"
  if [ "$MODE" = docker ]; then
    sed -i "s#^GMX #$GMX_IN #; s# GMX # $GMX_IN #g" "$f"; local g=""; [ "$gpu" = 1 ] && g="--gpus all"
    $DOCKER_PFX "docker run --rm --name $CNAME $g --cpus ${CPUS_MD:-$NT} --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -e GMX_MAXBACKUP=-1 -v '$HA':'$HA' -w '$dir' $IMAGE '$f'" > "$dir/$name.out" 2>&1
  else sed -i "s#^GMX #gmx #; s# GMX # gmx #g" "$f"; GMX_MAXBACKUP=-1 sh "$f" > "$dir/$name.out" 2>&1; fi; }
nmd(){ pgrep -f 'gmx[^ ]* mdrun' 2>/dev/null | wc -l; }
watchdog(){ while sleep 60; do [ "$(nmd)" -gt 1 ] && { log "看门狗：发现别的 mdrun，停 $CNAME 让路"; touch "$R/.yield"
    [ "$MODE" = docker ] && $DOCKER_PFX "docker stop -t 30 $CNAME" >/dev/null 2>&1; pkill -f "mdrun -deffnm (nvt|npt)" 2>/dev/null; break; }; done; }
: > "$S"; rm -f "$R/.yield"
summ "# HA-XG2 $(ts) host=$(hostname) MODE=$MODE ELEC=$ELEC SYSTEMS=[$SYSTEMS] PHS=[$PHS] NVT=$NVT_STEPS NPT=$NPT_STEPS NT=$NT"
# ---- 0) 空闲闸 ----
if [ "${SKIP_IDLE_CHECK:-0}" != 1 ]; then
  if others_running; then summ "REFUSE：有别的 gmx mdrun 在跑（$(nmd) 个），不抢 GPU"; summ "XG2 OVERALL REFUSED"; exit 2; fi
  u=$(gpu_util); if [ -n "$u" ] && [ "$u" -gt "${GPU_IDLE_MAX:-10}" ] 2>/dev/null; then summ "REFUSE：GPU ${u}% > ${GPU_IDLE_MAX:-10}%"; summ "XG2 OVERALL REFUSED"; exit 2; fi
fi
# ---- 1) 包完整性 + 力场重生成（CPU，秒级）----
(cd "$D" && sha256sum -c --quiet SHA256SUMS) >> "$LOG" 2>&1 || { summ "FAIL SHA256SUMS（重跑 fetch_ha_xg2.sh）"; summ "XG2 OVERALL FAIL"; exit 1; }
cd "$D"
for s in $SYSTEMS; do P=$HA/systems/$s
  $PY xg0_gen_cross.py $P/martini.itp $FT $P/HA_$s.itp $P/go_atomtypes.itp B work/regen_B_$s >> "$LOG" 2>&1
  for x in itp tsv override; do cmp -s work/regen_B_$s.$x patch/cross_B_$s.$x || { summ "FAIL 补丁重生成与包内不一致：$s.$x"; summ "XG2 OVERALL FAIL"; exit 1; }; done
  $PY $HA/compat/compat_merge.py $P/martini.itp $FT $P/HA_$s.itp $P/go_atomtypes.itp work/merged_base_$s.itp work/merged_base_${s}_report.txt 5.00 >> "$LOG" 2>&1
  $PY xg_apply.py work/merged_base_$s.itp patch/cross_B_$s.itp patch/cross_B_$s.override work/merged_B_$s.itp >> "$LOG" 2>&1
  got=$(sha256sum work/merged_B_$s.itp | cut -d' ' -f1)
  [ "$got" = "${MSHA[$s]}" ] || { summ "FAIL merged_B_$s.itp sha=$got ≠ box ${MSHA[$s]}"; summ "XG2 OVERALL FAIL"; exit 1; }
  summ "OK 力场 $s：补丁重生成一致，merged_B_$s.itp sha 与 box 一致"
done
EL=$(cat "$D/mdp/elec_$ELEC.inc")
mk_mdp(){ awk -v e="$EL" '{ if ($0=="@ELEC@") print e; else print }' "$D/mdp/$1.mdp" | sed "s/@NSTEPS@/$2/" > "$3"; }
overall=PASS
for s in $SYSTEMS; do for ph in $PHS; do
  W=$R/${s}_pH$ph; mkdir -p "$W"; cd "$W"
  [ -f RESULT.txt ] && grep -q '^VERDICT' RESULT.txt && { summ "SKIP ${s}_pH$ph 已完成：$(grep VERDICT RESULT.txt)"; grep -q 'VERDICT PASS' RESULT.txt || overall=FAIL; continue; }
  { echo "; XG2 $s pH$ph (auto by run_xg2.sh)"; echo "#define pH$ph"; echo "#define GO_VIRT"
    echo "#include \"$D/work/merged_B_$s.itp\""; echo "#include \"$HA/systems/$s/HA_$s.itp\""
    echo "#include \"$FT/molecules.itp\""; echo "#include \"$FT/ion.itp\""
    read -r nwna < <(awk 'NR>2 && substr($0,6,5)~/^WNA/ && substr($0,11,5)~/WN$/' "$D/systems/${s}_wna.gro" | wc -l)
    printf '[ system ]\nXG2 %s pH%s\n[ molecules ]\nHA_%s 1\nWNA %d\nNA %d\nH+ %d\n' "$s" "$ph" "$s" "$nwna" "${NNA[$s]}" "$nwna"; } > topol.top
  mk_mdp em 0 em.mdp; mk_mdp nvt $NVT_STEPS nvt.mdp; mk_mdp npt $NPT_STEPS npt.mdp
  log "== ${s}_pH$ph 开始"
  if [ ! -f em.gro ]; then
    run_g "$W" grompp_em 0 "GMX grompp -f em.mdp -c $D/systems/${s}_wna.gro -r $D/systems/${s}_wna.gro -p topol.top -o em.tpr -po em_mdout.mdp" "GMX dump -s em.tpr > em.dump" \
      || { summ "FAIL ${s}_pH$ph grompp_em（见 $W/grompp_em.out）"; overall=FAIL; continue; }
    $PY $D/xg1_check.py em.dump $D/patch/cross_B_$s.tsv $ph $FT/pH_dep_interactions.itp > xg1.out 2>&1; rc=$?; gzip -f em.dump
    [ $rc = 0 ] || { summ "FAIL ${s}_pH$ph xg1_check（tpr 里交叉 LJ 或 pH 宏不对，见 xg1.out），不上 mdrun"; overall=FAIL; continue; }
    run_g "$W" em 0 "GMX mdrun -deffnm em -nb cpu -ntmpi 1 -ntomp $NT -pin off" || { summ "FAIL ${s}_pH$ph EM（见 em.out）"; overall=FAIL; continue; }
  fi
  for st in nvt npt; do
    [ -f $st.gro ] && continue
    if [ "${SKIP_IDLE_CHECK:-0}" != 1 ] && others_running; then summ "YIELD ${s}_pH$ph $st 前发现别的 mdrun"; summ "XG2 OVERALL YIELD"; exit 2; fi
    if [ $st = nvt ]; then pre="GMX grompp -f nvt.mdp -c em.gro -r em.gro -p topol.top -o nvt.tpr -po nvt_mdout.mdp"
    else pre="GMX grompp -f npt.mdp -c nvt.gro -t nvt.cpt -p topol.top -o npt.tpr -po npt_mdout.mdp"; fi
    [ -f $st.tpr ] || run_g "$W" grompp_$st 0 "$pre" || { summ "FAIL ${s}_pH$ph grompp_$st"; overall=FAIL; continue 2; }
    cpi=""; [ -f $st.cpt ] && cpi="-cpi $st.cpt"
    watchdog & WD=$!
    run_g "$W" $st 1 "GMX mdrun -deffnm $st $cpi -cpt 15 $GPUF -ntmpi 1 -ntomp $NT -pin off"; rc=$?
    kill $WD 2>/dev/null; wait $WD 2>/dev/null
    [ -f "$R/.yield" ] && { summ "YIELD ${s}_pH$ph $st 运行中让路（checkpoint 已存，重跑本脚本续）"; summ "XG2 OVERALL YIELD"; exit 2; }
    [ $rc = 0 ] || { summ "FAIL ${s}_pH$ph mdrun $st rc=$rc（见 $st.out / $st.log）"; overall=FAIL; continue 2; }
  done
  run_g "$W" ana 0 "printf 'Temperature\nDensity\nPotential\nVolume\n\n' | GMX energy -f npt.edr -o npt_e.xvg" \
    "printf 'a BB\nq\n' | GMX make_ndx -f em.gro -o bb.ndx" \
    "printf 'System\n' | GMX trjconv -s npt.tpr -f npt.xtc -pbc mol -o npt_mol.xtc" \
    "printf 'BB\nBB\n' | GMX rms -s em.tpr -f npt_mol.xtc -n bb.ndx -o rmsd.xvg -tu ns" || log "分析步骤有报错（见 ana.out），判读会标缺失"
  $PY $D/xg2_analyze.py "$W" $REF_T > RESULT.txt 2>&1; v=$(tail -1 RESULT.txt)
  summ "${s}_pH$ph $v"; sed 's/^/    /' RESULT.txt | grep -v '^    VERDICT' | tee -a "$S" >/dev/null
  [ "$v" = "VERDICT PASS" ] || overall=FAIL
done; done
summ "XG2 OVERALL $overall $(ts)"
