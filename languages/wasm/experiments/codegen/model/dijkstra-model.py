#!/usr/bin/env python3
"""WebAssembly side study, codegen experiment: static instruction model of dijkstra.

usage: dijkstra-model.py <dijkstra-counts.jsonl>     (the output of dijkstra-count.c at n1 and n2)

Per-block instruction counts read off disasm/native-dijkstra.full.txt and disasm/wasm-dijkstra.full.txt
(clang 23.1.0 -O2 native, wasmtime 50.0.0 default cwasm; see disasm.sh) are weighted by the dynamic event
counts and summed for main's O(N) loops. Prints the predicted differential and the wasm/native ratio
(lower is better) for setup, heap and total; the study compares it with the measured cell (1.76 predicted).
The constants are tied to those exact binaries. Stdlib only.
"""
# Static per-block instruction counts (read from disasm/native-dijkstra.full.txt and
# disasm/wasm-dijkstra.full.txt, O2 builds) weighted by the dynamic event counts of
# dijkstra-count.c. Prints predicted instructions in main's O(N) loops for both sides.
import json, sys
def native(c):
    N, M = c["N"], c["M"]; P,S,NOE,T,A,B,W,E,I,U,V,Y = (c[k] for k in "P S NOE T A B W E I U V Y".split())
    setup = 19*M + 7*M + 6*N + 12*M + 1*N + 17*N
    heap = (2*P + 6*P + T*(4+4+2) + 4*A + 4*B + 6*W + 9*P + 4*(P-S) + 1*NOE
            + E*(6+3) + I*(6+1) + U*6 + V*4 + Y*1)
    return setup, heap
def wasm(c):
    N, M = c["N"], c["M"]; P,S,NOE,T,A,B,W,E,I,Z,U,V,Y = (c[k] for k in "P S NOE T A B W E I Z U V Y".split())
    setup = 54*M + 33*M/4 + 20*N/4 + 33*M + 24*N/8 + 27*N
    heap = (7*P + T*(5+5+2) + 8*A + 7*B + 8*W + 12*P + 3*S + 7*(P-S) + 3*NOE + 2*(P-S-NOE)
            + 2*P + 3*(P-1)
            + E*(9+3) + I*(7+1) + (I-Z)*1 + U*8 + V*3 + (V-Y)*2)
    return setup, heap
cs = [json.loads(l) for l in open(sys.argv[1])]
r = {}
for c in cs:
    r[c["N"]] = (native(c), wasm(c))
    (ns, nh), (ws, wh) = r[c["N"]]
    print(f"N={c['N']}: native setup {ns:.0f} heap {nh:.0f} total {ns+nh:.0f} | wasm setup {ws:.0f} heap {wh:.0f} total {ws+wh:.0f}")
(a,b) = sorted(r)
dn = [r[b][0][i]-r[a][0][i] for i in (0,1)]; dw = [r[b][1][i]-r[a][1][i] for i in (0,1)]
print(f"differential setup: native {dn[0]:.0f} wasm {dw[0]:.0f} ratio {dw[0]/dn[0]:.3f}")
print(f"differential heap:  native {dn[1]:.0f} wasm {dw[1]:.0f} ratio {dw[1]/dn[1]:.3f}")
print(f"differential total: native {sum(dn):.0f} wasm {sum(dw):.0f} ratio {sum(dw)/sum(dn):.3f}")
