# Homelab

Repositorio publico para versionar la configuracion declarativa del homelab y desplegar servicios como stacks de Portainer.

Los datos persistentes, logs, bases de datos, claves, JWT, backups y ficheros `.env` quedan fuera de Git. La ruta base actual es `/data/homelab`.

`/data/docker` fue eliminado. Algunos contenedores activos todavia declaran mounts antiguos hacia esa ruta, asi que no deben recrearse hasta extraer o confirmar sus datos vivos desde el propio contenedor.

## Servicios

| Servicio | Stack | Puerto(s) | Datos persistentes | Notas |
| --- | --- | --- | --- | --- |
| Portainer | `portainer/docker-compose.yml` | `9443/tcp` | `/data/homelab/portainer/data` | UI de gestion de Docker y stacks. |
| Home Assistant | `homeassistant/docker-compose.yml` | `8123/tcp` | `/data/homelab/homeassistant` | Usa `network_mode: host`, recomendado para discovery local. |
| Monitoring | `prometheus/docker-compose.yml` | `9090/tcp`, `9100/tcp`, `3000/tcp` | `/data/homelab/prometheus/data`, `/data/homelab/grafana/data` | Incluye Prometheus, Node Exporter y Grafana en la red `server-monitoring`. |
| AdGuard Home | `adguard/docker-compose.yml` | `53/tcp,udp`, `3001/tcp`, `8081/tcp` | `/data/homelab/adguard/conf`, `/data/homelab/adguard/work` | `3001` evita colision con Grafana en `3000`. |
| Passbolt | `passbolt/docker-compose.yml` | `8080/tcp`, `8444/tcp` | `/data/homelab/passbolt/db`, `/data/homelab/passbolt/gpg`, `/data/homelab/passbolt/jwt` | Requiere revisar dominio, SMTP y secretos. |

## Uso con Portainer

1. Copia el ejemplo del servicio que quieras desplegar:

   ```bash
   cp passbolt/.env.example passbolt/.env
   ```

2. Edita el `.env` local con rutas, dominio, puertos y secretos reales.
3. En Portainer, crea un stack nuevo y sube el `docker-compose.yml` del servicio.
4. Anade las variables del `.env` en la seccion de environment variables del stack, o usa el repositorio Git desde Portainer apuntando al directorio del servicio.
5. Despliega y valida logs antes de migrar trafico.

Para stacks ya activos, no ejecutes `up -d` sin comprobar primero las rutas de volumen. Como `/data/docker` ya no existe, reiniciar un contenedor que aun apunte a esa ruta puede arrancar vacio o fallar.

## Estado actual detectado

Los contenedores activos revisados siguen usando estas rutas antiguas o volumenes Docker:

| Contenedor | Mount activo |
| --- | --- |
| `adguard` | `/data/docker/adguard/conf`, `/data/docker/adguard/work` |
| `homeassistant` | `/data/docker/homeassistant` |
| `prometheus` | `/data/docker/prometheus/prometheus.yml`, `/data/docker/prometheus/data` |
| `grafana` | volumen Docker `grafana_data` |
| `portainer` | volumen Docker `portainer_portainer_data` |

Antes de recrear esos stacks desde este repositorio, extrae los datos vivos desde el contenedor o el volumen Docker, sincronizalos a `/data/homelab/...` y haz backup. Portainer tambien cambiaria de un volumen Docker gestionado a un bind mount en `/data/homelab/portainer/data`.

## Migracion

Los backups locales se guardan bajo `_backups/<timestamp>/` y no se suben a Git. La ultima copia de migracion creada es `_backups/20260516-225201/`.

Estado de migracion:

