#!/bin/bash
# 重写 MANIFEST_sha256.txt (包内全部文件, 除 MANIFEST 自身); 在 D1 根目录执行
cd "$(dirname "$0")/.." && find . -type f ! -name MANIFEST_sha256.txt ! -path './.git/*' -printf '%P\n' | LC_ALL=C sort | xargs -d '\n' sha256sum > MANIFEST_sha256.txt && wc -l MANIFEST_sha256.txt
