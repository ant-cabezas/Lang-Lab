#!/usr/bin/env bash
# WebAssembly side study, runtime experiment: measure ONE (image, configuration, benchmark) cell.
#
#   m.sh <image> <tag> <bench> -- <run template with {b}>
#
# Runs scripts/measure.sh inside <image> (every lang-lab-wasm image carries it at /usr/local/bin) at the
# full spec sizes n1/n2 of benchmarks/<bench>/spec.json, with the checksum gate on, and prints ONE JSON
# line on stdout: measure.sh's own line with {tag, image, cmd} prepended, or a {..., "FAIL": "<last 8
# lines>"} line when measure.sh printed no result. It always exits 0, so a failed cell never stops a sweep.
#
# Environment:
#   RUNS   fixed repetitions per size (default 5; the native controls are run with RUNS=2, they are bit-exact)
#   DENV   extra docker flags, word-split on purpose, e.g. DENV="-e TOKIO_WORKER_THREADS=1"
#   KIND   RUNTIME_KIND passed to measure.sh (default native, also for the wasm runtimes: as in the study)
# The run template is word-split by bash, exactly like scripts/bench-local.sh's run templates.
# Requires Docker and jq. Bash 3.2 compatible.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/../../../.." && pwd)"
[ $# -ge 4 ] || { echo "usage: m.sh <image> <tag> <bench> -- <run template>" >&2; exit 2; }
img="$1"; tag="$2"; b="$3"; shift 3; [ "$1" = "--" ] && shift
tmpl="$*"; cmd="${tmpl//\{b\}/$b}"
spec="$REPO/benchmarks/$b/spec.json"
n1=$(jq -r .n1 "$spec"); n2=$(jq -r .n2 "$spec")
c1=$(jq -r .checksums.n1.sum "$spec"); s1=$(jq -r '.checksums.n1.secondary // ""' "$spec")
c2=$(jq -r .checksums.n2.sum "$spec"); s2=$(jq -r '.checksums.n2.secondary // ""' "$spec")
# The throwaway version ran without `set -e` so that a failing cell still produced its FAIL line; the
# `|| true` keeps that behaviour under set -e.
out=$(docker run --rm -e "RUNTIME_KIND=${KIND:-native}" -e "N1=$n1" -e "N2=$n2" -e "RUNS=${RUNS:-5}" \
  -e "CHECK1_SUM=$c1" -e "CHECK1_FLIPS=$s1" -e "CHECK2_SUM=$c2" -e "CHECK2_FLIPS=$s2" ${DENV:-} \
  "$img" /usr/local/bin/measure.sh "$tag" "$b" -- $cmd 2>&1) || true
j=$(printf '%s\n' "$out" | grep '^{"language"' | tail -1 || true)
if [ -n "$j" ]; then printf '%s\n' "$j" | jq -c --arg t "$tag" --arg i "$img" --arg c "$cmd" '{tag:$t,image:$i,cmd:$c}+.'
else echo "{\"tag\":\"$tag\",\"image\":\"$img\",\"benchmark\":\"$b\",\"cmd\":\"$cmd\",\"FAIL\":$(printf '%s' "$out" | tail -8 | jq -Rs .)}"; fi
