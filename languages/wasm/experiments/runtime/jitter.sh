#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: the jitter diagnosis (which run flags make wasmtime and V8
# count deterministically under qemu-user + the insn plugin).
#
# Question: a default `wasmtime run` starts 8 guest threads (main + 7 tokio workers + a cache worker) and
# its per-size count moves by up to about 0.2% between runs. Which knob removes that, and does it move
# the differential? Every configuration below runs tak, fannkuch and dijkstra at both spec sizes, 5 times,
# and records the per-thread counts (knob.sh). The outcome is the study's binding configuration
# (TOKIO_WORKER_THREADS=1 + -C cache=n for wasmtime; --no-liftoff for Node, see languages/wasm/c/lane.json).
#
# The CONFIGS table is every configuration of the study run, with the exact image, docker flags, optional
# in-container precompile step (PRE) and command, in the order and parallel batches they were run
# (configurations of one batch run concurrently; the P1 rows were re-run alone to rule out contention).
# Aliases: wt26 / wt50 = lang-lab-wasm-runtime-wt26.0.1 / -wt50.0.0 (build-wt.sh), c = lang-lab-wasm:c.
# Known outcomes kept on purpose; ingest.py drops every block in which a run did not print the spec checksum:
#   wt50-preview2n  -S preview2=n is rejected by wasmtime 50 (the module never runs)
#   wt50-t1c-pool*  -O pooling-allocator=y: qemu's child is SIGKILLed (reproduced with free disk, so it is the knob)
#   wt50-t1c-cowN   -O memory-init-cow=n with the stock cwasm: compile-setting mismatch error, never re-run
# Corrected relative to the study run: wt50-t1c-concN was first run WITHOUT a matching cwasm (error, the
# module never ran) and then re-run validly with PRE under the same label. Only the valid form is here.
# ingest.py judges each (configuration, benchmark, size) block separately, so the envelope keeps the valid
# rows and lists the failed attempt under excluded.droppedFailedBlocks.
#
# Output: $RAWDIR/knobs-raw.log (appended; default $EXP_OUT/runtime/raw, EXP_OUT default
# ${TMPDIR:-/tmp}/lang-lab-wasm-experiments). ingest.py turns it into results/wasm/<date>-arm64-jitter.json
# (spreadPct = (max-min)/median of the process total per size, percent, lower is better).
#
#   languages/wasm/experiments/runtime/build-wt.sh && languages/wasm/experiments/runtime/jitter.sh
#   ONLY="wt50-default node-A-noliftoff" REPS=1 BS=tak languages/wasm/experiments/runtime/jitter.sh   # smoke test
#
# Environment: ONLY (space-separated labels to run, default all), REPS and BS override every row's
# repetitions / benchmarks (the pool2 row pins REPS=2 BS=tak unless overridden). About 40 minutes.
# Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
export RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"; mkdir -p "$RAWDIR"

