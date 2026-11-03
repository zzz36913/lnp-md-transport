#!/bin/bash
# [R4N6] 第 6 包小包收集. 由 R4N5 版 (D5/pkg/R4N5/xfer_small/collect_small.sh) 改; diff 见 xfer_small/collect_small.diff. 新增 (K 13:38/13:44, 13:47):
#   (1) 每 build 帧: 起点帧 (select/attempt_*/selected.gro = 闸门判过、prod 的 -c) + prod 0/200/400/.../1200 ns (XEXT 续段另加 1400/.../3000 ns), 各一帧 gro (frames/t<ns>.gro; trjconv -b t -e t, 只取恰在该时刻的帧, 没有就记 MISSING);
#   (2) 分析表 ANALYSIS.tsv (tools/analysis_table.py: 判读状态 + 各时刻 ncl/wpol/Cz; 描述用, 不进门);
#   (3) 先完成先传, 小包在前大包在后: $DEST/<tag>/upload/ 下 00_summary (ANALYSIS + 判读 + runs_status + MANIFEST, 最小) -> 每 build 一个小 tar (按 prod/ext STATUS 完成时刻排序) -> 最后全量 tar;
#       顺序写 UPLOAD_ORDER.txt (序号 文件 字节 sha256 完成时刻); 与 $DEST 里以前任何一次 UPLOAD_ORDER 内容 sha 相同的 build 小 tar 记 SAME_AS_PREV (可不再传);
#   (4) XEXT (PREREG_N6 §8.1): 冻结 collect 只读 prod*.xtc, 所以另跑 tools/collect_xext.py --machine <本机> (源 = R4N5 prod + 本晚 ext3000 段) + verdict_N6_wrap.py judge_xext, 出 collect_xext/{runs_status_xext.tsv,series_xext/,VERDICT_N6_XEXT.*}.
#   verdict_N5_wrap -> verdict_N6_wrap, N5_INTERIM -> N6_INTERIM, R4N5 -> R4N6 路径/名. 只读 run 目录, 只写 $DEST; 不上传 (上传仍走既有 ZCode 流程, 由调度按 UPLOAD_ORDER 执行).
# 原注释 (R4N5): 第 5 包小包收集. 由 R4N4 fix1101 版 (repo r4n4/xfer_small/collect_small.sh, sha256 6644f57367794d4a...ef35604f) 复制, 只改: R4N4->R4N5 路径/名, verdict_N4_wrap->verdict_N5_wrap,
#   PKG 默认 = 本脚本上一级 (本脚本在包内 xfer_small/), collect 成功后多跑一次 verdict_N5_wrap.py judge (只读 series, 写进小包).
# [R4N5v2 K 11-02 13:46] 时刻表 (PREREG_N5 §7/§9): 11-02 ~20:30 与 11-03 ~01:00 中途 COLLECT=0 (分支检查点), 11-03 07:00 收尾 COLLECT=1. (02:00 那次取消)
#   COLLECT=0 现在也尽力跑冻结 collect + N5 判读, 标 INTERIM (N5_INTERIM=1; 正在写的 xtc 末帧可能残缺 -> 失败只记 _collect FAIL, 小包照出). 每 run 的相描述量时间序列 = collect/series/<build>.csv (t_ns,ncl,wind,wpol,n_tube,Cz,C_max).
#   COLLECT=1 = 最终; 判读草稿 judge_N5.log/VERDICT_N5.md. 两种模式都删 xtc, 只留 series/状态/日志/末帧.
# 原注释 (R4N4 fix1101):
# [R4N5] 小包收集 (由 R4N3 版复制, 只改路径/包装名; 放在包内 xfer_small/) (在 k03/k04 上跑; 只读 run 目录, 只写 $DEST). 不碰任何 token / 口令 / 上传: 上传仍走既有 ZCode 流程.
# 用法: bash collect_small.sh <OUT=$HOME/R4N6/R4N6_run_<机>_*目录> [DEST=$HOME/R4N6/xfer]   环境: PKG=<R4N6 包目录, 默认本脚本上一级> XEXT_BASE=<默认 $PKG/xext/base_R4N5_T360.tsv> EXT_SRC_RUNS=<默认 $HOME/R4N5/R4N5_run_<机>_*> GATE_PY=<含 MDAnalysis 的 python> COLLECT=1|0
# 内容 (每个 build): 最新一段 (按 ext2000 > ext1200 > prod 取先存在的; 本包无续跑段, 实际即 prod) 的 末帧 gro (DONE 用 confout.gro; TRUNC 用 cpt 末态 -> gmx trjconv -dump 末帧) + STATUS + SHA256_out.txt + md log 末 60 行
#       relax select 的 gate_frames (L2 判据原始读数) + runner 的 ledger/slots 日志 + runs.tsv;
#       COLLECT=1 时另跑冻结 collect (verdict_N5_wrap.py collect; 判读再跑 verdict_N5_wrap.py judge, 按档分目录) 出每 run 的 series tsv (判读只要它, 不要 xtc).
# 02:00 "早完先传": 同一脚本, 只收已 DONE/TRUNC 的段; 还在跑的段在 MANIFEST 里记 RUNNING, 不打断、不读写其文件.
# [fix1101] 末帧: confout.gro > <deffnm>.gro (prod.gro / ext.gro / ext.partNNNN.gro, runner 用 -deffnm 不出 confout) > xtc 末帧 (宿主无 gmx: 容器 gmx trjconv -dump 1e9;
#           -dump -1 在 GROMACS 里取的是第 1 帧, 不是末帧). 容器: --rm, 无 --gpus, --network none, nice 19 + cpu-shares 128, 名字 xsmall_* (不撞 R4*_ 前缀), attempt 目录只读挂载. 失败原因写 MANIFEST note.
# [fix1101] GATE_PY 默认包内容器包装 (宿主 python3 无 numpy); collect 结果写 MANIFEST 行 _collect. 本包 inputs/L1_summary.tsv 已在 (24/24 PASS), 冻结脚本/包文件不动.
# [fix1101] 本脚本放包外 ~/R4N5_pkg/xfer_small/ (包内旧副本留着不动, MANIFEST_sha256 不变); PKG 默认 ../R4N5, 没有则退回 ..
set -u; OUT=${1:?OUT}; OUT=$(cd "$OUT" && pwd); DEST=${2:-$HOME/R4N6/xfer}; SD=$(cd "$(dirname "$0")" && pwd); PKG=${PKG:-$(cd "$SD/.." && pwd)}   # [R4N5] 本脚本在包内 xfer_small/, PKG = 上一级
GMX=${GMX:-}; IMG=${IMG:-ghcr.io/novomcp/gromacs-md:spark}; G=${G:-/usr/local/gromacs/bin/gmx}; GATE_PY=${GATE_PY:-$PKG/gatewrap/gate_py_container.sh}; COLLECT=${COLLECT:-1}
MACHINE=$(sed -n 's/^machine=\([^ ]*\).*/\1/p' $OUT/RUN_META.txt 2>/dev/null | head -1); MACHINE=${MACHINE:-$(basename $OUT | sed -n 's/^R4N6_run_\(k0[34]\)_.*/\1/p')}   # [R4N6]
XEXT_BASE=${XEXT_BASE:-$PKG/xext/base_R4N5_T360.tsv}; EXT_SRC_RUNS=${EXT_SRC_RUNS:-$HOME/R4N5/R4N5_run_${MACHINE}_*}; PYH=${PYH:-python3}   # [R4N6] PYH 只跑标准库脚本 (analysis_table)
FR_NS=${FR_NS:-"0 200 400 600 800 1000 1200"}; FR_NS_X=${FR_NS_X:-"1400 1600 1800 2000 2200 2400 2600 2800 3000"}   # [R4N6] 帧时刻 (ns)
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
gxro(){ # [R4N6] gxro <只读目录> <写目录> <gmx 子命令...> : 宿主 GMX 或容器 (同 lastgro 的容器约束: --rm 无 GPU 无网络 nice 19, 只读挂载)
  local a=$1 d=$2; shift 2
  if [ -n "$GMX" ]; then nice -n 19 $GMX "$@"; else docker run --rm -i --network none --name xsmall_$(hostname -s)_$$_$RANDOM --cpu-shares 128 -u "$(id -u):$(id -g)" -e HOME=/tmp -e OMP_NUM_THREADS=2 \
      -v $a:$a:ro -v $d:$d -w $d --entrypoint nice $IMG -n 19 $G "$@"; fi; }
