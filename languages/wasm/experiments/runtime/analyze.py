#!/usr/bin/env python3
"""WebAssembly side study, runtime experiment: quick table of one sweep file.

usage: analyze.py <jsonl> <baseline-tag> [tags...]
  e.g. analyze.py $RAWDIR/task1.jsonl clang-23.1.0 wt26.0.1-rec wt50.0.0-rec

Per benchmark: ratio = tag differential / baseline differential (lower is better) and, in parentheses, the
tag's largest per-size spread (max-min)/median in percent; last row the geometric mean. Reads the JSON lines
m.sh writes (FAIL lines print as FAIL/NA). A reading aid only: the envelopes come from ingest.py. Stdlib only.
"""
import json, sys, math
rows = [json.loads(l) for l in open(sys.argv[1]) if l.strip()]
base = sys.argv[2]
d = {}
for r in rows:
    if 'FAIL' in r: d[(r['tag'], r['benchmark'])] = None; continue
    sp = max((r[k]['max']-r[k]['min'])*100/r[k]['median'] for k in ('i_n1','i_n2'))
    d[(r['tag'], r['benchmark'])] = (r['differential'], sp, r['determinism'])
tags = sys.argv[3:] or sorted({t for t, _ in d if t != base})
benches = sorted({b for _, b in d})
print('bench'.ljust(20) + ''.join(t[:16].rjust(17) for t in tags))
gm = {t: [] for t in tags}
for b in benches:
    bl = d.get((base, b)); line = b.ljust(20)
    for t in tags:
        v = d.get((t, b))
        if v is None or bl is None: line += 'FAIL/NA'.rjust(17); continue
        ratio = v[0]/bl[0]; gm[t].append(ratio)
        line += f'{ratio:7.3f} ({v[1]:.4f}%)'.rjust(17)
    print(line)
print('GEOMEAN'.ljust(20) + ''.join((f'{math.exp(sum(map(math.log,gm[t]))/len(gm[t])):7.3f} n={len(gm[t])}' if gm[t] else '-').rjust(17) for t in tags))
