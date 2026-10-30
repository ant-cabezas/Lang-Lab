# WebAssembly side study

**Status: a side study, outside the ranking.** Nothing here is in `languages.json`, the matrix or the README
leaderboard, and no published number comes from CI (CI only runs a smoke check of the harness on an arm64
runner). Every ratio on this page is `wasm differential / native differential` for the **same
language, the same source and (wherever a toolchain allows it) the same compiler version**: **lower is better**,
1.00 = no overhead over the native build of that language. A ratio says what compiling a language to
WebAssembly costs that language; it is never a cross-language ranking.

The tables are generated from `results/wasm/` by `python3 scripts/make_wasm_tables.py --write` (never
hand-edited). The per-language data comes from `scripts/wasm-study.sh`; the study-level experiments (runtime and
compiler sweeps, code-generation knobs, jitter, wall-clock) come from `languages/wasm/experiments/`.

## What this measures, and what it does not

- It measures how many **guest instructions** a WebAssembly build of each benchmark spends compared with the
  native build of the same program, with the matrix backend (qemu-user + the TCG `insn` plugin, differential
  `I(n2) - I(n1)` at each benchmark's own spec sizes, checksum gate on every run). Startup and module compilation
  cancel in the differential, and so does V8's lazy compilation of every function both sizes call; code reached
  only at the larger size is compiled inside the differential (see the VB.NET note).
- WebAssembly is not executed directly. It is compiled to aarch64 by a runtime, so every wasm number is a
  property of **a toolchain plus a runtime**. The study uses two runtimes: **wasmtime 50.0.0 (Cranelift)**, the
  reference standalone runtime, and **Node 26.5.0 (V8 14.6, TurboFan tier)**, the browser engine family. The
  tier matters: see [V8 tiers](#v8-only-one-tier-is-a-fair-column).
- All counts are aarch64 guest instructions on one machine configuration. Instruction counts are blind to
  syscalls, to memory stalls and to dependency-chain latency; the [wall-clock check](#instructions-versus-time)
  measures how far they can be trusted for this question (answer: direction yes, per-benchmark size no).
- Geomeans of different languages cover **different benchmark sets** whenever a language has n/a cells, and
  they come from **different engines** for the languages whose wasm route is not their matrix runtime (labelled
  in every table: C# and VB.NET run on Mono, JavaScript on QuickJS-ng, Java/Kotlin/Scala through TeaVM). They
  are not comparable across languages and not comparable with the matrix.
- `message-ring` and the `-par` scaling sources are excluded: WASI preview 1 has no threads.

## Method

Each language is a **lane**: `languages/wasm/<lang>/Dockerfile` builds an image `FROM lang-lab-wasm-base` that
holds the wasm build of every benchmark and, where the matrix image cannot serve as the native control, a native
build made with the same compiler. `languages/wasm/<lang>/lane.json` declares the columns (native, wasmtime, V8
and any extra controls), their run templates, the environment, every source transform and every known asymmetry
between the two builds. `scripts/wasm-study.sh` builds the images and measures every (lane, column, benchmark)
cell with the matrix's `measure.sh` (median of 2 runs when exact, 5 when the count jitters).

Fairness rules every lane follows:

1. **The canonical benchmark sources are never edited.** When a language's wasm target needs a change to
   compute the same thing, it is a build-time transform, documented in the lane, applied to the wasm build and
   (where it could change native cost) to a native control column as well.
2. **Same compiler on both sides** wherever the toolchain allows it; otherwise the asymmetry is listed in
   `lane.json` and in the per-language notes below.
3. **Same optimisation level on both sides.** The wasm side only adds what WASI needs (for C: an 8 MiB stack,
   the native default).
4. Every cell passes the spec checksum gate at both sizes, or it is n/a with the error recorded.

Binding definitions (**primary vs reference ratio**, coverage, spread, tiers): [`wasm-rigor.md`](wasm-rigor.md).
Each lane's `lane.json` includes **`columnRoles`** (`control`, `wasm`, `reference`, `check`) so generated tables
never mix matrix/CoreCLR/gcc reference columns into the headline geomean.

wasmtime modules are precompiled (`wasmtime compile`) when the lane image is built, so Cranelift targets the CPU
features of the machine that builds the image, which is the machine that measures it.

### The shared base image (exact pins)

`languages/wasm/Dockerfile.base`, `FROM gcc:14` (the matrix C image), every download sha256-verified:

| Component | Version | Role |
|---|---|---|
| wasi-sdk | 34 (clang 23.1.0) | C and C-based runtimes to `wasm32-wasip1` |
| LLVM | 23.1.0 official release | the native control compiler for C (same clang version as wasi-sdk 34) |
| wasmtime | 50.0.0 | runtime column 1; `.cwasm` precompiled at image build time |
| Node | 26.5.0 (V8 14.6) | runtime column 2, through `languages/wasm/run-node.mjs` (`node:wasi`, preview 1) |
| qemu + insn plugin | from `lang-lab-qemu-insn` | the matrix measurement backend |

### Runtime configuration (binding for every lane)

- **wasmtime:** `wasmtime run -C cache=n --allow-precompiled <module>.cwasm` with `TOKIO_WORKER_THREADS=1`.
  wasmtime runs 8 guest threads (the main thread, tokio's worker pool and a compiled-module cache worker); these two
  settings leave 2 threads and cut
  the worst per-size run-to-run spread about 13x at the small size and 7x at the large size (see
  [measurement noise](#measurement-noise)); on wasmtime 50 they move no differential by more than 0.02%.
- **V8:** `node --predictable --single-threaded --single-threaded-gc --no-liftoff run-node.mjs <module>.wasm`, with
  `UV_THREADPOOL_SIZE=1` from the base image (as in the matrix's Node cell). `run-node.mjs` answers WASI
  `random_get` with a fixed pseudo-random byte stream, the same in every run (see [replication](#replication));
  wasmtime has no such option, so its modules still receive OS randomness.
  `--no-liftoff` is not optional; see [V8 tiers](#v8-only-one-tier-is-a-fair-column).

## A trap in the C sources: wasm32 is ILP32

The C benchmarks assume LP64 (`long` is 64 bits), which holds on every native target the matrix uses. wasm32 is
ILP32: `long` is 32 bits. Compiled unchanged, **13 of the 18 C benchmarks are wrong on wasm**, with no warning
from the compiler: 12 print a wrong checksum and dijkstra traps (the list is in `languages/wasm/c/lane.json`). `languages/wasm/c/lp64.sh` fixes this at build time without touching the
canonical sources: `#define long long long` after the last `#include` (so system headers keep their own types),
`%ld`/`%lu`/`%li` to `%lld`/`%llu`/`%lli`, and `L`/`UL` literal suffixes to `LL`/`ULL` (dijkstra's `1L << 62`
is otherwise a 32-bit shift).

The C lane proves the transform does not change the work: the transformed source is also compiled natively
(column `clang-lp64`). It differs from the canonical native build by 0 to 11 instructions per differential (at
most about 3e-7 relative, in either direction), not zero. The canonical native binary itself moves by a similar
handful of instructions between image builds (polymorphism: 34,011,776 in one build, 34,011,787 in another), so
the difference is at the noise floor of a rebuild, not a cost of the transform; the
[C table](#c-in-detail) prints the exact difference for every benchmark.

## Results

### Headline: what wasm costs each language

Ratio of the geomean over the benchmarks each language measures; lower is better. Read the coverage column
before comparing two rows.

<!-- WASM-HEADLINE:START -->
Primary ratios only (`wasmtime` / `node` vs **same-build** `native` control). [Rigor definitions](wasm-rigor.md).

| Language | Benchmarks measured | wasmtime 50 / native | V8 TurboFan / native | Cheapest on wasmtime | Most expensive on wasmtime |
|---|---:|---:|---:|---|---|
| Rust | 18 of 18 | **1.46x** | 1.46x | bigint 0.79x | gemm 2.63x |
| C | 18 of 18 | **1.53x** | 1.56x | bigint 1.00x | gemm 2.61x |
| VB.NET (Mono) | 18 of 18 | **1.96x** | 2.46x | binary-trees 1.72x | sha256 2.15x |
| JavaScript (QuickJS-ng) | 18 of 18 | **1.99x** | 2.36x | binary-trees 1.79x | mandelbrot 2.24x |
| C# (Mono) ‡ | 17 of 18, 1 n/a | **2.01x** | 2.55x | binary-trees 1.69x | k-means 2.25x |
| PHP | 18 of 18 | **2.04x** | 2.65x | binary-trees 1.84x | k-means 2.28x |
| Python (CPython) | 18 of 18 | **2.09x** | 2.41x | polymorphism 1.86x | lz77 2.19x |
| Swift | 18 of 18 | **2.99x** | 3.14x | binary-trees 1.30x | bigint 11.1x |
| Go | 18 of 18 | **3.12x** | 4.04x | mandelbrot 1.72x | k-nucleotide 6.64x |
| Ruby (CRuby) | 18 of 18 | **7.19x** | 8.72x | binary-trees 3.51x | bigint 28.0x |

‡ Native control does not measure every benchmark (see `lane.json` → `na`). Geomean is over the wasm cells that have a ratio only.
**Ruby (CRuby):** primary ratios include Asyncify and wasm32 `VALUE` semantics (heap 32-bit); not comparable to the matrix gcc reference without reading the reference table.
<!-- WASM-HEADLINE:END -->

### Reference columns (not primary wasm overhead)

Each reference column divided by the lane's native control: lower is better (fewer instructions than that
control). Context only, never part of the wasm ratios.

<!-- WASM-HEADLINE-REFERENCE:START -->
Reference columns only (not primary wasm overhead). [Rigor definitions](wasm-rigor.md).

| Language | Column | / native control | measured | Role (from lane) |
|---|---|---:|---:|---|
| C | `gcc` | 1.26x | 18 | reference: the matrix C baseline (gcc 14 -O2, the same gcc:14 image a... |
| C# (Mono) | `coreclr` | 0.12x | 17 | reference: the matrix runtime (CoreCLR 9.0.22, RyuJIT, TieredCompilat... |
| C# (Mono) | `mono-jit` | 0.29x | 17 | context: the same Mono build as the native column but with its defaul... |
| PHP | `matrix` | 0.80x | 18 | reference: the matrix image php:8.4.8-cli (gcc, HYBRID VM with global... |
| Python (CPython) | `matrix` | 1.07x | 18 | reference: the matrix image (official CPython build, gcc with PGO, LT... |
| Ruby (CRuby) | `matrix` | 1.41x | 18 | reference: the matrix Ruby cell (ruby:3.3-slim = CRuby 3.3.13, gcc -O... |
| Swift | `native-shim` | 1.00x | 11 | control: the 11 shimmed sources (int64.sh) compiled natively, measure... |
| VB.NET (Mono) | `coreclr` | 0.13x | 18 | reference: the matrix runtime (CoreCLR 9.0.22, RyuJIT, TieredCompilat... |
| VB.NET (Mono) | `mono-jit` | 0.51x | 18 | context: the same Mono build as the native column but with its defaul... |
<!-- WASM-HEADLINE-REFERENCE:END -->

### Measurement spread (primary cells)

Largest run-to-run spread, `(max - min) / median` of I(n1) or I(n2) over the runs: lower is better, 0 = bit-exact.

<!-- WASM-SPREAD:START -->
Worst **maxSpreadPct** per language among primary cells (`native`, `wasmtime`, `node` at both sizes). 0 = bit-exact; larger values used median of 5 runs.

| Language | Benchmark | Column | maxSpreadPct |
|---|---|---|---:|
| C | fannkuch | wasmtime | 0.01308 |
| C# (Mono) | mandelbrot | native | 0.00262 |
| Go | k-nucleotide | native | 5.41404 |
| Java (TeaVM) | tak | wasmtime | 0.01126 |
| JavaScript (QuickJS-ng) | tak | wasmtime | 0.00148 |
| Kotlin (TeaVM) | polymorphism | node | 0.01173 |
| PHP | fannkuch | wasmtime | 0.00118 |
| Python (CPython) | tak | wasmtime | 0.00218 |
| Ruby (CRuby) | binary-trees | wasmtime | 0.85465 |
| Rust | k-nucleotide | native | 0.07008 |
| Scala (TeaVM) | tak | wasmtime | 0.00714 |
| Swift | k-nucleotide | wasmtime | 0.48434 |
| VB.NET (Mono) | sort-search | native | 0.00309 |
<!-- WASM-SPREAD:END -->

### Per benchmark, wasmtime 50 (Cranelift)

`wasm differential / native differential`, lower is better.

<!-- WASM-WASMTIME:START -->
| Benchmark | Rust | C | VB.NET (Mono) | JavaScript (QuickJS-ng) | C# (Mono) | PHP | Python (CPython) | Swift | Go | Ruby (CRuby) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 0.79x | 1.00x | 1.89x | 1.96x | 2.01x | 2.17x | 2.08x | 11.1x | 2.72x | 28.0x |
| binary-trees | 1.34x | 1.02x | 1.72x | 1.79x | 1.69x | 1.84x | 1.96x | 1.30x | 3.71x | 3.51x |
| blur | 1.05x | 1.28x | 1.97x | 2.02x | 2.12x | 2.12x | 2.07x | 3.46x | 5.26x | 4.32x |
| dijkstra | 1.34x | 1.76x | 1.99x | 1.95x | 2.19x | 2.06x | 2.10x | 1.91x† | 2.68x | 11.1x |
| fannkuch | 1.58x | 1.71x | 1.75x | 2.06x | 1.71x | 1.98x | 2.11x | 1.58x | 3.03x | 3.76x |
| gbdt | 1.47x | 1.31x | 1.97x | 1.96x | 2.00x | 2.11x | 2.13x | 2.91x† | 3.37x | 3.68x |
| gemm | 2.63x | 2.61x | 1.91x | 2.00x | 2.01x | 2.14x | 2.17x | 8.94x† | 2.78x | 4.16x |
| k-means | 1.50x | 1.62x | 1.90x | 2.01x | 2.25x | 2.28x | 2.16x | 8.77x† | 3.21x | 4.10x |
| k-nucleotide | 1.62x | 1.69x | 2.11x | 1.86x | n/a | 2.02x | 2.10x | 2.23x | 6.64x | 3.61x |
| lz77 | 1.13x | 1.32x | 1.93x | 2.02x | 1.95x | 2.06x | 2.19x | 1.70x† | 3.46x | 4.55x |
| mandelbrot | 1.46x | 1.46x | 2.12x | 2.24x | 2.12x | 2.12x | 2.09x | 1.46x | 1.72x | 26.1x |
| polymorphism | 2.08x | 1.97x | 2.03x | 2.04x | 2.09x | 1.95x | 1.86x | 3.25x† | 3.81x | 23.2x |
| reverse-complement | 1.74x | 1.73x | 2.05x | 2.11x | 2.11x | 2.03x | 2.14x | 6.43x† | 2.69x | 14.1x |
| sha256 | 1.54x | 1.53x | 2.15x | 1.97x | 2.13x | 1.99x | 2.09x | 1.56x† | 1.83x | 23.2x |
| sort-search | 1.48x | 1.37x | 1.93x | 2.04x | 1.94x | 1.98x | 2.17x | 2.12x† | 2.98x | 7.29x |
| tak | 1.21x | 1.57x | 2.04x | 2.02x | 2.02x | 1.85x | 1.96x | 1.65x | 3.84x | 4.07x |
| viterbi | 1.42x | 1.71x | 1.95x | 1.97x | 1.99x | 2.12x | 2.10x | 7.57x† | 3.15x | 4.79x |
| vm | 1.77x | 1.53x | 1.91x | 1.82x | 2.00x | 1.88x | 2.08x | 2.21x† | 2.21x | 5.04x |
| **geomean** | **1.46x** | **1.53x** | **1.96x** | **1.99x** | **2.01x** | **2.04x** | **2.09x** | **2.99x** | **3.12x** | **7.19x** |

† Swift: wasm built with the Int64 shim (int64.sh); the unmarked Swift cells run the unmodified source with wasm32's native 32-bit Int.
<!-- WASM-WASMTIME:END -->

### Per benchmark, V8 TurboFan (Node 26.5.0, `--no-liftoff`)

`wasm differential / native differential`, lower is better.

<!-- WASM-V8:START -->
| Benchmark | Rust | C | JavaScript (QuickJS-ng) | Python (CPython) | VB.NET (Mono) | C# (Mono) | PHP | Swift | Go | Ruby (CRuby) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 1.25x | 1.42x | 2.38x | 2.38x | 2.31x | 2.62x | 2.83x | 15.5x | 3.72x | 30.4x |
| binary-trees | 1.20x | 0.98x | 1.96x | 2.22x | 2.32x | 2.30x | 2.32x | 1.19x | 6.46x | 4.19x |
| blur | 1.01x | 1.33x | 2.43x | 2.40x | 2.38x | 2.72x | 2.76x | 3.17x | 3.96x | 5.32x |
| dijkstra | 1.33x | 1.77x | 2.39x | 2.49x | 2.41x | 2.68x | 2.99x | 2.19x† | 22.9x | 12.7x |
| fannkuch | 1.77x | 2.27x | 2.59x | 2.65x | 2.13x | 2.10x | 2.65x | 1.68x | 4.62x | 5.16x |
| gbdt | 1.48x | 1.49x | 2.42x | 2.44x | 2.37x | 2.52x | 2.76x | 3.10x† | 3.21x | 4.89x |
| gemm | 2.53x | 3.29x | 2.42x | 2.48x | 2.24x | 2.53x | 2.65x | 11.6x† | 2.63x | 5.68x |
| k-means | 1.42x | 1.60x | 2.52x | 2.43x | 2.26x | 2.90x | 2.86x | 11.3x† | 3.05x | 5.58x |
| k-nucleotide | 1.85x | 1.60x | 2.07x | 2.31x | 3.50x | n/a | 2.50x | 2.08x | 9.17x | 4.19x |
| lz77 | 1.30x | 1.51x | 2.52x | 2.46x | 2.35x | 2.50x | 2.68x | 1.56x† | 3.23x | 6.17x |
| mandelbrot | 1.17x | 1.12x | 2.64x | 2.73x | 2.74x | 2.77x | 2.83x | 1.07x | 2.02x | 27.6x |
| polymorphism | 2.85x | 2.44x | 2.33x | 2.00x | 2.40x | 2.53x | 2.44x | 3.41x† | 4.15x | 24.8x |
| reverse-complement | 1.37x | 1.36x | 2.53x | 2.38x | 2.45x | 2.57x | 2.63x | 8.39x† | 3.67x | 16.0x |
| sha256 | 1.42x | 1.37x | 2.19x | 2.34x | 3.18x | 2.77x | 2.73x | 1.41x† | 1.93x | 25.3x |
| sort-search | 1.29x | 1.31x | 2.54x | 2.55x | 2.34x | 2.39x | 2.66x | 2.01x† | 3.72x | 8.83x |
| tak | 0.86x | 1.12x | 2.30x | 2.23x | 2.61x | 2.59x | 2.32x | 1.41x | 5.08x | 5.23x |
| viterbi | 1.45x | 1.53x | 2.35x | 2.43x | 2.33x | 2.50x | 2.77x | 10.0x† | 3.35x | 6.22x |
| vm | 1.82x | 1.87x | 2.09x | 2.63x | 2.34x | 2.51x | 2.46x | 2.53x† | 2.91x | 6.01x |
| **geomean** | **1.46x** | **1.56x** | **2.36x** | **2.41x** | **2.46x** | **2.55x** | **2.65x** | **3.14x** | **4.04x** | **8.72x** |

† Swift: wasm built with the Int64 shim (int64.sh); the unmarked Swift cells run the unmodified source with wasm32's native 32-bit Int.
<!-- WASM-V8:END -->

### C lane: V8 TurboFan vs Liftoff vs wasmtime (tiering experiment)

<!-- WASM-V8-LIFTOFF:START -->
| Benchmark | TurboFan (--no-liftoff), the study's V8 column | Liftoff only (base flags) | wasmtime 50 (reference) |
|---|---:|---:|---:|
| bigint | 1.417 | 3.131 | 1.001 |
| binary-trees | 0.978 | 0.912 | 1.018 |
| blur | 1.327 | 2.716 | 1.276 |
| dijkstra | 1.767 | 4.080 | 1.761 |
| fannkuch | 2.274 | 4.171 | 1.706 |
| gbdt | 1.493 | 2.472 | 1.309 |
| gemm | 3.293 | 8.260 | 2.610 |
| k-means | 1.596 | 3.329 | 1.621 |
| k-nucleotide | 1.609 | 2.744 | 1.686 |
| lz77 | 1.513 | 3.237 | 1.321 |
| mandelbrot | 1.124 | 3.040 | 1.463 |
| polymorphism | 2.436 | 4.906 | 1.974 |
| reverse-complement | 1.359 | 2.924 | 1.729 |
| sha256 | 1.374 | 5.442 | 1.531 |
| sort-search | 1.312 | 2.541 | 1.367 |
| tak | 1.125 | 1.136 | 1.565 |
| viterbi | 1.528 | 2.603 | 1.710 |
| vm | 1.873 | 3.389 | 1.534 |
| **geomean** | **1.562** | **3.036** | **1.528** |

C lane only. **A** = TurboFan (`--no-liftoff`, the study's binding V8 column). **B** = Liftoff-only (pessimistic tier). **wt** = wasmtime 50 for the same modules.
<!-- WASM-V8-LIFTOFF:END -->

### Java, Kotlin and Scala through TeaVM

There is no maintained route from JVM bytecode to WASI with a matching native build, except TeaVM 0.13.1 (its
WASI backend was removed in 0.14, so this is a frozen toolchain). TeaVM is an ahead-of-time compiler, not the
JVM: the native control is TeaVM's own C backend built with clang 23.1.0 `-O2`, and these rows say nothing about
the matrix's HotSpot cells. Each benchmark is compiled once to class files (javac `--release 25`, because TeaVM
0.13.1 rejects Java 26 class files; kotlinc 2.1.0; Scala 3.6.2), and the same class files go to `teavm -t C` and
`teavm -t wasi` with the same options (`-O 3`, heap 32 to 512 MB). The ratio therefore mixes two TeaVM backends:
the C one goes through LLVM, the wasm one is TeaVM's own emitter with no LLVM or Binaryen. TeaVM's output is not
byte-reproducible between builds of the same input (one of the compared modules differed). The TeaVM options were
checked on Java (six benchmarks, same options on both backends): doubling the heap moves the geomean by 1.2%, while
`-O 2` or `-O 1` raise it by 31% and 20% (mostly k-nucleotide and sha256), so the shipped `-O 3` is the setting most
favourable to wasm among those tried (`languages/wasm/java/lane.json`, `diagnostics`). Scala fannkuch is n/a:
both backends fail on `scala.runtime.ClassValueCompat` (a native `Class.initializeImpl` with no TeaVM
implementation), reached from `Array.tabulate`. Lower is better.

<!-- WASM-TEAVM:START -->
Primary ratios only (`wasmtime` / `node` vs **same-build** `native` control). [Rigor definitions](wasm-rigor.md).

| Language | Benchmarks measured | wasmtime 50 / native | V8 TurboFan / native | Cheapest on wasmtime | Most expensive on wasmtime |
|---|---:|---:|---:|---|---|
| Scala (TeaVM) | 17 of 18, 1 n/a | **1.85x** | 2.05x | lz77 1.21x | k-means 2.87x |
| Kotlin (TeaVM) | 18 of 18 | **1.88x** | 2.02x | lz77 1.21x | k-means 3.00x |
| Java (TeaVM) | 18 of 18 | **1.88x** | 2.00x | lz77 1.21x | k-means 3.00x |

‡ Native control does not measure every benchmark (see `lane.json` → `na`). Geomean is over the wasm cells that have a ratio only.
**Ruby (CRuby):** primary ratios include Asyncify and wasm32 `VALUE` semantics (heap 32-bit); not comparable to the matrix gcc reference without reading the reference table.

Per benchmark, wasmtime 50:

| Benchmark | Scala (TeaVM) | Kotlin (TeaVM) | Java (TeaVM) |
|---|---:|---:|---:|
| bigint | 1.55x | 1.55x | 1.55x |
| binary-trees | 2.06x | 2.00x | 1.93x |
| blur | 2.30x | 2.30x | 2.30x |
| dijkstra | 1.71x | 1.72x | 1.67x |
| fannkuch | n/a | 1.83x | 1.85x |
| gbdt | 1.75x | 1.51x | 1.51x |
| gemm | 2.16x | 2.16x | 2.16x |
| k-means | 2.87x | 3.00x | 3.00x |
| k-nucleotide | 2.52x | 2.65x | 2.64x |
| lz77 | 1.21x | 1.21x | 1.21x |
| mandelbrot | 1.42x | 1.42x | 1.42x |
| polymorphism | 1.99x | 1.96x | 1.99x |
| reverse-complement | 2.12x | 2.53x | 2.44x |
| sha256 | 1.54x | 1.62x | 1.64x |
| sort-search | 2.02x | 2.07x | 2.12x |
| tak | 1.65x | 1.53x | 1.53x |
| viterbi | 2.05x | 2.11x | 2.11x |
| vm | 1.37x | 1.59x | 1.69x |
| **geomean** | **1.85x** | **1.88x** | **1.88x** |

Per benchmark, V8 TurboFan:

| Benchmark | Java (TeaVM) | Kotlin (TeaVM) | Scala (TeaVM) |
|---|---:|---:|---:|
| bigint | 1.64x | 1.64x | 1.61x |
| binary-trees | 2.38x | 2.40x | 2.55x |
| blur | 1.97x | 1.97x | 1.97x |
| dijkstra | 1.59x | 1.60x | 1.87x |
| fannkuch | 1.88x | 1.83x | n/a |
| gbdt | 2.28x | 2.28x | 2.33x |
| gemm | 2.54x | 2.54x | 2.54x |
| k-means | 3.52x | 3.52x | 4.36x |
| k-nucleotide | 2.38x | 2.35x | 2.38x |
| lz77 | 1.33x | 1.33x | 1.41x |
| mandelbrot | 1.24x | 1.24x | 1.24x |
| polymorphism | 2.66x | 2.69x | 2.66x |
| reverse-complement | 2.64x | 2.72x | 2.30x |
| sha256 | 1.54x | 1.54x | 1.56x |
| sort-search | 1.95x | 2.22x | 2.05x |
| tak | 1.28x | 1.28x | 1.50x |
| viterbi | 2.60x | 2.60x | 2.67x |
| vm | 2.10x | 2.06x | 1.61x |
| **geomean** | **2.00x** | **2.02x** | **2.05x** |
<!-- WASM-TEAVM:END -->

### C in detail

Native control: clang 23.1.0 `-O2` (official LLVM release). Wasm: wasi-sdk 34 clang 23.1.0 `-O2` on the
`lp64.sh` source. The gcc 14 column is the matrix C baseline, shown for reference (gcc is not the same compiler,
so it is not the control). Ratios: lower is better.

<!-- WASM-C:START -->
| Benchmark | clang 23 native (instructions) | gcc 14 / clang | lp64 transform / clang | wasmtime / clang | V8 / clang |
|---|---:|---:|---:|---:|---:|
| bigint | 33,360,988 | 1.00x | identical | 1.00x | 1.42x |
| binary-trees | 826,254,653 | 0.93x | identical | 1.02x | 0.98x |
| blur | 8,016,629 | 4.54x | identical | 1.28x | 1.33x |
| dijkstra | 15,248,621 | 1.09x | -4 instr | 1.76x | 1.77x |
| fannkuch | 85,310,391 | 0.97x | identical | 1.71x | 2.27x |
| gbdt | 225,930,045 | 1.49x | -7 instr | 1.31x | 1.49x |
| gemm | 45,958,402 | 2.27x | identical | 2.61x | 3.29x |
| k-means | 21,750,231 | 2.03x | identical | 1.62x | 1.60x |
| k-nucleotide | 5,792,875 | 1.42x | identical | 1.69x | 1.60x |
| lz77 | 37,311,671 | 0.92x | +11 instr | 1.32x | 1.51x |
| mandelbrot | 16,251,320 | 0.86x | identical | 1.46x | 1.12x |
| polymorphism | 34,011,787 | 1.04x | -11 instr | 1.97x | 2.44x |
| reverse-complement | 10,200,105 | 1.10x | identical | 1.73x | 1.36x |
| sha256 | 22,785,026 | 1.09x | identical | 1.53x | 1.37x |
| sort-search | 52,255,210 | 1.01x | identical | 1.37x | 1.31x |
| tak | 47,195,172 | 1.04x | identical | 1.57x | 1.12x |
| viterbi | 27,779,934 | 1.79x | identical | 1.71x | 1.53x |
| vm | 194,400,000 | 0.85x | identical | 1.53x | 1.87x |
| **geomean** | | **1.26x** | | **1.53x** | **1.56x** |
<!-- WASM-C:END -->

## Where the overhead comes from (C, wasmtime 50)

Two benchmarks were taken apart instruction by instruction in the disassembly of the native binary and of the
Cranelift `.cwasm`, then the per-block counts were weighted by dynamic event counts and checked against the
measured differentials.

**Bounds checks are not the cost.** In the default configuration no linear-memory access in either benchmark
is preceded by a compare against a bound: accesses are plain `ldr`/`str [heapbase, wN, uxtw]` and an
out-of-bounds access is caught by guard pages. Turning the guard pages off forces explicit checks and costs a
lot (geomean 1.53x to 2.31x, see the [code-generation table](#compiler-and-runtime-options)); in the shipped
configuration the checks are absent.

**polymorphism** (megamorphic virtual call): native spends **22.674 instructions per dispatch**, wasm
**44.756** (measured differential over the 1.5 million dispatches it contains). A per-block model built from
the disassembly predicts 22.674 and 44.755, a ratio of 1.9739; the measured ratio is 1.9738 (native
34,010,850 predicted vs 34,011,776 measured; wasm 67,132,800 vs 67,133,430). The call sequence grows from 6
instructions per dispatch to 21.75 (the four call sites are unrolled, so the loop overhead is shared). What it
adds: the `call_indirect` table bounds check with its Spectre-safe `csel`, the lazy table-initialisation tag strip
and null check, the signature check, loading the code pointer and the callee and caller context, 32-bit address
arithmetic and zero-extension, and a spill and reload of the accumulator. The callee adds 6.33 per dispatch:
frame push and pop, loading the heap base from the context, the base-plus-offset address add, and a shift that
native folds into an addressing mode.

**dijkstra** (everything inlined into `main` on both sides): predicted 1.759, measured 1.761. There are no
bounds checks in any loop. The extra instructions are 32-bit address adds that native folds into a scaled
64-bit addressing mode (relaxation: 9 instructions per edge native, 12 wasm; sift-down step: 24 vs 35), and
loop-invariant constants that Cranelift rematerialises every iteration instead of keeping in a register (edge
generation: 19 vs 54, of which 22 are `mov`/`movk` constant rebuilds and 2 are explicit divide-by-zero trap
checks), plus spills where register pressure is higher (CSR fill: 12 vs 33). The per-iteration counts are read from the
disassembly that `languages/wasm/experiments/codegen/disasm.sh` reproduces; the dynamic weights and the prediction
are in `codegen/model/`.

In short: the wasm tax on this machine is **indirect-call checking, 32-bit address arithmetic and weaker
register allocation**, not memory safety checks.

## Compiler and runtime options

Each wasm column divided by its symmetric native clang 23.1.0 control (`-O3` by `-O3`, everything else by
`-O2`). Lower is better. Measured with the binding wasmtime configuration; an earlier run with wasmtime's
default threads gave the same geomeans to four decimals (no cell moved by more than 0.02%).

<!-- WASM-CODEGEN:START -->
| Benchmark | -O2 | -O3 (vs native -O3) | -O2 + wasm-opt -O3 | -O2 -msimd128 | explicit bounds checks | no signal-based traps | eager table init | Cranelift opt-level=0 | Cranelift inlining on |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 1.001 | 1.001 | 1.001 | 1.001 | 1.709 | 2.000 | 1.001 | 1.293 | 1.084 |
| binary-trees | 1.018 | 1.027 | 0.926 | 1.018 | 1.437 | 1.420 | 1.018 | 1.206 | 0.910 |
| blur | 1.276 | 1.268 | 1.256 | 1.276 | 2.345 | 2.372 | 1.276 | 1.378 | 1.258 |
| dijkstra | 1.761 | 1.698 | 1.749 | 1.760 | 2.976 | 3.034 | 1.761 | 1.873 | 1.751 |
| fannkuch | 1.706 | 1.706 | 1.683 | 1.696 | 2.623 | 2.813 | 1.706 | 2.038 | 1.740 |
| gbdt | 1.309 | 1.309 | 1.362 | 1.309 | 2.652 | 2.878 | 1.309 | 1.800 | 1.349 |
| gemm | 2.610 | 2.610 | 2.611 | 2.453 | 5.349 | 5.833 | 2.610 | 3.412 | 2.934 |
| k-means | 1.621 | 1.621 | 1.621 | 1.588 | 2.742 | 2.762 | 1.621 | 1.784 | 1.627 |
| k-nucleotide | 1.686 | 1.723 | 1.691 | 1.686 | 2.838 | 2.783 | 1.686 | 2.060 | 1.692 |
| lz77 | 1.321 | 1.134 | 1.212 | 1.321 | 1.928 | 1.867 | 1.321 | 1.329 | 1.212 |
| mandelbrot | 1.463 | 1.463 | 1.454 | 1.463 | 1.463 | 1.463 | 1.463 | 1.221 | 1.454 |
| polymorphism | 1.974 | 1.974 | 1.974 | 1.974 | 2.636 | 2.834 | 1.808 | 1.831 | 1.996 |
| reverse-complement | 1.729 | 1.729 | 1.706 | 1.729 | 2.200 | 2.303 | 1.729 | 1.582 | 1.700 |
| sha256 | 1.531 | 1.487 | 1.551 | 1.496 | 2.225 | 2.232 | 1.531 | 1.611 | 1.530 |
| sort-search | 1.367 | 1.367 | 1.363 | 1.367 | 2.246 | 2.163 | 1.367 | 1.450 | 1.369 |
| tak | 1.565 | 1.565 | 1.565 | 1.565 | 1.503 | 1.565 | 1.565 | 1.825 | 1.565 |
| viterbi | 1.710 | 1.710 | 1.637 | 1.710 | 2.647 | 2.533 | 1.709 | 1.802 | 1.695 |
| vm | 1.534 | 1.534 | 1.562 | 1.534 | 2.216 | 2.201 | 1.534 | 1.756 | 1.534 |
| **geomean** | **1.528** | **1.512** | **1.511** | **1.519** | **2.312** | **2.370** | **1.521** | **1.683** | **1.530** |
<!-- WASM-CODEGEN:END -->

- **`-O3`, `wasm-opt -O3` (Binaryen version_133) and `-msimd128` barely move the geomean** (`-O2` 1.528,
  `-O3` 1.512, `wasm-opt` 1.511, SIMD 1.519). Auto-vectorisation to wasm SIMD moves gemm, k-means,
  sha256 and fannkuch by 0.6 to 6% (dijkstra by 0.06%, the rest not at all); the benchmarks forbid hand-written SIMD.
- **Explicit bounds checks** (`-O memory-reservation=0 -O memory-guard-size=0`) and **no signal-based traps**
  (`-O signals-based-traps=n`) are the expensive switches: they are what an embedding without virtual-memory
  guard regions pays.
- **Eager table initialisation** (`-O table-lazy-init=n`) only matters for polymorphism (1.974 to 1.808), the one
  benchmark dominated by `call_indirect`.
- **Cranelift `opt-level=0` is not a speed result.** It gives fewer instructions on mandelbrot, polymorphism and
  reverse-complement. In polymorphism, for example, it emits a single `sdiv` + `msub` for `x % P` where the
  optimiser emits a 9 instruction magic-number sequence that is cheaper in cycles. The metric counts instructions, not cycles.
  `opt-level=1` produces byte-identical code to the default for all 18 modules, so it is not a separate column.

## Does the runtime or the compiler version matter?

### wasmtime releases 26 to 50

The same wasi-sdk 34 modules, precompiled by each release, against the same native clang 23.1.0 binary. Lower is
better.

<!-- WASM-RUNTIME-SWEEP:START -->
| Benchmark | wasmtime 26.0.1 | wasmtime 30.0.2 | wasmtime 34.0.2 | wasmtime 38.0.4 | wasmtime 42.0.2 | wasmtime 46.0.3 | wasmtime 50.0.0 | 26.0.1 default flags | 50.0.0 default flags |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 1.002 | 1.002 | 1.002 | 1.002 | 1.002 | 1.001 | 1.001 | 1.002 | 1.001 |
| binary-trees | 1.088 | 1.088 | 1.084 | 1.095 | 1.095 | 1.036 | 1.018 | 1.088 | 1.018 |
| blur | 1.245 | 1.220 | 1.220 | 1.374 | 1.276 | 1.276 | 1.276 | 1.245 | 1.276 |
| dijkstra | 1.713 | 1.673 | 1.702 | 1.765 | 1.748 | 1.761 | 1.761 | 1.713 | 1.761 |
| fannkuch | 2.319 | 2.513 | 2.525 | 3.197 | 3.163 | 1.706 | 1.706 | 2.319 | 1.706 |
| gbdt | 1.282 | 1.282 | 1.308 | 1.309 | 1.309 | 1.309 | 1.309 | 1.282 | 1.309 |
| gemm | 2.604 | 2.604 | 2.604 | 2.614 | 2.611 | 2.610 | 2.610 | 2.604 | 2.610 |
| k-means | 1.693 | 1.693 | 1.693 | 1.695 | 1.627 | 1.624 | 1.621 | 1.693 | 1.621 |
| k-nucleotide | 1.713 | 1.713 | 1.713 | 1.808 | 1.808 | 1.789 | 1.686 | 1.714 | 1.685 |
| lz77 | 1.329 | 1.329 | 1.329 | 1.333 | 1.321 | 1.321 | 1.321 | 1.329 | 1.321 |
| mandelbrot | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 |
| polymorphism | 1.775 | 1.775 | 1.775 | 2.143 | 2.128 | 1.996 | 1.974 | 1.776 | 1.974 |
| reverse-complement | 1.435 | 1.435 | 1.435 | 1.729 | 1.729 | 1.729 | 1.729 | 1.435 | 1.729 |
| sha256 | 1.612 | 1.612 | 1.674 | 1.674 | 1.525 | 1.546 | 1.531 | 1.612 | 1.531 |
| sort-search | 1.356 | 1.350 | 1.350 | 1.365 | 1.365 | 1.367 | 1.367 | 1.356 | 1.367 |
| tak | 1.571 | 1.571 | 1.615 | 1.615 | 1.615 | 1.615 | 1.565 | 1.571 | 1.565 |
| viterbi | 1.907 | 1.907 | 1.922 | 1.867 | 1.791 | 1.755 | 1.710 | 1.907 | 1.710 |
| vm | 1.809 | 1.809 | 1.809 | 1.809 | 1.670 | 1.522 | 1.534 | 1.809 | 1.534 |
| **geomean** | **1.562** | **1.565** | **1.575** | **1.648** | **1.615** | **1.541** | **1.528** | **1.562** | **1.528** |
<!-- WASM-RUNTIME-SWEEP:END -->

Two years of Cranelift moved the geomean only from 1.562 to 1.528, but single benchmarks swing far more than
that: fannkuch goes 2.32x (26) to 3.20x (38) to 1.71x (46 onwards). A wasm number without its runtime version
is not a reproducible number.

### wasi-sdk 25, 30 and 34, each against its own clang

Each wasi-sdk is compared with the official LLVM release of the same clang version, all on wasmtime 50. Lower is
better.

<!-- WASM-SDK-SWEEP:START -->
| Benchmark | sdk 25 / clang 19 | sdk 30 / clang 21 | sdk 30 mvp / clang 21 | sdk 34 / clang 23 | sdk 34 mvp / clang 23 | native clang 19 / clang 23 | wasm sdk 25 / sdk 34 | sdk 25 on wt 26 / clang 23 | sdk 34 on wt 26 / clang 23 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 1.002 | 1.002 | 1.002 | 1.001 | 1.001 | 1.000 | 1.000 | 1.002 | 1.002 |
| binary-trees | 0.900 | 0.906 | 0.906 | 1.018 | 1.018 | 1.000 | 0.884 | 0.981 | 1.088 |
| blur | 1.103 | 1.461 | 1.461 | 1.276 | 1.276 | 1.073 | 0.928 | 1.196 | 1.245 |
| dijkstra | 1.791 | 1.793 | 1.793 | 1.761 | 1.761 | 0.993 | 1.010 | 1.698 | 1.713 |
| fannkuch | 1.965 | 1.663 | 2.016 | 1.706 | 2.012 | 1.013 | 1.166 | 2.500 | 2.319 |
| gbdt | 1.309 | 1.309 | 1.309 | 1.309 | 1.309 | 1.000 | 1.000 | 1.282 | 1.282 |
| gemm | 1.765 | 1.765 | 1.765 | 2.610 | 2.610 | 1.479 | 1.000 | 2.604 | 2.604 |
| k-means | 1.630 | 1.621 | 1.621 | 1.621 | 1.621 | 1.000 | 1.005 | 1.701 | 1.693 |
| k-nucleotide | 1.544 | 1.616 | 1.616 | 1.686 | 1.686 | 1.035 | 0.948 | 1.608 | 1.713 |
| lz77 | 1.305 | 1.321 | 1.321 | 1.321 | 1.321 | 1.012 | 1.000 | 1.329 | 1.329 |
| mandelbrot | 1.463 | 1.463 | 1.463 | 1.463 | 1.463 | 1.000 | 1.000 | 1.463 | 1.463 |
| polymorphism | 1.974 | 2.029 | 2.029 | 1.974 | 1.974 | 1.000 | 1.000 | 1.775 | 1.775 |
| reverse-complement | 1.782 | 1.782 | 1.782 | 1.729 | 1.729 | 0.985 | 1.015 | 1.403 | 1.435 |
| sha256 | 1.384 | 1.384 | 1.384 | 1.531 | 1.531 | 1.057 | 0.956 | 1.527 | 1.612 |
| sort-search | 1.417 | 1.389 | 1.389 | 1.367 | 1.367 | 1.043 | 1.081 | 1.510 | 1.356 |
| tak | 1.359 | 1.359 | 1.359 | 1.565 | 1.565 | 1.000 | 0.868 | 1.365 | 1.571 |
| viterbi | 1.729 | 1.700 | 1.700 | 1.710 | 1.710 | 1.000 | 1.011 | 1.907 | 1.907 |
| vm | 1.489 | 1.525 | 1.525 | 1.534 | 1.534 | 0.960 | 0.932 | 1.830 | 1.809 |
| **geomean** | **1.463** | **1.478** | **1.494** | **1.528** | **1.542** | **1.031** | **0.987** | **1.542** | **1.562** |
<!-- WASM-SDK-SWEEP:END -->

The wasm modules barely change between compilers (sdk 25 / sdk 34 = 0.987). What changes is the native side:
native clang 23 is much better than clang 19 on gemm (clang 19 / clang 23 = 1.479), so the same wasm gemm module
looks 1.77x against clang 19 and 2.61x against clang 23. **The native control has to be the same compiler
version as the wasm toolchain**, or the ratio measures a compiler upgrade. The 2x2 corner (wasi-sdk 25 or 34 on
wasmtime 26 or 50, all against clang 23) separates the two: moving from wasmtime 26 to 50 lowers the geomean by
0.034 with either compiler, while moving from wasi-sdk 25 to 34 raises it by 0.020 with either runtime (the newer
compiler's wasm is not smaller everywhere: tak, binary-trees). On fannkuch the runtime dominates (wasi-sdk 34:
2.32x on wasmtime 26, 1.71x on 50).

## V8: only one tier is a fair column

Node 26.5.0 running the C modules under four tier configurations; ratio to native clang 23.1.0, lower is better.

<!-- WASM-V8-TIERING:START -->
| Benchmark | TurboFan (--no-liftoff), the study's V8 column | TurboFan, eager compilation | Liftoff only (base flags) | dynamic tiering (sync tier-up) | wasmtime 50 (reference) |
|---|---:|---:|---:|---:|---:|
| bigint | 1.417 | 1.417 | 3.131 | 3.130 | 1.001 |
| binary-trees | 0.978 | 0.979 | 0.912 | 0.924 | 1.018 |
| blur | 1.327 | 1.323 | 2.716 | 2.711 | 1.276 |
| dijkstra | 1.767 | 1.776 | 4.080 | 4.076 | 1.761 |
| fannkuch | 2.274 | 2.275 | 4.171 | 4.170 | 1.706 |
| gbdt | 1.493 | 1.493 | 2.472 | 2.471 | 1.309 |
| gemm | 3.293 | 3.295 | 8.260 | 8.259 | 2.610 |
| k-means | 1.596 | 1.596 | 3.329 | 3.327 | 1.621 |
| k-nucleotide | 1.609 | 1.626 | 2.744 | 2.741 | 1.686 |
| lz77 | 1.513 | 1.516 | 3.237 | 3.236 | 1.321 |
| mandelbrot | 1.124 | 1.124 | 3.040 | 3.037 | 1.463 |
| polymorphism | 2.436 | 2.432 | 4.906 | 4.906 | 1.974 |
| reverse-complement | 1.359 | 1.359 | 2.924 | 2.922 | 1.729 |
| sha256 | 1.374 | 1.371 | 5.442 | 5.440 | 1.531 |
| sort-search | 1.312 | 1.309 | 2.541 | 2.220 | 1.367 |
| tak | 1.125 | 1.124 | 1.136 | 0.909 | 1.565 |
| viterbi | 1.528 | 1.530 | 2.603 | 2.601 | 1.710 |
| vm | 1.873 | 1.873 | 3.389 | 3.389 | 1.534 |
| **geomean** | **1.562** | **1.563** | **3.036** | **2.977** | **1.528** |
<!-- WASM-V8-TIERING:END -->

`--single-threaded` (needed for a stable count) **forces `--no-wasm-tier-up`, and an explicit `--wasm-tier-up`
cannot override it**, so with the matrix's Node flags every wasm function runs in Liftoff, V8's baseline
compiler, forever. That configuration reports about 3x for C; it measures a baseline compiler, not V8. With
`--no-liftoff` every function is compiled by TurboFan, lazily on first call on the main thread, the count is
stable to 0.0012%, and for C compilation cancels in the differential (eager compilation adds the same 34 to 50
million instructions at both sizes). It cancels only for functions both sizes call: a large runtime that first
reaches some code at the larger size compiles it inside the differential (VB.NET, below). Dynamic tiering is no better a column: V8 has no on-stack replacement for wasm, so a
hot loop that runs inside a single call never leaves Liftoff, and the result mixes tiers per benchmark.

## Measurement noise

Per-thread guest instruction counts over 5 runs of tak, fannkuch and dijkstra; spread = (max - min) / median of
the process total at each size. Lower is better.

<!-- WASM-JITTER:START -->
| Configuration | Guest threads | Worst spread, small size | Worst spread, large size |
|---|---:|---:|---:|
| `wt50-default-P1` | 8..8 | 0.2256% | 0.0145% |
| `wt26-default` | 8..8 | 0.1274% | 0.0135% |
| `wt26-default-P1` | 8..8 | 0.1249% | 0.0162% |
| `wt50-default` | 8..8 | 0.1192% | 0.0121% |
| `wt50-tokio1` | 3..3 | 0.1154% | 0.0108% |
| `wt50-cpuset0` | 3..3 | 0.1118% | 0.0020% |
| `wt50-concN-only` | 8..8 | 0.1034% | 0.0070% |
| `wt50-parcompN` | 8..8 | 0.0905% | 0.0124% |
| `wt50-cacheN` | 8..8 | 0.0797% | 0.0101% |
| `wt50-rayon1` | 8..8 | 0.0786% | 0.0066% |
| `node-A2-noliftoff-eager` | 8..8 | 0.0362% | 0.0336% |
| `node-E-dyntier-default` | 8..8 | 0.0291% | 2.3871% |
| `wt50-t1c-concN` | 2..2 | 0.0175% | 0.0015% |
| `wt26-tokio1-cacheN` | 2..2 | 0.0154% | 0.0025% |
| `wt50-tokio1-cacheN-parN` | 2..2 | 0.0151% | 0.0025% |
| `wt50-t1c-sigtrapN` | 2..2 | 0.0128% | 0.0007% |
| `node-D-dyntier-sync` | 8..8 | 0.0122% | 0.0075% |
| `wt50-tokio1-cacheN-cpuset0` | 2..2 | 0.0118% | 0.0037% |
| `wt50-t1c-fixed2` | 2..2 | 0.0105% | 0.0017% |
| `wt50-tokio1-cacheN-fixrand` | 2..2 | 0.0097% | 0.0013% |
| `wt50-tokio1-cacheN` | 2..2 | 0.0092% | 0.0018% |
| `node-B-base` | 8..8 | 0.0086% | 6.8076% |
| `node-A-noliftoff` | 8..8 | 0.0011% | 0.0008% |
| `node-A-rep2` | 8..8 | 0.0010% | 0.0008% |
<!-- WASM-JITTER:END -->

- With default flags wasmtime runs 8 guest threads (main, tokio's worker pool sized from the 8 vCPUs, and a module
  cache worker) and its counts move by up to 0.23% at the small size. **wasmtime 26 behaves the same way as 50**
  here (same 8 threads, spreads of the same order: 0.13% against 0.12% at the small size).
- `TOKIO_WORKER_THREADS=1` alone or `-C cache=n` alone helps little; together they leave 2 threads and the
  spread drops to about 0.01% (small size) and 0.002% (large size). The residual is a few hundred instructions on
  the main thread and the one tokio worker; a shim that makes `getrandom` deterministic does not remove it, so
  wasmtime is near-exact, not bit-exact.
- V8 with `--no-liftoff` is the most stable configuration measured (0.0011%). On the same three benchmarks,
  Liftoff with background tier-up (`node-E`, Node's default flags) reaches 2.4% at the large size and bare
  Liftoff (`node-B`) 6.8%, a second reason not to use them.
- Validity is judged per (configuration, benchmark, size) block: a block counts only if every run printed the
  spec checksum. Four configurations have no valid block and are excluded: `-S preview2=n` (rejected by wasmtime
  50), `-O pooling-allocator=y` (the guest is killed under qemu, in two separate attempts) and
  `-O memory-init-cow=n` (only ever run with a module not compiled with the same flag). `-W concurrency-support=n`
  failed the same way on its first attempt; those blocks are dropped and its re-run with a matching module is
  kept (it does not reduce the spread).

## Instructions versus time

Does the instruction ratio predict the time ratio? The C modules were timed natively (no qemu) inside the C lane
image, one benchmark at a time, pinned to one vCPU, every repetition running all (column, size) pairs in a fresh
random order, 50 paired repetitions per cell over two passes. At the spec sizes native clang's time differentials are 0.7 to 40 ms,
at the timing noise floor, so a larger size L per benchmark (native clang differential 53 to 208 ms) is used, with the
checksum gate at L. Both sides are differentials: `t(L) - t(n1)` against `I(L) - I(n1)`. Time ratios are user
CPU time, median with a 95% bootstrap interval; lower is better.

<!-- WASM-WALLCLOCK:START -->
| Benchmark | wasmtime: time | wasmtime: instructions | V8 TurboFan: time | V8 TurboFan: instructions | V8 Liftoff: time | V8 Liftoff: instructions | gcc (native control): time | gcc (native control): instructions |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| bigint | 1.00 [0.99, 1.01] | 1.00 | 1.01 [0.99, 1.02] | 1.42 | 0.62 [0.60, 0.63] | 3.13 | 1.00 [0.99, 1.01] | 1.00 |
| binary-trees | 1.30 [1.28, 1.34] | 1.02 | 0.96 [0.94, 1.00] | 0.98 | 0.88 [0.86, 0.91] | 0.93 | 0.92 [0.90, 0.96] | 0.93 |
| blur | 1.28 [1.24, 1.31] | 1.28 | 1.15 [1.12, 1.19] | 1.33 | 2.02 [1.95, 2.08] | 2.71 | 2.86 [2.76, 2.94] | 4.55 |
| dijkstra | 1.34 [1.26, 1.39] | 1.76 | 1.10 [1.03, 1.15] | 1.76 | 2.44 [2.27, 2.57] | 4.07 | 0.94 [0.88, 1.00] | 1.09 |
| fannkuch | 1.31 [1.29, 1.33] | 1.68 | 1.22 [1.18, 1.25] | 2.23 | 1.95 [1.92, 1.98] | 4.29 | 1.05 [1.03, 1.07] | 0.97 |
| gbdt | 1.28 [1.25, 1.31] | 1.31 | 1.38 [1.34, 1.41] | 1.49 | 2.28 [2.17, 2.35] | 2.47 | 1.31 [1.27, 1.36] | 1.49 |
| gemm | 1.20 [1.18, 1.22] | 2.64 | 1.29 [1.26, 1.32] | 3.34 | 3.39 [3.33, 3.46] | 8.41 | 1.20 [1.18, 1.24] | 2.31 |
| k-means | 1.44 [1.39, 1.47] | 1.62 | 1.45 [1.39, 1.49] | 1.60 | 2.48 [2.39, 2.54] | 3.33 | 1.89 [1.83, 1.94] | 2.03 |
| k-nucleotide | 1.45 [1.42, 1.48] | 1.68 | 1.45 [1.41, 1.49] | 1.58 | 2.30 [2.24, 2.36] | 2.79 | 1.71 [1.67, 1.75] | 1.43 |
| lz77 | 1.14 [1.13, 1.16] | 1.32 | 1.26 [1.23, 1.29] | 1.51 | 2.32 [2.28, 2.36] | 3.24 | 1.02 [1.01, 1.05] | 0.92 |
| mandelbrot | 1.04 [1.02, 1.06] | 1.46 | 1.10 [1.08, 1.11] | 1.12 | 2.43 [2.39, 2.46] | 3.04 | 0.91 [0.90, 0.93] | 0.86 |
| polymorphism | 1.84 [1.81, 1.86] | 1.97 | 2.02 [1.98, 2.07] | 2.44 | 2.41 [2.36, 2.44] | 4.89 | 1.00 [0.98, 1.01] | 1.04 |
| reverse-complement | 1.39 [1.36, 1.41] | 1.73 | 1.37 [1.35, 1.39] | 1.36 | 2.16 [2.13, 2.19] | 2.92 | 1.90 [1.87, 1.92] | 1.10 |
| sha256 | 0.87 [0.85, 0.88] | 1.53 | 0.95 [0.93, 0.97] | 1.37 | 3.29 [3.25, 3.33] | 5.44 | 1.10 [1.08, 1.13] | 1.09 |
| sort-search | 1.05 [1.01, 1.07] | 1.36 | 1.06 [1.03, 1.09] | 1.31 | 1.33 [1.27, 1.37] | 2.59 | 0.99 [0.96, 1.02] | 1.01 |
| tak | 1.56 [1.53, 1.58] | 1.56 | 1.03 [1.01, 1.06] | 1.13 | 1.02 [0.99, 1.04] | 0.91 | 1.01 [0.98, 1.03] | 1.04 |
| viterbi | 1.50 [1.48, 1.55] | 1.71 | 1.39 [1.36, 1.44] | 1.53 | 2.33 [2.29, 2.40] | 2.60 | 1.49 [1.46, 1.54] | 1.79 |
| vm | 1.26 [1.25, 1.27] | 1.53 | 1.47 [1.44, 1.49] | 1.87 | 1.79 [1.77, 1.81] | 3.39 | 0.73 [0.72, 0.74] | 0.85 |
| **geomean** | **1.27** | **1.53** | **1.24** | **1.56** | **1.92** | **3.01** | **1.20** | **1.27** |

Spearman and R² measure how well the instruction ratio tracks the time ratio across the 18 benchmarks (higher is better; 1.00 = perfect).

| Comparison (18 benchmarks, size L) | Spearman | R² (log-log) |
|---|---:|---:|
| wasmtime / clang | 0.56 | 0.14 |
| V8 TurboFan / clang | 0.67 | 0.33 |
| V8 Liftoff / clang | 0.61 | 0.45 |
| gcc (native control) / clang | 0.83 | 0.67 |
| V8 TurboFan / wasmtime | 0.41 | 0.19 |
<!-- WASM-WALLCLOCK:END -->

- **Direction yes, size no.** On the geomean, instructions overstate the wasm overhead on every engine: 1.53x
  instructions vs 1.27x time on wasmtime, 1.56x vs 1.24x on V8 TurboFan. Per benchmark they explain little of
  the time ratio (R² 0.14 on wasmtime, 0.33 on TurboFan, log-log; R² is the share of the variation explained,
  higher is better), against 0.67 for the native gcc / clang
  control on the same machine. Part of that is range: the instruction ratios span 1.0x to 2.6x on wasmtime (1.0x to 3.3x on TurboFan), where
  the matrix study that
  found R² 0.91 spanned ratios from parity to two orders of magnitude. **Quote the instruction ratio as an upper-leaning estimate of the wasm cost,
  not as a time ratio.**
- **The extra wasm instructions are cheap ones.** Address adds, rematerialised constants and spill pairs run in
  parallel with the real work. sha256 is the extreme: 1.53x the instructions on wasmtime, 0.87x the time.
- **bigint is the clearest case of what instruction counts cannot see.** V8's Liftoff tier runs it with 3.1x the
  instructions of native clang and 0.62x the time. Native clang and Cranelift both fuse the multiply and the
  carry add into one `madd` whose accumulator is the carry from the previous limb; Liftoff emits a separate `mul`
  (which does not depend on the carry) and `add`, so its loop-carried chain is only `add` + `lsr`. The timing is
  consistent with the multiply latency sitting on the carry chain in the fused form; accumulator forwarding on
  the host core was not measured.
- **binary-trees on wasmtime: the cost is in the register save and restore code, not in memory.** It runs
  1.30x clang's time at 1.02x the instructions while V8 on the same module is at parity. Page faults, sys time,
  copy-on-write initialisation and the pooling allocator rule out the memory system. Cranelift saves registers on
  aarch64 as a chain of stack-pointer updates (six in dlmalloc, which the differential calls 14.85 million times),
  where clang and V8 move the stack pointer once. Rewriting only dlmalloc's prologue and epilogue in the
  precompiled module to the single-adjustment form, same instruction count, takes wasmtime from 1.21x to 0.96x of
  clang (V8: 0.95x) in a separate paired experiment (`languages/wasm/experiments/frames/`). Which part of this core
  penalises the chained form is not established (the VM exposes no performance counters).
- Undiagnosed: clang's gemm and blur are unusually fast per instruction relative to gcc and to wasm, with no NEON
  vector instructions in either native gemm binary.
- **Estimator caveat.** The host was loaded during timing: at size L the median run spent half of its wall time
  waiting in the run queue (90th percentile 56%). User CPU time is used instead; the interquartile range of each
  numerator differential is 6% of its median (2% to 20%), the two passes agree at R² 0.99 (log ratios, 72 cells), and
  two earlier passes with the pre-final flags give the same wasmtime time geomean (1.254 and 1.268; the two headline passes give 1.280 and 1.265). The verdict
  holds on wall time (wasmtime Spearman 0.64, R² 0.20). The Docker VM has no steal-time accounting, so absolute times are not
  quoted, only ratios.

## Replication

An independent re-measurement of four complete lanes on 2026-10-28 (images rebuilt from the same Dockerfiles, same
driver) against the published 2026-10-27 envelopes, as the largest change of any single cell differential
(lower is better; `results/wasm/2026-10-28-arm64-replication.json`):

| Lane | native | wasmtime | V8 TurboFan | wasmtime geomean | V8 geomean |
|---|---:|---:|---:|---:|---:|
| C | 0% | 0.006% | 0.014% | 1.528 / 1.528 | 1.561 / 1.561 |
| C# (Mono) | 0% | 0% | 0% | 2.015 / 2.015 | 2.552 / 2.552 |
| Java (TeaVM) | 0% | 0.001% | 0.004% | 1.881 / 1.881 | 2.003 / 2.003 |
| Go | 2.3% (k-nucleotide) | 0.7% (k-nucleotide) | **12.9% (sha256)** | 3.115 / 3.119 | 4.058 / 4.004 |

C, C# and Java reproduce to a few thousandths of a percent. Go did not on V8: single cells moved by up to 12.9%
(sha256; tak and bigint about 7%) between runs although each run's own repetitions agreed to within 0.17%. It is not
the build (the `.wasm` modules of two image builds are byte-identical) but Go's runtime seed: Go reads WASI
`random_get` at startup, and the seed shifts the whole V8 process by about 9.5 million instructions (0.16% of its
startup), in a few discrete levels. Each repetition of `I(n1)` and `I(n2)` drew its own seed, so a differential could
carry one whole step (14% of sha256's). With a fixed seed the differential reproduces to 12 instructions across two
very different seeds. Since then `run-node.mjs` answers `random_get` with a fixed byte stream (the same idea as
`PYTHONHASHSEED=0`) and the V8 column of every lane was re-measured with it (2026-10-29 envelopes; their native,
wasmtime and reference cells are the 2026-10-27 ones). The table above compares runs made before that change.
Against the 2026-10-27 V8 cells, the change moved Go (up to 12.7%, sha256), Swift k-nucleotide (0.2%: Swift seeds
its `Hasher` from `random_get`) and Scala dijkstra (0.27%, not a seed effect: the timing of V8's young-generation collections moves it
between launches, see [the audit](wasm-fairness-audit.md)); every other V8 cell of the 13 lanes stayed within 0.05%.

## Per-language notes

Each lane's `lane.json` lists its exact versions, every transform and every asymmetry; this section is the
summary. "Same build" means both columns come from the same source tree, compiler version and configure options.

**C.** clang 23.1.0 `-O2` on both sides (official LLVM release natively, wasi-sdk 34 for wasm); the only transform
is `lp64.sh` (see [above](#a-trap-in-the-c-sources-wasm32-is-ilp32)). Native links glibc, wasm links wasi-libc
(dlmalloc instead of ptmalloc). Native clang auto-vectorizes with NEON, the default wasm target has no SIMD (worth
2 to 6% on three benchmarks, see [options](#compiler-and-runtime-options)); pointers and `size_t` stay 32-bit on
wasm.

**Rust.** rustc 1.88.0 (LLVM 20.1.5), the same binary for both targets, `-O` on both sides, no transform: the
sources are correct on wasm32 unchanged. The native column is the matrix image itself. The wasm build adds an
8 MiB stack (the wasm default is 1 MiB). rustc builds wasm32-wasip1 with `panic=abort` and aarch64 with
`panic=unwind` (the target defaults), so only the native code carries unwinding paths; it is kept that way so the
native column stays the matrix binary.

**Go.** go1.24.4 `GOOS=wasip1 GOARCH=wasm`, no flags and no transform (`int` stays 64-bit on wasm). Native is the
matrix image with its environment (`GOMAXPROCS=1`, `GODEBUG=asyncpreemptoff=1`); on wasm those variables are inert
(measured: within 0.12%), since wasip1 has one thread, no sysmon and no preemption. Native Go
jitters up to 5.4% run to run (k-nucleotide; garbage-collector pacing on the main thread), wasm Go much less.

**Swift.** The matrix Swift (6.1.3) has no WASI SDK; the first official Swift SDK for WebAssembly is 6.2, so both
columns use Swift 6.2.0 (`swiftc -O`, wasm with the static stdlib the SDK prescribes) and the native column is not
the matrix cell. Swift's `Int` is **32 bits on wasm32**: 7 benchmarks are correct unchanged, the other 11 print a
wrong checksum, trap, or (vm) fail to compile. Those 11 are built with a shim that makes `Int`, `UInt` and integer
literals 64-bit (`int64.sh`, marked † in the tables); the shim does not compile for fannkuch and k-nucleotide,
which do not need it. Compiled natively the shim changes nothing on 9 of the 11 and adds 0.88% (dijkstra) and
0.098% (sha256). Swift's overflow-checked 64-bit multiply has no wasm instruction for the high half of the product,
so each one becomes a call to `__multi3`, a helper of about 130 instructions (aarch64 needs one extra `smulh` or
`umulh`). The hot loops of the four most expensive Swift cells, bigint, gemm, k-means and viterbi, all call it. As a
diagnostic outside the benchmark sources, a copy with wrapping `&*` on the hot multiplies brings their
wasmtime / native ratio from 11.1x to 1.4x (bigint), 8.9x to 2.5x (gemm), 8.8x to 1.9x (k-means) and 7.6x to
1.9x (viterbi), removing 86 to 99% of the extra instructions; in k-means and viterbi the copy also wraps the
adjacent index additions (details in `languages/wasm/swift/lane.json`). In the three shimmed ones it is the 64-bit
`Int` that creates these multiplies, which is also what native Swift computes.

**Python.** CPython 3.13.4 built twice from the same source with clang 23.1.0 (`-O3`, no PGO or LTO), with
`--with-pymalloc` and `--with-computed-gotos` forced on both sides (the WASI defaults would silently turn both
off). `PYTHONHASHSEED=0` on every column: with random seeds polymorphism splits into two modes 3.4% apart. Hashes
are 32-bit on wasm32, so the same seed still gives different dictionary layouts there; that is part of the target.
The matrix image (gcc, PGO, LTO, shared library) is shown as a reference column, not as the control.

**Ruby.** CRuby 3.3.13 (the matrix patch level) built twice from the same source with clang 23.1.0, YJIT off on
both, native hardening flags removed to match wasm. CRuby's wasm port needs Asyncify (a whole-module transform
for `setjmp`/`longjmp`, fibers and the GC's stack scan) and a one-symbol build fix: wasi-sdk 34's emulated `mmap`
library now defines a strong `mprotect` that fails CRuby's fiber-pool setup, so the wasm interpreter is built with
`-Dmprotect=rb_wasm_mprotect_stub` (CRuby's own no-op stub, as upstream intends). **`VALUE` is 32 bits on wasm32**:
no flonums and only 31-bit immediate integers, so every float and every integer beyond about 2^30 is a heap
object. Counted with `languages/wasm/ruby/alloc.rb`, bigint allocates 25 million objects per run on wasm against
54 thousand natively, and the benchmarks with the largest ratios are exactly the high-allocation ones. That cost
is real for every wasm32 Ruby and is not separated out. The matrix image is a reference column. Measured on
2026-10-27 (arm64, same-build native control): wasmtime **7.19x**, V8 TurboFan **8.72x**, matrix reference gcc
**1.41x** (geomean over 18 benchmarks; bigint and mandelbrot are the most expensive wasmtime cells).

**PHP.** php-src has no WASI port; PHP 8.4.8 is built with the generic `__wasi__` patches of gophper-wasm (MIT,
vendored with its licence under `languages/wasm/php/patches/`) plus one patch that keeps `zend_long` 64-bit on
wasm32 (otherwise the benchmarks overflow to float), a small compatibility layer (declarations WASI headers lack,
and failing stubs for users, sockets, `popen` and similar, none reached by the benchmarks), and wasm exception
handling for `setjmp`/`longjmp`. All of it is guarded by `__wasi__` or only linked into the wasm build. The native
control is the same patched tree with clang
23.1.0 and the same configure options (no opcache, CALL dispatch); the 64-bit `zend_long` on a 32-bit address
space is a configuration php-src does not target and is validated only by the checksum gates. The matrix image
(gcc, HYBRID dispatch with global registers) is a reference column.

**C# and VB.NET (Mono).** The only WASI route is the `wasi-experimental` workload: the Mono **interpreter**
compiled to wasm. It is officially unsupported on .NET 9 (and 10); the build guard is bypassed. Mono AOT to wasm
builds but crashes at startup, so there is no compiled-code column. The workload links a WASI preview 2
component, which `node:wasi` cannot load, so the lane relinks to preview 1. The native control is the Mono
interpreter too, but the only Mono 9 runtime published for linux-arm64 is 9.0.0-preview.7 while the wasm runtime is
9.0.22, so the engine and the class library (collections included) are different builds; C# k-nucleotide is n/a
because preview.7 lacks an API it uses. The native column pins Mono's non-concurrent major collector, which the
single-threaded wasm runtime cannot run concurrently anyway. Wasm assemblies are IL-trimmed, native ones are not. CoreCLR and Mono JIT columns are kept in the envelopes as references; against CoreCLR the wasm build costs
about 15 to 20x, which compares an interpreter with a JIT and says nothing about wasm. VB.NET keeps overflow checks
on in every column. On V8, VB.NET k-nucleotide and sha256 cost 3.50x and 3.18x the native Mono interpreter while
the same modules on wasmtime cost 2.11x and 2.15x, the largest V8 excess of either .NET lane. It is V8's lazy
compilation: about 127 Mono runtime functions (about 30 KB of wasm, the same set binary-trees reaches) are first
called only at the larger size, so TurboFan compiles them inside the differential (about 0.36 billion
instructions, 40% of VB.NET sha256's native differential). With `--no-wasm-lazy-compilation` the two cells fall to
2.79x and 2.63x, 1.30 and 1.25 times wasmtime, inside the band of the other cells (`languages/wasm/vbnet/lane.json`,
`diagnostics`).

**JavaScript (QuickJS-ng).** V8 cannot be compiled to wasm, so this lane measures QuickJS-ng 0.17.0, an
interpreter, built from source on both sides with clang 23.1.0 and identical CMake options. Each source gets one
line after `"use strict"` defining `process.argv` (QuickJS has no `process`; placed first it would silently turn
off strict mode); all three columns run the same file. QuickJS NaN-boxes its values on 32-bit targets, so wasm32
uses a different value representation from the 64-bit native build (the same kind of effect as Ruby's; its
size was not isolated).
Not comparable with the matrix Node cell.

**Java, Kotlin and Scala (TeaVM).** See [their section](#java-kotlin-and-scala-through-teavm).

## Languages with no wasm column

| Language | Why | Evidence |
|---|---|---|
| OCaml | wasm_of_ocaml 6.5.0 (the maintained route) has **31-bit ints**; 14 of 18 sources use arithmetic beyond 2^31 (modular hashes, LCGs, 32-bit masks). | reverse-complement prints 32018730 instead of 827974717; sort-search raises `Invalid_argument("index out of bounds")`. An Int64 rewrite would change native cost, which rule 1 forbids. Its fair native control would also be bytecode (`ocamlrun`), not the matrix `ocamlopt`. |
| Perl | No official WASI Perl. The one port (zeroperl, experimental, no releases) uses Asyncify for `setjmp`/`longjmp`, whose instrumentation is not wasm cost, and needs a cross-compiled `Configure`. | Not measured by decision: the result would measure a port, not wasm. |
| Fortran | No wasm32 flang runtime upstream. LFortran 0.68.0 is alpha, ships without its WASI runtime object, links with a triple wasi-sdk 34 no longer ships, and its module **ignores argv** (asked for n=9, it printed the n=7 result). | It would also need its own native column, since gfortran 14 is a different compiler. |
| Elixir | There is no BEAM for WASI. AtomVM's wasm builds are emscripten (JS glue, not `node:wasi`) and have no `:atomics`, which 10 of the 18 sources use. | AtomVM is also a different VM (no JIT), so there is no same-engine pairing. |

The versions tried, the exact errors and outputs are in `languages/wasm/not-measured.md`. VB.NET runs on the
C# lane's toolchain (Mono's WASI prototype) and is reported with it.

## Reproduce

```bash
scripts/wasm-study.sh                       # every lane: build images, measure, write results/wasm/
LANGS="c rust" scripts/wasm-study.sh        # some lanes
BENCH=tak LANGS=c scripts/wasm-study.sh     # one benchmark
python3 scripts/make_wasm_tables.py --write # regenerate the tables in this page
```

The study-level experiments have their own scripts and READMEs under `languages/wasm/experiments/`
(`runtime/`, `codegen/`, `wallclock/`, `frames/`); `languages/wasm/experiments/ingest.py` turns their raw output into the
`results/wasm/<date>-arm64-<kind>.json` envelopes the tables above read.
