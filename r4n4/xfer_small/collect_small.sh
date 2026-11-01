#!/bin/bash
# [R4N4] 小包收集 (由 R4N3 版复制, 只改路径/包装名; 放在包内 xfer_small/) (在 k03/k04 上跑; 只读 run 目录, 只写 $DEST). 不碰任何 token / 口令 / 上传: 上传仍走既有 ZCode 流程.
# 用法: bash collect_small.sh <OUT=$HOME/R4N4/R4N4_run_<机>_*目录> [DEST=$HOME/R4N4/xfer]   环境: PKG=<R4N4 包目录, 默认本脚本上一级> GATE_PY=<含 MDAnalysis 的 python> COLLECT=1|0
# 内容 (每个 build): 最新一段 (按 ext2000 > ext1200 > prod 取先存在的; 本包无续跑段, 实际即 prod) 的 末帧 gro (DONE 用 confout.gro; TRUNC 用 cpt 末态 -> gmx trjconv -dump 末帧) + STATUS + SHA256_out.txt + md log 末 60 行
#       relax select 的 gate_frames (L2 判据原始读数) + runner 的 ledger/slots 日志 + runs.tsv;
#       COLLECT=1 时另跑冻结 collect (verdict_N4_wrap.py collect; 判读再跑 verdict_N4_wrap.py judge, 按档分目录) 出每 run 的 series tsv (判读只要它, 不要 xtc).
# 02:00 "早完先传": 同一脚本, 只收已 DONE/TRUNC 的段; 还在跑的段在 MANIFEST 里记 RUNNING, 不打断、不读写其文件.
set -u; OUT=${1:?OUT}; OUT=$(cd "$OUT" && pwd); DEST=${2:-$HOME/R4N4/xfer}; PKG=${PKG:-$(cd "$(dirname "$0")/.." 2>/dev/null && pwd)}
GMX=${GMX:-gmx}; GATE_PY=${GATE_PY:-python3}; COLLECT=${COLLECT:-1}
tag=$(basename $OUT)_$(date +%m%d_%H%M); W=$DEST/$tag; mkdir -p $W/builds; M=$W/MANIFEST.tsv; echo -e "build\tseg\tstate\tlastframe\tnote" > $M
for bd in $OUT/builds/R4N1_*; do b=$(basename $bd); seg=; for s in ext2000 ext1200 prod; do [ -d $bd/$s ] && { seg=$s; break; }; done
  [ -z "$seg" ] && { echo -e "$b\t-\tNO_PROD\t-\t$(cat $bd/select/STATUS 2>/dev/null | head -c 120)" >> $M; continue; }
  a=$(ls -d $bd/$seg/attempt_* | sort | tail -1); st=$(head -c 200 $a/STATUS 2>/dev/null); d=$W/builds/$b/$seg; mkdir -p $d
  case "$st" in DONE*|TRUNC*|NUMERIC*) ;; *) echo -e "$b\t$seg\tRUNNING\t-\t${st:-no STATUS}" >> $M; continue;; esac
  cp $a/STATUS $d/; cp $a/SHA256_out.txt $d/ 2>/dev/null; tail -60 $(ls $a/*.log | grep -v part | head -1) > $d/md_tail.log 2>/dev/null
  lf=-; if [ -f $a/confout.gro ]; then cp $a/confout.gro $d/last.gro; lf=confout
  else x=$(ls $a/*.xtc 2>/dev/null | tail -1); t=$(ls $a/*.tpr | head -1); [ -n "$x" ] && echo 0 | $GMX trjconv -s $t -f $x -dump -1 -o $d/last.gro >/dev/null 2>&1 && lf=xtc_last; fi
  ls $bd/select/attempt_*/gate_frames >/dev/null 2>&1 && { mkdir -p $W/builds/$b/select; cp -r $(ls -d $bd/select/attempt_* | sort | tail -1)/gate_frames $W/builds/$b/select/; cp $bd/select/STATUS $W/builds/$b/select/ 2>/dev/null; }
  echo -e "$b\t$seg\t${st%% *}\t$lf\t-" >> $M; done
for f in ledger slots runs.tsv RUN_META.txt; do [ -e $OUT/$f ] && cp -r $OUT/$f $W/; done
if [ "$COLLECT" = 1 ] && [ -n "$PKG" ]; then $GATE_PY $PKG/verdict_N4_wrap.py collect $OUT --inputs $PKG/inputs --out $W/collect --jobs 2 > $W/collect.log 2>&1; echo "collect rc=$?" >> $W/collect.log
  find $W/collect -name '*.xtc' -delete 2>/dev/null; fi
( cd $W && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
tar -C $DEST -czf $DEST/$tag.tar.gz $tag && ( cd $DEST && sha256sum $tag.tar.gz > $tag.tar.gz.sha256 )
echo "small pack: $DEST/$tag.tar.gz ($(du -h $DEST/$tag.tar.gz | cut -f1)); $(awk -F'\t' 'NR>1{print $3}' $M | sort | uniq -c | tr '\n' ' ')"
