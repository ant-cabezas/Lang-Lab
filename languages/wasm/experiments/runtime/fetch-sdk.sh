#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: fetch the older toolchains for the wasi-sdk sweep (task2).
#
# Downloads, verifies (sha256) and unpacks wasi-sdk 25 and 30 and the official LLVM releases of the same
# clang versions (19.1.5 and 21.1.4, the native same-compiler controls) into $WORK/ctx-sdk/, the layout
# build-sdk.sh copies into its build container:
#   ctx-sdk/wasi-sdk-25  ctx-sdk/wasi-sdk-30  ctx-sdk/llvm-19.1.5  ctx-sdk/llvm-21.1.4
# Only clang, lld and clang's resource dir are extracted from the LLVM tarballs (about 10% of their size).
# The sha256 pins are of the files fetched for the study run; the LLVM 19.1.5 tarball was also checked
# once against its detached GPG signature (.sig) with https://releases.llvm.org/release-keys.asc.
# The two LLVM releases use different asset naming schemes (clang+llvm-...-aarch64-linux-gnu vs LLVM-...-Linux-ARM64).
#
#   languages/wasm/experiments/runtime/fetch-sdk.sh
#
# Environment: WORK (default ${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work), the downloads are
# kept in $WORK/dl and reused. Needs about 2.5 GB of host disk. Bash 3.2 compatible (bsdtar or GNU tar).
set -euo pipefail
WORK="${WORK:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work}"
DL="$WORK/dl"; C="$WORK/ctx-sdk"; mkdir -p "$DL" "$C"

sha256() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | cut -d' ' -f1; else shasum -a 256 "$1" | cut -d' ' -f1; fi; }
fetch() {  # fetch <url> <file> <sha256>
  if [ ! -f "$DL/$2" ]; then curl -fsSLo "$DL/$2.part" "$1"; mv "$DL/$2.part" "$DL/$2"; fi
  got="$(sha256 "$DL/$2")"
  [ "$got" = "$3" ] || { echo "fetch-sdk.sh: sha256 mismatch for $2: $got" >&2; exit 1; }
}
# GNU tar needs --wildcards for the member patterns below; bsdtar (macOS) globs by default.
WILD=""; tar --version 2>/dev/null | grep -q 'GNU tar' && WILD="--wildcards"

fetch https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-25/wasi-sdk-25.0-arm64-linux.tar.gz \
  wasi-sdk-25.0-arm64-linux.tar.gz 47fccad8b2498f2239e05e1115c3ffc652bf37e7de2f88fb64b2d663c976ce2d
fetch https://github.com/WebAssembly/wasi-sdk/releases/download/wasi-sdk-30/wasi-sdk-30.0-arm64-linux.tar.gz \
  wasi-sdk-30.0-arm64-linux.tar.gz 6f2977942308d91b0123978da3c6a0d6fce780994b3b020008c617e26764ea40
fetch https://github.com/llvm/llvm-project/releases/download/llvmorg-19.1.5/clang+llvm-19.1.5-aarch64-linux-gnu.tar.xz \
  clang+llvm-19.1.5-aarch64-linux-gnu.tar.xz 1bdc342b7d03cbcfafb2ffb8659eb0e4d5c6ddef6f56e0cad0e0c09c52577a4f
fetch https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.4/LLVM-21.1.4-Linux-ARM64.tar.xz \
  LLVM-21.1.4-Linux-ARM64.tar.xz b1cdf40de4dc53fc090684fb6a160c0c9348242d85d2321441a9873cb116ea18

for v in 25 30; do
  rm -rf "$C/wasi-sdk-$v"; mkdir -p "$C/wasi-sdk-$v"
  tar xzf "$DL/wasi-sdk-$v.0-arm64-linux.tar.gz" -C "$C/wasi-sdk-$v" --strip-components=1
done
rm -rf "$C/llvm-19.1.5" "$C/llvm-21.1.4"; mkdir -p "$C/llvm-19.1.5" "$C/llvm-21.1.4"
tar xJf "$DL/clang+llvm-19.1.5-aarch64-linux-gnu.tar.xz" -C "$C/llvm-19.1.5" --strip-components=1 $WILD \
  '*/bin/clang' '*/bin/clang-1[0-9]' '*/bin/lld' '*/bin/ld.lld' '*/lib/clang/*'
tar xJf "$DL/LLVM-21.1.4-Linux-ARM64.tar.xz" -C "$C/llvm-21.1.4" --strip-components=1 $WILD \
  '*/bin/clang' '*/bin/clang-2[0-9]' '*/bin/lld' '*/bin/ld.lld' '*/lib/clang/*'
du -sh "$C"/* >&2
