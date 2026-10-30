#!/usr/bin/env python3
"""WebAssembly side study: tables from results/wasm/ (out of the ranking; no third-party deps).

Reads the newest `<date>-arm64-<lang>.json` per language in results/wasm/ (written by
scripts/wasm-study.sh) plus the study-level envelopes written alongside them (runtime sweep, codegen,
wall-clock), and prints markdown tables. Every ratio is `wasm differential / native differential`
for the same language version and compiler family: LOWER IS BETTER, 1.00 = no overhead over native.
Nothing is extrapolated: a cell that is not measured says why.

    python3 scripts/make_wasm_tables.py            # print the tables
    python3 scripts/make_wasm_tables.py --write    # also splice them into docs/wasm-study.md
                                                   # between the <!-- WASM-xxx:START/END --> markers
    RESDIR=/tmp/x python3 scripts/make_wasm_tables.py   # dev data (nothing is spliced without --write)
"""
import glob
import json
import math
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESDIR = os.environ.get("RESDIR", os.path.join(ROOT, "results", "wasm"))
DOC = os.path.join(ROOT, "docs", "wasm-study.md")

# Display names; the engine is named whenever the wasm route is not the matrix runtime.
LABEL = {
    "c": "C", "rust": "Rust", "go": "Go", "swift": "Swift", "python": "Python (CPython)",
    "ruby": "Ruby (CRuby)", "php": "PHP", "csharp": "C# (Mono)", "vbnet": "VB.NET (Mono)",
    "javascript": "JavaScript (QuickJS-ng)", "java": "Java (TeaVM)", "kotlin": "Kotlin (TeaVM)",
    "scala": "Scala (TeaVM)",
}
STUDY_KINDS = ("runtime-sweep", "sdk-sweep", "v8-tiering", "jitter", "codegen", "wallclock")
# Compiled through TeaVM (JVM bytecode -> wasm, native control = TeaVM's C backend): a different compiler
# from the matrix JVM, so these languages get their own tables instead of sharing rows with the others.
TEAVM = ("java", "kotlin", "scala")
RIGOR = "[Rigor definitions](wasm-rigor.md)"


def headline(envs):
    rows = []
    for lang, e in envs.items():
        s = e["summary"]
        wt = s.get("wasmtime", {}).get("geomeanRatioToNative")
        nd = s.get("node", {}).get("geomeanRatioToNative")
        per = [(r["benchmark"], r["ratioToNative"].get("wasmtime")) for r in e["results"]
               if r.get("ratioToNative", {}).get("wasmtime")]
        n_nd = sum(1 for r in e["results"] if r.get("ratioToNative", {}).get("node"))
        best = min(per, key=lambda t: t[1]) if per else None
        worst = max(per, key=lambda t: t[1]) if per else None
        na = sum(1 for r in e["results"] if r.get("status") == "n/a")
        partial = e.get("lane", {}).get("partialControl")
        rows.append((wt or 1e9, lang, wt, nd, (len(per), n_nd), na, best, worst, len(e["results"]), partial))
    rows.sort()
    out = [
        f"Primary ratios only (`wasmtime` / `node` vs **same-build** `native` control). {RIGOR}.",
        "",
        "| Language | Benchmarks measured | wasmtime 50 / native | V8 TurboFan / native | Cheapest on wasmtime | Most expensive on wasmtime |",
        "|---|---:|---:|---:|---|---|",
    ]
    for _, lang, wt, nd, n, na, best, worst, total, partial in rows:
        tag = " ‡" if partial else ""
        meas = (f"{n[0]} of {total}" if n[0] == n[1] else f"{n[0]} of {total} (V8: {n[1]})") + (f", {na} n/a" if na else "")
        b = f"{best[0]} {fx(best[1])}" if best else "n/a"
        w = f"{worst[0]} {fx(worst[1])}" if worst else "n/a"
        out.append(
            f"| {LABEL.get(lang, lang)}{tag} | {meas} | **{fx(wt)}** | {fx(nd)} | {b} | {w} |"
        )
    notes = [
        "",
        "‡ Native control does not measure every benchmark (see `lane.json` → `na`). Geomean is over the wasm cells that have a ratio only.",
        "**Ruby (CRuby):** primary ratios include Asyncify and wasm32 `VALUE` semantics (heap 32-bit); not comparable to the matrix gcc reference without reading the reference table.",
    ]
    return "\n".join(out) + "\n" + "\n".join(notes)


