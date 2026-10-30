#!/usr/bin/env bash
# WebAssembly side study, runtime experiment (jitter): run knob.sh for ONE configuration.
#
#   knob-run.sh <image> <label> "<docker flags>" -- <cmd template with {b}>
#
# Starts one container of <image> with the docker flags (word-split: "-e K=V", "--cpuset-cpus=0"), pipes
# knob.sh into it, and APPENDS its RAW/SUM lines to $RAWDIR/knobs-raw.log; prints the label's last SUM lines.
# Environment: REPS (default 5) runs per size, BS (default "tak fannkuch dijkstra") benchmarks,
# PRE an optional shell snippet run in the container first (used to precompile a cwasm whose compile-time
# settings match a run flag, into /tmp/cw), RAWDIR (default $EXP_OUT/runtime/raw).
# jitter.sh calls this for every configuration; it is also usable by hand. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"; mkdir -p "$RAWDIR"
[ $# -ge 5 ] || { echo "usage: knob-run.sh <image> <label> \"<docker flags>\" -- <cmd template>" >&2; exit 2; }
img="$1"; label="$2"; denv="$3"; shift 3; [ "$1" = "--" ] && shift
docker run --rm -i $denv "$img" bash -c "cat > /tmp/knob.sh; ${PRE:-true}; bash /tmp/knob.sh '$label' ${REPS:-5} '${BS:-tak fannkuch dijkstra}' -- $*" \
  < "$HERE/knob.sh" >> "$RAWDIR/knobs-raw.log" || true
grep "^SUM $label " "$RAWDIR/knobs-raw.log" | tail -6 || true
