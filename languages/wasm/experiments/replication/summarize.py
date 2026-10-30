#!/usr/bin/env python3
"""WebAssembly side study, replication: how far an independent re-measurement moves each cell (stdlib only).

    summarize.py <baseline-dir> <baseline-date> <replica-dir> <replica-date> <outdir> [lang ...]

Both directories hold per-language envelopes written by scripts/wasm-study.sh. For every language measured in
both runs, and every column, it reports the largest absolute change of a cell's differential between the runs
(percent, lower is better) with the benchmark it occurs on, and the change of the wasmtime and V8 geomean
ratios. Only cells measured (status ok) in both runs count; a language whose replica is incomplete is skipped
unless every one of its cells was measured.
"""
import json
import os
import sys

bdir, bdate, rdir, rdate, outdir = sys.argv[1:6]
langs = sys.argv[6:]
out = {}
for lang in langs:
    a = json.load(open(os.path.join(bdir, f"{bdate}-arm64-{lang}.json")))
    b = json.load(open(os.path.join(rdir, f"{rdate}-arm64-{lang}.json")))
    ra = {r["benchmark"]: r for r in a["results"] if "columns" in r}
    cols, complete = {}, True
    for r in b["results"]:
        if "columns" not in r:
            continue
        for c, v in r["columns"].items():
            x = ra[r["benchmark"]]["columns"].get(c, {})
            if v.get("status") != "ok" or x.get("status") != "ok":
                complete = complete and v.get("status") == "n/a"
                continue
            d = 100 * abs(v["differential"] / x["differential"] - 1)
            if d >= cols.get(c, (-1, ""))[0]:
                cols[c] = (d, r["benchmark"])
    if not complete:
        print(f"skip {lang}: replica incomplete", file=sys.stderr)
        continue
    out[lang] = dict(
        maxCellChangePct={c: dict(pct=round(d, 3), benchmark=bm) for c, (d, bm) in sorted(cols.items())},
        geomean={k: dict(baseline=a["summary"][k]["geomeanRatioToNative"], replica=b["summary"][k]["geomeanRatioToNative"])
                 for k in ("wasmtime", "node")})
env = dict(study="wasm-side-study", kind="replication", date=rdate, isa="arm64",
           description=f"Independent re-measurement on {rdate} of the lanes in `languages` (same images rebuilt from the "
                       f"same Dockerfiles, same driver) against the published {bdate} envelopes.",
           meaning="maxCellChangePct: largest |replica / baseline - 1| of a cell differential in that column, percent "
                   "(lower is better; 0 = bit-identical); geomean: wasm / native ratios of both runs (lower is better)",
           languages=out)
p = os.path.join(outdir, f"{rdate}-arm64-replication.json")
json.dump(env, open(p, "w"), indent=1)
print(">>", p)
for l, v in out.items():
    print(l, {c: (x["pct"], x["benchmark"]) for c, x in v["maxCellChangePct"].items()}, v["geomean"])
