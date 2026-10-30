# Languages with no wasm column: the evidence

Investigated on 2026-10-26 on the study's base image (`lang-lab-wasm-base`: wasi-sdk 34, wasmtime 50.0.0, Node
26.5.0). Each language was tried on its most promising WASI route; this page records what was run and what it
printed, so the verdicts in [`docs/wasm-study.md`](../../docs/wasm-study.md#languages-with-no-wasm-column) can
be checked. Nothing here is a measurement that enters any table.

Two findings apply to every language:

- wasmtime 50.0.0 on aarch64 runs WasmGC (`struct.new`), exception handling (`try_table`/`throw`) and tail
  calls (`return_call`) with no flags (they are on by default since wasmtime 47). Stack switching
  (`cont.new`) is rejected ("cannot define continuation types when stack switching is disabled").
- `-W all-proposals=y` makes wasmtime 50 on aarch64 refuse every module ("the wasm_stack_switching feature is
  not supported on this compiler configuration"), so toolchain documentation that recommends it does not
  apply here.

## OCaml

- **Route:** wasm_of_ocaml 6.5.0 (installed with opam on OCaml 5.4.0), `--enable wasi`; Debian trixie's
  Binaryen. The module needs GC, exceptions and tail calls and runs on wasmtime 50 and `node:wasi` with no
  flags.
- **Blocker:** OCaml `int` is **31 bits** under wasm_of_ocaml (documented upstream), and 14 of the 18 sources
  rely on 63-bit integer arithmetic (modular polynomial hashes, LCGs, 32-bit masks).
  - fannkuch and tak print the correct checksums at both sizes.
  - reverse-complement prints 32018730 instead of 827974717 (n1) and 444387340 instead of 533032773 (n2).
  - sort-search raises `Invalid_argument("index out of bounds")`.
- **Why not rewrite:** an `Int64` port computes the same result but changes the native cost, which the
  study's rule 1 forbids. A WASI build of `ocamlrun` would also be 32-bit, with the same problem.
- **Fair control would also differ:** wasm_of_ocaml compiles bytecode, so its like-for-like native column is
  `ocamlrun`, not the matrix's `ocamlopt`. On fannkuch (differential, instructions): `ocamlopt` 214,592,024;
  `ocamlrun` 2,521,954,755; wasm_of_ocaml on wasmtime 451,460,807.

## Fortran

- **flang:** no upstream wasm32 build of the flang runtime was found; the known out-of-tree patches target
  emscripten, not WASI.
- **LFortran 0.68.0** (conda-forge, linux-aarch64, `lfortran-0.68.0-he6bc062_0.conda`, sha256
  `2938147b5b4d446b0f0d488d549ce38705e78cf8e67028d770f67898409bf9f2`; prints "Status: alpha", built on LLVM
  21.1.7):
  - Native fannkuch passes (`LFORTRAN_LINKER=gcc`): 228/16 at n=7, 8629/30 at n=9.
  - `--target=wasm32-wasi` fails three ways: the package lacks `lfortran_runtime_wasm_wasi.o` (it was built
    from the v0.68.0 source, sha256 `1f1d1c14a746eccf7295e95877ad46207f3676c0a9816e26057720e269fa4c26`); the
    link step uses the retired `wasm32-wasi` triple, for which wasi-sdk 34 ships no libraries (`-lc` not
    found; linking by hand with `wasm32-wasip1` works); and the module defines its own `_start` and **ignores
    argv**: `wasmtime run fannkuch.wasm 9` prints the n=7 result (228 / 16). Node behaves the same.
- Either route would also need its own native column, since the matrix's gfortran 14 is a different compiler.

## Perl

- There is no official WASI Perl. The one port, zeroperl (Perl 5.42.0 by default, no releases, last commit
  2026-04-13, self-described experimental), uses Asyncify for `setjmp`/`longjmp` (a whole-module
  transformation whose cost is the port's, not WebAssembly's), produces a reactor module with a Perl-specific
  entry argument, and needs a cross-compiled `Configure`.
- Not built or measured, by decision: the result would measure that port. A fair version would need a native
  perl built with clang 23 and the same `Configure`.

## Elixir

- There is no BEAM (ERTS) port to WASI.
- AtomVM's WebAssembly builds (v0.7.0-beta.0) are emscripten builds for Node and the browser, which need
  emscripten's JavaScript glue and cannot run under `node:wasi` or wasmtime. AtomVM's native function table
  has no `:atomics`, which 10 of the 18 Elixir sources use. Popcorn, which runs Elixir on AtomVM in the
  browser, documents big integers as "not fully supported".
- AtomVM is also a different virtual machine from BEAM (no JIT), so there would be no same-engine native
  control.
