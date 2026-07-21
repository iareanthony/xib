#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
port="${XIB_GRAFANA_PORT:-3000}"; user="${XIB_GRAFANA_USER:-admin}"; password="${XIB_GRAFANA_PASSWORD:-changeme}"
if [[ -f .env ]]; then
  value=$(grep -E '^XIB_GRAFANA_PORT=' .env | tail -1 | cut -d= -f2-); port="${value:-$port}"
  value=$(grep -E '^XIB_GRAFANA_USER=' .env | tail -1 | cut -d= -f2-); user="${value:-$user}"
  value=$(grep -E '^XIB_GRAFANA_PASSWORD=' .env | tail -1 | cut -d= -f2-); password="${value:-$password}"
fi
docker compose config --quiet
failed=$(docker compose ps --status restarting --status exited --services | grep -v '^initialize-volumes$' || true)
if [[ -n "$failed" ]]; then echo "FAIL unhealthy services: $failed"; exit 1; fi
base="http://127.0.0.1:${port}"
ready=false
for attempt in $(seq 1 30); do
  if curl -fsS --max-time 3 "${base}/api/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done
if [[ "$ready" != true ]]; then
  echo "FAIL Grafana did not become ready at ${base} within 60 seconds"
  docker compose logs --tail 50 grafana
  exit 1
fi
dashboards=$(curl -fsS -u "${user}:${password}" "${base}/api/search?type=dash-db" | python3 -c 'import json,sys; print(len(json.load(sys.stdin)))')
[[ "$dashboards" -ge 6 ]] || { echo "FAIL dashboards=$dashboards expected>=6"; exit 1; }
curl -fsS -u "${user}:${password}" "${base}/api/datasources/proxy/uid/vib-vm/api/v1/query?query=vib_vulnerabilities_total" | grep -q '"status":"success"'
echo "XIB Compose smoke test passed: dashboards=$dashboards"
