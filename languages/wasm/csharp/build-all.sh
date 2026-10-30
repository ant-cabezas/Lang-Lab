#!/bin/bash
# Builds every compute benchmark of one .NET language three ways, from the unmodified canonical sources.
#   build-all.sh <lang-dir> <project-extension> <out-dir>
#   e.g. build-all.sh languages/csharp csproj /out
# Output layout (all 18 apps of a mode share ONE runtime copy, assembly names are the benchmark names):
#   <out>/coreclr/<b>        self-contained CoreCLR 9.0.22 apphost, framework-dependent files shared (reference column)
#   <out>/mono/<b>           self-contained Mono apphost; run with MONO_ENV_OPTIONS=--interpreter it is the
#                            native counterpart of the wasm modules (same engine: Mono interpreter)
#   <out>/wasm/<b>.wasm      WASI preview1 core module: Mono interpreter + bundled trimmed assemblies
# message-ring and the -par variants are excluded (threads / processes, no wasm32-wasip1 equivalent).
set -euo pipefail
lang_dir="$1"; ext="$2"; out="$3"
rid="linux-$(uname -m | sed 's/aarch64/arm64/;s/x86_64/x64/')"
mono_fw="${MONO_PACK_VERSION:?}"
benches=()
for d in "$lang_dir"/*/; do
  b="$(basename "$d")"
  case "$b" in *-par|message-ring) continue;; esac
  ls "$d"*."$ext" >/dev/null 2>&1 && benches+=("$b")
done
echo "benchmarks (${#benches[@]}): ${benches[*]}"
mkdir -p "$out/coreclr" "$out/mono" "$out/wasm" /build/wasm /build/native
cp /opt/wasm-build/Directory.Build.targets /build/wasm/Directory.Build.targets
for b in "${benches[@]}"; do
  # CoreCLR reference and Mono counterpart: same project, same IL, different runtime pack.
  rm -rf "/build/native/$b"; cp -r "$lang_dir/$b" "/build/native/$b"
  dotnet publish "/build/native/$b/$b.$ext" -c Release -r "$rid" --self-contained true -o "$out/coreclr" >/dev/null
  rm -rf "/build/native/$b/obj" "/build/native/$b/bin"
  dotnet publish "/build/native/$b/$b.$ext" -c Release -r "$rid" --self-contained true \
    -p:UseMonoRuntime=true -p:RuntimeFrameworkVersion="$mono_fw" -p:DisableTransitiveFrameworkReferenceDownloads=true \
    -o "$out/mono" >/dev/null
  rm -rf "/build/native/$b"
  # WASI: the workload's non-AOT path (prebuilt Mono interpreter, relinked with the app bundled).
  rm -rf "/build/wasm/$b"; cp -r "$lang_dir/$b" "/build/wasm/$b"
  dotnet publish "/build/wasm/$b/$b.$ext" -c Release -r wasi-wasm \
    -p:WasmSingleFileBundle=true -p:WasiClang=/opt/wasm-build/wasi-clang-p1.sh -p:WasiClangVerbose=false \
    -o "/build/wasm/pub-$b" >/dev/null
  cp "/build/wasm/$b/bin/Release/net9.0/wasi-wasm/AppBundle/$b.wasm" "$out/wasm/$b.wasm"
  rm -rf "/build/wasm/$b" "/build/wasm/pub-$b"
  echo "built $b"
done
