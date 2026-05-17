# Repository Guidelines

## Project Structure & Module Organization

This repository stores homelab service configuration and persisted service data. Top-level service directories are the main ownership boundary:

- `homeassistant/`: Home Assistant YAML configuration, automations, scripts, scenes, blueprints, runtime database, logs, and `.storage` state.
- `portainer/`: Portainer Docker Compose definition in `docker-compose.yml`.
- `server_monitoring/`: Monitoring stack Compose definition, Prometheus and Blackbox configuration, Grafana MCP env examples, and the target home for monitoring persisted data.
- `prometheus/`: Temporary legacy location for Prometheus TSDB data under `prometheus/data/` until the data move is completed.
- `grafana/`: Temporary legacy location for Grafana persisted data under `grafana/data/` until the data move is completed.
- `adguard/`: AdGuard Home configuration and working data.
- `passbolt/`: Passbolt database, GPG, JWT, and related persisted service files.

Treat `*/data/`, database files, logs, keys, JWT material, and Home Assistant `secrets.yaml` as sensitive or generated state unless a task explicitly requires changing them.

During service migration work, every iteration must update both `README.md` and `AGENTS.md` whenever routes, ports, services, commands, migration status, validation steps, or rollback notes change. Keep documentation in sync with the exact operational state before moving to the next service.

When `/data/docker` is absent but containers still show old bind mounts, treat the running containers as the source of truth until data has been extracted. Prefer copying live data to a temporary backup first, then syncing into `/data/homelab` without deleting destination files unless a task explicitly calls for destructive cleanup.

Current migration checkpoint: Home Assistant has been deployed from GitHub through Portainer using `/data/homelab/homeassistant` and validated in the browser with existing entities/configuration present. Do not delete `homeassistant-legacy` until the broader migration is complete and rollback is no longer needed.

AdGuard checkpoint: migrated to Portainer from GitHub using `/data/homelab/adguard` after temporarily removing AdGuard from Tailscale DNS and restarting Portainer so Docker picked up `1.1.1.1`; the new stack was validated with configuration preserved.

Monitoring checkpoint: the stack name is `server_monitoring`. Compose and config now live under `server_monitoring/`, and the stack is deployed from Portainer/GitHub using `server_monitoring/docker-compose.yml`. The Docker network `server-monitoring` predates the Compose stack and is external. Prometheus and Grafana data still temporarily live at `/data/homelab/prometheus/data` and `/data/homelab/grafana/data` until the persisted data move is completed. Blackbox Exporter is part of the monitoring stack for HTTP service checks; it stays internal, joins `server-monitoring` plus the external app networks needed for checks (`adguard_default`, `passbolt_default`, `portainer_default`), uses `host.docker.internal` only for host-network services such as Home Assistant, and is scraped by Prometheus job `service-health`.

Passbolt checkpoint: clean local/Tailscale install deployed from Portainer/GitHub using `PASSBOLT_BASE_URL=http://homelab:8080` and no SMTP for now. Previous Passbolt data was intentionally removed after the new install was validated. GPG/JWT directories required ownership adjustment to UID/GID `33:33`; UI loads and the initial admin user was created through the CLI registration link.

Portainer checkpoint: migrated last by CLI after refreshing `/data/homelab/portainer/data` from the live container. Current Portainer container mounts `/data/homelab/portainer/data:/data` and `/var/run/docker.sock:/var/run/docker.sock`.

Portainer is managed Git-first but CLI-deployed, not self-managed by Portainer UI. To update it, pull from GitHub and run `docker compose --env-file portainer/.env -f portainer/docker-compose.yml up -d`; use explicit SSH remote `git@github.com:sermaal11/homelab.git` if the local `origin` remains HTTPS.

Security audit checkpoint: README now documents the public-repo security posture. No real secrets were found in tracked files or Git history during regex-based review; only ignored local `.env`, runtime data, databases, logs, Home Assistant secrets, AdGuard config, Grafana/Prometheus data, Portainer data, and Passbolt DB/GPG/JWT remain on disk.

Grafana MCP checkpoint: Codex is connected locally through `scripts/mcp-grafana.sh`; do not deploy this as a shared MCP service for other clients. The wrapper runs the official `grafana/mcp-grafana` Docker image in `stdio` mode on the external `server-monitoring` Docker network. Keep the real service account token only in ignored local file `server_monitoring/grafana/mcp-grafana.env`; use `server_monitoring/grafana/mcp-grafana.env.example` as the documented contract. The wrapper allows write operations, so the effective access level is controlled by the Grafana service account permissions.

Grafana dashboard checkpoint: the `Homelab` dashboard is edited through Grafana MCP, not stored as dashboard JSON in Git. It currently includes a visual overview plus sections for processor, temperatures, storage, network, service health/latency/HTTP codes, and energy. Service panels must aggregate by `service` (for example `max by (service) (...)`) to avoid duplicate cards when probe targets change and old Prometheus series remain in the selected time range.

## Build, Test, and Development Commands

- `docker compose -f portainer/docker-compose.yml config`: validate the Portainer Compose file.
- `docker compose -f portainer/docker-compose.yml up -d`: start or update Portainer.
- `docker compose -f portainer/docker-compose.yml logs -f`: follow Portainer logs.
- `docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config`: validate Home Assistant configuration from the repository root.
- `docker compose -p server_monitoring --env-file server_monitoring/.env -f server_monitoring/docker-compose.yml config`: validate the monitoring Compose file.
- `docker run --rm --entrypoint promtool -v "$PWD/server_monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus:latest check config /etc/prometheus/prometheus.yml`: validate Prometheus config.
- `docker run --rm --entrypoint blackbox_exporter -v "$PWD/server_monitoring/prometheus/blackbox.yml:/etc/blackbox_exporter/config.yml" prom/blackbox-exporter:latest --config.check --config.file=/etc/blackbox_exporter/config.yml`: validate the Blackbox Exporter config.
- `codex mcp get grafana`: verify the Grafana MCP launcher is registered in the local Codex config after running `codex mcp add grafana -- /data/homelab/scripts/mcp-grafana.sh`.

Use service-specific Docker commands when no wrapper script exists.

## Coding Style & Naming Conventions

Use two-space indentation for YAML files. Keep service definitions grouped by service directory and prefer descriptive lowercase names for files, folders, job names, and container names. Preserve existing Home Assistant include patterns in `configuration.yaml` and place automations in `automations.yaml`, scripts in `scripts.yaml`, and scenes in `scenes.yaml`.

Do not hard-code credentials, tokens, host-specific private keys, or passwords in new tracked files. Use Home Assistant `!secret` references where applicable.

## Testing Guidelines

There is no central test framework. Validate the exact service you change before committing. For YAML-only changes, run the relevant parser or container config check. For Home Assistant changes, run `check_config`. For Docker Compose changes, run `docker compose ... config`. For Prometheus changes, start Prometheus in a disposable container or use `promtool check config` if available.

## Commit & Pull Request Guidelines

This repository has no existing commits, so use clear imperative commit subjects such as `Add Portainer compose guide` or `Update Home Assistant automations`. Keep unrelated service changes in separate commits.

Pull requests should state which service changed, list validation commands run, mention any required manual restart or migration, and call out sensitive files intentionally touched. Include screenshots only for UI-facing Home Assistant dashboard changes.
