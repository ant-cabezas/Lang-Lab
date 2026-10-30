#!/usr/bin/env bash
# WebAssembly side study driver (OUT OF THE RANKING: never in languages.json or the matrix; CI only runs
# scripts/wasm-smoke.sh).
# For every language with a languages/wasm/<lang>/lane.json, measures the same benchmarks natively and
# as WebAssembly (wasmtime and Node's V8) under the same qemu-user + TCG insn backend as the matrix
# (scripts/measure.sh, driven by env N1/N2/CHECK{1,2}_SUM from each benchmarks/<b>/spec.json), and
# writes one envelope per language to $RESDIR (default results/wasm/). Nothing is extrapolated: a cell
# is either measured at full size with the checksum gate passing, or recorded as failed with the reason.
#
#   scripts/wasm-study.sh                        # every lane, every column, the 18 compute benchmarks
#   LANGS="c rust" scripts/wasm-study.sh         # a subset of lanes
#   BENCH="tak vm" RESDIR=/tmp/x scripts/wasm-study.sh   # a subset of benchmarks (dev runs)
#
# Environment:
#   DATE      envelope date (default: today)        RESDIR  output dir (default results/wasm)
#   LANGS     lanes to run (default: every languages/wasm/*/lane.json)
#   BENCH     space-separated subset of the 18 compute benchmarks (message-ring needs threads: excluded)
#   WASM_COLUMNS  columns to run (default: native wasmtime node plus each lane's extraColumns)
#   PAR       parallel cells (default 3; the guest instruction count is contention-immune)
#   RUNS      fixed repetitions per size; unset = measure.sh's adaptive default (2, escalating to 5)
#   RAWDIR    keep per-cell raw measure.sh output here (default: a temp dir that is deleted)
#   SKIP_BUILD=1    reuse already-built images
#   SKIP_MEASURE=1  re-assemble the envelopes from an existing RAWDIR without measuring
#   SKIP_IF_OK=1    skip a cell when RAW already has rc=0 and a passing checksum json (safe retries)
#
# lane.json schema (one per languages/wasm/<lang>/): nativeImage/nativeRun/nativeEnv/nativeKind,
# wasmImage/wasmtimeRun/nodeRun/wasmKind/wasmEnv, optional extraColumns {name: {image, run, env, kind,
# role, benchmarks}}, matrixPins {matrix-lang: version}, versions, transforms, asymmetries, na {bench: reason}. An extra column with a
# `benchmarks` list is measured for those benchmarks only. A column's kind only labels the cell (measure.sh
# changes behaviour only for kind=launcher); the node column shares the lane's wasmKind with wasmtime. Run templates carry a {b} placeholder
# and an absolute argv[0]; measure.sh appends the size. An image named lang-lab-<lang> is the matrix
# image and is built from languages/<lang>/Dockerfile exactly as scripts/bench-local.sh builds it.
# Requires Docker, jq, python3. Bash 3.2 compatible (macOS /bin/bash): no mapfile, no associative arrays.
set -euo pipefail
SELF="$(cd "$(dirname "$0")" && pwd)/$(basename "$0")"
cd "$(dirname "$0")/.."

ISA=arm64   # the wasm images carry the aarch64 qemu

