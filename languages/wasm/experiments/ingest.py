#!/usr/bin/env python3
"""WebAssembly side study: build the experiment envelopes from the raw experiment output.

usage: ingest.py <rawroot> <outdir> <date>

<rawroot> holds the raw output of the three experiment drivers, one subdirectory each:
  runtime/raw/{task1,task2,task3}.jsonl, runtime/raw/knobs-raw.log   (languages/wasm/experiments/runtime/)
  codegen/raw/{o2,o3,wasmopt,simd}.txt                                (languages/wasm/experiments/codegen/)
  wallclock/pooledCD/summary-user_ns.json                             (languages/wasm/experiments/wallclock/)
It writes six envelopes to <outdir>: <date>-arm64-{runtime-sweep,sdk-sweep,v8-tiering,jitter,codegen,wallclock}.json
(results/wasm/ for a published run). Every ratio in them is numerator / denominator, lower is better.
Only cells whose checksum gate passed are kept; nothing is extrapolated. Stdlib only.
"""
import json, os, re, sys, math

if len(sys.argv) != 4:
    sys.exit("usage: ingest.py <rawroot> <outdir> <date>")
L, OUT, DATE = sys.argv[1], sys.argv[2], sys.argv[3]
REPO = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
META = dict(study="wasm-side-study", date=DATE, isa="arm64",
            metric="differential instructions I(n2)-I(n1), qemu-user + TCG insn plugin")


def slim(j, tag, extra=None):
    sp = max((j[k]["max"] - j[k]["min"]) / j[k]["median"] for k in ("i_n1", "i_n2"))
    d = dict(tag=tag, benchmark=j["benchmark"], n1=j["n1"], n2=j["n2"], i_n1=j["i_n1"]["median"],
             i_n2=j["i_n2"]["median"], differential=j["differential"], runs=j["runs"],
             determinism=j["determinism"], maxSpreadPct=round(100 * sp, 5))
    if extra:
        d.update(extra)
    return d


DROPPED = []   # (file, tag, benchmark): cells whose LAST run in an appended log failed the gate


def from_jsonl(path, tags=None):
    """The last line per (tag, benchmark) wins, so a re-run replaces an earlier one; if that last run
    failed the checksum gate the cell is dropped (and listed in DROPPED), never back-filled from an
    older passing run."""
    last = {}
    for line in open(path):
        line = line.strip()
        if not line.startswith("{"):
            continue
        j = json.loads(line)
        t, b = j.get("tag"), j.get("benchmark")
        if t is None or b is None or (tags and t not in tags):
            continue
        last[(t, b)] = j
    cells = []
    for (t, b), j in last.items():
        if j.get("correct"):
            cells.append(slim(j, t, dict(command=j.get("cmd"), image=j.get("image"))))
        else:
            DROPPED.append((os.path.basename(path), t, b))
    return cells


def write(kind, desc, cells, columns, notes, provenance):
    env = dict(META, kind=kind, description=desc,
               ratioMeaning="numerator differential / denominator differential (lower is better)",
               columns=columns, notes=notes, provenance=provenance, cells=sorted(cells, key=lambda c: (c["tag"], c["benchmark"])))
    p = os.path.join(OUT, f"{DATE}-arm64-{kind}.json")
    json.dump(env, open(p, "w"), indent=1)
    print(">>", p, len(cells), "cells")


