.PHONY: up down restart logs build clean setup smoke

up: setup
	docker compose up -d

down:
	docker compose down

restart:
	docker compose restart

build:
	docker compose build --no-cache

logs:
	docker compose logs -f

setup:
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
	fi
	@echo "XIB Compose environment ready."

smoke: ## Run local runtime smoke checks against the XIB stack
	@bash scripts/smoke-test.sh

clean:
	docker compose down -v
	docker rmi xib-grafana 2>/dev/null || true
