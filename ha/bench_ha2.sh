#!/usr/bin/env bash
# HA-ENV-01 单槽基准：HA2 水盒（3HMG BHA 三聚体 GōMartini 3 + W + 0.15 M NaCl，20836 珠）EM → EQ 0.5 ns → PROD 10 ns，测 ns/day。
# **只在空闲窗口跑**：发现任何别的 gmx mdrun（J005/主线）或宿主 GPU 利用率 > ${GPU_IDLE_MAX:-10}% 就拒绝启动，不与 J005 抢 GPU。
# GPU 参数 -nb gpu -update cpu（Go 虚拟位点不支持 GPU update）。结果：~/ha_env/bench/<ts>/BENCH.txt
# 用法：setsid bash ~/ha_env/bench_ha2.sh </dev/null >/dev/null 2>&1 &     可选：NT=6 EQ_STEPS=50000 PROD_STEPS=500000
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ha_common.sh"
NT=${NT:-6}; EQ_STEPS=${EQ_STEPS:-50000}; PROD_STEPS=${PROD_STEPS:-500000}; CPUS=${BENCH_CPUS:-$NT}
W=$HA/bench/$(date +%Y%m%d_%H%M%S); mkdir -p "$W"; LOG=$W/bench.log; B=$W/BENCH.txt
if others_running; then log "REFUSE：有别的 gmx mdrun 在跑（$(pgrep -fc 'gmx[^ ]* mdrun') 个），不抢 GPU"; echo "REFUSED busy $(ts)" > "$B"; exit 2; fi
u=$(gpu_util); if [ -n "$u" ] && [ "$u" -gt "${GPU_IDLE_MAX:-10}" ] 2>/dev/null; then log "REFUSE：GPU 利用率 ${u}% > ${GPU_IDLE_MAX:-10}%"; echo "REFUSED gpu=${u}% $(ts)" > "$B"; exit 2; fi
log "bench 开始 host=$(hostname) NT=$NT EQ=$EQ_STEPS PROD=$PROD_STEPS GPU=${u:-?}%"
sed "s/@NSTEPS@/$EQ_STEPS/" "$HA/ha2box/eq.mdp" > "$W/eq.mdp"; sed "s/@NSTEPS@/$PROD_STEPS/" "$HA/ha2box/prod.mdp" > "$W/prod.mdp"
G="-ntmpi 1 -ntomp $NT -pin off"
run_gmx "$W" em 0 "GMX grompp -f $HA/ha2box/em.mdp -c $HA/ha2box/ha2box.gro -p $HA/ha2box/ha2box.top -o em.tpr -po em_mdout.mdp" "GMX mdrun -deffnm em -nb cpu $G" || { log "EM 失败，见 $W/em.out"; echo "FAIL em" > "$B"; exit 1; }
log "EM 完成 $(grep -m1 'Maximum force' "$W/em.log")"
others_running && { log "EM 后发现别的 mdrun 已启动，让路退出"; echo "YIELD after em $(ts)" > "$B"; exit 2; }
run_gmx "$W" eq 1 "GMX grompp -f eq.mdp -c em.gro -r em.gro -p $HA/ha2box/ha2box.top -o eq.tpr -po eq_mdout.mdp" "GMX mdrun -deffnm eq -nb gpu -update cpu $G" || { log "EQ 失败，见 $W/eq.out"; echo "FAIL eq" > "$B"; exit 1; }
log "EQ 完成 $(grep -A1 Performance "$W/eq.log" | tail -1)"
run_gmx "$W" prod 1 "GMX grompp -f prod.mdp -c eq.gro -t eq.cpt -p $HA/ha2box/ha2box.top -o prod.tpr -po prod_mdout.mdp" "GMX mdrun -deffnm prod -nb gpu -update cpu $G" || { log "PROD 失败，见 $W/prod.out"; echo "FAIL prod" > "$B"; exit 1; }
nsd=$(grep -A1 'Performance:' "$W/prod.log" | awk '/Performance:/{print $2}')
nan=$(grep -nw -i -c nan "$W/prod.log")
{ echo "HA2 水盒 单槽 ns/day=${nsd:-?}（$((PROD_STEPS*20/1000000)) ns，dt 20 fs，-nb gpu -update cpu，NT=$NT）"
  echo "host=$(hostname) $(ts) nan整词=$nan 末帧盒子=$(tail -1 "$W/prod.gro" 2>/dev/null)"; } | tee "$B" | tee -a "$LOG"
