.PHONY: up up-socket down restart logs build clean setup smoke

up: setup
	docker compose up -d

up-socket: setup
	@test -n "$(DOCKER_GID)" || grep -qE '^DOCKER_GID=[0-9]+$$' .env || \
		(echo "Set DOCKER_GID in .env: stat -c '%g' /var/run/docker.sock"; exit 1)
	docker compose -f docker-compose.yml -f docker-compose.socket.yml up -d

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
