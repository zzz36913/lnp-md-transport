#!/usr/bin/env bash
# 脂质滴定介观相 MVP 主流程。
# 接力队列(J004 正式用法): QUEUE_FILE=~/ph_phase/queue_k03.txt SLOTS=3 setsid bash ~/ph_phase/run_phase.sh </dev/null >/dev/null 2>&1 &
# 固定列表/验证: SYSTEMS="T0 T67 POS" BUILD_ONLY=1 bash ~/ph_phase/run_phase.sh
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

QUEUE_FILE=${QUEUE_FILE:-}           # 设了就进「接力队列」模式（见 queue_k03.txt / queue_k04.txt）
SLOTS=${SLOTS:-3}                     # 队列模式: 本机 GPU 并发槽位数
MIN_LEFT_H=${MIN_LEFT_H:-1}           # 队列模式: 距 MD_DEADLINE 不足此小时数时不再新开 ph 作业，改取 F 作业

log "==== ph_phase MVP host=$(hostname) MODE=$MODE WORK=$WORK PH=$PH FF=$FF ===="
( cd "$PH" && sha256sum -c --quiet SHA256SUMS ) >> "$LOG" 2>&1 || die "PH 目录 SHA256SUMS 校验失败（文件被改或不全）"

if [ -n "$QUEUE_FILE" ]; then
  # ================= 接力队列模式 =================
  # 队列文件每行一条：`ph <体系名>` 或 `F <标签> <shell 命令>`；# 后为注释。每次取作业都重新读文件，运行中可追加行。
  # SLOTS 个槽位各自循环：取最上面一条未被领取的作业(mkdir 原子锁 $WORK/.queue_claims/L<行号>)，跑完/失败即取下一条，
  # 直到队列空或到 MD_DEADLINE。剩余 < MIN_LEFT_H 小时时跳过 ph 行(不领取，记 SKIP)，只取 F 行。
  [ -f "$QUEUE_FILE" ] || die "队列文件不存在: $QUEUE_FILE"
  CLAIM="$WORK/.queue_claims"; mkdir -p "$CLAIM"
  NT=${NT_SLOT:-$(( $(nproc) / SLOTS ))}; [ "$NT" -ge 1 ] || NT=1; export NT
  log "QUEUE 模式 file=$QUEUE_FILE SLOTS=$SLOTS NT/槽=$NT 截止 $MD_DEADLINE MIN_LEFT_H=$MIN_LEFT_H T=${TEMP}K BOX=${BOX} WATER_WT=$WATER_WT GPUFLAGS='$GPUFLAGS'"
  queue_lines(){ awk '{sub(/#.*/,""); gsub(/^[ \t]+|[ \t]+$/,"")} NF{print NR"\t"$0}' "$QUEUE_FILE"; }
  next_job(){ local left=$(maxh_left); [ "$left" = 0 ] && return 1
    local short=$(awk -v l=$left -v m=$MIN_LEFT_H 'BEGIN{print (l<m)?1:0}') n line
    while IFS=$'\t' read -r n line; do
      [ -d "$CLAIM/L$n" ] && continue
      if [ "${line%% *}" = ph ] && [ "$short" = 1 ]; then
        [ -f "$CLAIM/skip_L$n" ] || { touch "$CLAIM/skip_L$n"; log "QUEUE SKIP L$n「$line」：剩余 ${left} h < ${MIN_LEFT_H} h，改取 F 作业" >&2; }
        continue; fi
      mkdir "$CLAIM/L$n" 2>/dev/null || continue
      printf '%s\t%s\n' "$n" "$line"; return 0
    done < <(queue_lines)
    return 1; }
  slot(){ local k=$1 job n line typ rc
    while job=$(next_job); do
      n=${job%%$'\t'*}; line=${job#*$'\t'}; typ=${line%% *}
      echo "slot$k START $(date '+%F %T')" > "$CLAIM/L$n/info"
      log "QUEUE slot$k 取 L$n「$line」(距截止 $(maxh_left) h)"
      case $typ in
        ph) set -- $line; pipeline "$2"; rc=$?
            [ -f "$WORK/$2/.failed" ] && rc=1 ;;
        F)  set -- $line; local tag=$2; local cmd=${line#F $tag }
            log "QUEUE slot$k F[$tag]: $cmd"; bash -c "$cmd"; rc=$? ;;
        *)  log "QUEUE slot$k L$n 未知类型「$typ」"; rc=2 ;;
      esac
      echo "END $(date '+%F %T') rc=$rc" >> "$CLAIM/L$n/info"
      log "QUEUE slot$k 结束 L$n rc=$rc，释放槽位"
    done
    log "QUEUE slot$k 无可取作业或已到截止 $MD_DEADLINE，退出"; }
  for k in $(seq 1 $SLOTS); do slot $k & sleep 10; done; wait
  while IFS=$'\t' read -r n line; do set -- $line; [ "$1" = ph ] || { log "QUEUE-STATUS L$n F[$2] $(tail -1 $CLAIM/L$n/info 2>/dev/null || echo 未领取)"; continue; }
    d="$WORK/$2"; st=NOT_STARTED; [ -d "$CLAIM/L$n" ] && st=RUN_INCOMPLETE
    [ -f "$d/.failed" ] && st=FAILED; [ -f "$WORK/$2.SEGDONE" ] && st=PROD_SEGMENT; [ -f "$d/.done_prod" ] && st=PROD_FULL
    [ -f "$CLAIM/skip_L$n" ] && [ ! -d "$CLAIM/L$n" ] && st=SKIPPED_SHORT
    log "STATUS $2 $st perf=$(awk '/Performance:/{print $2}' $d/prod.log 2>/dev/null | tail -1) t_ps=$(grep -E '^ +Step +Time' -A1 $d/prod.log 2>/dev/null | tail -1 | awk '{print $2}')"
  done < <(queue_lines)
  touch "$WORK/QUEUE.DONE"; log "==== ph_phase 接力队列结束 ===="; exit 0
fi

# ================= 固定列表模式（原 J004 / BUILD_ONLY 验证）=================
log "SYSTEMS=[$SYSTEMS] PARALLEL=$PARALLEL NT=$NT T=${TEMP}K BOX=${BOX}nm(插入 x$INS_SCALE) WATER_WT=$WATER_WT SALT=${SALT}M GPUFLAGS='$GPUFLAGS' 截止 $MD_DEADLINE BUILD_ONLY=$BUILD_ONLY"
for s in $SYSTEMS; do log "  $s: comp=$(sys_comp $s) alpha=$(sys_alpha $s)"; done
if [ "$PARALLEL" = 1 ]; then
  for s in $SYSTEMS; do pipeline "$s" & sleep 5; done; wait
else for s in $SYSTEMS; do pipeline "$s"; done; fi
for s in $SYSTEMS; do d="$WORK/$s"; st=RUN_INCOMPLETE
  [ -f "$d/.failed" ] && st=FAILED; [ -f "$d/.done_prod" ] && st=PROD_FULL; [ -f "$WORK/$s.SEGDONE" ] && [ ! -f "$d/.done_prod" ] && st=PROD_SEGMENT
  [ "$BUILD_ONLY" = 1 ] && [ -f "$d/verify_eq1.tpr" ] && st=VERIFIED
  log "STATUS $s $st perf=$(awk '/Performance:/{print $2}' $d/prod.log 2>/dev/null | tail -1)"; done
touch "$WORK/ALL.DONE"; log "==== ph_phase 本轮结束 ===="
