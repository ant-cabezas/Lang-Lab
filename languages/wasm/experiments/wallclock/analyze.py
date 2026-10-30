#!/usr/bin/env python3
"""WebAssembly side study, wall-clock experiment: compare time differentials with instruction differentials.

usage: analyze.py <dir>            -> prints the report, writes <dir>/summary.json
       METRIC=user_ns analyze.py <dir>  -> the same on user CPU time, writes <dir>/summary-user_ns.json
                                          (the study's headline estimator; ingest.py reads this file)

<dir> holds timing.jsonl (timeit.py rows, one pass or several pooled by pool.py), sizes.txt (the large size
L per benchmark) and counts.jsonl (count-one.sh rows). For every benchmark and column, the per-repetition
paired differential t(n2)-t(n1) (set "spec") and t(L)-t(n1) (set "large") is summarized by its median, IQR
and a 95% bootstrap CI (random.seed(1), so reruns are byte-identical). Ratio tables are column / clang,
time ratio next to instruction ratio (both lower is better), with Spearman and R2 of log time ratio on log
instruction ratio over benchmarks. The gate checks every column printed the spec checksum at n1/n2 and
clang's checksum at L. Stdlib only.
"""
import json, math, random, statistics as st, sys, os
from collections import defaultdict

D = sys.argv[1]
random.seed(1)
COLS = [c for c in ['clang', 'gcc', 'wasmtime', 'node', 'node-liftoff'] if c in {json.loads(l).get('col') for l in open(os.path.join(sys.argv[1], 'timing.jsonl')) if l.startswith('{"')}]
T = defaultdict(dict)  # (bench,col,n) -> {rep: row}
for l in open(os.path.join(D, 'timing.jsonl')):
    try: r = json.loads(l)
    except ValueError: continue
    T[(r['bench'], r['col'], r['n'])][r['rep']] = r
specs = {}
R = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', '..', 'benchmarks')
for b in sorted(os.listdir(R)):
    p = os.path.join(R, b, 'spec.json')
    if os.path.exists(p) and b != 'message-ring':
        specs[b] = json.load(open(p))
L = dict(l.split() for l in open(os.path.join(D, 'sizes.txt')) if l.strip())
L = {k: int(v) for k, v in L.items()}
# Only the benchmarks timed in this run (all 18 in a full run; a BENCH subset in a smoke test).
specs = {b: s for b, s in specs.items() if b in L}

C = {}  # (set,col,bench) -> differential
CJ = {}
if os.path.exists(os.path.join(D, 'counts.jsonl')):
    for l in open(os.path.join(D, 'counts.jsonl')):
        r = json.loads(l)
        if 'm' in r:
            C[(r['set'], r['col'], r['m']['benchmark'])] = r['m']['differential']
            CJ[(r['set'], r['col'], r['m']['benchmark'])] = r['m']['determinism']

def q(xs, p):
    xs = sorted(xs); k = (len(xs) - 1) * p; f = math.floor(k); c = math.ceil(k)
    return xs[f] + (xs[c] - xs[f]) * (k - f)

def ranks(v):
    o = sorted(range(len(v)), key=lambda i: v[i]); r = [0.0] * len(v); i = 0
    while i < len(o):
        j = i
        while j + 1 < len(o) and v[o[j + 1]] == v[o[i]]: j += 1
        for k in range(i, j + 1): r[o[k]] = (i + j) / 2 + 1
        i = j + 1
    return r

def pearson(x, y):
    mx, my = st.mean(x), st.mean(y)
    sx = math.sqrt(sum((a - mx) ** 2 for a in x)); sy = math.sqrt(sum((b - my) ** 2 for b in y))
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / (sx * sy)

def spearman(x, y): return pearson(ranks(x), ranks(y))

KEY = os.environ.get('METRIC', 'wall_ns')
def diffs(b, col, na, nb, key=KEY):
    A, B = T[(b, col, na)], T[(b, col, nb)]
    return [B[i][key] - A[i][key] for i in sorted(set(A) & set(B))]

