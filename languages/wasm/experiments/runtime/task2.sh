#!/usr/bin/env bash
# WebAssembly side study, runtime experiment, task 2: the wasi-sdk (compiler) sweep.
#
# Question: how much of the C column's wasm/native ratio is the compiler release rather than the runtime?
# wasi-sdk 25 / 30 / 34 (clang 19.1.5 / 21.1.4 / 23.1.0), each divided by a native control built with the
# official LLVM release of the same clang version, all run on wasmtime 50.0.0 with the binding run
# configuration (TOKIO_WORKER_THREADS=1, -C cache=n). Rows (tags):
#   sdk25-wasm, sdk30-wasm, sdk30-wasm-mvp, sdk34-wasm-mvp   wasm cells, RUNS=5
#   clang-19.1.5, clang-21.1.4 (+ clang-lp64-*)              native controls (and the lp64 no-op check), RUNS=2
#   clang-lp64-23.1.0                                         the lp64 check for the study's own clang
#   sdk25-wt26-rec                                            2x2 corner: sdk 25 modules on wasmtime 26.0.1
# The sdk34 rows (wt50.0.0-rec, clang-23.1.0) and sdk34 on wasmtime 26 (wt26.0.1-rec) come from task1.
# In the study run the sdk25-wt26-rec sweep was a separate command after the rest; it is the last step here.
#
# Output: $RAWDIR/task2.jsonl (appended; default $EXP_OUT/runtime/raw). ingest.py turns it into
# results/wasm/<date>-arm64-sdk-sweep.json (ratio = numerator differential / denominator differential, lower is better).
#
# Prerequisites: fetch-sdk.sh; build-sdk.sh 25 19.1.5; build-sdk.sh 30 21.1.4; build-sdk34mvp.sh;
# build-wt.sh (for wt26.0.1); build-sdk25wt26.sh. About 15 minutes on an 8-vCPU Docker VM.
#   BENCHES=tak languages/wasm/experiments/runtime/task2.sh       # smoke test
# Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"
O="$RAWDIR/task2.jsonl"; mkdir -p "$RAWDIR"
REC='/usr/local/bin/wasmtime run -C cache=n --allow-precompiled'
export DENV="-e TOKIO_WORKER_THREADS=1"
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk25 sdk25-wasm "$O" -- $REC /app/sdk25/wasm/{b}.cwasm
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk30 sdk30-wasm "$O" -- $REC /app/sdk30/wasm/{b}.cwasm
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk30 sdk30-wasm-mvp "$O" -- $REC /app/sdk30/wasm-mvp/{b}.cwasm
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk34mvp sdk34-wasm-mvp "$O" -- $REC /app/sdk34mvp/wasm-mvp/{b}.cwasm
export DENV=""
export RUNS=2
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk25 clang-19.1.5 "$O" -- /app/sdk25/clang/{b}
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk25 clang-lp64-19.1.5 "$O" -- /app/sdk25/clang-lp64/{b}
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk30 clang-21.1.4 "$O" -- /app/sdk30/clang/{b}
"$HERE/sweep.sh" lang-lab-wasm-runtime-sdk30 clang-lp64-21.1.4 "$O" -- /app/sdk30/clang-lp64/{b}
"$HERE/sweep.sh" lang-lab-wasm:c clang-lp64-23.1.0 "$O" -- /app/clang-lp64/{b}
# The 2x2 corner, with the binding wasmtime configuration and the default RUNS=5.
unset RUNS
DENV="-e TOKIO_WORKER_THREADS=1" "$HERE/sweep.sh" lang-lab-wasm-runtime-sdk25wt26 sdk25-wt26-rec "$O" -- \
  /usr/local/bin/wasmtime run -C cache=n --allow-precompiled /app/sdk25wt26/{b}.cwasm
echo "TASK2 DONE -> $O" >&2
