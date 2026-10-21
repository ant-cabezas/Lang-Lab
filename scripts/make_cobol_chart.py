#!/usr/bin/env python3
"""COBOL side study: chart + tables from results/cobol/ (out of the ranking; no third-party deps).

Reads the newest `<date>-arm64-*.json` set in results/cobol/ (written by scripts/cobol-study.sh):

    c, gnucobol32-natural, gnucobol32-best, gcobol15-natural, gcobol15-restricted   (headline columns)
    secondary (gcobol 16, GnuCOBOL 4.0-early-dev), attribution (callgrind, diagnostic)

and renders docs/charts/cobol-study.svg: a log-colour heatmap, benchmark x column, every cell the
ratio to C (= 1.00x) measured at the same full spec sizes, LOWER IS BETTER. Same palette/ramp as
scripts/make_matrix.py. Nothing is extrapolated: a cell that is not measured says why.

    python3 scripts/make_cobol_chart.py            # write the SVG, print the tables
    python3 scripts/make_cobol_chart.py --write    # also splice the tables into docs/cobol-study.md
                                                   # between the <!-- COBOL-xxx:START/END --> markers
    RESDIR=/tmp/x python3 scripts/make_cobol_chart.py   # dev data (nothing is spliced without --write)
"""
import glob
import json
import math
import os
import re
import sys
from xml.sax.saxutils import escape as _xesc

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESDIR = os.environ.get("RESDIR", os.path.join(ROOT, "results", "cobol"))
OUT = os.path.join(ROOT, "docs", "charts", "cobol-study.svg")
DOC = os.path.join(ROOT, "docs", "cobol-study.md")

BG, FG, MUTED, GRID = "#0d1117", "#e6edf3", "#9aa7b4", "#0d1117"
STOPS = [(-0.6, (35, 132, 67)), (-0.3, (65, 171, 93)), (-0.15, (173, 221, 142)),
         (0.0, (247, 252, 185)), (0.3, (255, 237, 160)), (0.7, (254, 217, 118)),
         (1.0, (254, 178, 76)), (1.7, (253, 141, 60)), (2.0, (252, 78, 42)),
         (3.0, (227, 26, 28)), (4.0, (177, 0, 38)), (5.4, (128, 0, 38))]
TLO, THI = STOPS[0][0], STOPS[-1][0]

BENCHES = ["binary-trees", "blur", "dijkstra", "fannkuch", "gbdt", "gemm", "k-means", "lz77", "mandelbrot",
           "polymorphism", "reverse-complement", "sort-search", "tak", "viterbi", "vm"]
HEAD = [("gnucobol32-natural", "GnuCOBOL 3.2", "natural code"),
        ("gnucobol32-best", "GnuCOBOL 3.2", "best variant"),
        ("gcobol15-natural", "gcobol 15.2", "natural code"),
        ("gcobol15-restricted", "gcobol 15.2", "restricted subset")]
GATE_LIMIT = 0.50   # pre-registered: < 50 percent of the differential in decimal/GMP (or libgcobol) helpers
GATE_MIN = 10       # pre-registered: at least 10 of the 15 benchmarks must qualify


def rgb_at(t):
    t = max(TLO, min(THI, t))
    for (t0, c0), (t1, c1) in zip(STOPS, STOPS[1:]):
        if t <= t1:
            f = (t - t0) / (t1 - t0) if t1 > t0 else 0.0
            return tuple(round(c0[i] + (c1[i] - c0[i]) * f) for i in range(3))
    return STOPS[-1][1]


def hexc(rgb):
    return "#%02x%02x%02x" % rgb


def text_on(rgb):
    lum = 0.2126 * rgb[0] + 0.7152 * rgb[1] + 0.0722 * rgb[2]
    return "#0d1117" if lum > 150 else "#ffffff"


def fmt(r):
    if r < 10:
        return f"{r:.2f}"
    if r < 100:
        return f"{r:.1f}"
    if r < 10000:
        return f"{r:,.0f}"
    return f"{r/1000:.1f}k"


