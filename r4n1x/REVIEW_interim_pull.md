# interim_pull.sh 草稿自审 (2026-10-30 13:2x SGT, box)
范围: 包外草稿, 不在 R4N1 / R4N1x MANIFEST 里; 改它不触发重建包.
## 自审发现并已改
1. 初稿在判 "OUTDIR 在运行目录外" 之前就 mkdir -p OUTDIR -> 若误把 OUTDIR 指进运行目录会先在里面建目录. 改为先 realpath -m 判, 通过后才 mkdir. 已测: 指进运行目录 -> rc=2, 运行目录里没有新建任何东西.
2. DRY / 无 DONE 时在 OUTDIR 留下 .interim_tmp_*: 改为 tar 前才 mktemp.
3. tar 内路径出现 "//prod": 去掉 builds/*/ 的尾斜杠.
4. 接收端不能直接对 SHA256_out.txt 做 -c (它还列了未打包的 edr/log/cpt/gro): 头注释写明改用 .files.tsv 复核.
## box 冒烟 (MODE=local 冒烟运行目录 + 主包冒烟运行目录 + 人工构造的假运行目录)
- 真实运行目录 2 个: 4 条 DONE 全打包; 打包前后 find(size,mtime)+全文件 sha256 快照一致 (运行目录未被改).
- 正在跑的条目 (k03 APPEND_TO 续跑时 s2 只有 relax/select): SKIP no_prod_attempt, 不碰.
- 构造: 无 STATUS -> SKIP RUNNING_OR_NO_STATUS; TRUNC -> SKIP not_DONE; xtc 被改 1 字节 -> REFUSE SHA_MISMATCH; 多一个未列入 SHA256_out 的 xtc -> REFUSE NOT_IN_SHA256_OUT; 续跑两段 (attempt_001 TRUNC_TIMEOUT + attempt_002 DONE part0002) -> 两段 xtc + tpr + 两份 SHA256_out 全打包.
- 接收端: sha256sum -c *.tar.sha256 OK; 解开后按 .files.tsv 复核 OK.
## 未测 / 已知限制
- "打包期间源文件变了 -> .VOID" 分支未构造触发 (DONE 条目按设计不会再被写).
- 只在 box (GNU tar/coreutils, bash 5) 跑过; Spark 上未跑.
- tar 读文件会更新 atime (只读访问的正常副作用), 不改 mtime/内容.
- 不含 edr/log/gro/cpt/relax/gate 记录; 中途判读若要 RUN 级记录 (ALL_RECORDS.tsv 等) 需另加, 本草稿按要求只打 xtc+tpr+SHA256_out.
## 用法 (21:00 前后)
OUTDIR=$HOME/R4_interim LABEL=2100 DRY=1 bash interim_pull.sh ~/R4N1/R4N1_run_k03_* ~/R4N1x/R4N1x_run_k03_*   # 先看清单
OUTDIR=$HOME/R4_interim LABEL=2100 bash interim_pull.sh ~/R4N1/R4N1_run_k03_* ~/R4N1x/R4N1x_run_k03_*
