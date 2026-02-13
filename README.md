# high-street-property-occupancy-tracking-MLflow

MLflow environment setup for a SURF Research Cloud VM (Ubuntu 22.04) using Docker, with Python dependencies managed by `uv` in the container image.

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
http://<your-vm-ip>:5000
```

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

## Local (non-Docker) run (optional)

If you also want to run MLflow directly on the VM host for debugging:

```bash
make uv-install
make sync
make local
```
