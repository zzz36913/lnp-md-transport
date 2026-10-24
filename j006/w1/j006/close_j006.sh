#!/bin/bash
# J006 收尾（k03 上跑；可在发车时就 nohup 起，它先睡到 MD 截止+5 min）：
#   等两台 MD 停 -> 每个 J006 体系导出【含水】全体系末帧 confout_W.gro(.gz) + 多帧含水 xtc(来自 prod.trr，默认每 50 ns 一帧)
#   + 非水末帧 + 日志数字 -> ~/xfer/j006/out/ ；容器里若有 numpy 则判相，否则只导数据给 box。
#   最后：若环境里有 GT（token，只在内存，绝不落盘）就自动调用 up_j006.sh 上传，否则提示手动跑。
# 只 kill run_phase/r.sh/gmx 与 gromacs-md:spark 容器，不碰 GLM / 8888 / 18888。
export TZ=Asia/Singapore
J=$(cd "$(dirname "$0")" && pwd); PH=${PH:-$(dirname "$J")}
O=$HOME/xfer/j006${TAGX:-w1}; mkdir -p $O/out $O/work; L=$O/close.log
IMG=${IMAGE:-ghcr.io/novomcp/gromacs-md:spark}; K4=${K4:-k04@10.0.0.2}; W=${W:-ph_j006_run}; MID=${MID:-0}   # MID=1: 不等、不杀，对正在跑的作业做只读快照(波 1→波 2 之间 / 22:30 中期报告)
DL=${MD_DEADLINE:-2026-10-24 22:30}; WAIT_AFTER_MIN=${WAIT_AFTER_MIN:-5}
log(){ echo "[$(date '+%F %T')] $*" | tee -a $L; }
st(){ echo "$*" > $O/STATE; log "STATE $*"; }
PAT='[r]un_phase|[ /]r\.sh|[g]mx '
dps3(){ docker ps -q --filter ancestor=$IMG 2>/dev/null || sg docker -c "docker ps -q --filter ancestor=$IMG"; }
dps4(){ ssh -o BatchMode=yes $K4 "docker ps -q --filter ancestor=$IMG 2>/dev/null || sg docker -c 'docker ps -q --filter ancestor=$IMG'"; }
busy(){ local a b c d; a=$(pgrep -f "$PAT"); b=$(ssh -o BatchMode=yes $K4 "pgrep -f '$PAT'"); c=$(dps3); d=$(dps4); [ -n "$a$b$c$d" ]; }
# 体系清单 = 两个队列文件里的 ph 行
SYS3=$(awk '$1=="ph"{print $2}' ${QF3:-$PH/queue_k03.txt} | tr '\n' ' '); SYS4=$(awk '$1=="ph"{print $2}' ${QF4:-$PH/queue_k04.txt} | tr '\n' ' ')
st SLEEPING; log "开始 host=$(hostname) 截止=$DL k03=[$SYS3] k04=[$SYS4] GT=$([ -n "${GT:-}" ] && echo 有 || echo 无)"
[ "$MID" = 1 ] && tw=0 || tw=$(( $(date -d "$DL" +%s) + WAIT_AFTER_MIN*60 - $(date +%s) )); [ $tw -gt 0 ] && { log "睡 ${tw}s 到截止+${WAIT_AFTER_MIN}min"; sleep $tw; }
st WAITING
[ "$MID" = 1 ] || for i in $(seq 1 20); do busy || break; sleep 30; done
if [ "$MID" != 1 ] && busy; then
  log "超时仍有残留，清理："
  log "k03 procs: $(pgrep -af "$PAT" | tr '\n' ';')"; log "k04 procs: $(ssh $K4 "pgrep -af '$PAT'" | tr '\n' ';')"
  pkill -f '[r]un_phase|[ /]r\.sh'; ssh $K4 "pkill -f '[r]un_phase|[ /]r\.sh'"
  for c in $(dps3); do log "k03 docker stop $c"; docker stop -t 60 $c >>$L 2>&1 || sg docker -c "docker stop -t 60 $c" >>$L 2>&1; done
  for c in $(dps4); do log "k04 docker stop $c"; ssh $K4 "docker stop -t 60 $c || sg docker -c 'docker stop -t 60 $c'" >>$L 2>&1; done
  sleep 5
else log "两台已自然停止"; fi
st EXPORT
# 每台本机执行的导出脚本（k04 上经 ssh 跑同一份）：参数 = WORK 目录、输出目录、体系...
cat > $O/work/exp_one.sh <<'EXP'
#!/bin/bash
IMG=$1; WK=$2; OUT=$3; shift 3; mkdir -p $OUT
PSQ=${PSQ:-$HOME/ph_phase_j006/phase_sq.py}
# 在容器里跑一段命令：先写成脚本文件（避免引号嵌套），docker 失败再用 sg docker
dk(){ local f=$OUT/.dk_$$_$RANDOM.sh; printf 'exec 2>&1\n%s\n' "$1" > $f
  local a="run --rm --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v $WK:$WK -v $OUT:$OUT -w $OUT $IMG $f"
  docker $a 2>/dev/null || sg docker -c "docker $a"; local rc=$?; rm -f $f; return $rc; }
