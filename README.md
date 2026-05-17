# Homelab Infrastructure

Repositorio publico para documentar y versionar la capa declarativa de un homelab basado en Docker, Portainer y Tailscale. El objetivo es que el repositorio sea util como referencia operativa, demostracion tecnica y punto unico de verdad para los stacks.

Los datos persistentes y secretos no forman parte del repositorio. Viven en el servidor bajo:

```text
/data/homelab
```

## Arquitectura

El homelab se organiza como stacks independientes por servicio. Portainer despliega los stacks de aplicacion desde GitHub, mientras que Portainer se mantiene con un flujo Git-first ejecutado por CLI para evitar que se autogestione desde su propia UI.

| Capa | Servicio | Rol |
| --- | --- | --- |
| Gestion | Portainer | Gestion de stacks Docker y operaciones desde UI |
| Automatizacion | Home Assistant | Integraciones, automatizaciones y paneles domesticos |
| Red | AdGuard Home | DNS local, filtrado y resolucion para el homelab |
| Observabilidad | Prometheus, Node Exporter, Blackbox Exporter, Grafana | Metricas, comprobaciones de servicios y dashboards |
| Secretos | Passbolt | Password manager local/Tailscale, pendiente de SMTP real |

## Inventario

| Servicio | Compose | Acceso | Persistencia | Gestion |
| --- | --- | --- | --- | --- |
| Portainer | `portainer/docker-compose.yml` | `https://homelab:9443` | `/data/homelab/portainer/data` | Git + CLI |
| Home Assistant | `homeassistant/docker-compose.yml` | `http://homelab:8123` | `/data/homelab/homeassistant` | Portainer + GitHub |
| AdGuard Home | `adguard/docker-compose.yml` | `http://homelab:3001` | `/data/homelab/adguard/conf`, `/data/homelab/adguard/work` | Portainer + GitHub |
| Monitoring | `prometheus/docker-compose.yml` | Grafana `3000`, Prometheus `9090`, Node Exporter `9100`; Blackbox Exporter interno `9115` | `/data/homelab/grafana/data`, `/data/homelab/prometheus/data` | Portainer + GitHub |
| Passbolt | `passbolt/docker-compose.yml` | `http://homelab:8080` | `/data/homelab/passbolt/db`, `/data/homelab/passbolt/gpg`, `/data/homelab/passbolt/jwt` | Portainer + GitHub |

## MCP De Grafana

El repositorio incluye un wrapper para conectar Codex localmente con Grafana usando la imagen oficial `grafana/mcp-grafana`. No se despliega como servicio ni se expone a otros clientes: Codex lo arranca bajo demanda en modo `stdio`, el contenedor se une a la red Docker `server-monitoring` y habla con Grafana por `http://grafana:3000`.

Preparacion local:

```bash
cp grafana/mcp-grafana.env.example grafana/mcp-grafana.env
```

Despues, crear en Grafana un service account token con permisos acordes al uso previsto y guardarlo en `grafana/mcp-grafana.env` como `GRAFANA_SERVICE_ACCOUNT_TOKEN`. El archivo real queda ignorado por Git. Para permitir que Codex cree o modifique dashboards, alertas y otros recursos, usar un service account con rol `Editor` o permisos equivalentes.

Registrar el MCP local en Codex:

```bash
codex mcp add grafana -- /data/homelab/scripts/mcp-grafana.sh
```

El wrapper permite operaciones de escritura; el alcance real depende de los permisos del service account configurado en Grafana.

## Comprobaciones De Servicios

El stack de monitoring incluye Blackbox Exporter para comprobar servicios desde Prometheus. El exporter no publica puerto al host; Prometheus lo consulta dentro de la red `server-monitoring` en `blackbox-exporter:9115`. Para comprobar servicios de otros stacks, el contenedor tambien se une a las redes externas `adguard_default`, `passbolt_default` y `portainer_default`.

Targets actuales del job `service-health`:

| Servicio | Target |
| --- | --- |
| Home Assistant | `http://host.docker.internal:8123` |
| Grafana | `http://grafana:3000/api/health` |
| Prometheus | `http://prometheus:9090/-/ready` |
| AdGuard Home | `http://adguard:3000` |
| Passbolt | `http://passbolt` |
| Portainer | `https://portainer:9443` |

