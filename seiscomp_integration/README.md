# RECOVAR: SeisComP Integration

Run RECOVAR as a real-time pick filter inside SeisComP: every pick from
`scautopick` gets a `recovar_score:[0–1]` comment attached and persisted to the
database.

Tested on Ubuntu 22.04 with SeisComP 7.x. For a containerized setup instead, see
[`docker/INSTALL.md`](docker/INSTALL.md) and [`docker/DEMO.md`](docker/DEMO.md).

## Install

1. System packages:

```bash
sudo apt-get install -y libboost-program-options1.74.0 mariadb-server mariadb-client
sudo systemctl start mariadb && sudo systemctl enable mariadb
```

2. SeisComP. Download `seiscomp-7.x.x-ubuntu22.04-x86_64.tar.gz` from
`seiscomp.de/downloader/` (free account), then:

```bash
tar xzf ~/Downloads/seiscomp-7.x.x-ubuntu22.04-x86_64.tar.gz -C ~/
```

Add to `~/.bashrc` and source it:

```bash
export SEISCOMP_ROOT=~/seiscomp
export PATH=/usr/bin:$SEISCOMP_ROOT/bin:$PATH
export LD_LIBRARY_PATH=$SEISCOMP_ROOT/lib
```

3. Run `seiscomp setup`:

```bash
seiscomp setup
```

| Prompt | Value |
|---|---|
| Agency ID | `TEST` |
| Enable database storage | `yes` |
| Database backend | `0` (mysql/mariadb) |
| Create the SeisComP database | `yes` |
| Run as super user | `yes` |
| RW user / password | `sysop` / `sysop` |
| Public hostname | `localhost` |
| RO user / password | `sysop` / `sysop` |
| Final prompt | `P` |

4. Clone RECOVAR and run the installer:

```bash
git clone git@github.com:onurefe/recovar.git ~/recovar
cd ~/recovar && git checkout seiscomp-integration
bash ~/recovar/seiscomp_integration/install.sh
```

The installer creates the Python venv at `~/.venv-recovar-seiscomp`, installs the
dependencies (tensorflow 2.14.0, numpy 1.26.0, scipy, obspy, pymysql, matplotlib)
and installs the `recovar_pick_filter` daemon into `$SEISCOMP_ROOT/bin/`. It prints
`All imports OK` when it succeeds.

Override the venv path or interpreter with
`RECOVAR_VENV=/path/to/venv PYTHON=python3.11 bash install.sh`. numpy is pinned to
`1.26.0` otherwise TensorFlow 2.14 declares no upper bound on numpy and crashes (ABI
mismatch) if numpy 2.x is pulled in.

## One-time station setup

1. Start scmaster:

```bash
seiscomp start scmaster
```

2. Load station inventory:

```bash
~/.venv-recovar-seiscomp/bin/python3 -c "
from obspy.clients.fdsn import Client
from obspy import UTCDateTime
inv = Client('IRIS').get_stations(
    network='IU', station='ANMO', location='00', channel='HH?',
    level='response',
    starttime=UTCDateTime('2018-01-01'), endtime=UTCDateTime('2025-01-01'))
inv.write('/tmp/inventory.xml', format='STATIONXML')
"
seiscomp exec import_inv fdsnxml /tmp/inventory.xml ~/seiscomp/etc/inventory/station.xml
seiscomp exec scinv sync --filebase ~/seiscomp/etc/inventory/ \
    -d mysql://sysop:sysop@localhost/seiscomp
```

3. Configure scautopick bindings:

```bash
cat > ~/seiscomp/etc/key/station_IU_ANMO << 'EOF'
global:default
scautopick:default
EOF

mkdir -p ~/seiscomp/etc/key/scautopick
cat > ~/seiscomp/etc/key/scautopick/profile_default << 'EOF'
detecStream    = HH
detecLocid     = 00
detecFilter    = "RMHP(10)>>ITAPER(30)>>BW(4,1,20)>>STALTA(0.5,10)"
trigOn         = 3.0
trigOff        = 1.5
timeCorr       = -0.8
picker         = AIC
useSquaredness = true
EOF

seiscomp update-config scautopick
```

## Run

```bash
source ~/.bashrc
seiscomp start scmaster scdb recovar_pick_filter
```

Wait for the model to load (~30 s):

```bash
tail -f ~/.seiscomp/log/recovar_pick_filter.log
# Expected: recovar_pick_filter: ready
```

Once ready, `recovar_pick_filter` listens on the PICK messaging group, scores every
pick scautopick detects, and scdb persists the score to the database.

Module management:

```bash
seiscomp start   recovar_pick_filter
seiscomp stop    recovar_pick_filter
seiscomp status  recovar_pick_filter
seiscomp enable  recovar_pick_filter   # auto-start with seiscomp start
seiscomp disable recovar_pick_filter
```

## Testing with the test archive

1. Build the test archive (downloads earthquake + noise waveforms from IRIS into
full-day SDS files):

```bash
~/.venv-recovar-seiscomp/bin/python3 ~/recovar/seiscomp_integration/create_test_archive.py \
    --output ~/seiscomp_test/sds
```

2. Start recovar_pick_filter in the background pointed at the archive:

```bash
seiscomp exec recovar_pick_filter \
    --model-path ~/recovar/models/representation_cross_covariances.h5 \
    --record-stream "sdsarchive://$HOME/seiscomp_test/sds" &
```

3. Wait for the model to load:

```bash
tail -f ~/.seiscomp/log/recovar_pick_filter.log | grep -m1 "pick_filter: ready"
```

4. Export the archive to a single MiniSEED file:

```bash
seiscomp exec scart -dsE \
    -t "2018-01-01T00:00:00~2024-12-31T23:59:59" \
    -n "IU.ANMO.00" \
    ~/seiscomp_test/sds > /tmp/playback.mseed
```

`sdsarchive://` can't be used directly with scautopick in playback mode, scautopick
requests "current time" data from the SDS reader, which falls outside the 2018–2024
archive. Exporting to a flat file first avoids this.

5. Run scautopick in playback mode from the file:

```bash
seiscomp exec scautopick \
    --playback \
    -I "file:///tmp/playback.mseed" \
    -d mysql://sysop:sysop@localhost/seiscomp
```

scautopick reads the file sequentially and publishes picks; recovar_pick_filter
fetches waveforms from the SDS archive to score each one. It exits when the file is
exhausted.

6. Stop recovar_pick_filter:

```bash
kill %1
```

7. Query the results:

```bash
~/.venv-recovar-seiscomp/bin/python3 ~/recovar/seiscomp_integration/query_scored_picks.py
```

Expected output (earthquake picks score > 0.8):

```
pick_time                  net  sta    cha  score   pick_id
-----------------------------------------------------------
2018-09-06 15:59:57.400    IU   ANMO   HHZ  0.9399  Pick/...
2019-07-06 03:21:34.600    IU   ANMO   HHZ  0.9883  Pick/...
...
N scored pick(s) from scautopick.
```

## Troubleshooting

| Symptom | Fix |
|---|---|
| `No stations added` in scautopick | Re-run `seiscomp update-config scautopick` |
| `waveform unavailable` in recovar log | Check `--record-stream` or `recordStream` in `~/.seiscomp/global.cfg` |
| No scored picks in database | Confirm scdb is running: `seiscomp status scdb` |
| `recovar_pick_filter` not starting | Check `~/.seiscomp/log/recovar_pick_filter.log` |
