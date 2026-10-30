# WebAssembly side study, Rust column. Build context is the repo root:
#   docker build -f languages/wasm/rust/Dockerfile -t lang-lab-wasm:rust .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Per benchmark, from the canonical languages/rust/<b>.rs (never edited, no source transform):
#   /app/wasm/<b>.wasm    rustc 1.88.0 -O, wasm32-wasip1 (the same rustc and the same flag as the matrix build)
#   /app/wasm/<b>.cwasm   the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# The native column is the matrix image lang-lab-rust (languages/rust/Dockerfile), not rebuilt here.
# Toolchain: the rust:1.88.0-slim-bookworm image (the matrix base) as builder, plus the wasm32-wasip1 std
# component fetched from static.rust-lang.org and pinned by sha256. rustc is the same binary (same bundled
# LLVM 20.1.5) for both targets. Only the link step differs: -C link-arg=-zstack-size sets the wasm shadow
# stack to 8 MiB (wasm default is 1 MiB; native main thread has 8 MiB), the analogue of the C lane's flag.
# Codegen flags: the matrix uses plain `rustc -O` (opt-level=2, no lto, default codegen-units, panic=unwind,
# no target-cpu), and the wasm build uses the same `-O`. wasm32-wasip1 has no target-cpu to match; its
# default feature set in 1.88 is the rustc baseline (see TOOLCHAIN for the exact list). Its default panic
# strategy is abort, not unwind; that asymmetry is kept and listed in lane.json.
# message-ring and the -par variants are excluded: they need threads, which wasm32-wasip1 lacks.
ARG RUST_VERSION=1.88.0
ARG RUST_IMAGE_DIGEST=sha256:38bc5a86d998772d4aec2348656ed21438d20fcdce2795b56ca434cf21430d89
ARG WASM_STD_SHA256=d8b9068daa681ad309f628254d0019b13f51690769d7e26d22469d97bde74248

FROM lang-lab-wasm-base AS fetch
ARG RUST_VERSION
ARG WASM_STD_SHA256
RUN curl -fsSL -o /rust-std.tar.xz "https://static.rust-lang.org/dist/rust-std-${RUST_VERSION}-wasm32-wasip1.tar.xz" \
 && echo "${WASM_STD_SHA256}  /rust-std.tar.xz" | sha256sum -c - \
 && mkdir /rust-std && tar -xJf /rust-std.tar.xz -C /rust-std --strip-components=1

FROM rust:${RUST_VERSION}-slim-bookworm@${RUST_IMAGE_DIGEST} AS build
ARG WASM_RUSTFLAGS="-O"
ARG WASM_STACK=8388608
COPY --from=fetch /rust-std /rust-std
RUN cd /rust-std && ./install.sh --prefix="$(rustc --print sysroot)" --components=rust-std-wasm32-wasip1 --disable-ldconfig \
 && rustc --print target-list | grep -qx wasm32-wasip1
COPY languages/rust/*.rs /src/
RUN set -eu; mkdir -p /out; \
    for f in /src/*.rs; do b=$(basename "$f" .rs); \
      case "$b" in *-par|message-ring) continue;; esac; \
      rustc $WASM_RUSTFLAGS --target wasm32-wasip1 -C link-arg=-zstack-size=$WASM_STACK "$f" -o "/out/$b.wasm"; \
    done; \
    { rustc -vV | sed -n 's/^release: /rustc: /p;s/^LLVM version: /llvm: /p'; \
      echo "wasm-rustflags: $WASM_RUSTFLAGS -C link-arg=-zstack-size=$WASM_STACK"; \
      echo "wasm-default-features: $(rustc --target wasm32-wasip1 --print cfg | grep target_feature | tr '\n' ' ')"; } > /out/TOOLCHAIN.part

FROM lang-lab-wasm-base
ARG WASM_STD_SHA256
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /out /app/wasm
COPY benchmarks /app/benchmarks
RUN set -eu; cd /app/wasm; \
    for w in *.wasm; do wasmtime compile $WASMTIME_COMPILE_FLAGS "$w" -o "${w%.wasm}.cwasm"; done; \
    { cat TOOLCHAIN.part; echo "wasm-std-component-sha256: $WASM_STD_SHA256"; \
      echo "wasmtime: $(wasmtime --version)"; echo "node: $(node --version)"; \
      echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN; rm TOOLCHAIN.part
ENV LANG_VERSION=rust
