#!/usr/bin/env bash
set -euo pipefail

cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
docker compose ps -a
echo
echo 'Artifactory health:'
docker compose exec -T artifactory curl --fail --silent --show-error --max-time 10 \
  http://localhost:8082/router/api/v1/system/health
echo
echo 'Artifactory UI: http://localhost:8092/ui/'
