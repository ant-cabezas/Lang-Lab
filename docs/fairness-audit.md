# Fairness audit: does each cell measure the language, or the implementation?

The most serious critique a cross-language benchmark can face is not "instructions are the wrong
metric" (that one is quantified in [metric-validity.md](metric-validity.md)); it is **"your
implementation of language X is bad, so the cell measures your code, not the language."** With one
author writing every implementation, that critique deserves a process, not a promise. This
document is that process and its results so far.

## Method

1. **Data triage.** Every cell is compared against its archetype peers (interpreters vs
   interpreters, JVM vs CLR, natives vs natives). A cell that deviates by an order of magnitude
   from its peers on one axis, while tracking them on the others, is flagged as a suspected
   implementation artifact rather than a language cost.
2. **Adversarial audit.** Each flagged cell gets a language-expert review whose explicit job is to
   *blame the implementation*: find the allocation, the missed idiom, the accidental O(n²), the
   build flag.
3. **Fairness review.** Any proposed fix is then reviewed by an independent algorithm reviewer
   with the opposite job: reject fixes that would quietly advantage one language over the rest
   (an optimization is only accepted if the same idiom is either available to all peers or is the
   language's genuinely idiomatic form).
4. **The checksum gate holds throughout.** A fix is only a fix if the bit-exact reference
   checksums still pass at both problem sizes.

Every audited case lands in exactly one of three buckets: **cleared** (the number is a real
language cost), **fixed** (implementation bug found, corrected, re-measured), or **rejected fix**
(a proposed optimization that the fairness review vetoed). All three buckets are listed below,
including the embarrassing ones, because a leaderboard is only trustworthy if its corrections are
public.

## Case 1: PHP, cleared

**Suspicion:** PHP runs ~3-5× lighter than Python/Perl/Ruby across the integer axes (for example
sha256: PHP 98× vs Python 601×). Triage hypothesis: the PHP 8 JIT was silently on.

**Finding: refuted.** `opcache.jit=disable` is set, `opcache_get_status()` confirms it, and the
instruction count is identical with and without opcache. PHP's advantage is real interpreter
architecture: typed zvals with native 64-bit integers (Python pays its arbitrary-precision int
machinery on every arithmetic op), plus compile-time constant folding. The archetype label
`interp` is correct and the cells stand.

## Case 2: Ruby k-nucleotide, fixed (the worst cell in the matrix was our bug)

**Suspicion:** Ruby's k-nucleotide sat at **1438× C**, the worst cell in the whole matrix, an
order of magnitude beyond its interpreter peers (Python 50×, Elixir 40×, Perl 36×).

**Finding: implementation bug, not the language.** The DNA generator built the sequence as
~200,000 one-character String objects joined at the end; those short-lived allocations do not
cancel in the size differential and ballooned the count. The study prose at the time blamed
Ruby's hash map. That prose was wrong.

**Fix (commit `0cb2c0f`):** generate into one in-place mutable buffer (4 allocations instead of
200,003). Checksums unchanged. Ruby's cell went from **1438× to 56.4×**, in line with its peers,
and the study narrative, cross-suite tables, matrix and leaderboard were all corrected.

## Case 3: Swift, two fixed, one rejected

**Suspicion:** Swift (a native, ARC language) ran 4-6× C on axes where Rust runs ~1×.

**Finding: about half the gap was fixable source, half is real.** `swiftc -O` keeps bounds,
overflow, exclusivity and CoW checks (it is not C's `-O2`), and the audit deliberately did NOT
switch to `-Ounchecked`, which would be non-idiomatic for production Swift.

- **tak, fixed (commit `2132918`):** a top-level mutable counter forced a `swift_beginAccess`
  exclusivity check on every recursive call; threading it as an `inout` parameter removed it.
  **4.75× to 1.15×.** Checksum unchanged.
- **fannkuch, fixed (same commit):** `withUnsafeMutableBufferPointer` around the flip loop removed
  per-swap CoW/bounds checks. **4.75× to 3.42×**; the residue is the permutation generator's own
  bounds/overflow checks, which idiomatic Swift genuinely pays.
- **k-nucleotide, fix REJECTED:** the proposal (replace the String key with a packed `UInt64`)
  was vetoed by the fairness review, because C#/Kotlin/Scala/Go could equally use an integer key
  and keep String keys; accepting it only for Swift would break the study's cross-language rule.
  Swift's 9.67× **stays** as a genuine cost of its heap-String path.
- **polymorphism 6.4×, cleared:** existential boxing (protocol witness project/destroy per
  dispatch) is how idiomatic Swift dynamic dispatch works; there is no fair source-level fix.

## Case 4: the flattering outliers, cleared

The audit also triaged the cells that look *too good*: C#/Elixir/Scala/Kotlin beating C on
binary-trees (0.28-0.45×). Finding: expected and real. A generational/bump allocator amortizes
allocation in ways `malloc`/`free` cannot; that is the axis working as designed, not a bug.

## Standing corrections

- The arm64 leaderboard reflects all fixes above. The x86_64 cells were refreshed by the green CI
  run of 2026-10-14 and reproduce the non-JVM order within 16%
  ([Study 2](metric-validity.md#study-2-cross-isa-stability-arm64-vs-x86_64)).
- Superseded numbers are never silently edited: fixes land as commits with the old and new values
  stated (see `0cb2c0f`, `2132918`, and the [CHANGELOG](../CHANGELOG.md)).

## Challenge us

If your language looks unfairly slow, the strongest possible response is a pull request:

1. Change only `languages/<lang>/<benchmark>.<ext>`.
2. Keep the algorithm within the study's fairness rules (each `benchmarks/<bench>/README.md`
   states them; no library shortcuts where the suite hand-rolls).
3. The bit-exact checksums must still pass at both sizes (`scripts/bench-fast.sh <lang>` gates
   this locally).

A PR that meets those three rules and lowers a cell is a finding, and it will be merged and
credited. That is how Ruby's worst cell got fixed; the process works.

## Language admission memos (v0.2.0)

Three languages join for v0.2.0: **OCaml**, **VB.NET** and **Fortran**. These memos are step 0 of the
[Method](#method), issued before any implementation exists, so the "your implementation is bad"
critique is answered in advance rather than after the fact. They are **binding** on whoever writes
the code. A deviation is not admitted until the
code is fixed or the memo is amended in this file with the reason; an amendment is a public fairness
event, like a rejected fix above. The post-implementation audit checks every cell against its memo
and against the canonical C source in `languages/c/`. Passing the checksum gate is necessary, never
sufficient.

Facts the memos rely on. `languages.json` already has entries for all three (`ocaml` and `fortran`
with `versionSource: manual`, `vbnet` sharing the `dotnet` EOL slug with `csharp`);
`versions.lock.json` pins `ocaml 5.4`, `vbnet 9.0`, `fortran 14` (the same GCC as the C baseline).
No `languages/<lang>/` directory exists yet. The metric is unchanged: differential
`I(n2) - I(n1)` under qemu-user + the TCG `insn` plugin, normalized to C = 1.0x, median of N.

### Admission gates common to all three

1. **Checksum and secondary** pass at both sizes of every `spec.json`, on arm64 locally and x86_64
   in CI, through `scripts/measure.sh` (line 1 equals the checksum; for benchmarks with a secondary,
   the trailing integer of the last output line equals it).
2. **Output contract.** Line 1 is the bare checksum, line 2 is the same label text as the C source
   (for example `gemm(256) = 682752`). Sizes come from `argv[1]`; defaults equal the C defaults.
3. **No library does the work.** Everything the benchmark READMEs forbid for the existing languages
   (stdlib sort, priority queue, bignum, crypto, matmul, bulk reverse, translate-style batch maps,
   builtin string hash, regex) is forbidden here with the same force.
4. **Allocation lint.** For every benchmark that is allocation-free in C (all except binary-trees,
   k-nucleotide, message-ring, and the one-time setup of buffers), the timed loops must allocate
   nothing: OCaml `Gc.minor_words` delta across the loops is 0, .NET `GC.GetAllocatedBytesForCurrentThread`
   delta is 0, Fortran shows no `malloc` in the loops (checked with the lint build below). A hidden
   allocation (boxed float, boxed Integer, array temporary) is an implementation artifact, not a
   language cost, and blocks admission, except where the sibling implementation on the same runtime has the
   identical allocation and the finding is logged in the closing audit (VB.NET sha256 vs C#). The lint
   instrumentation is removed from the shipped source.
5. **Declared-width parity with C.** Where C declares `int` or `long`, the new language uses its
   32-bit or 64-bit native equivalent unless the table says otherwise. Storage-width deviations
   (OCaml `int` arrays are 8 bytes per element; Fortran has no unsigned bytes) are listed in the
   tables because the metric is instruction count and is blind to cache footprint, but they are
   still disclosed.
6. **Triage on first data.** A new cell more than 10x off its archetype peers on one axis while
   tracking them on the others goes through Method steps 1 to 4 before it is published.

### OCaml (5.4)

**Build.** Image `ocaml/opam:debian-12-ocaml-5.4` (Debian bookworm, glibc 2.36, multi-arch),
`OCAML_VERSION=5.4`. Compile each benchmark with plain `ocamlopt -o /app/<b> <b>.ml`: stdlib only,
no `-package`, no `unix`, no `threads`, no `str`. The Dockerfile asserts at build time that
`ocamlopt -config` reports `flambda: false` (the official tag is non-flambda; a silent switch to a
flambda switch would change the whole inlining story). Forbidden: `-unsafe`, `-O2`/`-O3` (accepted
and ignored without flambda, so passing them would only mislead readers), `-inline N`,
`-unboxed-types`, `-ccopt`, C stubs and `external` declarations, `Obj`, every `unsafe_get`/
`unsafe_set`/`unsafe_chr` variant, `Bigarray`. **Bounds checks stay on**, the same precedent as
Swift `-O` (Case 3): idiomatic production OCaml keeps them. `[@inline]` is allowed on small
non-recursive helpers (`rotr`, `lcg`, `clamp`, `swap`) because C's `-O2` inlines the equivalents
unprompted; no other attribute.

**Runtime.** `runtimeKind: native`, no `runtimeEnv`, no `OCAMLRUNPARAM`, no `Gc.set`, no
`Gc.compact`/`Gc.full_major` calls. The GC is on at its defaults (the generational collector is the
thing binary-trees is meant to measure). A single-domain OCaml 5 program with neither `Thread`
nor `Domain` linked is one OS thread, far under MAX_CPUS=8. Admission includes one early qemu smoke
test with `OCAMLRUNPARAM` unset; if the 5.x runtime needs tuning to start under qemu-user, record
the change in this file instead of tuning silently.

**Monomorphic code.** Annotate integer types on every function that compares or does arithmetic
(`(x : int)`, `(a : int array)`). A comparison the compiler cannot prove to be on `int` becomes a
call to the polymorphic `caml_lessthan` family, which would measure our annotations, not OCaml.
`Stdlib.min`, `max` and `compare` are polymorphic: write explicit `if`. Do not capture `ref`s in
closures inside hot loops (a captured ref is heap-allocated; a local one lives in a register).

**Integer width (the headline OCaml question).** `int` is 63-bit two's complement
(range -2^62 .. 2^62-1) and arithmetic wraps modulo 2^63. The benchmark READMEs say "64-bit"; the
property they actually need is "no intermediate overflows", and the table below verifies it with
real numbers (2^62 = 4.6117e18). `Int64`/`Int32` are **not** used anywhere (boxed outside
unboxing special cases, and not the idiom). `mod` is applied only to non-negative values (OCaml `mod`
takes the sign of the dividend); bit masking uses `land`, and right shifts of masked values use
`lsr`, never `asr`.

| # | Benchmark | Binding rule | Largest intermediate | < 2^62 |
|---|---|---|---|---|
| 1 | fannkuch | `int array` for perm/perm1/count. `Array.blit` is the allowed analogue of C's `memcpy`; the prefix reversal and the perm1 rotation are explicit loops (no `Array.sub`, lists, or reversal helpers). | counters below 1e5 | yes |
| 2 | binary-trees | `type node = Nil \| Node of node * node`; **every** tree node including leaves is one `Node` block (`make 0 = Node (Nil, Nil)`), matching C where leaves are malloc'd. `Nil` is immediate and allocates nothing. Leaf test is `Node (Nil, _)`. Forbidden: `node option` fields (extra `Some` boxes), mutable records, node arrays or pools, `Lazy`, `Obj`, `Gc` calls. No explicit free; the long-lived tree is referenced after the loop. | total 3.2e6 | yes |
| 3 | mandelbrot | Native `float`, operators `+.` `-.` `*.` `/.` only, `Float.fma` forbidden. Keep the whole pixel loop in one function with local `float ref`s so ocamlopt unboxes them (verify with the allocation lint: 0 minor words in the loop). Write `2.0 *. float_of_int y /. float_of_int n -. 1.0` so the evaluation is `(2.0*y)/n` exactly as in C. `t = zr*.zi; zi = t+.t+.ci` verbatim. ocamlopt never contracts to FMA, so the gate is satisfied by construction. | floats | n/a |
| 4 | k-nucleotide | Stdlib **generic** `Hashtbl.t` keyed by `String.sub s i 8` (one allocation per probe, like Java/Kotlin/Go). Default initial size (`Hashtbl.create 16`), no presizing, no `Hashtbl.Make` functor with a custom hash or equality, no integer key, no direct addressing of the 4^8 space. Update with `find_opt` then `replace` (two lookups, mirroring C#'s `TryGetValue` plus indexer); `add` is allowed only on a confirmed miss and never on an existing key (it shadows rather than replaces, and `iter`/`fold` would then visit both bindings and double-count). Generator buffer is a `Bytes`, converted once. | `e*count` 1.3e10; LCG 5.4e8 | yes |
| 5 | reverse-complement | `Bytes` (the mutable byte buffer), `Bytes.get`/`Bytes.set` (checked), hand-written two-pointer loop and the middle-character fix-up, `comp : char -> char` as a `match`, hash via `Char.code`. No `Bytes.map`/`String.map`/`rev`. | `h*31+c` 3.1e10 | yes |
| 6 | sort-search | One `int array`, hand-written median-of-three Hoare quicksort and binary search with C's exact comparison sequence. The `do i++ while a[i] < pivot` scans are `incr` then `while` loops with identical test order. `/ 2` and `mod N` are the native int ops on non-negative values. Native stack recursion (depth about 32). | LCG `state*1103515245+12345` 2.37e18 (0.51 of 2^62) | yes |
| 7 | dijkstra | `int array` heap, CSR arrays, packed key `d*2097152+node`, `/` and `mod` by BASE as written in C. **INF is `max_int`, not `1 lsl 62`**: `1 lsl 62` is `min_int` in OCaml and would break both `nd < dist.(v)` and the final `dist.(i) < INF` test. INF is only ever compared, never added to, and every real distance is below 2e6, so the substitution is exact. Compound conditions use `&&` (short-circuit in OCaml). | LCG 2.37e18; key 4.2e12 | yes |
| 8 | blur | Two flat `int array`s of N*N, swapped between passes, `clamp` as a function, `acc / 16` with `/` on a non-negative int. | 4080 | yes |
| 9 | k-means | Flat `int array`s for points, centroids, sums, counts, assignment. `bd = -1` sentinel and strict `<` as in C. Floor mean with `/` on non-negative ints. | dist 2.6e5; sums 2.0e6 | yes |
| 10 | sha256 | Words are `int` holding a value in [0, 2^32). `rotr x n = ((x lsr n) lor (x lsl (32 - n))) land 0xFFFFFFFF` written out (no rotate intrinsic exists, none is simulated); `x lsl (32-n)` is below 2^62 for the rotation amounts used, and bits lost above bit 62 would not matter anyway. `ch` uses `(lnot e) land g`, which is non-negative because `g` is. Reduce with `land 0xFFFFFFFF` once per assignment statement (a chain of up to five 32-bit addends stays below 2^35, so one mask per statement is exact and is the same masking granularity PHP uses). Digest write-back `(h lsr 24) land 0xFF`. Hand-written, no Digest/Cryptokit. | 5 addends 2.1e10; `x lsl 30` just under 2^62 | yes |
| 11 | lz77 | `Bytes` input (C has `unsigned char[]`), `Char.code` on reads. The match scan is `&&` with C's operand order. WINDOW 512, strict `>`. | 6.1e6 | yes |
| 12 | vm | `int array` stack and locals, `PROG` copied verbatim, dispatch by an `if` chain or a `match` (the README allows a switch, if-chain or jump table; note C uses an if-chain, so the dispatch form is a toolchain consequence). ADD/MUL/SUB masked with `land 0xFFFFFFFF`; SUB of a negative result relies on two's complement `land`, which is exact. | `acc*31` 1.3e11, `i*i` 6.4e11; even a general 32x32 MUL wraps mod 2^63 and keeps the low 32 bits | yes (and wrap-safe) |
| 13 | bigint | `int array` limbs, size N+64 as in C, each in [0, 2^32). `cur = limbs.(i) * k + carry`, `land 0xFFFFFFFF`, `lsr 32`. No `Int64`, no `Zarith`/`Num`. | 2.6e13 | yes |
| 14 | tak | `let rec tak x y z` with a top-level `int ref` counter and `incr calls` at entry (a static global, like C). No memoization, no tail rewrite. OCaml evaluates arguments right to left; harmless, because the three inner calls are always all evaluated and only the counter total is observed. | 2.5e6 calls | yes |
| 15 | polymorphism | **OCaml objects**: `class virtual base a b c` declares the three fields explicitly (`val a = a`, `val b = b`, `val c = c`, so every object carries all three as in C and C#) and `method virtual apply : int -> int`; six concrete `inherit base` classes with distinct formulas; `objs : base array`; fold with `objs.(i)#apply acc`. The type factory (`match t with 0 -> (new t0 a b c :> base) \| ...`) is construction-time only. Rejected as the ranked form: records of closures (that is C's function-pointer asymmetry, which C needed because it has no objects; OCaml has objects) and variants plus `match` (the forbidden type switch). Type from `(s lsr 16) mod 6`. | `x*1000003+a` 1.0e15 | yes |
| 16 | gemm | Flat `int array`s of N*N, loop order i, k, j pinned, `c.(i*n+j) <- c.(i*n+j) + a * b.(k*n+j)`. The "64-bit accumulator" rule is satisfied by 63-bit `int` because the cell maximum is 4.13e6. | 4.1e6 | yes |
| 17 | viterbi | `int array` for `trans`, `emit`, `obs`, `back` (flat `t*S+j`), `path`, two score buffers swapped by reference. Strict `>`. Secondary printed as in C. | 1.6e7 | yes |
| 18 | gbdt | Flat `int array`s (`feat`, `thr`, `leafval`, `sample`; C uses 4-byte `int`, OCaml's are 8 bytes, disclosed), descent `2*node+1`/`2*node+2` with `<=`. | 1800 | yes |
| 19 | message-ring | See below. Token arithmetic `(v * 1103515245 + (id + 1)) land 0xFFFFFFFF` immediately after each transform. | `(2^32-1)*1103515245+32` = 4.74e18 | **no, by 2.8%** |

Shared LCG rows (sort-search, dijkstra, gemm, k-means, blur, lz77, viterbi, gbdt, polymorphism,
sha256 seed): `(2^31-1)*1103515245 + 12345 = 2.3698e18`, which is 0.514 of 2^62. Poly-hash
`h*31 + x` with `h < 1e9+7` is at most 3.1e10 everywhere. These are the only multiplications in the
suite whose magnitude is not trivially small.

**message-ring: the one value that exceeds 2^62, and why it is still safe.** For
`v` above about 4.179e9 (2.7% of the 32-bit range) the true product exceeds `max_int` and the OCaml
result wraps modulo 2^63, possibly negative. Because 2^63 is a multiple of 2^32, the wrapped value is
congruent to the true value modulo 2^32, so `land 0xFFFFFFFF` recovers the exact low 32 bits. The
rule is therefore: mask immediately after every transform, never `mod` an unmasked value, never
`asr`; only the final `v mod 1_000_000_007` is taken, on the masked non-negative token. `Int64` is
**not** mandated (the language manual guarantees the modulo-2^63 semantics; the 16000 hops
of the n1 run already include hundreds of wrapping multiplies, so the gate exercises that path).

**message-ring primitive: OCaml 5 effect handlers, `Effect.Deep`, one domain.** By elimination:
`Thread` and `Event` are systhreads (real pthreads; 32 workers would break the single-OS-thread
rule and exceed MAX_CPUS=8), `Domain` is OS threads and parallelism, Lwt and Eio are libraries absent
from the image (the same exclusion as Perl's `Coro`), a closure-queue CPS encoding is a callback
chain, not a coroutine switch. Effect handlers are in `Stdlib` and are OCaml's language-level
one-shot delimited continuations: a stackful fiber switch with no syscall, the direct analogue of PHP
and Ruby `Fiber` and of C's `swapcontext`. Binding shape: 32 worker fibers created **once** before the
lap loop with `Effect.Deep.match_with`; each worker body is
`for lap = 1 to n do receive; transform; send done`, where receive and send are `Effect.perform`
calls that suspend the fiber and hand its continuation to a hand-rolled single-threaded scheduler
(the same structure as the Rust executor); the transform is inside the worker, never in main; every
hop is exactly one `perform` plus one `continue`; main is the scheduler or a ring fiber; no `Thread`,
`Mutex`, `Condition`, `Domain`, `Event` linked. Expect the instruction track to look light (no
`rt_sigprocmask` syscalls, like Go and Rust); the README's wall-clock caveat applies unchanged and
message-ring stays excluded from the ranking.

**OCaml: flagged decisions.**
- `dijkstra` INF is `max_int` (above); this is an addition to the pre-agreed baseline.
- 63-bit `int` stands in for "64-bit" in the READMEs. Recommend a one-line README note that "an
  integer of at least 63 bits suffices" once OCaml is merged.
- Generic `Hashtbl` over the `Hashtbl.Make` functor is chosen because peers run their default map as
  shipped (Rust default SipHash, Java `HashMap`). A functorial variant is a legitimate challenger PR
  under the "Challenge us" rules only if the same change is judged idiomatic, and it would be recorded
  as such, not slipped in.
- Native objects for polymorphism are the ranked form. Optional **unranked** side measurement:
  the records-of-closures variant, to show readers what the object system costs (precedent: Swift's
  existential boxing, Case 3). It must not enter `results/*.json` envelopes that `make_matrix.py`
  auto-discovers.
- `Bytes` is used exactly where C has `char`/`unsigned char` buffers (reverse-complement, lz77) and
  the k-nucleotide generator; everything else is `int array`.

### VB.NET (.NET 9)

VB.NET is the same CLR, JIT and BCL as C#, so it is the cleanest natural experiment in the suite:
any gap between the two columns is the VB compiler, its defaults and its runtime library, not a
different runtime. That makes the rules below stricter than for a foreign language: every C# choice
that VB can mirror **must** be mirrored.

**Build.** Image `mcr.microsoft.com/dotnet/sdk:${DOTNET_VERSION}` (`DOTNET_VERSION=9.0`), the same
Dockerfile shape as `languages/csharp/Dockerfile`: one subdirectory per benchmark
(`languages/vbnet/<bench>/<bench>.vbproj` + `Program.vb`), published with `-c Release -r $RID
--self-contained true -p:PublishSingleFile=true`, same RID logic, `run` template
`/app/out/{b}/{b}`. `runtimeEnv` identical to C#: `DOTNET_gcServer=0`, `DOTNET_TieredCompilation=0`.
The `.vbproj` sets, explicitly and not by default: `OptionExplicit On`, `OptionStrict On`,
`OptionInfer On`, `OptionCompare Binary`, `RemoveIntegerChecks false`, `InvariantGlobalization true`,
`Optimize true`; no ReadyToRun, trimming, PGO or other publish knobs beyond what the C# projects use.
`MyType` is set to the lightest value that builds (`Empty`); startup cost cancels in the
differential regardless.

**Integer checks stay ON (a deliberate project decision).** VB's default is overflow-checked arithmetic, and
the idiomatic VB program ships that way. `RemoveIntegerChecks` is **not** used in ranked code. VB has
no `unchecked` block, so wraparound cannot be requested locally; the consequences are rules, not
suggestions:

- **`UInteger`, `ULong`, `UShort` arithmetic is banned in ranked code.** It is also checked
  (`UInteger + UInteger` throws on overflow), so it cannot provide wraparound. All 32-bit unsigned
  quantities live in `Long` in [0, 2^32) and are reduced with `And &HFFFFFFFFL`.
- **Hex literals carry the `L` suffix.** `&HB5C0FBCF` is a negative `Integer`; `&HB5C0FBCFL` is the
  intended positive `Long`.
- **Narrowing conversions are checked** (`conv.ovf`): `CByte(h >> 16)` throws for values above 255
  where C# `(byte)` truncates. Mask first: `CByte((h >> 16) And &HFFL)`. Use `CInt`/`CLng` only
  where C# has an explicit cast, and only on values proven in range.
- A silent wrong answer is impossible in this configuration: an unplanned overflow throws and the
  checksum gate fails loudly. That is a feature for an audit.

**Where C# actually relies on unchecked wraparound** (verified by reading every
`languages/csharp/*/Program.cs`; the list is short and exact):

1. `sha256`: every `uint` add (`w[i] = w[i-16]+s0+w[i-7]+s1`, `t1`, `t2`, `e = d+t1`, `a = t1+t2`,
   `h[i] += ...`), and the four truncating `(byte)` write-backs per word (`h[i] >> 24`, `>> 16`, `>> 8`, and `h[i]` itself).
2. `message-ring`: `v * LCG_MUL + addend` on `uint`.

Nothing else wraps: the LCG product `state*1103515245` is 2.37e18 inside `long`, vm MUL is below
2^40, bigint `cur` is `ulong` below 2^46, dijkstra `1L << 62` is a legal `Long`. VB must do instead:
sha256 adds as `(a + b + ...) And MASK` on `Long` (a sum of five 32-bit values is below 2^35, so one
mask per statement is exact), rotr as `((x >> n) Or (x << (32 - n))) And MASK` (VB shifts never
throw, `x << 30` is below 2^62), `ch` as `(e And f) Xor ((Not e) And g)` (non-negative because `g`
is), digest write-back through the masked `CByte`; message-ring as
`v = (v * 1103515245L + addend) And &HFFFFFFFFL` (product at most 4.74e18, below `Long.MaxValue`
9.22e18, so no overflow is even possible).

**Language-trap rules.**
- `Dim a(n)` allocates **n+1** elements. Always write `New Long(n - 1) {}`.
- `/` is floating-point division. Integer work uses `\` and `Mod` only; `/` appears only in
  mandelbrot (doubles). `Option Strict On` turns an accidental `/` into a compile error.
- **Operator precedence differs from C.** `Mod` binds tighter than `+`, so `h * 31 + x Mod P` is
  `h*31 + (x Mod P)`: write `(h * 31 + x) Mod P`. Shifts bind looser than `+`/`-`, and `And`/`Or`/`Xor`
  bind looser than comparison. Parenthesize every mixed expression.
- `AndAlso`/`OrElse` for every boolean condition (`And`/`Or` evaluate both sides and would read out
  of bounds in lz77 and the heap loops). `And`/`Or`/`Xor`/`Not` only for bit operations.
- `Is Nothing` for null tests; `If(a, b, c)` (the operator) never `IIf` (function, non-short-circuit,
  boxes to `Object`).
- Declare every variable with its C# type (`As Long`); `Dim s = 42` infers a checked `Integer`.
- **No `Microsoft.VisualBasic` runtime helpers in timed code** (`Strings.*`, `Conversion.*`,
  `Interaction.*`, `Collection`, late binding, `CInt` on strings). Parse arguments with
  `Integer.Parse`. Hot loops use BCL types and VB operators that compile to plain IL. This is the VB
  analogue of "no library does the work".
- Flat one-dimensional arrays only (no `(i, j)` multi-dimensional arrays, no `List(Of T)` where C#
  uses an array), indexed `i*n+j` exactly as C#.

| # | Benchmark | VB rule | Overflow behaviour under checks |
|---|---|---|---|
| 1 | fannkuch | Line-by-line port of the C# program; `Array.Copy` for perm1 to perm (C# does the same); explicit flip and rotation loops. | none |
| 2 | binary-trees | `NotInheritable Class Node` with public `Left`/`Right`, `New Node(Nothing, Nothing)` leaves, `Is Nothing` test; GC on (workstation, non-concurrent as set by `runtimeEnv`). | none |
| 3 | mandelbrot | `Double`, `2.0 * y / n - 1.0` evaluates `(2.0*y)/n`, `t = zr*zi : zi = t + t + ci` verbatim, `While i < 50 AndAlso tr + ti <= 4.0`. RyuJIT does not contract to FMA, same as C#. | none |
| 4 | k-nucleotide | `Dictionary(Of String, Long)` keyed by `s.Substring(i, K)`, `TryGetValue` then indexer set. **Documented asymmetry:** C# uses the .NET 9 `GetAlternateLookup(Of ReadOnlySpan(Of Char))` zero-allocation probe, which VB cannot express (VB cannot instantiate a generic with a ref struct such as `ReadOnlySpan`). VB therefore allocates one string per probe, like Java/Kotlin/Go. The implementer verifies this once and records the compiler error text in `languages/vbnet/README`; if VB can in fact express it, mirror C# exactly and drop this paragraph. Do not "fix" the gap with an integer key (the Swift k-nucleotide veto in Case 3 applies verbatim). | none |
| 5 | reverse-complement | `Byte()` buffer as C# does; the four ASCII codes are `Const ... As Byte` (65, 67, 71, 84) so no narrowing conversion occurs in the loops; `Comp(c As Byte) As Byte` via the `If(...)` operator; hand-written two-pointer loop and middle fix-up; hash `(h * 31 + s(k)) Mod P` with `s(k)` widened implicitly. No `Array.Reverse`. | none (`h*31` 3.1e10 in `Long`) |
| 6 | sort-search | `Long()` array, hand-written quicksort/binary search; `do..while` scans as `Do : i += 1 : Loop While a(i) < pivot`; `\` for `/ 2`. | LCG 2.37e18 fits `Long` |
| 7 | dijkstra | `Long()`/`Integer()` arrays as in C#, `1L << 62` INF, `key \ BASE`, `key Mod BASE`; heap conditions use `AndAlso`. | key 4.2e12 fits |
| 8 | blur | Flat `Integer()` buffers, `acc \ 16` (not `/`). | none |
| 9 | k-means | `Long()` points/centroids, `Integer()` assignment, strict `<`, `\` for the floor mean. | none |
| 10 | sha256 | The `Long`-with-mask scheme above. `K` and `H0` are `Long()` literals with `L` suffix; block and digest are `Byte()` as in C#, written back through masked `CByte`. No `System.Security.Cryptography`. | **the mandatory change vs C#** (item 1 of the wrap list) |
| 11 | lz77 | `Byte()` input, `AndAlso` chain in C's operand order. | none |
| 12 | vm | `Long()` stack and locals, `PROG` verbatim, `If/ElseIf` chain like C#; `And MASK` after ADD/MUL/SUB (`(a - b) And MASK` on a negative `Long` is exact). | MUL below 2^40 |
| 13 | bigint | `Long()` limbs (C# `uint[]`; 8 vs 4 bytes is a disclosed footprint deviation the metric cannot see), `cur = limbs(i) * k + carry`, `And &HFFFFFFFFL`, `>> 32`. No `System.Numerics.BigInteger`. | cur below 2.6e13 |
| 14 | tak | `Function Tak(x As Integer, y As Integer, z As Integer) As Integer`, `calls` a `Shared`/Module-level `Long`; no memoization. | none |
| 15 | polymorphism | `MustInherit Class Apply` with `MustOverride Function Run(x As Long) As Long`, six non-sealed subclasses (`Overrides`), `Apply()` array, `objs(i).Run(acc)`. Forbidden: `Interface`, delegates/`AddressOf`, `TypeOf ... Is` chains, `Select Case` on a type tag in the fold, `CallByName`/late binding. Factory `Select Case t` at construction time only. | `x*1000003+a` 1e15 fits |
| 16 | gemm | `Long()` A/B/C, i,k,j pinned. | 4.1e6 |
| 17 | viterbi | As C#: `Long()` score buffers, `Integer()` `back`/`path`, strict `>`. | 1.6e7 |
| 18 | gbdt | `Integer()` arrays, `<=`. | 1800 |
| 19 | message-ring | Same primitive as C#: `Async`/`Await` on a single-thread `SynchronizationContext` message loop, `TaskCompletionSource(Of Long)` rendezvous (`Of Long` replaces C#'s `Of UInteger`; the extra 4 bytes in a boxed completion source is a disclosed deviation), 32 workers started once, transform inside the worker, `Task.Factory.StartNew(...).Unwrap()`. No ThreadPool work. Transform per the wrap section. | handled by masking |

**VB.NET: flagged decisions.**
- Putting all unsigned work into `Long` adds a mask (`and`) per modular add and per rotate that C#'s
  `uint` does not execute, in addition to the `add.ovf`-style check instructions. Both are VB
  defaults/limitations, not implementation choices, and are the expected source of the VB sha256 gap
  to C#.
- **Optional unranked side measurement** to separate the two effects: build the same sources with
  `RemoveIntegerChecks true` for **sha256, vm, sort-search** (checks cost only), and a sha256 variant
  that also uses `UInteger` words (the C# idiom, valid only with checks removed). Report the three
  differentials against ranked VB and C#. Output must not land in `results/<date>-<isa>-<bench>.json`
  names that `make_matrix.py` auto-discovers (use a `results/side/` directory or a distinct language
  key that the matrix ignores). This is documentation, never a leaderboard cell.
- C#-vs-VB deltas on **k-nucleotide** and **sha256** are explained by the two asymmetries above and
  must carry that footnote wherever the two columns are compared.

### Fortran (gfortran 14)

Fortran is the second GCC front end in the suite: same middle end, same `-O2`, same code generator
as the C baseline. That makes it the tightest native comparison available, and it also means the
usual Fortran folklore (aliasing rules, column-major arrays, by-reference arguments) can silently
turn an implementation difference into a "language" difference. The rules below close each of those
doors in the direction of "mirror the C source".

**Build.** The same image as the C baseline, `gcc:${GCC_VERSION}` (14; the official image enables
the Fortran front end, and the Dockerfile asserts `gfortran --version` at build time). Free-form
`.f90`, one file per benchmark, compiled by `gfortran -O2 f.f90 -o /app/<name>` and **nothing else**:
the same flag set as C, no `-O3`, no `-march`, no `-ffast-math`, no `-funroll-loops`, no
`-fno-range-check`, no `-fcheck=*`, no `-fwrapv`, no `-ffp-contract=off` (C uses none of these), no
`-cpp`/preprocessor, no `-fopenmp`, no `-fcoarray`. The Dockerfile logs
`gfortran -O2 -Q --help=common | grep -E 'fp-contract|wrapv'` so the defaults are on record next to C's.
One contingency, link-only and not codegen: if `ldd /app/<b>` cannot resolve `libgfortran.so.5`
without `LD_LIBRARY_PATH` (which is forbidden for the qemu guest), link every Fortran binary with
`-static-libgfortran -static-libgcc`. A **lint build** (`-Wall -Wextra -Wconversion
-Warray-temporaries -Wcharacter-truncation`, output discarded) must be clean; it exists to catch
implicit narrowing and compiler-inserted array temporaries (hidden `malloc`), and its warnings are
the Fortran allocation lint.

**Runtime.** `runtimeKind: native`, no `runtimeEnv`, no GC. Output is via formatted `write`: line 1
`write(*,'(I0)') h` (`print *` and list-directed output prepend a space and fail the exact-string
gate), line 2 for example `write(*,'(A,I0,A,I0)') 'tak(', n, ') = ', r`, matching the C label
character for character. The size comes from `get_command_argument(1, buf)` plus an internal
`read(buf, *) n`. The `program` name replaces hyphens with underscores (`k_nucleotide`); the
binary name keeps the hyphen because it comes from the file name.

**Structure rules (each one prevents an implementation artifact).**
- `implicit none` in every unit; kinds from `iso_fortran_env` (`int32`, `int64`, `real64`). Mirror C's
  declared widths: C `int` is `integer(int32)`, C `long` is `integer(int64)`. Every literal that is
  not default integer carries its kind (`1103515245_int64`, `2.0_real64`; a bare `2.0` is
  **REAL(4)**).
- All work lives in module procedures (never internal procedures that capture host variables on a
  hot path, which would add a static-chain argument C does not have). The main program only parses
  the argument, calls a `run` routine, and prints.
- **Scalar dummy arguments are `value`** wherever C passes by value (tak, clamp, rotr, lcg, swap
  indices, hpush/hpop arguments). Default by-reference passing forces stack traffic C does not have.
- **Hot arrays are one-dimensional, flat, 0-based**: `integer(int64), allocatable :: c(:)` then
  `allocate(c(0:n*n-1))`, indexed `i*n + j` exactly as C. A two-dimensional Fortran array is
  column-major and would silently transpose the pinned i, k, j access pattern (gemm) and the stencil
  (blur); child indexing `2k+1` (gbdt) and the CSR layout (dijkstra) must also be flat. Array
  dummies are explicit-shape, assumed-size (`a(0:*)`) or assumed-shape with `contiguous`, never plain
  assumed-shape (a descriptor with a stride multiply per access that C's `long *` does not have).
- **No reliance on short-circuit `.and.`/`.or.`.** Fortran does not guarantee it. Where C writes
  `pos+l < N && l < MAX && in[cand+l] == in[pos+l]` (lz77) or `l < hsize && heap[l] < heap[m]`
  (dijkstra heap), restructure as nested `if`/`exit` with the same test order. The comparison and
  swap sequence is unchanged, so this is a fair rewrite, not a different algorithm. Compound
  conditions over pure scalars with no array access (mandelbrot's loop test) may stay `.and.`.
- **Allowed intrinsics:** `mod`, `iand`, `ior`, `ieor`, `not`, `ishft`, `shiftr`, `shiftl`, `int`,
  `real`, `ichar`, `achar`, `allocate`/`deallocate`, `get_command_argument`, and whole-array
  assignment only for zero-initialisation and fannkuch's `perm = perm1` (the `memcpy` analogue).
  **Forbidden:** `matmul`, `dot_product`, `sum`, `product`, `maxval`, `minval`, `maxloc`, `minloc`,
  `cshift`, `eoshift`, `pack`, `reshape`, `transfer`, negative-stride section reversal
  (`a(n:1:-1)`), rotate/bit-count intrinsics (`ishftc`, `dshiftl`, `dshiftr`, `popcnt`), and any
  array expression that does the algorithm's work.
- **Aliasing is the language's, not ours to fake or to fix.** Fortran may assume dummy arguments do not
  alias, which can let blur/gemm vectorize where C's pointers cannot. That is a real language
  property and stays; C does not get `restrict` added to compensate (the same stance as the LLVM
  auto-vectorization gap on blur).

**mandelbrot and FMA: what the gate protects.** The cross-language bit-exactness argument in the
mandelbrot README is that no multiply sits next to an add. gfortran shares gcc's default
`-ffp-contract=fast` (verify with the logged `--help=common` line). After GCC folds `t + t`, the only
contractable shape expected is `2*t + ci`, and `fma(t, 2, ci)` equals `(t + t) + ci` bit for bit because `2*t`
is exact, so the formulation survives contraction on arm64 (where FMA is baseline). On x86_64 the
default `x86-64` target has no FMA instruction and gfortran uses SSE2, never x87. The in-set count
gate (6518, 26004) is what detects a failure of this reasoning, because one flipped boundary pixel
changes the count. **If the gate fails on either ISA the fix is to reformulate the source, never to
add `-ffp-contract=off` to Fortran alone**: C does not use it, and the flag would only handicap the
Fortran column.

| # | Benchmark | Fortran rule | Hazard closed |
|---|---|---|---|
| 1 | fannkuch | `integer(int32)` perm/perm1/count, `integer(int64)` perm_idx, `perm = perm1` allowed, explicit flip and rotation loops (no `cshift`, no section reversal). | bulk-reverse shortcut |
| 2 | binary-trees | `type node; type(node), pointer :: left => null(), right => null(); end type`; `recursive` make/check/destroy; `allocate(p)` per node (leaves too) and an explicit recursive `deallocate`, mirroring `malloc`/`free`. Pointer components, **not** allocatable components (those recurse-deallocate implicitly and would change the destroy structure). No arena, pool, or array-of-nodes encoding. | arena or pool |
| 3 | mandelbrot | `real(real64)`, `2.0_real64*real(y,real64)/real(n,real64) - 1.0_real64` (evaluates `(2.0*y)/n`), `1.5_real64`, `4.0_real64`, the `t = zr*zi; zi = t + t + ci` form verbatim. gfortran honors parentheses (`-fprotect-parens`) and does no reassociation at `-O2`. | REAL(4) literals; FMA (see above) |
| 4 | k-nucleotide | Hand-rolled open addressing like C: module-level `character(len=8) :: htkey(0:HSIZE-1)`, `integer(int64) :: htcnt(0:HSIZE-1)`, used flags, `HBITS=18`, linear probing, `==` on the 8-character keys. **Hash deviation (documented):** FNV-1a **32-bit**, computed in `int64`: offset basis `h = 2166136261_int64`, then per byte `h = iand(ieor(h, c) * 16777619_int64, 4294967295_int64)` (product below 2^56). C's FNV-1a 64-bit relies on unsigned wrap, which Fortran cannot express without relying on signed overflow that gfortran does not guarantee. The probe sequences therefore differ slightly from C's, which is acceptable because the checksum is `sum encode*count` (hash and order independent) and the load factor is about 0.2; the per-byte `iand` adds 8 instructions per k-mer versus C. No built-in map exists in Fortran, so this is the same position as C's. No direct addressing of the 4^8 space. | signed-overflow UB; direct addressing |
| 5 | reverse-complement | `character(len=1), allocatable :: s(:)` with `allocate(s(0:L-1))`, `ichar`/`achar`, `comp` as nested `if`/`select case` on the character, hand-written two-pointer loop and middle fix-up; hash over `ichar(s(k))`. No `index`/`scan`/`verify`/`translate`-style batch, no `s(L:1:-1)`. | bulk reverse |
| 6 | sort-search | `integer(int64)` array dummy as `a(0:*)`, `recursive subroutine`, C's scan shape (`do; i=i+1; if (a(i) >= pivot) exit; end do`), `/` for `/ 2` and `mod`. Hot LCG product 2.37e18 is inside `int64`. | descriptor strides; stdlib sort |
| 7 | dijkstra | `INF = ishft(1_int64, 62)` (legal in `int64`), `int64` heap and CSR in module-level allocatable arrays (C uses static globals), heap loop conditions split into nested `if`. | non-short-circuit OOB |
| 8 | blur | Flat `integer(int32)` buffers, `clamp` a `value`-argument function, `acc / 16`, pointer swap by swapping which array is src. | column-major stencil |
| 9 | k-means | Flat `integer(int64)` arrays, `bd = -1` sentinel, strict `<`. | `minloc`/`sum` |
| 10 | sha256 | **No unsigned in Fortran: `int64` words in [0, 2^32)**, `iand(x, 4294967295_int64)` for reductions, one mask per statement (a five-term sum is below 2^35), `ishft(x, -n)` is a **logical** shift and `ishft(x, 32-n)` the left shift, rotr written as the explicit two-shift form masked to 32 bits (never `ishftc`: no language here uses a rotate intrinsic, and gcc only auto-recognizes rotates on 32-bit unsigned types, so the missing `ror` is a disclosed language cost). `not(e)` is 64-bit and is `iand`-ed with a non-negative operand. `K`/`H0` as `int(z'428a2f98', int64)` (BOZ needs a kind) or `_int64` decimals. Digest and block as `integer(int32)` arrays holding 0..255 (no unsigned byte; footprint deviation). No `integer(int32)` words relying on signed wrap. | signed-overflow UB; rotate intrinsic |
| 11 | lz77 | `integer(int8)` input is safe here (alphabet 0..5); nested-`if`/`exit` match loop in C's operand order; `WINDOW`, `MIN_MATCH`, `MAX_MATCH` as parameters. | `.and.` OOB read |
| 12 | vm | `integer(int64), parameter :: PROG(0:39) = [integer(int64) :: 0,0,2,0, ...]` verbatim; `integer(int64) :: stack(0:63)`; `select case (op)` or an `if` chain (README allows either; C uses an if-chain, so the form is a toolchain consequence); `iand` with the mask; `mod` only on the final non-negative result. | dispatch shortcut |
| 13 | bigint | `integer(int64)` limbs holding 32-bit values (C has `uint32_t`; 8 vs 4 bytes, disclosed), `cur = limbs(i)*k + carry`, `iand(cur, 4294967295_int64)`, `shiftr(cur, 32)`. No `selected_int_kind` beyond int64, no big-number library. | bignum library |
| 14 | tak | `recursive function tak(x, y, z) result(r)` with `integer(int32), value :: x, y, z`; `calls` an `int64` **module variable** (static global like C, not a host-associated local). | by-reference args; static chain |
| 15 | polymorphism | F2003: `type, abstract :: base` with `integer(int64) :: a, b, c` and `procedure(apply_if), deferred :: apply`; six `type, extends(base)` types binding `apply`; `type :: holder; class(base), allocatable :: p; end type` and an array of `holder` (Fortran cannot have an array of polymorphic elements directly); fold `acc = objs(i)%p%apply(acc)` with `integer(int64), value :: x`. **`select type` is forbidden** (it is the type switch). Procedure-pointer components are also rejected (that is C's function-pointer asymmetry; Fortran has real type-bound dispatch). The construction-time `select case (t)` with `allocate(t0 :: objs(i)%p)` is allowed. Type from `shiftr(s, 16)` then `mod 6`. | manual dispatch |
| 16 | gemm | Flat `int64` A/B/C, i, k, j pinned, no `matmul`, no 2D arrays. | column-major transpose |
| 17 | viterbi | `int64` score buffers swapped by index, `int32` `back` flat `t*S+j`, strict `>`. | none |
| 18 | gbdt | Flat `int32` arrays, descent `2*node+1`/`2*node+2`, `<=`. | none |
| 19 | message-ring | **N/A** (see below). | n/a |

Largest-intermediate check for Fortran: every product in the table is below 2^63 (the largest is the
shared LCG at 2.37e18, and the k-nucleotide FNV step at 2^56), so no `int64` signed overflow is ever
exercised, which is the only way to stay inside what the standard and gfortran guarantee.

**message-ring: Fortran coverage call (N/A).** Standard Fortran has no cooperative
coroutine or fiber primitive. Coarrays are separate images (processes or threads depending on the
runtime), `do concurrent` is a parallel-loop declaration, and OpenMP and pthreads are OS threads, all
of which violate the single-OS-thread rule and the MAX_CPUS=8 plugin constraint. Calling libc
`swapcontext` through `iso_c_binding` would measure C's primitive across an FFI boundary, not
Fortran (the same exclusion as Perl's CPAN `Coro`). This is a documented N/A gap, not a fairness
failure. Required follow-up by the implementer: add `"fortran"` to `"na"` in
`benchmarks/message-ring/spec.json` (the existing `naReason`, "no cooperative concurrency primitive to
measure (see the study README)", is already accurate for both Perl and Fortran), add the Fortran row
and a "Fortran coverage call" paragraph mirroring Perl's to `benchmarks/message-ring/README.md`, and do
not ship a `message-ring.f90`. Fortran therefore reports 18 of 19 benchmarks; its gate is "18/18
applicable green, 1 N/A".

**Fortran: flagged decisions.**
- FNV-1a is 32-bit in `int64` (documented hash deviation, checksum-neutral).
- Flat 0-based arrays and `value` arguments are mandated to mirror C; deviating toward "idiomatic
  Fortran" (2D arrays, by-reference scalars, assumed-shape) is exactly the implementation artifact
  this audit exists to refuse.
- Fortran's no-alias guarantee is kept as a genuine language property.
- `-static-libgfortran -static-libgcc` is the only permitted extra flag, and only if dynamic
  resolution without `LD_LIBRARY_PATH` fails.

### Amendments and open items these memos raise for other documents

1. `benchmarks/sort-search/README.md` and `benchmarks/dijkstra/README.md` state the LCG product as
   about 2.4e10; the real magnitude is `(2^31-1) * 1103515245 = 2.37e18`. The conclusion
   ("needs 64-bit") is unchanged, but the figure is wrong by eight orders of magnitude and the OCaml
   63-bit analysis depends on the correct one. Correct both READMEs.
2. The "64-bit" wording in several READMEs should say "at least 63 bits suffices (verified per
   language in the admission memos)".
3. `benchmarks/message-ring/spec.json` needs `"na": ["perl", "fortran"]` and its README needs the
   Fortran row; this memo does not edit either file.

### Closing audit (v0.2.0)

Scope: all three ports read line by line against `languages/c/*.c`, the C# sources (for VB.NET), the
benchmark READMEs and the memos above; the sources were not edited. Evidence gathered during the audit:
(a) OCaml allocation lint run on the shipped `lang-lab-ocaml` image with `OCAMLRUNPARAM=v=0x400`, comparing
`minor_words` at n1 and n2 for the 16 allocation-free benchmarks: the delta is 0 everywhere except 6 words
(fannkuch) and 1 word (viterbi, gbdt), i.e. no hidden allocation in any timed loop (polymorphism allocates
62565 words at construction, identical at both sizes); (b) the Fortran lint build
(`-Wall -Wextra -Wconversion -Warray-temporaries -Wcharacter-truncation`, `gcc:14`) over all 18 files:
zero warnings; (c) a probe-count simulation of the Fortran k-nucleotide table (FNV-1a 32-bit in `int64`)
against C's FNV-1a 64-bit table: 218,063 vs 217,635 probes at n2 (+0.2%), identical distinct-key counts, so
the hash deviation is checksum-neutral and effectively cost-neutral in probe count.

| Language | Verdict | Fix required |
|---|---|---|
| OCaml 5.4 | **CLEARED** (19/19) | none |
| Fortran (gfortran 14) | **CLEARED** (18/18, message-ring N/A) | none |
| VB.NET (.NET 9) | **CLEARED** (19/19) with the rulings below | documentation wording only (item F1) |

**OCaml.** Algorithmically equivalent to C on every benchmark; memo rules obeyed (stdlib only, plain
`ocamlopt`, bounds checks on, no `Int64`, `max_int` INF in dijkstra, `Node (Nil, Nil)` leaves, `Bytes` only
where C has char buffers, `[@inline]` only on `lcg`/`clampi`/`rotr`/`swap`, all of them in the memo's
allowed set). Rulings on the reported points:
- Native objects for polymorphism: conforms to row 15 (virtual base, three explicit fields, six
  `inherit` classes, `objs.(i)#apply`, factory at construction only). CLEARED.
- `Hashtbl.find_opt` then `replace`, `add` only on a confirmed miss: conforms to row 4. The 18.3x cell trips
  gate 6 (more than 10x from C) but not the triage condition: it sits inside the existing generic-map band
  (PHP 16.0x, Java 17.5x, JavaScript 18.6x) because it has the same shape (string key allocated per
  probe, general-purpose hash, structural equality call). It tracks its peers, so it is published as is.
- gemm 4.4x and the 1.3x to 3.8x range are inside the peer spread (JavaScript 5.75x, Swift 2.83x, C# 2.29x
  on gemm); the cause is language-level (tagged 63-bit ints, bounds checks, no vectorizer), not source shape.
  binary-trees 0.19x is the bump-allocating minor heap with no free, the same class as Kotlin 0.28x and
  Java 0.33x.
- message-ring via `Effect.Deep`: accepted as the memo's primitive, with one disclosed simplification. The
  worker performs a single `Recv` per hop (the memo sketched receive plus send), main resumes each
  continuation in ring order, and the token travels in a module-level `ref` rather than as an effect payload.
  Still exactly one `perform` plus one `continue` per hop, transform inside the worker, 32 fibers created
  once. The cell stays excluded from the ranking; add one sentence to the message-ring README row stating
  that the token is shared state, not a payload, so the cell is not read as a message-passing cost.
- `[@inline]` on small helpers: within the memo allowance. CLEARED.

**Fortran.** Mirrors C on every benchmark: flat 0-based arrays, `value` scalars, explicit-shape or
assumed-size dummies, nested `if`/`exit` for the lz77 and heap conditions, `.and.` only on pure scalars
(mandelbrot) and on `bd < 0 .or. dist < bd` in k-means (scalars, no array access), no forbidden
intrinsic, no `select type`, plain `gfortran -O2`. Rulings on the reported points:
- k-nucleotide FNV-1a 32-bit in `int64`: the memo's documented hash deviation; evidence (c) shows it does not
  change probing behaviour. The 1.31x is the per-byte `iand` plus a 64-bit multiply, as the memo predicted.
- bigint `int64` limbs (1.17x, equal to Rust and Go), sha256 `int64` words with `int32` byte arrays, lz77
  `int8` input: all listed in the memo tables as disclosed footprint deviations; the metric counts
  instructions, not bytes.
- fannkuch `perm(0:n-1) = perm1(0:n-1)`: the section form of the memo-allowed `perm = perm1` analogue of
  C's `memcpy`; not a shortcut, the flip and rotation loops are explicit. CLEARED.
- polymorphism 1.21x: the `holder` array with `class(base), allocatable` (one extra load for the vptr and one
  for the heap object) is the memo-mandated encoding because Fortran has no array of polymorphic elements.
- message-ring N/A: `spec.json` `na` includes `fortran` and the README has the coverage-call row. Done.

**VB.NET.** Same IL-level algorithm as C# on all 19 benchmarks; `.vbproj` matches the memo (Option Strict,
checks on, `MyType Empty`), Dockerfile and `runtimeEnv` are the C# ones, no `Microsoft.VisualBasic` helper,
no `UInteger`/`ULong`, `\` for integer division, `AndAlso`/`OrElse`. Rulings:
1. **sha256 per-hash allocation (w/b/h): ACCEPTED as like-for-like with C#; gate 4 is amended for this one
   cell.** VB.NET exists to isolate the VB compiler from the C# compiler on the same runtime, so VB must
   not be hoisted while C# is not. Hoisting only VB would manufacture a 2.9% gap that is a port choice.
   Hoisting both would change an already-published C# column (arm64 and the three x86_64 runs) for a 2.9%
   effect, below the C# run-to-run spread of 5.5%. **Finding logged against C#:**
   `languages/csharp/sha256/Program.cs` allocates `w` (line 29), `b` (line 55) and `h` (line 60) inside the
   timed loop, unlike C and OCaml, which use static or stack buffers there; it costs C# and VB.NET about 2.9%
   each on sha256 and is not corrected in v0.2.0. If both are ever hoisted it must be one commit for both
   columns with a re-measure. Gate 4 now reads: "...blocks admission, except where the language's sibling
   implementation on the same runtime has the identical allocation and the finding is logged here".
2. **k-nucleotide Substring per probe: CONFIRMED** as the memo's documented asymmetry. The compiler error
   (BC30668, `ReadOnlySpan(Of Char)` obsolete in VB) is recorded in `languages/vbnet/README`, which was the
   memo's condition. Any C#/VB.NET comparison of k-nucleotide must carry the footnote. The measured ratio is
   1.01x, so the footnote exists to explain the allocation difference, not a gap. Do not substitute an
   integer key.
3. **`CInt(...)` on `Long` indices: ACCEPTED, memo amended.** The memo said "CInt only where C# has an
   explicit cast", but C# indexes with a `long` implicitly and Option Strict makes the narrowing explicit,
   so `CInt` is the unavoidable VB spelling of the same source (the alternative, switching the variable
   types to `Integer`, would break the "declare every variable with its C# type" rule). The cost is bounded
   and measured: the dijkstra relax loop and vm (four `CInt(PROG(pc))` per instruction mix) come out at
   1.29x and 1.07x of C#. The setup-loop uses in blur, k-means, gemm, gbdt, viterbi and sort-search are
   outside the timed inner loops. The dijkstra `For e As Long = start(u) To start(u+1)-1` evaluates its
   bound once where C# re-reads `start[u+1]` each iteration; `start` is not written in the loop, so the
   semantics are identical and the effect is at most one load per edge in VB's favour.
4. **Gaps above 1.8x (blur 2.19, k-means 2.14, bigint 1.87): GENUINE overflow-check cost, not a port
   artifact.** Element types, array layout and loop shapes were compared line by line against C#: `blur`
   uses the same `Integer()` buffers and `Clampi`; `k-means` uses the same `Long()` points and `Integer()`
   assignment; `bigint` uses `Long()` limbs (memo row 13) against C# `uint[]`, with `limbs(i) * k + carry`
   a checked 64-bit multiply (multiply, high-half multiply, compare, branch instead of one multiply) where
   C# `ulong` is unchecked. In blur the inner `acc += K(...) * src(...)` is a checked 32-bit multiply plus
   checked add per tap, nine taps per pixel; in k-means `dist += df * df` is a checked 64-bit multiply. The
   same signature appears in the other arithmetic-heavy cells (gemm 1.56, viterbi 1.65, sha256 1.60, tak
   1.45), while the cells with no integer arithmetic in the loop sit at 1.01x to 1.15x. This is the cost the
   project decided to measure ("integer checks stay ON"); the optional `RemoveIntegerChecks` side
   measurement remains the way to quantify it, unranked.
5. mandelbrot 1.15x (floating point loop, only `i += 1` and `count += 1` are integer) is the checked loop
   counter; sources are line-identical to C#. No action.

Fix list:
- **F1 (VB.NET, documentation, non-blocking for the numbers).** `languages/vbnet/README` lines 17 to 20 say
  the C# program "does exactly the same" for sha256. The allocation count matches (three arrays per hash)
  but the byte count does not (VB words are `Long`, C# words are `uint`), so reword to "the same three
  allocations per hash as the C# program (byte sizes differ because the words are Long)". Also add one
  sentence naming the reason `CInt` appears on `Long` indices (ruling 3), which the README already half
  says on its last paragraph.
- **F2 (OCaml, documentation).** Add the sentence from the message-ring ruling (token is shared state) to
  the OCaml row of `benchmarks/message-ring/README.md`.
- No source change is required in any `languages/<lang>/` directory. Nothing in this audit blocks the
  v0.2.0 admission of the three languages.
