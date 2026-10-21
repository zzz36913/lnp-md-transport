#!/usr/bin/env bash
# run2-lnp 过夜实验：A(阴性对照 DSPC:CHOL 7:3) vs B(DSPC:CHOL:MC3 5:3:2)，各 NREP 副本
# 流水线/副本: insane(固定种子) -> top -> EM -> EQ1(0.5ns,dt10fs) -> EQ2(NPT) -> PROD(GPU,-maxh 自适应) -> 分析
# 幂等可重入: 每步 .done_<step> 标记; PROD 中断则 -cpi 续跑。重跑同一命令即可。
# 用法(k03): nohup bash ~/lnp_run2_exp/run_all.sh > ~/lnp_run2_exp/nohup.out 2>&1 &
# box 验证: MODE=local WORK=/tmp/x FF=/path/ff PROD_NS=0.05 EQ2_NS=0.1 ... bash run_all.sh
# 并行/多机: ONLY="B/rep2 A/rep3" 只跑指定副本; 各机设不同 ONLY，最后 ANALYZE_ONLY=1 汇总。
set -u
export TZ=Asia/Singapore
MODE=${MODE:-docker}                  # docker(k03,GPU) | local(box,CPU)
FF=${FF:-$HOME/lnp_ff}
WORK=${WORK:-$HOME/lnp_run2_exp}
IMAGE=${IMAGE:-ghcr.io/novomcp/gromacs-md:spark}
GMX_IN=${GMX_IN:-/usr/local/gromacs/bin/gmx}   # 容器内 gmx
DOCKER_PFX=${DOCKER_PFX:-sg docker -c}         # 已在 docker 组可设 DOCKER_PFX="bash -c"
NREP=${NREP:-3}
SYSTEMS=${SYSTEMS:-"A B"}
TEMP=${TEMP:-333.15}                  # 333.15K: 避开 M3 DSPC 相变带(Tm 330.5±2.5K, G3_thresholds.md)
SALT=${SALT:-0.15}                    # 待K拍板: M3 基准 PC 体系不加盐
BOX=${BOX:-10}
EQ1_NS=${EQ1_NS:-0.5}
EQ2_NS=${EQ2_NS:-10}
PROD_NS=${PROD_NS:-300}               # 上限; 实际由 -maxh 截断
PROD_MAXH_CAP=${PROD_MAXH_CAP:-1.0}   # 单副本 production 墙钟上限(h)
MD_DEADLINE=${MD_DEADLINE:-07:00}     # 所有 MD 必须结束的 SGT 时刻(07:45 前留 45min 分析收尾)
OVERHEAD_MIN=${OVERHEAD_MIN:-12}      # 每副本非 production 开销(估算,分钟): EM+EQ1+EQ2+grompp+docker
MIN_PROD_NS=${MIN_PROD_NS:-100}       # 每副本 production 少于此(ns) -> 结论只标 PRELIM(G3 文件要求 ≥150ns)
DISCARD_FRAC=${DISCARD_FRAC:-0.5}     # production 前 50% 丢弃，后 50% 统计
NT=${NT:-$(nproc)}
NSTXTC=${NSTXTC:-5000}               # production 轨迹输出间隔(步, 须为100的倍数); 5000步=100ps
SEED_BASE=${SEED_BASE:-20261021}
ONLY=${ONLY:-}
ANALYZE_ONLY=${ANALYZE_ONLY:-0}
if [ "$MODE" = docker ]; then GPUFLAGS=${GPUFLAGS:-"-nb gpu -pme gpu -update cpu"}; else GPUFLAGS=${GPUFLAGS:-""}; fi
# ^ -update cpu 是硬约束: CHOL/MC3 的 virtual sites 不支持 GPU update
# ---- G3 阈值(来源 assets/martini3/G3_thresholds.md) ----
# 文件只给纯 DSPC@333.15K 绝对值(APL 0.565±0.03, D_HH 4.34±0.15)。A(DSPC:CHOL)、B(含MC3) 无发表值。
# TODO 待填: 有可信参考值再填; 空=绝对对标不评(NA)，绝不编数。
APL_LO_A=${APL_LO_A:-}; APL_HI_A=${APL_HI_A:-}; TH_LO_A=${TH_LO_A:-}; TH_HI_A=${TH_HI_A:-}
APL_LO_B=${APL_LO_B:-}; APL_HI_B=${APL_HI_B:-}; TH_LO_B=${TH_LO_B:-}; TH_HI_B=${TH_HI_B:-}
# 自洽(G3_thresholds G3-7): 副本间极差 APL<0.02 nm2, 厚度<0.1 nm
APL_RANGE_MAX=0.02; TH_RANGE_MAX=0.10
# 成膜判据(启发式，非文献): 膜中心(|z|<0.25nm)水密度/体相水密度 < 0.05 且 PO4 峰距 > 3 nm
WATER_RATIO_MAX=0.05; TH_MIN_INTACT=3.0
# 可区分(预注册): 3 个 B 值与 3 个 A 值完全分离(置换检验双侧 p=0.1) 且 |Δ均值| > 2*max(sdA,sdB)
mkdir -p "$WORK"; LOG="$WORK/run_all.log"
log(){ echo "[$(date '+%F %T %Z')] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

composition(){ case $1 in
  A) echo "-l DSPC:7 -l CHOL:3 -u DSPC:7 -u CHOL:3";;
  B) echo "-l DSPC:5 -l CHOL:3 -l MC3:2 -u DSPC:5 -u CHOL:3 -u MC3:2";;
  *) die "unknown system $1";; esac; }