def latest_date():
    ds = sorted({os.path.basename(p).split("-arm64-")[0] for p in glob.glob(os.path.join(RESDIR, "*-arm64-*.json"))})
    if not ds:
        sys.exit(f"make_cobol_chart: no envelopes in {RESDIR}")
    return ds[-1]


def load(date, name):
    p = os.path.join(RESDIR, f"{date}-arm64-{name}.json")
    return json.load(open(p)) if os.path.exists(p) else None


def rows_by_bench(env):
    return {r["benchmark"]: r for r in env["results"]} if env else {}


def why(r):
    if r is None:
        return "no source"
    return {"checksum-fail": "wrong answer", "build-failed": "no build", "measure-fail": "no count"}.get(r["status"], r["status"])


def geomean(xs):
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else None


def common_geomeans(cols):
    """Geomean of each column over the benchmarks measured correctly in ALL columns (never extrapolated)."""
    common = [b for b in BENCHES if all((c.get(b) or {}).get("ratio") for c in cols)]
    return common, [geomean([c[b]["ratio"] for b in common]) for c in cols]


def render_svg(date, cols, labels):
    cw, ch = 132, 28
    left, top = 180, 118
    W = left + cw * len(cols) + 24
    H = top + ch * (len(BENCHES) + 1) + 112
    s = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" '
         f'font-family="ui-sans-serif,system-ui,Segoe UI,Helvetica,Arial">',
         f'<rect width="{W}" height="{H}" rx="10" fill="{BG}"/>',
         f'<text x="22" y="34" font-size="19" font-weight="700" fill="{FG}">Lang Lab · COBOL side study</text>',
         f'<text x="22" y="54" font-size="12.5" fill="{MUTED}">instructions vs C (= 1.00×, lower is better), differential I(n₂)−I(n₁), '
         f'full spec sizes · qemu+insn · arm64 · {date}</text>',
         f'<text x="22" y="72" font-size="12" fill="{MUTED}">not ranked, not in the matrix: 3 axes (sha256, k-nucleotide, bigint) '
         f'need hand-rolled machinery and are excluded</text>']
    for j, (key, comp, sub) in enumerate(labels):
        cx = left + j * cw + cw / 2
        s.append(f'<text x="{cx:.1f}" y="{top - 30}" text-anchor="middle" font-size="12.5" font-weight="700" fill="{FG}">{_xesc(comp)}</text>')
        s.append(f'<text x="{cx:.1f}" y="{top - 14}" text-anchor="middle" font-size="11" fill="{MUTED}">{_xesc(sub)}</text>')
    for i, b in enumerate(BENCHES):
        y = top + i * ch
        s.append(f'<text x="{left - 10}" y="{y + ch / 2 + 4:.1f}" text-anchor="end" font-size="12.5" font-weight="600" fill="{FG}">{_xesc(b)}</text>')
        for j, c in enumerate(cols):
            x = left + j * cw
            r = c.get(b)
            if r and r.get("ratio"):
                rgb = rgb_at(math.log10(r["ratio"]))
                s.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" fill="{hexc(rgb)}" stroke="{GRID}" stroke-width="1"/>')
                tag = ""
                if r.get("variant") not in (None, "original") and labels[j][0].endswith("best"):
                    tag = " " + ("bin" if r["variant"] == "bin" else "")
                s.append(f'<text x="{x + cw / 2:.1f}" y="{y + ch / 2 + 4:.1f}" text-anchor="middle" font-size="11.5" '
                         f'font-weight="600" fill="{text_on(rgb)}">{fmt(r["ratio"])}×{tag}</text>')
            else:
                s.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" fill="#161b22" stroke="{GRID}" stroke-width="1"/>')
                s.append(f'<text x="{x + cw / 2:.1f}" y="{y + ch / 2 + 4:.1f}" text-anchor="middle" font-size="10.5" '
                         f'fill="{MUTED}">{_xesc(why(r))}</text>')
    common, gms = common_geomeans(cols)
    y = top + len(BENCHES) * ch + 6
    s.append(f'<text x="{left - 10}" y="{y + ch / 2 + 4:.1f}" text-anchor="end" font-size="12" font-weight="700" fill="{FG}">geomean ({len(common)} common)</text>')
    for j, g in enumerate(gms):
        x = left + j * cw
        if g:
            rgb = rgb_at(math.log10(g))
            s.append(f'<rect x="{x}" y="{y}" width="{cw}" height="{ch}" fill="{hexc(rgb)}" stroke="{GRID}" stroke-width="1.5"/>')
            s.append(f'<text x="{x + cw / 2:.1f}" y="{y + ch / 2 + 4:.1f}" text-anchor="middle" font-size="12" font-weight="700" fill="{text_on(rgb)}">{fmt(g)}×</text>')
    ly = y + ch + 24
    lx, lw = left, cw * len(cols)
    s.append('<defs><linearGradient id="ramp" x1="0" y1="0" x2="1" y2="0">')
    for t, c in STOPS:
        s.append(f'<stop offset="{(t - TLO) / (THI - TLO):.3f}" stop-color="{hexc(c)}"/>')
    s.append('</linearGradient></defs>')
    s.append(f'<rect x="{lx}" y="{ly}" width="{lw}" height="12" rx="3" fill="url(#ramp)"/>')
    for r, txt in [(1, "1× (C)"), (10, "10×"), (100, "100×"), (1000, "1k×"), (10000, "10k×")]:
        tx = lx + (math.log10(r) - TLO) / (THI - TLO) * lw
        s.append(f'<line x1="{tx:.1f}" y1="{ly}" x2="{tx:.1f}" y2="{ly + 12}" stroke="{BG}" stroke-width="1"/>')
        s.append(f'<text x="{tx:.1f}" y="{ly + 26}" text-anchor="middle" font-size="10" fill="{MUTED}">{txt}</text>')
    s.append(f'<text x="{lx}" y="{ly + 46}" font-size="10" fill="{MUTED}">restricted subset = sources rewritten to avoid slow paths '
             f'(not idiomatic COBOL).</text>')
    s.append(f'<text x="{lx}" y="{ly + 60}" font-size="10" fill="{MUTED}">best variant = -fnotrunc, lower of original and -bin. '
             f'geomean: only benchmarks correct in all four columns.</text>')
    s.append('</svg>')
    return "\n".join(s)


