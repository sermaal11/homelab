#!/usr/bin/env sh
set -eu

ENV_FILE="${GITHUB_MCP_ENV_FILE:-/data/homelab/github/mcp.env}"

if [ -f "$ENV_FILE" ]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

if [ -z "${GITHUB_PERSONAL_ACCESS_TOKEN:-}" ]; then
  echo "GITHUB_PERSONAL_ACCESS_TOKEN is required. Set it in $ENV_FILE." >&2
  exit 1
fi

GITHUB_MCP_IMAGE="${GITHUB_MCP_IMAGE:-ghcr.io/github/github-mcp-server:latest}"
GITHUB_TOOLSETS="${GITHUB_TOOLSETS:-default,actions}"

exec docker run --rm -i \
  -e "GITHUB_PERSONAL_ACCESS_TOKEN=$GITHUB_PERSONAL_ACCESS_TOKEN" \
  -e "GITHUB_TOOLSETS=$GITHUB_TOOLSETS" \
  -e "GITHUB_HOST=${GITHUB_HOST:-}" \
  "$GITHUB_MCP_IMAGE"
