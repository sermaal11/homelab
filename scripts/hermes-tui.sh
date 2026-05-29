#!/usr/bin/env bash
set -euo pipefail

if [ -t 0 ]; then
  exec docker exec -it hermes /opt/hermes/.venv/bin/python /opt/hermes/hermes "$@"
fi

exec docker exec -i hermes /opt/hermes/.venv/bin/python /opt/hermes/hermes "$@"
