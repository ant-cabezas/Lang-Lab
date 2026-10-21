# languages/cobol: the COBOL side study

COBOL is **not a matrix language**: it is not in `languages.json`, `versions.lock.json`, the matrix, the
README leaderboard or CI. Everything here belongs to the side study described in
[`docs/cobol-study.md`](../../docs/cobol-study.md) and is driven by
[`scripts/cobol-study.sh`](../../scripts/cobol-study.sh). Results go to `results/cobol/`.

## Layout

| Path | What it is |
|---|---|
| `<bench>.cob` | The **original** (natural) source of each benchmark, 15 files: the straightforward COBOL port of the C reference (COMPUTE, `PIC S9(n) COMP-5`, `FUNCTION`, ...). This is the "natural code" column. Built by every Dockerfile. |
| `<bench>-bin.cob` | **BINARY variants** (5 files: fannkuch, gbdt, lz77, tak, viterbi). Same algorithm with COBOL 2002 `BINARY-LONG` / `BINARY-DOUBLE` items and single-verb `ADD` / `SUBTRACT` / `MOVE` instead of `COMPUTE`, for the GnuCOBOL decimal path. Used by the "best variant" column. |
| `gcobol/<bench>-gc.cob` | **Restricted-subset variants** for gcobol (15 files, one per benchmark). Written to avoid the front end's slow library paths (rule list in the study). They are a diagnostic of what the compiler can do, **not idiomatic COBOL**. Compiled only by `Dockerfile.gcobol`. |
| `Dockerfile` | GnuCOBOL **3.2** built from the GNU tarball (sha256 pinned), flags `-O2 -free`; `--build-arg COBC_FLAGS="-O2 -free -fnotrunc"` for the `-fnotrunc` image. `COBOL_SOURCE=apt` selects Debian's 3.1.2 instead. |
| `Dockerfile.gcobol` | GCC's COBOL front end **gcobol 15.2** (`gcobol-15=15.2.0-16ubuntu1`, Ubuntu 26.04); build args select 16.2 on Debian forky (secondary). Final flags `-O2 -fno-strict-aliasing -ffree-form -Wl,--export-dynamic`. |
| `Dockerfile.gnucobol4` | GnuCOBOL **4.0-early-dev** (`gnucobol4=4.0~early~20200606-7`, Debian trixie), secondary. |
| `Dockerfile.diag` | Adds valgrind on top of a study image, for the callgrind attribution (diagnostic only). |
| `tools/cg_attrib.py` | The callgrind attribution (libcob decimal/GMP vs libgcobol vs libc vs inline code). |
| `repro/` | Minimal reproducers of compiler bugs found by the study. Nothing was reported upstream. Not built into any image. |

Every Dockerfile logs the compiler version (`cobc --version` / `gcobol-N --version`) during the build and
records `/app/COBC_VERSION` and `/app/COBC_FLAGS`; the study driver copies both into every envelope.

## Rules that keep the study honest

- Same algorithm and the same checksum gate as every other language (`benchmarks/<b>/spec.json`). A variant
  that does not pass the gate at both spec sizes is not a result (the driver records the failure).
- A variant may change how an operation is *written* (verbs, item types, how a table is addressed) but may not
  replace a language mechanism with hand-rolled machinery: recursion stays real recursion, `ALLOCATE` stays
  one allocation per node, dynamic dispatch stays an indirect call.
- Sources are never edited per compiler by hand. The one place gcobol needs a source patch (argument
  reading, pointer `SET`s, a 19-digit picture) is a documented `sed` step in `Dockerfile.gcobol` and applies
  to the *original* sources only.
- Excluded benchmarks: sha256 (bit operations), k-nucleotide (hash map), bigint (bignum). They would measure
  hand-rolled emulation of machinery the language lacks.
