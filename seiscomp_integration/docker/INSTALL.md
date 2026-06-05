# RECOVAR SeisComP: Docker installation

Build and start the Docker container that runs SeisComP 7.x + the RECOVAR
`recovar_pick_filter` daemon. Once it is up, see the
[Docker demo](DEMO.md) to run the pick-filter pipeline.

Files here:

- `Dockerfile`: Ubuntu 22.04 + SeisComP + a Python venv with TensorFlow 2.14.
- `entrypoint.sh`: sets up (DB, config, daemon install, verify) then idles.

## Download SeisComP (required before building)

Download a SeisComP 7.x release for Ubuntu 22.04 (e.g.
`seiscomp-7.3.0-ubuntu22.04-x86_64.tar.gz`) from
[seiscomp.de/downloader](https://www.seiscomp.de/downloader/)
and place it in this folder:

```bash
seiscomp_integration/docker/seiscomp-7.*-ubuntu22.04-x86_64.tar.gz
```

The Dockerfile matches `seiscomp-7.*-ubuntu22.04-x86_64.*`, so any 7.x version works,
but keep only **one** such file in the folder (the build fails if it matches several).

## Build

From the repo root:

```bash
docker build -t recovar-seiscomp seiscomp_integration/docker
```

## Start

The repo is mounted read-only at `/root/recovar`, so the container uses your local
code without a rebuild.

```bash
docker run -d --name recovar-seiscomp  -p 2222:22  -v "$PWD":/root/recovar:ro  recovar-seiscomp
```

Setup runs MariaDB, creates the `seiscomp` database and `sysop` user, writes
`global.cfg` / `kernel.cfg`, installs the `recovar_pick_filter` daemon and verifies
imports, then leaves the container idle. Watch it with:

```bash
docker logs -f recovar-seiscomp      # done when it prints "Setup complete"
```

## Shell in

```bash
docker exec -it recovar-seiscomp bash
```
or over SSH (the container runs sshd, port 22 published on host port 2222):

```bash
ssh -p 2222 root@localhost        # password: recovar
```

The environment (`SEISCOMP_ROOT`, `PATH`, `PYTHONPATH`, …) is already set and the
venv lives at `/root/recovar-seiscomp`.

The demo steps use these shortcuts:

```bash
PY=/root/recovar-seiscomp/bin/python3
SDS=/root/seiscomp_test/sds
SC="seiscomp --asroot"
```

## Stop / clean up

```bash
docker stop recovar-seiscomp      # stop, keep state
docker start recovar-seiscomp     # resume
docker rm -f recovar-seiscomp     # remove
```
