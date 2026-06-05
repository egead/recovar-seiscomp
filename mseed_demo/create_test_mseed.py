"""Regenerate data/test.mseed by fetching the demo waveform from IRIS.

The committed test.mseed is 450 s of KO.DKL..HH? (Dikili, western Turkey) around
the P arrival of the M6.1 Bigadiç–Balıkesir earthquake (2025-08-10 16:53:47 UTC).
KO.DKL is ~100 km from the epicentre — regional distance, where the 1-20 Hz band
RECOVAR uses carries strong P/S energy. Only needed to rebuild the file; the
notebook demo uses the committed copy directly.
"""

from obspy import UTCDateTime
from obspy.clients.fdsn import Client

START = UTCDateTime("2025-08-10T16:53:04.96")   # P arrival − 60 s
DURATION_S = 450.0


def fetch_test_mseed(output="../data/test.mseed"):
    st = Client("IRIS").get_waveforms("KO", "DKL", "", "HH?", START, START + DURATION_S)
    if not st:
        raise RuntimeError("No data returned from IRIS.")
    st.write(output, format="MSEED")
    return output


if __name__ == "__main__":
    print("written:", fetch_test_mseed())
