#!/bin/bash
# [R4N3] 小包收集 (在 k03/k04 上跑; 只读 run 目录, 只写 $DEST). 不碰任何 token / 口令 / 上传: 上传仍走既有 ZCode 流程.
# 用法: bash collect_small.sh <OUT=R4N2_run_<机>_*目录> [DEST=$HOME/R4N3/xfer]   环境: PKG=<R4N3 包目录> GATE_PY=<含 MDAnalysis 的 python> COLLECT=1|0
# 内容 (每个 build): 最新一段 (ext2000 > prod) 的 末帧 gro (DONE 用 confout.gro; TRUNC 用 cpt 末态 -> gmx trjconv -dump 末帧) + STATUS + SHA256_out.txt + md log 末 60 行
#       relax select 的 gate_frames (L2 判据原始读数) + runner 的 ledger/slots 日志 + runs.tsv;
#       COLLECT=1 时另跑冻结 collect (verdict_N3_wrap.py collect) 出每 run 的 series tsv (判读只要它, 不要 xtc).
# 02:00 "早完先传": 同一脚本, 只收已 DONE/TRUNC 的段; 还在跑的段在 MANIFEST 里记 RUNNING, 不打断、不读写其文件.
# [fix1101] 末帧: confout.gro > <deffnm>.gro (prod.gro / ext.gro / ext.partNNNN.gro, runner 用 -deffnm 不出 confout) > xtc 末帧 (宿主无 gmx: 容器 gmx trjconv -dump 1e9;
#           -dump -1 在 GROMACS 里取的是第 1 帧, 不是末帧). 容器: --rm, 无 --gpus, --network none, nice 19 + cpu-shares 128, 名字 xsmall_* (不撞 R4*_ 前缀), attempt 目录只读挂载. 失败原因写 MANIFEST note.
# [fix1101] collect: R4N3 包 inputs/ 缺 L1_summary.tsv (verdict_R4_3day.py:188 FileNotFoundError). 用本目录 L1_summary_N3.tsv (= 包内 tools/l1_scan.sh 对包 inputs 原样跑出, 20/20 PASS, sha 下行锁定)
#           在 $W/collect_inputs 下做符号链接叠层传给 --inputs; 冻结脚本/包文件不动. GATE_PY 默认包内容器包装 (宿主 python3 无 numpy). collect 结果写 MANIFEST 行 _collect.
set -u; OUT=${1:?OUT}; OUT=$(cd "$OUT" && pwd); DEST=${2:-$HOME/R4N3/xfer}; SD=$(cd "$(dirname "$0")" && pwd); PKG=${PKG:-$(cd "$SD/../R4N3" 2>/dev/null && pwd)}
GMX=${GMX:-}; IMG=${IMG:-ghcr.io/novomcp/gromacs-md:spark}; G=${G:-/usr/local/gromacs/bin/gmx}; GATE_PY=${GATE_PY:-$PKG/gatewrap/gate_py_container.sh}; COLLECT=${COLLECT:-1}
L1=${L1:-$SD/L1_summary_N3.tsv}; L1_SHA=d4d5387918cc3b5ccee55d8019f2483e587c2df4a2c49c6f5440c099fd040e88
tag=$(basename $OUT)_$(date +%m%d_%H%M); W=$DEST/$tag; mkdir -p $W/builds; M=$W/MANIFEST.tsv; echo -e "build\tseg\tstate\tlastframe\tnote" > $M
lastgro(){ # lastgro <attempt> <dest>  -> lf / nt
  local a=$1 d=$2 f x t s rc; lf=-; nt=-
  for f in confout.gro prod.gro ext.gro $(cd $a && ls ext.part[0-9][0-9][0-9][0-9].gro 2>/dev/null | sort -r); do [ -s $a/$f ] && { cp $a/$f $d/last.gro && lf=${f%.gro}; return; }; done
  x=$(ls $a/*.xtc 2>/dev/null | sort | tail -1); [ -z "$x" ] && { nt="no gro, no xtc"; return; }
  s=$(basename $x .xtc); s=${s%.part[0-9][0-9][0-9][0-9]}; t=$a/$s.tpr; [ -f $t ] || t=$(ls $a/*.tpr 2>/dev/null | head -1); [ -z "$t" ] && { nt="xtc but no tpr"; return; }
  if [ -n "$GMX" ]; then echo 0 | nice -n 19 $GMX trjconv -s $t -f $x -dump 1e9 -o $d/last.gro > $d/lastframe.log 2>&1; rc=$?
  else echo 0 | nice -n 19 docker run --rm -i --network none --name xsmall_$(hostname -s)_$$_$RANDOM --cpu-shares 128 -u "$(id -u):$(id -g)" -e HOME=/tmp -e OMP_NUM_THREADS=2 \
      -v $a:$a:ro -v $d:$d -w $d --entrypoint /bin/sh $IMG -c "nice -n 19 $G trjconv -s $t -f $x -dump 1e9 -o $d/last.gro" > $d/lastframe.log 2>&1; rc=$?; fi
  local na=$(sed -n 2p $d/last.gro 2>/dev/null | tr -d ' '); local nl=$(wc -l 2>/dev/null < $d/last.gro || echo 0)
  if [ $rc = 0 ] && [ -n "$na" ] && [ "$nl" = $((na+3)) ]; then lf=xtc_last; nt="$(basename $x) $(grep -o 'Last written: frame *[0-9]* time *[0-9.]*' $d/lastframe.log | tail -1 | tr -s ' ')"
  else mv $d/last.gro $d/last.gro.bad 2>/dev/null; nt="trjconv FAIL rc=$rc: $(grep -v '^ *$' $d/lastframe.log | tail -2 | tr '\t\n' '  ' | cut -c1-160)"; fi; }
for bd in $OUT/builds/R4N1_*; do b=$(basename $bd); seg=; for s in ext2000 ext1200 prod; do [ -d $bd/$s ] && { seg=$s; break; }; done
  [ -z "$seg" ] && { echo -e "$b\t-\tNO_PROD\t-\t$(cat $bd/select/STATUS 2>/dev/null | head -c 120)" >> $M; continue; }
  a=$(ls -d $bd/$seg/attempt_* | sort | tail -1); st=$(head -c 200 $a/STATUS 2>/dev/null); d=$W/builds/$b/$seg; mkdir -p $d
  case "$st" in DONE*|TRUNC*|NUMERIC*) ;; *) echo -e "$b\t$seg\tRUNNING\t-\t${st:-no STATUS}" >> $M; continue;; esac
  cp $a/STATUS $d/; cp $a/SHA256_out.txt $d/ 2>/dev/null; tail -60 $(ls $a/*.log | grep -v part | head -1) > $d/md_tail.log 2>/dev/null
  lastgro $a $d
  ls $bd/select/attempt_*/gate_frames >/dev/null 2>&1 && { mkdir -p $W/builds/$b/select; cp -r $(ls -d $bd/select/attempt_* | sort | tail -1)/gate_frames $W/builds/$b/select/; cp $bd/select/STATUS $W/builds/$b/select/ 2>/dev/null; }
  echo -e "$b\t$seg\t${st%% *}\t$lf\t$nt" >> $M; done
for f in ledger slots runs.tsv RUN_META.txt; do [ -e $OUT/$f ] && cp -r $OUT/$f $W/; done
if [ "$COLLECT" = 1 ] && [ -n "$PKG" ]; then IN=$PKG/inputs; cs=OK; cn=-
  if [ ! -f $IN/L1_summary.tsv ]; then IN=$W/collect_inputs; mkdir -p $IN; ln -s $PKG/inputs/* $IN/; cp $L1 $IN/L1_summary.tsv 2>/dev/null
    [ "$(sha256sum 2>/dev/null < $IN/L1_summary.tsv | cut -d' ' -f1)" = "$L1_SHA" ] || { cs=FAIL; cn="L1_summary sha 不符/缺: $L1"; }; fi
  if [ $cs = OK ]; then $GATE_PY $PKG/verdict_N3_wrap.py collect $OUT --inputs $IN --out $W/collect --jobs 2 > $W/collect.log 2>&1; rc=$?; echo "collect rc=$rc" >> $W/collect.log
    [ $rc = 0 ] && cn="$(grep '^wrote' $W/collect.log | tail -1 | cut -c1-120)" || { cs=FAIL; cn="rc=$rc: $(grep -v '^collect rc' $W/collect.log | tail -1 | cut -c1-160)"; }; fi
  echo -e "_collect\t-\t$cs\t-\t$cn" >> $M
  find $W/collect -name '*.xtc' -delete 2>/dev/null; else echo -e "_collect\t-\tSKIP\t-\tCOLLECT=$COLLECT PKG=${PKG:-空}" >> $M; fi
( cd $W && find . -type f ! -name SHA256SUMS -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
tar -C $DEST -czf $DEST/$tag.tar.gz $tag && ( cd $DEST && sha256sum $tag.tar.gz > $tag.tar.gz.sha256 )
echo "small pack: $DEST/$tag.tar.gz ($(du -h $DEST/$tag.tar.gz | cut -f1)); $(awk -F'\t' 'NR>1{print $3}' $M | sort | uniq -c | tr '\n' ' ')"
