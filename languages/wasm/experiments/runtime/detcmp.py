#!/usr/bin/env python3
"""WebAssembly side study, runtime experiment: determinism of two configurations of one sweep file.

usage: detcmp.py <jsonl> <tagA> <tagB>
  e.g. detcmp.py $RAWDIR/task1.jsonl wt50.0.0-default wt50.0.0-rec

Per benchmark: the spread (max-min, absolute instructions and percent of the median) at n1 and n2 for A
and B, the change of the differential B-A (absolute and percent), and B's determinism label. Used to show
that the binding wasmtime flags cut the spread without moving the differential. Stdlib only.
"""
import json, sys
rows=[json.loads(l) for l in open(sys.argv[1]) if l.strip() and 'FAIL' not in l]
A,B=sys.argv[2],sys.argv[3]; d={(r['tag'],r['benchmark']):r for r in rows}
def sp(r,k): x=r[k]; return x['max']-x['min'], (x['max']-x['min'])*100/x['median']
print(f"{'bench':20}{'A n1 spr':>16}{'A n2 spr':>16}{'B n1 spr':>16}{'B n2 spr':>16}{'dDiff B-A':>12}{'%':>9}{'B exact':>8}")
mx=[0,0,0,0]
for b in sorted({k[1] for k in d}):
    a,bb=d.get((A,b)),d.get((B,b))
    if not a or not bb: continue
    s=[sp(a,'i_n1'),sp(a,'i_n2'),sp(bb,'i_n1'),sp(bb,'i_n2')]
    for i in range(4): mx[i]=max(mx[i],s[i][1])
    dd=bb['differential']-a['differential']
    print(f"{b:20}"+''.join(f"{x[0]:>7}/{x[1]:.4f}%".rjust(16) for x in s)+f"{dd:>12}{dd*100/a['differential']:>8.4f}%{bb['determinism']:>8}")
print('max %', ['%.4f'%m for m in mx])
