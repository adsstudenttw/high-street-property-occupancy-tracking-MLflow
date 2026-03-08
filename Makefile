SHELL := /bin/bash
UV_BIN := $(shell command -v uv 2>/dev/null || echo "$(HOME)/.local/bin/uv")
DATA_ROOT := $(HOME)/data/mlflow_test_storage

.PHONY: help vm-bootstrap docker-install uv-install sync init-dirs build up down logs ps local clean

help:
	@echo "Available targets:"
	@echo "  make vm-bootstrap   - Install Docker and initialize MLflow directories"
	@echo "  make docker-install - Install Docker Engine + Compose plugin on Ubuntu 22.04"
	@echo "  make uv-install     - Install uv (optional, for local non-Docker runs)"
	@echo "  make sync           - Sync Python dependencies using uv (optional)"
	@echo "  make init-dirs      - Create local MLflow backend/artifact directories"
	@echo "  make build          - Build Docker image"
	@echo "  make up             - Start MLflow service with Docker Compose"
	@echo "  make down           - Stop MLflow service"
	@echo "  make logs           - Stream MLflow logs"
	@echo "  make ps             - Show MLflow container status"
	@echo "  make local          - Run MLflow locally (without Docker)"
	@echo "  make clean          - Remove local env/cache/data"

vm-bootstrap: docker-install init-dirs

docker-install:
	@if [ "$$(id -u)" -ne 0 ]; then \
		sudo bash scripts/install_docker_ubuntu2204.sh; \
	else \
		bash scripts/install_docker_ubuntu2204.sh; \
	fi

uv-install:
	@command -v uv >/dev/null 2>&1 || curl -LsSf https://astral.sh/uv/install.sh | sh
	@echo "uv installation checked."

sync:
	@$(UV_BIN) sync

init-dirs:
	@mkdir -p $(DATA_ROOT)/mlruns $(DATA_ROOT)/mlartifacts

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

local: init-dirs
	@$(UV_BIN) run mlflow server \
		--host 0.0.0.0 \
		--port 5000 \
		--backend-store-uri sqlite:///$(DATA_ROOT)/mlruns/mlflow.db \
		--default-artifact-root $(DATA_ROOT)/mlartifacts

clean:
	@rm -rf .venv .pytest_cache .mypy_cache