def esc_md(x):
    return x.replace("|", "\\|")


def headline_md(date, cols, envs):
    rows = ["| Benchmark | GnuCOBOL 3.2 natural | GnuCOBOL 3.2 best variant | gcobol 15.2 natural | gcobol 15.2 restricted subset | C differential (instructions) |",
            "|---|--:|--:|--:|--:|--:|"]
    cenv = rows_by_bench(load(date, "c"))
    for b in BENCHES:
        cells = []
        for j, c in enumerate(cols):
            r = c.get(b)
            if r and r.get("ratio"):
                extra = ""
                if j == 1 and r.get("variant") == "bin":
                    extra = " (bin)"
                if j == 3:
                    extra = ""
                cells.append(f"{r['ratio']:.1f}{extra}" if r["ratio"] < 1000 else f"{r['ratio']:,.0f}{extra}")
            else:
                cells.append(f"*{why(r)}*")
        cd = cenv.get(b, {}).get("differential")
        rows.append(f"| {b} | " + " | ".join(cells) + f" | {cd:,} |")
    common, gms = common_geomeans(cols)
    rows.append(f"| **geomean over the {len(common)} benchmarks measured in all four columns** | " +
                " | ".join(f"**{g:.1f}**" for g in gms) + " | |")
    rows.append(f"| cells measured and correct (of {len(BENCHES)}) | " +
                " | ".join(str(sum(1 for b in BENCHES if (c.get(b) or {}).get('ratio'))) for c in cols) + " | |")
    return "\n".join(rows)


def secondary_md(date):
    env = load(date, "secondary")
    if not env:
        return "*(no secondary envelope)*"
    cols = env["columns"]
    out = ["| Benchmark | " + " | ".join(f"{c['column']}" for c in cols) + " |", "|---|" + "--:|" * len(cols)]
    for b in BENCHES:
        cells = []
        for c in cols:
            r = {x["benchmark"]: x for x in c["results"]}.get(b)
            cells.append(f"{r['ratio']:.1f}" if r and r.get("ratio") else f"*{why(r)}*")
        out.append(f"| {b} | " + " | ".join(cells) + " |")
    return "\n".join(out)


