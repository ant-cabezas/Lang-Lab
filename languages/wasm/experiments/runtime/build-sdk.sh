#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: build one wasi-sdk sweep image.
#
#   build-sdk.sh <wasi-sdk major> <llvm version>      # the study ran: 25 19.1.5, then 30 21.1.4
#
# Inside a throwaway container of lang-lab-wasm:c, compiles the 18 benchmarks with that wasi-sdk (wasm)
# and with the official LLVM release of the same clang version (the native same-compiler control), from
# the same sources lang-lab-wasm:c uses (/app/src = languages/c, /app/lp64 = the lp64.sh-transformed
# copies), with the study's flags (-O2; wasm adds -Wl,-z,stack-size=8388608):
#   /app/sdk<v>/clang/<b>        native control, canonical source
#   /app/sdk<v>/clang-lp64/<b>   native control, lp64 source (must count like clang/<b>: the lp64 no-op check)
#   /app/sdk<v>/wasm/<b>.wasm    wasi-sdk <v>, plus <b>.cwasm precompiled by the image's wasmtime 50.0.0
#   /app/sdk<v>/wasm-mvp/<b>.*   the same with -mcpu=mvp (benchmark code only; the prebuilt libc keeps its features)
# then builds the thin image lang-lab-wasm-runtime-sdk<v> (FROM lang-lab-wasm:c, COPY sdk<v>).
# NOTE: the wasm-mvp step was added after the sdk 25 image had been built, so the measured sdk25 image had
# no wasm-mvp directory; sdk25 mvp was never measured, the extra directory is harmless.
#
# Needs fetch-sdk.sh to have filled $WORK/ctx-sdk (default ${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work).
# About 2 minutes per image. Bash 3.2 compatible.
set -euo pipefail
[ $# -eq 2 ] || { echo "usage: build-sdk.sh <wasi-sdk major> <llvm version>" >&2; exit 2; }
WORK="${WORK:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work}"
v="$1"; lv="$2"; c="lang-lab-wasm-runtime-sdkbuild$v"
[ -d "$WORK/ctx-sdk/wasi-sdk-$v" ] && [ -d "$WORK/ctx-sdk/llvm-$lv" ] || { echo "build-sdk.sh: run fetch-sdk.sh first" >&2; exit 2; }
docker rm -f "$c" >/dev/null 2>&1 || true
docker run -d --name "$c" lang-lab-wasm:c sleep infinity >/dev/null
trap 'docker rm -f "$c" >/dev/null 2>&1 || true' EXIT
tar -C "$WORK/ctx-sdk" -cf - "wasi-sdk-$v" "llvm-$lv" | docker exec -i "$c" tar -C /opt -xf -
docker exec -i "$c" bash -s "$v" "$lv" <<'IN'
set -eu; v=$1; lv=$2; S=/opt/wasi-sdk-$v; L=/opt/llvm-$lv; o=/out/sdk$v; mkdir -p $o/wasm $o/wasm-mvp $o/clang $o/clang-lp64
cd /app
for f in src/*.c; do b=$(basename $f .c)
  $L/bin/clang -O2 $f -o $o/clang/$b -lm
  $L/bin/clang -O2 lp64/$b.c -o $o/clang-lp64/$b -lm
  $S/bin/clang -O2 -Wl,-z,stack-size=8388608 lp64/$b.c -o $o/wasm/$b.wasm -lm
  wasmtime compile $o/wasm/$b.wasm -o $o/wasm/$b.cwasm
  $S/bin/clang -O2 -mcpu=mvp -Wl,-z,stack-size=8388608 lp64/$b.c -o $o/wasm-mvp/$b.wasm -lm
  wasmtime compile $o/wasm-mvp/$b.wasm -o $o/wasm-mvp/$b.cwasm
done
{ echo "wasi-sdk: $($S/bin/clang --version | head -1)"; echo "native-clang: $($L/bin/clang --version | head -1)"; echo "wasmtime: $(wasmtime --version)"; cat $S/VERSION; } > $o/TOOLCHAIN
cat $o/TOOLCHAIN; ls $o/wasm | wc -l
IN
T="$WORK/ctx-thin$v"; rm -rf "$T"; mkdir -p "$T"
docker exec "$c" tar -C /out -cf - "sdk$v" | tar -C "$T" -xf -
printf 'FROM lang-lab-wasm:c\nCOPY sdk%s /app/sdk%s\n' "$v" "$v" > "$T/Dockerfile"
docker build -q -t "lang-lab-wasm-runtime-sdk$v" "$T"
