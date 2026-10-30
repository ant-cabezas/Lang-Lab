#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: build lang-lab-wasm-runtime-sdk34mvp.
#
# The -mcpu=mvp variant of the study's own toolchain (wasi-sdk 34, already in lang-lab-wasm:c): compiles
# the 18 lp64 sources with -O2 -mcpu=mvp -Wl,-z,stack-size=8388608 in a throwaway container, precompiles
# each with wasmtime 50.0.0, and builds a thin image adding /app/sdk34mvp/wasm-mvp/<b>.{wasm,cwasm}.
# In the study run this was an inline command, not a script; the commands are the same.
# -mcpu=mvp only affects the benchmark code: the prebuilt wasi-libc keeps its target features.
# Needs lang-lab-wasm:c. Under a minute. Bash 3.2 compatible.
set -euo pipefail
WORK="${WORK:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work}"
c=lang-lab-wasm-runtime-sdkbuild34
docker rm -f "$c" >/dev/null 2>&1 || true
docker run -d --name "$c" lang-lab-wasm:c sleep infinity >/dev/null
trap 'docker rm -f "$c" >/dev/null 2>&1 || true' EXIT
docker exec "$c" bash -c 'set -e; mkdir -p /out/sdk34mvp/wasm-mvp; cd /app
  for f in src/*.c; do b=$(basename $f .c)
    $WASI_SDK_PATH/bin/clang -O2 -mcpu=mvp -Wl,-z,stack-size=8388608 lp64/$b.c -o /out/sdk34mvp/wasm-mvp/$b.wasm -lm
    wasmtime compile /out/sdk34mvp/wasm-mvp/$b.wasm -o /out/sdk34mvp/wasm-mvp/$b.cwasm
  done
  ls /out/sdk34mvp/wasm-mvp | wc -l
  for b in fannkuch tak; do cmp -s /out/sdk34mvp/wasm-mvp/$b.wasm /app/wasm/$b.wasm && echo "$b identical to default" || echo "$b differs from default"; done'
T="$WORK/ctx-thin34mvp"; rm -rf "$T"; mkdir -p "$T"
docker exec "$c" tar -C /out -cf - sdk34mvp | tar -C "$T" -xf -
printf 'FROM lang-lab-wasm:c\nCOPY sdk34mvp /app/sdk34mvp\n' > "$T/Dockerfile"
docker build -q -t lang-lab-wasm-runtime-sdk34mvp "$T"
