#!/usr/bin/env bash
# WebAssembly side study, frames diagnostic (OUT OF THE RANKING): why C binary-trees takes 1.2 to 1.3x
# native clang's user time on wasmtime 50 while executing 1.02x the instructions.
#
#   languages/wasm/experiments/frames/run.sh            # everything, about 45 minutes
#   REPS=5 languages/wasm/experiments/frames/run.sh     # quick look (noisy)
#
# Steps, all inside one container of lang-lab-wasm:c (languages/wasm/c/Dockerfile) with this directory at /diag:
#   1. wasmtime run-configuration and code-generation variants of binary-trees.wasm (each cwasm compiled with
#      the flags it runs with), plus bt_fl.c (malloc/free replaced by a free list) natively and as wasm;
#   2. repatch.py: dlmalloc's, the tree functions', and both frames rewritten from Cranelift's chained form to
#      one stack adjustment (same instruction count);
#   3. two timing batches with bt_time.py (user time, sizes 10 and 16, every pair in random order each rep);
#   4. the aarch64 frame microbenchmarks (frames, prolog, chase).
# Output: $EXP_OUT/frames/{knobs,patch}.jsonl and micro.txt (EXP_OUT default ${TMPDIR:-/tmp}/lang-lab-wasm-experiments);
# summarize.py turns them into results/wasm/<date>-arm64-frames.json (ratios: lower is better).
# Needs the image lang-lab-wasm:c. Pins the measured processes to CPU ${CPU:-6}. Bash 3.2 compatible.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${EXP_OUT:-${TMPDIR:-/tmp}/lang-lab-wasm-experiments}/frames"; mkdir -p "$OUT"
REPS="${REPS:-25}"; CPU="${CPU:-6}"; C=lang-lab-wasm-frames
docker rm -f "$C" >/dev/null 2>&1 || true
docker run -d --name "$C" --entrypoint sleep lang-lab-wasm:c 36000 >/dev/null
trap 'docker rm -f "$C" >/dev/null 2>&1 || true' EXIT
docker cp "$HERE/." "$C:/diag"
docker exec "$C" bash -euc '
cd /diag; W=/app/wasm/binary-trees.wasm
wasmtime compile -O memory-init-cow=n $W -o cow_n.cwasm
wasmtime compile -O signals-based-traps=n $W -o sbt_n.cwasm
wasmtime compile -O memory-reservation=0 -O memory-guard-size=0 $W -o res0.cwasm
wasmtime compile -O memory-guard-size=0 $W -o guard0.cwasm
wasmtime compile -O memory-reservation-for-growth=1073741824 -O memory-reservation=0 $W -o grow1g.cwasm
wasmtime compile -C inlining=y $W -o inl.cwasm
wasmtime compile -C compiler=winch $W -o winch.cwasm
/opt/wasm/lp64.sh bt_fl.c bt_fl_lp64.c
/opt/llvm/bin/clang -O2 bt_fl.c -o bt_fl_native
$WASI_SDK_PATH/bin/clang -O2 -Wl,-z,stack-size=8388608 bt_fl_lp64.c -o bt_fl.wasm
wasmtime compile bt_fl.wasm -o bt_fl.cwasm; wasmtime compile -C inlining=y bt_fl.wasm -o bt_fl_inl.cwasm
wasmtime objdump --color never --addresses /app/wasm/binary-trees.cwasm > def_addr.dis
python3 repatch.py /app/wasm/binary-trees.cwasm p_dlm.cwasm def_addr.dis dlmalloc
python3 repatch.py /app/wasm/binary-trees.cwasm p_tree.cwasm def_addr.dis make check destroy
python3 repatch.py /app/wasm/binary-trees.cwasm p_all.cwasm def_addr.dis make check destroy dlmalloc
for f in p_dlm p_tree p_all; do for n in 10 16; do wasmtime run -C cache=n --allow-precompiled $f.cwasm $n | head -1; done; done
'
echo ">> timing batch 1: knobs ($REPS reps)" >&2
docker exec "$C" sh -c "cd /diag && python3 bt_time.py variants-knobs.json $REPS $CPU 10 16" > "$OUT/knobs.jsonl"
echo ">> timing batch 2: frame patch ($((REPS + 5)) reps)" >&2
docker exec "$C" sh -c "cd /diag && python3 bt_time.py variants-patch.json $((REPS + 5)) $CPU 10 16" > "$OUT/patch.jsonl"
echo ">> microbenchmarks" >&2
docker exec "$C" bash -euc "
cd /diag; /opt/llvm/bin/clang -O2 frames.c frames.S -o frames; /opt/llvm/bin/clang -O2 prolog.c prolog.S -o prolog
/opt/llvm/bin/clang -O2 chase.c -o chase
for f in fC0S fO0S fC1S fO1S fC2S fO2S fC3S fO3S fC4S fO4S fC5S fO5S fC0L fO0L fC1L fO1L fC2L fO2L fC3L fO3L fC4L fO4L fC5L fO5L; do
  taskset -c $CPU ./frames \$f 20000000; done
for m in 0 1 2 3 4 5 6; do taskset -c $CPU ./prolog \$m 20000000; done
for m in 0 1; do taskset -c $CPU ./chase \$m 20000000; done
" > "$OUT/micro.txt"
echo ">> done: $OUT" >&2
