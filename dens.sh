#!/usr/bin/env bash
# J002: z 向数密度剖面 (MC3/DSPC/CHOL/PO4), 后 150 ns, 以膜(DSPC+CHOL+MC3)居中。只读轨迹, 产出写 <rep>/density/
# 用法: setsid bash dens.sh <rep目录>... </dev/null >/dev/null 2>&1 &   日志 ~/j002_dens.out
set -u
IMAGE=${IMAGE:-ghcr.io/novomcp/gromacs-md:spark}
G=/usr/local/gromacs/bin/gmx
B=${B:-150000}
LOG=${LOG:-$HOME/j002_dens.out}
log(){ echo "[$(date '+%F %T %Z')] $*" >> "$LOG"; }
log "J002 start $*"
for d in "$@"; do
  d=$(readlink -f "$d")
  [ -f "$d/prod.tpr" ] && [ -f "$d/prod.xtc" ] || { log "$d: 缺 prod.tpr/xtc, 跳过"; continue; }
  mkdir -p "$d/density"
  cat > "$d/density/.run.sh" <<SH
set -e
cd '$d'
$G select -s prod.tpr -on density/idx.ndx -select '"MC3" resname MC3; "DSPC" resname DSPC; "CHOL" resname CHOL; "PO4" name PO4; "MEMB" resname DSPC CHOL MC3'
i=0
for g in MC3 DSPC CHOL PO4; do
  printf '4\n%s\n' \$i | $G density -f prod.xtc -s prod.tpr -n density/idx.ndx -d Z -center -b $B -sl 200 -dens number -o density/dens_\$g.xvg
  i=\$((i+1))
done
SH
  if sg docker -c "docker run --rm --cpus=2 --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v '$d':'$d' -w '$d' $IMAGE '$d/density/.run.sh'" > "$d/density/run.out" 2>&1; then
    for g in MC3 DSPC CHOL PO4; do
      awk -v g=$g '!/^[#@]/{if($2>m){m=$2;z=$1} a=($1<0?-$1:$1); if(a<0.15){c+=$2;n++}} END{printf "%s\tpeak_z=%.3f\tpeak=%.3f\tcenter(|z|<0.15)=%.3f\n",g,z,m,(n?c/n:0)}' "$d/density/dens_$g.xvg"
    done > "$d/density/SUMMARY.txt"
    log "$d: DONE $(ls "$d"/density/*.xvg | wc -l) xvg"
  else
    log "$d: FAILED, 见 $d/density/run.out: $(tail -3 "$d/density/run.out" | tr '\n' ' ')"
  fi
done
log "J002 ALL DONE"
