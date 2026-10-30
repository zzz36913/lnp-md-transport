#!/bin/bash
# interim_pull.sh (草稿, 包外; 不属于 R4N1 / R4N1x 包, 不进任何 MANIFEST)
# 用途: 中途回传 (21:00 前后). 只读运行目录, 只打包 "prod 已 DONE" 的条目的 prod*.xtc + prod.tpr + SHA256_out.txt.
# 用法: OUTDIR=<运行目录之外的目录> [LABEL=2100] [DRY=1] bash interim_pull.sh <run_dir> [<run_dir> ...]
#   run_dir = $J/R4N1_run_<机>_<TS> (主包) 或 $J/R4N1x_run_<机>_<TS> (追加包); 可一次给多个.
# 只读保证:
#   - 对 run_dir 只做 ls/cat/sha256sum/tar 读取; 不 mkdir、不写、不 touch、不改权限、不碰锁/HALT/GO/ledger.
#   - OUTDIR 必须在所有 run_dir 之外 (realpath 判), 否则拒绝. 输出文件已存在则拒绝 (不覆盖).
# DONE 判定 (与 lib 的 last_state 一致): builds/<b>/prod/ 下编号最大的 attempt_NNN 有 STATUS 且第一字段 = DONE.
#   - 最新 attempt 无 STATUS (= 正在跑) / 非 DONE (TRUNC/FAIL/...) -> 不打包, 只在清单里记原因.
#   - DONE 条目若是续跑 (多个 attempt, -noappend 分段), 把该 build 全部 prod attempt 的 prod*.xtc / prod.tpr / SHA256_out.txt 都打进去.
# 一致性: 打包前用各 attempt 自己的 SHA256_out.txt 校验其中列出的 xtc/tpr (sha256sum -c 只读); 任一不符 -> 该 build 整条不打包 (记 SHA_MISMATCH).
#   SHA256_out.txt 没列到的 xtc/tpr -> 该 build 不打包 (记 NOT_IN_SHA256_OUT), 防打进被改过/半写的文件.
# 打包期间再复核: tar 前后各取一次文件 size+mtime, 变了 -> 该 tar 作废改名 .VOID (不删), 退出码 3.
# 输出 (都在 OUTDIR): interim_<LABEL>_<TS>.tar (不压缩; xtc 本身已压缩), .files.tsv (每个打包文件 sha256/字节/所属 build),
#   .builds.tsv (每个 build 的判定与原因), .tar.sha256. 接收端: sha256sum -c *.tar.sha256; tar -xf 到空目录后
#   awk -F'\t' 'NR>1{print $1"  "$5}' <files.tsv> | sha256sum -c   (注意: SHA256_out.txt 里还列了未打包的 edr/log/cpt/gro, 不要直接对它 -c)
set -u
LABEL=${LABEL:-$(date +%H%M)}; TS=$(date +%m%d_%H%M%S); DRY=${DRY:-}
die(){ echo "ABORT: $*" >&2; exit 2; }
[ $# -ge 1 ] || die "至少给一个 run_dir"
[ -n "${OUTDIR:-}" ] || die "必须设 OUTDIR (运行目录之外)"
OD=$(realpath -m "$OUTDIR") || die "OUTDIR 不可解析"   # 先只算路径, 判完 "在运行目录之外" 才 mkdir (防在运行目录里建目录)
RUNS=()
for r in "$@"; do R=$(realpath -e "$r") || die "run_dir 不存在: $r"
  [ -d "$R/builds" ] || die "$R 不是运行目录 (无 builds/)"
  case "$OD/" in "$R"/*) die "OUTDIR=$OD 在运行目录 $R 之内 -> 拒绝";; esac
  case "$R/" in "$OD"/*) die "运行目录 $R 在 OUTDIR=$OD 之内 -> 拒绝";; esac
  RUNS+=("$R"); done
mkdir -p "$OD" || die "无法创建 OUTDIR=$OD"; [ "$(realpath -e "$OD")" = "$OD" ] || die "OUTDIR 解析前后不一致 (符号链接?)"
BASE=$OD/interim_${LABEL}_$TS; TAR=$BASE.tar; FL=$BASE.files.tsv; BL=$BASE.builds.tsv; LST=$BASE.list
for f in $TAR $FL $BL $LST $TAR.sha256; do [ -e "$f" ] && die "$f 已存在, 不覆盖"; done
printf 'run\tbuild\tdecision\tlast_attempt\tstatus\tn_attempts\tnote\n' > $BL
printf 'sha256\tbytes\trun\tbuild\tpath_in_tar\n' > $FL
: > $LST; npk=0
for R in "${RUNS[@]}"; do P=$(dirname "$R"); RN=$(basename "$R")
  for bd in $(ls -1d "$R"/builds/*/ 2>/dev/null | sort); do bd=${bd%/}; b=$(basename "$bd"); pd=$bd/prod
    atts=$(ls -1d "$pd"/attempt_[0-9][0-9][0-9] 2>/dev/null | sort); na=$(echo "$atts" | grep -c .)
    [ "$na" -gt 0 ] || { printf '%s\t%s\tSKIP\t-\t-\t0\tno_prod_attempt\n' "$RN" "$b" >> $BL; continue; }
    last=$(echo "$atts" | tail -1)
    if [ ! -f "$last/STATUS" ]; then printf '%s\t%s\tSKIP\t%s\tRUNNING_OR_NO_STATUS\t%s\tnot_touched\n' "$RN" "$b" "$(basename $last)" "$na" >> $BL; continue; fi
    st=$(cut -d' ' -f1 "$last/STATUS")
    [ "$st" = DONE ] || { printf '%s\t%s\tSKIP\t%s\t%s\t%s\tnot_DONE\n' "$RN" "$b" "$(basename $last)" "$st" "$na" >> $BL; continue; }
    ok=1; note=ok; files=()
    for a in $atts; do [ -f "$a/STATUS" ] || { ok=0; note="attempt_without_STATUS:$(basename $a)"; break; }
      [ -s "$a/SHA256_out.txt" ] || { [ "$a" = "$last" ] && { ok=0; note="no_SHA256_out_in_last"; break; }; continue; }   # 早期失败 attempt 可能没有 SHA256_out
      ( cd "$a" && sha256sum -c --quiet --status SHA256_out.txt ) || { ok=0; note="SHA_MISMATCH:$(basename $a)"; break; }
      for f in $(cd "$a" && ls -1 prod*.xtc prod.tpr 2>/dev/null); do
        awk -v f="$f" '{sub(/^\*/,"",$2)} $2==f{x=1} END{exit !x}' "$a/SHA256_out.txt" || { ok=0; note="NOT_IN_SHA256_OUT:$(basename $a)/$f"; break 2; }
        files+=("$a/$f"); done
      files+=("$a/SHA256_out.txt"); done
    [ $ok = 1 ] && ! printf '%s\n' "${files[@]}" | grep -q '\.xtc$' && { ok=0; note="DONE_but_no_xtc"; }
    [ $ok = 1 ] && ! printf '%s\n' "${files[@]}" | grep -q '/prod\.tpr$' && { ok=0; note="DONE_but_no_tpr"; }
    if [ $ok = 0 ]; then printf '%s\t%s\tREFUSE\t%s\t%s\t%s\t%s\n' "$RN" "$b" "$(basename $last)" "$st" "$na" "$note" >> $BL; continue; fi
    printf '%s\t%s\tPACK\t%s\t%s\t%s\t%s\n' "$RN" "$b" "$(basename $last)" "$st" "$na" "$note" >> $BL
    for f in "${files[@]}"; do rel=${f#$P/}; printf '%s\t%s\n' "$P" "$rel" >> $LST
      printf '%s\t%s\t%s\t%s\t%s\n' "$(sha256sum "$f" | cut -d' ' -f1)" "$(stat -c %s "$f")" "$RN" "$b" "$rel" >> $FL; npk=$((npk+1)); done
  done; done
echo "== interim_pull label=$LABEL runs=${#RUNS[@]} 打包文件=$npk 字节=$(awk -F'\t' 'NR>1{s+=$2} END{print s+0}' $FL)"
awk -F'\t' 'NR>1{c[$3]++} END{for(k in c) printf "   %s=%d", k, c[k]; print ""}' $BL
[ "$npk" -gt 0 ] || { echo "无 DONE 条目, 不建 tar"; exit 0; }
[ -n "$DRY" ] && { echo "DRY=1: 只出清单, 不建 tar ($FL $BL)"; exit 0; }
TMPD=$(mktemp -d "$OD/.interim_tmp_XXXX") || die "mktemp 失败"   # 只在 OUTDIR 里
snap(){ while IFS=$'\t' read -r p rel; do stat -c '%s %Y %n' "$p/$rel"; done < $LST; }
snap > $TMPD/before.txt
# 按 run 的父目录分组 tar (同一父目录一次 -C); 先建空 tar 再 -r 追加
tar -cf $TAR --files-from /dev/null || die "建 tar 失败"
for p in $(cut -f1 $LST | sort -u); do awk -F'\t' -v p="$p" '$1==p{print $2}' $LST > $TMPD/rel.txt
  tar -rf $TAR -C "$p" --no-recursion --files-from $TMPD/rel.txt || die "tar 追加失败 ($p)"; done
snap > $TMPD/after.txt
if ! cmp -s $TMPD/before.txt $TMPD/after.txt; then mv $TAR $TAR.VOID; echo "VOID: 打包期间源文件变了 -> $TAR.VOID (未删)"; diff $TMPD/before.txt $TMPD/after.txt | head; exit 3; fi
n_in=$(tar -tf $TAR | grep -c .); [ "$n_in" = "$npk" ] || { mv $TAR $TAR.VOID; echo "VOID: tar 内 $n_in 个 != 清单 $npk"; exit 3; }
( cd $OD && sha256sum $(basename $TAR) $(basename $FL) $(basename $BL) > $(basename $TAR).sha256 )
mv $TMPD $OD/_superseded_interim_tmp_$TS   # 不删, 只挪开
echo "OK: $TAR"; cat $TAR.sha256
