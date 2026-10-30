#!/usr/bin/env bash
# WebAssembly side study, codegen experiment: the disassembly behind the per-dispatch explanations.
#
# For polymorphism and dijkstra (the two benchmarks the codegen write-up explains instruction by
# instruction), dumps from lang-lab-wasm-codegen-o2 into $OUT (default $EXP_OUT/codegen/disasm):
#   native-<b>.full.txt       llvm-objdump of the clang 23.1.0 -O2 native binary
#   wasm-<b>.full.txt         wasmtime objdump of the default -O2 cwasm (what the wasm column executes)
#   wasmbounds-<b>.full.txt   the same module compiled with explicit bounds checks (knob/bounds)
#   wasmbytecode-<b>.full.txt the wasm bytecode itself (wasi-sdk llvm-objdump)
# and tak-default-vs-bounds.txt, tak's function in both cwasm variants. The annotated per-block counts
# in the study notes were read off these dumps; model/ turns them into predicted differentials.
# Bash 3.2 compatible.
set -euo pipefail
OUT="${OUT:-${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/codegen/disasm}"; mkdir -p "$OUT"
I=lang-lab-wasm-codegen-o2
for b in polymorphism dijkstra; do
  docker run --rm $I sh -c "/opt/llvm/bin/llvm-objdump -d --no-show-raw-insn --symbolize-operands /app/native/$b" > "$OUT/native-$b.full.txt"
  docker run --rm $I sh -c "wasmtime objdump --addresses --traps --color never /app/wasm/$b.cwasm" > "$OUT/wasm-$b.full.txt" 2>&1
  docker run --rm $I sh -c "wasmtime objdump --addresses --traps --color never /app/knob/bounds/$b.cwasm" > "$OUT/wasmbounds-$b.full.txt" 2>&1
  docker run --rm $I sh -c "/opt/wasi-sdk/bin/llvm-objdump -d /app/wasm/$b.wasm" > "$OUT/wasmbytecode-$b.full.txt" 2>&1
done
docker run --rm $I sh -c 'for v in wasm/tak.cwasm knob/bounds/tak.cwasm; do echo "== $v"; wasmtime objdump --addresses --color never /app/$v | grep -v "╰─╼" | awk "/::tak:/,/^\$/"; done' > "$OUT/tak-default-vs-bounds.txt"
wc -l "$OUT"/* >&2
