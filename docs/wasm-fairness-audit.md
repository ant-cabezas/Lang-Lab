# WebAssembly side study: fairness audit

Same process as the [matrix fairness audit](fairness-audit.md): triage suspicious cells, language-expert
review, algorithm fairness veto, checksum gate on any fix. This page covers **wasm primary ratios**
(`wasmtime` / `node` vs same-build `native` control) only. Every ratio is wasm instructions over native
instructions: lower is better, 1.00 = no overhead.

Status: **initial pass** (2026-10-28), updated 2026-10-29 (cases 6 and 8). Buckets: **cleared**, **n/a (closed)**, **rejected fix**, **open**.

## Case 1: C# k-nucleotide: n/a (closed)

**Suspicion:** wasm runs the benchmark; native Mono preview.7 throws on `Dictionary<,>.GetAlternateLookup`.

**Verdict:** **n/a with documented reason.** There is no same-engine native cell at the wasm BCL level; a ratio
would compare unlike runtimes. See `languages/wasm/csharp/lane.json` → `na` and `partialControl: true`.

**Rigor action:** Headline geomean excludes the missing benchmark; ‡ marks partial-control lanes in generated tables.

## Case 2: Ruby bigint, mandelbrot, sha256, polymorphism: cleared (target semantics + port cost)

**Suspicion:** wasmtime geomean about 7.2x, with spikes of 28.0x (bigint), 26.1x (mandelbrot) and 23.2x (sha256,
polymorphism) against 3.5x to 14.1x for the other 14 (reverse-complement 14.1x, dijkstra 11.1x).

**Finding:** Dominated by documented asymmetries: Asyncify instrumentation, wasm32 `VALUE` (31-bit integers,
heap objects for most arithmetic), not a checksum bug. `languages/wasm/ruby/alloc.rb` quantifies allocation
explosion vs native.

**Verdict:** **cleared** as an honest wasm32 CRuby port cost. Primary ratio is the right question; matrix gcc
reference belongs in the reference table only (`columnRoles.matrix = reference`).

## Case 3: Swift bigint / gemm / k-means / viterbi († cells): cleared with symbol

**Suspicion:** 11.1x (bigint, unshimmed: explicit `UInt64`), 8.9x (gemm), 8.8x (k-means) and 7.6x (viterbi, the
last three shimmed) against 1.3x to 6.4x for the other 14 Swift cells (reverse-complement 6.4x).

**Finding:** every one of the four hot loops calls `__multi3`: Swift's overflow-checked 64-bit multiply has no wasm
instruction for the high half. The 64-bit multiplies come from the shim (`Int` is 32-bit on wasm32, `int64.sh`
restores the native semantics) in gemm, k-means and viterbi, and from explicit `UInt64` in bigint. Diagnostic
wrapping multiplies remove 86 to 99% of the extra instructions (documented in `lane.json`).

**Verdict:** **cleared.** Table footnote (†) marks shimmed cells; readers must not compare † cells to unshimmed Swift
rows without reading the lane note.

## Case 4: Go k-nucleotide: open (monitor)

**Suspicion:** 6.6x wasmtime, the largest Go cell (the other 17 run 1.7x to 5.3x, geomean 2.98x); k-nucleotide is the
only benchmark built on the language's map. The native Go cell is also the noisiest of the lane (5.4% run-to-run
spread, garbage-collector pacing).

**Finding:** Not yet adversarially audited against Go's wasm map/runtime path; may be real wasip1 runtime cost.

**Next step:** go-expert disassembly or `-trace` style allocation compare wasm vs native on k-nucleotide only.
No source change until fairness review approves.

## Case 5: Rust native column = matrix image: cleared (documented asymmetry)

**Finding:** Native column is the matrix aarch64 binary; wasm is wasm32. Ratio mixes ISA change with wasm lowering.

**Verdict:** **cleared** with lane asymmetry text; Rust headline compares “matrix native aarch64” to wasm, same as
today's study question for compiled languages without a separate clang native rebuild.

## Case 6: Go on V8 between runs: explained and fixed

**Suspicion:** an independent re-measurement moved single Go V8 cells by up to 12.9% (sha256; tak and bigint about
7%) while each run's own repetitions agree to within 0.17%; C, C# and Java reproduce to a few thousandths of a
percent (`results/wasm/2026-10-28-arm64-replication.json`).

**Finding:** not the build (byte-identical modules across two image builds) but Go's runtime seed from WASI
`random_get`, which moves the V8 process by about 9.5 million instructions in discrete levels; each repetition drew
its own seed. With the seed fixed the differential reproduces to 12 instructions.

**Verdict:** **fixed.** `run-node.mjs` returns a fixed byte stream from `random_get`; the V8 column of every lane was
re-measured with it. wasmtime has no equivalent option (Go on wasmtime moved at most 0.7%).

## Case 7: VB.NET k-nucleotide and sha256 on V8: explained

**Suspicion:** V8 costs 1.66x and 1.48x what wasmtime does on these two cells, at most 1.35x elsewhere.

**Finding:** lazy TurboFan compilation of about 127 Mono runtime functions first called only at the larger size
lands inside the differential; `--no-wasm-lazy-compilation` brings both to 1.25x and 1.30x wasmtime. Details in
`languages/wasm/vbnet/lane.json` (`diagnostics.v8LazyCompile`).

**Verdict:** **cleared** (a property of lazy compilation in the V8 column, documented on the study page).

## Case 8: Scala dijkstra on V8 between sessions: explained

**Suspicion:** after the `random_get` fix the cell moved by 0.27% (65,550,712 to 65,373,165 instructions), more than
any other cell outside Go and Swift, although each run's repetitions agree to within 0.0004%.

**Finding:** not the seed (the TeaVM module imports no `random_get`) and not the build: the same cell on wasmtime
reproduces the 2026-10-27 value to 194 instructions. Eight V8 measurements on 2026-10-29 with the shipped `run-node.mjs`
(the re-measure and seven checks) gave 65,251,892 to 65,407,630, and the spread follows how the process is launched:
identical invocations agree to within about 1,700 instructions, while changing the driver's file name, its text or the
container launch moves the count by 34,000 to 149,000. A fixed `clock_time_get` changes nothing. Launched the way the
study launches it, a driver without the `random_get` override (the 2026-10-27 condition, rebuilt from the current
file) gives 65,259,047 and the shipped one 65,407,630.

**Cause:** the timing of V8's young-generation collections. Most likely a little more or less startup state shifts
where the scavenges fall, and one scavenge more or fewer between the two sizes moves the differential. With a 64 MB
young generation (`--min-semi-space-size=64`) every variant above (both drivers, two file names, two launch
shapes) gives 65,296,144 to 65,297,064 instructions, a spread of 920. The exact 2026-10-27 value (65,550,712) was not
reproduced, since the original pre-fix file is not kept.

**Verdict:** **explained; kept as measured.** The published cell uses the same flags as every other V8 cell; fixing
the young-generation size for one lane would make it unlike the others. Across all these sessions the ratio stays
between 1.871 and 1.879 (lower is better; published 1.874), well inside the lane's spread across benchmarks; no
other JVM-language cell moved by more than 0.05%.

---

New cases land here with date, bucket, and envelope date. Fixes that touch benchmark sources follow the matrix
rule: **algo-expert fairness review before merge.**
