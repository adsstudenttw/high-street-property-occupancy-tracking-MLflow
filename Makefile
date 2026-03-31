SHELL := /bin/bash
SURF_VOLUME_ROOT ?= /data/mlflow_test_storage
export SURF_VOLUME_ROOT
export DATA_ROOT ?= $(SURF_VOLUME_ROOT)/mlflow_data
export DOCKER_DATA_ROOT ?= $(SURF_VOLUME_ROOT)/docker
export CONTAINERD_ROOT ?= $(SURF_VOLUME_ROOT)/containerd
export TMPDIR ?= $(SURF_VOLUME_ROOT)/tmp
export MLFLOW_HOST_PORT ?= 80
export MLFLOW_GC_TRACKING_URI ?= http://127.0.0.1:5000

.PHONY: help vm-bootstrap docker-install docker-storage-configure sync-env init-dirs build up down logs logs-once ps storage-usage mlflow-gc clean

help:
	@echo "Available targets:"
	@echo "  make vm-bootstrap   - Install Docker and initialize MLflow directories"
	@echo "  make docker-install - Install Docker Engine + Compose plugin on Ubuntu 22.04"
	@echo "  make docker-storage-configure - Repoint Docker/containerd storage to SURF volume"
	@echo "  make sync-env       - Write the current DATA_ROOT to .env for docker compose"
	@echo "  make init-dirs      - Create local MLflow backend/artifact directories"
	@echo "  make build          - Build Docker image"
	@echo "  make up             - Start MLflow service with Docker Compose"
	@echo "  make down           - Stop MLflow service"
	@echo "  make logs           - Stream MLflow logs"
	@echo "  make logs-once      - Show recent MLflow logs without following"
	@echo "  make ps             - Show MLflow container status"
	@echo "  make storage-usage  - Show SURF-volume usage for MLflow and Docker paths"
	@echo "  make mlflow-gc      - Permanently delete MLflow runs/experiments in deleted state"
	@echo "  make clean          - Remove local env/cache/data"
	@echo ""
	@echo "Configurable variables:"
	@echo "  SURF_VOLUME_ROOT    - Mounted SURF volume used for all large writable data"
	@echo "  DATA_ROOT           - Host directory for MLflow DB and artifacts"
	@echo "  DOCKER_DATA_ROOT    - Docker daemon data-root on the SURF volume"
	@echo "  CONTAINERD_ROOT     - containerd persistent storage on the SURF volume"
	@echo "  TMPDIR              - Temporary directory on the SURF volume"
	@echo "  MLFLOW_HOST_PORT    - Host port exposed by Docker Compose (default: 80)"
	@echo "  MLFLOW_GC_TRACKING_URI - Tracking URI used by 'make mlflow-gc' inside the container"
	@echo "  GC_OLDER_THAN       - Optional age filter for 'make mlflow-gc' (for example: 7d)"
	@echo "  GC_RUN_IDS          - Optional comma-separated run ids for 'make mlflow-gc'"
	@echo "  GC_EXPERIMENT_IDS   - Optional comma-separated experiment ids for 'make mlflow-gc'"

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

docker-storage-configure:
	@if [ "$$(id -u)" -ne 0 ]; then \
		sudo env \
			SURF_VOLUME_ROOT="$(SURF_VOLUME_ROOT)" \
			DATA_ROOT="$(DATA_ROOT)" \
			DOCKER_DATA_ROOT="$(DOCKER_DATA_ROOT)" \
			CONTAINERD_ROOT="$(CONTAINERD_ROOT)" \
			TMPDIR="$(TMPDIR)" \
			bash scripts/configure_docker_storage.sh; \
	else \
		env \
			SURF_VOLUME_ROOT="$(SURF_VOLUME_ROOT)" \
			DATA_ROOT="$(DATA_ROOT)" \
			DOCKER_DATA_ROOT="$(DOCKER_DATA_ROOT)" \
			CONTAINERD_ROOT="$(CONTAINERD_ROOT)" \
			TMPDIR="$(TMPDIR)" \
			bash scripts/configure_docker_storage.sh; \
	fi

sync-env:
	@printf 'DATA_ROOT=%s\n' "$(DATA_ROOT)" > .env

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

logs-once:
	@docker compose logs --tail=200 mlflow

ps:
	@docker compose ps

storage-usage:
	@for path in \
		"$(SURF_VOLUME_ROOT)" \
		"$(DATA_ROOT)" \
		"$(DATA_ROOT)/mlruns" \
		"$(DATA_ROOT)/mlartifacts" \
		"$(DOCKER_DATA_ROOT)" \
		"$(CONTAINERD_ROOT)" \
		"$(TMPDIR)"; do \
		if [ -e "$$path" ]; then \
			du -sh "$$path"; \
		else \
			echo "missing $$path"; \
		fi; \
	done

mlflow-gc:
	@args=(--backend-store-uri sqlite:///mlruns/mlflow.db --artifacts-destination /app/mlartifacts); \
	if [ -n "$(GC_OLDER_THAN)" ]; then args+=(--older-than "$(GC_OLDER_THAN)"); fi; \
	if [ -n "$(GC_RUN_IDS)" ]; then args+=(--run-ids "$(GC_RUN_IDS)"); fi; \
	if [ -n "$(GC_EXPERIMENT_IDS)" ]; then args+=(--experiment-ids "$(GC_EXPERIMENT_IDS)"); fi; \
	echo "Running MLflow garbage collection with tracking URI $(MLFLOW_GC_TRACKING_URI)"; \
	MLFLOW_TRACKING_URI="$(MLFLOW_GC_TRACKING_URI)" docker compose exec -T mlflow uv run mlflow gc "$${args[@]}"

clean:
	@rm -rf .venv .pytest_cache .mypy_cache
