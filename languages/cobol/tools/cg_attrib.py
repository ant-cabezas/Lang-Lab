#!/usr/bin/env python3
"""Instruction attribution for the COBOL side study (DIAGNOSTIC ONLY, never the metric).

For every correct cell of the headline envelopes, runs the binary natively under callgrind inside its
study image at two REDUCED sizes (callgrind is ~50x slower than native) and attributes the
differential Ir(n_b) - Ir(n_a) per shared object / function:

    dec       libcob cob_decimal_* / cob_add / cob_mul / cob_div / cob_intr_* / libgmp   (GnuCOBOL decimal path)
    cobother  the rest of libcob                                                          (moves, compares, alloc, call)
    gcobol    libgcobol (the __gg__ helpers of GCC's COBOL front end)
    libc      libc / ld.so / libm                          (of which `dlsym` = dynamic symbol lookup per CALL)
    user      the program itself (inline code the compiler emitted)

It RESUMES from an existing attribution file and skips (column, benchmark) rows already present: delete the file
after any source or compiler change, or stale rows are kept.

Usage: cg_attrib.py <resdir> <date> [image-key ...]   -> <resdir>/<date>-arm64-attribution.json
"""
import collections, json, os, re, subprocess, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
# Reduced sizes (a, b): small enough for callgrind, large enough that the per-iteration work dominates.
SMALL = {
    "blur": (32, 48), "gemm": (32, 48), "k-means": (500, 750), "dijkstra": (1250, 1875),
    "sort-search": (12500, 25000), "viterbi": (5000, 7500), "gbdt": (1250, 2500), "lz77": (1500, 3000),
    "vm": (50000, 100000), "reverse-complement": (25000, 50000), "polymorphism": (10, 20),
    "mandelbrot": (32, 48), "tak": (6, 7), "binary-trees": (10, 12), "fannkuch": (7, 8),
}
# Used only when callgrind produced no profile at SMALL (valgrind was killed on those programs at the larger size).
FALLBACK = {"gbdt": (200, 400), "vm": (10000, 20000)}
DEC = re.compile(r"^(cob_decimal|cob_add|cob_sub|cob_mul|cob_div|cob_intr_|cob_mod|cob_pow|cob_numeric_cmp|cob_cmp_float)|mpz|mpn|gmp")


def parse(txt):
    ob, fnm, tot = {}, {}, collections.Counter()
    cur = curf = None
    skip = False
    for l in txt.split("\n"):
        m = re.match(r"(c?)ob=\((\d+)\)(?: (.*))?", l)
        if m:
            if m.group(3):
                ob[m.group(2)] = m.group(3)
            if not m.group(1):
                cur = m.group(2)
            continue
        m = re.match(r"(c?)fn=\((\d+)\)(?: (.*))?", l)
        if m:
            if m.group(3):
                fnm[m.group(2)] = m.group(3)
            if not m.group(1):
                curf = m.group(2)
            continue
        if l.startswith("calls="):
            skip = True
            continue
        if l and (l[0].isdigit() or l[0] in "+-*"):
            if skip:
                skip = False
                continue
            p = l.split()
            if len(p) >= 2:
                tot[(ob.get(cur, cur).split("/")[-1], fnm.get(curf, curf))] += int(p[1])
    return tot


def cat(o, f):
    f = re.sub(r"'\d+$", "", f)
    if o.startswith("libgmp"):
        return "dec"
    if o.startswith("libcob."):
        return "dec" if DEC.search(f) else "cobother"
    if o.startswith("libgcobol"):
        return "gcobol"
    if o.startswith(("libc.", "ld-", "libm")):
        return "libc"
    return "user"


def run(img, binname, n):
    out = subprocess.run(["docker", "run", "--rm", img, "sh", "-c",
                          f"cd /tmp; valgrind --tool=callgrind --callgrind-out-file=cg.out /app/{binname} {n} >/dev/null 2>&1; cat cg.out"],
                         capture_output=True, text=True).stdout
    return parse(out)


def main():
    resdir, date = sys.argv[1], sys.argv[2]
    only = sys.argv[3:]
    cols = {  # envelope file -> image key
        "gnucobol32-natural": "gnucobol32", "gnucobol32-best": "gnucobol32nt",
        "gcobol15-natural": "gcobol15", "gcobol15-restricted": "gcobol15",
    }
    outp = os.path.join(resdir, f"{date}-arm64-attribution.json")
    out = json.load(open(outp))["results"] if os.path.exists(outp) else []   # resume: keep rows already measured
    done = {(r["column"], r["benchmark"]) for r in out}
    built = set()
    for column, key in cols.items():
        if only and key not in only:
            continue
        p = os.path.join(resdir, f"{date}-arm64-{column}.json")
        if not os.path.exists(p):
            continue
        env = json.load(open(p))
        img = f"lang-lab-cobol-diag:{key}"
        if key not in built:
            subprocess.run(["docker", "build", "-q", "-f", os.path.join(ROOT, "languages/cobol/Dockerfile.diag"),
                            "--build-arg", f"BASE=lang-lab-cobol:{key}", "-t", img, ROOT], check=True, capture_output=True)
            built.add(key)
        for r in env["results"]:
            if r["status"] != "ok" or (column, r["benchmark"]) in done:
                continue
            a, b = SMALL[r["benchmark"]]
            for attempt in (0, 1):
                t1, t2 = run(img, r["source"], a), run(img, r["source"], b)
                d = collections.Counter({k: t2[k] - t1.get(k, 0) for k in t2})
                T = sum(d.values())
                if T > 0 or attempt or r["benchmark"] not in FALLBACK:
                    break
                a, b = FALLBACK[r["benchmark"]]
            if T <= 0:
                print(f"{column:22s} {r['source']:20s} no callgrind profile", flush=True)
                continue
            g = collections.Counter()
            for (o, f), v in d.items():
                g[cat(o, f)] += v
            dl = sum(v for (o, f), v in d.items() if re.search(r"dlsym|_dl_|dlerror", f))
            top = sorted(d.items(), key=lambda kv: -kv[1])[:3]
            row = dict(column=column, benchmark=r["benchmark"], source=r["source"], sizes=[a, b], dIr=T,
                       share={k: g[k] / T for k in ("dec", "cobother", "gcobol", "libc", "user")},
                       dlsymShare=dl / T,
                       top=[dict(object=k[0], function=re.sub(r"'\d+$", "", k[1]), share=v / T) for k, v in top])
            out.append(row)
            print(f"{column:22s} {r['source']:20s} n={a}-{b} dIr={T:>12d} " +
                  " ".join(f"{k}={100*row['share'][k]:5.1f}%" for k in row["share"]), flush=True)
    json.dump(dict(study="cobol-side-study", kind="attribution", date=date, isa="arm64", diagnostic=True,
                   note="callgrind at reduced sizes, native inside the study image; DIAGNOSTIC ONLY, never the metric",
                   results=out),
              open(outp, "w"), indent=1)


if __name__ == "__main__":
    main()
