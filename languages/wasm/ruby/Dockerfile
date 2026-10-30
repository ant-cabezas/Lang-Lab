# WebAssembly side study, Ruby column. Build context is the repo root:
#   docker build -f languages/wasm/ruby/Dockerfile -t lang-lab-wasm:ruby .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Two CRuby builds from the SAME pinned 3.3.13 source (the patch level of the matrix image ruby:3.3-slim),
# same LLVM release (23.1.0), same configure options:
#   /app/rb-native/   native aarch64, /opt/llvm/bin/clang (LLVM 23.1.0), the same-build control
#   /app/rb-wasm/     wasm32-wasi, wasi-sdk 34 clang (LLVM 23.1.0), cross-built with rb-native as BASERUBY,
#                     following the in-tree wasm/README.md recipe
#   /app/rb-wasm/bin/ruby.cwasm   the interpreter precompiled by wasmtime (AOT, runs skip Cranelift)
# Common configure options: --disable-shared --with-static-linked-ext --with-ext=ripper,monitor (the README
# list; monitor is the only extension loaded at startup, by rubygems) --disable-yjit --disable-rjit
# --disable-install-doc debugflags= ; optflags stay at the configure default (-O3 -fno-fast-math) on both.
# Hardening that configure applies only to the native target is turned off there too, because the wasm
# target cannot have it: --disable-fortify-source, stack_protector=no, and -mbranch-protection=pac-ret is
# removed from the generated Makefile (configure has no switch for it).
# Wasm-only steps, all from CRuby's own configure for wasi: _WASI_EMULATED_{SIGNAL,MMAN,GETPID,PROCESS_CLOCKS}
# and their libraries; setjmp/longjmp, fibers and the GC's register scan run on Asyncify, applied after the
# link by Binaryen: wasm-opt --asyncify -O3 --pass-arg=asyncify-ignore-imports (POSTLINK, wasmoptflags=-O3).
# Binaryen is pinned below. Link: -Wl,-z,stack-size=16777216 (the README value).
# Build-time transform (wasm build only): -Dmprotect=rb_wasm_mprotect_stub. CRuby's wasm/missing.c defines a
# weak no-op mprotect; wasi-sdk 34's libwasi-emulated-mman.a (linked for mmap) now defines a strong one that
# fails with EINVAL on the fiber pool guard page, so Init_Cont raised and ruby exited 1 with no output. The
# rename makes every CRuby call reach CRuby's own stub, as upstream intends. No native code is affected.
# A parallel make that fails is retried once serially (an intermittent ordering failure was seen once in
# the wasm tree); /app/flags/serial-retry records it if that happened.
# The matrix image (lang-lab-ruby: gcc, --enable-shared, YJIT compiled in but off) is a reference column only.
# The canonical languages/ruby/*.rb are copied unchanged. alloc.rb is a diagnostic helper (never measured).
# message-ring and the -par variants are excluded: they need threads, which wasm32-wasi lacks.
FROM lang-lab-wasm-base AS build
ARG RUBY_VERSION=3.3.13
ARG RUBY_SHA256=4cae72e971bd1cdb20ca87d299111182417c5276c162de8ead0ab0531426cd61
ARG BINARYEN_VERSION=133
ARG BINARYEN_SHA256=89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8
ARG MAKE_JOBS=4
ARG WASMTIME_COMPILE_FLAGS=""
RUN set -eux; cd /tmp; \
    curl -fsSLo binaryen.tgz "https://github.com/WebAssembly/binaryen/releases/download/version_${BINARYEN_VERSION}/binaryen-version_${BINARYEN_VERSION}-aarch64-linux.tar.gz"; \
    echo "${BINARYEN_SHA256}  binaryen.tgz" | sha256sum -c -; \
    mkdir /opt/binaryen && tar xzf binaryen.tgz -C /opt/binaryen --strip-components=1; rm binaryen.tgz; \
    curl -fsSLo ruby.tgz "https://cache.ruby-lang.org/pub/ruby/${RUBY_VERSION%.*}/ruby-${RUBY_VERSION}.tar.gz"; \
    echo "${RUBY_SHA256}  ruby.tgz" | sha256sum -c -; \
    mkdir /src && tar xzf ruby.tgz -C /src --strip-components=1; rm ruby.tgz
