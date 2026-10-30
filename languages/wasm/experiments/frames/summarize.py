#!/usr/bin/env python3
"""WebAssembly side study, frames diagnostic: turn run.sh's timing batches into an envelope (stdlib only).

    summarize.py <knobs.jsonl> <patch.jsonl> <outdir> <date>   ->  <outdir>/<date>-arm64-frames.json

Per variant: the user-time differential t(16) - t(10) per repetition, its median and interquartile range, and
two paired ratios (same repetition): to native clang and to wasmtime's default build. Lower is better. A run
whose first output line is not the binary-trees checksum for its size fails the gate and is dropped.
"""
import json
import os
import statistics as st
import sys
from collections import defaultdict

CHECK = {10: "135854", 16: "14985902"}   # binary-trees checksum (node count) at sizes 10 and 16


def batch(path):
    rows = [json.loads(l) for l in open(path) if l.strip()]
    bad = [r for r in rows if r["rc"] != 0 or r["out"] != CHECK.get(r["n"])]
    runs = defaultdict(dict)
    for r in rows:
        if r not in bad:
            runs[(r["var"], r["rep"])][r["n"]] = r
    diff = {k: {f: v[16][f] - v[10][f] for f in ("user_ns", "sys_ns", "minflt")} for k, v in runs.items() if 10 in v and 16 in v}
    out = {}
    for var in sorted({k[0] for k in diff}):
        reps = {rep: d for (v, rep), d in diff.items() if v == var}
        q = lambda xs: dict(median=round(st.median(xs), 4), iqr=[round(x, 4) for x in st.quantiles(xs, n=4)[::2]]) if len(xs) > 3 else None
        paired = lambda base: q([d["user_ns"] / diff[(base, rep)]["user_ns"] for rep, d in reps.items() if (base, rep) in diff])
        out[var] = dict(reps=len(reps), dUserMs=q([d["user_ns"] / 1e6 for d in reps.values()]),
                        dSysMs=round(st.median(d["sys_ns"] / 1e6 for d in reps.values()), 2),
                        dMinflt=st.median(d["minflt"] for d in reps.values()),
                        toClang=paired("clang") if var != "clang" else None,
                        toWasmtimeDefault=paired("wt-default") if var != "wt-default" else None)
        if var.startswith("fl-") and var != "fl-clang":
            out[var]["toFreeListClang"] = paired("fl-clang")
    return dict(gateFailures=len(bad), variants=out)


knobs, patch, outdir, date = sys.argv[1:5]
env = dict(study="wasm-side-study", kind="frames", date=date, isa="arm64",
           metric="user CPU time differential t(16) - t(10) of C binary-trees, native timing inside lang-lab-wasm:c, "
                  "pinned to one CPU, every (variant, size) pair in random order per repetition",
           ratioMeaning="paired per repetition: variant differential / clang (toClang) or / wasmtime default "
                        "(toWasmtimeDefault); lower is better",
           description="binary-trees runs 1.02x native clang's instructions on wasmtime 50 but more of its time. The knobs batch "
                       "varies wasmtime's memory and code-generation configuration and replaces malloc/free with a free list "
                       "(fl-*); the patch batch rewrites the register save and restore code of chosen functions in the "
                       "precompiled module from Cranelift's chained stack-pointer updates to one stack adjustment with the "
                       "same instruction count (repatch.py; a timing probe, not a fix: .eh_frame is not updated).",
           caveats=["absolute milliseconds are comparable only within a batch (host load drifted); the ratios are paired",
                    "the memory knobs that raise time (signals-based-traps=n, memory-reservation/guard-size 0) switch "
                    "wasmtime to explicit bounds checks, which add instructions: they are not a memory-system measurement"],
           provenance="languages/wasm/experiments/frames/",
           knobs=batch(knobs), patch=batch(patch))
p = os.path.join(outdir, f"{date}-arm64-frames.json")
json.dump(env, open(p, "w"), indent=1)
print(">>", p)
for b in ("knobs", "patch"):
    for v, s in env[b]["variants"].items():
        print(f"{b:6s} {v:22s} toClang {s['toClang'] and s['toClang']['median']}  toWtDefault {s['toWasmtimeDefault'] and s['toWasmtimeDefault']['median']}")
