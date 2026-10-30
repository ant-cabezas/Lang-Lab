#!/usr/bin/env python3
"""Assemble wasm-side-study envelopes from a RAW dir (same logic as wasm-study.sh tail)."""
import json
import math
import os
import subprocess
import sys
from datetime import datetime, timezone

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def cell(raw, lang, col, b):
    base = os.path.join(raw, f"{lang}--{col}--{b}")
    if os.path.exists(base + ".status"):
        return dict(status=open(base + ".status").read().strip())
    if not os.path.exists(base + ".rc"):
        return dict(status="not-run")
    rc = int(open(base + ".rc").read().strip() or 0)
    try:
        err = open(base + ".err").read().strip().splitlines()
    except OSError:
        err = []
    try:
        j = json.loads(open(base + ".json").read())
    except Exception:
        j = None
    if rc == 0 and j and j.get("correct"):
        spread = max((j[k]["max"] - j[k]["min"]) / j[k]["median"] for k in ("i_n1", "i_n2"))
        return dict(
            status="ok",
            n1=j["n1"],
            n2=j["n2"],
            i_n1=j["i_n1"]["median"],
            i_n2=j["i_n2"]["median"],
            differential=j["differential"],
            runs=j["runs"],
            determinism=j["determinism"],
            maxSpreadPct=round(100 * spread, 5),
        )
    status = {3: "checksum-fail", 4: "measure-fail"}.get(rc, f"fail-rc{rc}")
    return dict(status=status, note=" | ".join(err[-3:]))


def geomean(xs):
    xs = [x for x in xs if x]
    return math.exp(sum(math.log(x) for x in xs) / len(xs)) if xs else None


def image_digest(ref):
    try:
        out = subprocess.check_output(
            ["docker", "inspect", "--format", "{{.Id}}", ref],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return out if out else None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def assemble(lang, raw, resdir, date, isa, benches, wasm_columns=None):
    os.chdir(ROOT)
    lane = json.load(open(f"languages/wasm/{lang}/lane.json"))
    cols = wasm_columns or (
        ["native", "wasmtime", "node"] + sorted((lane.get("extraColumns") or {}).keys())
    )
    tc_path = os.path.join(raw, f"toolchain-{lang}.txt")
    toolchain = open(tc_path).read().strip().splitlines() if os.path.isfile(tc_path) else []
    na = lane.get("na") or {}
    rows = []
    for b in benches:
        if b in na:
            rows.append(dict(benchmark=b, status="n/a", reason=na[b]))
            continue
        only = {c: (lane.get("extraColumns") or {}).get(c, {}).get("benchmarks") for c in cols}
        cs = {
            c: (
                cell(raw, lang, c, b)
                if only[c] is None or b in only[c]
                else dict(
                    status="n/a",
                    reason=f"column {c} is defined only for: {' '.join(only[c])}",
                )
            )
            for c in cols
        }
        nat = cs.get("native", {})
        nd = nat.get("differential") if nat.get("status") == "ok" else None
        ratios = {}
        for c in cols:
            if c != "native" and cs[c].get("status") == "ok" and nd:
                ratios[c] = round(cs[c]["differential"] / nd, 4)
        rows.append(dict(benchmark=b, columns=cs, ratioToNative=ratios))
    summary = {}
    for c in cols:
        if c == "native":
            continue
        rs = [r["ratioToNative"].get(c) for r in rows if "ratioToNative" in r]
        ok = [x for x in rs if x]
        summary[c] = dict(
            measured=len(ok), geomeanRatioToNative=round(geomean(ok), 4) if ok else None
        )
    digests = {}
    for ref in {lane.get("nativeImage"), lane.get("wasmImage")}:
        if ref:
            d = image_digest(ref)
            if d:
                digests[ref] = d
    for ec in (lane.get("extraColumns") or {}).values():
        ref = ec.get("image")
        if ref and ref not in digests:
            d = image_digest(ref)
            if d:
                digests[ref] = d
    env = dict(
        study="wasm-side-study",
        language=lang,
        date=date,
        isa=isa,
        ranked=False,
        metric="differential instructions I(n2)-I(n1), qemu-user + TCG insn plugin",
        ratioMeaning="column differential / native differential, same language version and compiler family "
        "(lower is better; 1.00 = no overhead over native)",
        spreadMeaning="maxSpreadPct: largest (max - min) / median of I(n1) or I(n2) over the runs, percent "
        "(lower is better; 0 = bit-exact)",
        lane=lane,
        toolchain=toolchain,
        summary=summary,
        results=rows,
        provenance=dict(
            # when the envelope was assembled (not when the cells ran); no local paths, the envelope is published
            assembledAt=datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            imageDigests=digests,
        ),
    )
    path = os.path.join(resdir, f"{date}-{isa}-{lang}.json")
    json.dump(env, open(path, "w"), indent=1)
    print(
        f">> {path}: "
        + ", ".join(f"{c} {s['geomeanRatioToNative']} ({s['measured']})" for c, s in summary.items())
    )


def main():
    if len(sys.argv) < 2:
        sys.exit(
            "usage: assemble_wasm_envelope.py <lang> [rawdir] [date] [isa]\n"
            "   or: assemble_wasm_envelope.py --all-langs <rawdir> <date> [isa]  (needs LANGS env or all lanes)"
        )
    os.chdir(ROOT)
    benches = [
        p.split(os.sep)[1]
        for p in sorted(__import__("glob").glob("benchmarks/*/spec.json"))
        if p.split(os.sep)[1] != "message-ring"
    ]
    if sys.argv[1] == "--all-langs":
        raw, date = sys.argv[2], sys.argv[3]
        isa = sys.argv[4] if len(sys.argv) > 4 else "arm64"
        resdir = os.environ.get("RESDIR", os.path.join(ROOT, "results", "wasm"))
        bench_env = os.environ.get("BENCHES", "").split()
        if bench_env:
            benches = bench_env
        cols_env = os.environ.get("WASM_COLUMNS", "").split()
        wasm_columns = cols_env if cols_env else None
        langs = [x for x in os.environ.get("LANGS", "").split() if x] or [
            os.path.basename(os.path.dirname(p))
            for p in sorted(__import__("glob").glob("languages/wasm/*/lane.json"))
        ]
        for lang in langs:
            assemble(lang, raw, resdir, date, isa, benches, wasm_columns)
        return
    lang = sys.argv[1]
    raw = sys.argv[2] if len(sys.argv) > 2 else os.environ.get("RAWDIR", "")
    if not raw:
        sys.exit("rawdir required")
    date = sys.argv[3] if len(sys.argv) > 3 else os.environ.get("DATE", datetime.now().strftime("%Y-%m-%d"))
    isa = sys.argv[4] if len(sys.argv) > 4 else os.environ.get("ISA", "arm64")
    resdir = os.environ.get("RESDIR", os.path.join(ROOT, "results", "wasm"))
    assemble(lang, raw, resdir, date, isa, benches)


if __name__ == "__main__":
    main()