W='/usr/local/bin/wasmtime run --allow-precompiled /app/wt/{b}.cwasm'
WC='/usr/local/bin/wasmtime run -C cache=n'
N='/usr/local/bin/node --predictable --single-threaded --single-threaded-gc'
CW='mkdir -p /tmp/cw; for b in tak fannkuch dijkstra; do wasmtime compile'
# batch | label | image | docker flags | PRE | reps,benches override | runner | command
CONFIGS="1|wt50-default|c|||||/usr/local/bin/wasmtime run --allow-precompiled /app/wasm/{b}.cwasm
2|wt26-default|wt26|||||$W
2|wt50-preview2n|wt50|||||/usr/local/bin/wasmtime run -S preview2=n --allow-precompiled /app/wt/{b}.cwasm
2|wt50-rayon1|wt50|-e RAYON_NUM_THREADS=1||||$W
3|wt26-default-P1|wt26|||||$W
4|wt50-default-P1|wt50|||||$W
5|wt50-tokio1|wt50|-e TOKIO_WORKER_THREADS=1||||$W
5|wt50-cpuset0|wt50|--cpuset-cpus=0||||$W
5|wt50-parcompN|wt50|||||/usr/local/bin/wasmtime run -C parallel-compilation=n --allow-precompiled /app/wt/{b}.cwasm
6|wt50-cacheN|wt50|||||$WC --allow-precompiled /app/wt/{b}.cwasm
6|wt50-tokio1-cacheN|wt50|-e TOKIO_WORKER_THREADS=1||||$WC --allow-precompiled /app/wt/{b}.cwasm
6|wt50-tokio1-cacheN-parN|wt50|-e TOKIO_WORKER_THREADS=1||||$WC -C parallel-compilation=n --allow-precompiled /app/wt/{b}.cwasm
7|wt50-tokio1-cacheN-cpuset0|wt50|-e TOKIO_WORKER_THREADS=1 --cpuset-cpus=0||||$WC --allow-precompiled /app/wt/{b}.cwasm
7|wt26-tokio1-cacheN|wt26|-e TOKIO_WORKER_THREADS=1||||$WC --allow-precompiled /app/wt/{b}.cwasm
8|wt50-tokio1-cacheN-fixrand|wt50|-e TOKIO_WORKER_THREADS=1|||shim|$WC --allow-precompiled /app/wt/{b}.cwasm
9|wt50-t1c-pool|wt50|-e TOKIO_WORKER_THREADS=1||||$WC -O pooling-allocator=y --allow-precompiled /app/wt/{b}.cwasm
9|wt50-t1c-cowN|wt50|-e TOKIO_WORKER_THREADS=1||||$WC -O memory-init-cow=n --allow-precompiled /app/wt/{b}.cwasm
10|wt50-t1c-concN|wt50|-e TOKIO_WORKER_THREADS=1|$CW -W concurrency-support=n /app/wasm/\$b.wasm -o /tmp/cw/\$b.cwasm; done|||$WC -W concurrency-support=n --allow-precompiled /tmp/cw/{b}.cwasm
10|wt50-concN-only|wt50||$CW -W concurrency-support=n /app/wasm/\$b.wasm -o /tmp/cw/\$b.cwasm; done|||/usr/local/bin/wasmtime run -W concurrency-support=n --allow-precompiled /tmp/cw/{b}.cwasm
10|wt50-t1c-fixed2|wt50|-e TOKIO_WORKER_THREADS=1||||$WC --allow-precompiled /app/wt/{b}.cwasm
11|wt50-t1c-sigtrapN|wt50|-e TOKIO_WORKER_THREADS=1|$CW -O signals-based-traps=n /app/wasm/\$b.wasm -o /tmp/cw/\$b.cwasm; done|||$WC -O signals-based-traps=n --allow-precompiled /tmp/cw/{b}.cwasm
11|wt50-t1c-pool2|wt50|-e TOKIO_WORKER_THREADS=1||2,tak||$WC -O pooling-allocator=y --allow-precompiled /app/wt/{b}.cwasm
12|node-B-base|c|||||$N /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
12|node-A-noliftoff|c|||||$N --no-liftoff /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
12|node-A2-noliftoff-eager|c|||||$N --no-liftoff --no-wasm-lazy-compilation /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
13|node-D-dyntier-sync|c|||||/usr/local/bin/node --predictable --single-threaded-gc --wasm-sync-tier-up /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
13|node-E-dyntier-default|c|||||/usr/local/bin/node --predictable --single-threaded-gc /opt/wasm/run-node.mjs /app/wasm/{b}.wasm
13|node-A-rep2|c|||||$N --no-liftoff /opt/wasm/run-node.mjs /app/wasm/{b}.wasm"

image_of() { case "$1" in c) echo lang-lab-wasm:c;; wt26) echo lang-lab-wasm-runtime-wt26.0.1;; wt50) echo lang-lab-wasm-runtime-wt50.0.0;; *) echo "$1";; esac; }

run_row() {  # run_row <label> <image alias> <docker flags> <PRE> <reps,benches> <runner> <command>
  local reps="${REPS:-5}" bs="${BS:-tak fannkuch dijkstra}" script="$HERE/knob-run.sh"
  if [ -n "$5" ]; then reps="${REPS:-${5%%,*}}"; bs="${BS:-${5#*,}}"; fi
  [ "$6" = shim ] && script="$HERE/knob-shim.sh"
  # $7 is word-split on purpose: knob-run.sh joins its arguments back into the command template.
  PRE="$4" REPS="$reps" BS="$bs" "$script" "$(image_of "$2")" "$1" "$3" -- $7
}

selected() { [ -z "${ONLY:-}" ] && return 0; case " $ONLY " in *" $1 "*) return 0;; esac; return 1; }

prev=""
while IFS='|' read -r batch label img denv pre over runner cmd; do
  selected "$label" || continue
  if [ -n "$prev" ] && [ "$batch" != "$prev" ]; then wait; fi
  prev="$batch"
  echo ">> batch $batch: $label" >&2
  run_row "$label" "$img" "$denv" "$pre" "$over" "$runner" "$cmd" &
done <<EOF2
$CONFIGS
EOF2
wait
echo "JITTER DONE -> $RAWDIR/knobs-raw.log" >&2