# ---- runtime sweep (task1) -------------------------------------------------------------------
t1 = from_jsonl(f"{L}/runtime/raw/task1.jsonl")
vers = ["26.0.1", "30.0.2", "34.0.2", "38.0.4", "42.0.2", "46.0.3", "50.0.0"]
write("runtime-sweep",
      "The same wasi-sdk 34 modules run under seven wasmtime releases (latest patch of each major), each "
      "precompiled by that release; ratio to the same native clang 23.1.0 binary. Recommended run config "
      "(TOKIO_WORKER_THREADS=1, -C cache=n); the -default rows use no extra flags.",
      t1,
      [dict(key=f"wt{v}", label=f"wasmtime {v}", num=f"wt{v}-rec", den="clang-23.1.0") for v in vers]
      + [dict(key="wt26.0.1-default", label="26.0.1 default flags", num="wt26.0.1-default", den="clang-23.1.0"),
         dict(key="wt50.0.0-default", label="50.0.0 default flags", num="wt50.0.0-default", den="clang-23.1.0")],
      ["wasmtime 50.0.0 -rec cwasm files are byte-identical to lang-lab-wasm:c's"],
      "languages/wasm/experiments/runtime/ (sweep.sh task1)")

# ---- wasi-sdk sweep (task2 + task1 rows for sdk34) ----------------------------------------------
t2 = from_jsonl(f"{L}/runtime/raw/task2.jsonl")
keep = [c for c in t1 if c["tag"] in ("clang-23.1.0", "wt50.0.0-rec", "wt26.0.1-rec")]
write("sdk-sweep",
      "wasi-sdk 25 / 30 / 34 (clang 19.1.5 / 21.1.4 / 23.1.0), each against a native control built with the "
      "official LLVM release of the same version, all run on wasmtime 50.0.0 (recommended config). The -mvp rows "
      "compile the benchmark code with -mcpu=mvp (the prebuilt libc keeps its features). sdk25-wt26 is the "
      "2x2 corner: wasi-sdk 25 modules on wasmtime 26.0.1.",
      t2 + keep,
      [dict(key="sdk25", label="sdk 25 / clang 19", num="sdk25-wasm", den="clang-19.1.5"),
       dict(key="sdk30", label="sdk 30 / clang 21", num="sdk30-wasm", den="clang-21.1.4"),
       dict(key="sdk30mvp", label="sdk 30 mvp / clang 21", num="sdk30-wasm-mvp", den="clang-21.1.4"),
       dict(key="sdk34", label="sdk 34 / clang 23", num="wt50.0.0-rec", den="clang-23.1.0"),
       dict(key="sdk34mvp", label="sdk 34 mvp / clang 23", num="sdk34-wasm-mvp", den="clang-23.1.0"),
       dict(key="cl19", label="native clang 19 / clang 23", num="clang-19.1.5", den="clang-23.1.0"),
       dict(key="w25w34", label="wasm sdk 25 / sdk 34", num="sdk25-wasm", den="wt50.0.0-rec"),
       dict(key="f2x2-25-26", label="sdk 25 on wt 26 / clang 23", num="sdk25-wt26-rec", den="clang-23.1.0"),
       dict(key="f2x2-34-26", label="sdk 34 on wt 26 / clang 23", num="wt26.0.1-rec", den="clang-23.1.0")],
      [], "languages/wasm/experiments/runtime/ (sweep.sh task2)")

# ---- V8 tiering (task3) -------------------------------------------------------------------------
t3 = from_jsonl(f"{L}/runtime/raw/task3.jsonl")
write("v8-tiering",
      "Node 26.5.0 (V8 14.6) running the C modules under four tier configurations; ratio to native clang 23.1.0. "
      "Under --single-threaded V8 forces --no-wasm-tier-up, so the base flags run every function in Liftoff forever.",
      t3 + keep,
      [dict(key="A", label="TurboFan (--no-liftoff), the study's V8 column", num="node-A-noliftoff", den="clang-23.1.0"),
       dict(key="A2", label="TurboFan, eager compilation", num="node-A2-noliftoff-eager", den="clang-23.1.0"),
       dict(key="B", label="Liftoff only (base flags)", num="node-B-base-liftoff", den="clang-23.1.0"),
       dict(key="D", label="dynamic tiering (sync tier-up)", num="node-D-dyntier-sync", den="clang-23.1.0"),
       dict(key="wt", label="wasmtime 50 (reference)", num="wt50.0.0-rec", den="clang-23.1.0")],
      [], "languages/wasm/experiments/runtime/ (task3.sh)")

