#!/usr/bin/env sh
set -eu

ENV_FILE="${GRAFANA_MCP_ENV_FILE:-/data/homelab/grafana/mcp-grafana.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

if [ -z "${GRAFANA_SERVICE_ACCOUNT_TOKEN:-}" ]; then
  echo "GRAFANA_SERVICE_ACCOUNT_TOKEN is required. Set it in $ENV_FILE." >&2
  exit 1
fi

GRAFANA_URL="${GRAFANA_URL:-http://grafana:3000}"
GRAFANA_MCP_IMAGE="${GRAFANA_MCP_IMAGE:-grafana/mcp-grafana:latest}"
GRAFANA_MCP_NETWORK="${GRAFANA_MCP_NETWORK:-server-monitoring}"

exec docker run --rm -i \
  --network "$GRAFANA_MCP_NETWORK" \
  -e "GRAFANA_URL=$GRAFANA_URL" \
  -e "GRAFANA_SERVICE_ACCOUNT_TOKEN=$GRAFANA_SERVICE_ACCOUNT_TOKEN" \
  "$GRAFANA_MCP_IMAGE" \
  -t stdio
