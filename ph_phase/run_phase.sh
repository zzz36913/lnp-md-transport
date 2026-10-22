#!/usr/bin/env bash
# 脂质滴定介观相 MVP 主流程。用法(k03): SYSTEMS="T0 T100 NEG" setsid bash ~/ph_phase/run_phase.sh </dev/null >~/ph_k03.out 2>&1 &
# 每个体系: build -> grompp/EM -> EQ1(5fs) -> EQ2(10fs) -> PROD(20fs, -maxh 到 MD_DEADLINE, -cpi 续跑)
# 幂等: 每步 .done_<step>；PROD 被截断后重跑同一命令即从 prod.cpt 续跑；.failed 的体系跳过(删掉可重试)。
# PARALLEL=1(默认): 本机所列体系同时跑、共享一块 GPU，每个 -ntomp = nproc/体系数。PARALLEL=0 顺序跑。
source "$(cd "$(dirname "$0")" && pwd)/phase_common.sh"
SYSTEMS=${SYSTEMS:-"T0 T50 T100 POS NEG"}
PARALLEL=${PARALLEL:-1}
BUILD_ONLY=${BUILD_ONLY:-0}           # 1 = 只 build + grompp(EM/EQ1) 验证，不跑 mdrun
NSYS=$(echo $SYSTEMS | wc -w)
if [ "$PARALLEL" = 1 ]; then NT=${NT:-$(( $(nproc) / NSYS ))}; else NT=${NT:-$(nproc)}; fi
[ "$NT" -ge 1 ] || NT=1

maxh_left(){ local now=$(date +%s) dl=$(date -d "today $MD_DEADLINE" +%s)
  [ $dl -lt $(( now - 6*3600 )) ] && dl=$(date -d "tomorrow $MD_DEADLINE" +%s)
  awk -v r=$(( dl-now )) 'BEGIN{h=r/3600; if(h<0.02) print 0; else printf "%.3f", h}'; }

grompp_ok(){ local d=$1 name=$2   # grompp 不许有 WARNING（-maxwarn 0）；NOTE 记录
  local n=$(grep -c '^NOTE' "$d/$name.out" 2>/dev/null); [ "${n:-0}" -gt 0 ] && log "$d: $name 有 $n 个 NOTE（见 $name.out）"; return 0; }

