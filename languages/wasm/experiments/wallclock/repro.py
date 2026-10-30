#!/usr/bin/env python3
"""WebAssembly side study, wall-clock experiment: pass-to-pass reproducibility of the time ratios.

usage: [SUMF=summary-user_ns.json] repro.py <root> <passA>:<passB> ...
  e.g. SUMF=summary-user_ns.json repro.py $OUT passC:passD

For each pair of analyzed pass directories under <root> (analyze.py already run in both), compares the
per-benchmark time ratios (column / clang, lower is better) of every column: Spearman, R2 of the log ratios,
and the median and max factor by which a ratio moved between the passes. SUMF picks the summary file
(default summary.json, the wall-time one). Stdlib only.
"""
import json, math, sys
def pearson(x, y):
    mx, my = sum(x)/len(x), sum(y)/len(y)
    return sum((a-mx)*(b-my) for a, b in zip(x, y)) / math.sqrt(sum((a-mx)**2 for a in x)*sum((b-my)**2 for b in y))
def ranks(v):
    o = sorted(range(len(v)), key=lambda i: v[i]); r = [0]*len(v)
    for k, i in enumerate(o): r[i] = k
    return r
D = sys.argv[1]
for pa, pb in [x.split(':') for x in sys.argv[2:]]:
    A = json.load(open(f'{D}/{pa}/'+__import__('os').environ.get('SUMF','summary.json')))['cells']; B = json.load(open(f'{D}/{pb}/'+__import__('os').environ.get('SUMF','summary.json')))['cells']
    for key in ('large/wasmtime/clang', 'large/node/clang', 'large/node-liftoff/clang', 'large/gcc/clang', 'spec/wasmtime/clang', 'spec/node/clang'):
        ks = [k for k in A if k.startswith(key + '/') and k in B and A[k]['time_ratio'] > 0 and B[k]['time_ratio'] > 0]
        if len(ks) < 4: continue
        x = [math.log(A[k]['time_ratio']) for k in ks]; y = [math.log(B[k]['time_ratio']) for k in ks]
        d = sorted(abs(a-b) for a, b in zip(x, y))
        print(f'{pa} vs {pb} {key}: N={len(ks)} Spearman={pearson(ranks(x), ranks(y)):.2f} R2={pearson(x, y)**2:.2f} '
              f'median |shift| x{math.exp(d[len(d)//2]):.2f} max x{math.exp(d[-1]):.2f}')
