# HA-ENV-01 HA 支线环境部署包（tag `ha-env-v1`）

来源：K 2026-10-23 指示「等一有空余算力，就把环境都部署好」。本包**只做环境部署 + 自检 + 单槽吞吐基准**，不是生产发车（见 dd/21_ha_master_plan.md §6）。

## 硬约束
- **不和 J005 / 主线抢 GPU。** setup 和 selfcheck 只用 CPU 和磁盘（selfcheck 的容器不带 `--gpus`，用 `--cpus 4`，nice 19），任何时候都能跑。`bench_ha2.sh` 要用 GPU，**只在空闲窗口跑**：脚本启动前检查，发现别的 `gmx mdrun` 或者 GPU 利用率 >10% 就拒绝启动；EM 跑完后再查一次，有人占用就让路退出。
- 不碰 GLM（8888/18888 端口、key、模型名），不用 sudo/apt，不做任何 docker 镜像操作（更不做 prune）。
- k04 没有外网：所有东西从 k03 scp 过去，pip 走 k03 下载好的 `~/ha_env/wheels`（需两台 Python 主次版本相同）。

## k03（有网）
```bash
curl -fsSL https://cdn.jsdelivr.net/gh/zzz36913/lnp-md-transport@ha-env-v1/ha/fetch_ha_env.sh -o ~/fetch_ha_env.sh   # 镜像不通就换 fastly./gcore.jsdelivr.net 或 ghproxy.net
sha256sum ~/fetch_ha_env.sh            # 必须等于 RUNBOOK §46 / QUEUE HA-ENV-01 记的值
bash ~/fetch_ha_env.sh ha-env-v1       # → ~/ha_env，末行 "FETCH ALL OK (N files) tag=ha-env-v1"
bash ~/ha_env/setup_ha_env.sh          # 末行 "SETUP OK"；顺带把轮子下到 ~/ha_env/wheels 给 k04
bash ~/ha_env/selfcheck_ha.sh          # 末行 "SELFCHECK DONE pass=.. fail=.."
# 只在空闲窗口（两台都没有 J005/主线 mdrun）：
setsid bash ~/ha_env/bench_ha2.sh </dev/null >/dev/null 2>&1 &
```

## k04（离线，从 k03 推）
```bash
scp -r ~/ha_env ~/fetch_ha_env.sh k04@10.0.0.2:~/      # fetch 脚本末尾会打印这一行
ssh k04@10.0.0.2 'cd ~/ha_env && sha256sum -c --quiet SHA256SUMS && echo SUMS_OK'
ssh k04@10.0.0.2 'OFFLINE=1 bash ~/ha_env/setup_ha_env.sh && bash ~/ha_env/selfcheck_ha.sh'
```
scp 会把 k03 的 venv 一起拷过去，但 venv 里脚本的 shebang 写的是 k03 上的路径。`setup` 检测到路径不一致时，会删掉这个 venv，再按 `OFFLINE=1` 从 `wheels/` 重建（先核对 `wheels/PYVER` 是否一致）。想强制重建就加 `FORCE=1`。

## 耗时（全部是估算，未在 Spark 上实测）
| 步骤 | 资源 | 估算 |
|---|---|---|
| fetch（约 3 MB 包 + 16 MB martini_v3.0.0.itp，如果 ~/lnp_ff 已有就直接拷） | 网络 | 1–3 min |
| setup（pip 约 12 个包 + 下载 wheels） | CPU/网络 | 5–15 min |
| selfcheck（6 次 grompp：Go nbparams 很大，单次约 1 min；外加 CPU EM 几秒） | CPU ≤4 核 | 8–15 min |
| bench（EM + EQ 0.5 ns + PROD 10 ns，按约 2400 ns/day 估算） | 1 个 GPU 槽 + 6 核 | 10–20 min |
| k04 scp + 离线 setup + selfcheck | 内网/CPU | 10–20 min |

两台合计约 1–2 机时（估算）。

## 包内容
- `ha_common.sh`：docker 调用（同 J005 写法：`sg docker -c "docker run --rm ... ghcr.io/novomcp/gromacs-md:spark"`，容器内 GROMACS 2026.3）。
- `setup_ha_env.sh`：幂等安装 `venv`，包括 vermouth 0.15.0/martinize2（GōMartini 3 用 `-go`，内置 DSSP 走 mdtraj）、mdtraj、MDAnalysis、numpy/scipy/pandas/matplotlib/pymbar/tqdm，以及 martini_sour（来自 vendor，用 `--no-deps` 装）、titratable_martini_tools、Titratable Martini 教程文件和 GoMartini ContactMapGenerator（本机有 cc 才编译，属可选）。还会用 `ff/make_go_ff.py` 重新生成四个体系的 Go 合并 `martini.itp`，并按写死的 sha 校验。
- `selfcheck_ha.sh`：检查版本、sha、容器 gmx 和 GPU 可见性；对四个体系做真空 grompp，对 HA2 水盒做 grompp 并跑一次 CPU EM；再跑兼容试验 T1/T2。
- `bench_ha2.sh`：单槽 10 ns 吞吐基准，只在空闲时跑。
- `systems/{pre,post,pre2,post2}`：martinize2 产出的 itp/top/box.gro 和 Go 参数。
- `ha2box/`：HA2 水盒，20836 珠（3HMG BHA 三聚体 4983 珠 + W 15429 + NA 224 + CL 200），以及 em/eq/prod.mdp。
- `compat/`：martini_sour × GōMartini 最小兼容试验，包含 vendor 来的 titratable 力场、`compat_merge.py` 和 T1/T2 拓扑。
- `vendor/`：上游源码原样拷贝，来源和 commit 见 `vendor/SOURCES.txt`。
- `ff/`：Martini 3 溶剂和离子 itp、`make_go_ff.py`、`em_vac.mdp`。`martini_v3.0.0.itp`（16 MB）不放进仓库，由 fetch 从 `~/lnp_ff` 拷贝或从上游拉取，按 sha 0ecbf0ff…754894 校验。

## box 预演结果（GROMACS 2025.4 CPU，仅供参考，以 Spark 实测为准）
- HA2 水盒：grompp 0 警告，EM 1254 步收敛到 Fmax 91；EQ 3000 步、PROD 2000 步都正常，没有 nan。
- 兼容试验：T1 按预期失败（`Atomtype Q5 not found`）。T2 合并后 grompp 能过，但 **MISSING_PAIRS=60/66**：蛋白 22 种珠类型和 WNT/POS/DW 之间没有交叉 LJ 参数，GROMACS 会按零 LJ 处理且不报错。另外上游 titratable 示例用的是 PME + eps_r 6，而 Martini 3 蛋白用 RF eps_r 15。上游 `martini_sour conv_itp` 是空壳（只打印 "Not implemented yet."）。**结论：两者不能直接组合，交叉参数的来源要等 K 定。**