# ---- jitter (knobs) ---------------------------------------------------------------------------
# Human-readable meaning of every configuration label knob-run.sh / knob-shim.sh wrote (the exact
# commands are the CONFIGS table in runtime/jitter.sh). wt50 = wasmtime 50.0.0, wt26 = wasmtime 26.0.1.
LEGEND = {
    "wt50-default": "wasmtime 50.0.0, no extra flags (lang-lab-wasm:c, /app/wasm cwasm)",
    "wt26-default": "wasmtime 26.0.1, no extra flags",
    "wt26-default-P1": "wasmtime 26.0.1, no extra flags, re-run alone (no other jitter jobs in parallel)",
    "wt50-default-P1": "wasmtime 50.0.0, no extra flags, re-run alone (no other jitter jobs in parallel)",
    "wt50-preview2n": "wasmtime 50.0.0 with -S preview2=n (rejected by wasmtime 50: the module never ran)",
    "wt50-rayon1": "wasmtime 50.0.0 with RAYON_NUM_THREADS=1",
    "wt50-tokio1": "wasmtime 50.0.0 with TOKIO_WORKER_THREADS=1",
    "wt50-cpuset0": "wasmtime 50.0.0, container restricted to CPU 0 (docker --cpuset-cpus=0)",
    "wt50-parcompN": "wasmtime 50.0.0 with -C parallel-compilation=n",
    "wt50-cacheN": "wasmtime 50.0.0 with -C cache=n",
    "wt50-tokio1-cacheN": "wasmtime 50.0.0 with TOKIO_WORKER_THREADS=1 and -C cache=n (the study's binding wasmtime config)",
    "wt50-tokio1-cacheN-parN": "binding wasmtime config plus -C parallel-compilation=n",
    "wt50-tokio1-cacheN-cpuset0": "binding wasmtime config, container restricted to CPU 0",
    "wt26-tokio1-cacheN": "wasmtime 26.0.1 with TOKIO_WORKER_THREADS=1 and -C cache=n",
    "wt50-tokio1-cacheN-fixrand": "binding wasmtime config with a deterministic getrandom() preloaded into the guest (diagnostic)",
    "wt50-t1c-concN": "binding wasmtime config plus -W concurrency-support=n (cwasm compiled to match)",
    "wt50-concN-only": "wasmtime 50.0.0 with -W concurrency-support=n only (cwasm compiled to match)",
    "wt50-t1c-pool": "binding wasmtime config plus -O pooling-allocator=y (guest killed under qemu)",
    "wt50-t1c-pool2": "repeat of wt50-t1c-pool, 2 runs of tak only (guest killed under qemu)",
    "wt50-t1c-cowN": "binding wasmtime config plus -O memory-init-cow=n (cwasm mismatch: the module never ran)",
    "wt50-t1c-fixed2": "replication of the binding wasmtime config",
    "wt50-t1c-sigtrapN": "binding wasmtime config plus -O signals-based-traps=n (cwasm compiled to match)",
    "node-B-base": "Node 26.5.0 --predictable --single-threaded --single-threaded-gc (Liftoff only, no tier-up)",
    "node-A-noliftoff": "Node base flags plus --no-liftoff (TurboFan, lazy; the study's binding V8 config)",
    "node-A-rep2": "replication of node-A-noliftoff",
    "node-A2-noliftoff-eager": "Node base flags plus --no-liftoff --no-wasm-lazy-compilation (TurboFan, eager)",
    "node-D-dyntier-sync": "Node --predictable --single-threaded-gc --wasm-sync-tier-up (dynamic tiering, synchronous)",
    "node-E-dyntier-default": "Node --predictable --single-threaded-gc (dynamic tiering in background threads)",
}
def expected(b, n):
    sp = json.load(open(f"{REPO}/benchmarks/{b}/spec.json"))
    return sp["checksums"]["n1" if n == sp["n1"] else "n2"]["sum"]
