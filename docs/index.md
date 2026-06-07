# RECOVAR

RECOVAR is an unsupervised machine-learning framework for detecting seismic signals in continuous waveform data. It learns compressed representations waveforms with multiple-autoencoders and scores each 30 s  window with an earthquake probability in [0, 1]. 

Model inputs are 3-component, 3000-sample waveforms, demeaned, linear-detrended, and 1–20 Hz bandpassed

This documentation covers how to install RECOVAR, run the demo, and deploy it inside SeisComP (bare-metal or Docker).

## Pages

- **[Overview & install](../README.md)**, what RECOVAR is and how to set up the environment.
- **[Demo](../demo.ipynb)** continuous scoring on a real earthquake, single earthquake/noise windows, and a labeled ROC/AUC benchmark.
- **[SeisComP integration](../seiscomp_integration/README.md)** the real-time pick-filter daemon.
- **Docker**, [installation](../seiscomp_integration/docker/INSTALL.md) and [demo](../seiscomp_integration/docker/DEMO.md) for the containerized SeisComP setup.
