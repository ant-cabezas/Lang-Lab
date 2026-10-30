# WebAssembly side study, PHP column. Build context is the repo root:
#   docker build -f languages/wasm/php/Dockerfile -t lang-lab-wasm:php .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Two PHP CLI builds from the SAME pinned php-8.4.8 source tree (the matrix version), the same patch set, the same
# LLVM release (23.1.0) and the same configure flags:
#   /app/php-native/php          native aarch64, /opt/llvm/bin/clang (LLVM 23.1.0), the same-build control
#   /app/php-wasm/php.wasm       wasm32-wasip1, wasi-sdk 34 clang (LLVM 23.1.0)
#   /app/php-wasm/php.cwasm      the same module precompiled by wasmtime (AOT, runs skip Cranelift)
# Common configure flags: --disable-all --enable-cli --disable-cgi --disable-phpdbg --disable-opcache
# --disable-fiber-asm --disable-zend-signals --without-pcre-jit --disable-gcc-global-regs --without-valgrind
# --disable-shared --enable-static --without-pear, CFLAGS -O2, no LTO, no PGO. Loaded extensions: Core, date, pcre,
# hash, json, random, Reflection, standard, SPL (everything the 18 benchmarks need). OPcache is not compiled in on
# either side, so there is no JIT and no bytecode cache; the interpreter runs as `php -n` (no php.ini) in every
# study column. --disable-gcc-global-regs puts both builds on the CALL VM dispatch; the matrix image (gcc, global
# registers) uses HYBRID, so the matrix PHP is only a reference column.
#
# PHP has no WASI support upstream. The patches are the generic, __wasi__-guarded parts of mpyw/gophper-wasm
# (MIT, commit 3e1fa95fd74cac4b96c448aee948457cece09396, written for php-8.6.0RC4; they apply to 8.4.8 with offsets):
# (patch files are pinned by patches/SHA256SUMS; 0001-0003, 0005, 0006 are byte-identical to upstream)
#   0001 configure: no fiber asm / ucontext on WASI (ZEND_FIBER_UNSUPPORTED), PHP_OS=WASI
#   0002 fibers: stubs, Fiber throws on WASI
#   0003 zend_alloc: chunks come from aligned_alloc() instead of mmap (wasi-emulated-mman cannot align or unmap)
#   0005 random: csprng from WASI random_get
#   0006 getrusage: only the fields wasi-libc has
#   0007 fnmatch hunk of the upstream patch only (the res_search hunk assumes their host layer)
# plus one patch of ours:
#   0008 zend_long.h: ZEND_ENABLE_ZVAL_LONG64 also for __wasm32__, because wasm32 is ILP32 and the benchmarks need
#        PHP's 64-bit integers (the matrix PHP is LP64). Dead code natively: aarch64 already defines it.
# All patches sit behind __wasi__, host_os=wasi* or __wasm32__, so they are dead code in the native build; both
# builds are configured from the same patched and buildconf'd tree.
# Not taken from upstream: the host-ABI layer of gophper (compat/*.c, --wrap, ac_cv overrides). Instead
# compat/wasi-compat.h (force-included at make time) declares the POSIX calls wasi-libc hides, compat/include has
# the missing headers (from gophper, MIT) and compat/wasi-stubs.c holds failing stubs (users, sockets, popen,
# syslog, dlopen, getaddrinfo, madvise); configure runs without any of it so it detects those functions as absent.
# setjmp/longjmp (zend_try) use the wasm exception-handling lowering: -mllvm -wasm-enable-sjlj
# -mllvm -wasm-use-legacy-eh=false with -lsetjmp; wasmtime 50 and V8 (node 26) run it natively, no asyncify.
# The interpreter is the same for all benchmarks; the canonical languages/php/*.php are copied unchanged.
# message-ring and the -par variants are excluded: they need fork/sockets, which wasm32-wasip1 lacks.
FROM lang-lab-wasm-base AS build
ARG PHP_VERSION=8.4.8
ARG PHP_SHA256=aa6a4d330b47eacd83e351658ba8c47747a1e4356456219cfb6d75e7838da091
ARG MAKE_JOBS=4
ARG WASMTIME_COMPILE_FLAGS=""
ARG PHP_CONFIGURE="--disable-all --enable-cli --disable-cgi --disable-phpdbg --disable-opcache --disable-fiber-asm --disable-zend-signals --without-pcre-jit --disable-gcc-global-regs --without-valgrind --disable-shared --enable-static --without-pear"
RUN apt-get update -qq \
 && apt-get install -y -qq --no-install-recommends autoconf bison re2c pkg-config file >/dev/null \
 && rm -rf /var/lib/apt/lists/*
RUN set -eux; mkdir /src /build; cd /tmp; \
    curl -fsSLo php.txz "https://www.php.net/distributions/php-${PHP_VERSION}.tar.xz"; \
    echo "${PHP_SHA256}  php.txz" | sha256sum -c -; \
    tar xJf php.txz -C /src --strip-components=1; rm php.txz
COPY languages/wasm/php/patches /patches
COPY languages/wasm/php/compat /compat
# One patched, regenerated tree; both builds start from a copy of it.
RUN set -eux; cd /patches; sha256sum -c SHA256SUMS; cd /src; \
    for p in /patches/0001*.patch /patches/0002*.patch /patches/0003*.patch /patches/0005*.patch \
             /patches/0006*.patch /patches/0007*.patch /patches/0008*.patch; do patch -p1 --no-backup-if-mismatch < "$p"; done; \
    ./buildconf --force > /build/buildconf.log 2>&1
# Native control: LLVM 23.1.0 clang, -O2.
RUN set -eux; cp -a /src /build/native; cd /build/native; \
    CC=/opt/llvm/bin/clang CFLAGS="-O2" ./configure $PHP_CONFIGURE > /build/native.configure.log 2>&1; \
    make -j"$MAKE_JOBS" cli > /build/native.make.log 2>&1; \
    mkdir -p /out/php-native; cp sapi/cli/php /out/php-native/php; cp main/php_config.h /out/php-native/php_config.h
# Wasm: wasi-sdk 34 clang (LLVM 23.1.0), same flags plus the WASI emulation libs and the sjlj lowering.
RUN set -eux; cp -a /src /build/wasm; cd /build/wasm; \
    S="$WASI_SDK_PATH"; \
    export CC="$S/bin/clang --target=wasm32-wasip1 --sysroot=$S/share/wasi-sysroot" \
      AR="$S/bin/llvm-ar" RANLIB="$S/bin/llvm-ranlib" NM="$S/bin/llvm-nm" \
      CFLAGS="-O2 -D_WASI_EMULATED_SIGNAL -D_WASI_EMULATED_PROCESS_CLOCKS -D_WASI_EMULATED_MMAN -D_WASI_EMULATED_GETPID -mllvm -wasm-enable-sjlj -mllvm -wasm-use-legacy-eh=false" \
      LDFLAGS="-lwasi-emulated-signal -lwasi-emulated-process-clocks -lwasi-emulated-mman -lwasi-emulated-getpid -lsetjmp -Wl,-z,stack-size=8388608"; \
    ./configure --host=wasm32-wasi --build="$(/src/build/config.guess)" $PHP_CONFIGURE > /build/wasm.configure.log 2>&1; \
    $CC -O2 -I/compat/include -c /compat/wasi-stubs.c -o /build/wasi-stubs.o; \
    make -j"$MAKE_JOBS" cli EXTRA_CFLAGS="-I/compat/include -include /compat/wasi-compat.h" EXTRA_LIBS="/build/wasi-stubs.o" > /build/wasm.make.log 2>&1; \
    mkdir -p /out/php-wasm; cp sapi/cli/php /out/php-wasm/php.wasm; cp main/php_config.h /out/php-wasm/php_config.h; \
    wasmtime compile $WASMTIME_COMPILE_FLAGS /out/php-wasm/php.wasm -o /out/php-wasm/php.cwasm
# Configure-time differences between the two builds, kept for audit.
RUN set -eux; for d in native wasm; do \
      grep -E '^#define|^/\* #undef' /build/$d/main/php_config.h | sed 's/^\/\* #undef \(.*\) \*\//#undef \1/' | sort > /tmp/$d.cfg; done; \
    diff /tmp/native.cfg /tmp/wasm.cfg > /out/php-config.diff || true

FROM lang-lab-wasm-base
ARG PHP_VERSION=8.4.8
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /out/ /app/
COPY languages/php/*.php /app/
COPY benchmarks /app/benchmarks
RUN set -eu; rm -f /app/*-par.php /app/message-ring.php; \
    { echo "php: ${PHP_VERSION} (patched, see Dockerfile)"; \
      echo "clang: $(/opt/llvm/bin/clang --version | head -1)"; \
      echo "wasi-sdk: $("$WASI_SDK_PATH/bin/clang" --version | head -1)"; echo "wasmtime: $(wasmtime --version)"; \
      echo "node: $(node --version)"; echo "cflags: -O2 (wasm adds WASI emulation defines and sjlj flags)"; \
      echo "wasmtime-compile-flags: ${WASMTIME_COMPILE_FLAGS}"; \
      echo "extensions: $(/app/php-native/php -n -r 'echo implode(",", get_loaded_extensions());')"; } > /app/TOOLCHAIN
ENV LANG_VERSION=${PHP_VERSION}
