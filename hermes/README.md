# Hermes Agent

Hermes is the Telegram-first personal butler for this homelab. It runs as a normal Portainer/GitHub stack, keeps all agent state under `/data/homelab/hermes/data`, and is exposed only on LAN/Tailscale. The local Hermes image stays close to `nousresearch/hermes-agent:latest`, adds `honcho-ai` for self-hosted Honcho memory, and applies a small Codex stream compatibility patch for the OpenAI Codex OAuth backend.

## Access

- Gateway/API: `http://homelab:8642`
- Dashboard: `http://homelab:9119`
- Telegram: polling mode through `TELEGRAM_BOT_TOKEN`

Target runtime model setup after the clean reinstall: OpenAI Codex OAuth with `gpt-5.5` as the primary model. No fallback provider is configured while Codex is being validated.

Honcho memory runs as a sidecar group inside this same Compose stack. The Honcho API binds to `127.0.0.1:8000` by default, while Hermes reaches it inside the stack network as `http://honcho-api:8000`.

No Codex MCP servers are preconfigured inside Hermes. Hermes gets only network reachability and URL hints so it can develop its own skills/tools:

- Home Assistant: `http://host.docker.internal:8123`
- n8n: `http://n8n:5678`
- Nextcloud: `http://nextcloud`
- Prometheus: `http://prometheus:9090`
- Grafana: `http://grafana:3000`

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

Only `HERMES_API_SERVER_KEY` is required for the container to render its compose config. Model provider and Telegram can be configured inside Hermes after the first boot. If you prefer env-based setup, fill `OPENROUTER_API_KEY` or `OPENAI_API_KEY`, `GROQ_API_KEY`, `TELEGRAM_BOT_TOKEN`, and `TELEGRAM_ALLOWED_USERS` before deploying.

Hermes can also be authenticated/configured from its dashboard or CLI after the persistent data directory exists. This is the preferred path when no OpenAI/OpenRouter key is available yet.

## Honcho Memory

Honcho is optional and runs inside the Hermes stack as:

- `honcho-api`
- `honcho-deriver`
- `honcho-db`
- `honcho-redis`
- `honcho-ollama`

The stack builds Honcho from the upstream Git repository because upstream documents that there is no pre-built Docker Hub image. Add a real `GROQ_API_KEY` and a strong `HONCHO_POSTGRES_PASSWORD` to `hermes/.env` before deploying.

Initial no-paid-embeddings mode:

```bash
HONCHO_OPENAI_BASE_URL=https://api.groq.com/openai/v1
HONCHO_GROQ_MODEL=meta-llama/llama-4-scout-17b-16e-instruct
HONCHO_EMBED_MESSAGES=false
HONCHO_EMBEDDING_MODEL=nomic-embed-text
HONCHO_EMBEDDING_BASE_URL=http://honcho-ollama:11434/v1
HONCHO_EMBEDDING_VECTOR_DIMENSIONS=768
```

This lets Honcho use Groq for structured LLM work and local Ollama embeddings for persisted observations without paying an embedding provider.

After Honcho is healthy, configure Hermes external memory from inside the Hermes container:

```bash
docker exec -it hermes sh -lc 'cd /opt/hermes && . .venv/bin/activate && ./hermes memory setup'
```

Use self-hosted Honcho URL:

```text
http://honcho-api:8000
```

Validation:

```bash
docker exec hermes sh -lc 'cd /opt/hermes && . .venv/bin/activate && ./hermes memory status'
docker exec hermes sh -lc 'cd /opt/hermes && . .venv/bin/activate && ./hermes doctor'
scripts/honcho-inspect.sh
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

## Codex OAuth Patch

The Docker image runs `hermes/patches/patch_codex_stream.py` during build. It patches Hermes' `run_agent.py` so OpenAI Codex OAuth streams can recover when `chatgpt.com/backend-api/codex` sends valid text deltas and then a final frame with `response.output = null`, which otherwise causes openai-python to raise:

```text
TypeError: 'NoneType' object is not iterable
```

Validation from the running container:

```bash
docker exec --user hermes hermes /opt/hermes/.venv/bin/python /opt/hermes/hermes -z 'Responde solo: OK'
```

Expected output:

```text
OK
```

## TUI

Use the helper script from the host:

```bash
scripts/hermes-tui.sh
```

The local shell alias is:

```bash
alias hermes-tui='/data/homelab/scripts/hermes-tui.sh'
```

## Clean Reinstall

For a clean Hermes runtime without deleting Honcho memory, stop the stack, move `/data/homelab/hermes/data` aside, and redeploy. Keep `/data/homelab/hermes/honcho/*` intact.

## Security Rules

Hermes v1 must not mount `/var/run/docker.sock`, must not see `/data/homelab` directly, and must not inherit Codex MCP tokens. Its writable filesystem scope is its own persistent data/workspace under `/data/homelab/hermes/data`.

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
