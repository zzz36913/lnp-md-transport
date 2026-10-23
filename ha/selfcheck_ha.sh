#!/usr/bin/env bash
# HA-ENV-01 自检（只读：不改环境，只在 ~/ha_env/selfcheck/<时间戳>/ 写 grompp 产物与日志）。默认纯 CPU（容器不带 --gpus，--cpus 4，nice 19）。
# 内容：①组件版本 ②SHA256SUMS ③容器内 gmx 版本 + GPU 可见性（只列设备，不跑计算）④四体系真空 grompp（应过）
#       ⑤HA2 水盒 grompp（应过）⑥martini_sour×GōMartini 最小兼容试验 T1（预期失败）/T2（grompp + 缺失配对统计）⑦可选 HA2 水盒极短 CPU EM（RUN_EM=1 默认开）
# 用法：bash ~/ha_env/selfcheck_ha.sh      结果：~/ha_env/selfcheck/<ts>/SELFCHECK.txt，末行 "SELFCHECK DONE pass=.. fail=.."
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ha_common.sh"
W=$HA/selfcheck/$(date +%Y%m%d_%H%M%S); mkdir -p "$W"; LOG=$W/selfcheck.log; R=$W/SELFCHECK.txt; : > "$R"
RUN_EM=${RUN_EM:-1}; NT=${NT:-4}; P=0; F=0
ok(){ echo "PASS $*" | tee -a "$R"; P=$((P+1)); }; bad(){ echo "FAIL $*" | tee -a "$R"; F=$((F+1)); }; note(){ echo "INFO $*" | tee -a "$R"; }
renice -n 19 $$ >/dev/null 2>&1 || true
note "host=$(hostname) arch=$(uname -m) time=$(ts) MODE=$MODE IMAGE=$IMAGE"
others_running && note "检测到别的 gmx mdrun 在跑（J005/主线）——本自检只用 CPU（≤$CPUS 核），不碰 GPU 计算" || note "当前无别的 gmx mdrun"

# ① 版本
if [ -x "$HA/venv/bin/python" ]; then cat "$HA/VERSIONS.txt" 2>/dev/null | sed 's/^/INFO ver: /' | tee -a "$R"
  "$HA/venv/bin/python" -c 'import vermouth,mdtraj,MDAnalysis,numpy,scipy,pymbar,martini_sour' 2>>"$LOG" && ok "python 组件可导入（vermouth/mdtraj/MDAnalysis/numpy/scipy/pymbar/martini_sour）" || bad "python 组件导入失败（先跑 setup_ha_env.sh）"
  "$HA/venv/bin/martinize2" -V >/dev/null 2>&1 && ok "martinize2: $("$HA/venv/bin/martinize2" -V 2>&1 | head -1)" || bad "martinize2 不可用"
else bad "venv 不存在（先跑 setup_ha_env.sh）"; fi
[ -x "$HA/bin/contact_map" ] && note "contact_map 已编译（可选）" || note "contact_map 未编译（可选，不计失败）"
# ② 完整性
(cd "$HA" && sha256sum -c --quiet SHA256SUMS) >>"$LOG" 2>&1 && ok "SHA256SUMS 全部对上" || bad "SHA256SUMS 有不符"
# ③ 容器 gmx + GPU 可见性
if [ "$MODE" = docker ]; then
  mkdir -p "$W/ver"; run_gmx "$W/ver" gmxver 0 "GMX -version"
  v=$(grep -m1 'GROMACS version' "$W/ver/gmxver.out" | sed 's/.*: *//'); [ -n "$v" ] && ok "容器 gmx $v ($(grep -m1 'GPU support' "$W/ver/gmxver.out" | sed 's/.*: *//'))" || bad "容器 gmx -version 失败，见 $W/ver/gmxver.out"
  $DOCKER_PFX "docker run --rm --gpus all --entrypoint /bin/sh $IMAGE -c 'nvidia-smi -L'" > "$W/ver/gpu.out" 2>&1 && ok "容器内 GPU 可见：$(head -1 "$W/ver/gpu.out")" || bad "容器内 GPU 不可见，见 $W/ver/gpu.out"
  note "宿主 GPU 利用率=$(gpu_util)%（只读）"