frames(){ # [R4N6] frames <attempt> <dest> <ns 列表> : 每个时刻一帧 (只取恰在该时刻的帧; 多个 xtc 段逐个试); 结果记 $d/frames/FRAMES.tsv
  local a=$1 d=$2 ns=$3 t x tp ok; mkdir -p $d/frames; tp=$(ls $a/*.tpr 2>/dev/null | head -1)
  [ -z "$tp" ] && { echo -e "-\tNO_TPR" >> $d/frames/FRAMES.tsv; return; }
  for t in $ns; do ok=MISSING
    for x in $(ls $a/*.xtc 2>/dev/null | sort); do
      echo 0 | gxro $a $d/frames trjconv -s $tp -f $x -b $((t*1000)) -e $((t*1000)) -o $d/frames/t$t.gro > $d/frames/t$t.log 2>&1
      [ -s $d/frames/t$t.gro ] && { ok="$(basename $x)"; break; }; done
    [ $ok = MISSING ] && rm -f $d/frames/t$t.gro; echo -e "$t\t$ok" >> $d/frames/FRAMES.tsv; done; rm -f $d/frames/*.log; gzip -nf $d/frames/*.gro 2>/dev/null; }
for bd in $OUT/builds/R4N1_*; do b=$(basename $bd); seg=; for s in ext3000 prod; do [ -d $bd/$s ] && { seg=$s; break; }; done
  [ -z "$seg" ] && { echo -e "$b\t-\tNO_PROD\t-\t$(cat $bd/select/STATUS 2>/dev/null | head -c 120)" >> $M; continue; }
  a=$(ls -d $bd/$seg/attempt_* | sort | tail -1); st=$(head -c 200 $a/STATUS 2>/dev/null); d=$W/builds/$b/$seg; mkdir -p $d
  case "$st" in DONE*|TRUNC*|NUMERIC*) ;; *) echo -e "$b\t$seg\tRUNNING\t-\t${st:-no STATUS}" >> $M; continue;; esac
  cp $a/STATUS $d/; cp $a/SHA256_out.txt $d/ 2>/dev/null; tail -60 $(ls $a/*.log | grep -v part | head -1) > $d/md_tail.log 2>/dev/null
  lastgro $a $d
  fns="$FR_NS"; [ $seg = ext3000 ] && fns="$FR_NS_X"; frames $a $d "$fns"   # [R4N6] 0/200/.../1200 (prod) 或 1400/.../3000 (XEXT 续段; 0-1200 在 R4N5 小包里已有)
  sa=$(ls -d $bd/select/attempt_* 2>/dev/null | sort | tail -1); [ -n "$sa" ] && [ -s $sa/selected.gro ] && { mkdir -p $W/builds/$b/start; gzip -nc $sa/selected.gro > $W/builds/$b/start/selected.gro.gz; cp $sa/SELECTED_FRAME.txt $W/builds/$b/start/ 2>/dev/null; }   # [R4N6] 起点帧
  [ $seg = ext3000 ] && cp $(ls -d $bd/ext3000/attempt_* | sort | head -1)/EXT_SRC.txt $d/ 2>/dev/null
  echo -e "$b\t$(stat -c %Y $a/STATUS)" >> $W/.done_t
  ls $bd/select/attempt_*/gate_frames >/dev/null 2>&1 && { mkdir -p $W/builds/$b/select; cp -r $(ls -d $bd/select/attempt_* | sort | tail -1)/gate_frames $W/builds/$b/select/; cp $bd/select/STATUS $W/builds/$b/select/ 2>/dev/null; }
  echo -e "$b\t$seg\t${st%% *}\t$lf\t$nt" >> $M; done
for f in ledger slots runs.tsv RUN_META.txt; do [ -e $OUT/$f ] && cp -r $OUT/$f $W/; done
if [ "$COLLECT" != off ] && [ -n "$PKG" ]; then cs=OK; cn=-; export N6_INTERIM=$([ "$COLLECT" = 1 ] && echo 0 || echo 1); echo -e "_interim\t-\t$N6_INTERIM\t-\tCOLLECT=$COLLECT" >> $M
  $GATE_PY $PKG/verdict_N6_wrap.py collect $OUT --inputs $PKG/inputs --out $W/collect --jobs 2 > $W/collect.log 2>&1; rc=$?; echo "collect rc=$rc" >> $W/collect.log
  [ $rc = 0 ] && cn="$(grep '^wrote' $W/collect.log | tail -1 | cut -c1-120)" || { cs=FAIL; cn="rc=$rc: $(grep -v '^collect rc' $W/collect.log | tail -1 | cut -c1-160)"; }
  echo -e "_collect\t-\t$cs\t-\t$cn" >> $M
  [ $cs = OK ] && { $GATE_PY $PKG/verdict_N6_wrap.py judge $W/collect > $W/judge_N6.log 2>&1; echo -e "_judge_N6\t-\t$([ $? = 0 ] && echo OK || echo FAIL)\t-\t$(grep -m1 "总判" $W/judge_N6.log | cut -c1-120)" >> $M; }   # 收完顺手判 (只读 series, 判读草稿; 正式判读在 box 再跑一遍)
  if [ -n "$MACHINE" ] && ls -d $OUT/builds/*/ext3000 >/dev/null 2>&1; then   # [R4N6] XEXT: 本机有 ext3000 段才收
    $GATE_PY $PKG/tools/collect_xext.py --inputs $PKG/inputs --base $XEXT_BASE --runs $OUT --out $W/collect_xext --machine $MACHINE > $W/collect_xext.log 2>&1; rc=$?
    [ $rc = 0 ] && $GATE_PY $PKG/verdict_N6_wrap.py judge_xext $W/collect_xext > $W/judge_N6_xext.log 2>&1; rj=$?
    echo -e "_collect_xext\t-\t$([ $rc = 0 ] && echo OK || echo FAIL)\t-\trc=$rc judge_rc=$rj $(grep -m1 '总判' $W/judge_N6_xext.log 2>/dev/null | cut -c1-100)" >> $M; fi
  find $W/collect -name '*.xtc' -delete 2>/dev/null; else echo -e "_collect\t-\tSKIP\t-\tCOLLECT=$COLLECT PKG=${PKG:-空}" >> $M; fi
$PYH $PKG/tools/analysis_table.py $W > $W/analysis.log 2>&1; echo -e "_analysis\t-\t$([ $? = 0 ] && echo OK || echo FAIL)\t-\t$(tail -1 $W/analysis.log | cut -c1-100)" >> $M   # [R4N6]
( cd $W && find . -type f ! -name SHA256SUMS ! -name .done_t -print0 | sort -z | xargs -0 sha256sum > SHA256SUMS )
# [R4N6] 分包 + 上传顺序 (小在前大在后; build 按完成时刻). 内容 sha = 该 build 在 SHA256SUMS 里各行的 sha256 (与 tar 时间戳无关), 用于和以前各次比对.
U=$DEST/$tag.upload; mkdir -p $U; UO=$U/UPLOAD_ORDER.txt; echo -e "seq\tfile\tbytes\tsha256\tdone_t\tcontent_sha\tnote" > $UO; n=0
up(){ local f=$1 dt=$2 cs=$3 note=$4; n=$((n+1)); echo -e "$n\t$(basename $f)\t$(stat -c %s $f)\t$(sha256sum $f | cut -d' ' -f1)\t$dt\t$cs\t$note" >> $UO; }
tar -C $DEST -czf $U/00_summary_$tag.tar.gz $(cd $DEST && ls -d $tag/MANIFEST.tsv $tag/ANALYSIS.tsv $tag/runs.tsv $tag/RUN_META.txt $tag/judge_N6*.log $tag/collect/runs_status.tsv $tag/collect/VERDICT_N6.* $tag/collect/runs_N6.tsv $tag/collect_xext/runs_status_xext.tsv $tag/collect_xext/VERDICT_N6_XEXT.* $tag/collect_xext/runs_N6_xext.tsv 2>/dev/null) && up $U/00_summary_$tag.tar.gz - - "summary (最小, 先传)"
sort -t$'\t' -k2,2n $W/.done_t 2>/dev/null | while IFS=$'\t' read b dt; do
  cs=$(grep " ./builds/$b/" $W/SHA256SUMS | grep -v "\.log$" | cut -d' ' -f1 | sha256sum | cut -c1-16)
  prev=$(grep -l -P "\t$cs\t" $DEST/*.upload/UPLOAD_ORDER.txt 2>/dev/null | grep -v "^$UO$" | head -1)
  f=$U/b_$(printf %s $b | sed 's/^R4N1_//')_$tag.tar.gz
  tar -C $DEST -czf $f $(cd $DEST && ls -d $tag/builds/$b $tag/collect/series/$b.csv $tag/collect_xext/series_xext/$b.csv 2>/dev/null) && up $f "$(date -d @$dt '+%F %T %z')" $cs "${prev:+SAME_AS_PREV $(basename $(dirname $prev))}"
done; rm -f $W/.done_t
n=$(($(wc -l < $UO)-1)); tar -C $DEST -czf $DEST/$tag.tar.gz $tag && ( cd $DEST && sha256sum $tag.tar.gz > $tag.tar.gz.sha256 ) && up $DEST/$tag.tar.gz - - "全量 (最大, 最后传)"
echo "upload order: $UO ($(($(wc -l < $UO)-1)) 个文件)"; echo "small pack: $DEST/$tag.tar.gz ($(du -h $DEST/$tag.tar.gz | cut -f1)); $(awk -F'\t' 'NR>1{print $3}' $M | sort | uniq -c | tr '\n' ' ')"
