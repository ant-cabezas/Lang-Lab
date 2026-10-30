# WebAssembly side study, Go column. Build context is the repo root:
#   docker build -f languages/wasm/go/Dockerfile -t lang-lab-wasm:go .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Per benchmark, from the canonical languages/go/<b>.go (never edited, no transform needed):
#   /app/native/<b>       go build, GOOS=linux, the matrix build line (control: must count like lang-lab-go)
#   /app/wasm/<b>.wasm    go build, GOOS=wasip1 GOARCH=wasm, same gc compiler, same flags (none)
#   /app/wasm/<b>.cwasm   the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# Toolchain: the official Go tarball, pinned by version and sha256 (the matrix image golang:1.24.4-bookworm
# ships the same release), so native vs wasm differ only in GOOS/GOARCH. The GC stays on, as in the matrix.
# GOFLAGS=-buildvcs=false is the only flag the matrix build line does not carry: /app/src is not a VCS
# checkout in either image, so it is a no-op (proved by /app/native/<b> counting like lang-lab-go).
# The real versions are in /app/TOOLCHAIN (LANG_VERSION is just the lane name, as in the C lane).
# message-ring and the -par variants are excluded: goroutine/parallel benchmarks, not compute axes.
FROM lang-lab-wasm-base
ARG GO_VERSION=1.24.4
ARG GO_SHA256=d5501ee5aca0f258d5fe9bfaed401958445014495dc115f202d43d5210b45241
ARG WASMTIME_COMPILE_FLAGS=""
RUN set -eu; \
    curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-arm64.tar.gz" -o /tmp/go.tgz; \
    echo "${GO_SHA256}  /tmp/go.tgz" | sha256sum -c -; \
    tar -C /usr/local -xzf /tmp/go.tgz; rm /tmp/go.tgz
ENV PATH=/usr/local/go/bin:$PATH GOFLAGS=-buildvcs=false GOCACHE=/tmp/gocache
COPY languages/go/*.go /app/src/
COPY benchmarks /app/benchmarks
RUN set -eu; mkdir -p native wasm; \
    for f in src/*.go; do b=$(basename "$f" .go); \
      case "$b" in *-par|message-ring) rm -f "$f"; continue;; esac; \
      go build -o "native/$b" "$f"; \
      GOOS=wasip1 GOARCH=wasm go build -o "wasm/$b.wasm" "$f"; \
      wasmtime compile $WASMTIME_COMPILE_FLAGS "wasm/$b.wasm" -o "wasm/$b.cwasm"; \
    done; rm -rf /tmp/gocache; \
    { echo "go: $(go version)"; echo "wasmtime: $(wasmtime --version)"; echo "node: $(node --version)"; \
      echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN
ENV LANG_VERSION=go
