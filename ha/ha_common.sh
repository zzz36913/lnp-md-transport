#!/usr/bin/env bash
# HA-ENV-01 公共函数（setup/selfcheck/bench 共同 source）。不碰系统、不碰 GLM（8888/18888）、不做 docker image prune。
set -u
export TZ=Asia/Shanghai
HA=${HA_ENV:-$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)}
MODE=${MODE:-docker}                         # docker(k03/k04) | local(box 验证，用 PATH 里的 gmx)
IMAGE=${IMAGE:-ghcr.io/novomcp/gromacs-md:spark}
GMX_IN=${GMX_IN:-/usr/local/gromacs/bin/gmx}
DOCKER_PFX=${DOCKER_PFX:-sg docker -c}
CPUS=${CPUS:-4}                              # 容器 CPU 上限（grompp/EM 用，避免挤占在跑的作业）
ts(){ date '+%F %T %Z'; }
log(){ echo "[$(ts)] $*" | tee -a "${LOG:-/dev/null}"; }
# run_gmx <dir> <name> <gpu:0|1> <命令行...>：在 dir 里执行；命令里的 GMX 换成容器内 gmx 路径
run_gmx(){ local dir=$1 name=$2 gpu=$3; shift 3
  local f="$dir/.$name.sh"
  { echo 'set -e'; echo "cd '$dir'"; printf '%s\n' "$@"; } > "$f"
  if [ "$MODE" = docker ]; then
    sed -i "s#^GMX #$GMX_IN #; s# GMX # $GMX_IN #g" "$f"
    local g=""; [ "$gpu" = 1 ] && g="--gpus all"
    $DOCKER_PFX "docker run --rm $g --cpus $CPUS --entrypoint /bin/sh -u $(id -u):$(id -g) -e HOME=/tmp -v '$HA':'$HA' -w '$dir' $IMAGE '$f'" > "$dir/$name.out" 2>&1
  else
    sed -i "s#^GMX #gmx #; s# GMX # gmx #g" "$f"
    sh "$f" > "$dir/$name.out" 2>&1
  fi; }
# 有没有别的 mdrun 在跑（J005/主线）。有就返回 0。
others_running(){ pgrep -f 'gmx[^ ]* mdrun' >/dev/null 2>&1; }
gpu_util(){ nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>/dev/null | head -1 | tr -d ' '; }
