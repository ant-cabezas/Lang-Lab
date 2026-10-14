#!/usr/bin/env python3
"""Cross-ISA stability (metric-validity Study 2): arm64 vs x86_64, cell by cell.

No third-party dependencies. For every compute axis it takes the most recent arm64 envelope and
the most recent x86_64 envelope in results/, normalizes each cell to C on its own ISA, and reports
how much the vs-C ratio moves between ISAs: the share of cells within +/-10/25/50%, the median
shift, the per-language geomeans on both ISAs (the same quantity as the README leaderboard), the
worst-moving cells and whether the ranking order holds. Its output is the data behind
docs/metric-validity.md, Study 2; regenerate that table from here instead of editing it by hand.

    python3 scripts/cross_isa.py            # Markdown table + stats on stdout
    python3 scripts/cross_isa.py --cells    # also list every cell's shift
"""
import glob
import json
import math
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from _langnames import NAMES  # noqa: E402
from make_matrix import BENCH_ORDER, NOT_RANKED, ISA_SPECIFIC  # noqa: E402

AXES = [b for b in BENCH_ORDER if b not in NOT_RANKED]


def latest(isa, b):
    fs = sorted(glob.glob(os.path.join(ROOT, "results", f"*-{isa}-{b}.json")))
    return fs[-1] if fs else None


def load(isa):
    """ratio[lang][bench] = differential / C differential, for cells measured on this ISA."""
    ratio, dates = {}, set()
    for b in AXES:
        f = latest(isa, b)
        if not f:
            continue
        env = json.load(open(f))
        dates.add(env["date"])
        dates.update(r["measuredDate"] for r in env["results"] if r.get("measuredDate"))
        rs = {r["language"]: r for r in env["results"] if r.get("i_n1") and r.get("i_n2")}
        c = rs["c"]["differential"]
        for L, r in rs.items():
            ratio.setdefault(L, {})[b] = r["differential"] / c
    return ratio, dates


def geomean(vals):
    return math.exp(sum(math.log(v) for v in vals) / len(vals))


def fmt(r):
    return f"{r:.2f}" if r < 10 else (f"{r:.1f}" if r < 100 else f"{r:.0f}")


def main():
    a, adates = load("arm64")
    x, xdates = load("x86_64")
    if not x:
        sys.exit("cross_isa: no x86_64 envelopes in results/")
    langs = [L for L in a if L != "c"]
    cells = []  # (lang, bench, arm_ratio, x86_ratio, shift)
    for L in langs:
        for b in AXES:
            if b in a[L] and b in x.get(L, {}):
                cells.append((L, b, a[L][b], x[L][b], x[L][b] / a[L][b]))
    shifts = sorted(abs(math.log(s)) for *_, s in cells)
    n = len(cells)

    def within(p):
        return sum(1 for d in shifts if d <= math.log(1 + p)) / n

    med = sorted(s for *_, s in cells)[n // 2]
    print(f"arm64 envelopes dated {min(adates)}..{max(adates)}; x86_64 {min(xdates)}..{max(xdates)}")
    print(f"{n} cells with both ISAs present across {len(AXES)} axes")
    print(f"within +/-10%: {within(0.10):.0%}   +/-25%: {within(0.25):.0%}   "
          f"+/-50%: {within(0.50):.0%}   median shift x{med:.3f}")

    ga = {L: geomean(list(a[L].values())) for L in langs}
    gx = {L: geomean(list(x[L].values())) for L in langs if x.get(L)}
    print("\n| Language | geomean vs C, arm64 | geomean vs C, x86_64 | shift | ISA-stable? |")
    print("|---|--:|--:|--:|---|")
    for L in sorted(langs, key=ga.get):
        name = NAMES.get(L, L)
        if L not in gx:
            print(f"| {name} | {fmt(ga[L])} | (no x86_64 cells) | | |")
            continue
        s = gx[L] / ga[L]
        dev = abs(math.log(s))
        if L in ISA_SPECIFIC:
            verdict, name = f"**no (x{s:.1f})**", f"**{name}**"
        elif dev <= math.log(1.20):
            verdict = "yes"
        elif dev <= math.log(1.35):
            verdict = "mostly"
        else:
            verdict = f"no (x{s:.2f})"
        g1, g2 = (f"**{fmt(ga[L])}**", f"**{fmt(gx[L])}**") if L in ISA_SPECIFIC else (fmt(ga[L]), fmt(gx[L]))
        print(f"| {name} | {g1} | {g2} | x{s:.2f} | {verdict} |")

    nonjvm = [L for L in gx if L not in ISA_SPECIFIC]
    bound = max(abs(gx[L] / ga[L] - 1) for L in nonjvm)
    print(f"\nnon-JVM geomeans move at most {bound:.0%} between ISAs")
    print("arm64 order :", " < ".join(NAMES.get(L, L) for L in sorted(langs, key=ga.get)))
    print("x86_64 order:", " < ".join(NAMES.get(L, L) for L in sorted(gx, key=gx.get)))

    print("\nworst-moving cells:")
    for L, b, ra, rx, s in sorted(cells, key=lambda c: -abs(math.log(c[4])))[:8]:
        print(f"  {b}/{NAMES.get(L, L)}: {fmt(ra)}x -> {fmt(rx)}x (x{s:.2f})")
    if "--cells" in sys.argv:
        print("\nall cells (lang, bench, arm64, x86_64, shift):")
        for L, b, ra, rx, s in sorted(cells):
            print(f"  {NAMES.get(L, L):11} {b:18} {ra:9.2f} {rx:9.2f}  x{s:.2f}")


if __name__ == "__main__":
    main()
