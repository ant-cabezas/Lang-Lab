# WebAssembly side study, Swift column. Build context is the repo root:
#   docker build -f languages/wasm/swift/Dockerfile -t lang-lab-wasm:swift .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# Per benchmark, from the canonical languages/swift/<b>.swift (never edited; 11 of 18 get a build-time Int64 shim, see below):
#   /app/native/<b>       swiftc -O, linux-aarch64 (the matrix build line), built by the SAME toolchain as the wasm side
#   /app/wasm/<b>.wasm    swiftc -O -target wasm32-unknown-wasip1 against the SDK, -static-stdlib, 8 MiB shadow stack
#   /app/wasm/<b>.cwasm   the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# VERSION ASYMMETRY (documented, unavoidable): the matrix pins swift:6.1 (6.1.3). The official Swift SDK for
# WebAssembly first shipped with Swift 6.2 (swift.org lists no wasm-sdk for any 6.0 or 6.1 release), so this
# lane uses the nearest release that has one, 6.2.0 (image swift:6.2.0 = swift-6.2-RELEASE; the SDK must match
# the compiler release exactly). The native control /app/native/<b> is built here with that same 6.2.0 compiler,
# so native and wasm differ only in target. Its runtime libraries (libswiftCore, Foundation...) are copied from
# the swift image to /opt/swift-rt and found through an rpath, so the binaries run on the gcc/trixie base.
# Pins: swift:6.2.0 image, SDK swift-6.2-RELEASE_wasm.artifactbundle.tar.gz sha256 below (swift.org release
# metadata, "Wasm SDK" checksum of release 6.2).
# Flags: both sides use plain `swiftc -O`, like languages/swift/Dockerfile. The wasm link adds only
# -z stack-size=8388608 (wasm default shadow stack is 64 KiB; native main thread has 8 MiB). swiftc 6.2 has
# no -swift-sdk option (only SwiftPM does), so the SDK is wired by hand exactly as its swift-sdk.json and
# toolset.json describe: -sdk WASI.sdk, -resource-dir swift_static, -static-stdlib (toolset extraCLIOptions),
# plus the clang resource dir so wasm-ld finds libclang_rt.builtins-wasm32.a. Native is dynamic stdlib, as in
# the matrix; wasm is necessarily a static link.
# 64-bit Int: Swift's Int is the word size, 32 bits on wasm32 (the task's assumption of a 64-bit Int on
# wasm32 does not hold). Eleven benchmarks keep 64-bit LCG state in plain Int and trap or print a wrong
# checksum on wasm32 (measured, see INT64_BENCHES). For those the build applies int64.sh (int64-shim.swift
# inserted after `import Foundation`: IntegerLiteralType, Int and UInt become the 64-bit types plus an
# Array subscript/init/reserveCapacity overload for Int64). /app/native-shim/<b> compiles the same
# transformed source natively (column native-shim) to measure what the transform costs on a 64-bit target.
# message-ring and the -par variants are excluded: they need threads, which wasm32-wasip1 lacks.
ARG SWIFT_VERSION=6.2.0
ARG SWIFT_IMAGE_DIGEST=sha256:471acf16d3ce9b270d2f15ea177b0e150bdf1595ae2acfcc4932d1a03f43c3fd
ARG SWIFT_WASM_SDK_SHA256=fe4e8648309fce86ea522e9e0d1dc48e82df6ba6e5743dbf0c53db8429fb5224

FROM swift:${SWIFT_VERSION}@${SWIFT_IMAGE_DIGEST} AS build
ARG SWIFT_WASM_SDK_SHA256
ARG WASM_STACK=8388608
# The benchmarks that need the 64-bit Int shim on wasm32 (measured: they trap or print a wrong checksum
# unmodified); the other seven (bigint binary-trees blur fannkuch k-nucleotide mandelbrot tak) pass the
# checksum gate unmodified and are built from the canonical source.
ARG INT64_BENCHES="dijkstra gbdt gemm k-means lz77 polymorphism reverse-complement sha256 sort-search viterbi vm"
RUN swift sdk install "https://download.swift.org/swift-6.2-release/wasm-sdk/swift-6.2-RELEASE/swift-6.2-RELEASE_wasm.artifactbundle.tar.gz" \
      --checksum "${SWIFT_WASM_SDK_SHA256}" \
 && swift sdk list
COPY languages/swift/*.swift /src/
COPY languages/wasm/swift/int64.sh languages/wasm/swift/int64-shim.swift /tool/
RUN set -eu; mkdir -p /out/native /out/native-shim /out/wasm /out/rt /tmp/t; \
    sdk=swift-6.2-RELEASE_wasm; \
    B=/root/.swiftpm/swift-sdks/$sdk.artifactbundle/$sdk/wasm32-unknown-wasip1; \
    SR=$B/swift.xctoolchain/usr/lib/swift_static; \
    WF="-O -target wasm32-unknown-wasip1 -sdk $B/WASI.sdk -resource-dir $SR -static-stdlib -Xclang-linker -resource-dir -Xclang-linker $SR/clang -Xlinker -z -Xlinker stack-size=${WASM_STACK}"; \
    for f in /src/*.swift; do b=$(basename "$f" .swift); \
      case "$b" in *-par|message-ring) continue;; esac; \
      swiftc -O "$f" -o "/out/native/$b" -Xlinker -rpath -Xlinker /opt/swift-rt; \
      case " $INT64_BENCHES " in \
        *" $b "*) /tool/int64.sh "$f" "/tmp/t/$b.swift"; \
                  swiftc -O "/tmp/t/$b.swift" -o "/out/native-shim/$b" -Xlinker -rpath -Xlinker /opt/swift-rt; \
                  swiftc $WF "/tmp/t/$b.swift" -o "/out/wasm/$b.wasm";; \
        *) swiftc $WF "$f" -o "/out/wasm/$b.wasm";; \
      esac; \
    done; \
    cp -a /usr/lib/swift/linux/*.so /out/rt/; \
    { swiftc --version | head -1 | sed 's/^/swiftc: /'; echo "wasm-sdk: $sdk"; \
      echo "wasm-flags: $WF"; echo "native-flags: -O"; echo "int64-shim-benchmarks: $INT64_BENCHES"; } > /out/TOOLCHAIN.part

FROM lang-lab-wasm-base
ARG SWIFT_WASM_SDK_SHA256
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /out/native /app/native
COPY --from=build /out/native-shim /app/native-shim
COPY --from=build /out/wasm /app/wasm
COPY --from=build /out/rt /opt/swift-rt
COPY --from=build /out/TOOLCHAIN.part /tmp/TOOLCHAIN.part
COPY benchmarks /app/benchmarks
RUN set -eu; cd /app/wasm; \
    for w in *.wasm; do wasmtime compile $WASMTIME_COMPILE_FLAGS "$w" -o "${w%.wasm}.cwasm"; done; \
    { cat /tmp/TOOLCHAIN.part; echo "wasm-sdk-sha256: $SWIFT_WASM_SDK_SHA256"; \
      echo "wasmtime: $(wasmtime --version)"; echo "node: $(node --version)"; \
      echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN; rm /tmp/TOOLCHAIN.part
ENV LANG_VERSION=swift
