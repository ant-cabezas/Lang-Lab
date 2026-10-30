#!/usr/bin/env bash
# WebAssembly side study, wall-clock experiment: one timing pass. Runs INSIDE the long-lived
# lang-lab-wasm:c container that run.sh starts, with timeit.py at /tmp/timeit.py and sizes.txt at
# /tmp/sizes.txt (run.sh copies them in).
#
#   run-timing.sh <tag> <reps>      -> /tmp/timing-<tag>.jsonl and /tmp/timing-<tag>.log
#
# Serial, one benchmark at a time (the order of sizes.txt), every process pinned to one vCPU (WALL_CPU,
# default 7, so the Docker VM needs at least 8 vCPUs). Sizes: spec n1 and n2 (checked against the spec
# checksums) and the large size L from sizes.txt (checked by analyze.py against clang's output at L).
# The log records the load average at the start and end of every benchmark.
# The throwaway first version had 21 repetitions and no tag; every pass analyzed used this form with 25.
set -euo pipefail
tag="$1"; reps="$2"; cpu="${WALL_CPU:-7}"
cd /app
while read -r b L; do
  [ -n "$b" ] || continue
  n1=$(jq -r .n1 benchmarks/$b/spec.json); n2=$(jq -r .n2 benchmarks/$b/spec.json)
  c1=$(jq -r .checksums.n1.sum benchmarks/$b/spec.json); c2=$(jq -r .checksums.n2.sum benchmarks/$b/spec.json)
  echo "$(date -u +%FT%TZ) start $b $(cat /proc/loadavg)" >> /tmp/timing-$tag.log
  python3 /tmp/timeit.py $b $reps $cpu $n1:$c1 $n2:$c2 $L >> /tmp/timing-$tag.jsonl
  echo "$(date -u +%FT%TZ) end $b $(cat /proc/loadavg)" >> /tmp/timing-$tag.log
done < /tmp/sizes.txt
echo DONE >> /tmp/timing-$tag.log
