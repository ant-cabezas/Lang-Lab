#!/usr/bin/env bash
# WebAssembly side study smoke: build the qemu backend, the wasm base image and the C lane, measure two
# benchmarks in every C column, and fail unless every cell passed the checksum gate. Checksums only: it does not
# compare ratios with the published envelopes. Used by .github/workflows/wasm-study-smoke.yml (arm64 runner).
set -euo pipefail
cd "$(dirname "$0")/.."
export LANGS=c BENCH="fannkuch polymorphism" PAR="${PAR:-2}" RESDIR="${RESDIR:-/tmp/wasm-smoke-$$}"
export RAWDIR="$RESDIR/raw"
mkdir -p "$RAWDIR"
scripts/wasm-study.sh
python3 - "$RESDIR" <<'PY'
import glob, json, sys
envs = glob.glob(f"{sys.argv[1]}/*-c.json")
if len(envs) != 1:
    sys.exit(f"smoke: expected one C envelope in {sys.argv[1]}, found {len(envs)}")
d = json.load(open(envs[0]))
cells = [(r["benchmark"], c, v["status"]) for r in d["results"] for c, v in r.get("columns", {}).items()]
bad = [x for x in cells if x[2] != "ok"]
print(f"smoke: {len(cells)} cells, {len(bad)} not ok")
if not cells or bad:
    sys.exit(f"smoke FAILED: {bad or 'no cells'}")
PY
echo ">> smoke OK: envelope in $RESDIR"
