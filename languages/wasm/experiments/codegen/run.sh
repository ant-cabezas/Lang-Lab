#!/usr/bin/env bash
# WebAssembly side study, codegen experiment driver (OUT OF THE RANKING).
#
# Question: how much of the C column's wasm/native instruction ratio is the compile pipeline (C optimisation
# level, Binaryen, SIMD) or a wasmtime code-generation choice (bounds checks, signal-based traps, lazy table
# init, Cranelift opt level, inlining), rather than WebAssembly itself? Each wasm configuration is divided
# by its symmetric native clang 23.1.0 control (-O3 by -O3, everything else by -O2).
#
# Runs, in the study's order (batches sequential, 3 cells in parallel within a batch):
#   o2: native, wasm, knob/bounds, knob/nosig, knob/eagertable, knob/copt0, knob/inline -> raw/o2.txt
#   o3: native, wasm -> raw/o3.txt; wasmopt: wasm -> raw/wasmopt.txt; simd: wasm -> raw/simd.txt
# knob/copt1 (-O opt-level=1) is NOT measured: its cwasm is byte-identical to the default for all 18
# modules (checks.sh shows it). In the study run its batch was lost to a Docker disk-full incident along
# with most of the knob, o3, wasmopt and simd cells; those were re-run with the same scripts (the
# throwaway resume.sh) and copt1 was dropped then. This driver is the final, complete sequence.
#
# Output: $EXP_OUT/codegen/raw/{o2,o3,wasmopt,simd}.txt (appended) and $EXP_OUT/codegen/log/ (EXP_OUT default
# ${TMPDIR:-/tmp}/lang-lab-wasm-experiments). ingest.py turns them into results/wasm/<date>-arm64-codegen.json
# (ratio = wasm differential / native differential, lower is better); summarize.py prints the tables.
#
#   languages/wasm/experiments/codegen/build.sh && languages/wasm/experiments/codegen/run.sh
#   BENCHES=tak VARIANTS="o2:native o2:wasm" languages/wasm/experiments/codegen/run.sh   # smoke test
#
# About 1.5 hours on an 8-vCPU Docker VM (198 cells). Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUTDIR="${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/codegen"
mkdir -p "$OUTDIR/raw" "$OUTDIR/log"; export LOGDIR="$OUTDIR/log"
ALL="o2:native o2:wasm o2:knob/bounds o2:knob/nosig o2:knob/eagertable o2:knob/copt0 o2:knob/inline o3:native o3:wasm wasmopt:wasm simd:wasm"
for cv in ${VARIANTS:-$ALL}; do
  cfg="${cv%%:*}"; v="${cv#*:}"
  echo ">> lang-lab-wasm-codegen-$cfg $v" >&2
  "$HERE/run-batch.sh" "lang-lab-wasm-codegen-$cfg" "$v" "$OUTDIR/raw/$cfg.txt"
done
echo "CODEGEN DONE -> $OUTDIR/raw" >&2
