#!/bin/sh
# int64.sh <in.swift> <out.swift>: make a canonical Swift benchmark compute the same thing on wasm32.
#
# Swift's Int is the word size: 32 bits on wasm32, 64 on every native target the matrix uses. Eleven
# of the 18 benchmarks (see INT64_BENCHES in the Dockerfile) keep 64-bit LCG state and hash
# accumulators in plain Int, so unchanged they trap on overflow or print a wrong checksum on wasm32.
# The canonical sources are NOT edited; at build time the shim int64-shim.swift is inserted right after
# the `import Foundation` line, which makes Int, UInt and untyped integer literals 64-bit.
# On a 64-bit target the transform is nearly a no-op (identical on 9 of the 11, dijkstra +0.88%,
# sha256 +0.098%): the Dockerfile compiles the transformed sources natively
# too (column native-shim) and the lane measures it against the untransformed native build.
set -eu
[ $# -eq 2 ] || { echo "usage: int64.sh <in.swift> <out.swift>" >&2; exit 2; }
n="$(grep -n -m1 '^import Foundation$' "$1" | cut -d: -f1)"
[ -n "$n" ] || { echo "int64.sh: $1 has no 'import Foundation' line" >&2; exit 3; }
{ head -n "$n" "$1"; cat "$(dirname "$0")/int64-shim.swift"; tail -n +"$((n + 1))" "$1"; } > "$2"