def headline_reference(envs):
    out = [
        f"Reference columns only (not primary wasm overhead). {RIGOR}.",
        "",
        "| Language | Column | / native control | measured | Role (from lane) |",
        "|---|---|---:|---:|---|",
    ]
    any_row = False
    for lang in sorted(envs):
        e = envs[lang]
        lane = e.get("lane", {})
        roles = lane.get("columnRoles") or {}
        for col in sorted(roles):
            if roles[col] != "reference":
                continue
            sm = e.get("summary", {}).get(col)
            if not sm or sm.get("geomeanRatioToNative") is None:
                continue
            ec = (lane.get("extraColumns") or {}).get(col, {})
            role = (ec.get("role") or col).split(";")[0]
            if len(role) > 72:
                role = role[:69] + "..."
            out.append(
                f"| {LABEL.get(lang, lang)} | `{col}` | {fx(sm['geomeanRatioToNative'])} | {sm.get('measured', '')} | {role} |"
            )
            any_row = True
    if not any_row:
        return "_No reference-column geomeans in the current envelopes._"
    return "\n".join(out)


def spread_table(envs):
    out = [
        "Worst **maxSpreadPct** per language among primary cells (`native`, `wasmtime`, `node` at both sizes). "
        "0 = bit-exact; larger values used median of 5 runs.",
        "",
        "| Language | Benchmark | Column | maxSpreadPct |",
        "|---|---|---|---:|",
    ]
    for lang in sorted(envs):
        e = envs[lang]
        worst = (-1, None, None)
        for r in e.get("results", []):
            if r.get("status") == "n/a" or "columns" not in r:
                continue
            for col in ("native", "wasmtime", "node"):
                c = r["columns"].get(col, {})
                if c.get("status") != "ok":
                    continue
                sp = c.get("maxSpreadPct", 0) or 0
                if sp > worst[0]:
                    worst = (sp, r["benchmark"], col)
        if worst[1]:
            out.append(f"| {LABEL.get(lang, lang)} | {worst[1]} | {worst[2]} | {worst[0]:.5f} |")
    return "\n".join(out)


def v8_liftoff_table():
    d = latest_study("v8-tiering")
    if not d:
        return "_No v8-tiering envelope._"
    cols = [c for c in d["columns"] if c["key"] in ("A", "B", "wt")]
    if len(cols) < 2:
        return "_v8-tiering envelope missing TurboFan/Liftoff columns._"
    sub = dict(d, columns=cols)
    body = ratio_table(sub)
    return (
        body
        + "\n\nC lane only. **A** = TurboFan (`--no-liftoff`, the study's binding V8 column). "
        "**B** = Liftoff-only (pessimistic tier). **wt** = wasmtime 50 for the same modules."
    )


def geomean(xs):
    xs = [x for x in xs if x]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else None


def fx(x):
    return "n/a" if x is None else (f"{x:.2f}x" if x < 10 else f"{x:.1f}x")


def latest_lang_envelopes():
    by_lang = {}
    for f in sorted(glob.glob(os.path.join(RESDIR, "*-arm64-*.json"))):
        d = json.load(open(f))
        if d.get("study") != "wasm-side-study" or "language" not in d:
            continue
        by_lang[d["language"]] = d   # sorted by name, so the newest date wins
    return by_lang


def latest_study(kind):
    found = None
    for f in sorted(glob.glob(os.path.join(RESDIR, f"*-arm64-{kind}.json"))):
        found = json.load(open(f))
    return found


def marks(e):
    """{benchmark: symbol} from the lane's cellMarks (cells built with a lane-specific source variant)."""
    return {b: m["symbol"] for m in e["lane"].get("cellMarks", []) for b in m["benchmarks"]}


def mark_notes(envs):
    notes = [f"{m['symbol']} {m['note']}." for e in envs.values() for m in e["lane"].get("cellMarks", [])]
    return ("\n\n" + "\n".join(notes)) if notes else ""


