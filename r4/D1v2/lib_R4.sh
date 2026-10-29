#!/bin/bash
# lib_R4.sh -- R4 D1v2 菜谱扫描发车包公共函数 (被 run_R4.sh source). 由 R3_launch/lib_R3.sh 改写 (R3 已在 k03/k04 + gmx 2026.3 实跑过 relax/select/gate/prod 全链).
# R4 改动 (只列改动): 名字 R4_<DOPE|DOPC|MC3H|MC3>_h<050|100>_lam_s<k> (D1v2: h=相对水合度%); 闸门期望组成读 inputs/<b>/expect.env (不再写死 960/720); 速率按珠数缩放;
#   PRIO=low|raised 优先级开关; 默认 DEADLINE 2026-10-30 07:30 +0800; 容器前缀 R4_; 输出 $HOME/R4. 判据/阈值/选帧规则 (末 5 ns 最后合格帧) 与 R3 相同.
# 硬约束: 只用 gmx + 用户态 MPS; 不碰 GLM/ZCode/任何端口/key; 不独占显存/不重启 (须 K 批); 只 stop 本脚本起的 R4_<机>_<pid>_* 容器; 不 rm 任何东西; 旧 attempt 永不覆写.
export PYTHONDONTWRITEBYTECODE=1
HERE=${HERE:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
INP=$HERE/inputs; FF=$INP/ff
MODE=${MODE:-docker}                       # docker (Spark) | local (box 冒烟: GMX_LOCAL)
IMG=${IMG:-ghcr.io/novomcp/gromacs-md:spark}; G=${G:-/usr/local/gromacs/bin/gmx}
GMX_LOCAL=${GMX_LOCAL:-gmx}
NT=${NT:-5}; PINA=${PINA:-15}; PINB=${PINB:-5}
J=${J:-$HOME/R4}                           # 输出根; 实际输出 $J/R4_run_<机>_<TS>
DEADLINE=${DEADLINE:-"2026-10-30 07:30 +0800"}   # 显式 +0800, 不依赖 Spark 的 TZ
# ---- 逐步 maxwarn: 默认 0; 只有下面两个变量, 无其它旁路 ----
MAXWARN_RELAX=${MAXWARN_RELAX:-0}          # relax 步 (crescale_dev 必须 0; literal 须 2 且 K_APPROVED_LITERAL=yes)
MAXWARN_PROD=${MAXWARN_PROD:-0}            # prod 步 (必须 0, 非 0 则 ABORT: 需改包而不是改变量)
RELAX_ARM=${RELAX_ARM:-crescale_dev}       # crescale_dev (默认, 偏离 SI 协议) | literal (Berendsen, 需 K 批准)
K_APPROVED_LITERAL=${K_APPROVED_LITERAL:-}
# ---- 时间/吞吐 (f 的读取位置见 perf_eff) ----
PERF_NOM=${PERF_NOM:-13800}                # ns/day/槽 @ PERF_REF_BEADS 珠 (R3 主跑实测 prod 下限附近, 2 槽/机 MPS); 按珠数线性缩放 = 估算
PERF_REF_BEADS=${PERF_REF_BEADS:-12240}    # R3 lam 体系珠数 (960 脂*12 + 720 W)
# ---- 优先级开关 (规则7: 可关 GLM/提 MD 优先级; 独占显存/重启须 K 批, 本包不做) ----
PRIO=${PRIO:-low}                          # low: mdrun -nice 10 + docker --cpu-shares 512 (与他人共机时让路) | raised: -nice 0 + --cpu-shares 2048 (GLM 已停时)
case $PRIO in low) NICE=10; CPUSH=512;; raised) NICE=0; CPUSH=2048;; *) echo "ABORT: PRIO=$PRIO 须 low|raised"; exit 1;; esac
F_THR=${F_THR:-1.0}                        # 吞吐系数 f: 有效速率 = PERF_NOM*F_THR (规划敏感性 1.0/0.8/0.5)
PERF_OVERRIDE_FILE=${PERF_OVERRIDE_FILE:-$J/R4_perf_override.env}   # 预跑结果到后: 写 F_THR=0.9 或 PERF_NOM=... 到此文件 (包外, 不入 MANIFEST), 补跑判断每次现读
RELAX_FRAC=${RELAX_FRAC:-0.75}             # relax 速率 = RELAX_FRAC * prod 速率 (规划假设)
OVH_H=${OVH_H:-0.1}; GATE_H=${GATE_H:-0.15} # 每条额外开销 / 闸门耗时 (假设)
TAIL_H=${TAIL_H:-0.25}                     # prod -maxh = 剩余 - TAIL_H (留 checkpoint+退出)
MINRUN_H=${MINRUN_H:-0.6}                  # 主批: 剩余不足不开新条 -> SKIP_NO_TIME
SUPP_MARGIN_H=${SUPP_MARGIN_H:-0.75}       # 补跑: 剩余 >= 所需 + 45 min 才发
SUPP=${SUPP:-1}
GATE_MODE=${GATE_MODE:-host}               # host (Spark 上 $GATE_PY 跑 gate/t0_gate_launch.py) | manual (等人把 .PASS/.VOID 放进 $OUT/manual_gate/)
GATE_PY=${GATE_PY:-python3}
GATE_WAIT_MAX_H=${GATE_WAIT_MAX_H:-0.75}
REPLACE_ON_RELAX_FAIL=${REPLACE_ON_RELAX_FAIL:-1}   # relax 崩溃/未跑满的 build 是否按 L2 void 同等进替补账本 (决策开关)
HIST_BAN=${HIST_BAN:-""}                  # R4 无已知禁用 build
# ---- [TRR-AMEND 2026-10-28 取起点规则] 判据阈值一个未改; 只新增"从 relax 末 SEL_WIN_PS 内取最后一个合格帧作 prod 起点" (见 PRE_REG_AMENDMENT_R3_trr.md) ----
SEL_RULE=${SEL_RULE:-1}                    # 1=启用 (仅 lam 臂; hii 臂起点闸 N/A, 不变); 0=旧行为 (relax 末帧 + -t relax.cpt)
SEL_NSTOUT=${SEL_NSTOUT:-5000}             # relax 期间 trr 写出间隔 (步; 15 fs*5000=75 ps) -> nstxout=nstvout=此值, 不写 f
SEL_WIN_PS=${SEL_WIN_PS:-5000}             # 只在 relax 末尾这么多 ps (5 ns, ~67 帧) 内逐帧判定
SEL_KEEP_FRAMES=${SEL_KEEP_FRAMES:-0}      # 0=prod 前删除非选中帧 .gro (只保留 selected.gro, frames.tsv 与每帧 json 留作审计); 1=全留
GMXV=unknown
CN_PREFIX=${CN_PREFIX:-R4_}                # 容器名 R4_<机>_<pid>_<标签>
say(){ echo "[$(date '+%F %T')] ${SLOT_TAG:-R4}: $*" | tee -a "${OUT:-/tmp}/slots/${SLOT_TAG:-main}.log" 2>/dev/null; }
# ---------- 时间 ----------
DL=$(date -d "$DEADLINE" +%s 2>/dev/null) || { echo "ABORT: DEADLINE='$DEADLINE' 无法解析"; exit 1; }
rem_s(){ echo $((DL-$(date +%s))); }
rem_h(){ awk -v r=$(rem_s) 'BEGIN{printf "%.3f", r/3600}'; }
# ---------- 吞吐 f 读取位置 ----------
# 有效速率 ns/day = min( PERF_NOM*F_THR [可被 $PERF_OVERRIDE_FILE 改写], 本机已测 prod 'Performance:' 的最小值 [$OUT/THROUGHPUT.tsv] )
perf_eff(){ local f=$F_THR n=$PERF_NOM obs
  if [ -f "$PERF_OVERRIDE_FILE" ]; then eval "$(grep -E '^(F_THR|PERF_NOM)=[0-9.]+$' "$PERF_OVERRIDE_FILE")" 2>/dev/null; f=${F_THR:-$f}; n=${PERF_NOM:-$n}; fi
  obs=; [ "${USE_OBSERVED:-1}" = 1 ] && obs=$(awk -F'\t' '$3=="prod" && $4+0>0{ if(m==""||$4+0<m)m=$4+0 } END{print m}' "$OUT/THROUGHPUT.tsv" 2>/dev/null)
  awk -v n=$n -v f=$f -v o="${obs:-}" 'BEGIN{p=n*f; if(o!=""&&o+0<p)p=o+0; printf "%.1f", p}'; }
