#!/usr/bin/env bash
set -euo pipefail

root_ca="${1:?usage: prepare-ca-bundle.sh ROOT_CA_PEM OUTPUT_BUNDLE}"
output_bundle="${2:?usage: prepare-ca-bundle.sh ROOT_CA_PEM OUTPUT_BUNDLE}"
system_bundle="/etc/ssl/certs/ca-certificates.crt"

if [[ ! -f "$root_ca" ]]; then
  echo "Root CA PEM not found: $root_ca" >&2
  exit 1
fi
if [[ ! -r "$system_bundle" ]]; then
  echo "System CA bundle not readable: $system_bundle" >&2
  exit 1
fi

mkdir -p "$(dirname "$output_bundle")"
{
  cat "$system_bundle"
  printf '\n'
  cat "$root_ca"
  printf '\n'
} > "$output_bundle"
chmod 0644 "$output_bundle"
echo "Prepared combined CA bundle: $output_bundle"
