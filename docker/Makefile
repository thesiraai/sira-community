# SIRA Community Docker Management Makefile

.PHONY: help build up down restart logs shell migrate seed backup clean deploy-local deploy-dev deploy-test deploy-stage deploy-prod validate

ENV ?= prod
COMPOSE_FILE = docker/docker-compose.sira-community.app.yml

help: ## Show this help message
	@echo 'Usage: make [target] [ENV=environment]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ''
	@echo 'Available environments: local, dev, test, stage, prod'
	@echo 'Example: make deploy-dev ENV=dev'

build: ## Build Docker images
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) build

up: ## Start all services
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) up -d

down: ## Stop all services
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) down

restart: ## Restart all services
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) restart

logs: ## Show application logs
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) logs -f app

logs-all: ## Show all logs
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) logs -f

shell: ## Access application container shell
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) exec app bash

db-shell: ## Access PostgreSQL shell (via infrastructure)
	@echo "Note: PostgreSQL is managed by infrastructure. Use infrastructure tools to access."

redis-shell: ## Access Redis shell (via infrastructure)
	@echo "Note: Redis is managed by infrastructure. Use infrastructure tools to access."

migrate: ## Run database migrations
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) exec app bundle exec rake db:migrate

seed: ## Seed database
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) exec app bundle exec rake db:seed_fu

backup: ## Backup database (via infrastructure)
	@echo "Note: Database backups should be managed by infrastructure team."

clean: ## Remove containers and volumes (WARNING: deletes data)
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) down -v

ps: ## Show running containers
	docker compose -f $(COMPOSE_FILE) --env-file docker/env.community.app.$(ENV) ps

health: ## Check service health
	@echo "Checking application health..."
	@curl -f http://localhost/health || echo "Application not healthy"
	@echo "Note: Database and Redis health checks are managed by infrastructure."

secret: ## Generate secret key
	@ruby -e "require 'securerandom'; puts SecureRandom.hex(64)"

validate: ## Validate environment file
	@bash docker/scripts/validate-env.sh .env

generate-env: ## Generate environment file (usage: make generate-env ENV=prod)
	@bash docker/scripts/generate-env.sh $(ENV)

deploy-local: ## Deploy to local environment
	@bash docker/scripts/deploy.sh local

deploy-dev: ## Deploy to development server
	@bash docker/scripts/deploy.sh dev

deploy-test: ## Deploy to test server
	@bash docker/scripts/deploy.sh test

deploy-stage: ## Deploy to staging server
	@bash docker/scripts/deploy.sh stage

deploy-prod: ## Deploy to production server
	@bash docker/scripts/deploy.sh prod

setup-local: ## Setup local environment
	@cp docker/env.community.app.local .env
	@echo "✅ Local environment file created"
	@echo "⚠️  Review .env and update if needed"

setup-dev: ## Setup development environment
	@cp docker/env.community.app.dev .env
	@echo "✅ Development environment file created"
	@echo "⚠️  IMPORTANT: Update .env with actual credentials before deploying"

setup-test: ## Setup test environment
	@cp docker/env.community.app.test .env
	@echo "✅ Test environment file created"
	@echo "⚠️  IMPORTANT: Update .env with actual credentials before deploying"

setup-stage: ## Setup staging environment
	@cp docker/env.community.app.stage .env
	@echo "✅ Staging environment file created"
	@echo "⚠️  IMPORTANT: Update .env with actual credentials before deploying"

setup-prod: ## Setup production environment
	@cp docker/env.community.app.prod .env
	@echo "✅ Production environment file created"
	@echo "⚠️  CRITICAL: Update .env with actual production credentials before deploying"
	@echo "⚠️  Generate secret key: make secret"
	@echo "⚠️  Validate configuration: make validate"
