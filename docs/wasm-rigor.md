# WebAssembly study: rigor definitions

This page binds the vocabulary used in [`wasm-study.md`](wasm-study.md) and in every
`languages/wasm/<lang>/lane.json`. It does not change what is measured; it fixes how results are read.

## Primary ratio

**Primary ratio** = `wasm column differential / native control differential`, same language, same
canonical sources (plus documented build-time transforms on both sides when required).

- **Numerator:** `wasmtime` or `node` (V8 TurboFan with `--no-liftoff`), as in the study's binding runtime table.
- **Denominator:** the lane's **`native` column** with `columnRoles.native = control` (same compiler tree and
  configure flags as the wasm build, wherever the toolchain allows).

Lower is better; 1.00 = no instruction overhead over that control on this backend.

## Reference and check columns

Columns in `extraColumns` are never mixed into the **headline** geomean:

| `columnRoles` | Meaning |
|---|---|
| `control` | Denominator for primary wasm ratios (`native`). |
| `wasm` | Primary wasm runtimes (`wasmtime`, `node`). |
| `reference` | Context only (matrix image, CoreCLR, gcc baseline, etc.). Shown in the reference table. |
| `check` | Validates a transform (e.g. C `clang-lp64`); not a ranking column. |

## Coverage

Each headline row states `measured of 18` for wasmtime and V8 separately. Benchmarks listed in
`lane.json` → `na` are excluded from geomeans; the reason is copied into the envelope.

Lanes with **`partialControl: true`** have a native control that does not cover every benchmark at
full fidelity (e.g. C# k-nucleotide on Mono preview.7); headline geomeans are over the measured subset only.

## What the ratio excludes

- **`wasmtime compile` / module parse** on a cold path (modules are precompiled to `.cwasm` at image build).
- **Cranelift tier-up inside wasmtime** for the shipped config (precompiled code is fixed at build time).
- **Cross-language comparison:** geomeans in the headline table sort languages for readability only; they are not
  a league table (different engines, transforms, and benchmark coverage).

## Spread and repetitions

Each measured cell records **`maxSpreadPct`**: worst `(max−min)/median` across `i_n1` and `i_n2` over the
runs `measure.sh` took (2 when bit-exact, up to 5 on jitter). Per-benchmark tables footnote the worst spread
among native, wasmtime, and V8 for that cell.

## V8 tiers

- **Binding column:** TurboFan via `--no-liftoff` (fair comparison to optimized wasmtime code).
- **Secondary scenario:** Liftoff-only (see `WASM-V8-LIFTOFF` in the study page, from the tiering experiment on C).

## Replication

Published numbers are **arm64 guest instruction counts** from one machine configuration. `scripts/wasm-smoke.sh` (also run by CI on an arm64 runner) runs a **smoke**
subset (C, two benchmarks) to guard against harness drift; a full re-measure is manual (`scripts/wasm-study.sh`).

Fairness reviews for suspicious cells: [`wasm-fairness-audit.md`](wasm-fairness-audit.md).
