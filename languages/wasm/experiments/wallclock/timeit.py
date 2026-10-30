#!/usr/bin/env python3
"""WebAssembly side study, wall-clock experiment: the timing harness. Runs INSIDE lang-lab-wasm:c,
natively (no qemu): copied in and driven by run-timing.sh.

usage: timeit.py <bench> <reps> <cpu> <n>[:<expected>] ...
For every rep, all (column, size) pairs run in a fresh random order (interleaving spreads drift).
One warmup round is run first and discarded. Each process is pinned with taskset -c <cpu>.
Prints one JSON line per run: bench, col, n, rep, wall_ns, user_ns, sys_ns, out (line 1), rc, ok, load1.
ok compares the first output line with <expected> (None when no expected value is given, as for L).
user_ns / sys_ns come from wait4's rusage of the child.
Columns: clang and gcc native binaries; wasmtime and node with the study's binding run flags
(TOKIO_WORKER_THREADS=1 and -C cache=n; --no-liftoff); node-liftoff = Node without --no-liftoff.
The first two passes of the study (A, B) ran an earlier version of this file, with wasmtime and node
without the binding flags and no node-liftoff column; passes C and D, the headline, ran this one.
"""
import json, os, random, subprocess, sys, time

bench, reps, cpu = sys.argv[1], int(sys.argv[2]), sys.argv[3]
sizes = []
for a in sys.argv[4:]:
    n, _, exp = a.partition(':')
    sizes.append((n, exp or None))
COLS = {
    'clang': ['/app/clang/' + bench],
    'gcc': ['/app/gcc/' + bench],
    'wasmtime': ['/usr/local/bin/wasmtime', 'run', '-C', 'cache=n', '--allow-precompiled', f'/app/wasm/{bench}.cwasm'],
    'node': ['/usr/local/bin/node', '--predictable', '--single-threaded', '--single-threaded-gc', '--no-liftoff',
             '/opt/wasm/run-node.mjs', f'/app/wasm/{bench}.wasm'],
    'node-liftoff': ['/usr/local/bin/node', '--predictable', '--single-threaded', '--single-threaded-gc',
             '/opt/wasm/run-node.mjs', f'/app/wasm/{bench}.wasm'],
}
env = dict(os.environ, UV_THREADPOOL_SIZE='1', NODE_NO_WARNINGS='1', TOKIO_WORKER_THREADS='1')

def run(col, n):
    argv = ['taskset', '-c', cpu] + COLS[col] + [n]
    t0 = time.perf_counter_ns()
    p = subprocess.Popen(argv, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
    out = p.stdout.read()
    _, status, ru = os.wait4(p.pid, 0)
    t1 = time.perf_counter_ns()
    p.returncode = os.waitstatus_to_exitcode(status)
    line = out.decode(errors='replace').split('\n', 1)[0].strip()
    return t1 - t0, int(ru.ru_utime * 1e9), int(ru.ru_stime * 1e9), line, p.returncode

pairs = [(c, n, e) for c in COLS for (n, e) in sizes]
for rep in range(-1, reps):
    random.shuffle(pairs)
    for col, n, exp in pairs:
        w, u, s, line, rc = run(col, n)
        if rep < 0:
            continue
        load1 = open('/proc/loadavg').read().split()[0]
        print(json.dumps({'bench': bench, 'col': col, 'n': int(n), 'rep': rep, 'wall_ns': w, 'user_ns': u,
                          'sys_ns': s, 'out': line, 'rc': rc,
                          'ok': (line == exp) if exp else None, 'load1': float(load1)}), flush=True)
