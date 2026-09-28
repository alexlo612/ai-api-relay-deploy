.DEFAULT_GOAL := help
SHELL := /usr/bin/env bash

SERVICE ?=
FILE ?=
COMPOSE := docker compose -f compose.yaml

.PHONY: help init up start stop restart down status health logs backup backup-list restore pull update config newapi-audit

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"; print "AI API Relay deployment commands:"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  %-14s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

init: ## First-time initialization, secret generation, and startup
	@./scripts/bootstrap.sh

config: ## Validate Compose configuration
	@$(COMPOSE) config

up: ## Start or apply the stack
	@$(COMPOSE) up -d --remove-orphans

start: ## Start existing containers
	@$(COMPOSE) start $(SERVICE)

stop: ## Stop containers without removing them
	@$(COMPOSE) stop $(SERVICE)

restart: ## Restart all services or SERVICE=name
	@if [ -n "$(SERVICE)" ]; then $(COMPOSE) restart "$(SERVICE)"; else $(COMPOSE) restart; fi

down: ## Stop and remove containers while preserving all volumes
	@$(COMPOSE) down --remove-orphans

status: ## Show Compose service status
	@$(COMPOSE) ps

health: ## Run full health and diagnostics report
	@./scripts/healthcheck.sh

newapi-audit: ## Review New API access and routed-model pricing without secrets
	@./scripts/newapi-audit.sh

logs: ## Follow logs, optionally SERVICE=name
	@if [ -n "$(SERVICE)" ]; then $(COMPOSE) logs -f --tail=200 "$(SERVICE)"; else $(COMPOSE) logs -f --tail=200; fi

backup: ## Create a timestamped local backup
	@./scripts/backup.sh

backup-list: ## List local backup archives
	@./scripts/backup-list.sh

restore: ## Restore FILE=backups/backup-YYYYMMDD-HHMMSS.tar.gz
	@if [ -z "$(FILE)" ]; then echo "FILE=... is required" >&2; exit 1; fi
	@./scripts/restore.sh --file "$(FILE)"

pull: ## Pull pinned images from .env
	@$(COMPOSE) pull

update: ## Back up, pull pinned images, recreate changed containers, and health-check
	@./scripts/update.sh
