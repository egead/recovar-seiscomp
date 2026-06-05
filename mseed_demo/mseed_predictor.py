"""Helper functions for scoring a 3-component MiniSEED file with RECOVAR.

Import these from the demo notebook (model_test_mseed.ipynb). Each 40 s window is
resampled to 100 Hz, bandpassed 1-20 Hz, cropped to the inner 30 s (3000 samples),
demeaned + L2-normalized per channel (matching training), then scored to an
earthquake probability in [0, 1].
"""

import numpy as np
from scipy.signal import resample as sp_resample
from obspy import read, Stream

TARGET_FS   = 100
WINDOW_S    = 40.0
CROP_EDGE_S = 5.0
INNER_S     = WINDOW_S - 2 * CROP_EDGE_S
BP_LOW_HZ, BP_HIGH_HZ = 1.0, 20.0

N_FETCH  = int(WINDOW_S    * TARGET_FS)   # 4000
N_INNER  = int(INNER_S     * TARGET_FS)   # 3000
CROP_OFF = int(CROP_EDGE_S * TARGET_FS)   # 500

# Component name -> channel suffixes to try, in priority order.
COMP_MAP = [("Z", ["Z"]), ("H1", ["N", "1"]), ("H2", ["E", "2"])]


def _resample(arr, src_fs):
    if abs(src_fs - TARGET_FS) < 0.01:
        return arr
    return sp_resample(arr, int(round(len(arr) * TARGET_FS / src_fs)))


def _bandpass(arr):
    """Ideal 1-20 Hz rectangular Fourier mask (zero-phase)."""
    n = len(arr)
    freqs = np.fft.rfftfreq(n, d=1.0 / TARGET_FS)
    mask = (freqs >= BP_LOW_HZ) & (freqs <= BP_HIGH_HZ)
    return np.fft.irfft(np.fft.rfft(arr) * mask, n=n)


def _normalize(waveform):
    """Demean then L2-normalize each channel along the time axis (axis 0)."""
    x = waveform - waveform.mean(axis=0, keepdims=True)
    norm = np.sqrt(np.sum(x ** 2, axis=0, keepdims=True))
    return x / (1e-37 + norm)


def preprocess_stream(st):
    """Copy of st resampled to 100 Hz and bandpassed, for plotting what the model sees.

    Per-window demean/L2-norm is intentionally skipped here: it rescales each window
    independently and would make a continuous-data plot jump.
    """
    out = Stream()
    for tr in st:
        tr2 = tr.copy()
        tr2.data = _bandpass(_resample(tr.data.astype(np.float64), tr.stats.sampling_rate)).astype(np.float32)
        tr2.stats.sampling_rate = TARGET_FS
        out.append(tr2)
    return out


def _select_trace(st, suffixes):
    for suffix in suffixes:
        for tr in st:
            if tr.stats.channel.endswith(suffix):
                return tr
    return None


def _extract(tr, t_start):
    """N_FETCH samples from tr at t_start (resampled to 100 Hz), or None on a gap."""
    sliced = tr.slice(t_start, t_start + N_FETCH / TARGET_FS)
    if sliced is None or len(sliced) == 0 or np.ma.is_masked(sliced.data):
        return None
    arr = _resample(sliced.data.astype(np.float64), sliced.stats.sampling_rate)
    return arr[:N_FETCH] if len(arr) >= N_FETCH else None


def load_traces(mseed_path):
    """Read the file, merge gaps to masked arrays, and return {Z, H1, H2} traces."""
    st = read(mseed_path)
    st.merge(method=0, fill_value=None)
    traces = {}
    for name, suffixes in COMP_MAP:
        tr = _select_trace(st, suffixes)
        if tr is None:
            raise RuntimeError(f"Component '{name}' not found in {[t.stats.channel for t in st]}")
        traces[name] = tr
    return traces


def load_scorer(model_path):
    """Build the classifier and return score(waveform) for a (3000, 3) array."""
    from recovar.representation_learning_models import RepresentationLearningMultipleAutoencoder
    from recovar.classifier_models import ClassifierMultipleAutoencoder

    model = RepresentationLearningMultipleAutoencoder(
        name="rep_learning_autoencoder_ensemble", input_noise_std=1e-6, eps=1e-27)
    model.compile()
    model(np.zeros((1, N_INNER, 3), dtype=np.float32))
    model.load_weights(model_path)
    classifier = ClassifierMultipleAutoencoder(model)

    return lambda waveform: float(classifier(waveform[np.newaxis].astype(np.float32))[0])


def score_window(traces, scorer, t):
    """Score the single 40 s window at t. Returns a probability, or None on a gap."""
    channels = []
    for name in ("Z", "H1", "H2"):
        raw = _extract(traces[name], t)
        if raw is None:
            return None
        channels.append(_bandpass(raw)[CROP_OFF:CROP_OFF + N_INNER])
    return scorer(_normalize(np.stack(channels, axis=-1).astype(np.float32)))


def score_file(mseed_path, model_path, step_s=10.0):
    """Yield (window_start, inner_start, score) for each gap-free 40 s window."""
    traces = load_traces(mseed_path)
    scorer = load_scorer(model_path)
    t_start = max(tr.stats.starttime for tr in traces.values())
    t_end   = min(tr.stats.endtime   for tr in traces.values())
    t = t_start
    while t + WINDOW_S <= t_end:
        score = score_window(traces, scorer, t)
        if score is not None:
            yield t, t + CROP_EDGE_S, score
        t += step_s
