#!/bin/bash
# J004 07:00 收尾（k03 上 nohup 跑）：确认两台 MD 已停、残留则清理并记录；收集日志数字；phase_sq 判相；trjconv 非水末帧。
# 只读 + 写 ~/xfer/j004；只 kill run_phase/r.sh/gmx 与 gromacs-md:spark 容器，不碰 GLM。
export TZ=Asia/Singapore
O=$HOME/xfer/j004; mkdir -p $O/work; L=$O/close.log; : > $O/STATE
IMG=ghcr.io/novomcp/gromacs-md:spark; K4=k04@10.0.0.2; W=ph_phase_run
log(){ echo "[$(date '+%F %T')] $*" | tee -a $L; }
st(){ echo "$*" > $O/STATE; log "STATE $*"; }
PAT='[r]un_phase|[ /]r\.sh|[g]mx '
dps3(){ docker ps -q --filter ancestor=$IMG 2>/dev/null || sg docker -c "docker ps -q --filter ancestor=$IMG"; }
dps4(){ ssh -o BatchMode=yes $K4 "docker ps -q --filter ancestor=$IMG 2>/dev/null || sg docker -c 'docker ps -q --filter ancestor=$IMG'"; }
busy(){ local a b c d; a=$(pgrep -f "$PAT"); b=$(ssh -o BatchMode=yes $K4 "pgrep -f '$PAT'"); c=$(dps3); d=$(dps4); [ -n "$a$b$c$d" ]; }
st WAITING
log "开始 host=$(hostname)"
for i in $(seq 1 20); do busy || break; sleep 30; done
if busy; then
  log "超时仍有残留，清理："
  log "k03 procs: $(pgrep -af "$PAT" | tr '\n' ';')"; log "k04 procs: $(ssh $K4 "pgrep -af '$PAT'" | tr '\n' ';')"
  pkill -f '[r]un_phase|[ /]r\.sh'; ssh $K4 "pkill -f '[r]un_phase|[ /]r\.sh'"
  for c in $(dps3); do log "k03 docker stop $c"; docker stop -t 60 $c >>$L 2>&1 || sg docker -c "docker stop -t 60 $c" >>$L 2>&1; done
  for c in $(dps4); do log "k04 docker stop $c"; ssh $K4 "docker stop -t 60 $c || sg docker -c 'docker stop -t 60 $c'" >>$L 2>&1; done
  sleep 5
else log "两台已自然停止（无 run_phase/r.sh/gmx、无 MD 容器）"; fi
log "终检 k03 procs=[$(pgrep -af "$PAT" | tr '\n' ';')] cont=[$(dps3 | tr '\n' ' ')]"
log "终检 k04 procs=[$(ssh $K4 "pgrep -af '$PAT'" | tr '\n' ';')] cont=[$(dps4 | tr '\n' ' ')]"
st COLLECT
grep -E 'STATUS|QUEUE-STATUS|接力队列结束' ~/$W/phase.log | tail -30 > $O/k03_phase_status.txt
ssh $K4 "grep -E 'STATUS|QUEUE-STATUS|接力队列结束' ~/$W/phase.log | tail -30" > $O/k04_phase_status.txt
SYS3="POS T67 T67_rep2"; SYS4="T33 T100"
for s in $SYS3; do mkdir -p $O/work/$s; cp ~/$W/$s/prod.{gro,tpr,log} $O/work/$s/ 2>>$L; ls -l --time-style=+%T ~/$W/$s/prod.gro >>$L 2>&1; echo k03 > $O/work/$s/host; done
for s in $SYS4; do mkdir -p $O/work/$s; scp -q $K4:$W/$s/prod.{gro,tpr,log} $O/work/$s/ 2>>$L; ssh $K4 "ls -l --time-style=+%T ~/$W/$s/prod.gro" >>$L 2>&1; echo k04 > $O/work/$s/host; done
# prod.gro 缺失时从 xtc 取末帧
for s in $SYS3 $SYS4; do d=$O/work/$s; [ -s $d/prod.gro ] && continue
  log "$s 无 prod.gro，从 xtc 取末帧"; h=$(cat $d/host); src=~/$W/$s
  [ $h = k04 ] && { scp -q $K4:$W/$s/prod.xtc $d/ 2>>$L; src=$d; }
  sg docker -c "docker run --rm --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v $src:$src -v $d:$d -w $d $IMG -c 'echo 0 | /usr/local/gromacs/bin/gmx trjconv -s $d/prod.tpr -f $src/prod.xtc -dump 999999999 -o $d/prod.gro'" >>$L 2>&1; done
