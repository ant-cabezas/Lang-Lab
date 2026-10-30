#!/usr/bin/env bash
# WebAssembly side study, codegen experiment: ONE cell, run INSIDE a lang-lab-wasm-codegen-* image
# (run-batch.sh pipes it in on stdin):
#
#   docker run --rm -i lang-lab-wasm-codegen-o2 bash -s -- <variant> <bench> < cell.sh
#   variant: native | wasm | knob/<k>     -> one measure.sh JSON line on stdout
#
# Full spec sizes from /app/benchmarks/<bench>/spec.json, checksum gate on, measure.sh's adaptive RUNS
# (2, escalating to 5 on jitter: natives stay at 2, the wasm cells escalate to 5).
# The wasm cells run with the study's binding wasmtime configuration (-C cache=n, TOKIO_WORKER_THREADS=1).
# A knob variant runs its cwasm with the same wasmtime flags it was compiled with (/app/knob/<k>/FLAGS).
# No `set -e`: measure.sh's exit status is reported by its JSON line, not by this script.
set -u
v="$1"; b="$2"; spec=/app/benchmarks/$b/spec.json
export N1=$(jq -r .n1 $spec) N2=$(jq -r .n2 $spec) RUNTIME_KIND=native
export CHECK1_SUM=$(jq -r .checksums.n1.sum $spec) CHECK1_FLIPS=$(jq -r '.checksums.n1.secondary // ""' $spec)
export CHECK2_SUM=$(jq -r .checksums.n2.sum $spec) CHECK2_FLIPS=$(jq -r '.checksums.n2.secondary // ""' $spec)
export TOKIO_WORKER_THREADS=1
case "$v" in
  native) cmd=(/app/native/$b);;
  wasm)   cmd=(/usr/local/bin/wasmtime run -C cache=n --allow-precompiled /app/wasm/$b.cwasm);;
  knob/*) cmd=(/usr/local/bin/wasmtime run -C cache=n $(cat /app/$v/FLAGS) --allow-precompiled /app/$v/$b.cwasm);;
  *) echo "cell.sh: unknown variant $v" >&2; exit 2;;
esac
echo "CMD: ${cmd[*]}" >&2
measure.sh "$v" "$b" -- "${cmd[@]}"