mdp_nsteps(){ awk '$1=="nsteps"{print $3; exit}' "$1"; }
mdp_dt(){ awk '$1=="dt"{print $3; exit}' "$1"; }
# need_h <build> -> relax(15ns @ RELAX_FRAC*P) + GATE_H + prod(ns @ P) + OVH_H
need_h(){ local b=$1 arm pm rm P; arm=$(arm_of $b); pm=$INP/$b/prod_$arm.mdp; rm=$INP/$b/relax_$RELAX_ARM.mdp; P=$(awk -v p=$(perf_eff) -v r=$PERF_REF_BEADS -v n=$(exp_of $b EXP_ATOMS) 'BEGIN{if(n+0<=0)n=r; printf "%.1f", p*r/n}')   # 珠数缩放 (估算)
  awk -v P=$P -v rf=$RELAX_FRAC -v g=$GATE_H -v o=$OVH_H -v pn=$(mdp_nsteps $pm) -v pd=$(mdp_dt $pm) -v rn=$(mdp_nsteps $rm) -v rd=$(mdp_dt $rm) \
   'BEGIN{pns=pn*pd/1000; rns=rn*rd/1000; printf "%.3f", rns/(rf*P)*24 + g + pns/P*24 + o}'; }
# ---------- 名字解析 ----------
arm_of(){ case $1 in *_lam_*) echo lam;; *_hii_*) echo hii;; *) echo bad;; esac; }
cell_of(){ [[ $1 =~ ^R4_(DOPE|DOPC|MC3H|MC3)_(h[0-9][0-9][0-9])_lam_s[0-9]+$ ]] && echo ${BASH_REMATCH[1]}_${BASH_REMATCH[2]} || echo bad; }   # 格 = 体系_水合
valid_name(){ [[ $1 =~ ^R4_(DOPE|DOPC|MC3H|MC3)_h[0-9][0-9][0-9]_lam_s[0-9]+$ ]] || return 1
  [ -f $INP/$1/expect.env ] || return 1; for x in $HIST_BAN; do [ "$1" = "$x" ] && return 1; done; return 0; }
# expect.env (builder 写): EXP_LIP EXP_W EXP_CL EXP_ATOMS
exp_of(){ awk -F= -v k=$2 '$1==k{print $2}' $INP/$1/expect.env 2>/dev/null; }
# ---------- gmx 调用 ----------
need_cmd(){ if [ "$MODE" = local ]; then command -v "$GMX_LOCAL" >/dev/null 2>&1 || [ -x "$GMX_LOCAL" ] || { echo "ABORT: MODE=local 但找不到 $GMX_LOCAL"; return 1; }
  else command -v docker >/dev/null 2>&1 || { echo "ABORT: 没有 docker"; return 1; }; fi; }
# [TRR-AMEND] GXI=1 => docker run -i (trjconv 要从 stdin 读组号 'echo 0 | GXI=1 gx trjconv ...'; 不设则与旧版逐字相同).
# gx: 在 $PWD 跑 gmx. GXG=1 给容器 GPU (只 mdrun). 容器名 $CN (调用者设). TMOPFX='timeout -s TERM -k 180 <秒>' 时给该条命令加外层超时 (grompp 时为空).
gx(){ if [ "$MODE" = local ]; then $TMOPFX env GMXLIB=$FF $GMX_LOCAL "$@" 2>&1; else
  $TMOPFX docker run --rm ${GXI:+-i} --name ${CN:-$(cn_name x$BASHPID)} --cpu-shares $CPUSH ${GXG:+--gpus all} ${MPSARGS-} --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -e GMXLIB=$FF -v $HERE:$HERE:ro -v $OUT_PARENT:$OUT_PARENT -w "$PWD" $IMG -c "exec 2>&1; $G $*"; fi; }
