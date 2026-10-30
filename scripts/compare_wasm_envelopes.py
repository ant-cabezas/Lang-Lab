#!/usr/bin/env python3
"""Compare wasm language envelopes between two measurement dates (read-only).

Reports per-(language, benchmark, column) ratio deltas. Default: baseline 2026-10-27 vs replication date.

    python3 scripts/compare_wasm_envelopes.py
    python3 scripts/compare_wasm_envelopes.py --baseline 2026-10-27 --replicate 2026-10-28 --threshold 0.02
"""
import argparse
import glob
import json
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESDIR = os.path.join(ROOT, "results", "wasm")
PRIMARY = ("wasmtime", "node")


def load_lang(resdir, date, isa, lang):
    path = os.path.join(resdir, f"{date}-{isa}-{lang}.json")
    if not os.path.isfile(path):
        return None
    return json.load(open(path))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--baseline", default="2026-10-27")
    ap.add_argument("--replicate", default="2026-10-28")
    ap.add_argument("--isa", default="arm64")
    ap.add_argument("--threshold", type=float, default=0.02, help="relative ratio change flag (0.02 = 2%)")
    ap.add_argument("--resdir", default=RESDIR)
    args = ap.parse_args()

    langs = sorted(
        os.path.basename(p).replace(".json", "").split(f"-{args.isa}-", 1)[-1]
        for p in glob.glob(os.path.join(args.resdir, f"{args.baseline}-{args.isa}-*.json"))
    )
    langs = [l for l in langs if load_lang(args.resdir, args.baseline, args.isa, l)]

    flagged = []
    compared = 0
    missing_rep = []
    for lang in langs:
        base = load_lang(args.resdir, args.baseline, args.isa, lang)
        rep = load_lang(args.resdir, args.replicate, args.isa, lang)
        if not rep:
            missing_rep.append(lang)
            continue
        for br in base["results"]:
            b = br["benchmark"]
            if br.get("status") == "n/a":
                continue
            rr = next((r for r in rep["results"] if r["benchmark"] == b), None)
            if not rr or rr.get("status") == "n/a":
                continue
            for col in PRIMARY:
                x0 = br.get("ratioToNative", {}).get(col)
                x1 = rr.get("ratioToNative", {}).get(col)
                if x0 is None or x1 is None:
                    continue
                compared += 1
                rel = abs(x1 - x0) / x0 if x0 else abs(x1 - x0)
                if rel > args.threshold:
                    flagged.append((rel, lang, b, col, x0, x1))

    print(f"baseline={args.baseline} replicate={args.replicate} isa={args.isa}")
    print(f"compared primary ratios: {compared}")
    if missing_rep:
        print(f"missing replicate envelope: {', '.join(missing_rep)}")
    flagged.sort(reverse=True)
    print(f"cells with relative change > {100*args.threshold:.0f}%: {len(flagged)}")
    for rel, lang, b, col, x0, x1 in flagged[:40]:
        print(f"  {lang}/{b}/{col}: {x0:.4f} -> {x1:.4f}  ({rel*100:.2f}%)")
    if len(flagged) > 40:
        print(f"  ... and {len(flagged)-40} more")

    # geomean summary
    for col in PRIMARY:
        shifts = []
        for lang in langs:
            base = load_lang(args.resdir, args.baseline, args.isa, lang)
            rep = load_lang(args.resdir, args.replicate, args.isa, lang)
            if not base or not rep:
                continue
            g0 = base["summary"].get(col, {}).get("geomeanRatioToNative")
            g1 = rep["summary"].get(col, {}).get("geomeanRatioToNative")
            if g0 and g1:
                shifts.append(abs(g1 - g0) / g0)
        if shifts:
            mx = max(shifts)
            print(f"geomean {col}: max lang relative shift {mx*100:.2f}%")

    return 1 if flagged and compared else 0


if __name__ == "__main__":
    sys.exit(main() or 0)
