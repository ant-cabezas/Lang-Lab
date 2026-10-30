# WebAssembly side study, Python column. Build context is the repo root:
#   docker build -f languages/wasm/python/Dockerfile -t lang-lab-wasm:python .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Two CPython builds from the SAME pinned 3.13.4 source, same LLVM release (23.1.0), same configure options:
#   /app/py-native/   native aarch64, /opt/llvm/bin/clang (LLVM 23.1.0), the same-build control
#   /app/py-wasm/     wasm32-wasip1, wasi-sdk 34 clang (LLVM 23.1.0), cross-built with the native one as build python
#   /app/py-wasm/bin/python3.13.cwasm   the interpreter precompiled by wasmtime (AOT, runs skip Cranelift)
# Common configure options: --without-ensurepip --disable-test-modules --with-pymalloc --with-computed-gotos. No PGO, no LTO,
# no --enable-shared on either side (the matrix image python:3.13.4 is gcc + PGO + LTO + shared; it is only a
# reference column, measured from lang-lab-python). pymalloc is OFF by default on WASI, so it is forced ON
# for both builds to match the matrix allocator. Computed gotos are forced ON for both because the cross
# build cannot run configure's run-probe and would silently fall back to switch dispatch (a dispatch
# difference, not a wasm cost). The wasm configure gets PKG_CONFIG_LIBDIR pointed at the wasi sysroot so that
# it does not pick up the host's zlib. The prefixes live under /app so that the stdlib is found
# from argv[0] alone: run-node.mjs passes an empty environment and preopens only /app.
# The interpreter is the same for all benchmarks; the canonical languages/python/*.py are copied unchanged.
# message-ring and the -par variants are excluded: they need threads, which wasm32-wasip1 lacks.
FROM lang-lab-wasm-base AS build
ARG PYTHON_VERSION=3.13.4
ARG PYTHON_SHA256=2666038f1521b7a8ec34bf2997b363778118d6f3979282c93723e872bcd464e0
ARG MAKE_JOBS=4
ARG WASMTIME_COMPILE_FLAGS=""
RUN set -eux; mkdir /src /build; cd /tmp; \
    curl -fsSLo py.tgz "https://www.python.org/ftp/python/${PYTHON_VERSION}/Python-${PYTHON_VERSION}.tgz"; \
    echo "${PYTHON_SHA256}  py.tgz" | sha256sum -c -; \
    tar xzf py.tgz -C /src --strip-components=1; rm py.tgz
# Native control: LLVM 23.1.0 clang, GNU ar. Also serves as --with-build-python for the cross build.
RUN set -eux; mkdir /build/native; cd /build/native; \
    CC=/opt/llvm/bin/clang AR=ar /src/configure --prefix=/app/py-native \
      --without-ensurepip --disable-test-modules --with-pymalloc --with-computed-gotos > configure.log 2>&1; \
    make -j"$MAKE_JOBS" > make.log 2>&1; make install > install.log 2>&1; \
    cp pyconfig.h /app/py-native.pyconfig.h; \
    { grep -E '^(OPT|CC|CFLAGS|CFLAGS_NODIST|CONFIGURE_CFLAGS|CONFIGURE_LDFLAGS|LDFLAGS|LIBS)=' Makefile; } > /app/py-native.flags
# Wasm: mirrors Tools/wasm/wasi.py configure_wasi_python (config.site, host triple, build python).
RUN set -eux; mkdir /build/wasm; cd /build/wasm; \
    export PKG_CONFIG_PATH="" PKG_CONFIG_LIBDIR="$WASI_SDK_PATH/share/wasi-sysroot/lib/pkgconfig" \
      PKG_CONFIG_SYSROOT_DIR="$WASI_SDK_PATH/share/wasi-sysroot" \
      CONFIG_SITE=/src/Tools/wasm/config.site-wasm32-wasi \
      CC="$WASI_SDK_PATH/bin/clang" CPP="$WASI_SDK_PATH/bin/clang-cpp" CXX="$WASI_SDK_PATH/bin/clang++" \
      AR="$WASI_SDK_PATH/bin/llvm-ar" RANLIB="$WASI_SDK_PATH/bin/llvm-ranlib" \
      HOSTRUNNER="wasmtime run --wasm max-wasm-stack=8388608 --dir /::/"; \
    /src/configure --host=wasm32-wasip1 --build="$(/src/config.guess)" \
      --with-build-python=/app/py-native/bin/python3.13 --prefix=/app/py-wasm \
      --without-ensurepip --disable-test-modules --with-pymalloc --with-computed-gotos > configure.log 2>&1; \
    make -j"$MAKE_JOBS" > make.log 2>&1; make install > install.log 2>&1; \
    cp pyconfig.h /app/py-wasm.pyconfig.h; \
    { grep -E '^(OPT|CC|CFLAGS|CFLAGS_NODIST|CONFIGURE_CFLAGS|CONFIGURE_LDFLAGS|LDFLAGS|LIBS)=' Makefile; } > /app/py-wasm.flags; \
    wasmtime compile $WASMTIME_COMPILE_FLAGS /app/py-wasm/bin/python3.13.wasm -o /app/py-wasm/bin/python3.13.cwasm; \
    find /app/py-native /app/py-wasm -name '*.opt-*.pyc' -delete; \
    rm -rf /build /src

FROM lang-lab-wasm-base
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /app /app
COPY languages/python/*.py /app/src/
COPY benchmarks /app/benchmarks
RUN set -eu; cd /app; \
    for f in src/*.py; do b=$(basename "$f" .py); \
      case "$b" in *-par*|message-ring) continue;; esac; cp "$f" "$b.py"; done; rm -rf src; \
    { echo "cpython: 3.13.4 (sha256 2666038f1521b7a8ec34bf2997b363778118d6f3979282c93723e872bcd464e0)"; \
      echo "native cc: $(/opt/llvm/bin/clang --version | head -1)"; \
      echo "wasm cc: $("$WASI_SDK_PATH/bin/clang" --version | head -1)"; echo "wasmtime: $(wasmtime --version)"; \
      echo "node: $(node --version)"; echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; \
      echo "--- native flags"; cat py-native.flags; echo "--- wasm flags"; cat py-wasm.flags; \
      for v in CONFIG_ARGS CC CFLAGS PY_CFLAGS_NODIST PY_CORE_CFLAGS LDFLAGS LIBS; do \
        echo "native $v: $(/app/py-native/bin/python3.13 -c "import sysconfig;print(sysconfig.get_config_var('$v'))")"; \
        echo "wasm $v: $(wasmtime run --dir /app::/app /app/py-wasm/bin/python3.13.wasm -c "import sysconfig;print(sysconfig.get_config_var('$v'))")"; done; \
      echo "--- interpreter-relevant pyconfig.h macros (native | wasm)"; \
      for m in USE_COMPUTED_GOTOS HAVE_COMPUTED_GOTOS WITH_PYMALLOC HAVE_MMAP SIZEOF_LONG SIZEOF_VOID_P SIZEOF_SIZE_T Py_GIL_DISABLED Py_DEBUG; do \
        echo "$m: $(grep -E "^(/\* #undef |#define )$m( |\\b)" py-native.pyconfig.h | head -1) | $(grep -E "^(/\* #undef |#define )$m( |\\b)" py-wasm.pyconfig.h | head -1)"; done; } > /app/TOOLCHAIN
ENV LANG_VERSION=3.13.4
