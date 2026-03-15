SHELL := /bin/bash
SURF_VOLUME_ROOT ?= /data/mlflow_test_storage
export SURF_VOLUME_ROOT
export DATA_ROOT ?= $(SURF_VOLUME_ROOT)/mlflow_data
export DOCKER_DATA_ROOT ?= $(SURF_VOLUME_ROOT)/docker
export CONTAINERD_ROOT ?= $(SURF_VOLUME_ROOT)/containerd
export TMPDIR ?= $(SURF_VOLUME_ROOT)/tmp
export MLFLOW_HOST_PORT ?= 80

.PHONY: help vm-bootstrap docker-install init-dirs build up down logs ps clean

help:
	@echo "Available targets:"
	@echo "  make vm-bootstrap   - Install Docker and initialize MLflow directories"
	@echo "  make docker-install - Install Docker Engine + Compose plugin on Ubuntu 22.04"
	@echo "  make init-dirs      - Create local MLflow backend/artifact directories"
	@echo "  make build          - Build Docker image"
	@echo "  make up             - Start MLflow service with Docker Compose"
	@echo "  make down           - Stop MLflow service"
	@echo "  make logs           - Stream MLflow logs"
	@echo "  make ps             - Show MLflow container status"
	@echo "  make clean          - Remove local env/cache/data"
	@echo ""
	@echo "Configurable variables:"
	@echo "  SURF_VOLUME_ROOT    - Mounted SURF volume used for all large writable data"
	@echo "  DATA_ROOT           - Host directory for MLflow DB and artifacts"
	@echo "  DOCKER_DATA_ROOT    - Docker daemon data-root on the SURF volume"
	@echo "  CONTAINERD_ROOT     - containerd persistent storage on the SURF volume"
	@echo "  TMPDIR              - Temporary directory on the SURF volume"
	@echo "  MLFLOW_HOST_PORT    - Host port exposed by Docker Compose (default: 80)"

vm-bootstrap: docker-install init-dirs

docker-install:
	@if [ "$$(id -u)" -ne 0 ]; then \
		sudo env \
			SURF_VOLUME_ROOT="$(SURF_VOLUME_ROOT)" \
			DATA_ROOT="$(DATA_ROOT)" \
			DOCKER_DATA_ROOT="$(DOCKER_DATA_ROOT)" \
			CONTAINERD_ROOT="$(CONTAINERD_ROOT)" \
			TMPDIR="$(TMPDIR)" \
			bash scripts/install_docker_ubuntu2204.sh; \
	else \
		env \
			SURF_VOLUME_ROOT="$(SURF_VOLUME_ROOT)" \
			DATA_ROOT="$(DATA_ROOT)" \
			DOCKER_DATA_ROOT="$(DOCKER_DATA_ROOT)" \
			CONTAINERD_ROOT="$(CONTAINERD_ROOT)" \
			TMPDIR="$(TMPDIR)" \
			bash scripts/install_docker_ubuntu2204.sh; \
	fi

init-dirs:
	@mkdir -p \
		$(DATA_ROOT)/mlruns \
		$(DATA_ROOT)/mlartifacts \
		$(DOCKER_DATA_ROOT) \
		$(CONTAINERD_ROOT) \
		$(TMPDIR)

build:
	@docker compose build

up: init-dirs
	@docker compose up -d --build

down:
	@docker compose down

logs:
	@docker compose logs -f mlflow

ps:
	@docker compose ps

clean:
	@rm -rf .venv .pytest_cache .mypy_cache