summary = {'cells': {}, 'gate': {}}
# ---- gate: spec sizes checksum, L agreement across columns, rc == 0
print('## Gate')
for b, s in specs.items():
    probs = []
    for col in COLS:
        for n in (s['n1'], s['n2']):
            rows = T[(b, col, n)].values()
            if not rows: probs.append(f'{col}@{n} missing')
            bad = [r for r in rows if not r['ok'] or r['rc'] != 0]
            if bad: probs.append(f'{col}@{n}: {len(bad)} bad')
    ref = {r['out'] for r in T[(b, 'clang', L[b])].values()}
    for col in COLS:
        outs = {r['out'] for r in T[(b, col, L[b])].values()}
        rcs = {r['rc'] for r in T[(b, col, L[b])].values()}
        if outs != ref or rcs != {0} or len(ref) != 1: probs.append(f'{col}@L outs={outs} rcs={rcs}')
    summary['gate'][b] = {'L': L[b], 'L_checksum': sorted(ref)[0] if ref else None, 'problems': probs}
    print(f'{b:20s} L={L[b]:<9} {"OK" if not probs else probs}')

def cell(b, col, na, nb, key=KEY):
    d = diffs(b, col, na, nb, key)
    if not d: return None
    A = [r[key] for r in T[(b, col, na)].values()]; B = [r[key] for r in T[(b, col, nb)].values()]
    return {'n': len(d), 'med': st.median(d), 'q1': q(d, .25), 'q3': q(d, .75),
            'iqr': q(d, .75) - q(d, .25), 'mindiff': min(B) - min(A), 'd': d}

def boot_ratio(dw, dc, it=2000):
    out = []
    for _ in range(it):
        a = st.median(random.choices(dw, k=len(dw))); c = st.median(random.choices(dc, k=len(dc)))
        if c > 0 and a > 0: out.append(a / c)
    return q(out, .025), q(out, .975)

rows = {}
for setname in ('spec', 'large'):
    print(f'\n## Differentials, set={setname} (ms; median [IQR] of paired per-rep differentials; min-diff)')
    for b, s in specs.items():
        na = s['n1']; nb = s['n2'] if setname == 'spec' else L[b]
        line = f'{b:19s}'
        for col in COLS:
            c = cell(b, col, na, nb); cu = cell(b, col, na, nb, 'user_ns')
            if c is None: line += ' n/a'; continue
            bm = sorted(st.median(random.choices(c['d'], k=len(c['d']))) for _ in range(1000))
            c['ci'] = (bm[25], bm[974])
            # resolved: the 95% bootstrap CI of the median differential excludes 0 and is narrower than +/-50%
            c['resolved'] = bm[25] > 0 and (bm[974] - bm[25]) < c['med']
            rows[(setname, b, col)] = (c, cu)
            line += f" | {col[:6]} {c['med']/1e6:8.2f} [{c['iqr']/1e6:6.2f}]{'' if c['resolved'] else '*'} min {c['mindiff']/1e6:7.2f}"
        print(line)

