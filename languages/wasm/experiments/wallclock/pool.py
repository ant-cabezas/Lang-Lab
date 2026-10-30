#!/usr/bin/env python3
"""WebAssembly side study, wall-clock experiment: pool timing passes into one analysis directory.

usage: pool.py <outdir> <passdir> [<passdir> ...]
  e.g. pool.py $OUT/pooledCD $OUT/passC $OUT/passD

Concatenates every pass's timing.jsonl into <outdir>/timing.jsonl, adding 1000 x (pass index) to rep (so
repetitions of different passes never pair with each other in the per-rep differentials) and a "pass"
field (the pass directory's name); copies the first pass's sizes.txt. This is the merge the study ran
inline for pooledCD (passC offset 0, passD offset 1000). counts.jsonl is copied in separately (run.sh).
Stdlib only.
"""
import json, os, shutil, sys

if len(sys.argv) < 3:
    sys.exit("usage: pool.py <outdir> <passdir> [<passdir> ...]")
out, passes = sys.argv[1], sys.argv[2:]
os.makedirs(out, exist_ok=True)
shutil.copyfile(os.path.join(passes[0], 'sizes.txt'), os.path.join(out, 'sizes.txt'))
with open(os.path.join(out, 'timing.jsonl'), 'w') as f:
    for i, p in enumerate(passes):
        name = os.path.basename(os.path.normpath(p))
        for l in open(os.path.join(p, 'timing.jsonl')):
            r = json.loads(l); r['rep'] += 1000 * i; r['pass'] = name; f.write(json.dumps(r) + '\n')
