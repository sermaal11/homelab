# Repository Guidelines

## Project Structure & Module Organization

This repository stores homelab service configuration and persisted service data. Top-level service directories are the main ownership boundary:

- `homeassistant/`: Home Assistant YAML configuration, automations, scripts, scenes, blueprints, runtime database, logs, and `.storage` state.
- `portainer/`: Portainer Docker Compose definition in `docker-compose.yml`.
- `prometheus/`: Prometheus configuration in `prometheus.yml` plus local TSDB data under `prometheus/data/`.
- `grafana/`: Grafana persisted data under `grafana/data/` when the monitoring stack is migrated to bind mounts.
- `adguard/`: AdGuard Home configuration and working data.
- `passbolt/`: Passbolt database, GPG, JWT, and related persisted service files.

Treat `*/data/`, database files, logs, keys, JWT material, and Home Assistant `secrets.yaml` as sensitive or generated state unless a task explicitly requires changing them.

During service migration work, every iteration must update both `README.md` and `AGENTS.md` whenever routes, ports, services, commands, migration status, validation steps, or rollback notes change. Keep documentation in sync with the exact operational state before moving to the next service.

When `/data/docker` is absent but containers still show old bind mounts, treat the running containers as the source of truth until data has been extracted. Prefer copying live data into `_backups/<timestamp>/` first, then syncing into `/data/homelab` without deleting destination files unless a task explicitly calls for destructive cleanup.

## Build, Test, and Development Commands

- `docker compose -f portainer/docker-compose.yml config`: validate the Portainer Compose file.
- `docker compose -f portainer/docker-compose.yml up -d`: start or update Portainer.
- `docker compose -f portainer/docker-compose.yml logs -f`: follow Portainer logs.
- `docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config`: validate Home Assistant configuration from the repository root.
- `docker run --rm -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus --config.file=/etc/prometheus/prometheus.yml --web.enable-lifecycle`: smoke-test Prometheus startup with this config.

Use service-specific Docker commands when no wrapper script exists.

## Coding Style & Naming Conventions

Use two-space indentation for YAML files. Keep service definitions grouped by service directory and prefer descriptive lowercase names for files, folders, job names, and container names. Preserve existing Home Assistant include patterns in `configuration.yaml` and place automations in `automations.yaml`, scripts in `scripts.yaml`, and scenes in `scenes.yaml`.

Do not hard-code credentials, tokens, host-specific private keys, or passwords in new tracked files. Use Home Assistant `!secret` references where applicable.

## Testing Guidelines

There is no central test framework. Validate the exact service you change before committing. For YAML-only changes, run the relevant parser or container config check. For Home Assistant changes, run `check_config`. For Docker Compose changes, run `docker compose ... config`. For Prometheus changes, start Prometheus in a disposable container or use `promtool check config` if available.

## Commit & Pull Request Guidelines

This repository has no existing commits, so use clear imperative commit subjects such as `Add Portainer compose guide` or `Update Home Assistant automations`. Keep unrelated service changes in separate commits.

Pull requests should state which service changed, list validation commands run, mention any required manual restart or migration, and call out sensitive files intentionally touched. Include screenshots only for UI-facing Home Assistant dashboard changes.
