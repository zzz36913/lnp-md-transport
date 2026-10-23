#!/usr/bin/env bash
# HA-ENV-01 setup：在 ~/ha_env 里幂等装好 HA 支线用户态环境。纯 CPU/磁盘，不占 GPU。
#   - 不用 sudo/apt、不改系统、不碰 GLM（8888/18888）、不做任何 docker 镜像操作（更不 prune）。
#   - Python 包装进 $HA/venv（版本钉死，pip 按索引 sha256 自动校验；下载的轮子另记真实 sha256 到 logs/）。
#   - vendor/ 里的上游源码与教程 zip 由 fetch_ha_env.sh 按 SHA256SUMS 逐文件校验过；这里再 sha256sum -c 一遍。
# 用法：
#   k03（有网）：bash ~/ha_env/setup_ha_env.sh            # 装环境 + 顺带把轮子下到 ~/ha_env/wheels 给 k04
#   k04（离线）：OFFLINE=1 bash ~/ha_env/setup_ha_env.sh  # 只用 ~/ha_env/wheels（需与 k03 同 Python 主次版本）
# 可选变量：PY=python3  PIP_INDEX=<url>  DOWNLOAD_WHEELS=1|0（k03 默认 1）  FORCE=1（重建 venv）
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/ha_common.sh"
cd "$HA" || exit 1; mkdir -p logs bin wheels
LOG=$HA/logs/setup_$(date +%Y%m%d_%H%M%S).log; : > "$LOG"
PY=${PY:-python3}; OFFLINE=${OFFLINE:-0}; DOWNLOAD_WHEELS=${DOWNLOAD_WHEELS:-$([ "$OFFLINE" = 1 ] && echo 0 || echo 1)}
fail(){ log "SETUP FAILED step=$1 —— $2"; echo "SETUP FAILED step=$1" > SETUP_STATUS; exit 1; }
log "HA-ENV-01 setup 开始 host=$(hostname) arch=$(uname -m) HA=$HA OFFLINE=$OFFLINE"

# 1) 包内文件完整性
sha256sum -c --quiet SHA256SUMS >> "$LOG" 2>&1 || fail sums "SHA256SUMS 校验不过，先重跑 fetch_ha_env.sh"
log "1/7 SHA256SUMS OK ($(wc -l < SHA256SUMS) files)"

# 2) Martini 3 基础力场（fetch 已放到 ff/；这里只核 sha）
MSHA=0ecbf0ff334b2ec21dc5e3151aca42167b977bc2aed41eb2a44bd8c997754894
[ "$(sha256sum ff/martini_v3.0.0.itp 2>/dev/null | cut -d' ' -f1)" = "$MSHA" ] || fail ff "ff/martini_v3.0.0.itp 缺失或 sha 不符（应为 $MSHA），重跑 fetch_ha_env.sh"
log "2/7 martini_v3.0.0.itp sha OK"

# 3) 四个体系的 Go 合并 martini.itp（make_go_ff.py 重新生成；与 box 上原件逐字节一致的 sha 写死在这里）
declare -A GOSHA=([pre]=2da8f39f7de12dfda274de73b45664e17c3b463505131144d407b96c1c231f0d [post]=da3c678761f8a42d6612cc305b149d4f9643163d6ce1df0b88f0b40aaa328d58 \
                  [pre2]=9c053b826e7d47b4becb713f6dab14835bf379080caf5489e36af3112fff71ce [post2]=4db5714cf23f923638e35acedea2af8099ce54043665a5bc6f2e57718ca3af52)
for s in pre post pre2 post2; do o=systems/$s/martini.itp
  [ "$(sha256sum "$o" 2>/dev/null | cut -d' ' -f1)" = "${GOSHA[$s]}" ] && continue
  $PY ff/make_go_ff.py ff/martini_v3.0.0.itp systems/$s/go_atomtypes.itp systems/$s/go_nbparams.itp "$o" >> "$LOG" 2>&1
  [ "$(sha256sum "$o" | cut -d' ' -f1)" = "${GOSHA[$s]}" ] || fail goff "$o 重新生成后 sha 不符"
done
log "3/7 Go 合并 martini.itp ×4 sha OK"

# 4) venv
VENV=$HA/venv
if [ "${FORCE:-0}" = 1 ]; then rm -rf "$VENV"; fi
# venv 被 scp 到别的路径/用户（k03→k04）后脚本 shebang 失效：检测到就删掉，从 wheels 重建
if [ -f "$VENV/bin/martinize2" ] && ! head -1 "$VENV/bin/martinize2" | grep -qF "$VENV/bin/"; then log "  venv 来自别的路径，重建"; rm -rf "$VENV"; fi
if [ ! -x "$VENV/bin/python" ]; then
  $PY -m venv "$VENV" >> "$LOG" 2>&1 || { rm -rf "$VENV"; log "python3 -m venv 不可用，退到 pip --user virtualenv"
    $PY -m pip install --user -q virtualenv >> "$LOG" 2>&1 && $PY -m virtualenv "$VENV" >> "$LOG" 2>&1 || fail venv "无 venv/virtualenv（不装系统包；请 K 决定：apt 装 python3-venv，或改用容器内 pip）"; }
fi
VP=$VENV/bin/python; PYVER=$($VP -c 'import sys;print("%d.%d"%sys.version_info[:2])')
log "4/7 venv OK ($VENV, Python $PYVER)"

