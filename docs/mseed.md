# Scoring MiniSEED files

The [Demo](../demo.ipynb) shows MiniSEED scoring end to end. This page is the helper-API
reference for running it on your own data, using the functions in
`mseed_demo/mseed_predictor.py`.

## Helpers

The functions live in `mseed_demo/mseed_predictor.py`:

| Function | Purpose |
|---|---|
| `load_traces(path)` | Read a MiniSEED file, merge gaps, return the Z/H1/H2 traces. |
| `load_scorer(model_path)` | Build the classifier; returns `score(waveform)`. |
| `score_window(traces, scorer, t)` | Score one 40 s window starting at time `t`. |
| `score_file(path, model_path, step_s=10)` | Slide a window across the file, yield `(window_start, inner_start, score)`. |
| `preprocess_stream(st)` | Resample + bandpass a stream for plotting. |

## Single window

```python
from obspy import UTCDateTime
from mseed_predictor import load_traces, load_scorer, score_window

traces = load_traces("data/test.mseed")
scorer = load_scorer("models/representation_cross_covariances.h5")

t = UTCDateTime("2025-08-10T16:53:34.96")   # 40 s window over the P arrival
print(score_window(traces, scorer, t))      # -> 0.9225
```

## Sliding window across a file

```python
from mseed_predictor import score_file

for window_start, inner_start, score in score_file(
        "data/test.mseed", "models/representation_cross_covariances.h5", step_s=10):
    print(inner_start, round(score, 4))
```

`window_start` is the start of the 40 s fetch window; `inner_start` is the start of
the scored 30 s window (`window_start + 5 s`); `score` is the earthquake probability.

## Test data

`data/test.mseed` is committed. To rebuild it from IRIS:

```bash
python mseed_demo/create_test_mseed.py
```

or `from create_test_mseed import fetch_test_mseed; fetch_test_mseed()`.
