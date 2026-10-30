#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: build the wasmtime version swap images.
#
# One image per wasmtime major in the sweep (the latest patch release of every fourth major, 26 to 50),
# tagged lang-lab-wasm-runtime-wt<version>, from Dockerfile.wt on top of lang-lab-wasm:c. Each image
# precompiles the same wasi-sdk 34 modules with its own wasmtime into /app/wt/<b>.cwasm. Consumed by
# task1.sh (version sweep), jitter.sh (wt26 and wt50 rows) and build-sdk25wt26.sh (wt26).
# The release tarballs are pinned by sha256 (the asset digests GitHub publishes for each release).
# 50.0.0 is the study's own wasmtime (languages/wasm/Dockerfile.base): its /app/wt cwasm files are
# byte-identical to lang-lab-wasm:c's /app/wasm ones.
#
#   languages/wasm/experiments/runtime/build-wt.sh              # all seven
#   VERSIONS="26.0.1 50.0.0" languages/wasm/experiments/runtime/build-wt.sh
#
# Needs lang-lab-wasm:c (languages/wasm/c/Dockerfile). Images are built sequentially. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
PINS="26.0.1 8dbb0445ce71b673a5b6021e1d406b9381748b8338224b6f7a569c6cdca60310
30.0.2 197c5c8c4debc3394ba1e5b1193bfd0acb64a97d1dbcbe52d15192d12dc796ee
34.0.2 c7d6f6a2d15bf2310b0aea8b57dd392c091aa9830f57408cbea86affcc132756
38.0.4 7c57fdeac10e64d5f9bd3873139577fbef2949379411f0308dc5f1ef99d3f63b
42.0.2 9d55dbe5cec028692ea8dd5ceaf0250541e9b7cc50a9f22586bf3e130034ad60
46.0.3 99aa698281ce7c18cb174899df86296d730bf39d6e4826ae6e56a773e0cbe53f
50.0.0 10f9ad1f8539d2e04e041cc622de6a270109ab1e43a6be1f69843c2082166832"
VERSIONS="${VERSIONS:-$(printf '%s\n' "$PINS" | cut -d' ' -f1 | tr '\n' ' ')}"
fail=0
for v in $VERSIONS; do
  sha="$(printf '%s\n' "$PINS" | awk -v v="$v" '$1 == v {print $2}')"
  [ -n "$sha" ] || { echo "build-wt.sh: no sha256 pin for wasmtime $v" >&2; exit 2; }
  echo "== wasmtime $v" >&2
  # The context is this directory; Dockerfile.wt copies nothing from it.
  docker build -q -f "$HERE/Dockerfile.wt" --build-arg "WT_VERSION=$v" --build-arg "WT_SHA256=$sha" \
    -t "lang-lab-wasm-runtime-wt$v" "$HERE" || { echo "BUILD FAIL $v" >&2; fail=1; }
done
exit $fail
