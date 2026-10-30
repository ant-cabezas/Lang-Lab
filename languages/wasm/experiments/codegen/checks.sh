#!/usr/bin/env bash
# WebAssembly side study, codegen experiment: identity checks behind the envelope notes.
#
# Inside lang-lab-wasm-codegen-o2, for every module: does the knob/inline cwasm disassemble to the same
# code as the default (`wasmtime objdump`), and is the knob/copt1 cwasm byte-identical to the default?
# Study result, reproduced: "inline:DIFF copt1:same" on all 18 lines. -C inlining=y changes the code, so it
# is measured; -O opt-level=1 produces the default cwasm byte for byte, so copt1 is not measured.
# Bash 3.2 compatible.
set -euo pipefail
docker run --rm lang-lab-wasm-codegen-o2 sh -c 'cd /app; for b in $(ls wasm/*.cwasm | xargs -n1 basename | sed s/.cwasm//); do
  a=$(wasmtime objdump --color never wasm/$b.cwasm | md5sum); i=$(wasmtime objdump --color never knob/inline/$b.cwasm | md5sum)
  c1=$(cmp -s wasm/$b.cwasm knob/copt1/$b.cwasm && echo same || echo diff)
  [ "$a" = "$i" ] && echo "$b inline:same-code copt1:$c1" || echo "$b inline:DIFF copt1:$c1"; done'
