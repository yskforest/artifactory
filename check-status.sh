#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker compose ps -a
echo
echo 'Artifactory health:'
docker compose exec -T artifactory curl --fail --silent --show-error --max-time 10 \
  http://localhost:8082/router/api/v1/system/health
echo
https_host=$(docker compose exec -T nginx printenv HTTPS_HOSTNAME)
https_port=$(docker compose exec -T nginx printenv HTTPS_PORT)
if [[ "${https_port}" == "443" ]]; then
  echo "Artifactory UI: https://${https_host}/ui/"
else
  echo "Artifactory UI: https://${https_host}:${https_port}/ui/"
fi
