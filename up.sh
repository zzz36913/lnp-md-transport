#!/bin/bash
# upload ~/xfer/figs/*.gro to github via REST API (api.github.com)
read -rsp 'token: ' GT; echo; export GT
python3 - <<'PY'
import os,glob,base64,json,urllib.request
T=os.environ['GT'];R='zzz36913/lnp-md-transport'
H={'Authorization':'Bearer '+T,'Accept':'application/vnd.github+json','User-Agent':'k03'}
for f in sorted(glob.glob(os.path.expanduser('~/xfer/figs/*.gro'))):
    p='figs/'+os.path.basename(f);u='https://api.github.com/repos/%s/contents/%s'%(R,p)
    sha=None
    try:
        sha=json.load(urllib.request.urlopen(urllib.request.Request(u,headers=H),timeout=60))['sha']
    except Exception: pass
    d={'message':'upload '+p,'content':base64.b64encode(open(f,'rb').read()).decode()}
    if sha: d['sha']=sha
    try:
        r=urllib.request.urlopen(urllib.request.Request(u,data=json.dumps(d).encode(),headers=H,method='PUT'),timeout=300)
        print('OK',p,r.status)
    except Exception as e:
        print('FAIL',p,getattr(e,'code',''),str(e)[:120])
PY
unset GT
