# R2a 运行包 (方案 C, n=2, 10 条, 16 µs)
- R2a_pkg.tar.gz  sha256 d802b831165c254b3dfef757625ecd08b90486433cbe8a32a2b1133c0297f489 (192 项)
- MANIFEST_sha256.txt  sha256 08608fcf66149196aa4d149065f0298bd9c37dc480e9472c071fd07e21c595d6 (包内文件清单, 解压后 sha256sum -c)

## 取包与校验
  mkdir -p $HOME/R2a && cd $HOME && curl -sSL <tarball URL> -o R2a_pkg.tar.gz && sha256sum R2a_pkg.tar.gz   # 须等于上面的 sha256
  tar -xzf R2a_pkg.tar.gz -C $HOME/R2a   # 若包内已含 R2a/ 顶层目录, 以 tar -tzf 先看
  cd $HOME/R2a && sha256sum -c MANIFEST_sha256.txt

## 发车 (详见包内 README_R2a.md; k03=seed1, k04=seed2; MPS 目录 $HOME/mps_R2a 须为空/不存在)
  DRY=1 bash scripts/R2a_machine.sh k03        # 先干跑
  nohup bash scripts/R2a_machine.sh k03 > R2a_k03.log 2>&1 &     # k04 机把 k03 换成 k04
截止 2026-10-28 07:30 +0800 (-maxh 自动收尾)。需 GLM 已停后再发。
