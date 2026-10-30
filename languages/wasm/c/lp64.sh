#!/usr/bin/env bash
# lp64.sh <in.c> <out.c>: make a canonical C benchmark source compute the same thing on wasm32.
#
# The C sources assume LP64 (long is 64-bit), which holds on every native target the matrix uses.
# wasm32 is ILP32: long is 32-bit, so 13 of the 18 benchmarks silently print a wrong checksum when
# compiled unchanged. The canonical sources are NOT edited (they are the matrix baseline); instead
# this transform is applied at build time, to the wasm build only:
#   1. `#define long long long` inserted after the last #include, so system headers are untouched
#      and every `long` / `unsigned long` in the benchmark becomes 64-bit;
#   2. printf length modifiers %ld/%lu/%li become %lld/%llu/%lli to match;
#   3. integer literal suffixes L/UL become LL/ULL (e.g. `1L << 62` would otherwise be a 32-bit shift).
# On an LP64 target the transform is a no-op: languages/wasm/c/Dockerfile compiles the transformed
# sources natively too (column clang-lp64). The generated machine code is identical except for the
# printf format string itself, so the differentials match to within a few instructions (glibc's printf
# parses one more character of "%lld"). Fails if a source already uses `long long` (the define would
# then nest).
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: lp64.sh <in.c> <out.c>" >&2; exit 2; }
in="$1"; out="$2"
if grep -q 'long[[:space:]]\+long' "$in"; then
  echo "lp64.sh: $in already uses 'long long'; the transform would nest" >&2; exit 3
fi
last_include="$(grep -n '^#include' "$in" | tail -1 | cut -d: -f1)"
[ -n "$last_include" ] || { echo "lp64.sh: $in has no #include line" >&2; exit 3; }
awk -v L="$last_include" '
  { gsub(/%ld/, "%lld"); gsub(/%lu/, "%llu"); gsub(/%li/, "%lli"); print }
  NR == L { print "#define long long long" }
' "$in" | sed -E 's/\b(0[xX][0-9a-fA-F]+|[0-9]+)([uU]?)[lL]\b/\1\2LL/g' > "$out"