st ANALYZE
if python3 -c 'import numpy' 2>>$L; then NP=1; log "numpy OK $(python3 -c 'import numpy;print(numpy.__version__)')"; else NP=0; log "宿主无 numpy，跳过判相"; fi
for s in $SYS3 $SYS4; do d=$O/work/$s
  [ $NP = 1 ] && { timeout 900 python3 ~/ph_phase/phase_sq.py $d/prod.gro --conn --sq-out $O/${s}_sq.dat > $O/${s}_phase.json 2>>$L || log "$s phase_sq 失败 rc=$?"; }
  printf 'set -e\ncd %s\necho "not resname W" > sel.txt\n/usr/local/gromacs/bin/gmx select -s prod.tpr -sf sel.txt -on nonW.ndx\necho 0 | /usr/local/gromacs/bin/gmx trjconv -s prod.tpr -f prod.gro -n nonW.ndx -o %s/j004_%s_last_nonW.gro\n' $d $O $s > $d/tc.sh
  sg docker -c "docker run --rm --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v $O:$O -w $d $IMG $d/tc.sh" > $d/tc.out 2>&1 || log "$s trjconv 失败，见 $d/tc.out"
  log "$s nonW gro: $(sed -n 2p $O/j004_${s}_last_nonW.gro 2>/dev/null) 珠 / 全体系 $(sed -n 2p $d/prod.gro) 珠"
done
st SUMMARY
python3 - "$O" $SYS3 $SYS4 <<'PY' 2>>$L
import sys,os,json,re
O=sys.argv[1]; rows=[]
hdr=['system','host','perf_ns_day','last_step','last_time_ps','ns','prod_gro_beads','nonW_beads','phase','dims','ratios','nonlamellar','best_guess','n_water_clusters','cluster_wrap_axes','water_vox_frac','box_nm','npart_W']
for s in sys.argv[2:]:
    d=os.path.join(O,'work',s); host=open(d+'/host').read().strip()
    perf=step=tps='NA'
    try:
        L=open(d+'/prod.log').read().splitlines()
        for i,l in enumerate(L):
            if l.startswith('Performance:'): perf=l.split()[1]
            if re.match(r'^ +Step +Time',l) and i+1<len(L):
                p=L[i+1].split()
                if len(p)>=2: step,tps=p[0],p[1]
    except Exception as e: pass
    ns='NA'
    try: ns='%.1f'%(float(tps)/1000)
    except: pass
    def nb(f):
        try: return open(f).readlines()[1].strip()
        except: return 'NA'
    j={}
    try: j=json.load(open(os.path.join(O,s+'_phase.json')))
    except: pass
    c=j.get('connectivity',{})
    rows.append([s,host,perf,step,tps,ns,nb(d+'/prod.gro'),nb(os.path.join(O,'j004_%s_last_nonW.gro'%s)),j.get('phase','NA'),j.get('dims','NA'),j.get('ratios','NA'),j.get('nonlamellar','NA'),j.get('best_guess',''),c.get('n_clusters','NA'),[x['wrap_axes'] for x in c.get('clusters',[])][:4] if c else 'NA',c.get('water_vox_frac','NA'),j.get('box_nm','NA'),j.get('npart','NA')])
with open(os.path.join(O,'j004_phase.tsv'),'w') as f:
    f.write('\t'.join(hdr)+'\n')
    for r in rows: f.write('\t'.join(json.dumps(x,ensure_ascii=False) if isinstance(x,list) else str(x) for x in r)+'\n')
for r in rows: print('ROW',' | '.join(str(x) for x in r[:9]))
PY
{ echo "== J004 close $(date '+%F %T') =="; cat $O/j004_phase.tsv; echo "== k03 phase.log STATUS =="; cat $O/k03_phase_status.txt; echo "== k04 phase.log STATUS =="; cat $O/k04_phase_status.txt; echo "== close.log =="; cat $L; } > $O/SUMMARY.txt
ls -l $O >> $O/SUMMARY.txt
st DONE
echo "CLOSE DONE $(date '+%T')"; grep -c . $O/j004_phase.tsv
