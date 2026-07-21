#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
action=${1:-install}

compose=(docker compose --project-directory "$root" --profile sib)

case "$action" in
  install)
    "${compose[@]}" up -d
    ;;
  start)
    "${compose[@]}" up -d
    ;;
  stop)    "${compose[@]}" stop sib-falco sib-sidekick sib-node-exporter sib-victoriametrics sib-victorialogs ;;
  health)  "${compose[@]}" ps sib-falco sib-sidekick sib-node-exporter sib-victoriametrics sib-victorialogs ;;
  logs)    "${compose[@]}" logs -f sib-falco sib-sidekick sib-victoriametrics sib-victorialogs ;;
  *) echo "Usage: $0 {install|start|stop|health|logs}" >&2; exit 2 ;;
esac