pipeline(){ local sys=$1 d="$WORK/$1"
  [ -f "$d/.done_prod" ] && { log "$sys: production 已完成，跳过"; return 0; }
  [ -f "$d/.failed" ] && { log "$sys: 之前失败(.failed)，跳过；删 $d/.failed 可重试"; return 0; }
  bash "$PH/build_phase.sh" "$sys" || { touch "$d/.failed"; return 1; }
  step "$d" grompp_em "GMX grompp -f em.mdp -c sys.gro -p sys.top -o em.tpr -maxwarn 0" || { touch "$d/.failed"; return 1; }; grompp_ok "$d" grompp_em
  if [ "$BUILD_ONLY" = 1 ]; then
    run_gmx "$d" verify_eq1 "GMX grompp -f eq1.mdp -c sys.gro -p sys.top -o verify_eq1.tpr -maxwarn 0" \
      && log "$sys: BUILD_ONLY 验证通过(grompp em+eq1 0 warning) beads=$(sed -n 2p $d/sys.gro | tr -d ' ')" \
      || { log "$sys: verify_eq1 grompp 失败，见 $d/verify_eq1.out"; touch "$d/.failed"; return 1; }
    return 0; fi
  step "$d" em "GMX mdrun -deffnm em -ntmpi 1 -ntomp $NT $PINFLAGS" || { touch "$d/.failed"; return 1; }
  grep -qiE 'converged to (Fmax|machine precision)' "$d/em.log" || log "$sys: 警告 EM 未见收敛字样(继续，见 em.log)"
  step "$d" grompp_eq1 "GMX grompp -f eq1.mdp -c em.gro -p sys.top -o eq1.tpr -maxwarn 0" || { touch "$d/.failed"; return 1; }
  step "$d" eq1 "GMX mdrun -deffnm eq1 -ntmpi 1 -ntomp $NT $PINFLAGS $GPUFLAGS -cpi eq1.cpt" || { touch "$d/.failed"; return 1; }
  step "$d" grompp_eq2 "GMX grompp -f eq2.mdp -c eq1.gro -t eq1.cpt -p sys.top -o eq2.tpr -maxwarn 0" || { touch "$d/.failed"; return 1; }
  step "$d" eq2 "GMX mdrun -deffnm eq2 -ntmpi 1 -ntomp $NT $PINFLAGS $GPUFLAGS -cpi eq2.cpt" || { touch "$d/.failed"; return 1; }
  step "$d" grompp_prod "GMX grompp -f prod.mdp -c eq2.gro -t eq2.cpt -p sys.top -o prod.tpr -maxwarn 0" || { touch "$d/.failed"; return 1; }
  local mh=$(maxh_left)
  [ "$mh" = 0 ] && { log "$sys: 已过 MD 截止 $MD_DEADLINE，不开 production（重跑可续）"; return 0; }
  log "$sys: production -maxh $mh (截止 $MD_DEADLINE, NT=$NT)"
  # prod 不打 .done 直到 nsteps 跑满；被 -maxh 截断时留 prod.cpt，下次重跑续跑
  if run_gmx "$d" prod "GMX mdrun -deffnm prod -ntmpi 1 -ntomp $NT $PINFLAGS $GPUFLAGS -maxh $mh -cpi prod.cpt"; then
    grep -iqw 'nan' "$d/prod.log" && log "$sys: 警告 prod.log 出现 nan"
    local perf=$(awk '/Performance:/{print $2}' "$d/prod.log" | tail -1)
    local tlast=$(grep -E '^ +Step +Time' -A1 "$d/prod.log" | tail -1 | awk '{print $2}')
    log "$sys: production 段结束 t=${tlast:-?} ps Performance=${perf:-?} ns/day"
    local nsteps=$(awk -F= '/^nsteps/{gsub(/ /,"",$2); print $2}' "$d/prod.mdp")
    local slast=$(grep -E '^ +Step +Time' -A1 "$d/prod.log" | tail -1 | awk '{print $1}')
    [ -n "$slast" ] && [ "$slast" -ge "$nsteps" ] 2>/dev/null && touch "$d/.done_prod"
    touch "$WORK/$sys.SEGDONE"
  else log "$sys: production 失败，见 $d/prod.out"; touch "$d/.failed"; return 1; fi; }

log "==== ph_phase MVP host=$(hostname) MODE=$MODE WORK=$WORK PH=$PH FF=$FF ===="
log "SYSTEMS=[$SYSTEMS] PARALLEL=$PARALLEL NT=$NT T=${TEMP}K BOX=${BOX}nm(插入 x$INS_SCALE) WATER_WT=$WATER_WT SALT=${SALT}M GPUFLAGS='$GPUFLAGS' 截止 $MD_DEADLINE BUILD_ONLY=$BUILD_ONLY"
for s in $SYSTEMS; do log "  $s: comp=$(sys_comp $s) alpha=$(sys_alpha $s)"; done
( cd "$PH" && sha256sum -c --quiet SHA256SUMS ) >> "$LOG" 2>&1 || die "PH 目录 SHA256SUMS 校验失败（文件被改或不全）"
if [ "$PARALLEL" = 1 ]; then
  for s in $SYSTEMS; do pipeline "$s" & sleep 5; done; wait
else for s in $SYSTEMS; do pipeline "$s"; done; fi
for s in $SYSTEMS; do d="$WORK/$s"; st=RUN_INCOMPLETE
  [ -f "$d/.failed" ] && st=FAILED; [ -f "$d/.done_prod" ] && st=PROD_FULL; [ -f "$WORK/$s.SEGDONE" ] && [ ! -f "$d/.done_prod" ] && st=PROD_SEGMENT
  [ "$BUILD_ONLY" = 1 ] && [ -f "$d/verify_eq1.tpr" ] && st=VERIFIED
  log "STATUS $s $st perf=$(awk '/Performance:/{print $2}' $d/prod.log 2>/dev/null | tail -1)"; done
touch "$WORK/ALL.DONE"; log "==== ph_phase 本轮结束 ===="
