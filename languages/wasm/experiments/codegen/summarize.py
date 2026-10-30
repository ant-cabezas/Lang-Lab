#!/usr/bin/env python3
"""WebAssembly side study, codegen experiment: summary tables of the raw batch files.

usage: summarize.py <raw>/o2.txt <raw>/o3.txt <raw>/wasmopt.txt <raw>/simd.txt

Prints, per benchmark, the wasm/native differential ratio of every configuration (wasm over its symmetric
native control; lower is better) with geometric means, each configuration relative to the default -O2 wasm
module (lower is better), and the determinism / spread of every column. Lines without a JSON result
(failed cells) are listed at the end. A reading aid; the envelope comes from ingest.py. Stdlib only.
"""
import sys, json, math, collections
rows = collections.defaultdict(dict); fails = []
for f in sys.argv[1:]:
    for line in open(f):
        p = line.rstrip("\n").split(" ", 3)
        if len(p) < 4 or not p[3].startswith("{"):
            fails.append(line.strip()); continue
        img, var, b, js = p; o = json.loads(js)
        cfg = img.replace("lang-lab-wasm-codegen-", "") + ("" if var in ("native", "wasm") else ":" + var.split("/")[1])
        side = "native" if var == "native" else "wasm"
        rows[(cfg, side)][b] = o
cfgs = [("o2", "o2"), ("o3", "o3"), ("wasmopt", "o2"), ("simd", "o2")] + \
       [("o2:" + k, "o2") for k in ("bounds", "nosig", "eagertable", "copt0", "copt1", "inline")]
benches = sorted(rows[("o2", "native")])
avail = [(c, n) for c, n in cfgs if rows.get((c, "wasm"))]
hdr = f"{'bench':20}{'native-O2':>12}{'native-O3':>12}" + "".join(f"{c:>14}" for c, _ in avail)
print("wasm/native differential ratio (native control in parentheses of the header row below)")
print(hdr)
gm = collections.defaultdict(list)
for b in benches:
    no2 = rows[("o2", "native")].get(b, {}).get("differential"); no3 = rows.get(("o3", "native"), {}).get(b, {}).get("differential")
    s = f"{b:20}{no2 or 0:>12}{no3 or 0:>12}"
    for c, n in avail:
        w = rows[(c, "wasm")].get(b); nat = rows[(n, "native")].get(b)
        if w and nat and w["correct"] and nat["correct"]:
            r = w["differential"] / nat["differential"]; gm[c].append(r); s += f"{r:>14.3f}"
        else: s += f"{'MISSING':>14}"
    print(s)
print(f"{'GEOMEAN':44}" + "".join(f"{math.exp(sum(map(math.log, gm[c]))/len(gm[c])):>14.3f}" for c, _ in avail))
print(f"{'n':44}" + "".join(f"{len(gm[c]):>14}" for c, _ in avail))
print("\nwasm differential relative to the default -O2 wasm module (same native control)")
print(f"{'bench':20}" + "".join(f"{c:>14}" for c, _ in avail))
for b in benches:
    base = rows[("o2", "wasm")].get(b)
    print(f"{b:20}" + "".join(f"{(rows[(c,'wasm')][b]['differential']/base['differential'] if b in rows[(c,'wasm')] and base else float('nan')):>14.3f}" for c, _ in avail))
print("\ndeterminism / runs (wasm side)")
for c, _ in avail:
    d = collections.Counter(f"{o['determinism']}/{o['runs']}" for o in rows[(c, "wasm")].values())
    sp = max(max((o[k]["max"] - o[k]["min"]) / o[k]["median"] for k in ("i_n1", "i_n2")) for o in rows[(c, "wasm")].values())
    print(f"  {c:16} {dict(d)}  max (max-min)/median at either size: {sp*100:.4f}%")
for c in ("o2", "o3"):
    if rows.get((c, "native")):
        print(f"  native-{c:9} {dict(collections.Counter(o['determinism'] for o in rows[(c,'native')].values()))}")
if fails: print("\nFAILED LINES:"); [print("  " + x[:300]) for x in fails]
