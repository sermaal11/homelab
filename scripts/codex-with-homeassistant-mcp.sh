#!/usr/bin/env sh
set -eu

ENV_FILE="${HOMEASSISTANT_MCP_ENV_FILE:-/data/homelab/homeassistant/mcp.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

if [ -z "${HOMEASSISTANT_TOKEN:-}" ]; then
  echo "HOMEASSISTANT_TOKEN is required. Set it in $ENV_FILE." >&2
  exit 1
fi

export HOMEASSISTANT_TOKEN

exec codex "$@"
