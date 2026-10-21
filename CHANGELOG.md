# Changelog

All notable changes to Lang Lab are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- **Fortran** (gfortran 14, built from the same `gcc` image and `-O2` flags as the C baseline, so
  the two pins move together): 18 benchmarks with bit-exact reference checksums, every cell
  deterministic. Overall 1.05x C on arm64, the closest any language has come to the baseline.
  message-ring is N/A: standard Fortran has no cooperative concurrency primitive.
- **OCaml** (OCaml 5.4, native `ocamlopt`, no flambda, bounds checks on): all 19 benchmarks with
  bit-exact reference checksums, every cell deterministic without any runtime pinning. Adds a new
  archetype, native code with a garbage collector and no JIT; its bump-allocating minor heap puts
  binary-trees at 0.19x C. The ports respect OCaml's 63-bit `int`; message-ring uses OCaml 5
  effect handlers on a single domain.
- **VB.NET** (.NET 9, same CLR and runtime pinning as C#): all 19 benchmarks with bit-exact
  reference checksums. Measured with Visual Basic's default integer overflow checks on, so the
  gap to C# on the same runtime (1.0x to 2.2x per axis) is the cost of that language default.
- **COBOL side study** (`docs/cobol-study.md`, `results/cobol/`, `scripts/cobol-study.sh`), outside
  the matrix; COBOL remains removed from the ranking since 0.1.0. GnuCOBOL 3.2 and GCC's gcobol 15.2
  on the 15 benchmarks that need no hand-rolled machinery, measured at full size with C at the same
  sizes (lower is better): natural COBOL costs 25x to about 7,000x C on both compilers; a restricted
  single-verb subset on gcobol reaches about 5x to 7x C on integer loops, while calls and floats stay
  far from C. Also documents two gcobol miscompiles, with reproducers.
- **Language admission memos** in `docs/fairness-audit.md`: the binding fairness rules each new
  language was implemented against, and the closing audit that cleared all three ports.

### Fixed

- The sort-search and dijkstra READMEs understated the LCG product `state*1103515245` as ~2.4e10;
  it reaches ~2.37e18, which is why those benchmarks need at least 63-bit integers.
- C# projects hardcoded `net9.0`, so bumping the pinned .NET SDK would have kept building against
  the 9.0 runtime while labelling the results with the new version. The target framework now follows
  the pin (`DOTNET_VERSION`), as VB.NET's does; on .NET 9 the build and its counts are unchanged.

## [0.1.0] - 2026-10-14

### Added

- **Measurement backend** — QEMU user-mode + the TCG `insn` plugin, counting *guest*
  instructions (deterministic on shared CI, unlike wall-clock time). The headline metric is the
  differential `I(n₂) − I(n₁)` normalized to **C = 1.0×** (lower is better), which cancels runtime startup and JIT
  compilation to isolate the algorithm's real work.
- **11 languages + a C baseline**, chosen to cover every backend runtime archetype: C, Rust and
  Swift (native), Go (compiled + concurrent GC), Python, Perl, PHP and Ruby
  (interpreters), Kotlin, Scala and C# (VMs with JIT + GC), and Elixir (BEAM).
- **Java** (plain JVM, Temurin/OpenJDK 26): all 19 benchmarks implemented with bit-exact
  reference checksums (19/19 gates on the first try), one runnable jar per benchmark, measured
  under the same SerialGC single-thread pinning as Kotlin/Scala and carrying the same
  ISA-specific leaderboard marker. Version-watched via the `openjdk-builds-from-oracle` feed
  (endoflife.date has no `java` slug).
- **JavaScript** (Node.js 26 / V8): all 19 benchmarks implemented with bit-exact reference
  checksums, covering the speculative-JIT-with-deopts archetype the suite lacked. V8's
  background compiler/GC threads were characterized under the counting backend and pinned with
  `--predictable --single-threaded --single-threaded-gc` (+ `UV_THREADPOOL_SIZE=1`), which
  collapses run-to-run jitter from 4-24% to under 0.1%. The ports pin down JS number semantics
  where 64-bit intermediates exceed 2^53 (`Math.imul` for the shared LCG, `>>> 0` masks,
  explicit carry division in bigint), verified against a BigInt reference.
- **An 18-benchmark suite**, each stressing an orthogonal runtime axis, every implementation
  reproducing a bit-exact reference checksum: fannkuch, binary-trees, mandelbrot, k-nucleotide,
  reverse-complement, sort-search, dijkstra, blur, k-means, sha256, lz77, vm, bigint, tak,
  polymorphism, and the AI/ML axes gemm (quantized int8 matmul), viterbi (HMM/CRF sequence
  decoding) and gbdt (gradient-boosted tree ensemble inference).
- **message-ring benchmark (concurrency overhead)**: an axis measuring the per-handoff instruction
  cost of each language's cooperative message-passing primitive (a 32-worker ring driven for N
  laps), implemented in 13 languages with their idiomatic cooperative primitive (C `ucontext`, Go
  channels, a hand-rolled std `Future` executor in Rust, Swift continuations, Python `asyncio`,
  PHP/Ruby fibers, Kotlin/Scala JVM virtual threads, a single-thread C# synchronization context,
  Elixir BEAM processes). Perl is N/A (no cooperative primitive in core). Measured under
  qemu+insn across all 13 and shown in the master comparison matrix, but **excluded from the
  ranking geomean**: instruction counts are syscall-blind for context-switch primitives, and the
  concurrency study shows wall-clock inverts the ordering (the leaderboard ranks the 18 compute
  axes only).
