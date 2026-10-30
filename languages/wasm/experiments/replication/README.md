# replication: does an independent re-measurement reproduce the envelopes?

`summarize.py` compares two sets of per-language envelopes written by `scripts/wasm-study.sh` (a published run and
an independent re-measurement with images rebuilt from the same Dockerfiles) and writes
`results/wasm/<date>-arm64-replication.json`: for every lane measured completely in both runs, the largest change
of any cell differential per column (percent, **lower is better**, 0 = bit-identical) and both runs' geomean
ratios.

```sh
RESDIR=/tmp/replica scripts/wasm-study.sh                      # a second full run into a scratch directory
python3 languages/wasm/experiments/replication/summarize.py \
  results/wasm 2026-10-27 /tmp/replica "$(date +%F)" results/wasm c csharp go java
```

The published replication covers C, C#, Go and Java (the four lanes the second run completed).
