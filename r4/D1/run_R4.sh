#!/bin/bash
# run_R4.sh -- R4 D1 菜谱扫描 (4 体系 DOPE/DOPC/MC3H/MC3 × 2 水合 × N=3, 全片层起点) 正式发车: 一台 Spark 一个实例. 由 R3_launch/run_R3.sh 改写. 两个槽 (A pin 15 / B pin 5, NT=5) 共用一个用户态 MPS 守护.
# 流水线 (每个 build): relax 15 ns -> 起点资格闸 (t0_gate prod0, 2/2/2/2 @0.65/0.75/0.95, v1==v2) -> prod (PR 各向异性 tau_p=12, nstpcouple=3, v-rescale; lam 2 µs / hii 1 µs)
#   闸不合格 = VOID_BUILD (L2): 不是事件/不是删失, 不进 prod, 进替补账本. 替补只看起点读数, 不看 prod 结果.
# 用法:  bash run_R4.sh <k03|k04>                  正式 (先过发车判据 launch_guard, 不过则 ABORT)
#        CHECK=1 bash run_R4.sh <机>               只跑发车判据 (含 60 s 复查), 不建输出目录/不起 MPS/容器
#        DRY=1 bash run_R4.sh <机>                 只打印计划+时间判断, 不建输出/不起 MPS/容器
#        APPEND_TO=<R4_run_目录> bash run_R4.sh <机>   同机续跑 (只追加新 attempt; DONE 的步骤跳过; TRUNC 的 prod 用 -noappend 续)
# 关键 env (默认值见 lib_R4.sh; README_R4_D1.md 有总表):
#   RELAX_ARM=crescale_dev|literal  MAXWARN_RELAX=0 (literal 才可为 2, 另需 K_APPROVED_LITERAL=yes)  MAXWARN_PROD=0 (非 0 即 ABORT)
#   DEADLINE="2026-10-30 07:30 +0800"  F_THR=1.0 / PERF_NOM=13800 @12240 珠 (按珠数缩放) / $J/R4_perf_override.env  PRIO=low|raised (吞吐 f 读取位置)  SUPP=1 SUPP_MARGIN_H=0.75
#   GATE_MODE=host|manual GATE_PY=python3  REPLACE_ON_RELAX_FAIL=1  MODE=docker|local  J=$HOME/R4  MPSROOT=$HOME/mps_R4
# 不覆写/不 rm: 输出 $J/R4_run_<机>_<TS>/ (已存在则 ABORT); builds/<build>/<relax|gate|prod>/attempt_NNN/ (mkdir 原子, STATUS 只写一次); ALL_RECORDS.tsv 只 >>.
# [TRR-AMEND 2026-10-28] 起点规则: relax 写 trr, 末 5 ns 逐帧同一闸门取最后合格帧作 prod -c; 见 PRE_REG_AMENDMENT_R3_trr.md / lib_R4.sh step_select. 开关 SEL_RULE=1|0 SEL_NSTOUT SEL_WIN_PS SEL_KEEP_FRAMES
# R4 改动未在 Spark/2026.3 上实测 (R3 原链已实跑); 见 README_R4_D1.md.
HERE=$(cd "$(dirname "$0")" && pwd); MACHINE=${1:?usage: bash run_R4.sh <k03|k04>}; ORCH_PID=$$
case $MACHINE in k03|k04) ;; *) echo "ABORT: 机器名须为 k03 或 k04"; exit 1;; esac
. "$HERE/lib_R4.sh"
REFB=$(rdlines0(){ grep -vE '^\s*(#|$)' "$1" | awk '{print $1}'; }; rdlines0 $HERE/chains/${MACHINE}_A.txt | head -1)   # 自检/估时参考 build = A 链第一条
CA=$HERE/chains/${MACHINE}_A.txt; CB=$HERE/chains/${MACHINE}_B.txt; SPARES=$HERE/chains/spares_${MACHINE}.txt; SUPPQ=$HERE/chains/supp_${MACHINE}.txt
rdlines(){ [ -f "$1" ] && grep -vE '^\s*(#|$)' "$1" | awk '{print $1}'; }
# ------------------------------------------------------------------ 发车判据 (R2b REVIEW §4 同款多条件 + R3 专项)
f(){ echo "  [FAIL] $*"; bad=1; }; p(){ echo "  [ok]   $*"; }
launch_guard(){ local b x dup P n2; bad=0
  echo "== launch_guard machine=$MACHINE MODE=$MODE $(date '+%F %T %z')"
  # 1 包完整
  ( cd $HERE && sha256sum -c MANIFEST_sha256.txt --quiet ) >/dev/null 2>&1 && p "MANIFEST sha256 全 OK" || f "包与 MANIFEST_sha256.txt 不符 (cd $HERE && sha256sum -c MANIFEST_sha256.txt)"
  # 2 参数/开关
  [ "$MAXWARN_PROD" = 0 ] && p "MAXWARN_PROD=0" || f "MAXWARN_PROD=$MAXWARN_PROD (须 0; prod 警告须看见, 非 0 需改包)"
  case $RELAX_ARM in
    crescale_dev) [ "$MAXWARN_RELAX" = 0 ] && p "RELAX_ARM=crescale_dev (偏离 SI 协议的开发臂), MAXWARN_RELAX=0" || f "crescale_dev 不需要 maxwarn, MAXWARN_RELAX=$MAXWARN_RELAX 须 0";;
    literal) if [ "$K_APPROVED_LITERAL" = yes ] && [ "$MAXWARN_RELAX" = 2 ]; then p "RELAX_ARM=literal, K_APPROVED_LITERAL=yes, MAXWARN_RELAX=2 (逐字核对 2 条警告; 不符则 HALT)"; else f "literal 须同时 K_APPROVED_LITERAL=yes 且 MAXWARN_RELAX=2 (现 '$K_APPROVED_LITERAL'/$MAXWARN_RELAX)"; fi;;
    *) f "RELAX_ARM=$RELAX_ARM 非法";; esac
  if [ -n "${NSTEPS_OVERRIDE_RELAX}${NSTEPS_OVERRIDE_PROD}" ]; then [ "$MODE" = local ] && p "NSTEPS_OVERRIDE_* 已设 (MODE=local 冒烟)" || f "NSTEPS_OVERRIDE_* 只允许 MODE=local"; else p "无 nsteps 覆盖"; fi
  [ -z "${ALLOW_BUSY:-}" ] && p "未设 ALLOW_BUSY" || f "ALLOW_BUSY 已设 (本包不接受)"
  # 3 时间窗
  if [ "$(rem_s)" -gt 0 ]; then p "距 DEADLINE($DEADLINE) 剩 $(rem_h) h"; else f "已过 DEADLINE"; fi
  P=$(perf_eff); n2=$(need_h $REFB)
  echo "  [info] 有效速率 ${P} ns/day/槽 (PERF_NOM=$PERF_NOM F_THR=$F_THR; 估计非实测), 一条 $REFB (relax+闸+prod, 珠数缩放, 估算) 约需 ${n2} h; 剩余 $(rem_h) h ->" \
        "$(awk -v r=$(rem_h) -v n=$n2 -v t=$TAIL_H 'BEGIN{ if(r-t>=n) print "主批第 1 波可完整跑满"; else print "第 1 波 prod 会被 -maxh 截断; 用 NSTEPS 更短的包或向 K 报告"}')"
  # 4 输入/链
  need_cmd || bad=1
  for b in $(rdlines $CA; rdlines $CB; rdlines $SPARES; rdlines $SUPPQ); do valid_name $b || { f "链/替补/补跑里有非法 build 或缺 expect.env: $b"; continue; }
    for x in start.gro sys.top index.ndx relax_$RELAX_ARM.mdp prod_$(arm_of $b).mdp; do [ -s $INP/$b/$x ] || f "缺 $INP/$b/$x"; done; done
  for x in $(grep -E '^#include' $INP/$REFB/sys.top | sed 's/.*"\(.*\)".*/\1/'); do [ -s $FF/$x ] || f "缺力场 $FF/$x"; done
  [ -n "$(rdlines $CA)" ] && [ -n "$(rdlines $CB)" ] && p "chains: A=$(rdlines $CA | wc -l) 条 B=$(rdlines $CB | wc -l) 条 spares=$(rdlines $SPARES | wc -l) 补跑队列=$(rdlines $SUPPQ | wc -l)" || f "缺链文件"
  dup=$( (rdlines $CA; rdlines $CB; rdlines $SPARES; rdlines $SUPPQ) | sort | uniq -d | tr '\n' ' '); [ -z "$dup" ] && p "链/替补/补跑无重复 build" || f "重复 build: $dup"
  dup=$(for x in $HERE/chains/*.txt; do rdlines $x; done | sort | uniq -d | tr '\n' ' '); [ -z "$dup" ] && p "两机全部 chains/spares/supp 文件之间无同一 build 重复 (账本只按机, 跨机重复会被当成 2 个独立重复实验)" || f "跨机重复 build: $dup"
  # 5 进程/容器/MPS 冲突 (R2b M1: 60 s 复查; 不抢占)
  if [ "$MODE" = docker ]; then
    [ "$(pgrep -c gmx)" = 0 ] && p "pgrep gmx 为空" || f "已有 gmx 进程: $(pgrep -a gmx | head -3 | tr '\n' ';')"
    x=$(procs_other $$ 'R2a_machine|R2a_slot|R2b_machine|R2b_slot|run_R2|run_prerun|preflight_R3|run_R3\.sh|run_R4\.sh'); [ -z "$x" ] && p "无 R2a/R2b/prerun/run_R3/其它 run_R4 脚本进程 (已排除本进程及其祖先/后代)" || f "有相关脚本进程: $(echo "$x" | head -3 | tr '\n' ';')"
    if [ -n "${HAVE_LOCK:-}" ]; then p "已持有 flock $J/.R4_${MACHINE}.flock"; elif test_lock; then p "flock 可得 (无同机 run_R4 在跑)"; else f "flock 被占用: 同机已有 run_R4 在跑"; fi
    [ -z "$(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^(R2a_|R2b_|R3|R4_|j009_)')" ] && p "docker ps 无 R2a_/R2b_/R3*/R4_/j009_ 容器" || f "有占卡容器: $(docker ps --format '{{.Names}}' | grep -E '^(R2a_|R2b_|R3|R4_|j009_)' | tr '\n' ' ')"
    [ -z "$(pgrep -a nvidia-cuda-mps)" ] && p "无 nvidia-cuda-mps 进程" || f "已有 MPS 进程: $(pgrep -a nvidia-cuda-mps | tr '\n' ';') (上一批未收尾?)"
    [ -z "$(ls -A ${MPSROOT:-$HOME/mps_R4} 2>/dev/null)" ] && p "MPSROOT=${MPSROOT:-$HOME/mps_R4} 为空/不存在" || f "MPSROOT 非空"
    if [ $bad = 0 ]; then echo "  ... ${GUARD_RECHECK_S:-60}s 后复查 (R2b M1: 空档漏报)"; sleep ${GUARD_RECHECK_S:-60}; [ "$(pgrep -c gmx)" = 0 ] && p "60 s 后 pgrep gmx 仍为空" || f "60 s 后出现 gmx 进程"; fi
    x=$(df -Pk "$(dirname $J)" 2>/dev/null | awk 'NR==2{printf "%d",$4/1048576}'); [ "${x:-0}" -ge 5 ] && p "磁盘可用 ${x} GiB" || f "磁盘可用 ${x:-?} GiB < 5"
  else echo "  [info] MODE=local: 跳过 gmx/容器/MPS/磁盘冲突检查 (仅 box 冒烟)"; fi
  # 5b [TRR-AMEND] 取起点规则自检: 参数 + 容器内 trjconv 经 stdin (-i) 取组号能跑通 (用 start.gro 当 1 帧 "轨迹")
  if [ "$SEL_RULE" = 1 ]; then [ "$GATE_MODE" = host ] && p "SEL_RULE=1 取起点规则: relax 每 ${SEL_NSTOUT} 步写 trr, 末 ${SEL_WIN_PS} ps 逐帧闸门, 选最后合格帧 (SEL_KEEP_FRAMES=$SEL_KEEP_FRAMES)" || echo "  [warn] SEL_RULE=1 但 GATE_MODE=$GATE_MODE: 无自动逐帧闸门, 回退旧行为 (末帧+-t cpt)"
    case "$SEL_NSTOUT$SEL_WIN_PS" in *[!0-9]*|"") f "SEL_NSTOUT/SEL_WIN_PS 须为整数";; esac
  else echo "  [warn] SEL_RULE=0: 旧行为 (relax 末帧 + -t relax.cpt), 与已作废的预跑 0/6 读数同款起点, 不建议"; fi
  # 6 gmx 版本 + 闸门可执行 (真跑一次 builder 级闸门, 期望 PASS)
  GMXV=$(gmx_version); [ -n "$GMXV" ] && check_gmxv && p "gmx 版本 $GMXV" || f "gmx 版本检查失败 ('$GMXV', 期望 ${EXPECT_GMX:-2026.3})"
  if [ "$GATE_MODE" = host ]; then
    $GATE_PY -c 'import numpy, scipy, MDAnalysis' >/dev/null 2>&1 && p "闸门依赖 numpy/scipy/MDAnalysis 可导入 ($GATE_PY)" || f "GATE_PY=$GATE_PY 导不进 numpy/scipy/MDAnalysis (设 GATE_PY=<含依赖的 python>, 或 GATE_MODE=manual)"
    x=$(mktemp -d); ( cd $x && $GATE_PY $HERE/gate/t0_gate_launch.py $INP/$REFB/start.gro --level builder --arm lam --expect-lipids $(exp_of $REFB EXP_LIP) --expect-w $(exp_of $REFB EXP_W) --json g.json ) >/dev/null 2>&1 && p "闸门自检: $REFB/start.gro PASS (rc=0)" || f "闸门自检失败 (应 PASS)"
    ( cd $x && $GATE_PY $HERE/gate/t0_gate_launch.py $HERE/proof/neg_selftest_bridged.gro --level builder --arm lam --expect-lipids 960 --expect-w 720 --json h.json ) >/dev/null 2>&1 && f "闸门负自检: 已知桥连帧竟 PASS" || p "闸门负自检: 已知桥连帧 (R3 DOPC relax 末帧) 判不合格 rc!=0"
  else p "GATE_MODE=manual: 须有人在 $OUT/manual_gate/<build>.PASS|.VOID 放闸门结论 (每条 relax 后最长等 ${GATE_WAIT_MAX_H} h)"; fi
  if [ "$SEL_RULE" = 1 ]; then x=$OUT/seltest_$$; mkdir -p $x; ( cd $x && echo 0 | GXI=1 CN=$(cn_name seltest_$BASHPID) gx trjconv -f $INP/$REFB/start.gro -s $INP/$REFB/start.gro -sep -o t.gro ) > $x/trjconv.log 2>&1
    [ -n "$(ls $x/t*.gro 2>/dev/null)" ] && p "trjconv(stdin 组号) 自检通过" || f "trjconv 自检失败 (docker run -i / gmx trjconv?): $x/trjconv.log"; fi
  # 5c 两槽同时 grompp 自检 (真发车时两槽的第 1 条 build 会同时 grompp relax; 这里用各槽首条 build 同时跑, 验容器名不撞/2026.3 能 grompp 派生 mdp; 只写 $OUT/gpchk, 不 mdrun)
  y=$OUT/gpchk; mkdir -p $y; gpp=; for t in "chkA $(rdlines $CA | head -1)" "chkB $(rdlines $CB | head -1)"; do set -- $t
    ( SLOT_TAG=$1; b=$2; dd=$y/$1/$b/attempt_001; mkdir -p $dd; mdp=$dd/relax_$RELAX_ARM.mdp
      if [ "$SEL_RULE" = 1 ] && [ "$(arm_of $b)" = lam ]; then awk '!($1=="nstxout"||$1=="nstvout")' $INP/$b/relax_$RELAX_ARM.mdp > $mdp; printf 'nstxout = %s\nnstvout = %s\n' $SEL_NSTOUT $SEL_NSTOUT >> $mdp; else cp $INP/$b/relax_$RELAX_ARM.mdp $mdp; fi
      gp $dd relax $mdp $INP/$b/start.gro $INP/$b/sys.top $INP/$b/index.ndx $MAXWARN_RELAX; echo "$GP_RC $GP_NW" > $dd/gp_rc_nw.txt ) & gpp="$gpp $!"; done; wait $gpp
  for t in chkA chkB; do r=$(cat $y/$t/*/attempt_001/gp_rc_nw.txt 2>/dev/null); if [ "$RELAX_ARM" = crescale_dev ]; then [ "$r" = "0 0" ] && p "两槽同时 grompp 自检 $t: rc=0 无 warning" || f "两槽同时 grompp 自检 $t 失败 (rc nwarn='$r'): $y/$t/*/attempt_001/grompp.log"
    else [ "${r%% *}" = 0 ] && p "两槽同时 grompp 自检 $t: rc=0 (literal, nwarn=${r#* })" || f "两槽同时 grompp 自检 $t 失败 ('$r'): $y/$t/*/attempt_001/grompp.log"; fi; done
  [ $bad = 0 ] && { echo "== launch_guard: ALL OK"; return 0; } || { echo "== launch_guard: FAIL (见 [FAIL])"; return 1; }; }
