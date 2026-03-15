# high-street-property-occupancy-tracking-MLflow

MLflow 2.18.0 server setup for a SURF Research Cloud VM (Ubuntu 22.04) using Docker, with Python dependencies managed by `uv` in the container image.

## Prerequisites

- Ubuntu 22.04 VM
- `sudo` access
- Internet access to install Docker and `uv`

## Quickstart

Run the full VM bootstrap:

```bash
make vm-bootstrap
```

This will:

- Install Docker Engine + Docker Compose plugin
- Create local data directories used by MLflow

Start MLflow:

```bash
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

## Useful commands

- `make help`: show all targets
- `make docker-install`: install Docker on Ubuntu 22.04
- `make uv-install`: install `uv` on host (optional for local non-Docker runs)
- `make sync`: install Python dependencies on host with `uv` (optional)
- `make build`: build the MLflow Docker image
- `make up`: start MLflow in Docker
- `make logs`: tail MLflow logs
- `make down`: stop MLflow
- `make clean`: remove local cache/data directories

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

## Local (non-Docker) run (optional)

If you also want to run MLflow directly on the VM host for debugging:

```bash
make uv-install
make sync
make local
```