RUN set -eux; mkdir -p /build/native /build/wasm /app/flags; \
    COMMON="--disable-install-doc --disable-shared --with-static-linked-ext --with-ext=ripper,monitor \
      --disable-yjit --disable-rjit --disable-fortify-source stack_protector=no debugflags="; \
    cd /build/native; \
    CC=/opt/llvm/bin/clang /src/configure --prefix=/app/rb-native $COMMON > configure.log 2>&1; \
    sed -i 's/ -mbranch-protection=pac-ret//' Makefile; \
    make -j"$MAKE_JOBS" > make.log 2>&1 || { echo native >> /app/flags/serial-retry; make > make2.log 2>&1; }; \
    make install > install.log 2>&1; \
    cp .ext/include/aarch64-linux/ruby/config.h /app/flags/native-config.h; \
    grep -E '^(CC|optflags|debugflags|warnflags|XCFLAGS|ASFLAGS|CPPFLAGS|LDFLAGS|XLDFLAGS|LIBS|MAINLIBS|configure_args) =' Makefile > /app/flags/native.flags; \
    cd /build/wasm; export PATH="/opt/binaryen/bin:$PATH"; \
    /src/configure --host=wasm32-unknown-wasi --build="$(/src/tool/config.guess)" --prefix=/app/rb-wasm \
      --with-baseruby=/app/rb-native/bin/ruby $COMMON \
      CPPFLAGS="-Dmprotect=rb_wasm_mprotect_stub" LDFLAGS="-Wl,-z,stack-size=16777216" > configure.log 2>&1; \
    make -j"$MAKE_JOBS" > make.log 2>&1 || { echo wasm >> /app/flags/serial-retry; make > make2.log 2>&1; }; \
    make install > install.log 2>&1; \
    cp .ext/include/wasm32-wasi/ruby/config.h /app/flags/wasm-config.h; \
    grep -E '^(CC|optflags|debugflags|warnflags|XCFLAGS|ASFLAGS|CPPFLAGS|LDFLAGS|XLDFLAGS|LIBS|MAINLIBS|POSTLINK|WASMOPT|wasmoptflags|configure_args) =' Makefile > /app/flags/wasm.flags; \
    wasm-opt --version > /app/flags/wasm-opt.version; \
    cd /; rm -rf /build /src; \
    wasmtime compile $WASMTIME_COMPILE_FLAGS /app/rb-wasm/bin/ruby -o /app/rb-wasm/bin/ruby.cwasm

FROM lang-lab-wasm-base
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /app /app
COPY languages/ruby/*.rb /app/src/
COPY languages/wasm/ruby/alloc.rb /app/diag/alloc.rb
COPY benchmarks /app/benchmarks
RUN set -eu; cd /app; \
    for f in src/*.rb; do b=$(basename "$f" .rb); \
      case "$b" in *-par|message-ring) continue;; esac; cp "$f" "$b.rb"; done; \
    { echo "cruby: 3.3.13 (sha256 4cae72e971bd1cdb20ca87d299111182417c5276c162de8ead0ab0531426cd61)"; \
      echo "native: $(/app/rb-native/bin/ruby -v)"; \
      echo "native cc: $(/opt/llvm/bin/clang --version | head -1)"; \
      echo "wasm cc: $("$WASI_SDK_PATH/bin/clang" --version | head -1) (wasi-sdk $WASI_SDK_VERSION)"; \
      echo "binaryen: $(cat flags/wasm-opt.version) (sha256 89c07ea56faf38d0fbecf36ca8ec0721756716185f265b568e133d427f299bf8)"; \
      echo "wasmtime: $(wasmtime --version)"; echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; \
      echo "node: $(node --version)"; echo "serial make retry: $(cat flags/serial-retry 2>/dev/null || echo none)"; \
      echo "--- native flags"; cat flags/native.flags; echo "--- wasm flags"; cat flags/wasm.flags; \
      echo "--- config.h diff (native vs wasm)"; diff flags/native-config.h flags/wasm-config.h || true; } > /app/TOOLCHAIN
ENV LANG_VERSION=3.3.13
