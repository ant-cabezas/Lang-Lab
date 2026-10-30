#!/usr/bin/env bash
# WebAssembly side study, codegen experiment: one (image, variant) over the 18 compute benchmarks.
#
#   run-batch.sh <image> <variant> <outfile>
#
# Runs cell.sh in <image> once per benchmark, PAR cells in parallel (default 3), and APPENDS one line per
# benchmark to <outfile>: "<image> <variant> <bench> <measure.sh JSON line>" (the JSON is missing when the
# cell failed; ingest.py and summarize.py skip such lines). Each cell's stderr goes to
# $LOGDIR/<image>-<variant>-<bench>.err (default: a log/ directory next to <outfile>).
# BENCHES overrides the benchmark list. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
[ $# -eq 3 ] || { echo "usage: run-batch.sh <image> <variant> <outfile>" >&2; exit 2; }
img="$1"; v="$2"; out="$3"
LOGDIR="${LOGDIR:-$(cd "$(dirname "$out")" && pwd)/../log}"; mkdir -p "$LOGDIR"
benches="${BENCHES:-bigint binary-trees blur dijkstra fannkuch gbdt gemm k-means k-nucleotide lz77 mandelbrot polymorphism reverse-complement sha256 sort-search tak viterbi vm}"
printf '%s\n' $benches | xargs -P "${PAR:-3}" -I{} bash -c '
  r=$(docker run --rm -i "$0" bash -s -- "$1" {} < "$2/cell.sh" 2>"$3/$(echo $0|tr :/ __)-$(echo $1|tr / _)-{}.err" | tail -1)
  echo "$0 $1 {} $r"' "$img" "$v" "$HERE" "$LOGDIR" >> "$out"
