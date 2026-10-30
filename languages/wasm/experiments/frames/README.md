# frames: why binary-trees is slow on wasmtime at equal instructions

**Question.** In the wall-clock experiment, C binary-trees on wasmtime 50 executes 1.02x native clang's
instructions but takes about 1.2 to 1.3x its user time, while V8 running the same module is at parity. What costs
the time? Envelope: `results/wasm/<date>-arm64-frames.json`. Every ratio is a paired user-time differential ratio,
**lower is better**.

## Finding

- **Not the memory system.** Minor page faults over the differential are the same for wasmtime and V8 (half of
  native's: wasm32 nodes are smaller), wasmtime's sys time is flat, and copy-on-write initialisation and the
  pooling allocator change nothing (paired 0.99 and 0.95). The knobs that raise the time
  (`-O signals-based-traps=n`, reservation or guard size 0) make wasmtime insert explicit bounds checks, which
  add instructions; they say nothing about virtual memory.
- **The allocator calls.** Replacing malloc/free with a free list (`bt_fl.c`) shrinks everything and leaves
  wasmtime at 1.20x the free-list clang while V8 is at 0.97x, so most of the gap sits in the 14.85 million
  malloc and free calls the differential contains.
- **The register save and restore code.** Cranelift saves callee-saved registers on aarch64 as a chain of
  stack-pointer updates (`stp x29, x30, [sp, #-16]!` followed by up to five more pre-indexed `stp`, mirrored
  with post-indexed `ldp`); dlmalloc chains six. clang, glibc's allocator and V8 move the stack pointer once and
  store at fixed offsets. Rewriting only dlmalloc's prologue and epilogue in the precompiled module to that form,
  with the same instruction count (`repatch.py`), takes wasmtime from 1.21x clang to 0.96x, level with V8 (0.95x),
  in a paired batch of 30 repetitions. Patching the tree functions alone, or both, gives a similar gain, which
  points to a limit on stack-pointer updates in flight rather than a fixed cost per frame.
- **Microbenchmarks** (`frames`, `prolog`, `chase`): the chained form costs more than linearly with chain length
  (about +0.3 to +4.3 ns per call for 1 to 6 pairs around an 8-instruction body); chained pushes alone or pops
  alone cost little, together they cost about +4 ns; the `[x, w, uxtw]` addressing mode wasm loads use has the
  same latency as `[x, x]`.
- **Not established:** which structure of this core penalises the chained form (the Docker VM exposes no
  performance counters and masks the CPU part number), and whether other cores behave the same.
- `-C inlining=y` is a mitigation available today (paired 0.86 of the default), but it changes the
  instruction count.

## Reproduce

```sh
languages/wasm/experiments/frames/run.sh       # needs lang-lab-wasm:c; about 45 minutes
python3 languages/wasm/experiments/frames/summarize.py \
  "${TMPDIR:-/tmp}"/lang-lab-wasm-experiments/frames/{knobs,patch}.jsonl results/wasm "$(date +%F)"
```

`variants-knobs.json` and `variants-patch.json` hold the exact command line of every variant. Timing on a loaded
host is noisy: the harness pins each process to one CPU, randomises the order of every (variant, size) pair in
each repetition and the summary uses paired ratios; absolute milliseconds are comparable only within a batch.