memb_sel(){ case $1 in A) echo "resname DSPC CHOL";; B) echo "resname DSPC CHOL MC3";; esac; }

# 在 rep 目录里执行 gmx 命令串(POSIX sh)。docker 模式: 同路径挂载 FF/WORK, 以当前用户身份运行
run_gmx(){ local dir=$1 name=$2; shift 2
  local f="$dir/.$name.sh"
  { echo 'set -e'; echo "cd '$dir'"; printf '%s\n' "$@"; } > "$f"
  if [ "$MODE" = docker ]; then
    sed -i "s#^GMX #$GMX_IN #; s# GMX # $GMX_IN #g" "$f"
    $DOCKER_PFX "docker run --rm --gpus all --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v '$FF':'$FF':ro -v '$WORK':'$WORK' -w '$dir' $IMAGE '$f'" >> "$dir/$name.out" 2>&1
  else
    sed -i "s#^GMX #gmx #; s# GMX # gmx #g" "$f"
    sh "$f" >> "$dir/$name.out" 2>&1
  fi; }

step(){ local dir=$1 name=$2; shift 2
  [ -f "$dir/.done_$name" ] && { log "$dir: $name 已完成，跳过"; return 0; }
  log "$dir: $name 开始"; local t0=$(date +%s)
  if run_gmx "$dir" "$name" "$@"; then
    case $name in grompp_*) local w; w=$(grep -c '^WARNING' "$dir/$name.out"); [ "$w" -gt 0 ] && log "$dir: $name 有 $w 个 WARNING: $(grep -A2 '^WARNING' "$dir/$name.out" | tr '\n' ' ' | cut -c1-300)";; esac
    touch "$dir/.done_$name"; log "$dir: $name 完成 ($(( $(date +%s)-t0 ))s)"
  else log "$dir: $name 失败，见 $dir/$name.out"; return 1; fi; }

