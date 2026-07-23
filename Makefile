.PHONY: up up-ca up-socket down restart logs build clean setup pull-submodules smoke sib-install sib-start sib-stop sib-health sib-logs

up: setup
	docker compose up -d

up-ca: setup
	@root_ca="$(XIB_ROOT_CA)"; \
		if [ -z "$$root_ca" ] && [ -f .env ]; then \
			root_ca="$$(sed -n 's/^XIB_ROOT_CA=//p' .env | tail -n 1)"; \
		fi; \
		test -n "$$root_ca" || \
			(echo "Set XIB_ROOT_CA to a PEM file containing the environment root CA(s)."; exit 1); \
		bash scripts/prepare-ca-bundle.sh "$$root_ca" ".xib/trust/ca-bundle.crt"
	XIB_CA_BUNDLE="$(CURDIR)/.xib/trust/ca-bundle.crt" \
		docker compose -f docker-compose.yml -f docker-compose.ca.yml up -d

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
	@if [ ! -f sib/detection/config/rules/falco_rules.yaml ]; then \
		echo "Initializing pinned SIB package..."; \
		git submodule update --init --recursive --force sib; \
	fi
	@if [ ! -f .env ]; then \
		echo "Creating .env from .env.example..."; \
		cp .env.example .env; \
	fi
	@echo "XIB Compose environment ready."

pull-submodules:
	git submodule update --init --recursive

smoke: ## Run local runtime smoke checks against the XIB stack
	@bash scripts/smoke-test.sh

sib-install: ## Install pinned Docker SIB/Falco runtime stack (privileged)
	@bash scripts/sib-docker.sh install

sib-start sib-stop sib-health sib-logs:
	@bash scripts/sib-docker.sh $(@:sib-%=%)

clean:
	docker compose down -v
	docker rmi xib-grafana 2>/dev/null || true
