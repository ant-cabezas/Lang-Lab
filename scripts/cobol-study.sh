#!/usr/bin/env bash
# COBOL side study driver (OUT OF THE RANKING: never in languages.json / the matrix / CI).
# Builds the version-pinned COBOL images, measures every cell under the same qemu-user + TCG insn
# backend as the matrix (scripts/measure.sh, driven by env N1/N2/CHECK{1,2}_SUM from each
# benchmarks/<b>/spec.json), measures C at the SAME full spec sizes with the existing C image, and
# writes one envelope per column to $RESDIR (default results/cobol/). Nothing is extrapolated: a
# cell is either measured at full size and correct, or recorded as failed with the reason.
#
#   scripts/cobol-study.sh                      # the four headline columns, 15 benchmarks
#   SECONDARY=1 scripts/cobol-study.sh          # + gcobol 16 and GnuCOBOL 4.0-early-dev (secondary file)
#   BENCH="tak vm" scripts/cobol-study.sh       # a subset (dev runs; write elsewhere with RESDIR)
#   RESDIR=/tmp/x IMAGES="gcobol15" scripts/cobol-study.sh
#
# Environment:
#   DATE       envelope date (default: today)           RESDIR  output dir (default results/cobol)
#   IMAGES     image keys to run (default: gnucobol32 gnucobol32nt gcobol15; SECONDARY=1 appends
#              gcobol16 gnucobol4 gnucobol4nt)           BENCH   space-separated subset of the 15
#   PAR        parallel cells (default 6; the guest instruction count is contention-immune, the
#              native checksum gate inside measure.sh is cheap)
#   RUNS       fixed repetitions per size; unset = measure.sh's adaptive default (2, escalating to 5
#              on jitter). Native COBOL is bit-exact, so 2 reps record determinism "exact".
#   RAWDIR     keep per-cell raw measure.sh output here (default: a temp dir that is deleted)
#   SKIP_BUILD=1  reuse already-built images (tags lang-lab-cobol:<key>, lang-lab-c)
#   SKIP_MEASURE=1  re-assemble the envelopes from an existing RAWDIR without measuring (needs the same IMAGES)
#
# Excluded on purpose (they need hand-rolled emulation of machinery COBOL lacks): sha256 (bit ops),
# k-nucleotide (hash map), bigint (bignum). Requires Docker, jq, python3.
# Bash 3.2 compatible (macOS /bin/bash): no mapfile, no associative arrays.
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")/.."

BENCHES_ALL="binary-trees blur dijkstra fannkuch gbdt gemm k-means lz77 mandelbrot polymorphism reverse-complement sort-search tak viterbi vm"
BENCHES="${BENCH:-$BENCHES_ALL}"
RESDIR="${RESDIR:-results/cobol}"
DATE="${DATE:-$(date +%F)}"
PAR="${PAR:-6}"
ISA=arm64   # qemu-aarch64 guest (the image's qemu is the aarch64 build); cross-ISA is not comparable
IMAGES_DEFAULT="gnucobol32 gnucobol32nt gcobol15"
[ "${SECONDARY:-0}" = "1" ] && IMAGES_DEFAULT="$IMAGES_DEFAULT gcobol16 gnucobol4 gnucobol4nt"
IMAGES="${IMAGES:-$IMAGES_DEFAULT}"
GCC_VERSION="$(jq -r '.c // "14"' versions.lock.json)"

tag_of() { echo "lang-lab-cobol:$1"; }

# Which source variants each image runs (original = languages/cobol/<b>.cob, bin = <b>-bin.cob,
# gc = languages/cobol/gcobol/<b>-gc.cob). Only variants whose source file exists are run.
variants_of() {
  case "$1" in
    gnucobol32)   echo "orig" ;;
    gnucobol32nt) echo "orig bin" ;;
    gcobol15|gcobol16) echo "orig gc" ;;
    gnucobol4|gnucobol4nt) echo "orig bin" ;;
    *) echo "unknown image key: $1" >&2; exit 2 ;;
  esac
}

bin_of() {  # bench variant -> binary name, empty when the source does not exist
  case "$2" in
    orig) [ -f "languages/cobol/$1.cob" ] && echo "$1" || true ;;
    bin)  [ -f "languages/cobol/$1-bin.cob" ] && echo "$1-bin" || true ;;
    gc)   [ -f "languages/cobol/gcobol/$1-gc.cob" ] && echo "$1-gc" || true ;;
  esac
}