# Validity is judged per block: the RAW lines of one (configuration, benchmark, size) followed by its SUM line.
# A block counts only if every run printed the spec checksum. A label re-run after a failed first attempt (e.g. a
# precompile step added) keeps its valid blocks; a configuration with no valid block at all is listed as excluded.
pending, failed_blocks, rows = {}, set(), []
for line in open(f"{L}/runtime/raw/knobs-raw.log"):
    m = re.match(r"RAW (\S+) (\S+) n=(\d+) run\d+ out=(\S*) ", line)
    if m:
        ok = m[4] == str(expected(m[2], int(m[3])))
        k = (m[1], m[2], m[3])
        pending[k] = pending.get(k, True) and ok
        continue
    s = re.match(r"SUM (\S+) (\S+) n=(\d+) ", line)
    if not s:
        continue
    m = re.match(r"SUM (\S+) (\S+) n=(\d+) threads=(\S+) cpu0=(\d+)\.\.(\d+) others=(\d+)\.\.(\d+) total=(\d+)\.\.(\d+) spread%=([\d.]+)", line)
    # every SUM line closes its block; an unparsable one (spread%=+nan when no run produced a count) is a failure
    if not pending.pop((s[1], s[2], s[3]), False) or not m:
        failed_blocks.add(s[1])
        continue
    rows.append(dict(config=m[1], benchmark=m[2], n=int(m[3]), threads=m[4], cpu0Min=int(m[5]), cpu0Max=int(m[6]),
                     othersMin=int(m[7]), othersMax=int(m[8]), totalMin=int(m[9]), totalMax=int(m[10]), spreadPct=float(m[11])))
bad = failed_blocks - {r["config"] for r in rows}
print("jitter configs excluded (no valid block):", sorted(bad))
print("jitter configs with some failed blocks dropped:", sorted(failed_blocks - bad))
env = dict(META, kind="jitter",
           description="Per-thread guest instruction counts (plugin cpu N lines) over 5 runs for tak, fannkuch and dijkstra "
                       "under wasmtime run-configuration knobs; spread = (max-min)/median of the process total per size.",
           provenance="languages/wasm/experiments/runtime/ (knob-run.sh)",
           spreadMeaning="spreadPct = (max - min) / median of the per-size process total over the runs, percent (lower is better)",
           excluded=dict(configs=sorted(bad), reason="no block where every run printed the spec checksum (flag rejected, cwasm mismatch or guest killed)",
                         droppedFailedBlocks=sorted(failed_blocks - bad)),
           rows=rows,
           legend={k: LEGEND[k] for k in sorted({r["config"] for r in rows} | bad)})
p = os.path.join(OUT, f"{DATE}-arm64-jitter.json"); json.dump(env, open(p, "w"), indent=1); print(">>", p, len(rows), "rows")

# ---- codegen ----------------------------------------------------------------------------------
cells = {}
for f in ("o2", "o3", "wasmopt", "simd"):
    for line in open(f"{L}/codegen/raw/{f}.txt"):
        parts = line.split(" ", 3)
        if len(parts) < 4 or not parts[3].startswith("{"):
            continue
        try:
            j = json.loads(parts[3])
        except ValueError:
            continue
        if not j.get("correct"):
            continue
        img, col = parts[0], parts[1]
        tag = f"{img.replace('lang-lab-wasm-codegen-', '')}/{col}"
        cells[(tag, j["benchmark"])] = slim(j, tag, dict(image=img))
