#!/bin/bash
# clang wrapper for the .NET 9 wasi workload, selected with -p:WasiClang=/opt/wasm/wasi-clang-p1.sh.
# The workload hard-codes --target=wasm32-unknown-wasip2 (and links with wasm-component-ld plus
# WasiHttpWorld_component_type.wit), so every build yields a WASI 0.2 component that wasmtime can
# run but node:wasi (preview1 only) cannot. This wrapper rewrites each response file the workload
# passes: target wasip2 -> wasip1, and drops the component-type option. The result is a plain core
# module importing wasi_snapshot_preview1, the one artifact both wasmtime and V8 run. The sources,
# the Mono runtime pack and every other flag are untouched.
set -eu
real="${WASI_SDK_PATH%/}/bin/clang"
args=()
for a in "$@"; do
  case "$a" in
    @*) t="$(mktemp)"
        sed -e 's#wasm32-unknown-wasip2#wasm32-wasip1#g' -e 's#wasm32-wasip2#wasm32-wasip1#g' "${a#@}" \
          | { grep -v -e '--component-type' || true; } > "$t"
        args+=("@$t") ;;
    *) args+=("${a//wasm32-unknown-wasip2/wasm32-wasip1}") ;;
  esac
done
exec "$real" "${args[@]}"
