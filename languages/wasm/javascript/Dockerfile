# WebAssembly side study, JavaScript column (QuickJS-ng, NOT Node/V8). Build context is the repo root:
#   docker build -f languages/wasm/javascript/Dockerfile -t lang-lab-wasm:javascript .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# V8 cannot be compiled to wasm, so this lane measures JavaScript as QuickJS-ng 0.17.0, an interpreter
# with no JIT, built twice from the same source tarball with the same CMake configuration:
#   /app/native/qjs     native aarch64, official LLVM 23.1.0 clang (the same-compiler control)
#   /app/wasm/qjs.wasm  wasm32-wasip1, wasi-sdk 34 clang 23.1.0
#   /app/wasm/qjs.cwasm the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# The result is NOT comparable to the matrix Node/V8 JavaScript cell (a JIT).
#
# Identical build options on both sides (the only per-target differences come from QuickJS's own CMake
# logic: the WASI branch adds a 2 MiB stack and the wasi-emulated-{process-clocks,signal} libs, the
# native branch links pthread):
#   CMAKE_BUILD_TYPE=Release, CMAKE_C_FLAGS_RELEASE="-O2 -DNDEBUG"  (same -O level as the C column)
#   QJS_BUILD_LIBC=ON               std/os modules compiled into libqjs (quickjs-libc.c), same on both
#   QJS_BUILD_CLI_WITH_MIMALLOC=OFF, QJS_BUILD_CLI_WITH_STATIC_MIMALLOC=OFF  (system allocator)
#   QJS_BUILD_CLI_STATIC=OFF, BUILD_SHARED_LIBS=OFF, QJS_DISABLE_PARSER=OFF  (defaults, stated for the record)
#   QJS_ENABLE_ASAN/MSAN/TSAN/UBSAN/GC_STRESS=OFF  (defaults)
#   QJS_WASI_REACTOR=OFF            command module with _start (the qjs CLI)
# GC settings: the qjs CLI's defaults on both sides (refcounting plus cycle collector, no memory
# limit flags, no -m/-s/--stack-size arguments).
#
# The canonical languages/javascript/<b>.js read process.argv (Node). The one build-time transform
# below inserts, right after the first line (the "use strict" directive, kept first so strictness is
# unchanged), `globalThis.process = { argv: ["qjs", ...scriptArgs] };` and writes /app/js/<b>.js,
# which BOTH columns run, so the prelude cancels between columns.
# Node-only APIs found in the 18 sources: process.argv only. console.log exists in QuickJS. No require,
# Buffer, BigInt, performance, timers or imports are used. message-ring and the -par variants are
# excluded (they need event-loop concurrency / threads).
ARG QJS_VERSION=0.17.0
ARG QJS_SHA256=559bc4c420475e55c7ab4510adbc562f55d7524d75e8e89d79ce4bb02f5687d9
ARG QJS_CFLAGS="-O2 -DNDEBUG"
ARG WASMTIME_COMPILE_FLAGS=""

FROM lang-lab-wasm-base AS build
ARG QJS_VERSION
ARG QJS_SHA256
ARG QJS_CFLAGS
RUN apt-get update -qq && apt-get install -y -qq --no-install-recommends cmake >/dev/null && rm -rf /var/lib/apt/lists/*
RUN set -eux; cd /tmp; \
    curl -fsSLo q.tgz "https://github.com/quickjs-ng/quickjs/archive/refs/tags/v${QJS_VERSION}.tar.gz"; \
    echo "${QJS_SHA256}  q.tgz" | sha256sum -c -; \
    mkdir /tmp/qjs-src && tar xzf q.tgz -C /tmp/qjs-src --strip-components=1
RUN set -eux; \
    COMMON="-DCMAKE_BUILD_TYPE=Release -DCMAKE_C_FLAGS_RELEASE=\"${QJS_CFLAGS}\" -DQJS_BUILD_LIBC=ON \
      -DQJS_BUILD_CLI_WITH_MIMALLOC=OFF -DQJS_BUILD_CLI_WITH_STATIC_MIMALLOC=OFF -DQJS_BUILD_CLI_STATIC=OFF \
      -DBUILD_SHARED_LIBS=OFF -DQJS_DISABLE_PARSER=OFF -DQJS_BUILD_EXAMPLES=OFF -DQJS_ENABLE_INSTALL=OFF \
      -DQJS_WASI_REACTOR=OFF"; \
    eval cmake -S /tmp/qjs-src -B /tmp/b-native $COMMON -DCMAKE_C_COMPILER=/opt/llvm/bin/clang; \
    cmake --build /tmp/b-native --target qjs_exe -j4; \
    eval cmake -S /tmp/qjs-src -B /tmp/b-wasm $COMMON \
      -DCMAKE_TOOLCHAIN_FILE=/opt/wasi-sdk/share/cmake/wasi-sdk-p1.cmake -DWASI_SDK_PREFIX=/opt/wasi-sdk; \
    cmake --build /tmp/b-wasm --target qjs_exe -j4; \
    mkdir -p /out; cp /tmp/b-native/qjs /out/qjs-native; cp /tmp/b-wasm/qjs /out/qjs.wasm; ls -l /out; \
    cmake --version | head -1 > /out/cmake-version

FROM lang-lab-wasm-base
ARG QJS_VERSION
ARG QJS_CFLAGS
ARG WASMTIME_COMPILE_FLAGS
COPY --from=build /out /tmp/out
COPY languages/javascript/*.js /app/src/
RUN set -eu; mkdir -p native wasm js; \
    mv /tmp/out/qjs-native native/qjs; mv /tmp/out/qjs.wasm wasm/qjs.wasm; \
    for f in src/*.js; do b=$(basename "$f" .js); \
      case "$b" in *-par|message-ring) continue;; esac; \
      { head -1 "$f"; echo 'globalThis.process = { argv: ["qjs", ...scriptArgs] };'; tail -n +2 "$f"; } > "js/$b.js"; \
    done; \
    wasmtime compile $WASMTIME_COMPILE_FLAGS wasm/qjs.wasm -o wasm/qjs.cwasm; \
    { echo "quickjs-ng: $QJS_VERSION (built from source, tarball sha256 pinned)"; \
      echo "native-cc: $(/opt/llvm/bin/clang --version | head -1)"; \
      echo "wasm-cc: $("$WASI_SDK_PATH/bin/clang" --version | head -1)"; \
      echo "cmake: $(cat /tmp/out/cmake-version)"; echo "wasmtime: $(wasmtime --version)"; \
      echo "node: $(node --version)"; echo "qjs-cflags: $QJS_CFLAGS"; \
      echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN; \
    rm -rf /tmp/out src
ENV LANG_VERSION=javascript-quickjs-ng
