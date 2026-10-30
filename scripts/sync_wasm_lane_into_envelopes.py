#!/usr/bin/env python3
"""Patch embedded lane.json in wasm language envelopes from languages/wasm/*/lane.json."""
import glob
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RESDIR = os.path.join(ROOT, "results", "wasm")
for path in glob.glob(os.path.join(RESDIR, "*-arm64-*.json")):
    d = json.load(open(path))
    if d.get("study") != "wasm-side-study" or "language" not in d:
        continue
    lang = d["language"]
    lane_path = os.path.join(ROOT, "languages", "wasm", lang, "lane.json")
    if not os.path.isfile(lane_path):
        continue
    d["lane"] = json.load(open(lane_path))
    json.dump(d, open(path, "w"), indent=1)
    print(">>", path)