- **Concurrency study** (`docs/concurrency-study.md`): a reproducible, cross-track write-up of
  concurrency per language along three axes: primitive cost (wall-clock per hop, with an
  instruction-count view alongside), parallel scalability as wall-clock `T1/TP`, and real-vs-GIL/GVL
  parallelism. Built with no dedicated hardware, explicit about what it cannot measure (latency,
  throughput under load, contention). Documents that the instruction-count view of message-ring is
  blind to syscall cost (which flatters C's syscall-based `swapcontext`): in wall-clock, Go, PHP and
  Ruby beat C at message-passing.
- **Two automated pipelines** on free GitHub-hosted runners: *version-watch* (endoflife.date →
  pull request bumping `versions.lock.json` when a language ships a new version) and *benchmark*
  (a version-pinned Docker image per language → measured results committed to git history).
- **The master comparison matrix** — a log-coloured heatmap of every language × every benchmark —
  as the README hero, plus per-benchmark SVG charts and a versioned result history under
  `results/`.
- **Scaling track (wall-clock parallel speedup)**: a second, complementary measurement track that
  reports the wall-clock speedup `T1/TP` (higher is better) at 1/2/4 cores (compute region only, run natively, no
  qemu) for five embarrassingly-parallel axes (gemm, mandelbrot, blur, k-means, gbdt) across every
  language, each using its idiomatic real-parallel primitive. Unlike the instruction track it is a
  ratio, not bit-reproducible. Ships with a
  fairness rulebook (`docs/scaling-track.md`), per-language speedup charts, and a dedicated CI
  workflow that refreshes `results/scaling/`.
- **An x86_64 matrix and the script behind Study 2.** `docs/charts/matrix-x86_64.svg` renders
  the CI data as a second master matrix (`make_matrix.py --isa x86_64`), so a reader who reproduces
  on Linux x86_64 has a chart to compare against. `scripts/cross_isa.py` prints the cell-level
  arm64 vs x86_64 comparison that metric-validity Study 2 is made of, so that table is generated
  from the envelopes instead of maintained by hand (and `make_matrix.py` now warns when either ISA
  column drifts from them).

### Changed

- **The README matrix states its provenance on the first screen**: a line derived from the
  envelopes themselves names the ISA and host, the measurement dates, the toolchain version each
  row was measured on, and how far the other ISA's CI data moves the result (currently: the
  non-JVM ranking reproduces within 16%, the JVM geomeans are 1.1-1.9× higher on x86_64).
- **Metric-validity Study 2 re-derived from the green x86_64 CI runs of 2026-10-14**: Java and
  JavaScript gain their x86_64 column (V8 turns out ISA-stable like the interpreters; Kotlin and
  Scala are x1.9), the Go, Swift and Ruby x86_64 cells now post-date their fixes, and the JVM gemm
  cells (up to 7× between ISAs) are called out as the reason "up to 2×" describes the JVM geomean,
  not any single JVM cell. The day's three green runs also measured **JVM run-to-run variance on
  one ISA**: every non-JVM runtime reproduces within 2% (C and PHP bit-identical) except C# (5.5%)
  and Go (9%), while JVM cells move up to 1.5× (Kotlin), 1.7× (Scala) and 3.3× (Java, whose x86_64 geomean came out
  as 4.47, 3.56 and 3.26, partly across a base-image change). The README, the matrix legends and
  the "not valid for" list now mark JVM ratios as ISA- **and run-**specific.