build_image() {
  local key="$1" tag; tag="$(tag_of "$1")"
  echo ">> building $tag" >&2
  case "$key" in
    gnucobol32)   docker build -q -f languages/cobol/Dockerfile -t "$tag" . >/dev/null ;;
    gnucobol32nt) docker build -q -f languages/cobol/Dockerfile --build-arg 'COBC_FLAGS=-O2 -free -fnotrunc' -t "$tag" . >/dev/null ;;
    gcobol15)     docker build -q -f languages/cobol/Dockerfile.gcobol -t "$tag" . >/dev/null ;;
    gcobol16)     docker build -q -f languages/cobol/Dockerfile.gcobol --build-arg BASE_IMAGE=debian:forky-slim \
                    --build-arg GCOBOL_VER=16 --build-arg GCOBOL_PKG=16.2.0-3 -t "$tag" . >/dev/null ;;
    gnucobol4)    docker build -q -f languages/cobol/Dockerfile.gnucobol4 -t "$tag" . >/dev/null ;;
    gnucobol4nt)  docker build -q -f languages/cobol/Dockerfile.gnucobol4 --build-arg 'COBC_FLAGS=-O2 -free -fnotrunc' -t "$tag" . >/dev/null ;;
  esac
}

# ---- one cell: __cell <key> <bench> <binary> <rawdir> -------------------------------------------
if [ "${1:-}" = "__cell" ]; then
  key="$2"; b="$3"; bin="$4"; raw="$5"
  spec="benchmarks/$b/spec.json"
  if [ "$key" = "c" ]; then img="lang-lab-c"; lang=c; else img="$(tag_of "$key")"; lang=cobol; fi
  out="$raw/$key--$bin"
  if ! docker run --rm "$img" test -x "/app/$bin" 2>/dev/null; then
    echo "build-failed" > "$out.status"; exit 0
  fi
  n1="$(jq -r .n1 "$spec")"; n2="$(jq -r .n2 "$spec")"
  c1="$(jq -r '.checksums.n1.sum' "$spec")"; s1="$(jq -r '.checksums.n1.secondary // ""' "$spec")"
  c2="$(jq -r '.checksums.n2.sum' "$spec")"; s2="$(jq -r '.checksums.n2.secondary // ""' "$spec")"
  rc=0
  docker run --rm -e RUNTIME_KIND=native -e "N1=$n1" -e "N2=$n2" ${RUNS:+-e "RUNS=$RUNS"} \
    -e "CHECK1_SUM=$c1" -e "CHECK1_FLIPS=$s1" -e "CHECK2_SUM=$c2" -e "CHECK2_FLIPS=$s2" \
    "$img" /usr/local/bin/measure.sh "$lang" "$b" -- "/app/$bin" > "$out.json" 2> "$out.err" || rc=$?
  echo "$rc" > "$out.rc"
  echo ">> $key / $bin: rc=$rc $(tr -d '\n' < "$out.json" | jq -r '.differential // empty' 2>/dev/null)" >&2
  exit 0
fi

# ---- driver -------------------------------------------------------------------------------------
if [ -n "${RAWDIR:-}" ]; then RAW="$RAWDIR"; mkdir -p "$RAW"; else RAW="$(mktemp -d)"; trap 'rm -rf "$RAW"' EXIT; fi
mkdir -p "$RESDIR"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo ">> building qemu-insn base" >&2
  docker build -q -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn . >/dev/null
  echo ">> building lang-lab-c (gcc $GCC_VERSION)" >&2
  docker build -q -f languages/c/Dockerfile --build-arg "GCC_VERSION=$GCC_VERSION" -t lang-lab-c . >/dev/null
  for key in $IMAGES; do build_image "$key"; done
fi

# record what each image actually contains (version string + flags the Dockerfile logged)
for key in $IMAGES; do
  docker run --rm "$(tag_of "$key")" sh -c 'cat /app/COBC_VERSION; echo "---FLAGS---"; cat /app/COBC_FLAGS; echo "---LANGV---"; echo "$LANG_VERSION"' > "$RAW/meta-$key.txt"
done
docker run --rm lang-lab-c sh -c 'gcc --version | head -1; echo "---LANGV---"; echo "$LANG_VERSION"' > "$RAW/meta-c.txt"

jobs_file="$RAW/jobs.txt"; : > "$jobs_file"
for b in $BENCHES; do echo "__cell c $b $b $RAW" >> "$jobs_file"; done
for key in $IMAGES; do
  for v in $(variants_of "$key"); do
    for b in $BENCHES; do
      bin="$(bin_of "$b" "$v")"
      [ -n "$bin" ] && echo "__cell $key $b $bin $RAW" >> "$jobs_file"
    done
  done
