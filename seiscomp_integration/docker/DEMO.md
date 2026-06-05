# RECOVAR SeisComP: Docker demo

Run the pick-filter pipeline inside the container. First build and start the
container and shell into it, see [Docker installation](INSTALL.md). The steps below
assume you are in the container shell with the `$PY` / `$SDS` / `$SC` shortcuts set
(they are defined in the installation page).

## Pick-filter pipeline

`scautopick` produces picks and `recovar_pick_filter` attaches a `recovar_score` to
each. It runs on an archive/playback and **needs IRIS network access** to fetch the
inventory and test archive.

Run these steps in the container shell, in order.

1. Start the message system and DB writer:

```bash
$SC start scmaster scdb
sleep 6
$SC status scmaster scdb
```

2. Load station inventory from IRIS (needs network):

```bash
$PY -c "
from obspy.clients.fdsn import Client
from obspy import UTCDateTime
inv = Client('IRIS').get_stations(
    network='IU', station='ANMO', location='00', channel='HH?',
    level='response',
    starttime=UTCDateTime('2018-01-01'), endtime=UTCDateTime('2025-01-01'))
inv.write('/tmp/inventory.xml', format='STATIONXML')
print('inventory written')
"
$SC exec import_inv fdsnxml /tmp/inventory.xml $SEISCOMP_ROOT/etc/inventory/station.xml
$SC exec scinv sync --filebase $SEISCOMP_ROOT/etc/inventory/ \
    -d mysql://sysop:sysop@localhost/seiscomp
```

3. Configure scautopick bindings:

```bash
cat > $SEISCOMP_ROOT/etc/key/station_IU_ANMO << 'EOF'
global:default
scautopick:default
EOF
mkdir -p $SEISCOMP_ROOT/etc/key/scautopick
cat > $SEISCOMP_ROOT/etc/key/scautopick/profile_default << 'EOF'
detecStream    = HH
detecLocid     = 00
detecFilter    = "RMHP(10)>>ITAPER(30)>>BW(4,1,20)>>STALTA(0.5,10)"
trigOn         = 3.0
trigOff        = 1.5
timeCorr       = -0.8
picker         = AIC
useSquaredness = true
EOF
$SC update-config scautopick
```

4. Build the test archive from IRIS (needs network):

```bash
$PY /root/recovar/seiscomp_integration/create_test_archive.py --output $SDS
```

5. Start the pick filter in the background and wait for it to come up:

```bash
$SC exec recovar_pick_filter \
    --model-path /root/recovar/models/representation_cross_covariances.h5 \
    --record-stream "sdsarchive://$SDS" \
    > /root/.seiscomp/log/recovar_pick_filter.log 2>&1 &
RECOVAR_PID=$!
tail -f /root/.seiscomp/log/recovar_pick_filter.log   # Ctrl-C once you see "pick_filter: ready"
```

6. Export the archive to flat MiniSEED:

```bash
$SC exec scart -dsE \
    -t "2018-01-01T00:00:00~2024-12-31T23:59:59" \
    -n "IU.ANMO.00" \
    $SDS > /tmp/playback.mseed
ls -lh /tmp/playback.mseed
```

7. Run the playback:

```bash
$SC exec scautopick \
    --playback \
    -I "file:///tmp/playback.mseed" \
    -d mysql://sysop:sysop@localhost/seiscomp
sleep 20   # let recovar drain
```

8. Stop the pick filter:

```bash
kill $RECOVAR_PID
```

9. Query the scored picks:

```bash
$PY /root/recovar/seiscomp_integration/query_scored_picks.py --sds $SDS
```

## Get the figure over SSH

`query_scored_picks.py` can save a waveform/score figure to a PNG (`--plot`
uses a headless backend, so no display is needed). Generate it inside the
container, then copy it to the host with `scp`.

Inside the container:

```bash
$PY /root/recovar/seiscomp_integration/query_scored_picks.py --sds $SDS --plot --plot-output /tmp/scored_picks.png
```

On the host:

```bash
scp -P 2222 root@localhost:/tmp/scored_picks.png .   # password: recovar
```

## Notes

- The repo mount is read-only, write to `/tmp`, `$SDS`, or the SeisComP trees, not
  `/root/recovar`.