def per_bench(envs, column):
    langs = sorted(envs, key=lambda l: envs[l]["summary"].get(column, {}).get("geomeanRatioToNative") or 1e9)
    benches = sorted({r["benchmark"] for e in envs.values() for r in e["results"]})
    out = ["| Benchmark | " + " | ".join(LABEL.get(l, l) for l in langs) + " |",
           "|---|" + "---:|" * len(langs)]
    for b in benches:
        cells = []
        for l in langs:
            r = next((r for r in envs[l]["results"] if r["benchmark"] == b), None)
            if r is None:
                cells.append("")
            elif r.get("status") == "n/a":
                cells.append("n/a")
            else:
                x = r.get("ratioToNative", {}).get(column)
                if x:
                    cells.append(fx(x) + marks(envs[l]).get(b, ""))
                else:   # no ratio: say which side did not measure (never a bare "ok")
                    st = {c: r["columns"].get(c, {}).get("status", "not run") for c in ("native", column)}
                    cells.append(f"{column} {st[column]}" if st[column] != "ok" else f"native {st['native']}")
        out.append(f"| {b} | " + " | ".join(cells) + " |")
    gm = [fx(envs[l]["summary"].get(column, {}).get("geomeanRatioToNative")) for l in langs]
    out.append("| **geomean** | " + " | ".join(f"**{g}**" for g in gm) + " |")
    return "\n".join(out) + mark_notes(envs)


def c_detail(envs):
    e = envs.get("c")
    if not e:
        return "_No C envelope._"
    out = ["| Benchmark | clang 23 native (instructions) | gcc 14 / clang | lp64 transform / clang | wasmtime / clang | V8 / clang |",
           "|---|---:|---:|---:|---:|---:|"]
    for r in e["results"]:
        if "columns" not in r:
            out.append(f"| {r['benchmark']} | n/a | | | | |")
            continue
        c, q = r["columns"], r.get("ratioToNative", {})
        lp = c.get("clang-lp64", {}).get("differential") if c.get("clang-lp64", {}).get("status") == "ok" else None
        nat = c.get("native", {}).get("differential") if c.get("native", {}).get("status") == "ok" else None
        lpd = "n/a" if lp is None or nat is None else ("identical" if lp == nat else f"{lp - nat:+d} instr")
        natd = f"{nat:,}" if nat is not None else f"native {c.get('native', {}).get('status', 'not run')}"
        out.append(f"| {r['benchmark']} | {natd} | {fx(q.get('gcc'))} | {lpd} | {fx(q.get('wasmtime'))} | {fx(q.get('node'))} |")
    s = e["summary"]
    g = lambda k: fx(s.get(k, {}).get("geomeanRatioToNative"))
    out.append(f"| **geomean** | | **{g('gcc')}** | | **{g('wasmtime')}** | **{g('node')}** |")
    return "\n".join(out)


def ratio_table(d):
    """Benchmark x column table for a study envelope: each column is num-tag differential / den-tag differential."""
    diff = {(c["tag"], c["benchmark"]): c["differential"] for c in d["cells"]}
    benches = sorted({c["benchmark"] for c in d["cells"]})
    cols = d["columns"]
    out = ["| Benchmark | " + " | ".join(c["label"] for c in cols) + " |", "|---|" + "---:|" * len(cols)]
    per_col = {c["key"]: [] for c in cols}
    for b in benches:
        cells = []
        for c in cols:
            n, m = diff.get((c["num"], b)), diff.get((c["den"], b))
            x = n / m if n and m else None
            per_col[c["key"]].append(x)
            cells.append(f"{x:.3f}" if x else "n/a")
        out.append(f"| {b} | " + " | ".join(cells) + " |")
    out.append("| **geomean** | " + " | ".join(
        f"**{geomean(per_col[c['key']]):.3f}**" if all(per_col[c["key"]]) else "n/a" for c in cols) + " |")
    return "\n".join(out)


def jitter_table(d):
    """Per configuration: guest threads and the worst per-size spread at the smaller and larger size."""
    sizes = {}
    for r in d["rows"]:
        sizes.setdefault(r["benchmark"], set()).add(r["n"])
    agg = {}
    for r in d["rows"]:
        small = r["n"] == min(sizes[r["benchmark"]])
        a = agg.setdefault(r["config"], dict(threads=set(), s=0.0, l=0.0))
        a["threads"].add(r["threads"])
        a["s" if small else "l"] = max(a["s" if small else "l"], r["spreadPct"])
    out = ["| Configuration | Guest threads | Worst spread, small size | Worst spread, large size |", "|---|---:|---:|---:|"]
    for k, a in sorted(agg.items(), key=lambda kv: -kv[1]["s"]):
        out.append(f"| `{k}` | {', '.join(sorted(a['threads']))} | {a['s']:.4f}% | {a['l']:.4f}% |")
    return "\n".join(out)


