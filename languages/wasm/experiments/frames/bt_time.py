#!/usr/bin/env python3
# WebAssembly side study, frames diagnostic: native user-time harness (stdlib only). Runs every (variant,
# size) pair in a fresh random order per repetition after one discarded warm-up round, each process pinned
# with taskset, and prints one JSON line per run (wall/user/sys ns, page faults, context switches from wait4,
# first output line, exit code).
# usage: bt_time.py <variants.json> <reps> <cpu> <n1> <L> ; prints JSON lines
import json, os, random, subprocess, sys, time
V = json.load(open(sys.argv[1])); reps=int(sys.argv[2]); cpu=sys.argv[3]; sizes=sys.argv[4:]
env = dict(os.environ, UV_THREADPOOL_SIZE='1', NODE_NO_WARNINGS='1', TOKIO_WORKER_THREADS='1')
def run(argv, n):
    t0=time.perf_counter_ns()
    p=subprocess.Popen(['taskset','-c',cpu]+argv+[n], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=env)
    out,err=p.communicate()
    t1=time.perf_counter_ns()
    ru=p.rusage if hasattr(p,'rusage') else None
    return t1-t0, out, err, p.returncode
# use wait4 for rusage
def run4(argv,n):
    t0=time.perf_counter_ns()
    p=subprocess.Popen(['taskset','-c',cpu]+argv+[n], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, env=env)
    out=p.stdout.read()
    _,st,ru=os.wait4(p.pid,0)
    t1=time.perf_counter_ns()
    return dict(wall_ns=t1-t0,user_ns=int(ru.ru_utime*1e9),sys_ns=int(ru.ru_stime*1e9),minflt=ru.ru_minflt,
                majflt=ru.ru_majflt,nvcsw=ru.ru_nvcsw,nivcsw=ru.ru_nivcsw,maxrss=ru.ru_maxrss,
                out=out.decode(errors='replace').split('\n',1)[0], rc=os.waitstatus_to_exitcode(st))
pairs=[(k,n) for k in V for n in sizes]
for rep in range(-1,reps):
    random.shuffle(pairs)
    for k,n in pairs:
        r=run4(V[k],n)
        if rep<0: continue
        r.update(var=k,n=int(n),rep=rep); print(json.dumps(r),flush=True)
