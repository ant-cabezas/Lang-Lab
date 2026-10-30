#!/usr/bin/env bash
# WebAssembly side study, codegen experiment: build the four compile-configuration images (Dockerfile).
#
#   lang-lab-wasm-codegen-o2       native -O2, wasm -O2, plus every wasmtime knob cwasm (KNOBS=1)
#   lang-lab-wasm-codegen-o3       native -O3, wasm -O3
#   lang-lab-wasm-codegen-wasmopt  -O2, then Binaryen wasm-opt -O3 on the module (Binaryen version_133, sha256-pinned)
#   lang-lab-wasm-codegen-simd     wasm -O2 -msimd128 (native stays -O2)
# Every image: clang 23.1.0 (official LLVM release) native, wasi-sdk 34 wasm, wasmtime 50.0.0 compile.
#
#   languages/wasm/experiments/codegen/build.sh            # all four
#   CONFIGS=o2 languages/wasm/experiments/codegen/build.sh
#
# Needs lang-lab-wasm-base (languages/wasm/Dockerfile.base). A few minutes per image. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
cd "$HERE/../../../.."   # the build context is the repo root
F=languages/wasm/experiments/codegen/Dockerfile
for cfg in ${CONFIGS:-o2 o3 wasmopt simd}; do
  echo "== lang-lab-wasm-codegen-$cfg" >&2
  case "$cfg" in
    o2)      docker build -q -f "$F" --build-arg KNOBS=1 -t lang-lab-wasm-codegen-o2 . ;;
    o3)      docker build -q -f "$F" --build-arg NATIVE_CFLAGS=-O3 --build-arg WASM_CFLAGS=-O3 -t lang-lab-wasm-codegen-o3 . ;;
    wasmopt) docker build -q -f "$F" --build-arg WASM_OPT=-O3 -t lang-lab-wasm-codegen-wasmopt . ;;
    simd)    docker build -q -f "$F" --build-arg "WASM_CFLAGS=-O2 -msimd128" -t lang-lab-wasm-codegen-simd . ;;
    *) echo "build.sh: unknown configuration $cfg" >&2; exit 2 ;;
  esac
  docker run --rm "lang-lab-wasm-codegen-$cfg" cat /app/TOOLCHAIN >&2
done
