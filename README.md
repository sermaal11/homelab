# Homelab

Repositorio publico para versionar los stacks Docker del homelab y desplegarlos desde Portainer. La configuracion declarativa vive en GitHub; los datos persistentes, secretos y ficheros `.env` viven solo en el servidor.

Ruta base actual:

```text
/data/homelab
```

## Servicios

| Servicio | Stack | URL / puerto | Datos persistentes | Gestion |
| --- | --- | --- | --- | --- |
| Portainer | `portainer/docker-compose.yml` | `https://homelab:9443` | `/data/homelab/portainer/data` | Git-first, actualizado por CLI |
| Home Assistant | `homeassistant/docker-compose.yml` | `http://homelab:8123` | `/data/homelab/homeassistant` | Portainer desde GitHub |
| AdGuard Home | `adguard/docker-compose.yml` | `http://homelab:3001` | `/data/homelab/adguard/conf`, `/data/homelab/adguard/work` | Portainer desde GitHub |
| Monitoring | `prometheus/docker-compose.yml` | Prometheus `9090`, Grafana `3000`, Node Exporter `9100` | `/data/homelab/prometheus/data`, `/data/homelab/grafana/data` | Portainer desde GitHub |
| Passbolt | `passbolt/docker-compose.yml` | `http://homelab:8080` | `/data/homelab/passbolt/db`, `/data/homelab/passbolt/gpg`, `/data/homelab/passbolt/jwt` | Portainer desde GitHub |

## Despliegue

Los stacks de aplicación se despliegan en Portainer con:

```text
Repository URL: https://github.com/sermaal11/homelab.git
Repository reference: refs/heads/main
Compose path: <servicio>/docker-compose.yml
```

Las variables reales se configuran en Portainer o en `.env` locales ignorados por Git. No subas `.env`, bases de datos, logs, claves, JWT ni directorios `data`.

Portainer es la excepción: no debe autodesplegarse desde su propia UI. Su compose también vive en GitHub, pero se actualiza por CLI:

```bash
git pull git@github.com:sermaal11/homelab.git main
docker compose --env-file portainer/.env -f portainer/docker-compose.yml up -d
```

Si `origin` sigue configurado por HTTPS y no hay token, usa la URL SSH explicita como arriba.

## Variables

Cada servicio tiene un `.env.example` versionado. Copia el ejemplo a `.env` solo en el servidor:

```bash
cp passbolt/.env.example passbolt/.env
```

Resumen de variables importantes:

| Servicio | Variables clave |
| --- | --- |
| Home Assistant | `TZ`, `HOMEASSISTANT_CONFIG_DIR` |
| AdGuard Home | `ADGUARD_DNS_PORT`, `ADGUARD_WEB_PORT`, `ADGUARD_SETUP_PORT`, `ADGUARD_WORK_DIR`, `ADGUARD_CONF_DIR` |
| Monitoring | `PROMETHEUS_PORT`, `NODE_EXPORTER_PORT`, `GRAFANA_PORT`, `PROMETHEUS_DATA_DIR`, `GRAFANA_DATA_DIR` |
| Passbolt | `PASSBOLT_BASE_URL`, `PASSBOLT_DB_PASSWORD`, `PASSBOLT_DB_DIR`, `PASSBOLT_GPG_DIR`, `PASSBOLT_JWT_DIR` |
| Portainer | `PORTAINER_HTTPS_PORT`, `PORTAINER_DATA_DIR` |

## Notas Operativas

- `/data/docker` fue retirado; no debe usarse en nuevos stacks.
- AdGuard es DNS del homelab. Si se para y Portainer necesita clonar GitHub, puede ser necesario usar DNS externo temporal en Tailscale y reiniciar Portainer para refrescar DNS de Docker.
- La red `server-monitoring` ya existia antes del stack de monitoring, por eso se declara como externa.
- Home Assistant usa `network_mode: host`, `privileged`, `NET_ADMIN`, `NET_RAW` y `/run/dbus:/run/dbus:ro` para discovery/Bluetooth.
- Passbolt esta en modo local con `PASSBOLT_BASE_URL=http://homelab:8080` y sin SMTP por ahora. Cuando se exponga con Tailscale Funnel, revisar URL publica y SMTP real.

## Validacion

Validar sintaxis de compose:

```bash
docker compose --env-file portainer/.env -f portainer/docker-compose.yml config
docker compose --env-file homeassistant/.env -f homeassistant/docker-compose.yml config
docker compose --env-file adguard/.env -f adguard/docker-compose.yml config
docker compose --env-file prometheus/.env -f prometheus/docker-compose.yml config
docker compose --env-file passbolt/.env -f passbolt/docker-compose.yml config
```

Home Assistant:

```bash
docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config
```

Prometheus:

```bash
docker run --rm --entrypoint promtool -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus:latest check config /etc/prometheus/prometheus.yml
```

Estado rapido:

```bash
docker ps
git status --short --ignored
```

## Estructura

```text
.
├── adguard/
├── grafana/
├── homeassistant/
├── passbolt/
├── portainer/
└── prometheus/
```

## Publicacion

Antes de publicar cambios:

- Ejecuta `git status --short --ignored`.
- Confirma que solo se versionan `docker-compose.yml`, `.env.example`, YAML de Home Assistant y documentacion.
- Verifica que `.env`, `secrets.yaml`, `.storage`, bases de datos, logs, claves GPG/JWT y datos persistentes siguen ignorados.
- Valida el stack modificado con `docker compose ... config`.