cells = list(cells.values())
write("codegen",
      "C compile-option and wasmtime code-generation knobs (wasmtime 50.0.0, wasi-sdk 34). Each wasm column is "
      "divided by its symmetric native clang 23.1.0 control (-O3 by -O3, everything else by -O2).",
      cells,
      [dict(key="o2", label="-O2", num="o2/wasm", den="o2/native"),
       dict(key="o3", label="-O3 (vs native -O3)", num="o3/wasm", den="o3/native"),
       dict(key="wasmopt", label="-O2 + wasm-opt -O3", num="wasmopt/wasm", den="o2/native"),
       dict(key="simd", label="-O2 -msimd128", num="simd/wasm", den="o2/native"),
       dict(key="bounds", label="explicit bounds checks", num="o2/knob/bounds", den="o2/native"),
       dict(key="nosig", label="no signal-based traps", num="o2/knob/nosig", den="o2/native"),
       dict(key="eagertable", label="eager table init", num="o2/knob/eagertable", den="o2/native"),
       dict(key="copt0", label="Cranelift opt-level=0", num="o2/knob/copt0", den="o2/native"),
       dict(key="inline", label="Cranelift inlining on", num="o2/knob/inline", den="o2/native")],
      ["bounds = -O memory-reservation=0 -O memory-guard-size=0; nosig = -O signals-based-traps=n; eagertable = "
       "-O table-lazy-init=n; copt0 = -O opt-level=0; inline = -C inlining=y; each cwasm compiled with the same flags",
       "Binaryen version_133 (sha256 89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8)",
       "-O opt-level=1 produces byte-identical cwasm to the default for all 18 modules"],
      "languages/wasm/experiments/codegen/")

# ---- wall-clock validation ----------------------------------------------------------------------
WD = f"{L}/wallclock"
w = json.load(open(f"{WD}/pooledCD/summary-user_ns.json"))
wall = json.load(open(f"{WD}/pooledCD/summary.json"))
COMP = [("wasmtime", "clang"), ("node", "clang"), ("node-liftoff", "clang"), ("gcc", "clang")]
bad_b = sorted(b for b, g in w["gate"].items() if g.get("problems"))   # gate at L: any problem drops the benchmark
rows = []
for key, c in sorted(w["cells"].items()):
    size, num, den, b = key.split("/")
    if size != "large" or (num, den) not in COMP or b in bad_b:
        continue
    if not c.get("resolved", True) or any(not math.isfinite(x) for x in c["ci"] + [c["time_ratio"]]):
        continue
    rows.append(dict(benchmark=b, num=num, den=den, L=w["gate"][b]["L"], timeRatio=round(c["time_ratio"], 4),
                     ci95=[round(x, 4) for x in c["ci"]], instrRatio=round(c["instr_ratio"], 4),
                     numMs=round(c["t_w_ms"], 2), denMs=round(c["t_c_ms"], 2),
                     numIqrMs=round(c["iqr_w_ms"], 2), denIqrMs=round(c["iqr_c_ms"], 2)))
stats = {}
for (num, den) in COMP + [("node", "wasmtime")]:
    s, sw = w[f"stats/large/{num}/{den}"], wall[f"stats/large/{num}/{den}"]
    stats[f"{num}/{den}"] = dict(n=s["n"], spearman=round(s["spearman"], 3), r2Log=round(s["r2_log"], 3),
                                 geomeanTime=round(s["geomean_time"], 4), geomeanInstr=round(s["geomean_instr"], 4),
                                 wallSpearman=round(sw["spearman"], 3), wallR2Log=round(sw["r2_log"], 3))
for (num, den) in COMP:
    s = w[f"stats/spec/{num}/{den}"]
    stats[f"spec:{num}/{den}"] = dict(n=s["n"], spearman=round(s["spearman"], 3), r2Log=round(s["r2_log"], 3))

def _pearson(x, y):
    mx, my = sum(x) / len(x), sum(y) / len(y)
    return sum((a - mx) * (b - my) for a, b in zip(x, y)) / math.sqrt(sum((a - mx) ** 2 for a in x) * sum((b - my) ** 2 for b in y))
# replication: the two headline passes against each other (log user-time ratios, all four comparisons, size L)
cC = json.load(open(f"{WD}/passC/summary-user_ns.json"))["cells"]; cD = json.load(open(f"{WD}/passD/summary-user_ns.json"))["cells"]
ks = [k for k in cC if k.startswith("large/") and tuple(k.split("/")[1:3]) in COMP and k in cD
      and cC[k]["time_ratio"] > 0 and cD[k]["time_ratio"] > 0]
