# RECOVAR

RECOVAR is an unsupervised machine-learning framework for detecting seismic
signals in continuous waveform data. It learns compressed representations of
3-component waveforms with deep autoencoders and scores each window with an
earthquake probability in [0, 1], no labels required.

This documentation covers how to install RECOVAR, run the demo, score your own
MiniSEED files, and deploy it inside SeisComP (bare-metal or Docker).

## Pages

- **[Overview & install](../README.md)**, what RECOVAR is and how to set up the environment.
- **[Demo](../demo.ipynb)**, the full notebook: labeled benchmark, a single 40 s
  window, and continuous scoring on a real earthquake.
- **[Scoring MiniSEED files](mseed.md)**, use the helper functions on your own data.
- **[SeisComP integration](../seiscomp_integration/README.md)**, the real-time pick-filter daemon.
- **Docker**, [installation](../seiscomp_integration/docker/INSTALL.md) and [demo](../seiscomp_integration/docker/DEMO.md) for the containerized SeisComP setup.

## At a glance

The model targets 3-component, 100 Hz waveforms. Each 40 s window is bandpassed
1–20 Hz, cropped to an inner 30 s (3000 samples), demeaned and L2-normalized, then
scored. The same preprocessing is used everywhere, the demo, the MiniSEED helpers,
and the SeisComP daemon, so scores are consistent across all entry points.
