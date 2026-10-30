# WebAssembly side study, C# column. Build context is the repo root:
#   docker build -f languages/wasm/csharp/Dockerfile -t lang-lab-wasm:csharp .
# (needs lang-lab-wasm-base, see languages/wasm/Dockerfile.base)
#
# The .NET WASI route today is the wasi-experimental workload: Mono (the interpreter, mono-ee-interp)
# compiled to WebAssembly, with the app's trimmed assemblies bundled into one module
# (WasmSingleFileBundle). It is NOT CoreCLR and NOT ahead-of-time compiled code:
#   - .NET 8: the workload builds and runs (wasi-sdk 16, Mono interpreter only, no AOT cross pack on wasi).
#   - .NET 9 (this lane): the packs exist at 9.0.22 and need wasi-sdk 24, but the SDK manifest aborts
#     every wasi-wasm build ("not supported in .NET 9"). The guard is a one-line target, neutralised by
#     Directory.Build.targets in this directory. OFFICIALLY UNSUPPORTED. AOT (RunAOTCompilation) builds
#     but the module dies at startup (NullReferenceException in HashHelpers.GetPrime inside AOT'd
#     CoreLib, also with WasmStripILAfterAOT=false and WasmDedup=false), so only interpreter mode exists.
#   - .NET 10: same guard ("not supported in .NET 10"), wasi-sdk 25.
# The workload links with wasi-sdk's wasip2 target by default (a component, which V8 cannot load);
# wasi-clang-p1.sh, selected through -p:WasiClang, rewrites the link to wasm32-wasip1 so one core
# module serves wasmtime and node.
#
# Per benchmark, from the canonical languages/csharp/<b>/ (never edited):
#   /app/coreclr/<b>        self-contained CoreCLR 9.0.22 apphost (matrix runtime; run with the matrix runtimeEnv)
#   /app/mono/<b>           self-contained Mono apphost (9.0.0-preview.7 pack, see below); with
#                           MONO_ENV_OPTIONS=--interpreter it is the same-engine native counterpart
#   /app/wasm/<b>.wasm      WASI preview1 module, Mono interpreter + the bundled app
#   /app/wasm/<b>.cwasm     the same module precompiled by wasmtime (AOT, so runs skip Cranelift)
# All apps of a mode share one runtime directory (assembly name = benchmark name), which keeps the image small.
#
# Pins: SDK image by digest; workload packs 9.0.22 by nupkg sha256; wasi-sdk 24 by sha256 (taken from the
# download, the release publishes no digest); the native Mono runtime pack is 9.0.0-preview.7.24405.7
# because NO stable Microsoft.NETCore.App.Runtime.Mono.linux-arm64 exists on nuget.org or the dotnet9
# feed (checked 2026-10-26), only 9.0.0-preview.* ones. message-ring and the -par variants are excluded.
ARG SDK_DIGEST=sha256:d7cfd59385751fc87897a138ba173fb1bbc2bf946ea78aecc91a119993676997
FROM mcr.microsoft.com/dotnet/sdk:9.0@${SDK_DIGEST} AS build
ARG WASI_SDK_SHA256=ae6c1417ea161e54bc54c0a168976af57a0c6e53078857886057a71a0d928646
ARG MONO_PACK_VERSION=9.0.0-preview.7.24405.7
ARG MONO_PACK_SHA256=2508af47bbf18d5e0b645583d306a475ddcc5260c0079474f7136ff359a99674
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 MONO_PACK_VERSION=${MONO_PACK_VERSION} WASI_SDK_PATH=/opt/wasi-sdk-24
RUN dotnet workload install wasi-experimental --skip-manifest-update >/dev/null \
 && cd /usr/share/dotnet/packs \
 && printf '%s  %s\n' \
      bf701ebddeebf74204714c4b52def36d31e22dae1edb9a32298901c24df2408d Microsoft.NET.Runtime.WebAssembly.Wasi.Sdk/9.0.22/Microsoft.NET.Runtime.WebAssembly.Wasi.Sdk.nupkg \
      3f54518405edeac94bbd7664e9b537cad9045274fb7c6285cceed14cfbed299b Microsoft.NETCore.App.Runtime.Mono.wasi-wasm/9.0.22/Microsoft.NETCore.App.Runtime.Mono.wasi-wasm.nupkg \
      227ee8afcd5ecb02a87670ff76d034bb5354f6e9e05068f3d1eef2be40e3cad6 Microsoft.NETCore.App.Runtime.AOT.linux-arm64.Cross.wasi-wasm/9.0.22/Microsoft.NETCore.App.Runtime.AOT.linux-arm64.Cross.wasi-wasm.nupkg \
      3823adbb931d84672fff0df3569aff81eb7ad94dc61c231044fa6c5d15045a34 Microsoft.NET.Runtime.MonoAOTCompiler.Task/9.0.22/Microsoft.NET.Runtime.MonoAOTCompiler.Task.nupkg \
      4351b0c92b899cd1646672eeccbd6c760fae2c64dac9f036cfd5780f44fed23e Microsoft.NET.Runtime.MonoTargets.Sdk/9.0.22/Microsoft.NET.Runtime.MonoTargets.Sdk.nupkg \
    | sha256sum -c - \
 && rm -rf /root/.nuget/packages/* /tmp/*
# wasi-sdk 24 is what dotnet/runtime v9.0.22 pins (src/mono/wasi/wasi-sdk-version.txt); the targets look for
# the marker file VERSION24 that the runtime repo's own provisioning step touches.
RUN set -eux; cd /tmp; \
    curl -fsSLo w.tgz https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-24/wasi-sdk-24.0-arm64-linux.tar.gz; \
    echo "${WASI_SDK_SHA256}  w.tgz" | sha256sum -c -; \
    mkdir "$WASI_SDK_PATH" && tar xzf w.tgz -C "$WASI_SDK_PATH" --strip-components=1; rm w.tgz; \
    touch "$WASI_SDK_PATH/VERSION24"; echo 24 > "$WASI_SDK_PATH/wasi-sdk-version.txt"
COPY languages/wasm/csharp/Directory.Build.targets languages/wasm/csharp/wasi-clang-p1.sh languages/wasm/csharp/build-all.sh /opt/wasm-build/
COPY languages/csharp/ /src/
RUN /opt/wasm-build/build-all.sh /src csproj /out \
 && f=$(find /root/.nuget/packages/microsoft.netcore.app.runtime.mono.linux-arm64 -name '*.nupkg') \
 && echo "${MONO_PACK_SHA256}  $f" | sha256sum -c - \
 && { echo "sdk: $(dotnet --version)"; dotnet --list-runtimes | grep NETCore; dotnet workload list | tail -n +4 | head -3; \
      echo "wasi-sdk: $("$WASI_SDK_PATH/bin/clang" --version | head -1)"; echo "mono-pack: $MONO_PACK_VERSION"; } > /out/TOOLCHAIN.dotnet \
 && rm -rf /build /root/.nuget /tmp/*

FROM lang-lab-wasm-base
ARG WASMTIME_COMPILE_FLAGS=""
COPY --from=build /out/ /app/
RUN set -eu; for f in /app/wasm/*.wasm; do wasmtime compile $WASMTIME_COMPILE_FLAGS "$f" -o "${f%.wasm}.cwasm"; done; \
    { cat /app/TOOLCHAIN.dotnet; echo "wasmtime: $(wasmtime --version)"; echo "node: $(node --version)"; \
      echo "wasmtime-compile-flags: $WASMTIME_COMPILE_FLAGS"; } > /app/TOOLCHAIN; rm /app/TOOLCHAIN.dotnet
ENV LANG_VERSION=9.0.22
