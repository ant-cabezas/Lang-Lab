#!/usr/bin/env python3
"""WebAssembly side study, codegen experiment: static instruction model of polymorphism's dispatch loop.

usage: polymorphism-model.py        (no input; the study ran it inline and saved its output)

Per-dispatch instruction counts read off disasm/{native,wasm}-polymorphism.full.txt (clang 23.1.0 -O2
native, wasmtime 50.0.0 default cwasm; see disasm.sh): native 6 per loop iteration plus 16/16/16/17/17/18
for apply0..apply5; wasm a 4x-unrolled loop of call sites (20, 20, 20, 19 plus an 8-instruction tail) plus
22/22/22/24/24/24. The type mix is the LCG's over the N=10000 objects. The prediction (dispatch loop only,
N x (n2-n1) dispatches) is compared with the measured differentials of the o2 cells, which are constants
here (lang-lab-wasm-codegen-o2, native and wasm rows of raw/o2.txt). Ratio = wasm / native, lower is better.
Expected output: ratio 1.9739 predicted, 1.9738 measured. Stdlib only.
"""
c = [1697, 1663, 1614, 1690, 1623, 1713]; n = sum(c)
nat_apply = [16, 16, 16, 17, 17, 18]; was_apply = [22, 22, 22, 24, 24, 24]
na = sum(a*b for a, b in zip(c, nat_apply))/n; wa = sum(a*b for a, b in zip(c, was_apply))/n
nd = 6+na; wd = (20+20+20+19+8)/4+wa
D = 10000*(200-50)
print(f"native per dispatch {nd:.4f} (loop 6 + apply {na:.4f}); wasm per dispatch {wd:.4f} (loop 21.75 + apply {wa:.4f})")
print(f"predicted differential (dispatch loop only, {D} dispatches): native {nd*D:.0f}  wasm {wd*D:.0f}  ratio {wd/nd:.4f}")
W = 67133430   # published codegen run (results/wasm/2026-10-27-arm64-codegen.json, o2/wasm); an earlier exploratory run gave 67135548
print("measured differential: native 34011776  wasm", W, " ratio", round(W/34011776, 4))
print(f"residual: native {34011776-nd*D:+.0f}  wasm {W-wd*D:+.0f} (150 extra passes of outer-loop overhead + library)")
