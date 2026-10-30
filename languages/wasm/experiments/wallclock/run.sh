#!/usr/bin/env bash
# WebAssembly side study, wall-clock experiment driver (OUT OF THE RANKING).
#
# Question: does the instruction-count metric rank the wasm columns the way real time does? Times the C
# column natively (no qemu) inside lang-lab-wasm:c, as clang, gcc, wasmtime, node (V8 TurboFan) and
# node-liftoff, and compares each column's time differential over clang with its instruction differential
# over clang, per benchmark.
#   1. timing: one long-lived lang-lab-wasm:c container; for every pass (default C and D), run-timing.sh runs
#      the benchmarks one at a time, every process pinned to one vCPU, 25 repetitions, each repetition
#      running every (column, size) pair in a fresh random order. Sizes: spec n1, n2 and a large L
#      (sizes.txt: calibrated to about 100 to 300 ms of native clang run time) so the differential t(L)-t(n1) is well resolved.
#   2. pool: the passes are pooled (pool.py) into pooled<passes> (default pooledCD, 50 paired repetitions).
#   3. counts: the instruction differentials of the same commands under qemu-user + the insn plugin
#      (count-one.sh, 3 in parallel), for set spec (n1, n2) and set large (n1, L; gated on clang's L output).
#   4. analysis: analyze.py on every pass and the pool, on wall time and on user CPU time (METRIC=user_ns).
# The headline estimator is user CPU time: in the study about half of the wall time was run-queue wait on a
# loaded host, while user time was stable and passes C and D agree (ingest.py records both in `checks`).
#
# Output in $OUT (default $EXP_OUT/wallclock, EXP_OUT default ${TMPDIR:-/tmp}/lang-lab-wasm-experiments):
# pass<P>/{timing.jsonl,timing.log,sizes.txt,counts.jsonl,report*.txt,summary*.json}, the same for the pool,
# and counts.jsonl. ingest.py reads pooledCD/summary-user_ns.json into results/wasm/<date>-arm64-wallclock.json
# (timeRatio and instrRatio = column / clang differential, lower is better).
#
#   languages/wasm/experiments/wallclock/run.sh
#   BENCH=tak PASSES="C" REPS=2 languages/wasm/experiments/wallclock/run.sh     # smoke test
#
# Environment: PASSES (default "C D"), REPS (default 25), BENCH (subset of sizes.txt), WALL_CPU (vCPU to
# pin, default 7: needs an 8-vCPU Docker VM), PAR (count jobs in parallel, default 3), SKIP_TIMING=1 /
# SKIP_COUNTS=1 (reuse what is in $OUT). Run it on an otherwise idle host: absolute times are not quoted
# because the Docker VM has no steal-time accounting. About 2.5 hours (timing about 40 minutes, counts
# about 1.5 hours). Requires Docker, jq, python3. Bash 3.2 compatible.
#
# Differences from the study run: passes A and B ran an earlier timeit.py (wasmtime and node without the
# binding flags, no node-liftoff column) and are not part of the headline; the counts ran while timing
# passes were still running (here they run after the timing); the first counts batch was split by a
# mid-run flag change (see count-one.sh).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${OUT:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/wallclock}"
PASSES="${PASSES:-C D}"; REPS="${REPS:-25}"; PAR="${PAR:-3}"
mkdir -p "$OUT"
SIZES="$OUT/sizes.txt"
if [ -n "${BENCH:-}" ]; then
  : > "$SIZES"; for b in $BENCH; do grep "^$b " "$HERE/sizes.txt" >> "$SIZES"; done
else cp "$HERE/sizes.txt" "$SIZES"; fi

CT=lang-lab-wasm-wallclock-run
if [ "${SKIP_TIMING:-0}" != 1 ]; then
  docker rm -f $CT >/dev/null 2>&1 || true
  docker run -d --name $CT lang-lab-wasm:c sleep infinity >/dev/null
  trap 'docker rm -f '$CT' >/dev/null 2>&1 || true' EXIT
  docker cp "$HERE/timeit.py" $CT:/tmp/timeit.py
  docker cp "$HERE/run-timing.sh" $CT:/tmp/run-timing.sh
  docker cp "$SIZES" $CT:/tmp/sizes.txt
  for p in $PASSES; do
    echo ">> timing pass $p ($REPS repetitions)" >&2
    docker exec -e "WALL_CPU=${WALL_CPU:-7}" $CT bash /tmp/run-timing.sh "$p" "$REPS"
    mkdir -p "$OUT/pass$p"
    docker cp $CT:/tmp/timing-$p.jsonl "$OUT/pass$p/timing.jsonl"
    docker cp $CT:/tmp/timing-$p.log "$OUT/pass$p/timing.log"
    cp "$SIZES" "$OUT/pass$p/"
  done
  docker rm -f $CT >/dev/null; trap - EXIT
fi

pool="$OUT/pooled$(echo $PASSES | tr -d ' ')"; dirs=""
for p in $PASSES; do dirs="$dirs $OUT/pass$p"; done
python3 -I "$HERE/pool.py" "$pool" $dirs

if [ "${SKIP_COUNTS:-0}" != 1 ]; then
  # CL = clang's first output line at L (identical in every repetition; analyze.py's gate checks it).
  first="$(echo $PASSES | cut -d' ' -f1)"
  jobs="$OUT/count-jobs.txt"; : > "$jobs"
  while read -r b L; do
    [ -n "$b" ] || continue
    CL="$(jq -r --arg b "$b" --argjson n "$L" 'select(.bench == $b and .col == "clang" and .n == $n) | .out' "$OUT/pass$first/timing.jsonl" | head -1)"
    for c in clang gcc wasmtime node node-liftoff; do
      echo "spec $c $b" >> "$jobs"; echo "large $c $b $L $CL" >> "$jobs"
    done
  done < "$SIZES"
  echo ">> counts: $(wc -l < "$jobs" | tr -d ' ') cells, $PAR in parallel" >&2
  xargs -P "$PAR" -L1 "$HERE/count-one.sh" < "$jobs" > "$OUT/counts.jsonl"
  grep -c '"fail"' "$OUT/counts.jsonl" >&2 || true
fi

for d in $dirs "$pool"; do
  cp "$OUT/counts.jsonl" "$d/"
  python3 -I "$HERE/analyze.py" "$d" > "$d/report.txt"
  METRIC=user_ns python3 -I "$HERE/analyze.py" "$d" > "$d/report-user.txt"
done
echo "WALLCLOCK DONE -> $pool/summary-user_ns.json" >&2
