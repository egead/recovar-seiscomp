# RECOVAR SeisComP: Docker demo

Run the pick-filter pipeline inside the container. For what this does, see the
[overview](OVERVIEW.md). First build and start the container, see
[Docker installation](INSTALL.md). Then open a shell in it over SSH to connect to
the docker container:

```bash
ssh -p 2222 root@localhost        # password: recovar
```

Run the steps below from that shell.

## Pick-filter pipeline

`scautopick` produces picks and `recovar_pick_filter` attaches a `recovar_score` to
each. It runs on an archive/playback and **needs IRIS network access** to fetch the
inventory and test archive. Run the steps in order.

1. Start and check the SeisComp bus and database writer:

```bash
seiscomp --asroot start scmaster scdb
sleep 6
seiscomp --asroot status scmaster scdb
```

2. Load station inventory from IRIS (needs network):

```bash
/root/recovar-seiscomp/bin/python3 -c "
from obspy.clients.fdsn import Client
from obspy import UTCDateTime
inv = Client('IRIS').get_stations(
    network='IU', station='ANMO', location='00', channel='HH?',
    level='response',
    starttime=UTCDateTime('2018-01-01'), endtime=UTCDateTime('2025-01-01'))
inv.write('/tmp/inventory.xml', format='STATIONXML')
print('inventory written')
"
seiscomp --asroot exec import_inv fdsnxml /tmp/inventory.xml /root/seiscomp/etc/inventory/station.xml
seiscomp --asroot exec scinv sync --filebase /root/seiscomp/etc/inventory/ \
    -d mysql://sysop:sysop@localhost/seiscomp
```

3. Configure scautopick bindings:

```bash
cat > /root/seiscomp/etc/key/station_IU_ANMO << 'EOF'
global:default
scautopick:default
EOF
mkdir -p /root/seiscomp/etc/key/scautopick
cat > /root/seiscomp/etc/key/scautopick/profile_default << 'EOF'
detecStream    = HH
detecLocid     = 00
detecFilter    = "RMHP(10)>>ITAPER(30)>>BW(4,1,20)>>STALTA(0.5,10)"
trigOn         = 3.0
trigOff        = 1.5
timeCorr       = -0.8
picker         = AIC
useSquaredness = true
EOF
seiscomp --asroot update-config scautopick
```

4. Download the test archive from IRIS (needs network):

```bash
/root/recovar-seiscomp/bin/python3 /root/recovar/seiscomp_integration/create_test_archive.py --output /root/seiscomp_test/sds
```

5. Start the pick filter in the background and wait for it to come up. Stop any
   previous instance first. two clients with the same name can't connect to the
   messaging system at once (see Troubleshooting):

```bash
seiscomp --asroot stop recovar_pick_filter 2>/dev/null   # clear a managed instance, if any
pkill -f recovar_pick_filter 2>/dev/null                 # clear a leftover background run

seiscomp --asroot exec recovar_pick_filter \
    --model-path /root/recovar/models/representation_cross_covariances.h5 \
    --record-stream "sdsarchive:///root/seiscomp_test/sds" \
    > /root/.seiscomp/log/recovar_pick_filter.log 2>&1 &
RECOVAR_PID=$!
until grep -q "pick_filter: ready" /root/.seiscomp/log/recovar_pick_filter.log; do sleep 1; done
echo "ready"
```

6. Export the archive to flat MiniSEED:

```bash
seiscomp --asroot exec scart -dsE \
    -t "2018-01-01T00:00:00~2024-12-31T23:59:59" \
    -n "IU.ANMO.00" \
    /root/seiscomp_test/sds > /tmp/playback.mseed
ls -lh /tmp/playback.mseed
```

7. Run the playback:

```bash
seiscomp --asroot exec scautopick \
    --playback \
    -I "file:///tmp/playback.mseed" \
    -d mysql://sysop:sysop@localhost/seiscomp
sleep 20   # let recovar drain
```

8. Stop the pick filter:

```bash
kill $RECOVAR_PID
```

9. Query the scored picks from the SeisComp database and plot the scores:

```bash
/root/recovar-seiscomp/bin/python3 /root/recovar/seiscomp_integration/query_scored_picks.py --sds /root/seiscomp_test/sds --plot --plot-output /tmp/scored_picks.png
```

## Get the figure over SSH

`query_scored_picks.py` can save a waveform/score figure to a PNG (`--plot`
uses a headless backend, so no display is needed). Generate it inside the
container, then copy it to the host with `scp`.

On the host:

```bash
scp -P 2222 root@localhost:/tmp/scored_picks.png .   # password: recovar
```

## Notes

- The repo mount is read-only, write to `/tmp`, `/root/seiscomp_test/sds`, or the
  SeisComP trees, not `/root/recovar`.

## Troubleshooting

- **`... name not unique`**: a `recovar_pick_filter` client is already connected to
  the messaging system (e.g. you re-ran step 5 without stopping the previous run).
  SeisComP rejects a second client with the same name. Clear it and start again:

  ```bash
  seiscomp --asroot stop recovar_pick_filter 2>/dev/null
  pkill -f recovar_pick_filter 2>/dev/null
  ```
