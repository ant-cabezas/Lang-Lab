#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: build lang-lab-wasm-runtime-sdk25wt26 (Dockerfile.sdk25wt26).
#
# Crosses the two older axes: the wasi-sdk 25 modules of lang-lab-wasm-runtime-sdk25 (build-sdk.sh 25 19.1.5)
# precompiled and run by wasmtime 26.0.1 (lang-lab-wasm-runtime-wt26.0.1, build-wt.sh). With the sdk25 on
# wasmtime 50 and sdk34 on wasmtime 26/50 cells it completes a 2x2 toolchain x runtime factorial.
# In the study run the modules were copied from the sdk25 build context; here they are copied out of the
# sdk25 image, the same files. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
WORK="${WORK:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work}"
C="$WORK/ctx-sdk25wt26"; rm -rf "$C"; mkdir -p "$C/w"
cid="$(docker create lang-lab-wasm-runtime-sdk25)"
trap 'docker rm "$cid" >/dev/null 2>&1 || true' EXIT
docker cp "$cid:/app/sdk25/wasm/." "$C/w-all"
cp "$C"/w-all/*.wasm "$C/w/"; rm -rf "$C/w-all"
docker build -q -f "$HERE/Dockerfile.sdk25wt26" -t lang-lab-wasm-runtime-sdk25wt26 "$C"
