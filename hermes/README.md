# Hermes Agent

Hermes is the Telegram-first personal butler for this homelab. It runs as a normal Portainer/GitHub stack, keeps all agent state under `/data/homelab/hermes/data`, and is exposed only on LAN/Tailscale. The local Hermes image extends `nousresearch/hermes-agent:latest` with `honcho-ai` so the bundled Honcho memory plugin works after redeploys.

## Access

- Gateway/API: `http://homelab:8642`
- Dashboard: `http://homelab:9119`
- Telegram: polling mode through `TELEGRAM_BOT_TOKEN`

Current runtime model setup: OpenAI Codex `gpt-5.5` is the primary model and Groq `llama-3.3-70b-versatile` is the fallback. Telegram should keep lightweight toolsets only (`todo`, `memory`, `homeassistant`, `messaging`) so normal messages do not trigger oversized provider payloads.

Honcho memory runs as a sidecar group inside this same Compose stack. The Honcho API binds to `127.0.0.1:8000` by default, while Hermes can reach it inside the stack network as `http://honcho-api:8000`.

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

## Honcho Memory

Honcho is optional and runs inside the Hermes stack as:

- `honcho-api`
- `honcho-deriver`
- `honcho-db`
- `honcho-redis`

The stack builds Honcho from the upstream Git repository because upstream documents that there is no pre-built Docker Hub image. Add a real `GROQ_API_KEY` and a strong `HONCHO_POSTGRES_PASSWORD` to `hermes/.env` before deploying.

Initial no-paid-embeddings mode:

```bash
HONCHO_OPENAI_BASE_URL=https://api.groq.com/openai/v1
HONCHO_GROQ_MODEL=llama-3.3-70b-versatile
HONCHO_EMBED_MESSAGES=false
```

This lets Honcho use Groq for LLM work without requiring an embedding provider. Semantic vector search can be enabled later by adding local embeddings through Ollama/LiteLLM or a low-cost embedding provider, then setting `HONCHO_EMBED_MESSAGES=true`.

After Honcho is healthy, configure Hermes external memory from inside the Hermes container:

```bash
docker exec -it hermes sh -lc 'cd /opt/hermes && . .venv/bin/activate && ./hermes memory setup'
```

Use self-hosted Honcho URL:

```text
http://honcho-api:8000
```

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
