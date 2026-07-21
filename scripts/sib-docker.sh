#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
sib_dir=${SIB_DIR:-"$root/.xib-components/sib"}
sib_repo=${SIB_REPOSITORY:-https://github.com/iareanthony/sib.git}
sib_commit=${SIB_COMMIT:-b41a981999e915b1a6900cbb70619716bf94a720}
action=${1:-install}

prepare() {
  if [[ ! -d "$sib_dir/.git" ]]; then
    mkdir -p "$(dirname "$sib_dir")"
    git clone "$sib_repo" "$sib_dir"
  fi
  git -C "$sib_dir" fetch origin
  git -C "$sib_dir" checkout --detach "$sib_commit"
  [[ -f "$sib_dir/.env" ]] || cp "$sib_dir/.env.example" "$sib_dir/.env"
  # Avoid XIB's Grafana port and reserve stable SIB endpoints.
  sed -i -E 's/^GRAFANA_PORT=.*/GRAFANA_PORT=3400/' "$sib_dir/.env"
  sed -i -E 's/^VICTORIAMETRICS_PORT=.*/VICTORIAMETRICS_PORT=8429/' "$sib_dir/.env"
  sed -i -E 's/^VICTORIALOGS_PORT=.*/VICTORIALOGS_PORT=9428/' "$sib_dir/.env"
  sed -i -E 's/^SIDEKICK_PORT=.*/SIDEKICK_PORT=2801/' "$sib_dir/.env"
}

case "$action" in
  install)
    prepare
    make -C "$sib_dir" network install-storage-vm install-alerting install-detection
    SIB_DIR="$sib_dir" docker compose -f "$root/docker-compose.yml" -f "$root/docker-compose.sib.yml" up -d grafana
    ;;
  start)
    make -C "$sib_dir" start-storage-vm start-alerting start-detection
    SIB_DIR="$sib_dir" docker compose -f "$root/docker-compose.yml" -f "$root/docker-compose.sib.yml" up -d grafana
    ;;
  stop)    make -C "$sib_dir" stop ;;
  health)  make -C "$sib_dir" health ;;
  logs)    make -C "$sib_dir" logs ;;
  *) echo "Usage: $0 {install|start|stop|health|logs}" >&2; exit 2 ;;
esac