# ------------------------------------------------------------------ 补跑队列 (主批 10 条后空槽接活; 严格按下列优先级, 每个作业须过时间判断)
# 优先级: (1) L2 替补轮: 本机账本里有 VOID_L2 (或 relax 失败, 见 REPLACE_ON_RELAX_FAIL) 的格, 取 spares_<机>.txt 里同格未用的替补 build, 再 relax+gate+prod
#         (2) chains/supp_<机>.txt 按文件顺序 (R4: 默认空; 见 README_R4_D1.md).
# 时间判断 supp_fits: 剩余墙钟 >= need_h + SUPP_MARGIN_H(0.75=45min) 且 now+need_h < DEADLINE; 不过则记 SUPP_SKIP_NO_TIME 并看下一个候选 (更短的作业可能放得下).
supp_fits(){ local b=$1 n; n=$(need_h $b); SUPP_NEED=$n
  awk -v r=$(rem_h) -v n=$n -v m=$SUPP_MARGIN_H 'BEGIN{exit !(r>=n+m)}' && [ $(( $(date +%s) + $(awk -v n=$n 'BEGIN{printf "%d", n*3600}') )) -lt $DL ]; }
claim_supp(){ local cell v s line b; CLAIM_B=; CLAIM_ROLE=; CLAIM_NOTE=; halted && return 1
  for cell in $(for b in $(rdlines $CA; rdlines $CB; rdlines $SPARES); do cell_of $b; done | sort -u); do
    for v in $(ledger_list void | grep -E "^R4_${cell%_w*}_${cell#*_}_"); do ledger_has replfor $v && continue
      for s in $(rdlines $SPARES | grep -E "^R4_${cell%_w*}_${cell#*_}_lam_"); do ledger_has claim $s && continue
        supp_fits $s || { ledger_claim skipnote ${SLOT_TAG}.$s && rec skip $s repl - - SUPP_SKIP_NO_TIME - - - - - - $SUPP_NEED "替补(for $v) 剩余不足 need+${SUPP_MARGIN_H}h"; continue; }
        ledger_claim replfor $v || continue; ledger_claim claim $s || { rmdir $OUT/ledger/replfor/$v; continue; }
        CLAIM_B=$s; CLAIM_ROLE=replacement; CLAIM_NOTE="replaces=$v"; return 0; done
      [ -n "$(rdlines $SPARES | grep -E "^R4_${cell%_w*}_${cell#*_}_lam_")" ] || { ledger_claim noted nospare_$v && { rec skip $v repl - - NO_SPARE - - - - - - - "格 $cell 无替补 build -> 该格 N<3, 按 PREREG_R4 记 NOT_EVALUABLE 或 K 决策"; say "NO_SPARE: $v 无替补"; }; }
    done; done
  for b in $(rdlines $SUPPQ); do ledger_has claim $b && continue
    supp_fits $b || { ledger_claim skipnote ${SLOT_TAG}.$b && rec skip $b supp - - SUPP_SKIP_NO_TIME - - - - - - $SUPP_NEED "补跑剩余不足 need+${SUPP_MARGIN_H}h"; continue; }
    ledger_claim claim $b || continue; CLAIM_B=$b; CLAIM_ROLE=supplement; CLAIM_NOTE="queue=$(basename $SUPPQ)"; return 0; done
  return 1; }
slot(){ local tag=$1 po=$2 ch=$3 b
  SLOT_TAG=$tag; say "== slot start chain=$ch pinoffset=$po NT=$NT deadline=$DEADLINE gate=$GATE_MODE relax=$RELAX_ARM"
  for b in $(rdlines $ch); do ledger_claim claim $b; run_build $b primary $po main; say "END $b rc=$?"; done
  if [ "$SUPP" = 1 ]; then while claim_supp; do say "补跑领取 $CLAIM_B ($CLAIM_ROLE $CLAIM_NOTE) need=${SUPP_NEED}h remaining=$(rem_h)h"; run_build $CLAIM_B $CLAIM_ROLE $po supp "$CLAIM_NOTE"; say "END $CLAIM_B rc=$?"; done; fi
  say "== slot end"; }
summary(){ echo "== summary $MACHINE $(date '+%F %T %z')"; printf 'build\trelax\tgate\tprod\n'
  for d in $OUT/builds/*/; do b=$(basename $d); printf '%s\t%s\t%s\t%s\n' $b $(last_state $d/relax) $(last_state $d/gate) $(last_state $d/prod); done | tee $OUT/SUMMARY.tsv
  for c in $(for b in $(rdlines $CA; rdlines $CB; rdlines $SPARES); do cell_of $b; done | sort -u); do v=$(ledger_list void | grep -c "^R4_${c%_w*}_${c#*_}_"); g=$(ls -d $OUT/builds/R4_${c%_w*}_${c#*_}_lam_*/gate 2>/dev/null | wc -l); echo "L2 void_rate $c(本机, lam): $v / $g 个已读闸 (L1 见 inputs/L1_summary.tsv)"; done | tee -a $OUT/SUMMARY.tsv
  for v in $(ledger_list void); do ledger_has replfor $v || echo "UNRESOLVED_VOID $v (无替补/时间不足 -> 该格 n 减少, 报告里按 PREREG_R4 NOT_EVALUABLE/n<3 处理)"; done | tee -a $OUT/SUMMARY.tsv; }
# ------------------------------------------------------------------ main
if [ -n "${CHECK:-}" ]; then OUT=/tmp/R4_check_$$; mkdir -p $OUT/slots; OUT_PARENT=$OUT; launch_guard; exit $?; fi
if [ -n "${DRY:-}" ]; then
  OUT=$(mktemp -d /tmp/R4_dry_XXXXXX); OUT_PARENT=$OUT; mkdir -p $OUT/slots $OUT/ledger; SLOT_TAG=dry; GMXV=dry
  echo "== DRY machine=$MACHINE MODE=$MODE relax=$RELAX_ARM maxwarn(relax/prod)=$MAXWARN_RELAX/$MAXWARN_PROD deadline=$DEADLINE remaining=$(rem_h)h P=$(perf_eff) ns/day (PERF_NOM=$PERF_NOM F_THR=$F_THR) 不建输出/不起 MPS/容器"
  for t in "A $PINA $CA" "B $PINB $CB"; do set -- $t; t0=$(date +%s); echo "-- slot ${MACHINE}_$1 pin=$2 (顺序执行)"
    for b in $(rdlines $3); do n=$(need_h $b); st=$(date -d @$t0 '+%m-%d %H:%M'); t0=$((t0+$(awk -v n=$n 'BEGIN{printf "%d", n*3600}'))); echo "   $b need=${n}h  预计 $st -> $(date -d @$t0 '+%m-%d %H:%M')  $(awk -v t=$t0 -v d=$DL 'BEGIN{print (t+0>d+0)?"[超 deadline: 会被 -maxh 截断/SKIP]":""}')"
      echo "      [TRR-AMEND] SEL_RULE=$SEL_RULE (lam): relax 加 nstxout=nstvout=$SEL_NSTOUT -> 末 ${SEL_WIN_PS}ps trr 帧逐帧闸门 -> 选最后合格帧作 prod -c (无 -t); 0 合格 -> VOID_L2"; echo "      relax: grompp -f relax_$RELAX_ARM.mdp -c start.gro -maxwarn $MAXWARN_RELAX; mdrun | gate($GATE_MODE) | prod: $( [ "$SEL_RULE" = 1 ] && [ "$(arm_of $b)" = lam ] && echo "grompp -f prod_lam.mdp -c selected.gro (无 -t; 起点 sha 须与闸门判过的一致, 否则 VOID_SEL_MISMATCH; SEL_SKIP 时回退 -c relax.gro -t relax.cpt)" || echo "grompp -f prod_$(arm_of $b).mdp -c relax.gro -t relax.cpt" ) -maxwarn $MAXWARN_PROD; mdrun -maxh=(剩余-${TAIL_H}h)"; done; done
  echo "-- 补跑队列 (SUPP=$SUPP; 各作业此刻的时间判断; 实际领取发生在槽主链结束时, 此处按 '现在' 评估):"
  for b in $(rdlines $SPARES) $(rdlines $SUPPQ); do supp_fits $b && r=FITS || r=SKIP_NO_TIME; echo "   $b need=${SUPP_NEED}h rem=$(rem_h)h margin=${SUPP_MARGIN_H}h -> $r"; done
  echo "   (优先级: 1 L2 替补[spares: $(rdlines $SPARES | tr '\n' ' ')] -> 2/3 supp 队列顺序 [$(rdlines $SUPPQ | tr '\n' ' ')]; A3/E1d 永不入队)"
  exit 0; fi
need_cmd || exit 1
take_lock || { echo "ABORT: 同机 run_R4 已在运行 (flock $J/.R4_${MACHINE}.flock)"; exit 1; }; HAVE_LOCK=1
init_out $MACHINE || exit 1; exec > >(tee -a $OUT/orchestrator.log) 2>&1
echo "OUT=$OUT"; launch_guard || { echo "ABORT: 发车判据不过, 未起 MPS/容器"; exit 1; }
GMXV=${GMXV:-unknown}
{ echo "machine=$MACHINE host=$(hostname) start=$(date '+%F %T %z') deadline=$DEADLINE gmx=$GMXV mode=$MODE"; env | grep -E '^(RELAX_ARM|MAXWARN_|K_APPROVED|F_THR|PERF_NOM|GATE_|SUPP|REPLACE_|SEL_|NT=|PINA|PINB|TAIL_H|MINRUN_H|IMG=|J=|EXPECT_GMX|PRIO|PERF_)' | sort; echo "PRIO=$PRIO NICE=$NICE CPUSH=$CPUSH"; (cd $HERE && sha256sum run_R4.sh lib_R4.sh MANIFEST_sha256.txt); } > $OUT/RUN_META.txt
mps_start || exit 1
cleanup(){ echo "[$(date '+%F %T')] INTERRUPT/EXIT: 只停本脚本容器 ${CN_PREFIX}${MACHINE}_${ORCH_PID}_*"; [ "$MODE" = local ] || { for c in $(docker ps --format '{{.Names}}' | grep "^${CN_PREFIX}${MACHINE}_${ORCH_PID}_"); do docker stop -t 120 $c >/dev/null 2>&1; done; }; }
trap 'cleanup; kill $PA $PB 2>/dev/null; wait $PA $PB 2>/dev/null; mps_stop; exit 143' INT TERM
( slot ${MACHINE}_A $PINA $CA ) & PA=$!
( slot ${MACHINE}_B $PINB $CB ) & PB=$!
wait $PA $PB; mps_stop; summary; echo "== machine $MACHINE done $(date '+%F %T %z') OUT=$OUT"
