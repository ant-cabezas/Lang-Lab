# WebAssembly side study: runtime experiment

Out of the ranking, like the rest of `languages/wasm/`. These scripts back four envelopes in
`results/wasm/`. Every count is a guest instruction count from qemu-user plus the TCG insn plugin
(`scripts/measure.sh`), arm64, at the full spec sizes, with the checksum gate on.

## Questions

| Script | Question | Envelope kind |
|---|---|---|
| `task1.sh` | Is the C column's wasm/native ratio a property of WebAssembly or of the wasmtime release? The same wasi-sdk 34 modules run under seven wasmtime releases (26.0.1 to 50.0.0). | `runtime-sweep` |
| `task2.sh` | How much of the ratio comes from the compiler release? wasi-sdk 25, 30 and 34, each divided by a native control built with the same clang version, plus `-mcpu=mvp` builds and a 2x2 toolchain by runtime corner. | `sdk-sweep` |
| `task3.sh` | Which V8 tier does the node column measure? Four Node 26.5.0 tiering configurations. | `v8-tiering` |
| `jitter.sh` | Which run flags make wasmtime and V8 count deterministically under qemu? This is where the study's binding flags come from: `TOKIO_WORKER_THREADS=1` plus `-C cache=n` for wasmtime, and `--no-liftoff` for Node. | `jitter` |

Every ratio in these envelopes is a numerator differential divided by a denominator differential, where
the differential is I(n2) - I(n1). **Lower is better**: 1.0 means as many instructions as the native
clang control. The jitter envelope reports `spreadPct = (max - min) / median` of the per-size process
total, in percent. **Lower is better** for that too.

## Validation

The published `runtime-sweep` and `v8-tiering` envelopes (2026-10-27) and `sdk-sweep` envelope (2026-10-28) come
from runs of the scripts in this directory as they are, with every image rebuilt from its pins. They reproduce
the original exploratory run: the same geomeans to four decimals and no cell moved by more than 0.04%, except
V8's Liftoff-only configuration, whose own run-to-run spread reaches 6.8% (largest change 2.7%). The jitter
envelope (2026-10-26) is still the exploratory run.

## Reproduce

You need Docker, jq and python3, plus `lang-lab-wasm:c` (see `languages/wasm/c/Dockerfile`). Raw
output goes to `$EXP_OUT/runtime/raw/`, and `EXP_OUT` defaults to
`${TMPDIR:-/tmp}/lang-lab-wasm-experiments`. Build products go to `$WORK`, which defaults to
`${TMPDIR:-/tmp}/lang-lab-wasm-experiments/runtime-work`. Nothing is written under `results/` unless
you point `ingest.py` there.

```sh
E=languages/wasm/experiments/runtime
$E/build-wt.sh                      # lang-lab-wasm-runtime-wt{26.0.1,...,50.0.0}, about 5 min
$E/task1.sh                         # about 15 min
$E/task3.sh                         # about 20 min
$E/fetch-sdk.sh                     # wasi-sdk 25/30 + LLVM 19.1.5/21.1.4, sha256-pinned, about 2.5 GB
$E/build-sdk.sh 25 19.1.5
$E/build-sdk.sh 30 21.1.4
$E/build-sdk34mvp.sh
$E/build-sdk25wt26.sh               # needs wt26.0.1 and sdk25
$E/task2.sh                         # about 15 min
$E/jitter.sh                        # about 40 min
python3 languages/wasm/experiments/ingest.py "${TMPDIR:-/tmp}/lang-lab-wasm-experiments" results/wasm "$(date +%F)"
```

`ingest.py` also expects the codegen and wallclock raw output (see their READMEs). Expect about 2 hours
in total on an 8-vCPU Docker VM, plus image builds.

Smoke test (one benchmark):

```sh
BENCHES=tak languages/wasm/experiments/runtime/task3.sh
ONLY="wt50-default node-A-noliftoff" REPS=2 BS=tak languages/wasm/experiments/runtime/jitter.sh
```

Reading aids (they print tables and do not write envelopes): `analyze.py <jsonl> <baseline-tag> [tags]`,
`detcmp.py <jsonl> <tagA> <tagB>`, `sdk-table.py <task1+task2 jsonl>`.

## Files

- `m.sh` measures one cell; `sweep.sh` runs one configuration over the 18 compute benchmarks, 3 cells
  in parallel. Wasm cells use `RUNS=5` and native controls use `RUNS=2` (they are bit-exact).
- `Dockerfile.wt` + `build-wt.sh` build the wasmtime swap images. Each release tarball is pinned by
  sha256, and each image precompiles `/app/wt/<b>.cwasm` with its own wasmtime.
- `fetch-sdk.sh`, `build-sdk.sh`, `build-sdk34mvp.sh`, `Dockerfile.sdk25wt26` + `build-sdk25wt26.sh`
  build the sdk sweep images.
- `knob.sh` runs inside the container. `knob-run.sh` and `knob-shim.sh` run one jitter configuration;
  the shim preloads `fixrand.c`'s deterministic `getrandom()` into the guest. `jitter.sh` holds the
  table of every configuration. `cpus.sh` was the first per-thread look.

## Differences from the study run

- `wt50-t1c-concN` was first run without a matching cwasm. That run errored and the module never ran.
  It was then re-run validly under the same label. `jitter.sh` has only the valid form. ingest.py judges
  each (configuration, benchmark, size) block separately, so the published envelope keeps the valid rows
  and lists the failed first attempt under `excluded.droppedFailedBlocks`.
- `knob.sh` gained the `outs=` field, and `knob-run.sh` gained `PRE`, part-way through the run. The
  committed versions are the final ones, and `ingest.py` reads both SUM forms.
- The `wasm-mvp` step was added to `build-sdk.sh` after the sdk 25 image was built. sdk 25 mvp was
  never measured, so the extra directory changes nothing.
- The sdk34mvp build and the toolchain downloads were inline commands, not scripts. The commands are
  the same.
- The study's swap images were deleted after measuring, so `build-wt.sh` rebuilds them from the pinned
  releases.