done
echo ">> $(wc -l < "$jobs_file" | tr -d ' ') cells, parallelism $PAR" >&2
if [ "${SKIP_MEASURE:-0}" != "1" ]; then xargs -P "$PAR" -L 1 "$SELF" < "$jobs_file" || true; fi

# ---- assemble envelopes -------------------------------------------------------------------------
IMAGES="$IMAGES" RAW="$RAW" RESDIR="$RESDIR" DATE="$DATE" ISA="$ISA" BENCHES="$BENCHES" python3 -I - <<'PY'
import json, os, math, glob

RAW, RESDIR, DATE, ISA = os.environ["RAW"], os.environ["RESDIR"], os.environ["DATE"], os.environ["ISA"]
IMAGES = os.environ["IMAGES"].split()
BENCHES = os.environ["BENCHES"].split()

# What each image is, beyond what it logs about itself (the pins live in the Dockerfiles).
INFO = {
    "gnucobol32":   dict(compiler="GnuCOBOL", pin="3.2 from the GNU tarball, sha256 3bb48af46ced4779facf41fdc2ee60e4ccb86eaa99d010b36685315df39c2ee2 (debian:bookworm-slim, gcc 12.2)"),
    "gnucobol32nt": dict(compiler="GnuCOBOL", pin="3.2 from the GNU tarball, sha256 3bb48af46ced4779facf41fdc2ee60e4ccb86eaa99d010b36685315df39c2ee2 (debian:bookworm-slim, gcc 12.2)"),
    "gcobol15":     dict(compiler="gcobol", pin="gcobol-15=15.2.0-16ubuntu1 (ubuntu:26.04)"),
    "gcobol16":     dict(compiler="gcobol", pin="gcobol-16=16.2.0-3 (debian:forky-slim)"),
    "gnucobol4":    dict(compiler="GnuCOBOL", pin="gnucobol4=4.0~early~20200606-7 (debian:trixie-slim)"),
    "gnucobol4nt":  dict(compiler="GnuCOBOL", pin="gnucobol4=4.0~early~20200606-7 (debian:trixie-slim)"),
}
VARIANT_NAME = {"orig": "original", "bin": "bin", "gc": "restricted"}

def meta(key):
    txt = open(os.path.join(RAW, f"meta-{key}.txt")).read()
    flags = langv = ""
    if "---LANGV---" in txt:
        txt, langv = txt.split("---LANGV---")
    if "---FLAGS---" in txt:
        txt, flags = txt.split("---FLAGS---")
    lines = txt.strip().splitlines()
    return (lines[0] if lines else ""), flags.strip(), langv.strip()

def cell(key, bench, bin_):
    base = os.path.join(RAW, f"{key}--{bin_}")
    if os.path.exists(base + ".status"):
        return dict(status="build-failed")
    if not os.path.exists(base + ".rc"):
        return dict(status="not-run")
    rc = int(open(base + ".rc").read().strip() or 0)
    err = ""
    try:
        err = open(base + ".err").read().strip().splitlines()
        err = err[-1] if err else ""
    except OSError:
        pass
    try:
        j = json.loads(open(base + ".json").read())
    except Exception:
        j = None
    if rc == 0 and j and j.get("correct"):
        return dict(status="ok", n1=j["n1"], n2=j["n2"], i_n1=j["i_n1"]["median"], i_n2=j["i_n2"]["median"],
                    differential=j["differential"], runs=j["runs"], determinism=j["determinism"], version=j["version"])
    status = {3: "checksum-fail", 4: "measure-fail"}.get(rc, f"fail-rc{rc}")
    return dict(status=status, note=err)

# ---- C baseline
c_ver, _, c_lv = meta("c")
c_rows = {}
for b in BENCHES:
    r = cell("c", b, b)
    c_rows[b] = r
cenv = dict(study="cobol-side-study", kind="c-baseline", date=DATE, isa=ISA, metric="differential instructions I(n2)-I(n1), qemu-user + TCG insn plugin",
            compiler=f"gcc {c_lv}", compilerVersion=c_ver, flags="gcc -O2",
            results=[dict(benchmark=b, **{k: v for k, v in c_rows[b].items() if k != "version"}) for b in BENCHES])
json.dump(cenv, open(os.path.join(RESDIR, f"{DATE}-{ISA}-c.json"), "w"), indent=1)

