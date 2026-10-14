# Metric validity: what the instruction count does and does not capture

lang-lab's headline metric is the differential guest-instruction count `I(n2) - I(n1)`, normalized
to C. This document **measures**, empirically, how valid that metric is, instead of asserting it.
The short version: it is a strong predictor of relative wall-clock for compute-bound work and is
ISA-robust for native and interpreter runtimes, but its magnitude is only approximate, it is not
ISA-robust for JIT (JVM) runtimes, and it actively misleads when a syscall sits on the critical
path. Read it as "user-space instruction work," a proxy for algorithmic efficiency, not as
wall-clock speed.

## Summary

| Question | Answer |
|---|---|
| Does it predict wall-clock *order*? | Yes. Spearman rank 0.87 across 55 cells; near-perfect for non-JIT. |
| Does it predict wall-clock *magnitude*? | Approximately. R² 0.91 (log-log, compute-bound); typical error ~1.3x, p90 ~3x. |
| Is it ISA-robust (arm64 vs x86_64)? | For native, interpreter and V8 runtimes, yes (geomeans within 16%, same order). For the JVM, no (geomeans 1.5-1.9x higher on x86_64; single cells up to 7x). |
| When does it actively mislead? | Syscall on the critical path (concurrency primitives) and JIT cross-ISA magnitude. |

## Study 1: instruction count vs wall-clock (calibration)

**Method.** Five compute-heavy, syscall-free benchmarks (gemm, sha256, k-means, lz77, mandelbrot)
x 11 languages, measured **both ways on the same machine (arm64)**: the qemu+insn instruction
differential and the native wall-clock differential (min of repetitions, `t(n2) - t(n1)` to cancel
startup). Both normalized to C, correlated in log space.

**Result.** On the 52 cleanly-measurable cells, Pearson(log instr-vs-C, log wall-vs-C) = **0.956
(R² = 0.91)**; Spearman rank = 0.87. Magnitude error (how far the wall-clock ratio sits from the
instruction ratio): **median x1.32, p90 x2.96**, with a long tail. So the metric reliably orders
languages by speed and gets the magnitude right to about a third, but not better.

**Caveat on the calibration itself.** Three JVM cells (k-means/scala, lz77/kotlin, lz77/scala) were
excluded as measurement failures: at the small spec sizes these programs run too fast natively for a
stable wall-clock differential, and JIT warmup swamps the signal (their differential collapsed to
noise). Including them drags R² down to 0.62. That is a limitation of *this calibration setup at
those sizes*, not evidence about the metric, and it is itself an instance of the JIT difficulty
documented in Study 2.

**Where magnitude diverges most (real cells).** FP-heavy interpreters on mandelbrot (Python, Perl,
PHP, Ruby): the instruction count **overstates** the gap by roughly 3x, because C's floating-point
instructions are individually expensive (latency, no pipelining benefit) while the interpreter's
bookkeeping instructions are cheap and pipeline well, so "one instruction" is not the same cost on
each side. The extreme case lives in a separate study: in
[`message-ring`](../benchmarks/message-ring/README.md), a kernel syscall on every hop makes the
instruction count **invert** the wall-clock ranking (Go is 2.3x faster than C in wall-clock but
11.5x "worse" in instructions). See [the concurrency study](concurrency-study.md).

## Study 2: cross-ISA stability (arm64 vs x86_64)

**Method.** For each cell, compare the vs-C instruction ratio on arm64 (local, the headline
matrix, envelopes of 2026-06-16 to 2026-07-17) and on x86_64 (the green CI run of 2026-10-14),
across the 18 compute axes: 233 cells with both ISAs present (csharp/k-nucleotide is unmeasured on
x86_64, see below). Both ISAs run the same pinned toolchain versions. Every number in this section
is printed by `python3 scripts/cross_isa.py` from the envelopes; regenerate it from there instead of
editing it by hand (`make_matrix.py` warns when this table and the envelopes disagree).

**Result.** 34% of cells stay within +/-10% across ISAs, 63% within +/-25%, 79% within +/-50%; the
median shift is x1.02 (no systematic bias). The tail is the story, and it is **the JVM**:

| Language | geomean vs C, arm64 | geomean vs C, x86_64 | shift | ISA-stable? |
|---|--:|--:|--:|---|
| Rust | 1.11 | 1.20 | x1.08 | yes |
| C# | 1.54 | 1.31 | x0.85 | yes |
| Go | 1.64 | 1.63 | x1.00 | yes |
| Swift | 2.03 | 2.03 | x1.00 | yes |
| **Scala** | **2.39** | **4.61** | x1.93 | **no (x1.9)** |
| **Kotlin** | **2.53** | **4.70** | x1.86 | **no (x1.9)** |
| **Java** | **2.92** | **4.47** | x1.53 | **no (x1.5)** |
| JavaScript | 5.09 | 4.87 | x0.96 | yes |
| Elixir | 22.3 | 23.3 | x1.04 | yes |
| PHP | 32.2 | 27.4 | x0.85 | yes |
| Ruby | 75.3 | 63.6 | x0.84 | yes |
| Python | 104 | 114 | x1.09 | yes |
| Perl | 146 | 130 | x0.89 | yes |

The ten non-JVM geomeans move at most 16% between ISAs and keep exactly the same order. V8
(JavaScript) turns out as ISA-stable as the interpreters, which settles the question left open when
it was added. The three JVM languages run 1.5-1.9x more instructions relative to C on x86_64, and
they also reorder among themselves: Java (x1.53) overtakes Scala and Kotlin (x1.9) on x86_64.

