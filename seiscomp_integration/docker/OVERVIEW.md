# RECOVAR SeisComP Integration Overview

RECOVAR is an unsupervised model that scores a 3-component waveform window with an
earthquake probability in [0, 1].

Inside SeisComP it runs as a module called `recovar_pick_filter`. The flow is:

1. `scautopick` detects picks on the incoming waveforms.
2. `recovar_pick_filter` listens for those picks, pulls the waveform window around
   each one, and runs RECOVAR on it.
3. It attaches the result to the pick as a `recovar_score` comment.
4. `scdb` writes the scored pick to the database.

A high score means the pick looks like a real earthquake, and a low score means it looks
like noise. You can use the score to keep likely earthquake picks and filter out
noise picks.
