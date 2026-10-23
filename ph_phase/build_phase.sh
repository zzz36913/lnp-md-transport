#!/usr/bin/env bash
# 建体系：随机混合自组装起点（J004）或预组装 lam/hii 起点（J005，build_preasm.py）。用法: bash build_phase.sh T0 [T50 ...]（幂等：有 .done_build 则跳过）
# 步骤: 拷 itp -> phase_counts.py 算分子数 -> gmx insert-molecules 逐种随机放入 BOX*INS_SCALE 立方盒 -> 写 sys.top -> 写 mdp
source "$(cd "$(dirname "$0")" && pwd)/phase_common.sh"

write_mdps(){ local d=$1 seed=$2 geom=${3:-random}
  local pc=$PCTYPE; [ -n "$pc" ] || { [ "$geom" = random ] && pc=isotropic || pc=semiisotropic; }
  local rp="1.0" cp="3e-4"; [ "$pc" = semiisotropic ] && { rp="1.0 1.0"; cp="3e-4 3e-4"; }
  local n1=$(awk -v n=$EQ1_NS -v dt=$EQ1_DT 'BEGIN{printf "%d", n*1000/dt}')
  local n2=$(awk -v n=$EQ2_NS 'BEGIN{printf "%d", n*1000/0.010}')
  local n3=$(awk -v n=$PROD_NS 'BEGIN{printf "%d", n*1000/0.020}')
  sed "s/@EM_STEPS@/$EM_STEPS/" "$PH/mdp/em.mdp" > "$d/em.mdp"
  local P="s/@PCTYPE@/$pc/; s/@REFP@/$rp/; s/@COMP@/$cp/"
  sed "s/@NSTEPS@/$n1/; s/@TEMP@/$TEMP/g; s/@SEED@/$seed/; s/@DT@/$EQ1_DT/; s/@TAUP@/$EQ1_TAUP/; $P" "$PH/mdp/eq1.mdp" > "$d/eq1.mdp"
  sed "s/@NSTEPS@/$n2/; s/@TEMP@/$TEMP/g; $P" "$PH/mdp/eq2.mdp" > "$d/eq2.mdp"
  sed "s/@NSTEPS@/$n3/; s/@TEMP@/$TEMP/g; s/@NSTXTC@/$NSTXTC/; s/@NSTTRR@/$NSTTRR/; $P" "$PH/mdp/prod.mdp" > "$d/prod.mdp"
  ! grep -l '@[A-Z_]*@' "$d"/*.mdp >/dev/null 2>&1 || die "mdp 占位符未替换: $(grep -l '@[A-Z_]*@' "$d"/*.mdp)"; }

build_one(){ local sys=$1 d="$WORK/$1"; mkdir -p "$d"
  local comp=$(sys_comp $sys) alpha=$(sys_alpha $sys) BOX=$(sys_box $sys) geom=$(sys_geom $sys)   # 盒长可按体系覆盖: PH_BOX_<SYS>
  local CBOX=$BOX   # 算分子数用的等效立方盒边长；hii 用矩形盒的等体积边长
  [ "$geom" = hii ] && CBOX=$(awk -v a=$HII_A -v nx=$HII_NX -v ny=$HII_NY -v lz=$HII_LZ 'BEGIN{printf "%.4f", (nx*a*ny*a*sqrt(3)*lz)^(1/3)}')
  if [ -f "$d/.done_build" ]; then   # 已建：参数必须一致，否则拒绝复用（防止验证与正式跑参数不同）
    local want="$sys comp=$comp alpha=$alpha box=$BOX " have=$(cut -d' ' -f1-4 "$d/SYSTEM.txt" 2>/dev/null)" "
    [ "$have" = "$want" ] || die "$sys: 已有 build 参数不符（已有「$have」≠ 现在「$want」）；确认后删 $d 重建"
    log "$d: build 已完成且参数一致，跳过"; return 0; fi
  [ -n "$comp" ] || die "$sys 没有组成（设 PH_COMP_$sys=...）"
  local seed=$(( SEED_BASE + $(echo -n "$sys" | cksum | cut -d' ' -f1) % 100000 ))
  for f in $CORE_ITPS; do [ -s "$FF/$f" ] || die "缺 $FF/$f"; cp "$FF/$f" "$d/"; done
  for f in $PH_ITPS; do cp "$PH/ff/$f" "$d/"; done
  ( cd "$d" &&  python3 "$PH/phase_counts.py" --comp "$comp" --alpha "$alpha" --box "$CBOX" --water-wt "$WATER_WT" \
      --dens "$DENS" --salt "$SALT" --itp $PH_ITPS martini_v3.0.0_phospholipids_PC_v2.itp martini_v3.0.0_sterols_v1.itp \
      martini_v3.0.0_solvents_v1.itp martini_v3.0.0_ions_v1.itp > counts.txt 2> counts.log ) || die "$sys counts 失败: $(cat $d/counts.log)"
  log "$sys: comp=$comp alpha=$alpha geom=$geom seed=$seed $(cat $d/counts.log)"
  if [ "$geom" != random ]; then   # J005 预组装：纯标准库 python 放置 + 分子间最近邻 >= 0.30 nm 自检
    local gargs="--box $BOX --nbil $NBIL"; [ "$geom" = hii ] && gargs="--hii-a $HII_A --nx $HII_NX --ny $HII_NY --lz $HII_LZ"
    ( cd "$d" && python3 "$PH/build_preasm.py" --geom $geom --counts counts.txt --tmpl "$PH/ff" $gargs --seed $seed --info preasm.json -o sys.gro > preasm.out 2>&1 ) \
      || die "$sys 预组装失败/自检不过: $(tail -c 600 $d/preasm.out)"
    log "$sys: preasm $(cat $d/preasm.json)"
  else
  local L=$(awk -v b=$BOX -v s=$INS_SCALE 'BEGIN{printf "%.3f", b*s}')
  local cmds=() prev="" i=0 mol n s
  while read -r mol n; do i=$((i+1)); s=$(( seed + i ))
    if [ -z "$prev" ]; then cmds+=("GMX insert-molecules -ci $PH/ff/mol_$mol.gro -nmol $n -box $L $L $L -try 1000 -seed $s -o ins$i.gro > ins$i.txt 2>&1")
    else cmds+=("GMX insert-molecules -f $prev -ci $PH/ff/mol_$mol.gro -nmol $n -try 1000 -seed $s -o ins$i.gro > ins$i.txt 2>&1"); fi
    prev=ins$i.gro
  done < "$d/counts.txt"
  cmds+=("cp $prev sys.gro")
  rm -f "$d"/ins*.gro "$d/build.out"
  run_gmx "$d" build "${cmds[@]}" || die "$sys insert-molecules 失败，见 $d/build.out / ins*.txt"
  # 校验：每种都放满
  i=0; while read -r mol n; do i=$((i+1))
    local got=$(grep -oE 'Added [0-9]+ molecules' "$d/ins$i.txt" | awk '{print $2}')
    [ "$got" = "$n" ] || die "$sys: $mol 只放进 ${got:-?}/$n（盒子太挤；调大 INS_SCALE 后删 $d 重建）"
  done < "$d/counts.txt"
  fi
  { for f in $TOP_ORDER; do printf '#include "%s"\n' "$f"; done
    printf '\n[ system ]\nph_phase %s comp=%s alpha=%s box=%s water_wt=%s T=%s\n\n[ molecules ]\n' "$sys" "$comp" "$alpha" "$BOX" "$WATER_WT" "$TEMP"
    cat "$d/counts.txt"; } > "$d/sys.top"
  local na=$(sed -n 2p "$d/sys.gro" | tr -d ' ')
  write_mdps "$d" "$seed" "$geom"
  echo "$sys comp=$comp alpha=$alpha box=$BOX geom=$geom ins_box=${L:-NA} water_wt=$WATER_WT T=$TEMP seed=$seed beads=$na" > "$d/SYSTEM.txt"
  touch "$d/.done_build"; log "$sys: build 完成 beads=$na ($d/sys.gro, sys.top)"; }

[ $# -ge 1 ] || die "用法: build_phase.sh SYS [SYS...]"
command -v python3 >/dev/null || die "宿主机缺 python3"
for s in "$@"; do build_one "$s"; done