write_mdps(){ local d=$1 seed=$2
  local common="cutoff-scheme = Verlet
nstlist = 20
verlet-buffer-tolerance = 0.005
coulombtype = reaction-field
rcoulomb = 1.1
epsilon_r = 15
vdw_modifier = Potential-shift-verlet
rvdw = 1.1"
  local tp="tcoupl = v-rescale
tc-grps = System
tau_t = 1.0
ref_t = $TEMP
pcoupl = c-rescale
pcoupltype = semiisotropic
tau_p = 4.0
ref_p = 1.0 1.0
compressibility = 3e-4 3e-4
constraints = none
constraint_algorithm = lincs
lincs_order = 8
lincs_iter = 2"
  printf '%s\n' "define = -DFLEXIBLE" "integrator = steep" "nsteps = 20000" "emtol = 100" "$common" > "$d/em.mdp"
  local n1=$(awk -v n=$EQ1_NS 'BEGIN{printf "%d", n*1000/0.010}')
  local n2=$(awk -v n=$EQ2_NS 'BEGIN{printf "%d", n*1000/0.020}')
  local n3=$(awk -v n=$PROD_NS 'BEGIN{printf "%d", n*1000/0.020}')
  printf '%s\n' "integrator = md" "dt = 0.010" "nsteps = $n1" "nstxout-compressed = 5000" "nstenergy = 500" "nstlog = 5000" "$common" "$tp" \
    "gen_vel = yes" "gen_temp = $TEMP" "gen_seed = $seed" > "$d/eq1.mdp"
  printf '%s\n' "integrator = md" "dt = 0.020" "nsteps = $n2" "nstxout-compressed = 5000" "nstenergy = 500" "nstlog = 5000" "$common" "$tp" \
    "gen_vel = no" "continuation = yes" > "$d/eq2.mdp"
  printf '%s\n' "integrator = md" "dt = 0.020" "nsteps = $n3" "nstxout-compressed = $NSTXTC" "nstenergy = $(( NSTXTC<500 ? NSTXTC : 500 ))" "nstlog = 5000" "$common" "$tp" \
    "gen_vel = no" "continuation = yes" > "$d/prod.mdp"; }

