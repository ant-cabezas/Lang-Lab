#!/usr/bin/env bash
# WebAssembly side study, runtime experiment (jitter): first look at the per-thread plugin log.
# Runs INSIDE a container; prints the plugin's per-thread lines of every run on one line:
#
#   docker run --rm -i lang-lab-wasm:c bash -c 'cat > /tmp/cpus.sh; bash /tmp/cpus.sh 3 6 \
#     /usr/local/bin/wasmtime run --allow-precompiled /app/wasm/tak.cwasm' < languages/wasm/experiments/runtime/cpus.sh
#
#   cpus.sh <reps> <n> <cmd...>      (n is appended to the command)
# This is how the eight guest threads of a default wasmtime run were found; knob.sh is the systematic version.
# No `set -e` on purpose: a failing guest must still print its line.
reps="$1"; n="$2"; shift 2
for ((i=1;i<=reps;i++)); do
  GLIBC_TUNABLES=glibc.pthread.rseq=0 /opt/qi/qemu-aarch64 -plugin /opt/qi/libinsn.so -d plugin -D /tmp/l "$@" "$n" >/tmp/o 2>/tmp/e
  echo "run$i out=$(head -1 /tmp/o) | $(tr '\n' ';' < /tmp/l)"
done
