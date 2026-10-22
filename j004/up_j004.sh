#!/bin/bash
# 同 ~/up.sh：经 api.github.com 上传 ~/xfer/j004 下 TSV/JSON/SUMMARY/非水末帧 .gro 到 j004/out/
read -rsp 'token: ' GT; echo; export GT
python3 - <<'PY'
import os,glob,base64,json,urllib.request
T=os.environ['GT'];R='zzz36913/lnp-md-transport'
H={'Authorization':'Bearer '+T,'Accept':'application/vnd.github+json','User-Agent':'k03'}
D=os.path.expanduser('~/xfer/j004/')
fs=sorted(glob.glob(D+'*.tsv')+glob.glob(D+'*.json')+glob.glob(D+'*_sq.dat')+glob.glob(D+'SUMMARY.txt')+glob.glob(D+'*.gro'))
ok=0
for f in fs:
    p='j004/out/'+os.path.basename(f);u='https://api.github.com/repos/%s/contents/%s'%(R,p)
    sha=None
    try: sha=json.load(urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=60))['sha']
    except Exception: pass
    d={'message':'upload '+p,'content':base64.b64encode(open(f,'rb').read()).decode()}
    if sha: d['sha']=sha
    try:
        r=urllib.request.urlopen(urllib.request.Request(u,data=json.dumps(d).encode(),headers=H,method='PUT'),timeout=600); ok+=1
        print('OK',p,r.status)
    except Exception as e: print('FAIL',p,getattr(e,'code',''),str(e)[:120])
print('UPLOAD %d/%d'%(ok,len(fs)))
PY
unset GT
