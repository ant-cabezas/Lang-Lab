#!/usr/bin/env bash
# WebAssembly side study, runtime experiment, task 1: the wasmtime version sweep.
#
# Question: is the C column's wasm/native ratio a property of WebAssembly or of the wasmtime release?
# The same wasi-sdk 34 modules run under seven wasmtime releases (latest patch of majors 26, 30, ..., 50),
# each precompiled by its own release (build-wt.sh), and are divided by the same native clang 23.1.0
# binary (/app/clang/<b> of lang-lab-wasm:c, the same LLVM release as wasi-sdk 34's clang).
#   <v>-rec      the study's binding run configuration: TOKIO_WORKER_THREADS=1 and -C cache=n
#   <v>-default  no extra flags (50.0.0 and 26.0.1 only), to show the binding flags do not move the counts
# Every cell: scripts/measure.sh at full spec sizes, checksum gate on, RUNS=5 (the native clang column
# RUNS=2, it is bit-exact), 3 cells in parallel.
#
# Output: $RAWDIR/task1.jsonl (appended; default $EXP_OUT/runtime/raw, EXP_OUT default
# ${TMPDIR:-/tmp}/lang-lab-wasm-experiments). ingest.py turns it into
# results/wasm/<date>-arm64-runtime-sweep.json (ratio = wasm differential / clang differential, lower is better).
#
#   languages/wasm/experiments/runtime/build-wt.sh && languages/wasm/experiments/runtime/task1.sh
#   BENCHES=tak languages/wasm/experiments/runtime/task1.sh     # smoke test
#
# About 15 minutes on an 8-vCPU Docker VM (10 configurations x 18 benchmarks). Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"
O="$RAWDIR/task1.jsonl"; mkdir -p "$RAWDIR"
RUNS=2 "$HERE/sweep.sh" lang-lab-wasm:c clang-23.1.0 "$O" -- /app/clang/{b}
REC='/usr/local/bin/wasmtime run -C cache=n --allow-precompiled /app/wt/{b}.cwasm'
DEF='/usr/local/bin/wasmtime run --allow-precompiled /app/wt/{b}.cwasm'
"$HERE/sweep.sh" lang-lab-wasm-runtime-wt50.0.0 wt50.0.0-default "$O" -- $DEF
for v in 50.0.0 26.0.1 30.0.2 34.0.2 38.0.4 42.0.2 46.0.3; do
  DENV="-e TOKIO_WORKER_THREADS=1" "$HERE/sweep.sh" "lang-lab-wasm-runtime-wt$v" "wt$v-rec" "$O" -- $REC
done
"$HERE/sweep.sh" lang-lab-wasm-runtime-wt26.0.1 wt26.0.1-default "$O" -- $DEF
echo "TASK1 DONE -> $O" >&2
