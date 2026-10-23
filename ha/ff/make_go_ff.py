import sys
base, goat, gonb, out = sys.argv[1:5]
L = open(base).read().split('\n')
i_nb = next(i for i,l in enumerate(L) if l.strip().startswith('[ nonbond_params'))
body = lambda f: [l for l in open(f).read().split('\n') if not l.strip().startswith('[')]
new = L[:i_nb] + body(goat) + L[i_nb:] + body(gonb)
open(out,'w').write('\n'.join(new)+'\n')