def helper_share(row):
    sh = row["share"]
    return sh["dec"] + sh["gcobol"]


def attribution_md(date):
    env = load(date, "attribution")
    if not env:
        return "*(no attribution envelope)*", "*(no gate data)*", {}
    by = {}
    for r in env["results"]:
        by.setdefault(r["column"], {})[r["benchmark"]] = r
    names = {"gnucobol32-natural": "GnuCOBOL 3.2 natural", "gnucobol32-best": "GnuCOBOL 3.2 best variant",
             "gcobol15-natural": "gcobol 15.2 natural", "gcobol15-restricted": "gcobol 15.2 restricted"}
    out = ["Share of the differential instructions (percent; callgrind at reduced sizes, diagnostic only). "
           "**helper** = libcob decimal/GMP for GnuCOBOL, libgcobol for gcobol.", "",
           "| Column | Benchmark | source | helper | other libcob | libc | of which dlsym | inline code |",
           "|---|---|---|--:|--:|--:|--:|--:|"]
    for col in names:
        for b in BENCHES:
            r = by.get(col, {}).get(b)
            if not r:
                continue
            sh = r["share"]
            p = lambda v: f"{max(0.0, 100 * v):.1f}"
            out.append(f"| {names[col]} | {b} | {r['source']} | {p(helper_share(r))} | {p(sh['cobother'])} | "
                       f"{p(sh['libc'])} | {p(r['dlsymShare'])} | {p(sh['user'])} |")
    gate = ["| Column | benchmarks measured and correct | with a callgrind profile | helper share < 50 percent | gate (at least 10 of 15) |",
            "|---|--:|--:|--:|---|"]
    verdict = {}
    for col in names:
        envc = load(date, col)
        ok = [r["benchmark"] for r in (envc or {"results": []})["results"] if r["status"] == "ok"]
        cells = by.get(col, {})
        npass = sum(1 for r in cells.values() if helper_share(r) < GATE_LIMIT)
        failing = sorted(b for b, r in cells.items() if helper_share(r) >= GATE_LIMIT)
        noprof = sorted(b for b in ok if b not in cells)
        verdict[col] = (len(ok), len(cells), npass, failing, noprof)
        gate.append(f"| {names[col]} | {len(ok)} | {len(cells)} | {npass} | {'GO' if npass >= GATE_MIN else 'NO-GO'} |")
    return "\n".join(out), "\n".join(gate), verdict


def splice(text, tag, body):
    pat = re.compile(rf"(<!-- {tag}:START -->)\n?.*?\n?(<!-- {tag}:END -->)", re.S)
    if not pat.search(text):
        sys.exit(f"make_cobol_chart: markers {tag} not found in docs/cobol-study.md")
    return pat.sub(lambda m: m.group(1) + "\n" + body + "\n" + m.group(2), text)


def main():
    date = latest_date()
    envs = [load(date, k) for k, _, _ in HEAD]
    cols = [rows_by_bench(e) for e in envs]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    svg = render_svg(date, cols, HEAD)
    open(OUT, "w").write(svg)
    head = headline_md(date, cols, envs)
    sec = secondary_md(date)
    attr, gate, verdict = attribution_md(date)
    print(head, "\n")
    print(sec, "\n")
    print(gate, "\n")
    for k, v in verdict.items():
        print(k, "ok", v[0], "profiled", v[1], "pass", v[2], "failing", v[3], "no profile", v[4])
    print(f"wrote {os.path.relpath(OUT, ROOT)} (data date {date})")
    if "--write" in sys.argv:
        t = open(DOC).read()
        t = splice(t, "COBOL-HEADLINE", head)
        t = splice(t, "COBOL-SECONDARY", sec)
        t = splice(t, "COBOL-ATTRIB", attr)
        t = splice(t, "COBOL-GATE", gate)
        open(DOC, "w").write(t)
        print("spliced tables into docs/cobol-study.md")


if __name__ == "__main__":
    main()
