#!/bin/bash
# gate_py_container.sh  --  GATE_PY 包装脚本草案 (放在 R3_launch/ 之外, 不改 run_R3.sh / lib_R3.sh)
# *** 未在 Spark 上验证 (box 上没有 docker; 只做过静态审查 + docker 垫片参数传递测试, 见 README_gatewrap.md) ***
#
# 作用: 宿主 python3 没有 numpy, 所以把 "python3 <args>" 转到镜像 ghcr.io/novomcp/gromacs-md:spark 里跑
#       (镜像内 Python 3.10.12 + numpy 1.24.3 / scipy 1.15.3 / MDAnalysis 2.7.0, 来自调度实读).
# 调用方式 (在 Spark 上发车命令前面加 GATE_PY):
#       GATE_PY=$HOME/R3_gatewrap/gate_py_container.sh bash run_R3.sh k03      # chmod +x 已做; 路径不要含空格 (lib_R3.sh 里 $GATE_PY 不带引号)
# lib_R3.sh / run_R3.sh 里的两种调用:
#       ( cd $d && $GATE_PY $HERE/gate/t0_gate_launch.py $rd/relax.gro --level prod0 ... --json gate.json )
#       $GATE_PY -c 'import numpy, scipy, MDAnalysis'
# 其中 $HERE=R3_launch 目录, $d/$rd 在 $OUT=$HOME/R3/R3_run_* 之下, CHECK 的 OUT=/tmp/R3_check_$$, 自检用 mktemp -d (/tmp) —— 全部落在下面的 -v 挂载范围内.
# 可选环境变量: GATE_IMG (默认 ghcr.io/novomcp/gromacs-md:spark; 注意 lib_R3.sh 的 IMG 没有 export, 所以这里不读 IMG, 想换镜像设 GATE_IMG)
set -u
IMG_G=${GATE_IMG:-ghcr.io/novomcp/gromacs-md:spark}
# 挂载: $HOME 读写 (闸门要把 gate.json 写进 $OUT 下的 attempt 目录, 并读 $HERE/gate、$HERE/inputs 与 relax.gro); /tmp 读写 (CHECK 的 OUT 和 mktemp -d).
# 工作目录用调用者的 $PWD (lib_R3.sh 是先 cd 再调用, gate.json 用相对路径写在 cwd). 若 $PWD 不在 $HOME 或 /tmp 之下 (例如 CHECK 里的 -c 导入测试从 / 或 /var 起),
# 容器内看不到该目录, 退到 -w /tmp 并在 stderr 警告 (纯 -c 导入测试不受影响; step_gate 总是 cd 进 $HOME 下的 attempt 目录, 不会走到这条).
W=$PWD
case "$PWD" in "$HOME"|"$HOME"/*|/tmp|/tmp/*) ;; *) echo "gate_py_container.sh: 警告 PWD=$PWD 不在 \$HOME 或 /tmp 下, 容器内改用 -w /tmp" >&2; W=/tmp;; esac
# 不加 --gpus (闸门纯 CPU, 不碰 GPU/MPS, 不占卡); 不起名字 (随机名, 不会匹配 R2a_/R2b_/R3*/j009_ 前缀, 也不会被 run_R3.sh 的 cleanup 误停或被 CHECK 当成占卡容器).
# --network none: 闸门不联网. HOME=/tmp: -u 非 root 时容器里没有可写 HOME (MDAnalysis/matplotlib 缓存). PYTHONDONTWRITEBYTECODE=1: 不往 $HERE/gate 写 __pycache__ (保持包文件字节不变).
# 线程限 2: 闸门与另一槽的 mdrun 同机并行时, 别抢 Grace CPU.
exec docker run --rm --network none \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp -e MPLCONFIGDIR=/tmp -e PYTHONDONTWRITEBYTECODE=1 \
  -e OMP_NUM_THREADS=2 -e OPENBLAS_NUM_THREADS=2 -e MKL_NUM_THREADS=2 \
  -v "$HOME:$HOME" -v /tmp:/tmp -w "$W" \
  --entrypoint python3 "$IMG_G" "$@"