| Servicio | Estado | Origen vivo | Destino nuevo | Validacion |
| --- | --- | --- | --- | --- |
| Home Assistant | migrado y validado desde Portainer/GitHub | `homeassistant:/config` | `/data/homelab/homeassistant` | UI `8123`, logs, `check_config` |
| AdGuard Home | migrado y validado desde Portainer/GitHub | `adguard:/opt/adguardhome/conf`, `adguard:/opt/adguardhome/work` | `/data/homelab/adguard` | DNS `53`, UI/setup `3001` |
| Monitoring | en migracion a Portainer/GitHub | `prometheus:/prometheus`, `grafana:/var/lib/grafana` | `/data/homelab/prometheus/data`, `/data/homelab/grafana/data` | Prometheus targets, Grafana `3000` |
| Passbolt | preparado, pendiente de secretos y despliegue | datos existentes en `/data/homelab/passbolt` | `/data/homelab/passbolt` | DB, URL publica, SMTP |
| Portainer | datos extraidos y sincronizados, pendiente de recrear al final por CLI | volumen `portainer_portainer_data` | `/data/homelab/portainer/data` | login `9443`, stacks visibles |

Datos sincronizados en `/data/homelab`:

| Ruta | Tamano aproximado | Nota |
| --- | --- | --- |
| `/data/homelab/homeassistant` | `20M` | Copia viva de `homeassistant:/config`. |
| `/data/homelab/adguard` | `110M` | Copia viva de `conf` y `work`. |
| `/data/homelab/prometheus/data` | `685M` | Copia viva de `prometheus:/prometheus`. |
| `/data/homelab/grafana/data` | `52M` | Copia del volumen usado por Grafana. |
| `/data/homelab/portainer/data` | `1.2M` | Copia del volumen usado por Portainer. |

Validaciones realizadas tras la sincronizacion:

| Validacion | Resultado |
| --- | --- |
| `docker compose config` de Portainer, Home Assistant, Monitoring, AdGuard y Passbolt | OK |
| Home Assistant `check_config` con `/data/homelab/homeassistant` | OK |
| Prometheus `promtool check config` con `/data/homelab/prometheus/prometheus.yml` | OK |

Notas de despliegue:

| Servicio | Nota |
| --- | --- |
| Home Assistant | Migrado a `/data/homelab/homeassistant` y validado en UI con entidades/configuracion conservadas. Docker confirma `NET_ADMIN`, `NET_RAW` y `/run/dbus:/run/dbus:ro`; los logs siguen mostrando errores de `habluetooth.scanner`, pero el servicio funciona igual que antes. |
| AdGuard Home | Migrado a Portainer desde GitHub tras cambiar DNS temporalmente en Tailscale y reiniciar Portainer para que Docker usara `1.1.1.1`. Conserva configuracion y publica `53`, `3001` y `8081`. |
| Monitoring | La red `server-monitoring` ya existia sin labels de Compose; el stack la declara como `external: true` para que Portainer la reutilice sin intentar apropiarsela. |

Siguiente paso operativo: recrear cada stack desde Portainer, uno a uno, usando las rutas `/data/homelab`. No elimines los contenedores antiguos hasta validar el reemplazo.

## Validacion

```bash
docker compose -f portainer/docker-compose.yml config
docker compose -f homeassistant/docker-compose.yml config
docker compose -f prometheus/docker-compose.yml config
docker compose -f adguard/docker-compose.yml config
docker compose -f passbolt/docker-compose.yml config
```

Home Assistant:

```bash
docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config
```

Prometheus:

```bash
docker run --rm -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus --config.file=/etc/prometheus/prometheus.yml --web.enable-lifecycle
```

## Estructura

```text
.
├── adguard/
├── homeassistant/
├── passbolt/
├── portainer/
├── prometheus/
└── grafana/
```

Cada carpeta contiene su `docker-compose.yml` y un `.env.example`. Los `.env` reales son locales y no se suben a Git.

## Checklist antes de publicar

- Revisar `git status --ignored` y confirmar que no aparecen secretos como ficheros versionables.
- No subir `homeassistant/secrets.yaml`, `.storage`, bases de datos, logs, claves GPG/JWT ni `prometheus/data`.
- Sustituir todos los `CHANGE_ME` de los `.env` locales antes de desplegar.
- Confirmar que las rutas persistentes existen en `/data/homelab`.
- Hacer backup antes de recrear Passbolt, Home Assistant o cualquier servicio con base de datos.
