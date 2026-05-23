# Hermes Agent

Hermes is the Telegram-first personal butler for this homelab. It runs as a normal Portainer/GitHub stack, keeps all agent state under `/data/homelab/hermes/data`, and is exposed only on LAN/Tailscale.

## Access

- Gateway/API: `http://homelab:8642`
- Dashboard: `http://homelab:9119`
- Telegram: polling mode through `TELEGRAM_BOT_TOKEN`

Do not expose Hermes with Tailscale Funnel or public HTTPS until its auth, approval, memory, and tool permissions have been reviewed.

## Preparation

Create the local env file:

```bash
cp hermes/.env.example hermes/.env
```

Generate the gateway API key:

```bash
openssl rand -hex 32
```

Only `HERMES_API_SERVER_KEY` is required for the container to render its compose config. Model provider, Telegram, Home Assistant, and Grafana credentials can be configured inside Hermes after the first boot. If you prefer env-based setup, fill `OPENROUTER_API_KEY` or `OPENAI_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, and `HOMEASSISTANT_TOKEN` before deploying.

Hermes can also be authenticated/configured from its dashboard or CLI after the persistent data directory exists. This is the preferred path when no OpenAI/OpenRouter key is available yet.

## Deployment

Portainer stack settings:

```text
Repository URL: https://github.com/sermaal11/homelab.git
Repository reference: refs/heads/main
Compose path: hermes/docker-compose.yml
```

Local validation:

```bash
docker compose --env-file hermes/.env -f hermes/docker-compose.yml config
docker compose --env-file hermes/.env -f hermes/docker-compose.yml ps
docker compose --env-file hermes/.env -f hermes/docker-compose.yml logs -f
```

## First Boot

After the container creates `/data/homelab/hermes/data`, copy the tracked starter files into the persistent data directory and adjust them from the dashboard if Hermes rewrites its config format:

```bash
cp hermes/bootstrap/SOUL.md hermes/data/SOUL.md
mkdir -p hermes/data/memories
cp hermes/bootstrap/USER.md hermes/data/memories/USER.md
```

Use `hermes/bootstrap/config.mcp.yaml` as the reference for MCP targets:

- Home Assistant MCP: `http://host.docker.internal:8123/api/mcp`
- Prometheus: `http://prometheus:9090`
- Grafana: `http://grafana:3000`

## Security Rules

Hermes v1 must not mount `/var/run/docker.sock` and must not see `/data/homelab` directly. Its writable filesystem scope is its own persistent data/workspace under `/data/homelab/hermes/data`.

Allowed without asking:

- read Home Assistant context
- read homelab health from Prometheus/Grafana when configured
- manage the shopping list
- draft responses or plans

Requires explicit confirmation:

- send external messages
- publish LinkedIn content
- restart or deploy services
- move or delete files
- change Home Assistant automations

Never without an explicit direct instruction:

- touch Passbolt data
- change AdGuard/DNS
- expose services publicly
- use Portainer write operations
- delete bulk data

## Rollback

Stop the stack from Portainer or locally:

```bash
docker compose --env-file hermes/.env -f hermes/docker-compose.yml down
```

The persisted state remains in `/data/homelab/hermes/data`; move it aside only if a clean reinstall is required.
