#!/bin/bash
# J006: box CPU(gmx 2025.2) 烟测——读 queue 里每条 ph 行的参数，建体系 + grompp(em,eq1) (BUILD_ONLY=1)。
# 用法: FF=<核心 itp 目录> WORK=<烟测目录> bash smoke_box.sh queue_k03.txt queue_k04.txt
PH=$(cd "$(dirname "$0")/.." && pwd)
for q in "$@"; do grep '^ph ' "$q" | while read -r _ name rest; do
  ( for kv in $rest; do export "$kv"; done
    MODE=local MD_DEADLINE='2026-10-24 22:30' SYSTEMS=$name BUILD_ONLY=1 PARALLEL=0 bash $PH/run_phase.sh ) ; done; done
