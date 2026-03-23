# high-street-property-occupancy-tracking-MLflow

MLflow 2.18.0 server setup for a SURF Research Cloud VM (Ubuntu 22.04) using Docker, with Python dependencies managed by `uv` in the container image.

The repository is designed to work well with a mounted SURF volume so the large writable data stays off the VM root disk.

## Prerequisites

- Ubuntu 22.04 VM
- `sudo` access
- Internet access to install Docker and `uv`
- A mounted SURF volume for large writable data, for example `/data/mlflow_test_storage`

## Storage layout

By default, the project now uses `/data/mlflow_test_storage` as the root for all large mutable data:

- Repository checkout: clone this repository onto the mounted SURF volume
- MLflow DB and artifacts: `/data/mlflow_test_storage/mlflow_data`
- Docker data-root: `/data/mlflow_test_storage/docker`
- containerd persistent storage: `/data/mlflow_test_storage/containerd`
- Temporary files used by this project: `/data/mlflow_test_storage/tmp`

Override the mount point by setting `SURF_VOLUME_ROOT` before running `make` targets.

Important caveat: the large mutable data is moved to the SURF volume, but Ubuntu package installation still places Docker binaries and system configuration under standard system paths such as `/usr`, `/lib`, and `/etc` on the root disk. This repository minimizes root-disk growth; it cannot relocate the operating system itself.

## Disk usage caveat

Large project data lives on the SURF volume: the repository checkout, Docker data-root, containerd storage, MLflow artifacts/database, and the temporary directory used by this setup.

Small OS-managed files still use the root disk, including Docker binaries and system configuration installed by Ubuntu packages.

## Quickstart

Mount your SURF volume first and clone the repository onto it. Example:

```bash
export SURF_VOLUME_ROOT=/data/mlflow_test_storage
cd "$SURF_VOLUME_ROOT"
git clone <your-repo-url>
cd high-street-property-occupancy-tracking-MLflow
```

Run the full VM bootstrap:

```bash
export SURF_VOLUME_ROOT=/data/mlflow_test_storage
make vm-bootstrap
```

This will:

- Install Docker Engine + Docker Compose plugin
- Configure Docker `data-root` and containerd persistent storage on the SURF volume
- Create MLflow data, cache, and temporary directories on the SURF volume

Start MLflow:

```bash
export SURF_VOLUME_ROOT=/data/mlflow_test_storage
make up
```

MLflow UI will be available at:

```text
http://<your-vm-ip>
```

For this SURF deployment, the tracking URI for remote clients should be:

```text
http://ubuntu2204sudo.property-occupa.src.surf-hosted.nl
```

The Docker deployment publishes container port `5000` on host port `80` by default so it matches the current VM security group. If you prefer another public port, override `MLFLOW_HOST_PORT` and open the same port in the security group.

This repository pins the server to `mlflow==2.18.0` so it is a better fit for machine learning VMs that are also on MLflow `2.x`.

Stop MLflow:

```bash
make down
```

## Migrating To A New SURF Volume

If your current SURF volume is filling up, you can move the repository checkout and all large writable data to a new mounted volume.

The safest sequence is:

1. Attach the new SURF volume to the workspace and mount it on the VM, for example at `/data/mlflow_large`.
2. Stop MLflow:

```bash
cd /path/to/high-street-property-occupancy-tracking-MLflow
make down
```

3. Stop Docker and containerd before copying their storage directories:

```bash
sudo systemctl stop docker.service docker.socket containerd.service
```

4. Copy the entire old SURF volume contents to the new one and keep the old volume untouched until you have verified the new setup:

```bash
export OLD_SURF_VOLUME_ROOT=/data/mlflow_test_storage
export NEW_SURF_VOLUME_ROOT=/data/mlflow_large
sudo rsync -aHAX --info=progress2 "$OLD_SURF_VOLUME_ROOT"/ "$NEW_SURF_VOLUME_ROOT"/
```

5. Start using the repository copy on the new volume:

```bash
cd "$NEW_SURF_VOLUME_ROOT/high-street-property-occupancy-tracking-MLflow"
export SURF_VOLUME_ROOT="$NEW_SURF_VOLUME_ROOT"
export DATA_ROOT="$SURF_VOLUME_ROOT/mlflow_data"
export DOCKER_DATA_ROOT="$SURF_VOLUME_ROOT/docker"
export CONTAINERD_ROOT="$SURF_VOLUME_ROOT/containerd"
export TMPDIR="$SURF_VOLUME_ROOT/tmp"
```

6. Repoint Docker and containerd to the new storage location:

```bash
make docker-storage-configure
```

7. Update `.env` so direct `docker compose` commands also use the new data path:

```bash
make sync-env
```

8. Start MLflow again from the new repository path:

```bash
make up
```

9. Verify that existing experiments, runs, metrics, and artifacts are still visible in the MLflow UI before detaching or deleting the old volume.

Notes:

- If you rely on `.env` for `docker compose` commands outside `make`, update it to the new `DATA_ROOT` value after the move.
- If the repository checkout is not currently stored on the old SURF volume, copy or clone the repository onto the new volume separately.
- The operating system itself still remains on the VM root disk. This migration moves the project checkout, MLflow data, Docker data-root, containerd storage, and temporary files.

## Useful commands

- `make help`: show all targets
- `make docker-install`: install Docker on Ubuntu 22.04
- `make docker-storage-configure`: reconfigure Docker and containerd storage roots
- `make sync-env`: update `.env` with the current `DATA_ROOT`
- `make build`: build the MLflow Docker image
- `make up`: start MLflow in Docker
- `make logs`: tail MLflow logs
- `make down`: stop MLflow
- `make clean`: remove local cache/data directories

## Configuration

These environment variables control where data is written:

- `SURF_VOLUME_ROOT`: mounted SURF volume used for large writable data
- `DATA_ROOT`: MLflow backend store and artifact directory root
- `DOCKER_DATA_ROOT`: Docker daemon storage location
- `CONTAINERD_ROOT`: containerd persistent storage location
- `TMPDIR`: temporary directory used by the installer
- `MLFLOW_HOST_PORT`: public host port exposed by Docker Compose

Example:

```bash
export SURF_VOLUME_ROOT=/data/mlflow_test_storage
export DATA_ROOT=$SURF_VOLUME_ROOT/mlflow_data
export DOCKER_DATA_ROOT=$SURF_VOLUME_ROOT/docker
export CONTAINERD_ROOT=$SURF_VOLUME_ROOT/containerd
export TMPDIR=$SURF_VOLUME_ROOT/tmp
```

## Remote logging from another VM

This project is configured to accept remote tracking traffic from other machines over HTTP and to proxy artifact uploads through the MLflow server.

On the machine learning VM, point MLflow to the tracking server:

```bash
export MLFLOW_TRACKING_URI=http://ubuntu2204sudo.property-occupa.src.surf-hosted.nl
```

Or in Python:

```python
import mlflow

mlflow.set_tracking_uri("http://ubuntu2204sudo.property-occupa.src.surf-hosted.nl")
```

Important: after switching the server to proxied artifact serving, create a new experiment for remote runs. Existing experiments keep their original artifact location and may still point at a local filesystem path that the other VM cannot access.

Because this MLflow 2.18.0 server does not use the newer `--allowed-hosts` middleware from MLflow 3.5+, protection should come from the SURF security group and, if needed, a reverse proxy.

For multiple machine learning VMs, restrict inbound port `80` to the specific VM IPs or to your private SURF subnet instead of leaving it open to `0.0.0.0/0`.

Examples:

```text
80  80  145.38.207.111/32  in  tcp
80  80  <second-ml-vm-ip>/32  in  tcp
80  80  <third-ml-vm-ip>/32   in  tcp
```

Or, if all VMs communicate over the SURF private network:

```text
80  80  10.10.10.0/24  in  tcp
```

If you need encryption or broader access, place MLflow behind HTTPS on port `443` with a reverse proxy such as Nginx.
