R4N2_rv3 k03 night2 VOID_L2 gate JSON (2026-10-31 16:24:20 +0800, run R4N2_run_k03_1031_150232, host spark-235d)
builds: R4N1_MC3H_h100_T350_hii_s1 R4N1_MC3H_h100_T350_hii_s2 R4N1_MC3H_h100_T350_hii_s3 R4N1_MC3H_h100_T350_hii_s4 R4N1_MC3_h100_T350_hii_s1 R4N1_MC3_h100_T350_hii_s2 R4N1_MC3_h100_T350_hii_s3 R4N1_MC3_h100_T350_hii_s4
void_k03_rv3_frames.tsv: 每个闸门 JSON 一行 (select/attempt_*/gate_frames/f<idx>_try<n>.json 逐帧 + gate/attempt_*/gate.json 末帧 frame=relax_end)
dL*/L0 = JSON box_dev (|L/L0-1|), sd* = 带符号 L/L0-1 (L0 = inputs/<b>/expect.env BOX0), L/C/wpol/n_tube = readings.*, t_ps 取自 frames.tsv
void_k03_rv3_raw.tar.gz: 原样 (tar -xzf 得 builds/<b>/{gate,select}/...); void_k03_rv3_raw_sha256.txt: 包内每个文件 sha256
check: sha256sum -c SHA256SUMS
