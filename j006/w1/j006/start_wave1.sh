#!/bin/bash
# J006 波 1 发车（每台一条命令）：  HT=k03 bash ~/ph_phase_j006/j006/start_wave1.sh    (k04 同理 HT=k04)
# k03 3 槽（另有 1 槽被 T100_rep2 填充占用）/ k04 4 槽，每槽 -ntomp 5（NT_SLOT=5），接力队列，截止 2026-10-24 22:30（SGT）；队列尾 F 行 = 波 2 钩子 wave2_hook.sh。
# 先决: 本机 ~/ph_phase_j006 已 fetch 并通过 SHA256SUMS；GLM/8888/18888 已按 K 授权停（本脚本不碰）。
export TZ=Asia/Singapore
HT=${HT:?need HT=k03|k04}
export PH=$HOME/ph_phase_j006 WORK=$HOME/ph_j006_run FF=${FF:-$HOME/lnp_ff} MODE=docker
export MD_DEADLINE=${MD_DEADLINE:-'2026-10-24 22:30'} SLOTS=${SLOTS:-$([ $HT = k04 ] && echo 4 || echo 3)} NT_SLOT=${NT_SLOT:-5} MIN_LEFT_H=${MIN_LEFT_H:-1}
export QUEUE_FILE=$PH/queue_$HT.txt
mkdir -p $WORK
( cd $PH && sha256sum -c --quiet SHA256SUMS ) || { echo "SHA256SUMS 校验失败，不发车"; exit 1; }
[ -d $FF ] || { echo "FF=$FF 不存在（Martini 核心 itp 目录）"; exit 1; }
setsid nohup bash $PH/run_phase.sh </dev/null >/dev/null 2>&1 &
HT=$HT PH=$PH WORK=$WORK FF=$FF SLOTS=$SLOTS NT_SLOT=$NT_SLOT setsid nohup bash $PH/j006/wave2_hook.sh </dev/null >> $HOME/j006_wave2_hook_$HT.out 2>&1 &
sleep 3; echo "J006 wave1 $HT 已发车 $(date '+%F %T') 截止 $MD_DEADLINE SLOTS=$SLOTS 日志 $WORK/phase.log"; pgrep -af "[r]un_phase" | head -2
