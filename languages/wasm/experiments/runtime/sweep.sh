#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: one configuration over the 18 compute benchmarks.
#
#   sweep.sh <image> <tag> <outfile> -- <run template with {b}>
#
# Calls m.sh once per benchmark, P cells in parallel (default 3; the guest instruction count is
# contention-immune), and APPENDS one JSON line per benchmark to <outfile> (in completion order).
# RUNS, DENV and KIND pass through to m.sh. BENCHES overrides the benchmark list (smoke tests).
# message-ring is excluded: it needs threads, which wasm32-wasip1 lacks. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ $# -ge 4 ] || { echo "usage: sweep.sh <image> <tag> <outfile> -- <run template>" >&2; exit 2; }
img="$1"; tag="$2"; out="$3"; shift 3; [ "$1" = "--" ] && shift
B="bigint binary-trees blur dijkstra fannkuch gbdt gemm k-means k-nucleotide lz77 mandelbrot polymorphism reverse-complement sha256 sort-search tak viterbi vm"
mkdir -p "$(dirname "$out")"
printf '%s\n' ${BENCHES:-$B} | xargs -P "${P:-3}" -I{} "$HERE/m.sh" "$img" "$tag" {} -- "$@" >> "$out"
