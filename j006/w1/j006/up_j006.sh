#!/bin/bash
# 经 api.github.com 上传 ~/xfer/j006/out/* 到 zzz36913/lnp-md-transport 的 j006/out/。
# token：优先读环境变量 GT（只在内存）；没有则 read -rsp 提示输入（不回显）。绝不写盘、不打印。
# >45 MB 的文件按 45 MB 切成 .partNN 再传（Contents API 单文件上限）。box 端合并: cat f.part* > f
[ -n "${GT:-}" ] || { read -rsp 'token: ' GT; echo; }
export GT
D=${1:-$HOME/xfer/j006${TAGX:-w1}/out} python3 - <<'PY'
import os,glob,base64,json,urllib.request
T=os.environ['GT'];R='zzz36913/lnp-md-transport'
H={'Authorization':'Bearer '+T,'Accept':'application/vnd.github+json','User-Agent':'k03-j006'}
D=os.environ['D'].rstrip('/')+'/'; CH=45*1024*1024
items=[]
for f in sorted(glob.glob(D+'*')):
    if not os.path.isfile(f): continue
    b=open(f,'rb').read(); n=os.path.basename(f)
    if len(b)<=CH: items.append(('j006'+os.environ.get('TAGX','w1')+'/out/'+n,b))
    else:
        for i in range(0,len(b),CH): items.append(('j006/out/%s.part%02d'%(n,i//CH),b[i:i+CH]))
ok=0
for p,b in items:
    u='https://api.github.com/repos/%s/contents/%s'%(R,p); sha=None
    try: sha=json.load(urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=60))['sha']
    except Exception: pass
    d={'message':'j006 upload '+p,'content':base64.b64encode(b).decode()}
    if sha: d['sha']=sha
    try:
        r=urllib.request.urlopen(urllib.request.Request(u,data=json.dumps(d).encode(),headers=H,method='PUT'),timeout=900); ok+=1
        print('OK',p,len(b),r.status,flush=True)
    except Exception as e: print('FAIL',p,getattr(e,'code',''),str(e)[:120],flush=True)
print('UPLOAD %d/%d'%(ok,len(items)))
PY
unset GT
