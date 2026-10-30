#!/usr/bin/env python3
"""WebAssembly side study, runtime experiment: the wasi-sdk sweep table (task 2).

usage: sdk-table.py <jsonl>      where <jsonl> = task1.jsonl and task2.jsonl concatenated:
  cat $RAWDIR/task1.jsonl $RAWDIR/task2.jsonl > /tmp/t12.jsonl && sdk-table.py /tmp/t12.jsonl

Prints wasm/native ratios per wasi-sdk (each wasm column over the same-version native clang, lower is
better), the native clang-to-clang and wasm-to-wasm cross ratios, geometric means, the lp64 no-op check
(clang-lp64-<v> must equal clang-<v> exactly) and the largest per-size spread of every wasm column.
(The throwaway name of this script was t2.py.) Stdlib only.
"""
import json,sys,math
d={}
for l in open(sys.argv[1]):
    r=json.loads(l)
    if 'FAIL' in r: continue
    d[(r['tag'],r['benchmark'])]=r
D=lambda t,b:d[(t,b)]['differential']
B=sorted({k[1] for k in d})
cols=[('sdk25 wasm/clang19','sdk25-wasm','clang-19.1.5'),('sdk30 wasm/clang21','sdk30-wasm','clang-21.1.4'),('sdk30mvp/clang21','sdk30-wasm-mvp','clang-21.1.4'),
      ('sdk34 wasm/clang23','wt50.0.0-rec','clang-23.1.0'),('sdk34mvp/clang23','sdk34-wasm-mvp','clang-23.1.0'),
      ('clang19/clang23','clang-19.1.5','clang-23.1.0'),('clang21/clang23','clang-21.1.4','clang-23.1.0'),
      ('wasm25/wasm34','sdk25-wasm','wt50.0.0-rec'),('wasm30/wasm34','sdk30-wasm','wt50.0.0-rec')]
print('bench'.ljust(20)+''.join(c[0].rjust(19) for c in cols))
g={c[0]:[] for c in cols}
for b in B:
    s=b.ljust(20)
    for n,a,z in cols:
        x=D(a,b)/D(z,b); g[n].append(x); s+=f'{x:19.3f}'
    print(s)
print('GEOMEAN'.ljust(20)+''.join(f'{math.exp(sum(map(math.log,g[c[0]]))/len(g[c[0]])):19.3f}' for c in cols))
print()
for v in ['19.1.5','21.1.4','23.1.0']:
    bad=[b for b in B if D('clang-lp64-'+v,b)!=D('clang-'+v,b)]
    ex=[d[('clang-'+v,b)]['determinism'] for b in B]+[d[('clang-lp64-'+v,b)]['determinism'] for b in B]
    print('lp64 no-op', v, 'mismatches:', bad or 'none', 'determinism:', set(ex))
    for b in bad: print('  ',b,D('clang-'+v,b),D('clang-lp64-'+v,b),D('clang-lp64-'+v,b)/D('clang-'+v,b))
for t in ['sdk25-wasm','sdk30-wasm','sdk30-wasm-mvp','sdk34-wasm-mvp']:
    print(t,'max per-size spread %.4f%%'%max((d[(t,b)][k]['max']-d[(t,b)][k]['min'])*100/d[(t,b)][k]['median'] for b in B for k in ('i_n1','i_n2')))
