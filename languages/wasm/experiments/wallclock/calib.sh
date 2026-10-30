#!/usr/bin/env bash
# WebAssembly side study, wall-clock experiment: second step of choosing the large size L. Runs INSIDE a
# lang-lab-wasm:c container (copy it in, then `bash /tmp/calib.sh`).
#
# For every benchmark, the best of 5 native clang runs (pinned to vCPU 7, microseconds) at spec n2 and at
# the candidate size below (from probe.sh). The final L in sizes.txt targets about 100 to 300 ms of native
# clang time; for several benchmarks it is a further multiple of these candidates, picked by hand from
# this output. No `set -e`: a failing size must not stop the calibration.
cd /app
while read b L; do
  for n in $(jq -r .n2 benchmarks/$b/spec.json) $L; do
    best=999999
    for i in 1 2 3 4 5; do s=$(date +%s%N); taskset -c 7 clang/$b $n >/dev/null; e=$(date +%s%N); t=$(( (e-s)/1000 )); [ $t -lt $best ] && best=$t; done
    echo "$b n=$n min5=${best}us"
  done
done <<'L'
bigint 12000
binary-trees 16
blur 1024
dijkstra 80000
fannkuch 10
gbdt 80000
gemm 512
k-means 32000
k-nucleotide 800000
lz77 96000
mandelbrot 1024
polymorphism 1000
reverse-complement 6400000
sha256 160000
sort-search 800000
tak 10
viterbi 640000
vm 3200000
L