# column_field <lang> <column> <field>: image|run|kind|env (env as K=V lines)
column_field() {
  jq -r --arg c "$2" --arg f "$3" '
    def col: if $c == "native" then {image: .nativeImage, run: .nativeRun, env: (.nativeEnv // {}), kind: (.nativeKind // "native")}
             elif $c == "wasmtime" then {image: .wasmImage, run: .wasmtimeRun, env: (.wasmEnv // {}), kind: (.wasmKind // "native")}
             elif $c == "node" then {image: .wasmImage, run: .nodeRun, env: (.wasmEnv // {}), kind: (.wasmKind // "native")}
             else (.extraColumns[$c] // {}) | {image, run, env: (.env // {}), kind: (.kind // "native")} end;
    col | if $f == "env" then (.env | to_entries[] | "\(.key)=\(.value)") else (.[$f] // "") end
  ' "languages/wasm/$1/lane.json"
}

# ---- one cell: __cell <lang> <column> <bench> <rawdir> --------------------------------------------
if [ "${1:-}" = "__cell" ]; then
  lang="$2"; col="$3"; b="$4"; raw="$5"
  spec="benchmarks/$b/spec.json"
  out="$raw/$lang--$col--$b"
  img="$(column_field "$lang" "$col" image)"; tmpl="$(column_field "$lang" "$col" run)"
  kind="$(column_field "$lang" "$col" kind)"
  if [ -z "$tmpl" ] || [ "$tmpl" = "null" ]; then echo "no-run-template" > "$out.status"; exit 0; fi
  runcmd="${tmpl//\{b\}/$b}"
  envflags=()
  while IFS= read -r kv; do [ -n "$kv" ] && envflags+=(-e "$kv"); done < <(column_field "$lang" "$col" env)
  n1="$(jq -r .n1 "$spec")"; n2="$(jq -r .n2 "$spec")"
  c1="$(jq -r '.checksums.n1.sum' "$spec")"; s1="$(jq -r '.checksums.n1.secondary // ""' "$spec")"
  c2="$(jq -r '.checksums.n2.sum' "$spec")"; s2="$(jq -r '.checksums.n2.secondary // ""' "$spec")"
  rc=0
  # $runcmd is word-split on purpose (bash), exactly like bench-local.sh's run template.
  docker run --rm -e "RUNTIME_KIND=$kind" -e "N1=$n1" -e "N2=$n2" ${RUNS:+-e "RUNS=$RUNS"} \
    -e "CHECK1_SUM=$c1" -e "CHECK1_FLIPS=$s1" -e "CHECK2_SUM=$c2" -e "CHECK2_FLIPS=$s2" \
    ${envflags[@]+"${envflags[@]}"} "$img" /usr/local/bin/measure.sh "$lang" "$b" -- $runcmd \
    > "$out.json" 2> "$out.err" || rc=$?
  echo "$rc" > "$out.rc"
  echo ">> $lang / $col / $b: rc=$rc $(tr -d '\n' < "$out.json" | jq -r '.differential // empty' 2>/dev/null || true)" >&2
  exit 0
fi

# ---- driver -------------------------------------------------------------------------------------
BENCHES_ALL="$(find benchmarks -name spec.json | sed 's:^benchmarks/::; s:/spec.json$::' | grep -vx message-ring | sort | tr '\n' ' ')"
BENCHES="${BENCH:-$BENCHES_ALL}"
LANGS="${LANGS:-$(for f in languages/wasm/*/lane.json; do basename "$(dirname "$f")"; done | tr '\n' ' ')}"
# A subset or re-assembly run must not overwrite the published envelopes (same DATE, fewer cells).
if [ -z "${RESDIR:-}" ] && { [ -n "${BENCH:-}" ] || [ -n "${WASM_COLUMNS:-}" ]; }; then
  echo "wasm-study.sh: BENCH/WASM_COLUMNS subsets need an explicit RESDIR (results/wasm holds full envelopes)" >&2; exit 2
fi
if [ "${SKIP_MEASURE:-0}" = "1" ] && [ -z "${RAWDIR:-}" ]; then
  echo "wasm-study.sh: SKIP_MEASURE=1 re-assembles an existing RAWDIR; set RAWDIR" >&2; exit 2
fi
RESDIR="${RESDIR:-results/wasm}"
DATE="${DATE:-$(date +%F)}"
PAR="${PAR:-3}"

if [ -n "${RAWDIR:-}" ]; then RAW="$RAWDIR"; mkdir -p "$RAW"; else RAW="$(mktemp -d)"; trap 'rm -rf "$RAW"' EXIT; fi
mkdir -p "$RESDIR"

columns_of() {  # lang -> its column names
  if [ -n "${WASM_COLUMNS:-}" ]; then echo "$WASM_COLUMNS"; return; fi
  echo "native wasmtime node $(jq -r '(.extraColumns // {}) | keys | join(" ")' "languages/wasm/$1/lane.json")"
}

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  echo ">> building qemu-insn base and wasm base" >&2
  docker build -q -f languages/_base/Dockerfile.qemu-insn -t lang-lab-qemu-insn . >/dev/null
  docker build -q -f languages/wasm/Dockerfile.base -t lang-lab-wasm-base . >/dev/null
  for lang in $LANGS; do
    echo ">> building lang-lab-wasm:$lang" >&2
    docker build -q -f "languages/wasm/$lang/Dockerfile" -t "lang-lab-wasm:$lang" . >/dev/null
    for col in $(columns_of "$lang"); do
      img="$(column_field "$lang" "$col" image)"
      case "$img" in
        lang-lab-wasm*|"") : ;;
        lang-lab-*)
          m="${img#lang-lab-}"
          if [ ! -f "$RAW/built-$m" ]; then
            # the lane's own pin wins (matrixPins), so a matrix version bump cannot silently change a
            # native control away from the compiler the wasm build uses; otherwise versions.lock.json
            ver="$(jq -r --arg l "$m" '.matrixPins[$l] // empty' "languages/wasm/$lang/lane.json")"
            [ -n "$ver" ] || ver="$(jq -r --arg l "$m" '.[$l]' versions.lock.json)"
            arg="$(jq -r --arg l "$m" '.[$l].buildArg' languages.json)"
            echo ">> building matrix image $img ($ver)" >&2
            docker build -q -f "languages/$m/Dockerfile" --build-arg "${arg}=${ver}" -t "$img" . >/dev/null
            : > "$RAW/built-$m"
          fi ;;
      esac
    done
  done
fi

# record what each image contains
for lang in $LANGS; do
  # a re-assembly keeps the toolchain record of the images that were measured
  if [ "${SKIP_MEASURE:-0}" = "1" ] && [ -s "$RAW/toolchain-$lang.txt" ]; then continue; fi
  docker run --rm "lang-lab-wasm:$lang" sh -c 'cat /app/TOOLCHAIN 2>/dev/null || true' > "$RAW/toolchain-$lang.txt"
done

jobs_file="$RAW/jobs.txt"; : > "$jobs_file"
for lang in $LANGS; do
  for col in $(columns_of "$lang"); do
    for b in $BENCHES; do
      if jq -e --arg b "$b" '(.na // {}) | has($b)' "languages/wasm/$lang/lane.json" >/dev/null; then continue; fi
      # an extra column may exist for some benchmarks only (extraColumns.<col>.benchmarks)
      if jq -e --arg c "$col" --arg b "$b" '(.extraColumns[$c].benchmarks // null) as $l | $l != null and ($l | index($b) | not)' \
           "languages/wasm/$lang/lane.json" >/dev/null; then continue; fi
      if [ "${SKIP_IF_OK:-0}" = "1" ]; then
        rcf="$RAW/$lang--$col--$b.rc"
        if [ -f "$rcf" ] && [ "$(cat "$rcf")" = "0" ] && jq -e '.correct == true' "$RAW/$lang--$col--$b.json" >/dev/null 2>&1; then
          continue
        fi
      fi
      echo "__cell $lang $col $b $RAW" >> "$jobs_file"
    done
  done
done
echo ">> $(wc -l < "$jobs_file" | tr -d ' ') cells, parallelism $PAR" >&2
if [ "${SKIP_MEASURE:-0}" != "1" ]; then xargs -P "$PAR" -L 1 "$SELF" < "$jobs_file" || true; fi

# ---- assemble envelopes -------------------------------------------------------------------------
export LANGS RAW RESDIR DATE ISA BENCHES WASM_COLUMNS="${WASM_COLUMNS:-}"
python3 "$(dirname "$SELF")/assemble_wasm_envelope.py" --all-langs "$RAW" "$DATE" "$ISA"
