# WebAssembly side study, codegen experiment: one image per compile configuration.
# Build context is the repo root (build.sh does this for the four configurations):
#   docker build -f languages/wasm/experiments/codegen/Dockerfile --build-arg NATIVE_CFLAGS=... \
#     --build-arg WASM_CFLAGS=... [--build-arg WASM_OPT=-O3] [--build-arg KNOBS=1] -t lang-lab-wasm-codegen-<cfg> .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
# Per benchmark:
#   /app/native/<b>      /opt/llvm/bin/clang $NATIVE_CFLAGS on the canonical languages/c/<b>.c
#   /app/wasm/<b>.wasm   wasi-sdk clang $WASM_CFLAGS on the lp64.sh-transformed source [then wasm-opt $WASM_OPT]
#   /app/wasm/<b>.cwasm  wasmtime compile (default settings)
#   /app/knob/<k>/<b>.cwasm  the same .wasm compiled with wasmtime knob set <k> (only when KNOBS=1)
FROM lang-lab-wasm-base AS binaryen
ARG BINARYEN_VERSION=133
ARG BINARYEN_SHA256=89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8
RUN set -eux; cd /tmp; \
    u="https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-aarch64-linux.tar.gz"; \
    curl -fsSLo binaryen.tgz "$u"; curl -fsSLo binaryen.tgz.sha256 "$u.sha256"; \
    echo "${BINARYEN_SHA256}  binaryen.tgz" | sha256sum -c -; \
    grep -q "${BINARYEN_SHA256}" binaryen.tgz.sha256; \
    mkdir /opt/binaryen && tar xzf binaryen.tgz -C /opt/binaryen --strip-components=1; \
    /opt/binaryen/bin/wasm-opt --version

FROM lang-lab-wasm-base
ARG NATIVE_CFLAGS="-O2"
ARG WASM_CFLAGS="-O2"
ARG WASM_OPT=""
ARG WASM_STACK=8388608
ARG KNOBS=0
# Binaryen lives off PATH so the wasi-sdk clang driver never auto-runs wasm-opt.
COPY --from=binaryen /opt/binaryen /opt/binaryen
COPY languages/c/*.c /app/src/
COPY benchmarks /app/benchmarks
RUN set -eu; mkdir -p native wasm lp64; \
    command -v wasm-opt && { echo "wasm-opt on PATH" >&2; exit 1; } || true; \
    for f in src/*.c; do b=$(basename "$f" .c); \
      case "$b" in *-par|message-ring) rm -f "$f"; continue;; esac; \
      /opt/wasm/lp64.sh "$f" "lp64/$b.c"; \
      /opt/llvm/bin/clang $NATIVE_CFLAGS "$f" -o "native/$b" -lm; \
      "$WASI_SDK_PATH/bin/clang" $WASM_CFLAGS -Wl,-z,stack-size=$WASM_STACK "lp64/$b.c" -o "wasm/$b.wasm" -lm; \
      if [ -n "$WASM_OPT" ]; then mv "wasm/$b.wasm" "wasm/$b.pre.wasm"; \
        /opt/binaryen/bin/wasm-opt $WASM_OPT "wasm/$b.pre.wasm" -o "wasm/$b.wasm"; fi; \
      wasmtime compile "wasm/$b.wasm" -o "wasm/$b.cwasm"; \
      if [ "$KNOBS" = 1 ]; then \
        for k in bounds:"-O memory-reservation=0 -O memory-guard-size=0" \
                 nosig:"-O signals-based-traps=n" \
                 eagertable:"-O table-lazy-init=n" \
                 copt0:"-O opt-level=0" copt1:"-O opt-level=1" \
                 inline:"-C inlining=y"; do \
          n="${k%%:*}"; fl="${k#*:}"; mkdir -p "knob/$n"; echo "$fl" > "knob/$n/FLAGS"; \
          wasmtime compile $fl "wasm/$b.wasm" -o "knob/$n/$b.cwasm"; \
        done; fi; \
    done; \
    { echo "native: $(/opt/llvm/bin/clang --version | head -1) $NATIVE_CFLAGS"; \
      echo "wasi-sdk: $("$WASI_SDK_PATH/bin/clang" --version | head -1) $WASM_CFLAGS"; \
      echo "wasm-opt: $(/opt/binaryen/bin/wasm-opt --version) ${WASM_OPT:-not applied}"; \
      echo "wasmtime: $(wasmtime --version)"; echo "knobs: $KNOBS"; } > /app/TOOLCHAIN