# 5) pip 安装（钉死版本 → 不行退宽松版本）；k04 离线只认 wheels/
PIPQ="$VP -m pip --disable-pip-version-check --timeout 60 -q"
if [ "$OFFLINE" = 1 ]; then
  [ "$(cat wheels/PYVER 2>/dev/null)" = "$PYVER-$(uname -m)" ] || fail wheels "wheels/PYVER=$(cat wheels/PYVER 2>/dev/null) 与本机 $PYVER-$(uname -m) 不符"
  SRC="--no-index --find-links $HA/wheels"
else
  SRC=""
  for idx in ${PIP_INDEX:-} https://pypi.org/simple https://pypi.tuna.tsinghua.edu.cn/simple https://mirrors.aliyun.com/pypi/simple; do
    $PIPQ download --no-deps -d /tmp/ha_pipprobe_$$ pbr==7.1.3 -i "$idx" >> "$LOG" 2>&1 && { SRC="-i $idx"; break; }
  done; rm -rf /tmp/ha_pipprobe_$$
  [ -n "$SRC" ] || fail pip "所有 PyPI 源都连不上"
fi
log "5/7 pip 源：${SRC}"
if $VP -c 'import vermouth,mdtraj,MDAnalysis,numpy,scipy,pandas,matplotlib,pymbar,tqdm' 2>/dev/null && [ "${FORCE:-0}" != 1 ]; then
  log "  Python 包已在，跳过安装（幂等）"; REQ=$(cat .req_used 2>/dev/null || echo requirements-ha.txt)
else
  REQ=requirements-ha.txt
  $PIPQ install $SRC -r $REQ >> "$LOG" 2>&1 || { log "  钉死版本装不上（多半某包无本机轮子），退到宽松版本"; REQ=requirements-ha.loose.txt
    $PIPQ install $SRC -r $REQ >> "$LOG" 2>&1 || fail pip "requirements 安装失败，见 $LOG"; }
  echo "$REQ" > .req_used
fi
# martini_sour（vendor 源码，--no-deps：上游钉的 networkx~=2.0/decorator==4.4.2 与 vermouth 0.15 冲突）
$VP -c 'import martini_sour' 2>/dev/null || PBR_VERSION=0.0.1 $PIPQ install --no-deps --no-build-isolation vendor/martini_sour-67ac029.tar.gz >> "$LOG" 2>&1 || fail martini_sour "vendor 安装失败"
if [ "$DOWNLOAD_WHEELS" = 1 ]; then
  $PIPQ download $SRC -d wheels -r $REQ >> "$LOG" 2>&1 && $PIPQ download $SRC -d wheels setuptools wheel pip >> "$LOG" 2>&1 \
    && echo "$PYVER-$(uname -m)" > wheels/PYVER && (cd wheels && find . -type f ! -name PYVER -exec sha256sum {} + | sort -k2 > ../logs/wheels_sha256.txt) \
    && log "  轮子已下到 wheels/（$(ls wheels | wc -l) 个，真实 sha256 见 logs/wheels_sha256.txt），供 k04 离线装" \
    || log "  WARN 轮子下载不全，k04 离线安装可能失败"
fi
$PIPQ freeze > logs/pip_freeze.txt 2>&1
log "6/7 Python 包 OK（$REQ）"

# 7) 工具：titratable 脚本、教程文件、GoMartini contact_map（有 cc 才编）、env.sh
mkdir -p tools; cp -f vendor/titratable_martini_tools-032da52/*.py tools/
[ -d tutorial_titratable ] || $VP -c "import zipfile;zipfile.ZipFile('vendor/titratable_martini_tutorial_files.zip').extractall('tutorial_titratable')"
rm -rf tutorial_titratable/__MACOSX
if [ ! -x bin/contact_map ]; then
  CC=$(command -v cc || command -v gcc || command -v clang || true)
  if [ -n "$CC" ]; then rm -rf /tmp/ha_cmg_$$; cp -r vendor/GoMartini-17d2ebf/ContactMapGenerator /tmp/ha_cmg_$$
    (cd /tmp/ha_cmg_$$ && $CC -O2 -o "$HA/bin/contact_map" *.c -lm) >> "$LOG" 2>&1 && log "  contact_map 已编译" || log "  WARN contact_map 编译失败（可选工具，martinize2 -go 自带接触图，不影响）"
    rm -rf /tmp/ha_cmg_$$
  else log "  SKIP contact_map：本机无 C 编译器（可选，martinize2 -go 自带接触图）"; fi
fi
cat > env.sh <<EOS
# source ~/ha_env/env.sh 后可用 martinize2 / martini_sour / tools/*.py
export HA_ENV=$HA
export PATH=$HA/venv/bin:$HA/bin:\$PATH
EOS
log "7/7 工具 OK"
{ echo "host=$(hostname) arch=$(uname -m) python=$PYVER req=$REQ time=$(ts)"
  $VENV/bin/martinize2 -V 2>&1 | head -1
  $VP -c 'import vermouth,mdtraj,MDAnalysis,numpy,scipy,pandas,pymbar,networkx;print("vermouth",vermouth.__version__,"mdtraj",mdtraj.__version__,"MDAnalysis",MDAnalysis.__version__,"numpy",numpy.__version__,"scipy",scipy.__version__,"pandas",pandas.__version__,"pymbar",pymbar.__version__,"networkx",networkx.__version__)' 2>/dev/null | tail -1
  echo "martini_sour $($VENV/bin/martini_sour -V 2>&1 | tail -1)"; } > VERSIONS.txt 2>&1
cat VERSIONS.txt | tee -a "$LOG"
echo "SETUP OK $(ts)" > SETUP_STATUS; log "SETUP OK —— 下一步：bash $HA/selfcheck_ha.sh"