G=/usr/local/gromacs/bin/gmx
for s in "$@"; do d=$WK/$s; o=$OUT/$s; mkdir -p $o; [ -d $d ] || { echo "$s NO_DIR" > $o/export.txt; continue; }
  cp $d/SYSTEM.txt $d/counts.txt $d/preasm.json $d/EM_FAIL.txt $d/prod.log $d/prod.tpr $o/ 2>/dev/null
  grep -E '^(Steepest|Maximum force|Potential Energy)' $d/em.log > $o/em_summary.txt 2>/dev/null
  st=NOT_STARTED; [ -f $d/em.log ] && st=EM; [ -f $d/eq2.gro ] && st=EQ_DONE; [ -f $d/prod.log ] && st=PROD; [ -f $d/.failed ] && st=FAILED
  echo "STATUS $st" > $o/export.txt
  [ -f $d/prod.tpr ] || continue
  # 含水全体系末帧：prod.gro(-maxh 正常结束会写) > prod.cpt > prod.trr 最后一帧
  if [ -s $d/prod.gro ] && [ ! $d/prod.gro -ot $d/prod.cpt ]; then cp $d/prod.gro $o/confout_W.gro; echo "confout from prod.gro" >> $o/export.txt
  else dk "echo 0 | $G trjconv -s $d/prod.tpr -f $d/prod.cpt -o $o/confout_W.gro" > $o/tc_cpt.out 2>&1 && echo "confout from prod.cpt" >> $o/export.txt \
       || { dk "echo 0 | $G trjconv -s $d/prod.tpr -f $d/prod.trr -dump 999999999 -o $o/confout_W.gro" > $o/tc_trr.out 2>&1 && echo "confout from last trr frame" >> $o/export.txt; }; fi
  # 多帧含水：trr(每 NSTTRR 步一帧, 默认 50 ns) -> xtc(全体系, 0.001 nm 精度)；再补上 confout 末帧
  [ -s $d/prod.trr ] && dk "echo 0 | $G trjconv -s $d/prod.tpr -f $d/prod.trr -o $o/frames_W.xtc" > $o/tc_frames.out 2>&1 \
     && echo "frames_W.xtc $(tr '\r' '\n' < $o/tc_frames.out | grep '^Last frame' | tr -s ' ')" >> $o/export.txt
  # 非水末帧（小文件，方便快速看）
  [ -s $o/confout_W.gro ] && { printf 'not resname W and not resname NA and not resname CL\n' > $o/sel.txt
    dk "$G select -s $d/prod.tpr -sf $o/sel.txt -on $o/nonW.ndx && echo 0 | $G trjconv -s $d/prod.tpr -f $o/confout_W.gro -n $o/nonW.ndx -o $o/last_nonW.gro" > $o/tc_nonW.out 2>&1; }
  # 判相：容器里有 numpy 才跑（宿主无 numpy）
  if [ -s $o/confout_W.gro ] && dk "python3 -c 'import numpy'" >/dev/null 2>&1; then
    cp $PSQ $o/phase_sq.py 2>/dev/null || true
    [ -f $o/phase_sq.py ] && { HK=""; case $s in *_HII) HK="--hkl '2,1,0;2,-1,0;0,2,0'";; esac
      dk "timeout 900 python3 $o/phase_sq.py $o/confout_W.gro --sel W --conn $HK --sq-out $o/sq.dat > $o/phase.json"; } > $o/phase_sq.out 2>&1
  else echo "phase_sq skipped (容器无 numpy 或无 confout)，数据交 box 判相" >> $o/export.txt; fi
  gzip -f $o/confout_W.gro 2>/dev/null
  ls -l $o >> $o/export.txt
done
EXP
chmod +x $O/work/exp_one.sh
bash $O/work/exp_one.sh $IMG $HOME/$W $O/work/k03 $SYS3 >> $L 2>&1
scp -q $O/work/exp_one.sh $K4:/tmp/exp_one_j006.sh && ssh $K4 "bash /tmp/exp_one_j006.sh $IMG \$HOME/$W \$HOME/xfer/j006${TAGX:-w1}/k04 $SYS4" >> $L 2>&1
mkdir -p $O/work/k04; scp -qr $K4:xfer/j006${TAGX:-w1}/k04/. $O/work/k04/ 2>>$L
st PACK
for h in k03 k04; do for s in $( [ $h = k03 ] && echo $SYS3 || echo $SYS4 ); do o=$O/work/$h/$s; [ -d $o ] || continue
  for f in confout_W.gro.gz frames_W.xtc last_nonW.gro phase.json sq.dat prod.log em_summary.txt export.txt preasm.json EM_FAIL.txt SYSTEM.txt counts.txt; do
    [ -s $o/$f ] && cp $o/$f $O/out/j006_${s}_$f; done
  # prod.tpr 也传（box 端判相/选原子用）
  [ -s $o/prod.tpr ] && cp $o/prod.tpr $O/out/j006_${s}_prod.tpr
done; done
grep -E 'STATUS|QUEUE|EM_FAIL|EM Fmax|preasm|接力队列结束' ~/$W/phase.log > $O/out/j006_k03_phase_status.txt 2>/dev/null
ssh $K4 "grep -E 'STATUS|QUEUE|EM_FAIL|EM Fmax|preasm|接力队列结束' ~/$W/phase.log" > $O/out/j006_k04_phase_status.txt 2>/dev/null
{ echo "== J006 close $(date '+%F %T') =="; for f in $O/out/*_export.txt; do echo "-- $f"; head -6 $f; done
  for f in $O/out/*_prod.log; do echo "$(basename $f) perf=$(awk '/Performance:/{print $2}' $f | tail -1) last=$(grep -E '^ +Step +Time' -A1 $f | tail -1)"; done
  echo "== close.log =="; cat $L; ls -l $O/out; } > $O/out/j006_SUMMARY.txt
st UPLOAD
if [ -n "${GT:-}" ]; then bash $J/up_j006.sh >> $L 2>&1; else log "环境无 GT：请手动 bash $J/up_j006.sh（会提示输入 token，不回显、不落盘）"; fi
st DONE; echo "CLOSE DONE $(date '+%T')"
