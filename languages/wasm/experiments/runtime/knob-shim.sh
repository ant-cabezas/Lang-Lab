#!/usr/bin/env bash
# WebAssembly side study, runtime experiment (jitter): knob-run.sh with a deterministic getrandom().
#
#   knob-shim.sh <image> <label> "<docker flags>" -- <cmd template with {b}>
#
# Diagnostic only: tests whether random hash seeds in the runtime cause the residual per-run jitter.
# Builds fixrand.c (a getrandom() replacement driven by a fixed LCG) into /tmp/fixrand.so inside the
# container and makes knob.sh start qemu with -E LD_PRELOAD=/tmp/fixrand.so (qemu's guest environment
# option), so the preload applies to the guest, not to qemu. Same environment and output as knob-run.sh. Result in the study: the jitter stayed.
# Bash 3.2 compatible (the in-container part needs csplit and gcc, both in lang-lab-wasm images).
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
RAWDIR="${RAWDIR:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/runtime/raw}"; mkdir -p "$RAWDIR"
[ $# -ge 5 ] || { echo "usage: knob-shim.sh <image> <label> \"<docker flags>\" -- <cmd template>" >&2; exit 2; }
img="$1"; label="$2"; denv="$3"; shift 3; [ "$1" = "--" ] && shift
{ cat "$HERE/fixrand.c"; echo '//@@SPLIT@@'; cat "$HERE/knob.sh"; } | docker run --rm -i $denv "$img" bash -c "cat > /tmp/all; csplit -s -f /tmp/p /tmp/all '/^\/\/@@SPLIT@@/'; mv /tmp/p00 /tmp/fixrand.c; tail -n +2 /tmp/p01 > /tmp/knob.sh; gcc -O2 -shared -fPIC /tmp/fixrand.c -o /tmp/fixrand.so; sed -i 's|/opt/qi/qemu-aarch64 -plugin|/opt/qi/qemu-aarch64 -E LD_PRELOAD=/tmp/fixrand.so -plugin|' /tmp/knob.sh; bash /tmp/knob.sh '$label' ${REPS:-5} '${BS:-tak fannkuch dijkstra}' -- $*" \
  >> "$RAWDIR/knobs-raw.log" || true
grep "^SUM $label " "$RAWDIR/knobs-raw.log" | tail -6 || true
