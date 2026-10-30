#!/usr/bin/env bash
# WebAssembly side study, wall-clock experiment: the instruction count of ONE (set, column, benchmark).
#
#   count-one.sh <set: spec|large> <col> <bench> [L] [CL]    -> one tagged measure.sh JSON line on stdout
#
# Runs scripts/measure.sh in lang-lab-wasm:c under qemu-user + the insn plugin with the same column
# commands timeit.py times. set spec = the spec sizes n1/n2 and checksums; set large = n1 and the large
# size L, gated on CL (clang's checksum at L). Output: {"set","col","m": <measure.sh line>} or
# {"set","col","bench","fail": rc,"err": "..."}. measure.sh's adaptive RUNS (2, escalating to 5).
# Columns: clang, gcc, wasmtime (binding flags), node (--no-liftoff), node-liftoff, and wasmtime-old
# (no binding flags). In the study run the first 111 jobs ran before the binding flags were adopted; their
# wasmtime / node rows were relabeled wasmtime-old / node-liftoff (the commands those columns run here)
# and the missing cells re-run; run.sh runs the final columns directly.
# Requires Docker and jq. Bash 3.2 compatible.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ $# -ge 3 ] || { echo "usage: count-one.sh <spec|large> <col> <bench> [L] [CL]" >&2; exit 2; }
set_="$1"; col="$2"; b="$3"; L="${4:-}"; CL="${5:-}"
spec=$REPO/benchmarks/$b/spec.json
n1=$(jq -r .n1 $spec); n2=$(jq -r .n2 $spec)
c1=$(jq -r .checksums.n1.sum $spec); s1=$(jq -r '.checksums.n1.secondary // ""' $spec)
c2=$(jq -r .checksums.n2.sum $spec); s2=$(jq -r '.checksums.n2.secondary // ""' $spec)
if [ "$set_" = large ]; then n2=$L; c2=$CL; s2=""; fi
case $col in
  clang) kind=native; cmd=(/app/clang/$b);;
  gcc) kind=native; cmd=(/app/gcc/$b);;
  wasmtime-old) kind=inproc-vm; cmd=(/usr/local/bin/wasmtime run --allow-precompiled /app/wasm/$b.cwasm);;
  wasmtime) kind=inproc-vm; cmd=(/usr/local/bin/wasmtime run -C cache=n --allow-precompiled /app/wasm/$b.cwasm);;
  node-liftoff) kind=inproc-vm; cmd=(/usr/local/bin/node --predictable --single-threaded --single-threaded-gc /opt/wasm/run-node.mjs /app/wasm/$b.wasm);;
  node) kind=inproc-vm; cmd=(/usr/local/bin/node --predictable --single-threaded --single-threaded-gc --no-liftoff /opt/wasm/run-node.mjs /app/wasm/$b.wasm);;
  *) echo "count-one.sh: unknown column $col" >&2; exit 2;;
esac
err="$(mktemp)"; trap 'rm -f "$err"' EXIT
rc=0
# TOKIO_WORKER_THREADS=1 goes to every column (it only affects wasmtime), except wasmtime-old, which
# reproduces the pre-binding-flags runs that had neither it nor -C cache=n.
tok="-e TOKIO_WORKER_THREADS=1"; [ "$col" = wasmtime-old ] && tok=""
out=$(docker run --rm --name lang-lab-wasm-wallclock-q-$set_-$col-$b -e UV_THREADPOOL_SIZE=1 $tok -e NODE_NO_WARNINGS=1 \
  -e RUNTIME_KIND=$kind -e N1=$n1 -e N2=$n2 -e CHECK1_SUM=$c1 -e CHECK1_FLIPS=$s1 -e CHECK2_SUM=$c2 -e CHECK2_FLIPS=$s2 \
  lang-lab-wasm:c /usr/local/bin/measure.sh "wasm-$col" "$b" -- "${cmd[@]}" 2>"$err") || rc=$?
if [ $rc -eq 0 ]; then echo "{\"set\":\"$set_\",\"col\":\"$col\",\"m\":$out}"
else echo "{\"set\":\"$set_\",\"col\":\"$col\",\"bench\":\"$b\",\"fail\":$rc,\"err\":$(tail -5 "$err" | jq -Rs .)}"; fi