def wallclock_table(d):
    """Per benchmark: user-time differential ratio [95% CI] next to the instruction differential ratio."""
    comps = [("wasmtime", "clang", "wasmtime"), ("node", "clang", "V8 TurboFan"),
             ("node-liftoff", "clang", "V8 Liftoff"), ("gcc", "clang", "gcc (native control)")]
    cell = {(r["num"], r["den"], r["benchmark"]): r for r in d["rows"]}
    benches = sorted({r["benchmark"] for r in d["rows"]})
    out = ["| Benchmark | " + " | ".join(f"{lab}: time | {lab}: instructions" for _, _, lab in comps) + " |",
           "|---|" + "---:|---:|" * len(comps)]
    for b in benches:
        cells = []
        for num, den, _ in comps:
            r = cell.get((num, den, b))
            cells += ([f"{r['timeRatio']:.2f} [{r['ci95'][0]:.2f}, {r['ci95'][1]:.2f}]", f"{r['instrRatio']:.2f}"]
                      if r else ["n/a", "n/a"])
        out.append(f"| {b} | " + " | ".join(cells) + " |")
    st = d["stats"]
    out.append("| **geomean** | " + " | ".join(
        f"**{st[f'{n}/{m}']['geomeanTime']:.2f}** | **{st[f'{n}/{m}']['geomeanInstr']:.2f}**" for n, m, _ in comps) + " |")
    n = st["wasmtime/clang"]["n"]
    out += ["", f"Spearman and R² measure how well the instruction ratio tracks the time ratio across the {n} benchmarks "
            "(higher is better; 1.00 = perfect).", "",
            f"| Comparison ({n} benchmarks, size L) | Spearman | R² (log-log) |", "|---|---:|---:|"]
    for n, m, lab in comps + [("node", "wasmtime", "V8 TurboFan / wasmtime")]:
        s = st[f"{n}/{m}"]
        out.append(f"| {lab if m == 'wasmtime' else lab + ' / clang'} | {s['spearman']:.2f} | {s['r2Log']:.2f} |")
    return "\n".join(out)


def study_table(kind):
    d = latest_study(kind)
    if not d:
        return f"_No {kind} envelope._"
    if kind == "jitter":
        return jitter_table(d)
    if kind == "wallclock":
        return wallclock_table(d)
    if "columns" in d and "cells" in d:
        return ratio_table(d)
    return d.get("table_md") or "_(no table)_"


def splice(text, name, body):
    pat = re.compile(rf"(<!-- WASM-{name}:START -->\n)(.*?)(<!-- WASM-{name}:END -->)", re.S)
    if not pat.search(text):
        sys.exit(f"marker WASM-{name} not found in {DOC}")
    return pat.sub(lambda m: m.group(1) + body + "\n" + m.group(3), text)


def main():
    envs = latest_lang_envelopes()
    if not envs:
        print(f"(no per-language envelopes in {RESDIR}; only the study blocks are printed)", file=sys.stderr)
    main_envs = {l: e for l, e in envs.items() if l not in TEAVM}
    teavm_envs = {l: e for l, e in envs.items() if l in TEAVM}
    blocks = {
        "HEADLINE": headline(main_envs),
        "HEADLINE-REFERENCE": headline_reference({**main_envs, **teavm_envs}),
        "SPREAD": spread_table({**main_envs, **teavm_envs}),
        "WASMTIME": per_bench(main_envs, "wasmtime"),
        "V8": per_bench(main_envs, "node"),
        "V8-LIFTOFF": v8_liftoff_table(),
        "C": c_detail(envs),
    }
    blocks["TEAVM"] = "_No TeaVM envelopes._"
    if teavm_envs:
        blocks["TEAVM"] = (headline(teavm_envs) + "\n\nPer benchmark, wasmtime 50:\n\n" + per_bench(teavm_envs, "wasmtime")
                           + "\n\nPer benchmark, V8 TurboFan:\n\n" + per_bench(teavm_envs, "node"))
    for kind in STUDY_KINDS:
        blocks[kind.upper()] = study_table(kind)
    for k, v in blocks.items():
        print(f"## {k}\n\n{v}\n")
    if "--write" in sys.argv:
        text = open(DOC).read()
        for k, v in blocks.items():
            if f"<!-- WASM-{k}:START -->" in text:
                text = splice(text, k, v)
        open(DOC, "w").write(text)
        print(f">> spliced into {DOC}")


if __name__ == "__main__":
    main()
