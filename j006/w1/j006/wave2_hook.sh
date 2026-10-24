#!/bin/bash
# J006 波 2 钩子（由 start_wave1.sh 在发车时另起后台监视；队列 F 行在截止后不会被取，所以不用 F 行）。HT=k03|k04
# 作用: 等本机波 1 全部 ph 作业结束 -> 读 $PH/WAVE2_BRANCH（调度/LNP MD 在 22:30 判读后写入分支名；最多等 POLL_MIN 分钟）
#       -> 没有则默认分支 EXT（原样续跑波 1 全部 6 条，新截止 W2_DEADLINE）-> 用 w2/queue_<分支>_<HT>.txt 重新发车，机器不空转。
# 分支队列文件由 j006-wave2-* 包提供（解到 $PH/w2/）；EXT 随波 1 包自带。
export TZ=Asia/Singapore
HT=${HT:?}; PH=${PH:-$HOME/ph_phase_j006}; WK=${WORK:-$HOME/ph_j006_run}; CL=$WK/.queue_claims
W2_DEADLINE=${W2_DEADLINE:-'2026-10-25 07:30'}; POLL_MIN=${POLL_MIN:-25}
log(){ echo "[$(date '+%F %T')] wave2_hook[$HT] $*"; }
PL=$(awk '/^ph /{print NR}' $PH/queue_$HT.txt); nph=$(echo $PL | wc -w)   # 声明队列里 ph 行的行号 = claims 目录名 L<行号>
log "等待波 1 的 $nph 条 ph 作业结束 (claims $CL)"
for i in $(seq 1 400); do d=0; for n in $PL; do grep -q '^END' $CL/L$n/info 2>/dev/null && d=$((d+1)); done
  [ $d -ge $nph ] && break; sleep 30; done
log "波 1 ph 作业 END 数 $d/$nph；开始等 $PH/WAVE2_BRANCH（最多 ${POLL_MIN} 分钟）"
for i in $(seq 1 $((POLL_MIN*2))); do [ -s $PH/WAVE2_BRANCH ] && break; sleep 30; done
BR=$(tr -d ' \n\r' < $PH/WAVE2_BRANCH 2>/dev/null); [ -n "$BR" ] || { BR=EXT; log "未收到分支指令 -> 默认 EXT（续跑波 1）"; }
Q=$PH/w2/queue_${BR}_$HT.txt; [ -f $Q ] || { log "找不到 $Q -> 回退 EXT"; BR=EXT; Q=$PH/w2/queue_EXT_$HT.txt; }
[ -f $Q ] || { log "EXT 队列也不存在，放弃"; exit 1; }
[ -s $PH/WAVE2_DEADLINE ] && W2_DEADLINE=$(cat $PH/WAVE2_DEADLINE)
mv $CL ${CL}_w1_$(date +%H%M) 2>/dev/null
export PH WORK=$WK FF=${FF:-$HOME/lnp_ff} MODE=docker MD_DEADLINE="$W2_DEADLINE" SLOTS=${SLOTS:-$([ $HT = k04 ] && echo 4 || echo 3)} NT_SLOT=${NT_SLOT:-5} MIN_LEFT_H=${MIN_LEFT_H:-1} QUEUE_FILE=$Q
log "发车波 2 分支=$BR 队列=$Q 截止=$W2_DEADLINE"
setsid nohup bash $PH/run_phase.sh </dev/null >/dev/null 2>&1 &
sleep 5; log "波 2 run_phase 已起: $(pgrep -f '[r]un_phase' | tr '\n' ' ')"