El modulo `http_service` acepta respuestas correctas, redirects y respuestas de autenticacion como senal de que el servicio responde.

## Dashboard Homelab

El dashboard `Homelab` de Grafana es el panel operativo principal. Actualmente esta organizado en estas secciones:

| Seccion | Contenido |
| --- | --- |
| Vista general | Estado global, servicios online, CPU, memoria, temperatura, disco, red y uptime |
| Procesador | Uso total y por nucleo fusionado, uso temporal y reparto de trabajo de CPU |
| Temperaturas | Temperaturas actuales, evolucion termica y ventilador |
| Almacenamiento | Uso por mountpoint, evolucion de uso, lectura/escritura y actividad de disco |
| Red | Estado de enlace, velocidad, trafico, paquetes, errores y descartes |
| Servicios | Online/caido, tiempo de respuesta, disponibilidad reciente, respuesta media, servicio mas lento y codigos HTTP |
| Energia | Alimentacion AC/bateria, porcentaje de bateria y consumo |

Los paneles de servicios usan el job Prometheus `service-health` y agrupan por `service` para evitar duplicados cuando cambian los targets. Los cambios de layout del dashboard se realizan via Grafana MCP y no estan versionados como JSON en este repositorio.

## Despliegue Desde Portainer

Para los stacks de aplicacion:

```text
Repository URL: https://github.com/sermaal11/homelab.git
Repository reference: refs/heads/main
Compose path: <servicio>/docker-compose.yml
```

Las variables reales se configuran en Portainer o en `.env` locales ignorados por Git. Los `.env.example` documentan el contrato esperado sin exponer secretos.

Portainer se actualiza desde el host:

```bash
git pull git@github.com:sermaal11/homelab.git main
docker compose --env-file portainer/.env -f portainer/docker-compose.yml up -d
```

## Variables Por Servicio

| Servicio | Variables principales |
| --- | --- |
| Home Assistant | `TZ`, `HOMEASSISTANT_CONFIG_DIR` |
| AdGuard Home | `ADGUARD_DNS_PORT`, `ADGUARD_WEB_PORT`, `ADGUARD_SETUP_PORT`, `ADGUARD_WORK_DIR`, `ADGUARD_CONF_DIR` |
| Monitoring | `PROMETHEUS_PORT`, `NODE_EXPORTER_PORT`, `GRAFANA_PORT`, `PROMETHEUS_DATA_DIR`, `GRAFANA_DATA_DIR`, `BLACKBOX_CONFIG_FILE` |
| Grafana MCP | `GRAFANA_URL`, `GRAFANA_SERVICE_ACCOUNT_TOKEN`, `GRAFANA_MCP_IMAGE`, `GRAFANA_MCP_NETWORK` |
| Passbolt | `PASSBOLT_BASE_URL`, `PASSBOLT_DB_PASSWORD`, `PASSBOLT_DB_DIR`, `PASSBOLT_GPG_DIR`, `PASSBOLT_JWT_DIR` |
| Portainer | `PORTAINER_HTTPS_PORT`, `PORTAINER_DATA_DIR` |

Ejemplo de preparacion local:

```bash
cp passbolt/.env.example passbolt/.env
```

## Seguridad

### Resultado de Auditoria

Auditoria realizada sobre ficheros versionados e historial Git:

| Control | Resultado |
| --- | --- |
| Secretos reales en Git | No detectados |
| `.env` versionados | No detectados |
| Bases de datos versionadas | No detectadas |
| Claves GPG/JWT/SSH versionadas | No detectadas |
| Config sensible de Home Assistant | `secrets.yaml`, `.storage` y DB estan ignorados |
| Config sensible de AdGuard | `AdGuardHome.yaml` y `work/` estan ignorados |
| Datos de Grafana, Prometheus, Portainer y Passbolt | Ignorados |

Comandos usados durante la revision:

