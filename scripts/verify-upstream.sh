#!/usr/bin/env bash

set -euo pipefail

docker_version="$(awk -F= '$1 == "ARG ACME_DNS_VERSION" { print $2; exit }' Dockerfile)"
docker_commit="$(awk -F= '$1 == "ARG ACME_DNS_COMMIT" { print $2; exit }' Dockerfile)"
chart_version="$(awk '$1 == "appVersion:" { gsub(/\"/, "", $2); print $2; exit }' charts/acme-dns/Chart.yaml)"

if [[ "${docker_version#v}" != "$chart_version" ]]; then
  echo "Dockerfile packages $docker_version but Chart.yaml declares $chart_version" >&2
  exit 1
fi

remote_commit="$(
  git ls-remote https://github.com/acme-dns/acme-dns.git "refs/tags/${docker_version}" \
    | awk 'NR == 1 { print $1 }'
)"

if [[ -z "$remote_commit" ]]; then
  echo "upstream tag $docker_version was not found" >&2
  exit 1
fi

if [[ "$docker_commit" != "$remote_commit" ]]; then
  echo "Dockerfile commit $docker_commit does not match $docker_version ($remote_commit)" >&2
  exit 1
fi
