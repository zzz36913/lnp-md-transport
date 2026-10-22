#!/usr/bin/env bash
# 脂质滴定介观相 MVP —— 公共参数/函数（build_phase.sh 与 run_phase.sh 共同 source）
# 所有科学参数均为环境变量，可在发车命令前覆盖；每个体系的组成/α 可用 PH_COMP_<SYS> / PH_ALPHA_<SYS> 单独覆盖。
set -u
export TZ=Asia/Singapore
PH=${PH:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}   # 本套脚本目录(含 ff/ mdp/)
MODE=${MODE:-docker}                  # docker(k03/k04 GPU) | local(box CPU 验证)
FF=${FF:-$HOME/lnp_ff}                # Martini 3 核心 itp 所在(与 run2 同一套)
WORK=${WORK:-$HOME/ph_phase_run}
IMAGE=${IMAGE:-ghcr.io/novomcp/gromacs-md:spark}
GMX_IN=${GMX_IN:-/usr/local/gromacs/bin/gmx}
DOCKER_PFX=${DOCKER_PFX:-sg docker -c}
TEMP=${TEMP:-310}                     # K
BOX=${BOX:-14}                        # 目标立方盒边长(nm)；脂质/水数量按此体积和密度推算
INS_SCALE=${INS_SCALE:-1.25}          # 随机插入用的放大盒(边长倍数)，EQ 各向同性压缩回 ~BOX
WATER_WT=${WATER_WT:-0.30}            # 水相(含离子)质量分数；脂:水 = 70:30
DENS=${DENS:-602}                     # amu/nm^3 (=1.0 g/cm^3，估算)
SALT=${SALT:-0.15}                    # M NaCl（按 W 珠×4 个水分子折算）
SEED_BASE=${SEED_BASE:-20261022}
EM_STEPS=${EM_STEPS:-20000}
EQ1_NS=${EQ1_NS:-1}                   # dt 5 fs, tau_p 2 ps：压缩阶段
EQ2_NS=${EQ2_NS:-4}                   # dt 10 fs
PROD_NS=${PROD_NS:-2000}              # 上限；实际由 -maxh(截止时刻) 截断，可 -cpi 续跑
MD_DEADLINE=${MD_DEADLINE:-07:00}     # production 必须停的 SGT 时刻（K 10-22：接力到 07:00；07:45 前收尾）
NSTXTC=${NSTXTC:-25000}               # 0.5 ns/帧
GPUFLAGS=${GPUFLAGS-"-nb gpu -update cpu"}   # 无 PME(reaction-field)；CHOL 虚位点 -> update cpu
PINFLAGS=${PINFLAGS:-"-pin off"}      # 一机多作业共享 GPU/CPU 时不绑核

# ---- 预置体系（可被 PH_COMP_<SYS>/PH_ALPHA_<SYS> 覆盖；也可只靠这两个变量定义全新体系名）----
# 体系名规则: T<N> = MC3:CHOL:DSPC 50:40:10、α=N/100（T33/T67 取 1/3、2/3）；POS/NEG 对照；
# 后缀 _rep<k> = 同组成换种子的副本（种子由完整体系名哈希得到，自动不同）。
sys_base(){ echo "${1%_rep*}"; }
preset_comp(){ local b=$(sys_base $1); case $b in
  T[0-9]|T[0-9][0-9]|T100) echo "MC3:50,CHOL:40,DSPC:10";;
  POS) echo "DOPE:80,CHOL:20";;
  NEG) echo "DOPC:80,CHOL:20";;
  *) echo "";; esac; }
preset_alpha(){ local b=$(sys_base $1); case $b in
  T33) echo 0.333333;; T67) echo 0.666667;;
  T[0-9]|T[0-9][0-9]|T100) awk -v n=${b#T} 'BEGIN{printf "%g", n/100}';;
  *) echo 0;; esac; }
# 覆盖优先级: PH_COMP_<完整名> > PH_COMP_<基名> > 预置
sys_comp(){ local v="PH_COMP_$1" w="PH_COMP_$(sys_base $1)"; echo "${!v:-${!w:-$(preset_comp $1)}}"; }
sys_alpha(){ local v="PH_ALPHA_$1" w="PH_ALPHA_$(sys_base $1)"; echo "${!v:-${!w:-$(preset_alpha $1)}}"; }

CORE_ITPS="martini_v3.0.0.itp martini_v3.0.0_ffbonded_v2.itp martini_v3.0.0_phospholipids_PC_v2.itp martini_v3.0.0_sterols_v1.itp martini_v3.0.0_solvents_v1.itp martini_v3.0.0_ions_v1.itp"
PH_ITPS="martini_v3.0.0_phospholipids_PE_v2.itp martini_v3.0.0_phospholipids_PS_v2.itp martini_v3.0.0_phospholipids_PI_v2.itp MC3.itp MC3H.itp"
# include 顺序(硬规矩)：core -> ffbonded_v2 -> PC_v2 -> PE_v2 -> PS_v2 -> PI_v2 -> sterols -> MC3 -> MC3H -> solvents -> ions
# PS/PI 已备好（K 可能把内体阴离子脂加成第二维，见 dd/16）；其净电荷由 phase_counts.py 自动用 NA 中和
TOP_ORDER="martini_v3.0.0.itp martini_v3.0.0_ffbonded_v2.itp martini_v3.0.0_phospholipids_PC_v2.itp martini_v3.0.0_phospholipids_PE_v2.itp martini_v3.0.0_phospholipids_PS_v2.itp martini_v3.0.0_phospholipids_PI_v2.itp martini_v3.0.0_sterols_v1.itp MC3.itp MC3H.itp martini_v3.0.0_solvents_v1.itp martini_v3.0.0_ions_v1.itp"

mkdir -p "$WORK"; LOG=${LOG:-$WORK/phase.log}
log(){ echo "[$(date '+%F %T %Z')] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

# 在 dir 内执行 gmx 命令串；docker 模式同路径挂载 FF/PH(只读)与 WORK
run_gmx(){ local dir=$1 name=$2; shift 2
  local f="$dir/.$name.sh"
  { echo 'set -e'; echo "cd '$dir'"; printf '%s\n' "$@"; } > "$f"
  if [ "$MODE" = docker ]; then
    sed -i "s#^GMX #$GMX_IN #; s# GMX # $GMX_IN #g" "$f"
    $DOCKER_PFX "docker run --rm --gpus all --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v '$FF':'$FF':ro -v '$PH':'$PH':ro -v '$WORK':'$WORK' -w '$dir' $IMAGE '$f'" >> "$dir/$name.out" 2>&1
  else
    sed -i "s#^GMX #gmx #; s# GMX # gmx #g" "$f"
    sh "$f" >> "$dir/$name.out" 2>&1
  fi; }

step(){ local dir=$1 name=$2; shift 2
  [ -f "$dir/.done_$name" ] && { log "$dir: $name 已完成，跳过"; return 0; }
  log "$dir: $name 开始"; local t0=$(date +%s)
  if run_gmx "$dir" "$name" "$@"; then touch "$dir/.done_$name"; log "$dir: $name 完成 ($(( $(date +%s)-t0 ))s)"
  else log "$dir: $name 失败，见 $dir/$name.out"; return 1; fi; }