build(){ local sys=$1 rep=$2 d=$3 seed=$4
  [ -f "$d/.done_build" ] && return 0
  cp "$FF"/*.itp "$d/" || die "拷贝力场失败"
  # insane 内部 random.seed() 无参 -> 改成固定种子(副本可复现且互相独立)。拷一份改，不动 FF 原件
  sed "s/^\(\s*\)random\.seed()$/\1random.seed($seed)/" "$FF/insane3.py" > "$d/insane3_seeded.py"
  grep -q "random.seed($seed)" "$d/insane3_seeded.py" || die "insane 种子补丁失败"
  ( cd "$d" && python3 insane3_seeded.py -o sys.gro -p sys.ins.top -x $BOX -y $BOX -z $BOX $(composition $sys) -sol W -salt $SALT -pbc rectangular \
      -alname DSPC -alhead 'C P' -allink 'G G' -altail 'CCCC CCCC' -alcharge 0 > insane.out 2>&1 ) || die "$d insane 失败"
  awk 'NR==2{n=$1} NF{nl=NR; k=NF} END{exit !(nl==n+3 && k>=3)}' "$d/sys.gro" || die "$d sys.gro 不完整(缺盒子行/原子数不符)"
  { printf '#include "%s"\n' martini_v3.0.0.itp martini_v3.0.0_ffbonded_v2.itp martini_v3.0.0_phospholipids_PC_v2.itp \
      martini_v3.0.0_sterols_v1.itp MC3.itp martini_v3.0.0_solvents_v1.itp martini_v3.0.0_ions_v1.itp
    sed -n '/\[ system \]/,$p' "$d/sys.ins.top"; } > "$d/sys.top"
  write_mdps "$d" "$seed"; touch "$d/.done_build"; log "$d: build 完成 (seed=$seed)"; }

# 每层脂数 = 全部脂分子(DSPC+CHOL+MC3) / 2
nleaf(){ awk '/\[ *molecules *\]/{m=1;next} m&&$1~/^(DSPC|CHOL|MC3)$/{n+=$2} END{print n/2}' "$1/sys.top"; }

prod_maxh(){ # 按截止时刻自适应分配: (剩余时间 - 剩余副本开销)/剩余 production 数，封顶 CAP
  local now=$(date +%s) dl=$(date -d "today $MD_DEADLINE" +%s)
  [ $dl -lt $(( now - 6*3600 )) ] && dl=$(date -d "tomorrow $MD_DEADLINE" +%s)
  [ $dl -le $now ] && { echo 0; return; }
  awk -v r=$(( dl-now )) -v np=$1 -v nb=$2 -v oh=$OVERHEAD_MIN -v cap=$PROD_MAXH_CAP \
    'BEGIN{h=(r/3600 - nb*oh/60)/np; if(h>cap)h=cap; if(h<0.05)h=0.05; printf "%.3f", h}'; }

analyze_rep(){ local d=$1 sys=$2
  [ -f "$d/.done_prod" ] || { echo "NA"; return; }
  if [ ! -f "$d/.done_ana" ]; then
    local tend
    run_gmx "$d" ana \
      "GMX select -s prod.tpr -on ana.ndx -select '\"MEMB\" $(memb_sel $sys); \"PO4\" name PO4; \"W\" resname W'" \
      "GMX check -f prod.xtc 2> check.txt || true" || return 1
    local t0f; t0f=$(tr '\r' '\n' < "$d/check.txt" | awk '/Reading frame +0 +time/{print $NF; exit}')
    tend=$(awk -v a="$t0f" '$1=="Time" && NF>=3 {printf "%.3f", a+($2-1)*$3; exit}' "$d/check.txt")
    [ -n "$tend" ] && [ -n "$t0f" ] || { log "$d: 读不到 prod.xtc 时间范围" >&2; return 1; }
    local tb=$(awk -v a=$t0f -v t=$tend -v f=$DISCARD_FRAC 'BEGIN{printf "%.3f", a+(t-a)*f}')
    echo "$tb $tend $t0f" > "$d/ana_window.txt"
    run_gmx "$d" ana \
      "printf 'Box-X\nBox-Y\n\n' | GMX energy -f prod.edr -b $tb -o box.xvg" \
      "printf '0\n1\n' | GMX density -s prod.tpr -f prod.xtc -n ana.ndx -d Z -center -sl 200 -b $tb -o dens_po4.xvg" \
      "printf '0\n2\n' | GMX density -s prod.tpr -f prod.xtc -n ana.ndx -d Z -center -sl 200 -b $tb -o dens_w.xvg" || return 1
    touch "$d/.done_ana"
  fi
  local nl=$(nleaf "$d")
  local apl=$(awk -v nl=$nl '!/^[@#]/{a=$2*$3/nl; s+=a; q+=a*a; n++} END{if(n){m=s/n; v=q/n-m*m; if(v<0)v=0; printf "%.4f %.4f %d", m, sqrt(v), n} else print "NA NA 0"}' "$d/box.xvg")
  local th=$(awk '!/^[@#]/{if($1<0&&$2>mn){mn=$2;zn=$1} if($1>0&&$2>mp){mp=$2;zp=$1}} END{if(mn>0&&mp>0) printf "%.3f", zp-zn; else print "NA"}' "$d/dens_po4.xvg")
  local wr=$(awk '!/^[@#]/{z=($1<0)?-$1:$1; if(z<0.25){c+=$2;nc++} if(z>3.5){b+=$2;nb++}} END{if(nc&&nb&&b>0) printf "%.4f", (c/nc)/(b/nb); else print "NA"}' "$d/dens_w.xvg")
  local nsd=$(awk '/Performance:/{print $2}' "$d/prod.log" | tail -1)
  local pns=$(awk '{printf "%.3f", ($2-$3)/1000}' "$d/ana_window.txt")
  local nan=$(grep -ilw 'nan' "$d"/em.log "$d"/eq1.log "$d"/eq2.log "$d"/prod.log 2>/dev/null | wc -l)
  echo "${nsd:-NA} $pns $apl $th $wr $nan"; }

in_range(){ awk -v x="$1" -v lo="$2" -v hi="$3" 'BEGIN{ if(lo==""||hi==""||x=="NA") print "NA"; else print (x>=lo&&x<=hi)?"PASS":"FAIL"}'; }

summarize(){ local out="$WORK/RESULTS.tsv"
  printf 'system\trep\tns_per_day\tprod_ns\tAPL_nm2\tAPL_sd_frames\tnframes\tPO4PO4_nm\tW_center_ratio\tnan_logs\tbilayer_intact\tG3_abs\ttraj\tlog\n' > "$out"
  for sys in $SYSTEMS; do for r in $(seq 1 $NREP); do local d="$WORK/$sys/rep$r"
    [ -d "$d" ] || continue
    local res; res=$(analyze_rep "$d" "$sys") || res="NA"
    set -- $res; [ $# -lt 8 ] && set -- NA NA NA NA 0 NA NA NA
    local intact=$(awk -v w="$7" -v t="$6" -v wm=$WATER_RATIO_MAX -v tm=$TH_MIN_INTACT -v nn="$8" 'BEGIN{if(w=="NA"||t=="NA")print "NA"; else print (w<wm&&t>tm&&nn==0)?"YES":"NO"}')
    local alo=APL_LO_$sys ahi=APL_HI_$sys tlo=TH_LO_$sys thi=TH_HI_$sys
    local g1=$(in_range "$3" "${!alo}" "${!ahi}") g2=$(in_range "$6" "${!tlo}" "${!thi}") g
    if [ "$g1" = NA ] || [ "$g2" = NA ]; then g="NA_noref"; elif [ "$g1$g2" = PASSPASS ]; then g=PASS; else g=FAIL; fi
    printf '%s\trep%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' $sys $r "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$8" "$intact" "$g" "$d/prod.xtc" "$d/prod.log" >> "$out"
  done; done
  # 系统级: 均值/sd(副本=统计单位)、自洽、A/B 可区分
  awk -F'\t' -v ar=$APL_RANGE_MAX -v tr=$TH_RANGE_MAX -v mp=$MIN_PROD_NS '
    NR>1 && $5!="NA" && $8!="NA" {if($4+0<mp) short=1; s=$1; n[s]++; a[s,n[s]]=$5; t[s,n[s]]=$8; if($11!="YES") bad[s]++}
    function st(arr,s,  i,m,v,mn,mx){m=0;for(i=1;i<=n[s];i++)m+=arr[s,i];m/=n[s];v=0;mn=1e9;mx=-1e9
      for(i=1;i<=n[s];i++){v+=(arr[s,i]-m)^2; if(arr[s,i]<mn)mn=arr[s,i]; if(arr[s,i]>mx)mx=arr[s,i]}
      SD=(n[s]>1)?sqrt(v/(n[s]-1)):0; MN=mn; MX=mx; return m}
    function sep(arr,  ma,mb,sa,sb,mna,mxa,mnb,mxb,d,sd){ if(n["A"]<3||n["B"]<3) return "NA(n<3)"
      ma=st(arr,"A");sa=SD;mna=MN;mxa=MX; mb=st(arr,"B");sb=SD;mnb=MN;mxb=MX; d=mb-ma; if(d<0)d=-d; sd=(sa>sb)?sa:sb
      return ((mnb>mxa||mna>mxb) && d>2*sd) ? "YES" : "NO" }
    END{ print "# per-system (replicate = statistical unit)"
      print "system\tn\tAPL_mean\tAPL_sd\tAPL_range\tTH_mean\tTH_sd\tTH_range\tall_intact\tself_consistent"
      for(s in n){ am=st(a,s);asd=SD;arg=MX-MN; tm=st(t,s);tsd=SD;trg=MX-MN
        printf "%s\t%d\t%.4f\t%.4f\t%.4f\t%.3f\t%.3f\t%.3f\t%s\t%s\n", s,n[s],am,asd,arg,tm,tsd,trg,(bad[s]?"NO":"YES"),((n[s]>=2&&arg<ar&&trg<tr)?"YES":"NO") }
      print "# A vs B distinguishability (pre-registered: full separation of 3v3 AND |dmean|>2*max(sd))"
      da=sep(a); dt=sep(t)
      printf "APL\t%s\nPO4PO4\t%s\n", da, dt
      v=(da=="YES"||dt=="YES")?"ESTABLISHED":"NOT_ESTABLISHED"
      if(bad["A"]) v=v"_BUT_NEG_CONTROL_NOT_INTACT(INVALID)"
      if(short) v=v"_PRELIM(prod<" mp "ns)"
      printf "VERDICT\t%s\n", v }' "$out" > "$WORK/SUMMARY.tsv"
  log "汇总写入 $out 和 $WORK/SUMMARY.tsv"; cat "$out" "$WORK/SUMMARY.tsv" | tee -a "$LOG"; }

# ================= 主流程 =================
REPS=""; for r in $(seq 1 $NREP); do for s in $SYSTEMS; do REPS="$REPS $s/rep$r"; done; done   # A1 B1 A2 B2...: 时间不够时也成对
[ -n "$ONLY" ] && REPS="$ONLY"
NREPS=$(echo $REPS | wc -w)
log "==== run2-lnp 过夜实验 MODE=$MODE WORK=$WORK FF=$FF ===="
log "将执行: 体系[$SYSTEMS] x $NREP 副本 = $NREPS 条流水线(顺序:$REPS); T=${TEMP}K salt=${SALT}M box=${BOX}nm"
log "每条: insane -> EM(≤20000步) -> EQ1 ${EQ1_NS}ns(dt10fs) -> EQ2 ${EQ2_NS}ns -> PROD(≤${PROD_NS}ns, -maxh 自适应≤${PROD_MAXH_CAP}h, flags='$GPUFLAGS') -> 分析"
log "预计时长(估算): 每条 ≈ ${OVERHEAD_MIN}min 开销 + production ≤${PROD_MAXH_CAP}h; 整批 ≈ $(awk -v n=$NREPS -v o=$OVERHEAD_MIN -v c=$PROD_MAXH_CAP 'BEGIN{printf "%.1f", n*(o/60+c)}')h 上限; MD 截止 $MD_DEADLINE SGT"
for f in martini_v3.0.0.itp martini_v3.0.0_ffbonded_v2.itp martini_v3.0.0_phospholipids_PC_v2.itp martini_v3.0.0_sterols_v1.itp MC3.itp martini_v3.0.0_solvents_v1.itp martini_v3.0.0_ions_v1.itp insane3.py; do
  [ -s "$FF/$f" ] || die "缺力场文件 $FF/$f"; done
command -v python3 >/dev/null || die "宿主机缺 python3(insane 需要)"

if [ "$ANALYZE_ONLY" != 1 ]; then
i=0
for rr in $REPS; do i=$((i+1)); sys=${rr%%/*}; r=${rr##*rep}; d="$WORK/$sys/rep$r"; mkdir -p "$d"
  seed=$(( SEED_BASE + r*100 + $(printf '%d' "'$sys") ))
  [ -f "$d/.done_prod" ] && { log "$d: production 已完成，跳过"; continue; }
  [ -f "$d/.failed" ] && { log "$d: 之前失败(.failed)，跳过；删 .failed 可重试"; continue; }
  build "$sys" "$r" "$d" "$seed"
  step "$d" grompp_em "GMX grompp -f em.mdp -c sys.gro -p sys.top -o em.tpr -maxwarn 1" || { touch "$d/.failed"; continue; }
  w=$(grep -c '^WARNING' "$d/grompp_em.out"); [ "$w" -gt 1 ] && { log "$d: grompp EM 警告 $w>1"; touch "$d/.failed"; continue; }
  step "$d" em "GMX mdrun -deffnm em -nt $NT -pin auto" || { touch "$d/.failed"; continue; }
  grep -qiE 'converged to (Fmax|machine precision)' "$d/em.log" || log "$d: 警告 EM 未见收敛字样(仍继续，见 em.log)"
  step "$d" grompp_eq1 "GMX grompp -f eq1.mdp -c em.gro -p sys.top -o eq1.tpr -maxwarn 1" || { touch "$d/.failed"; continue; }
  step "$d" eq1 "GMX mdrun -deffnm eq1 -ntmpi 1 -ntomp $NT $GPUFLAGS" || { touch "$d/.failed"; continue; }
  step "$d" grompp_eq2 "GMX grompp -f eq2.mdp -c eq1.gro -t eq1.cpt -p sys.top -o eq2.tpr -maxwarn 1" || { touch "$d/.failed"; continue; }
  step "$d" eq2 "GMX mdrun -deffnm eq2 -ntmpi 1 -ntomp $NT $GPUFLAGS -cpi eq2.cpt" || { touch "$d/.failed"; continue; }
  step "$d" grompp_prod "GMX grompp -f prod.mdp -c eq2.gro -t eq2.cpt -p sys.top -o prod.tpr -maxwarn 1" || { touch "$d/.failed"; continue; }
  left=$(( NREPS - i + 1 )); mh=$(prod_maxh $left $(( left - 1 )))
  [ "$mh" = 0 ] && { log "已过 MD 截止 $MD_DEADLINE，停止开新 production"; break; }
  log "$d: production -maxh $mh (剩余 $left 条)"
  step "$d" prod "GMX mdrun -deffnm prod -ntmpi 1 -ntomp $NT $GPUFLAGS -maxh $mh -cpi prod.cpt" || { touch "$d/.failed"; continue; }
  grep -iqw 'nan' "$d/prod.log" && log "$d: 警告 prod.log 出现 nan"
  touch "$WORK/$sys/rep$r.DONE"
done
fi
summarize
touch "$WORK/ALL.DONE"; log "==== 全部结束 ===="