```bash
git ls-files
git grep -n -I -E '(password|secret|token|api[_-]?key|private[_-]?key|BEGIN .*PRIVATE|CHANGE_ME|jwt|gpg)'
git grep -n -I -E '([0-9]{1,3}\.){3}[0-9]{1,3}|[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}'
git grep -n -I -E '(kVRq|PASSBOLT_DB_PASSWORD=[^C]|serverkey_private|BEGIN PGP|home-assistant_v2|AdGuardHome\.yaml)' $(git rev-list --all)
git status --short --ignored
```

### Riesgos Aceptados

| Riesgo | Motivo | Mitigacion |
| --- | --- | --- |
| Varias imagenes usan `latest` | Facilita actualizaciones en homelab | Revisar cambios antes de redeploy; considerar tags fijos si se prioriza reproducibilidad |
| Portainer monta `/var/run/docker.sock` | Necesario para gestionar Docker | Restringir acceso a Portainer y proteger credenciales |
| Home Assistant usa `network_mode: host` y `privileged` | Discovery local y Bluetooth | Mantenerlo solo en host confiable; no exponer directamente a Internet |
| Node Exporter monta `/` como lectura | Necesario para metricas host | Mount read-only y red interna de monitoring |
| AdGuard publica DNS `53` | Es DNS del homelab | Evitar exponer `53` fuera de LAN/Tailscale |
| Passbolt usa HTTP local | Instalacion local/Tailscale inicial | Antes de Funnel, cambiar `PASSBOLT_BASE_URL` a URL publica HTTPS y configurar SMTP real |

## Operacion

- `/data/docker` fue retirado; no debe reaparecer en nuevos compose.
- AdGuard es dependencia DNS. Si se para y Portainer necesita clonar GitHub, puede requerir DNS externo temporal en Tailscale y reinicio de Portainer para refrescar DNS de Docker.
- La red `server-monitoring` es externa porque existia antes del stack de monitoring.
- El stack `server_monitoring` se despliega desde Portainer/GitHub. Blackbox Exporter se ejecuta dentro de `server-monitoring`, usa redes externas de los stacks comprobados cuando aplica, comprueba Home Assistant mediante `host.docker.internal` y no expone puerto al host.
- Passbolt no tiene SMTP por ahora; el primer admin se creo por CLI. SMTP se configurara cuando se exponga con Tailscale Funnel o dominio publico.

## Validacion

Validar todos los compose:

```bash
docker compose --env-file portainer/.env -f portainer/docker-compose.yml config
docker compose --env-file homeassistant/.env -f homeassistant/docker-compose.yml config
docker compose --env-file adguard/.env -f adguard/docker-compose.yml config
docker compose --env-file prometheus/.env -f prometheus/docker-compose.yml config
docker compose --env-file passbolt/.env -f passbolt/docker-compose.yml config
```

Grafana MCP:

```bash
docker network inspect server-monitoring
test -n "$(grep '^GRAFANA_SERVICE_ACCOUNT_TOKEN=' grafana/mcp-grafana.env | cut -d= -f2-)"
codex mcp get grafana
```

Home Assistant:

```bash
docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config
```

Prometheus:

```bash
docker run --rm --entrypoint promtool -v "$PWD/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus:latest check config /etc/prometheus/prometheus.yml
docker run --rm --entrypoint blackbox_exporter -v "$PWD/prometheus/blackbox.yml:/etc/blackbox_exporter/config.yml" prom/blackbox-exporter:latest --config.check --config.file=/etc/blackbox_exporter/config.yml
```

Estado general:

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

## Publicacion Segura

Antes de publicar cambios:

1. Ejecutar `git status --short --ignored`.
2. Confirmar que solo se versionan compose, `.env.example`, YAML publico de Home Assistant y documentacion.
3. Verificar que `.env`, `secrets.yaml`, `.storage`, bases de datos, logs, claves GPG/JWT y directorios persistentes siguen ignorados.
4. Validar el compose modificado con `docker compose ... config`.
5. Evitar incluir capturas con tokens, usuarios internos o URLs privadas sensibles.

## Roadmap

- Configurar SMTP real para Passbolt cuando se exponga con Tailscale Funnel.
- Evaluar tags fijos o digest pinning para imagenes criticas.
- Añadir backup automatizado para datos persistentes.
- Documentar procedimiento de restauracion por servicio.