else note "MODE=local：gmx $(gmx --version 2>/dev/null | grep -m1 'GROMACS version' | sed 's/.*: *//')，跳过 GPU 检查"; fi
# ④ 四体系真空 grompp（-maxwarn 1：top 与 mdp 重复定义 GO_VIRT 的已知警告）
for s in pre post pre2 post2; do d=$W/sys_$s; mkdir -p "$d"
  run_gmx "$d" grompp 0 "GMX grompp -f $HA/ff/em_vac.mdp -c $HA/systems/$s/box.gro -p $HA/systems/$s/HA_$s.top -o em.tpr -po mdout.mdp -maxwarn 1"
  [ -s "$d/em.tpr" ] && ok "grompp $s（$(sed -n 2p "$HA/systems/$s/box.gro" | tr -d ' ') 珠）" || bad "grompp $s，见 $d/grompp.out"
done
# ⑤ HA2 水盒 grompp（maxwarn 0）+ ⑦ 可选 CPU EM
d=$W/ha2box; mkdir -p "$d"
run_gmx "$d" grompp 0 "GMX grompp -f $HA/ha2box/em.mdp -c $HA/ha2box/ha2box.gro -p $HA/ha2box/ha2box.top -o em.tpr -po mdout.mdp"
if [ -s "$d/em.tpr" ]; then ok "grompp HA2 水盒（$(sed -n 2p "$HA/ha2box/ha2box.gro" | tr -d ' ') 珠，maxwarn 0）"
  if [ "$RUN_EM" = 1 ]; then
    run_gmx "$d" em 0 "GMX mdrun -deffnm em -nb cpu -ntmpi 1 -ntomp $NT -pin off"
    fm=$(grep -m1 'Maximum force' "$d/em.log" 2>/dev/null | awk '{print $4}')
    if [ -n "$fm" ] && awk -v f="$fm" 'BEGIN{exit !(f<1000)}'; then ok "HA2 水盒 CPU EM Fmax=$fm (<1000) $(grep -m1 -E 'converged|did not converge' "$d/em.log")"; else bad "HA2 水盒 EM Fmax=${fm:-无} ，见 $d/em.out"; fi
  fi
else bad "grompp HA2 水盒，见 $d/grompp.out"; fi
# ⑥ 兼容性试验
d=$W/compat; mkdir -p "$d"
for t in t1_naive t2_merged; do sed "s#@HA@#$HA#g" "$HA/compat/$t.top" > "$d/$t.top"; done
run_gmx "$d" t1 0 "GMX grompp -f $HA/compat/compat.mdp -c $HA/systems/post/box.gro -p t1_naive.top -o t1.tpr -po t1_mdout.mdp" || true
if [ -s "$d/t1.tpr" ]; then note "兼容 T1（裸 include titratable 力场）意外通过——请人工看 $d/t1.out"
else note "兼容 T1 按预期失败：$(grep -m1 -i 'not found' "$d/t1.out" | sed 's/^ *//')"; P=$((P+1)); fi
PYX=$HA/venv/bin/python; [ -x "$PYX" ] || PYX=python3
$PYX "$HA/compat/compat_merge.py" "$HA/systems/post/martini.itp" "$HA/compat/ff_titratable" "$HA/systems/post/HA_post.itp" "$HA/systems/post/go_atomtypes.itp" "$d/merged_post.itp" "$d/compat_report.txt" "${PH_TEST:-5.00}" >> "$LOG" 2>&1
run_gmx "$d" t2 0 "GMX grompp -f $HA/compat/compat.mdp -c $HA/compat/t2_post_wna.gro -p t2_merged.top -o t2.tpr -po t2_mdout.mdp" || true
mp=$(grep -m1 MISSING_PAIRS "$d/compat_report.txt" 2>/dev/null)
[ -s "$d/t2.tpr" ] && ok "兼容 T2 合并力场 grompp 通过（语法层）；$mp" || bad "兼容 T2 grompp 失败，见 $d/t2.out；$mp"
note "兼容结论看 $d/compat_report.txt：MISSING_PAIRS>0 = 蛋白珠×WNT/POS/DW 无交叉 LJ 参数，不能直接上生产（待 K 定参数来源）"
echo "SELFCHECK DONE pass=$P fail=$F dir=$W $(ts)" | tee -a "$R"
