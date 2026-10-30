# WebAssembly side study: wall-clock experiment

Out of the ranking. The question is whether the instruction-count metric ranks the wasm columns the
way real time does. The C column is timed natively, without qemu, inside `lang-lab-wasm:c` as five
columns:

- clang
- gcc
- wasmtime (`TOKIO_WORKER_THREADS=1 -C cache=n`)
- node (`--no-liftoff`, TurboFan)
- node-liftoff

For each benchmark, every column's time differential over clang is set next to its instruction
differential over clang. The instruction differential comes from qemu-user plus the insn plugin,
using the same commands.

It produces the `results/wasm/<date>-arm64-wallclock.json` envelope. It contains:

- `timeRatio`: the column's user-CPU-time differential t(L) - t(n1) divided by clang's. The median of
  50 paired repetitions, pooled from passes C and D, with a 95% bootstrap CI.
- `instrRatio`: the same ratio on instruction differentials I(L) - I(n1).
- The Spearman correlation and R2 (log-log) between the two ratios over the 18 benchmarks.

For both ratios, **lower is better**: 1.0 means as fast as (or as many instructions as) native clang.
L is a per-benchmark size (`sizes.txt`) calibrated so native clang runs about 100 to 300 ms; the resulting clang
differentials t(L)-t(n1) are 53 to 208 ms (the envelope's `checks.clangDifferentialMsAtL`).

## Reproduce

You need Docker, jq, python3, `lang-lab-wasm:c`, and a Docker VM with at least 8 vCPUs, because every
timed process is pinned to vCPU 7 (`WALL_CPU`). Keep the host otherwise idle.

```sh
languages/wasm/experiments/wallclock/run.sh     # about 2.5 hours: timing about 40 min, counts about 1.5 h
python3 languages/wasm/experiments/ingest.py "${TMPDIR:-/tmp}/lang-lab-wasm-experiments" results/wasm "$(date +%F)"
SUMF=summary-user_ns.json python3 languages/wasm/experiments/wallclock/repro.py \
  "${TMPDIR:-/tmp}/lang-lab-wasm-experiments/wallclock" passC:passD   # pass-to-pass agreement
```

Output goes to `$OUT`, which defaults to `$EXP_OUT/wallclock`, with
`EXP_OUT=${TMPDIR:-/tmp}/lang-lab-wasm-experiments`. That directory gets `passC/`, `passD/` and
`pooledCD/` (timing, counts, reports, `summary.json` on wall time and `summary-user_ns.json` on user
time). `ingest.py` reads `pooledCD/summary-user_ns.json`. `analyze.py` is deterministic: its bootstrap
is seeded, so re-analyzing the same data gives byte-identical summaries.

Smoke test (about 5 minutes):

```sh
BENCH=tak PASSES=C REPS=2 OUT=/tmp/wc-smoke languages/wasm/experiments/wallclock/run.sh
```

## Files

- `run.sh` is the driver.
- `timeit.py` and `run-timing.sh` run inside the timing container.
- `pool.py` merges passes.
- `count-one.sh` measures one instruction-count cell.
- `analyze.py` writes the reports and summaries. `repro.py` compares passes.
- `sizes.txt` lists the large sizes. `probe.sh` and `calib.sh` are the in-container helpers used to
  choose them.

## Estimator and caveats

User CPU time is the headline estimator. In the study the median run at size L spent half of its wall
time waiting in the run queue of a loaded host (90th percentile 56%). The interquartile range of each
numerator differential is 6% of its median (2% to 20%), and passes C and D agree at R2 0.99 (all in the
envelope's `checks`). Absolute times are not quoted, because the Docker VM has no steal-time
accounting.

## Differences from the study run

- Passes A and B ran an earlier `timeit.py`: wasmtime and node without the binding flags, and no
  node-liftoff column. They replicate the wasmtime time geomean (1.254 and 1.268) but are not part of the
  headline. `run.sh` runs only C and D by default.
- The first counts batch was split by a mid-run flag change. Its pre-change wasmtime and node rows were
  relabeled `wasmtime-old` and `node-liftoff`, and the missing cells were re-run. `run.sh` runs the
  final columns directly. `count-one.sh` keeps a `wasmtime-old` column (no binding flags) for that
  comparison.
- In the study, the counts ran while timing passes were still running. `run.sh` runs them after the
  timing.
- A host-load logger (uptime every 60 s) ran alongside the study's passes. It is not part of these
  scripts.
- `analyze.py` now restricts the benchmark list to the ones in `sizes.txt`, so a one-benchmark smoke
  test can be analyzed. With the full `sizes.txt` its output is byte-identical to the study's.
