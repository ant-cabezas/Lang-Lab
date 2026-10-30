# WebAssembly side study: codegen experiment

Out of the ranking. The question is how much of the C column's wasm/native instruction ratio comes
from the compile pipeline (C optimisation level, Binaryen `wasm-opt`, SIMD) or from a wasmtime
code-generation choice (explicit bounds checks, signal-based traps, lazy table init, Cranelift opt
level, inlining), and how much is WebAssembly itself.

Each wasm configuration is divided by its symmetric native clang 23.1.0 control: -O3 by -O3, and every
other configuration by -O2. The toolchain is clang 23.1.0 (official LLVM release) for native,
wasi-sdk 34 for wasm and wasmtime 50.0.0, all from `lang-lab-wasm-base`. Counts are guest instructions
from qemu-user plus the TCG insn plugin (`scripts/measure.sh`), arm64, at the full spec sizes, with the
checksum gate on.

It produces the `results/wasm/<date>-arm64-codegen.json` envelope. Every ratio in it is the wasm
differential divided by the native differential, where the differential is I(n2) - I(n1).
**Lower is better**: 1.0 means as many instructions as native.

## Reproduce

You need Docker, jq, python3 and `lang-lab-wasm-base` (see `languages/wasm/Dockerfile.base`). Raw
output goes to `$EXP_OUT/codegen/raw/` and logs to `$EXP_OUT/codegen/log/`. `EXP_OUT` defaults to
`${TMPDIR:-/tmp}/lang-lab-wasm-experiments`.

```sh
E=languages/wasm/experiments/codegen
$E/build.sh            # lang-lab-wasm-codegen-{o2,o3,wasmopt,simd}, a few minutes each
$E/run.sh              # 198 cells, about 1.5 hours on an 8-vCPU Docker VM
python3 $E/summarize.py "${TMPDIR:-/tmp}/lang-lab-wasm-experiments"/codegen/raw/{o2,o3,wasmopt,simd}.txt
$E/checks.sh           # identity checks behind the envelope notes
$E/disasm.sh           # disassembly dumps for polymorphism, dijkstra and tak
python3 languages/wasm/experiments/ingest.py "${TMPDIR:-/tmp}/lang-lab-wasm-experiments" results/wasm "$(date +%F)"
```

Smoke test (o2 image only, one benchmark):

```sh
CONFIGS=o2 languages/wasm/experiments/codegen/build.sh
BENCHES=tak VARIANTS="o2:native o2:wasm o2:knob/bounds" languages/wasm/experiments/codegen/run.sh
```

## Files

- `Dockerfile` builds one image per configuration. `KNOBS=1` (o2 only) also compiles every module
  with each wasmtime knob set into `/app/knob/<k>/`, and writes the flags to `FLAGS`. The cwasm is
  compiled with the same flags it is run with.
- `build.sh`, `run.sh`, `run-batch.sh` and `cell.sh` do the measurement. `cell.sh` runs inside the
  image.
- `summarize.py` prints the reading tables. `checks.sh` shows that `-O opt-level=1` (copt1) produces
  the default cwasm byte for byte, so copt1 is not measured. It also shows that `-C inlining=y` does
  change the code.
- `disasm.sh` writes the dumps that the per-dispatch explanations were read from. In `model/`,
  `dijkstra-count.c` and `dijkstra-model.py` predict dijkstra's differential from per-block counts.
  `polymorphism-model.py` predicts polymorphism's dispatch cost. Both predicted ratios are lower is
  better: 1.76 for dijkstra and 1.9739 for polymorphism, against 1.9738 measured.

## History

- The published envelope (`results/wasm/2026-10-27-arm64-codegen.json`) comes from one clean run of `build.sh`
  and `run.sh` as they are in the repo, with the binding wasmtime configuration (`TOKIO_WORKER_THREADS=1`,
  `-C cache=n`) and `measure.sh`'s adaptive RUNS (every wasm cell ends at 5).
- An earlier exploratory run used wasmtime's default threads and lost cells to a Docker disk-full incident (they
  were re-run then). Its geomeans match the published ones to four decimals and no cell differs by more than 0.02%.
- copt1 (`-O opt-level=1`) is not measured: its cwasm is byte-identical to the default for all 18 modules
  (`checks.sh`).