# 容器名唯一且落在 cleanup 的 ^R4_<机>_<pid>_ 范围: R4_<机>_<ORCH_PID>_<SLOT_TAG>_<后缀>; 后缀须含 build/阶段/attempt 或 BASHPID (F2: 旧默认名 R3_x$$ 在两槽子 shell 里 $$ 相同 -> 重名)
cn_name(){ echo "${CN_PREFIX}${MACHINE}_${ORCH_PID}_${SLOT_TAG:-nos}_$1" | tr -c 'A-Za-z0-9_.\n-' '_'; }
gmx_version(){ ( cd /tmp; OUT_PARENT=${OUT_PARENT:-/tmp} CN=$(cn_name ver_$BASHPID) gx --version 2>&1 | grep -m1 'GROMACS version' | awk '{print $NF}' ); }
check_gmxv(){ case "$GMXV" in ${EXPECT_GMX:-2026.3}*) return 0;; esac; [ "${EXPECT_GMX:-}" = any ] && return 0; echo "ABORT: gmx 版本 '$GMXV' != 期望 ${EXPECT_GMX:-2026.3} (box 冒烟请设 EXPECT_GMX=any)"; return 1; }
# ---------- 进程冲突扫描 (F1) / 防双开 ----------
# procs_other <egrep 模式>: 列出 args 命中模式、且不是 "本 shell / 本 shell 的祖先 (ssh 外层 bash -c ... run_R3.sh ...) / 本 shell 的后代 (子 shell, $(...), ps, awk)" 的进程.
procs_other(){ ps -eo pid=,ppid=,args= | awk -v me=${1:?} -v pat="$2" '
  { pid=$1; pp[pid]=$2; $1=""; $2=""; ln[pid]=$0 }
  END{ for(a=me; a>1 && !(a in anc); a=pp[a]) anc[a]=1
       for(p in ln){ if(p in anc) continue; d=0; for(q=p; q>1; q=pp[q]) if(q==me){d=1;break}; if(d) continue
         if(ln[p] ~ pat) print p ln[p] } }'; }
# take_lock: flock 防同机双开 (fd 9 随进程退出自动释放, 不需要 rm); 已被占用则返回 1
take_lock(){ mkdir -p "$J" && exec 9>>"$J/.R4_${MACHINE}.flock" && flock -n 9; }
test_lock(){ mkdir -p "$J" && ( exec 9>>"$J/.R4_${MACHINE}.flock"; flock -n 9 ); }
# ---------- 输出目录/attempt/状态 (不覆写) ----------
init_out(){ local M=$1
  if [ -n "${APPEND_TO:-}" ]; then [ -d "$APPEND_TO" ] || { echo "ABORT: APPEND_TO 不存在"; return 1; }; OUT=$(cd "$APPEND_TO" && pwd); APPEND=1
  else TS=$(date +%m%d_%H%M%S); mkdir -p "$J" || return 1; OUT=$J/R4_run_${M}_$TS; mkdir "$OUT" 2>/dev/null || { echo "ABORT: $OUT 已存在, 不覆盖 (续跑用 APPEND_TO=该目录)"; return 1; }; fi
  OUT_PARENT=$(dirname "$OUT"); mkdir -p "$OUT/slots" "$OUT/ledger" "$OUT/manual_gate"; export OUT OUT_PARENT; }
new_attempt(){ local s=$1 n d; mkdir -p "$s"; n=$(ls -1d "$s"/attempt_[0-9][0-9][0-9] 2>/dev/null | sed 's/.*attempt_//' | sort -n | tail -1); n=$((10#${n:-0}))
  while :; do n=$((n+1)); d=$(printf '%s/attempt_%03d' "$s" $n); mkdir "$d" 2>/dev/null && { echo "$d"; return 0; }; done; }
last_attempt(){ ls -1d "$1"/attempt_[0-9][0-9][0-9] 2>/dev/null | sort | tail -1; }
last_state(){ local d; d=$(last_attempt "$1"); [ -n "$d" ] && [ -f "$d/STATUS" ] && cut -d' ' -f1 "$d/STATUS" || echo NONE; }
setstat(){ ( set -o noclobber; echo "$2 ${3:-}" > "$1/STATUS" ) 2>/dev/null || echo "WARN: $1/STATUS 已存在, 不覆盖" >&2; }
warn_extract(){ awk '/^WARNING [0-9]+/{p=1} /^(Number of degrees|There w(as|ere) [0-9]+ (NOTE|WARNING))/{p=0} p' "$1"; }
nanchk(){ grep -ciE '(^|[^a-z])nan([^a-z]|$)|fatal error|LINCS WARNING' "$1" 2>/dev/null; }
REC_HEADER=$'ts\tmachine\tslot\tstage\tbuild\trole\tarm_or_mdp\tattempt_dir\tstate\tgmx_version\tmaxwarn\tgrompp_rc\tn_warn\tmdrun_rc\tlaststep\tperformance_ns_day\tremaining_h\tneed_h\tnote'
# rec <stage> <build> <role> <arm_or_mdp> <attempt_dir> <state> <maxwarn> <grompp_rc> <n_warn> <mdrun_rc> <laststep> <perf> <need_h> <note>  (只 >>, 单行 <4096B, O_APPEND 原子)
rec(){ [ -f "$OUT/ALL_RECORDS.tsv" ] || printf '%s\n' "$REC_HEADER" >> "$OUT/ALL_RECORDS.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T %z')" "${MACHINE:--}" "${SLOT_TAG:--}" "$1" "$2" "$3" "$4" "$5" "$6" "$GMXV" "${7:--}" "${8:--}" "${9:--}" "${10:--}" "${11:--}" "${12:--}" "$(rem_h)" "${13:--}" "${14:--}" >> "$OUT/ALL_RECORDS.tsv"; }
# ---------- 账本 (机器内两槽共享; mkdir 原子) ----------
ledger_claim(){ mkdir -p "$OUT/ledger/$1" && mkdir "$OUT/ledger/$1/$2" 2>/dev/null; }          # 成功=抢到
ledger_has(){ [ -d "$OUT/ledger/$1/$2" ]; }
ledger_list(){ ls -1 "$OUT/ledger/$1" 2>/dev/null; }
ledger_add(){ mkdir -p "$OUT/ledger/$1" && mkdir "$OUT/ledger/$1/$2" 2>/dev/null; return 0; }
halted(){ [ -f "$OUT/HALT" ]; }
halt(){ ( set -o noclobber; echo "$(date '+%F %T') ${SLOT_TAG:-}: $*" > "$OUT/HALT" ) 2>/dev/null; say "HALT: $*"; }
# ---------- MPS (同 R2b: 用户态守护, MPSROOT 须空; 只关自己新起的) ----------
mps_start(){ [ "$MODE" = local ] && return 0; [ -n "${NOMPS:-}" ] && return 0; MPSROOT=${MPSROOT:-$HOME/mps_R4}
  [ -z "$(ls -A $MPSROOT 2>/dev/null)" ] || { echo "ABORT: $MPSROOT 非空 (有 MPS 残留? 换新空目录)"; return 1; }
  export MPSPIPE=$MPSROOT/pipe MPSLOG=$MPSROOT/log; mkdir -p $MPSPIPE $MPSLOG; PRE_MPS=" $(pgrep nvidia-cuda-mps | tr '\n' ' ') "
  CUDA_MPS_PIPE_DIRECTORY=$MPSPIPE CUDA_MPS_LOG_DIRECTORY=$MPSLOG nvidia-cuda-mps-control -d || { echo "ABORT: MPS 起不来"; return 1; }; sleep 3
  pgrep -a nvidia-cuda-mps > $OUT/slots/${MACHINE}_mps_start.txt
  export MPSARGS="--ipc=host -v $MPSPIPE:$MPSPIPE -v $MPSLOG:$MPSLOG -e CUDA_MPS_PIPE_DIRECTORY=$MPSPIPE -e CUDA_MPS_LOG_DIRECTORY=$MPSLOG"; MPS_UP=1; }
mps_stop(){ [ -n "${MPS_UP:-}" ] || return 0; echo quit | CUDA_MPS_PIPE_DIRECTORY=$MPSPIPE CUDA_MPS_LOG_DIRECTORY=$MPSLOG timeout 20 nvidia-cuda-mps-control > $OUT/slots/${MACHINE}_mps_quit.txt 2>&1; sleep 2
  for p in $(pgrep nvidia-cuda-mps); do case "$PRE_MPS" in *" $p "*) ;; *) kill $p 2>/dev/null;; esac; done; MPS_UP=; }
# ---------- grompp ----------
# gp <attempt_dir> <tag> <mdp> <gro> <top> <ndx> <maxwarn> [extra...] -> GP_RC GP_NW; grompp.log / warnings.txt
gp(){ local d=$1 tag=$2 mdp=$3 gro=$4 top=$5 ndx=$6 mw=$7 cn; shift 7
  cn=$(cn_name gp_${tag}_$(basename $(dirname $(dirname "$d")))_$(basename "$d"))   # 含 机/pid/槽/阶段tag/build/attempt; 同一 attempt 目录只会 grompp 一次
  ( cd "$d" && CN=$cn gx grompp -f "$mdp" -c "$gro" -p "$top" -n "$ndx" -o $tag.tpr -po ${tag}_out.mdp "$@" -maxwarn $mw ) > "$d/grompp.log" 2>&1; GP_RC=$?
  warn_extract "$d/grompp.log" > "$d/warnings.txt"; GP_NW=$(grep -c '^WARNING' "$d/grompp.log"); }
norm_ws(){ tr -s ' \t\n' ' ' < "$1" | sed 's#\[file [^] ]*/#[file #g; s/^ //; s/ $//'; }   # 去掉 grompp 报告里的 mdp 目录前缀, 其余逐字
# ---------- mdrun (单次; 后台+wait 使 TERM trap 立即生效; 外层 timeout=剩余+600) ----------
# run_mdrun <attempt_dir> <deffnm> <pinoff> <maxh> <timeout_s> [mdrun 额外参数...] -> MD_RC; 日志 <deffnm>.log, stdout mdrun.out
run_mdrun(){ local d=$1 f=$2 po=$3 mh=$4 to=$5; shift 5; local pin gpuf
  if [ "$MODE" = local ]; then pin=${PINFLAGS-"-pin off"}; gpuf=${GPUFLAGS-"-nb cpu -update cpu"}; else pin=${PINFLAGS-"-pin on -pinoffset $po -pinstride 1"}; gpuf=${GPUFLAGS-"-nb gpu -update cpu"}; fi
  MD_CN=${CN_PREFIX}${MACHINE}_${ORCH_PID}_${SLOT_TAG}_${f}_$(basename $d)
  echo "mdrun -deffnm $f -ntmpi 1 -ntomp $NT $gpuf $pin -nice $NICE -maxh $mh $*  (PRIO=$PRIO cpu-shares=$CPUSH)" > $d/mdrun_cmd.txt; echo "container=$MD_CN" >> $d/mdrun_cmd.txt
  ( cd "$d" && GXG=1 CN=$MD_CN TMOPFX="timeout -s TERM -k 180 $to" gx mdrun -deffnm $f -ntmpi 1 -ntomp $NT $gpuf $pin -nice $NICE -maxh $mh "$@" ) > "$d/mdrun.out" 2>&1 & MDP=$!
  wait $MDP; MD_RC=$?
  if [ $MD_RC = 124 ] || [ $MD_RC = 137 ]; then [ "$MODE" = local ] || docker stop -t 120 $MD_CN >/dev/null 2>&1; fi; }
laststep_of(){ awk '/^ +Step +Time/{getline; s=$1} END{print s+0}' "$1" 2>/dev/null; }
perf_of(){ grep -E '^Performance:' "$1" 2>/dev/null | tail -1 | awk '{print $2}'; }
# ======================= 单条 build 流水线: relax -> 闸门(L2 起点资格) -> prod =======================
PROD_MIN_H=${PROD_MIN_H:-0.5}              # 闸门通过后 prod 可用 -maxh 低于此值 -> SKIP_NO_TIME_PROD (不白起)
NSTEPS_OVERRIDE_RELAX=${NSTEPS_OVERRIDE_RELAX:-}; NSTEPS_OVERRIDE_PROD=${NSTEPS_OVERRIDE_PROD:-}   # 仅 MODE=local 冒烟
USE_OBSERVED=${USE_OBSERVED:-1}
thr_rec(){ [ -n "$4" ] || return 0; [ -f "$OUT/THROUGHPUT.tsv" ] || printf 'ts\tbuild\tstage\tperf_ns_day\tlaststep\tslot\n' >> "$OUT/THROUGHPUT.tsv"
  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$(date '+%F %T %z')" "$1" "$2" "$4" "$3" "${SLOT_TAG:--}" >> "$OUT/THROUGHPUT.tsv"; }
inputs_sha(){ ( cd $INP/$1 && sha256sum start.gro sys.top index.ndx relax_$RELAX_ARM.mdp prod_$2.mdp ) > "$3/inputs_sha256.txt" 2>&1; }
done_dir(){ local s=$1 d st; for d in $(ls -1d "$s"/attempt_[0-9][0-9][0-9] 2>/dev/null | sort -r); do [ -f $d/STATUS ] && [ "$(cut -d' ' -f1 $d/STATUS)" = "$2" ] && { echo $d; return 0; }; done; return 1; }
consec_fail(){ # consec_fail <kind>: 机器内同类 grompp 失败计数 (>=2 即判系统性问题, HALT)
  ledger_add gpfail_$1 "$(date +%s)_$$_$RANDOM"; [ "$(ledger_list gpfail_$1 | wc -l)" -ge 2 ]; }
# ---- relax ----
step_relax(){ local b=$1 po=$2 d mdp tgt mh to ls rc st nn
  mdp=$INP/$b/relax_$RELAX_ARM.mdp; d=$(new_attempt $OUT/builds/$b/relax); inputs_sha $b $(arm_of $b) $d
  # [TRR-AMEND] lam 臂: 在 attempt 目录生成派生 mdp (同名 relax_$RELAX_ARM.mdp, 使 grompp 警告里 [file ...] 文本不变), = 原 mdp 逐字 + 末尾追加 nstxout/nstvout (不写 f; 其余输出/参数一字不改).
  #         原 mdp 若自带 nstxout/nstvout 行 (精确键名, 不含 nstxout-compressed) 则先滤掉再追加. 原 inputs/*/relax_*.mdp 与其 MANIFEST sha 不动.
  if [ "$SEL_RULE" = 1 ] && [ "$(arm_of $b)" = lam ]; then
    awk '!($1=="nstxout"||$1=="nstvout")' $mdp > $d/relax_$RELAX_ARM.mdp
    printf '; [TRR-AMEND] appended by run_R4 (取起点规则, 同 R3): relax 期间写 x,v 供末 5 ns 逐帧闸门; 不写 f\nnstxout                  = %s\nnstvout                  = %s\n' $SEL_NSTOUT $SEL_NSTOUT >> $d/relax_$RELAX_ARM.mdp
    ( cd $d && sha256sum relax_$RELAX_ARM.mdp ) >> $d/inputs_sha256.txt; diff <(cat $mdp) <(cat $d/relax_$RELAX_ARM.mdp) > $d/mdp_diff_trr.txt; mdp=$d/relax_$RELAX_ARM.mdp; fi
  gp $d relax $mdp $INP/$b/start.gro $INP/$b/sys.top $INP/$b/index.ndx $MAXWARN_RELAX
  if [ $GP_RC != 0 ]; then setstat $d GROMPP_FAIL "rc=$GP_RC nw=$GP_NW"; rec relax $b $ROLE relax_$RELAX_ARM $d GROMPP_FAIL $MAXWARN_RELAX $GP_RC $GP_NW - - - $NEEDH "grompp 失败, 不自动改 maxwarn/改臂"
    consec_fail relax && halt "relax grompp 连续失败(系统性), 不烧后续 build; 见 $d/grompp.log"; return 1; fi
  if [ "$RELAX_ARM" = literal ]; then   # 2 条警告须与 B1_warnings_expected.txt 逐字一致 (空白折叠后), 否则不跑 (2026.3 的条数/文字可能不同)
    if [ "$GP_NW" != 2 ] || [ "$(norm_ws $d/warnings.txt)" != "$(norm_ws $HERE/B1_warnings_expected.txt)" ]; then
      setstat $d WARN_MISMATCH "nw=$GP_NW 与 B1 原文不符"; rec relax $b $ROLE relax_$RELAX_ARM $d WARN_MISMATCH $MAXWARN_RELAX $GP_RC $GP_NW - - - $NEEDH "literal 警告与预期原文不符 -> 停, 回 K"
      halt "literal relax 警告与 B1 原文不符 ($d/warnings.txt)"; return 1; fi; fi
  tgt=${NSTEPS_OVERRIDE_RELAX:-$(mdp_nsteps $mdp)}; mh=$(awk -v h=$(rem_h) -v t=$TAIL_H 'BEGIN{x=h-t; if(x>1)x=1; if(x<0.05)x=0.05; printf "%.3f",x}'); to=$(( $(rem_s) + 600 )); [ $to -gt 300 ] || to=300
  say "relax $b arm=$RELAX_ARM maxwarn=$MAXWARN_RELAX nsteps=$tgt maxh=$mh"
  run_mdrun $d relax $po $mh $to ${NSTEPS_OVERRIDE_RELAX:+-nsteps $NSTEPS_OVERRIDE_RELAX}
  ls=$(laststep_of $d/relax.log); nn=$(nanchk $d/relax.log); thr_rec $b relax $ls "$(perf_of $d/relax.log)"
  if [ $MD_RC = 0 ] && [ "${ls:-0}" -ge "$tgt" ] && [ "${nn:-1}" = 0 ] && [ -s $d/relax.gro ] && [ -s $d/relax.cpt ]; then st=DONE; else st=RELAX_FAIL; fi
  setstat $d $st "rc=$MD_RC laststep=$ls/$tgt nan=$nn"; rec relax $b $ROLE relax_$RELAX_ARM $d $st $MAXWARN_RELAX $GP_RC $GP_NW $MD_RC $ls "$(perf_of $d/relax.log)" $NEEDH "arm=$RELAX_ARM"
  [ $st = DONE ]; }
# ---- [TRR-AMEND] 取起点规则: relax 末 SEL_WIN_PS 内的 trr 帧逐帧用同一个 t0_gate (prod0 级, lam, 960/720) 判定, 选"最后一个"合格帧作 prod 起点 ----
# 判据/阈值/退出码语义与 step_gate 完全相同 (同一命令行, 只是输入换成 trjconv 取出的单帧 gro, 带速度). 不合格帧不看 prod 结果, 只看起点读数.
# 输出 $OUT/builds/<b>/select/attempt_NNN/{frames.tsv,SELECTED_FRAME.txt,selected.gro,gate_frames/*.json,frames/}; 设置 SEL_GRO (给 step_gate) ; 无合格帧/无 trr 则 SEL_GRO=relax.gro (末帧) -> step_gate 照旧判 VOID_L2 (走原有 relax-gate-fail 路径).
# STATUS: SEL_OK (有合格帧, selected.gro 存在) | SEL_NONE (有帧但 0 合格) | SEL_SKIP (无 trr/GATE_MODE!=host/trjconv 失败: 回退旧行为, 即 relax 末帧 + -t relax.cpt, 记录原因)
# [M2] gro_has_vel <gro>: 所有原子行定宽 >=68 列 (x,y,z 各 8 + vx,vy,vz 各 8, trjconv 默认精度) 且速度字段非全零. (不用 NF==9: 残基号/原子号过大时字段会粘连)
gro_has_vel(){ awk 'NR==2{n=$1+0} NR>2&&NR<=n+2{ if(length($0)<68) bad=1; else if(substr($0,45,24) ~ /[1-9]/) nz=1 } END{exit !(n>0 && !bad && nz)}' "$1"; }
# [M3] sel_verify <build> <sel>: prod 起点 selected.gro 的 sha256 必须 = select 记录 (SELECTED_FRAME.txt) = step_gate 判 PASS 那次的输入 (gate/attempt_*/input.txt 的路径与 sha). 不符返回 1, SELV_MSG 说明.
sel_verify(){ local b=$1 sel=$2 gd s1 s2 s3 gi; SELV_MSG=; s1=$(sha256sum "$sel" 2>/dev/null | cut -d' ' -f1)
  gd=$(done_dir $OUT/builds/$b/gate PASS) || { SELV_MSG="无 PASS 的闸门 attempt"; return 1; }
  gi=$(sed -n 's/^relax_gro=//p' $gd/input.txt | head -1); s2=$(sed -n '2p' $gd/input.txt | cut -d' ' -f1); s3=$(sed -n 's/^selected_gro_sha256=//p' $(dirname "$sel")/SELECTED_FRAME.txt | head -1)
  [ -n "$s1" ] && [ "$s1" = "$s2" ] && [ "$s1" = "$s3" ] && [ "$(readlink -f "$gi")" = "$(readlink -f "$sel")" ] && return 0
  SELV_MSG="prod 起点 $sel sha=$s1 | 闸门判过 $gi sha=$s2 | SELECTED_FRAME sha=$s3"; return 1; }
sel_gro_of(){ local d; d=$(done_dir $OUT/builds/$1/select SEL_OK) && echo $d/selected.gro; }
step_select(){ local b=$1 rd=$2 d fd gd T B n=0 nq=0 i f t rc v r65 last= lastt= sh mdp
  SEL_GRO=$rd/relax.gro; [ "$SEL_RULE" = 1 ] && [ "$(arm_of $b)" = lam ] || return 0
  d=$(new_attempt $OUT/builds/$b/select); fd=$d/frames; gd=$d/gate_frames; mkdir -p $fd $gd
  if [ "$GATE_MODE" != host ]; then setstat $d SEL_SKIP "GATE_MODE=$GATE_MODE: 无自动闸门, 回退旧行为 (末帧)"; rec select $b $ROLE trr_select $d SEL_SKIP - - - - - - $NEEDH "GATE_MODE=$GATE_MODE"; return 0; fi
  if [ ! -s $rd/relax.trr ] || [ ! -s $rd/relax.tpr ]; then setstat $d SEL_SKIP "无 relax.trr/relax.tpr"; rec select $b $ROLE trr_select $d SEL_SKIP - - - - - - $NEEDH "无 trr: 回退旧行为"; return 0; fi
  mdp=$rd/relax_$RELAX_ARM.mdp; T=$(awk -v n=${NSTEPS_OVERRIDE_RELAX:-$(mdp_nsteps $mdp)} -v dt=$(mdp_dt $mdp) 'BEGIN{printf "%.3f", n*dt}'); B=$(awk -v t=$T -v w=$SEL_WIN_PS 'BEGIN{b=t-w; if(b<0)b=0; printf "%.3f", b}')
  ( cd $fd && echo 0 | GXI=1 CN=$(cn_name sel_$(basename $(dirname $d))_$(basename $d)) gx trjconv -f $rd/relax.trr -s $rd/relax.tpr -b $B -e $T -sep -o fr.gro ) > $d/trjconv.log 2>&1; rc=$?
  n=$(ls -1 $fd/fr*.gro 2>/dev/null | wc -l)
  if [ $rc != 0 ] || [ $n = 0 ]; then setstat $d SEL_SKIP "trjconv rc=$rc nframes=$n"; rec select $b $ROLE trr_select $d SEL_SKIP - - - - - - $NEEDH "trjconv 失败: 回退旧行为, 见 $d/trjconv.log"; return 0; fi
  printf 'idx\tt_ps\tgate_rc\tverdict\treading_0.65_v1\tfile\ttries\n' > $d/frames.tsv; local nerr=0 tries qf=() qt=() k nvb=0 nexp dtm lastframe_t wmsg=
  for f in $(ls -1 $fd/fr*.gro | sort -V); do i=$(basename $f .gro); i=${i#fr}; t=$(head -1 $f | grep -o 't= *[0-9.]*' | sed 's/t= *//'); tries=0
    # [M1] 闸门 t0_gate_launch 约定 rc=0 PASS / rc=3 不合格(VOID); 其他 rc (docker/python 瞬时错误) 重试 SEL_GATE_RETRY(默认2) 次, 仍失败 -> 该帧 ERR (不计入合格)
    while :; do rm -f $gd/f$i.json; ( cd $gd && $GATE_PY $HERE/gate/t0_gate_launch.py $f --level prod0 --arm lam --expect-lipids $(exp_of $b EXP_LIP) --expect-w $(exp_of $b EXP_W) --json f$i.json ) > $gd/f$i.out 2>&1; rc=$?; tries=$((tries+1))
      [ $rc = 0 ] || [ $rc = 3 ] && break; [ $tries -gt ${SEL_GATE_RETRY:-2} ] && break; sleep ${SEL_RETRY_S:-2}; done
    if [ $rc = 0 ] || [ $rc = 3 ]; then
      v=$(tr -d ' \n' < $gd/f$i.json 2>/dev/null | grep -o '"verdict":"[^"]*"' | head -1 | cut -d'"' -f4); r65=$(tr -d ' \n' < $gd/f$i.json 2>/dev/null | grep -o '"0.65":{"v1":\[[0-9,]*\]' | sed 's/.*"v1"://')
    else v=ERR; r65=; nerr=$((nerr+1)); fi
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $i $t $rc ${v:--} ${r65:--} $(basename $f) $tries >> $d/frames.tsv; lastframe_t=$t
    if [ $rc = 0 ]; then nq=$((nq+1)); qf+=($f); qt+=($t); fi; done
  # [M1] 帧数/末帧时间 sanity: 期望 n≈SEL_WIN_PS/(SEL_NSTOUT*dt) (默认 67), 末帧 t≈T; 不符只记 WARN (不改行为)
  dtm=$(mdp_dt $mdp); nexp=$(awk -v w=$SEL_WIN_PS -v o=$SEL_NSTOUT -v dt=$dtm 'BEGIN{printf "%.2f", w/(o*dt)}')
  awk -v n=$n -v e=$nexp 'BEGIN{d=n-e; if(d<0)d=-d; exit !(d<=1.5)}' || wmsg="WARN: 窗口帧数 $n 与期望 ≈$nexp 不符"
  awk -v a=${lastframe_t:-0} -v T=$T -v iv=$(awk -v o=$SEL_NSTOUT -v dt=$dtm 'BEGIN{print o*dt}') 'BEGIN{d=a-T; if(d<0)d=-d; exit !(d<=iv+0.01)}' || wmsg="$wmsg WARN: 末帧 t=${lastframe_t:-?} 与 T=$T 不符"
  [ $nerr -gt 0 ] && wmsg="$wmsg WARN: ERR 帧 $nerr 个 (闸门执行错误, 重试后仍失败, 不计合格)"
  [ -n "$wmsg" ] && { echo "$wmsg" > $d/WARN.txt; say "select $b: $wmsg"; }
  # [M2] 从最后一个合格帧往前找第一个"带速度"的 gro (见 gro_has_vel); 无速度的合格帧不选并记 novel_frames.txt
  last=; lastt=; k=$(( ${#qf[@]} - 1 ))
  while [ $k -ge 0 ] && [ $nerr -le ${SEL_ERR_MAX:-3} ]; do if gro_has_vel ${qf[$k]}; then last=${qf[$k]}; lastt=${qt[$k]}; break; else nvb=$((nvb+1)); echo "no-velocity: $(basename ${qf[$k]}) t=${qt[$k]}" >> $d/novel_frames.txt; fi; k=$((k-1)); done
  if [ $nerr -gt ${SEL_ERR_MAX:-3} ]; then   # [M1] ERR 帧过多: 选帧不可信 -> SEL_SKIP, 回退原路径 (relax 末帧, step_gate 照判, 合格才 prod -t relax.cpt)
    { echo "build=$b"; echo "selected_t_ps=SKIP"; echo "n_frames_window=$n"; echo "n_err=$nerr"; echo "n_qualified=$nq"; echo "window_ps=[$B,$T]"; echo "-> ERR 帧>${SEL_ERR_MAX:-3}: SEL_SKIP, 按原路径末帧判"; } > $d/SELECTED_FRAME.txt
    setstat $d SEL_SKIP "ERR frames=$nerr>${SEL_ERR_MAX:-3}"; rec select $b $ROLE trr_select $d SEL_SKIP - - - - - - $NEEDH "ERR 帧 $nerr>${SEL_ERR_MAX:-3}: 回退旧行为"; say "select $b: ERR 帧 $nerr -> SEL_SKIP (末帧原路径)"; last=
  elif [ -n "$last" ]; then cp $last $d/selected.gro; sh=$(sha256sum $d/selected.gro | cut -d' ' -f1)
    { echo "build=$b"; echo "selected_t_ps=$lastt"; echo "selected_file=$(basename $last)"; echo "n_frames_window=$n"; echo "n_qualified=$nq"; echo "n_err=$nerr"; echo "n_qualified_novel=$nvb"; echo "qualified_fraction=$(awk -v a=$nq -v b=$n 'BEGIN{printf "%.4f",a/b}')"
      echo "window_ps=[$B,$T]"; echo "selected_gro_sha256=$sh"; echo "trr_sha256=$(sha256sum $rd/relax.trr | cut -d' ' -f1)"; echo "rule=last qualified frame (with velocities) in window (gate = t0_gate_launch prod0 lam, expect from inputs/$b/expect.env, thresholds unchanged)"; [ -n "$wmsg" ] && echo "$wmsg"; } > $d/SELECTED_FRAME.txt
    SEL_GRO=$d/selected.gro; setstat $d SEL_OK "t_ps=$lastt qualified=$nq/$n err=$nerr"; rec select $b $ROLE trr_select $d SEL_OK - - - - - - $NEEDH "selected_t_ps=$lastt qualified=$nq/$n err=$nerr novel=$nvb sha=${sh:0:12}"; say "select $b: 选中帧 t=$lastt ps, 合格 $nq/$n (ERR $nerr, 无速度跳过 $nvb)"
  else { echo "build=$b"; echo "selected_t_ps=NONE"; echo "n_frames_window=$n"; echo "n_qualified=$nq"; echo "n_err=$nerr"; echo "n_qualified_novel=$nvb"; echo "qualified_fraction=0.0000"; echo "window_ps=[$B,$T]"; echo "-> 按原有 relax-gate-fail 路径作废 (step_gate 对末帧判 VOID_L2)"; } > $d/SELECTED_FRAME.txt
    setstat $d SEL_NONE "qualified=$nq/$n novel=$nvb"; rec select $b $ROLE trr_select $d SEL_NONE - - - - - - $NEEDH "qualified=$nq/$n (无速度 $nvb) -> 作废"; say "select $b: $nq/$n 帧合格(无速度 $nvb) -> VOID"; fi
  # 清理 (prod 前): 只删本函数刚生成的非选中帧 .gro; trr/frames.tsv/各帧 json 保留
  if [ "$SEL_KEEP_FRAMES" != 1 ]; then for f in $(ls -1 $fd/fr*.gro); do [ "$f" = "${last:-}" ] || rm -f -- "$f"; done; fi
  return 0; }
# ---- 闸门 (L2: relax 末帧 = prod 帧 0; v1/v2 同款 t0_gate; 只用起点读数, 不看 prod 结果) ----
step_gate(){ local b=$1 rd=$2 gin=${3:-$2/relax.gro} arm=$(arm_of $1) d rc st w0 t   # [TRR-AMEND] 第 3 参数 = 被判定的起点帧 (默认=旧行为 relax.gro)
  d=$(new_attempt $OUT/builds/$b/gate); echo "relax_gro=$gin" > $d/input.txt; sha256sum $gin >> $d/input.txt
  if [ "$GATE_MODE" = manual ] && [ $arm = hii ]; then rc=0   # hii 臂起点豁免 (N/A), 不需人工
  elif [ "$GATE_MODE" = manual ]; then w0=$(date +%s); say "gate(manual) 等 $OUT/manual_gate/$b.PASS|.VOID (输入 $gin; 最长 ${GATE_WAIT_MAX_H}h)"
    while :; do [ -f $OUT/manual_gate/$b.PASS ] && { rc=0; break; }; [ -f $OUT/manual_gate/$b.VOID ] && { rc=3; break; }
      t=$(( $(date +%s) - w0 )); if awk -v t=$t -v m=$GATE_WAIT_MAX_H 'BEGIN{exit !(t/3600>=m)}' || [ $(rem_s) -lt 600 ]; then rc=99; break; fi; sleep ${GATE_POLL_S:-30}; done
  else ( cd $d && $GATE_PY $HERE/gate/t0_gate_launch.py $gin --level prod0 --arm $arm --expect-lipids $(exp_of $b EXP_LIP) --expect-w $(exp_of $b EXP_W) --json gate.json ) > $d/gate.out 2>&1; rc=$?; fi
  case $rc in 0) [ $arm = lam ] && st=PASS || st=NA_HII;; 3) st=VOID_L2;; 99) st=GATE_TIMEOUT;; *) st=GATE_ERROR;; esac
  setstat $d $st "rc=$rc mode=$GATE_MODE"; rec gate $b $ROLE t0_gate_prod0 $d $st - - - $rc - - $NEEDH "mode=$GATE_MODE reading=$(grep -o '"verdict": *"[^"]*"' $d/gate.json 2>/dev/null | head -1)"
  case $st in VOID_L2) [ $arm = lam ] && ledger_add void $b;; GATE_ERROR) halt "闸门执行错误 (python 依赖?) 见 $d/gate.out";; esac
  GATE_ST=$st; [ $st = PASS ] || [ $st = NA_HII ]; }
# ---- prod ----
step_prod(){ local b=$1 po=$2 rd=$3 sel=${4:-} arm=$(arm_of $1) mdp d prev tgt mh to ls rc st nn lg res=""   # [TRR-AMEND] 第 4 参数 sel = 取起点规则选中的 selected.gro (空=旧行为)
  mdp=$INP/$b/prod_$arm.mdp; tgt=${NSTEPS_OVERRIDE_PROD:-$(mdp_nsteps $mdp)}
  mh=$(awk -v h=$(rem_h) -v t=$TAIL_H 'BEGIN{printf "%.3f", h-t}'); if ! awk -v m=$mh -v p=$PROD_MIN_H 'BEGIN{exit !(m>=p)}'; then
    d=$(new_attempt $OUT/builds/$b/prod); setstat $d SKIP_NO_TIME_PROD "maxh=$mh<$PROD_MIN_H"; rec prod $b $ROLE prod_$arm $d SKIP_NO_TIME_PROD - - - - - - $NEEDH "闸门后剩余不足, relax+gate 结果保留"; return 1; fi
  prev=$(last_attempt $OUT/builds/$b/prod); to=$(( $(rem_s) + 600 ))
  tpr=$(ls -1 $OUT/builds/$b/prod/attempt_*/prod.tpr 2>/dev/null | head -1); cpt=$(ls -1 $OUT/builds/$b/prod/attempt_*/prod*.cpt 2>/dev/null | grep -v _prev | tail -1)
  if [ -n "$prev" ] && [ -n "$tpr" ] && [ -n "$cpt" ] && [ "$(last_state $OUT/builds/$b/prod)" != DONE ]; then   # 续跑: 新 attempt + -noappend (旧 attempt 一个字节都不动)
    d=$(new_attempt $OUT/builds/$b/prod); res="-s $tpr -cpi $cpt -noappend"; printf 'tpr=%s\ncpt=%s\n' $tpr $cpt > $d/RESUME_FROM.txt; GP_RC=0; GP_NW=-
  else d=$(new_attempt $OUT/builds/$b/prod); inputs_sha $b $arm $d
    if [ -n "$sel" ] && ! sel_verify $b $sel; then   # [M3] prod 起点必须就是闸门判过的 selected.gro (sha256 比对); 不一致 -> VOID 并记日志, 不 grompp
      setstat $d VOID_SEL_MISMATCH "起点与闸门判过的帧不一致"; echo "$SELV_MSG" > $d/VOID_SEL_MISMATCH.txt; rec prod $b $ROLE prod_$arm $d VOID_SEL_MISMATCH - - - - - - $NEEDH "起点 sha 与闸门判过的不一致: $SELV_MSG"
      say "VOID $b: prod 起点与闸门判过的帧不一致 ($SELV_MSG)"; ledger_add void $b; return 1; fi
    # [TRR-AMEND] 有 sel: -c selected.gro (带速度, 即闸门判过的那一帧), 不带 -t (grompp 的 -t 会用 cpt 的末帧坐标/速度覆盖 -c); 无 sel: 旧行为 relax 末帧 + -t relax.cpt
    if [ -n "$sel" ]; then echo "start_gro=$sel" > $d/START_FRAME.txt; sha256sum $sel >> $d/START_FRAME.txt; cp $(dirname $sel)/SELECTED_FRAME.txt $d/SELECTED_FRAME.txt 2>/dev/null
      gp $d prod $mdp $sel $INP/$b/sys.top $INP/$b/index.ndx $MAXWARN_PROD
    else gp $d prod $mdp $rd/relax.gro $INP/$b/sys.top $INP/$b/index.ndx $MAXWARN_PROD -t $rd/relax.cpt; fi
    if [ $GP_RC != 0 ]; then setstat $d GROMPP_FAIL "rc=$GP_RC nw=$GP_NW"; rec prod $b $ROLE prod_$arm $d GROMPP_FAIL $MAXWARN_PROD $GP_RC $GP_NW - - - $NEEDH "prod grompp 失败 (不重试)"
      consec_fail prod && halt "prod grompp 连续失败(系统性); 见 $d/grompp.log"; return 1; fi; fi
  say "prod $b arm=$arm nsteps=$tgt maxh=$mh ${res:+(resume)}"
  run_mdrun $d prod $po $mh $to ${NSTEPS_OVERRIDE_PROD:+-nsteps $NSTEPS_OVERRIDE_PROD} $res
  lg=$(ls -1 $d/prod*.log 2>/dev/null | tail -1); ls=$(laststep_of $lg); nn=$(nanchk $lg)
  if [ $MD_RC = 0 ] && [ "${ls:-0}" -ge "$tgt" ] && grep -q '^Finished mdrun' "$lg" 2>/dev/null; then st=DONE; [ "${nn:-1}" = 0 ] || st=NUMERIC_FAIL
  elif [ $MD_RC = 0 ] && grep -q '^Finished mdrun' "$lg" 2>/dev/null; then st=TRUNC; elif [ $MD_RC = 124 ] || [ $MD_RC = 137 ]; then st=TRUNC_TIMEOUT; else st=FAIL; fi
  ( cd $d && sha256sum prod*.tpr prod*.xtc prod*.edr prod*.log prod*.cpt prod*.gro 2>/dev/null > SHA256_out.txt )
  thr_rec $b prod $ls "$(perf_of $lg)"; setstat $d $st "rc=$MD_RC laststep=$ls/$tgt nan=$nn"
  rec prod $b $ROLE prod_$arm $d $st $MAXWARN_PROD ${GP_RC:--} ${GP_NW:--} $MD_RC $ls "$(perf_of $lg)" $NEEDH "target=$tgt"; [ $st = DONE ]; }
# run_build <build> <role> <pinoff> <kind main|supp> [note]
run_build(){ local b=$1 po=$3 kind=$4 s rd; ROLE=$2; valid_name $b || { say "REFUSE 非法/禁用 build 名 $b"; rec skip $b $ROLE - - REFUSE_NAME - - - - - - - "名字非法/无 expect.env"; return 9; }
  mkdir -p $OUT/builds/$b; NEEDH=$(need_h $b); halted && { rec skip $b $ROLE - - SKIP_HALT - - - - - - - $NEEDH "HALT 文件存在"; return 3; }
  if [ $kind = main ] && ! awk -v h=$(rem_h) -v m=$MINRUN_H 'BEGIN{exit !(h>=m)}'; then say "SKIP_NO_TIME $b 剩余 $(rem_h)h < $MINRUN_H"; rec skip $b $ROLE - - SKIP_NO_TIME - - - - - - - $NEEDH "主批剩余不足"; return 3; fi
  s=$(last_state $OUT/builds/$b/prod); [ "$s" = DONE ] && { say "$b prod 已 DONE, 跳过"; return 0; }
  [ "$(last_state $OUT/builds/$b/gate)" = VOID_L2 ] && { say "$b 已 VOID_L2, 跳过"; return 5; }
  if ! rd=$(done_dir $OUT/builds/$b/relax DONE); then
    if ! step_relax $b $po; then [ "$(arm_of $b)" = lam ] && [ "$REPLACE_ON_RELAX_FAIL" = 1 ] && [ "$(last_state $OUT/builds/$b/relax)" = RELAX_FAIL ] && ledger_add void $b; return 4; fi
    rd=$(done_dir $OUT/builds/$b/relax DONE); fi
  if ! done_dir $OUT/builds/$b/gate PASS >/dev/null && ! done_dir $OUT/builds/$b/gate NA_HII >/dev/null; then
    step_select $b $rd   # [TRR-AMEND] 取起点规则 (lam+SEL_RULE=1; 否则 SEL_GRO=relax.gro 同旧行为)
    step_gate $b $rd $SEL_GRO || { say "$b 闸门 $GATE_ST -> 不进 prod"; return 5; }; fi
  step_prod $b $po $rd $( [ "$SEL_RULE" = 1 ] && [ "$(arm_of $b)" = lam ] && sel_gro_of $b ); }