xs, ys = [math.log(cC[k]["time_ratio"]) for k in ks], [math.log(cD[k]["time_ratio"]) for k in ks]
passes = {p: round(json.load(open(f"{WD}/{p}/summary-user_ns.json"))["stats/large/wasmtime/clang"]["geomean_time"], 3)
          for p in ("passA", "passB", "passC", "passD")}
# run-queue wait at size L in the headline passes: (wall - user - sys) / wall per run
waits = sorted((r["wall_ns"] - r["user_ns"] - r["sys_ns"]) / r["wall_ns"]
               for p in ("passC", "passD") for r in map(json.loads, open(f"{WD}/{p}/timing.jsonl"))
               if r["n"] == w["gate"][r["bench"]]["L"] and r["wall_ns"] > 0)
q = lambda v, f: v[min(len(v) - 1, int(f * len(v)))]
rel_iqr = sorted(r["numIqrMs"] / r["numMs"] for r in rows) 
spec_ms = sorted(c["t_c_ms"] for k, c in w["cells"].items() if k.startswith("spec/wasmtime/clang/"))
checks = dict(
    passCvsD=dict(n=len(ks), r2Log=round(_pearson(xs, ys) ** 2, 3)),
    wasmtimeTimeGeomeanByPass=passes,
    runQueueShareOfWallAtL=dict(p10=round(q(waits, 0.10), 3), median=round(q(waits, 0.5), 3), p90=round(q(waits, 0.9), 3)),
    numeratorRelIqrOfDifferential=dict(min=round(rel_iqr[0], 3), median=round(q(rel_iqr, 0.5), 3), max=round(rel_iqr[-1], 3)),
    clangDifferentialMsAtL=dict(min=round(min(r["denMs"] for r in rows), 1), max=round(max(r["denMs"] for r in rows), 1)),
    clangDifferentialMsAtSpecSizes=dict(min=round(spec_ms[0], 1), max=round(spec_ms[-1], 1)),
)
env = dict(META, kind="wallclock",
           metric="user CPU time differential t(L)-t(n1) (median of 50 paired repetitions) vs instruction differential I(L)-I(n1)",
           description="Native timing inside lang-lab-wasm:c, pinned with taskset to one vCPU, benchmarks one at a time, each "
                       "repetition running every (column, size) pair in a fresh random order. L is a per-benchmark size larger "
                       "than the spec sizes (see checks.clangDifferentialMsAtL); the gate requires every column to print clang's "
                       "checksum at L. Two passes (C, D) with the study's binding runtime flags, 25 repetitions each, pooled.",
           estimator="user CPU time, because about half of the wall time was run-queue wait on a loaded host (checks.runQueueShareOfWallAtL); "
                     "the two passes agree (checks.passCvsD) and the verdict also holds on wall time (stats.*.wallSpearman/wallR2Log)",
           ratioMeaning="numerator / denominator (lower is better); timeRatio and instrRatio are both differentials. "
                        "spearman and r2Log: how well instrRatio tracks timeRatio across benchmarks (higher is better)",
           caveats=["absolute times are not quoted: the Docker VM has no steal-time accounting, so user time may include host preemption",
                    "passes A and B used the pre-final runtime flags; their wasmtime time geomeans are in checks.wasmtimeTimeGeomeanByPass"],
           excludedBenchmarks=bad_b,
           provenance="languages/wasm/experiments/wallclock/",
           stats=stats, checks=checks, rows=rows)
p = os.path.join(OUT, f"{DATE}-arm64-wallclock.json"); json.dump(env, open(p, "w"), indent=1); print(">>", p, len(rows), "rows")
if DROPPED:
    print("cells dropped because their last run failed the gate:", DROPPED)
