#!/usr/bin/env bash
# WebAssembly side study, wall-clock experiment: first step of choosing the large size L. Runs INSIDE a
# lang-lab-wasm:c container (copy it in, then `bash /tmp/probe.sh`).
#
# From each benchmark's spec n2, grows n (by 1 for the exponential benchmarks fannkuch, binary-trees and
# tak, doubling otherwise) until native clang, pinned to vCPU 7, takes over 150 ms; prints every step with
# clang's first output line. calib.sh then refines the candidates; the chosen sizes are sizes.txt.
# No `set -e`: a benchmark that fails at some size must not stop the probe.
cd /app
for b in $(ls clang); do
  n=$(jq -r .n2 benchmarks/$b/spec.json)
  for i in 1 2 3 4 5 6 7 8; do
    s=$(date +%s%N); o=$(taskset -c 7 clang/$b $n | head -1); e=$(date +%s%N); t=$(( (e-s)/1000000 ))
    echo "$b n=$n clang=${t}ms out=$o"
    [ $t -gt 150 ] && break
    case $b in fannkuch|binary-trees|tak) n=$((n+1));; gemm|blur|mandelbrot) n=$((n*2));; *) n=$((n*2));; esac
  done
done