These arm64 geomeans are the **same quantity as the README leaderboard**: both are computed over
the 18 compute axes, with message-ring excluded from the ranking (it is shown in the matrix as an
unranked column). If the two ever disagree, one of them is stale: recompute both from
`results/*-arm64-*.json` (`make_matrix.py --write` and `cross_isa.py`). The x86_64 column is the
same quantity for the CI data, rendered as `docs/charts/matrix-x86_64.svg`.

**Worst single cells, all JVM:** gemm/Java 1.03x -> 7.48x (x7.2), gemm/Kotlin 1.00x -> 5.98x
(x6.0), gemm/Scala 1.07x -> 6.09x (x5.7); sort-search/Scala and /Kotlin, mandelbrot/Scala,
bigint/Scala and vm/Java move x3.2-3.6. gemm is the extreme case: a cell that ties C on arm64 is
6-7x on x86_64. The per-cell cause has not been isolated, so the practical rule is that "1.5-2x"
describes the JVM *geomean*, not any single JVM cell: read JVM cells per ISA, never as one number.

**Cells the x86_64 runner cannot measure.** Three cells are recorded as `{"measured": false}` in
the x86_64 envelopes and skipped by the geomeans above: csharp/k-nucleotide, kotlin/message-ring
and scala/message-ring. All three measure fine on arm64, and all three fail the same way on the
x86_64 runner: the process ends (exit 4 for C#, exit 0 for the two JVM virtual-thread ports)
without the plugin ever printing its instruction summary, and the only plugin output is its
`detected repeat execution @ 0x...` log line. It is not the out-of-memory the cell was first
attributed to: the C# allocation fix of 2026-06-21 targeted an OOM, but every x86_64 envelope since,
starting with the first one after that fix (2026-06-22), records this same exit-4 signature. The
cause has not been diagnosed (it needs reproducing on an x86_64 host). The
allow-list in `.github/workflows/benchmark.yml` names exactly these three cells, so they are
recorded instead of failing the run; any other cell failing still turns the run red.

**Why.** A JVM program's instruction count is dominated by JIT-generated machine code, which differs
substantially between arm64 and x86_64. The differential cancels startup, but not the per-ISA
difference in what the JIT emits. Native and interpreter runtimes execute the same (or nearly the
same) guest instruction stream on both ISAs, so they are stable.

## What the metric is valid for

- **Within-language regression detection across versions, fixed ISA.** Excellent and deterministic.
  This is the strongest use (the `rustc-perf` use case): "did this runtime version get more or less
  efficient at this kernel."
- **Cross-language rank / algorithmic-efficiency proxy for native and interpreter runtimes.**
  Reliable (rank holds, ISA-robust).
- **A proxy for relative wall-clock on compute-bound work.** Good for order, approximate (~1.3x,
  tail ~3x) for magnitude.

## What it is NOT valid for

- **Absolute or precise relative wall-clock speed.** Use a wall-clock benchmark.
- **Cross-language magnitude for JIT/JVM languages.** ISA-dependent by 1.5-2x on the geomean and
  up to 7x on single cells; report JVM per-ISA, not as a single number.
- **Anything syscall-bound** (concurrency primitives, I/O). The instruction count can invert the
  truth. The [scaling track](scaling-track.md) and the message-ring wall-clock exist for this.

## Anticipated objections

Objections we consider technically correct, stated here before anyone else states them:

- **"The differential does not cancel the JIT completely."** True. `I(n2) − I(n1)` cancels the JIT
  work that is *common* to both runs, but tiered compilation is time-dependent: between n1 and n2 a
  method can hit a different tier, recompile, OSR or deopt, so some JIT work survives the
  subtraction. Study 1 hit an instance of exactly this (three JVM cells excluded from the
  calibration because warmup swamped the differential at small sizes). Mitigations in place:
  single-tier pinning for the CLR (`DOTNET_TieredCompilation=0`), median-of-N reporting for every
  JIT runtime, and the adaptive-RUNS escalation on jitter. Treat JIT-runtime cells as
  median-of-a-noisy-quantity, not as bit-exact counts (native/interpreter cells *are* bit-exact).
  A related, disclosed asymmetry: V8's `--single-threaded` pinning folds its background compiler
  onto the measured thread, while HotSpot's C1/C2 compiler threads stay concurrent and counted.
  Within the JVM family the effect is uniform, and the differential cancels most one-time
  compilation, but a JVM-vs-JavaScript cell comparison carries it.
- **"Under qemu TCG the JIT does not see the real CPU."** True. A JIT emits code according to the
  CPU features it detects; under TCG it sees qemu's emulated CPU model, which is not the local
  hardware, so the emitted code (and its instruction count) can differ from what production
  hardware would get. This is one more reason JVM/CLR cells are ISA-specific numbers under this
  backend rather than universal constants; Study 2 quantifies the consequence (the JVM geomean
  is 1.5-1.9x higher on x86_64, single cells up to 7x). The counts remain deterministic and comparable *within* the fixed
  (ISA, qemu, plugin) triple that the reproducibility contract pins.
- **"The 18 axes are not independent, so the flat geomean overweights tight integer loops."**
  Partially true, and acknowledged: several axes (sha256, bigint, vm, lz77, sort-search, fannkuch)
  correlate strongly for interpreters, where they all price the same dispatch overhead. The
  leaderboard therefore also reports per-family geomeans alongside the flat one (see the README),
  so a reader can weight families instead of axes.

## How to read the master matrix

It shows **user-space instruction work vs C**, a proxy for algorithmic efficiency, not wall-clock
speed. Its geomean/leaderboard is computed over the 18 compute axes: message-ring is shown as a
column but excluded from the ranking, for exactly the syscall-blindness documented above. It is a
reliable rank for the non-JVM languages; treat the **Java/Kotlin/Scala cells as ISA-specific**. For
concurrency, read the scaling track and the message-ring wall-clock, not the instruction number.
