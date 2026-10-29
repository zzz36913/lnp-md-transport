#!/usr/bin/env python3
"""R4 D1 闸门包装器 (同 R3_launch 版逐字, 只改此注释): 原样运行同目录下的 t0_gate.py(原件, 字节相同), 仅在 import 前把 topo_v2.CS_ANALYZER
重定向到同目录的 stalk_topology_analyzer.py (原件里这条路径写死在 box 的 /workspace/review_cs/..., Spark 上没有)。
读数逻辑/判据/退出码(0=PASS 或 hii N/A, 3=VOID)一律来自原件, 本文件不改任何判据。
用法同 t0_gate.py。"""
import os, sys, runpy
here = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, here)
import topo_v2
topo_v2.CS_ANALYZER = os.path.join(here, 'stalk_topology_analyzer.py')
sys.argv[0] = os.path.join(here, 't0_gate.py')
runpy.run_path(sys.argv[0], run_name='__main__')