- **Go now runs with its garbage collector on** (default `GOGC=100`; previously the whole suite
  ran `GOGC=off`). Disabling the GC in a suite whose allocation axis (binary-trees) exists to
  measure collection work was an inconsistency: Go's numbers now include real GC work, like every
  other managed runtime. The single-thread pinning stays (`GOMAXPROCS=1`, `asyncpreemptoff`),
  since the instruction counter sums every thread in the process. Go's cells were re-measured
  across all axes under the new configuration, and every managed runtime's pinned configuration
  is now disclosed in the README's "Runtime configuration" section.

### Removed

- **COBOL** (GnuCOBOL), and with it the whole extrapolation subsystem that existed only for its
  four pathological cells (`scripts/extrapolate.py`, the `EXTRAP_CELLS` projection in CI and the
  local driver). COBOL's suite ratio (geomean ~460× C, peaking ~223,000× on sha256) was dominated
  by hand-rolled emulation of machinery the language lacks (fixed-width binary words, dynamic
  maps, bignums) rather than by anything a backend service would run, and its projected cells were
  the only numbers in the matrix not measured full-size. Every remaining number is now directly
  measured, matching the project's reproducibility contract.

### Fixed

- **A second CI run on the same day no longer loses its measurements.** The collect jobs of the
  `benchmark` and `scaling` workflows checked out the triggering commit rather than `main`, so a
  run queued behind another same-day run rebased its data commit onto the first run's and hit an
  add/add conflict on the same-date envelopes (the 2026-10-14 second run failed exactly there, with
  all 14 measurement jobs green). They now check out `main`'s HEAD and overwrite the same-date
  envelopes in place.
- **The three x86_64 cells that cannot be measured are now explained in one place** (Study 2 of
  metric-validity, linked from the README status), and the CI allow-list no longer describes
  csharp/k-nucleotide as an out-of-memory: all three (csharp/k-nucleotide, kotlin/message-ring,
  scala/message-ring) measure fine on arm64 and end under qemu-x86_64 without the plugin's
  instruction summary, cause undiagnosed. They are recorded as `measured: false` and skipped by
  the x86_64 geomeans rather than silently missing.
- **C#'s recorded arm64 geomean (1.38) was an arithmetic slip**, not a data problem: it had been
  computed over 17 of the 18 compute axes, omitting k-nucleotide, C#'s single worst cell (9.73×
  vs C). The envelopes were never wrong and never changed; the correct 18-axis figure is **1.54**,
  now consistent between the leaderboard and metric-validity.
- **Ruby k-nucleotide** was 1438× C, by far the worst cell in the whole suite, because of an
  implementation bug in its DNA generator: it built the sequence as one `String` object per
  nucleotide (~200k short-lived allocations the size differential could not cancel), not because of
  the hash map the study text blamed. Rebuilt as an in-place mutable buffer, Ruby now measures
  **56× C** on k-nucleotide, in line with the other interpreters (Perl 36×, Elixir 40×, Python 50×);
  the bit-exact checksums are unchanged. The k-nucleotide study narrative, the cross-suite tables,
  the master matrix and the leaderboard were corrected to match.
- **Swift tak and fannkuch** were inflated by avoidable per-operation overhead rather than the
  language itself: tak's global call-counter forced a runtime exclusivity check on every recursive
  call (threading it as an `inout` parameter cut tak from 4.75× to **1.15× C**), and fannkuch's flip
  loop paid an Array copy-on-write and bounds check per swap (`withUnsafeMutableBufferPointer` cut
  fannkuch from 4.75× to **3.42× C**). Both checksums are unchanged; the study tables, master matrix
  and leaderboard were updated to match.

[Unreleased]: https://github.com/ant-cabezas/Lang-Lab/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/ant-cabezas/Lang-Lab/releases/tag/v0.1.0
