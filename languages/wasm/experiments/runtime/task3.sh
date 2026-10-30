#!/usr/bin/env bash
# WebAssembly side study, runtime experiment, task 3: V8 (Node 26.5.0, V8 14.6) tiering configurations.
#
# Question: which V8 compiler tier does the node column measure? Under --single-threaded V8 forces
# --no-wasm-tier-up, so the base flags leave every wasm function in the Liftoff baseline tier forever.
# Four configurations of the C modules (/app/wasm/<b>.wasm of lang-lab-wasm:c):
#   node-A-noliftoff         base flags + --no-liftoff: TurboFan for every function, compiled lazily on the
#                            main thread (the study's binding node column)
#   node-A2-noliftoff-eager  + --no-wasm-lazy-compilation: TurboFan, eager (compilation moves out of the differential)
#   node-B-base-liftoff      base flags only: Liftoff forever
#   node-D-dyntier-sync      no --single-threaded, --wasm-sync-tier-up: dynamic tiering, synchronous
# base flags = --predictable --single-threaded --single-threaded-gc. RUNS=5, checksum gate on, 3 cells in parallel.
#
# Output: $RAWDIR/task3.jsonl (appended; default $EXP_OUT/runtime/raw). ingest.py turns it, together with
# the clang-23.1.0 and wt50.0.0-rec rows of task1.jsonl, into results/wasm/<date>-arm64-v8-tiering.json
# (ratio = node differential / clang differential, lower is better).
#
#   languages/wasm/experiments/runtime/task3.sh
#   BENCHES=tak languages/wasm/experiments/runtime/task3.sh      # smoke test
#
# About 20 minutes on an 8-vCPU Docker VM. Needs only lang-lab-wasm:c. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"
O="$RAWDIR/task3.jsonl"; mkdir -p "$RAWDIR"; I=lang-lab-wasm:c
BASE='/usr/local/bin/node --predictable --single-threaded --single-threaded-gc'
"$HERE/sweep.sh" $I node-A-noliftoff "$O" -- $BASE --no-liftoff /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
"$HERE/sweep.sh" $I node-B-base-liftoff "$O" -- $BASE /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
"$HERE/sweep.sh" $I node-A2-noliftoff-eager "$O" -- $BASE --no-liftoff --no-wasm-lazy-compilation /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
"$HERE/sweep.sh" $I node-D-dyntier-sync "$O" -- /usr/local/bin/node --predictable --single-threaded-gc --wasm-sync-tier-up /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
echo "TASK3 DONE -> $O" >&2