def rows_for(key, variants, pick_best):
    ver, flags, langv = meta(key)
    out = []
    for b in BENCHES:
        cands = []
        for v in variants:
            bin_ = {"orig": b, "bin": b + "-bin", "gc": b + "-gc"}[v]
            if not os.path.exists(os.path.join(RAW, f"{key}--{bin_}.status")) and not os.path.exists(os.path.join(RAW, f"{key}--{bin_}.rc")):
                continue   # that source does not exist for this benchmark
            c = cell(key, b, bin_)
            c.update(source=bin_, variant=VARIANT_NAME[v])
            cands.append(c)
        if not cands:
            continue
        ok = [c for c in cands if c["status"] == "ok"]
        chosen = min(ok, key=lambda c: c["differential"]) if (pick_best and ok) else cands[-1] if pick_best else cands[0]
        row = dict(benchmark=b, **chosen)
        cd = c_rows[b].get("differential") if c_rows[b]["status"] == "ok" else None
        row["cDifferential"] = cd
        row["ratio"] = (chosen["differential"] / cd) if (chosen["status"] == "ok" and cd) else None
        if pick_best and len(cands) > 1:
            row["alternatives"] = [dict(source=c["source"], status=c["status"], differential=c.get("differential")) for c in cands]
        row["compiler"] = INFO[key]["compiler"]
        row["compilerVersion"] = ver
        row["flags"] = flags
        row["determinism"] = chosen.get("determinism")
        out.append(row)
    return out, dict(image=f"lang-lab-cobol:{key}", compiler=INFO[key]["compiler"], pin=INFO[key]["pin"],
                     compilerVersion=ver, flags=flags, langVersion=langv)

def write(name, column, key, variants, pick_best, doc):
    rows, m = rows_for(key, variants, pick_best)
    if not rows:
        return None
    env = dict(study="cobol-side-study", column=column, description=doc, date=DATE, isa=ISA,
               metric="differential instructions I(n2)-I(n1), qemu-user + TCG insn plugin",
               ratioMeaning="COBOL differential / C differential at the same full spec sizes (lower is better; C = 1.00)",
               ranked=False, cBaseline=f"{DATE}-{ISA}-c.json", **m, results=rows)
    json.dump(env, open(os.path.join(RESDIR, f"{DATE}-{ISA}-{name}.json"), "w"), indent=1)
    return env

def mrows(key, variants, pick_best):
    return rows_for(key, variants, pick_best)

if "gnucobol32" in IMAGES:
    write("gnucobol32-natural", "gnucobol32-natural", "gnucobol32", ["orig"], False,
          "GnuCOBOL 3.2, the 15 unmodified original sources, plain -O2 -free.")
if "gnucobol32nt" in IMAGES:
    write("gnucobol32-best", "gnucobol32-best", "gnucobol32nt", ["orig", "bin"], True,
          "GnuCOBOL 3.2 with -fnotrunc; per benchmark the lower-instruction correct source of {original, -bin}.")
if "gcobol15" in IMAGES:
    write("gcobol15-natural", "gcobol15-natural", "gcobol15", ["orig"], False,
          "gcobol 15.2, the 15 unmodified original sources (plus the Dockerfile porting patches), final flag set.")
    write("gcobol15-restricted", "gcobol15-restricted", "gcobol15", ["gc"], False,
          "gcobol 15.2, restricted-subset -gc sources written to avoid libgcobol slow paths (not idiomatic COBOL).")

# secondary: gcobol 16 and GnuCOBOL 4.0-early-dev, one file, several columns
sec = []
def add(column, key, variants, pick_best, doc):
    if key in IMAGES:
        rows, m = rows_for(key, variants, pick_best)
        if rows:
            sec.append(dict(column=column, description=doc, **m, results=rows))
add("gcobol16-natural", "gcobol16", ["orig"], False, "gcobol 16.2, original sources (RECURSIVE programs fail to link).")
add("gcobol16-restricted", "gcobol16", ["gc"], False, "gcobol 16.2, restricted-subset -gc sources.")
add("gnucobol4-natural", "gnucobol4", ["orig"], False, "GnuCOBOL 4.0-early-dev, original sources, plain -O2 -free.")
add("gnucobol4-best", "gnucobol4nt", ["orig", "bin"], True, "GnuCOBOL 4.0-early-dev with -fnotrunc; best of {original, -bin} per benchmark.")
if sec:
    json.dump(dict(study="cobol-side-study", kind="secondary", date=DATE, isa=ISA, ranked=False,
                   metric="differential instructions I(n2)-I(n1), qemu-user + TCG insn plugin",
                   ratioMeaning="COBOL differential / C differential at the same full spec sizes (lower is better; C = 1.00)",
                   cBaseline=f"{DATE}-{ISA}-c.json", columns=sec),
              open(os.path.join(RESDIR, f"{DATE}-{ISA}-secondary.json"), "w"), indent=1)
print(f">> envelopes written to {RESDIR}")
PY