def ratio_table(setname, wcol, base='clang'):
    print(f'\n## {wcol}/{base}, set={setname}: time ratio (median diff, 95% bootstrap CI) | min-diff ratio | user-time ratio | instr ratio | time/instr')
    X, Y, Ym, Yu, names = [], [], [], [], []
    for b, s in specs.items():
        k1, k2 = (setname, b, wcol), (setname, b, base)
        if k1 not in rows or k2 not in rows: continue
        (cw, uw), (cc, uc) = rows[k1], rows[k2]
        ok = cw['resolved'] and cc['resolved']
        tr = cw['med'] / cc['med'] if cc['med'] > 0 else float('nan')
        lo, hi = boot_ratio(cw['d'], cc['d']) if ok else (float('nan'),) * 2
        mr = cw['mindiff'] / cc['mindiff'] if cc['mindiff'] > 0 else float('nan')
        ur = uw['med'] / uc['med'] if uc['med'] > 0 else float('nan')
        iw, ic = C.get((setname, wcol, b)), C.get((setname, base, b))
        ir = iw / ic if iw and ic else None
        summary['cells'][f'{setname}/{wcol}/{base}/{b}'] = dict(time_ratio=tr, ci=[lo, hi], min_ratio=mr, user_ratio=ur,
            instr_ratio=ir, resolved=ok, t_w_ms=cw['med'] / 1e6, t_c_ms=cc['med'] / 1e6, iqr_w_ms=cw['iqr'] / 1e6,
            iqr_c_ms=cc['iqr'] / 1e6, I_w=iw, I_c=ic, det_w=CJ.get((setname, wcol, b)), det_c=CJ.get((setname, base, b)))
        print(f"{b:19s} {tr:6.2f} [{lo:5.2f},{hi:5.2f}]{'' if ok else ' UNRESOLVED'} | {mr:6.2f} | {ur:6.2f} | "
              f"{(f'{ir:6.2f}') if ir else '   n/a'} | {(f'{tr/ir:5.2f}') if ir else 'n/a'}")
        if ok and ir and tr > 0:
            X.append(math.log(ir)); Y.append(math.log(tr)); Ym.append(math.log(mr) if mr > 0 else float('nan'))
            Yu.append(math.log(ur)); names.append(b)
    if len(X) >= 4:
        r = pearson(X, Y); rho = spearman(X, Y)
        gm_t = math.exp(st.mean(Y)); gm_i = math.exp(st.mean(X))
        resid = sorted(zip([y - x for x, y in zip(X, Y)], names))
        okm = [(x, y) for x, y in zip(X, Ym) if not math.isnan(y)]
        rm = pearson([a for a, _ in okm], [b for _, b in okm]); ru = pearson(X, Yu)
        mag = sorted(abs(y - x) for x, y in zip(X, Y))
        st_ = dict(n=len(X), spearman=rho, pearson_log=r, r2_log=r * r, r2_min=rm * rm, spearman_min=spearman([a for a, _ in okm], [b for _, b in okm]),
                   r2_user=ru * ru, geomean_time=gm_t, geomean_instr=gm_i,
                   median_abs_factor=math.exp(st.median(mag)), p90_abs_factor=math.exp(q(mag, .9)),
                   most_over=[(n, math.exp(v)) for v, n in resid[:4]], most_under=[(n, math.exp(v)) for v, n in resid[-4:]])
        summary[f'stats/{setname}/{wcol}/{base}'] = st_
        print(f"N={len(X)} Spearman={rho:.3f} R2(log)={r*r:.3f} [min-diff R2={rm*rm:.3f}, user-time R2={ru*ru:.3f}] "
              f"geomean time={gm_t:.2f} instr={gm_i:.2f} | |time/instr| median x{st_['median_abs_factor']:.2f} p90 x{st_['p90_abs_factor']:.2f}")
        print('  time < instr (instr overstates):', ', '.join(f'{n} {v:.2f}' for n, v in st_['most_over']))
        print('  time > instr (instr understates):', ', '.join(f'{n} {v:.2f}' for n, v in st_['most_under']))

for setname in ('large', 'spec'):
    for w in ('wasmtime', 'node', 'node-liftoff', 'gcc'):
        if w in COLS: ratio_table(setname, w)
    ratio_table(setname, 'node', 'wasmtime')

# pooled: all non-baseline columns across benchmarks, vs clang, both ISA-agnostic (time vs instr)
for setname in ('large', 'spec'):
    X, Y = [], []
    for k, v in summary['cells'].items():
        s_, w, base, b = k.split('/')
        if s_ == setname and base == 'clang' and v['resolved'] and v['instr_ratio'] and v['time_ratio'] > 0:
            X.append(math.log(v['instr_ratio'])); Y.append(math.log(v['time_ratio']))
    if len(X) > 4:
        r = pearson(X, Y)
        summary[f'stats/{setname}/pooled'] = dict(n=len(X), spearman=spearman(X, Y), r2_log=r * r)
        print(f'\npooled {setname} (gcc+wasmtime+node vs clang): N={len(X)} Spearman={spearman(X, Y):.3f} R2={r*r:.3f}')

json.dump(summary, open(os.path.join(D, 'summary.json' if KEY == 'wall_ns' else f'summary-{KEY}.json'), 'w'), indent=1, default=str)
