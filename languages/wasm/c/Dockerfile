# WebAssembly side study, C column. Build context is the repo root:
#   docker build -f languages/wasm/c/Dockerfile -t lang-lab-wasm:c .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Per benchmark, from the canonical languages/c/<b>.c (never edited):
#   /app/gcc/<b>          gcc -O2, the matrix C baseline (same gcc:14 image as languages/c)
#   /app/clang/<b>        clang -O2 native, the same LLVM release as wasi-sdk: the same-compiler control
#   /app/clang-lp64/<b>   the same, on the lp64.sh-transformed source (same machine code bar the printf format string)
#   /app/wasm/<b>.wasm    wasi-sdk clang -O2 on the transformed source, wasm32-wasip1
#   /app/wasm/<b>.cwasm   the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# message-ring and the -par variants are excluded: they need threads, which wasm32-wasip1 lacks.
FROM lang-lab-wasm-base
ARG WASM_CFLAGS="-O2"
ARG WASM_STACK=8388608
ARG WASMTIME_COMPILE_FLAGS=""
COPY languages/c/*.c /app/src/
COPY benchmarks /app/benchmarks
RUN set -eu; mkdir -p gcc clang clang-lp64 wasm lp64; \
    for f in src/*.c; do b=$(basename "$f" .c); \
      case "$b" in *-par|message-ring) rm -f "$f"; continue;; esac; \
      /opt/wasm/lp64.sh "$f" "lp64/$b.c"; \
      gcc -O2 "$f" -o "gcc/$b" -lm; \
      /opt/llvm/bin/clang -O2 "$f" -o "clang/$b" -lm; \
      /opt/llvm/bin/clang -O2 "lp64/$b.c" -o "clang-lp64/$b" -lm; \
      "$WASI_SDK_PATH/bin/clang" $WASM_CFLAGS -Wl,-z,stack-size=$WASM_STACK "lp64/$b.c" -o "wasm/$b.wasm" -lm; \
      wasmtime compile $WASMTIME_COMPILE_FLAGS "wasm/$b.wasm" -o "wasm/$b.cwasm"; \
    done; \
    { echo "gcc: $(gcc --version | head -1)"; echo "clang: $(/opt/llvm/bin/clang --version | head -1)"; \
      echo "wasi-sdk: $("$WASI_SDK_PATH/bin/clang" --version | head -1)"; echo "wasmtime: $(wasmtime --version)"; \
      echo "node: $(node --version)"; echo "wasm-cflags: $WASM_CFLAGS"; echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN
ENV LANG_VERSION=c
