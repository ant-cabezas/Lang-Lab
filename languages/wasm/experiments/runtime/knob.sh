#!/usr/bin/env bash
# WebAssembly side study, runtime experiment (jitter): runs INSIDE a container, piped in by knob-run.sh.
#
#   knob.sh <label> <reps> "<benches>" -- <cmd template with {b}>      (the size is appended)
#
# For every benchmark and both spec sizes (n1, n2 from /app/benchmarks/<b>/spec.json) runs the command
# <reps> times under qemu-user + the TCG insn plugin directly (not through measure.sh), because the
# question is per-thread: the plugin log has one "cpu N insns" line per guest thread plus the total.
# Prints one "RAW <label> <b> n=<n> run<i> out=<first output line> | <plugin log lines joined by ;>"
# line per run and one summary line per (benchmark, size):
#   SUM <label> <b> n=<n> threads=a..b cpu0=a..b others=a..b total=a..b spread%=<(max-min)/median*100> outs=<distinct outputs>
# others = the sum over guest threads 1..N. The environment (TOKIO_WORKER_THREADS etc.) passes through.
# The outs= field was added part-way through the study run, so the earliest SUM lines of the published
# knobs-raw.log lack it; ingest.py reads both forms.
# No `set -e` on purpose: a configuration whose guest fails (rejected flag, killed process) must still
# print its RAW/SUM lines, which is how ingest.py detects and excludes it.
label="$1"; reps="$2"; benches="$3"; shift 3; [ "$1" = "--" ] && shift
tmpl="$*"
for b in $benches; do
  spec=/app/benchmarks/$b/spec.json
  for n in $(jq -r .n1 $spec) $(jq -r .n2 $spec); do
    cmd="${tmpl//\{b\}/$b}"; tots=(); c0=(); oth=(); nth=(); outs=()
    for ((i=1;i<=reps;i++)); do
      GLIBC_TUNABLES=glibc.pthread.rseq=0 /opt/qi/qemu-aarch64 -plugin /opt/qi/libinsn.so -d plugin -D /tmp/l $cmd "$n" >/tmp/o 2>/tmp/e
      echo "RAW $label $b n=$n run$i out=$(head -1 /tmp/o) | $(tr '\n' ';' < /tmp/l)"
      tots+=($(awk '/total insns/{print $3}' /tmp/l)); c0+=($(awk '/^cpu 0 insns/{print $4}' /tmp/l))
      oth+=($(awk '/^cpu [1-9]/{s+=$4} END{print s+0}' /tmp/l)); nth+=($(grep -c '^cpu ' /tmp/l)); outs+=("$(head -1 /tmp/o)")
    done
    st() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END{printf "%d..%d", a[1], a[NR]}'; }
    sp=$(printf '%s\n' "${tots[@]}" | sort -n | awk '{a[NR]=$1} END{printf "%.5f", (a[NR]-a[1])*100/a[int((NR+1)/2)]}')
    echo "SUM $label $b n=$n threads=$(st "${nth[@]}") cpu0=$(st "${c0[@]}") others=$(st "${oth[@]}") total=$(st "${tots[@]}") spread%=$sp outs=$(printf '%s\n' "${outs[@]}" | sort -u | tr '\n' ',')"
  done
done
