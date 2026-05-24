# Homelab Infrastructure

Repositorio publico para documentar y versionar la capa declarativa de un homelab basado en Docker, Portainer y Tailscale. El objetivo es que el repositorio sea util como referencia operativa, demostracion tecnica y punto unico de verdad para los stacks.

Los datos persistentes y secretos no forman parte del repositorio. Viven como bind mounts locales documentados en los `.env.example`; en este servidor se usa una raiz de datos dedicada:

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
| Automatizacion | n8n, Redis | Automatizaciones internas, webhooks y buffers temporales para flujos conversacionales |
| Mayordomo | Hermes Agent | Agente personal Telegram-first con dashboard local y contexto del homelab |
| Secretos | Passbolt | Password manager local/Tailscale, pendiente de SMTP real |
| Archivos | Nextcloud, MariaDB, Redis | Nube privada tipo Drive para documentos y ficheros |

## Inventario

| Servicio | Compose | Acceso | Persistencia | Gestion |
| --- | --- | --- | --- | --- |
| Portainer | `portainer/docker-compose.yml` | `https://homelab:9443` | `portainer/data` | Git + CLI |
| Home Assistant | `homeassistant/docker-compose.yml` | `http://homelab:8123` | `homeassistant/` | Portainer + GitHub |
| AdGuard Home | `adguard/docker-compose.yml` | `http://homelab:3001` | `adguard/conf`, `adguard/work` | Portainer + GitHub |
| Monitoring | `server_monitoring/docker-compose.yml` | Grafana `3000`, Prometheus `9090`, Node Exporter `9100`; Blackbox Exporter interno `9115` | `server_monitoring/grafana/data`, `server_monitoring/prometheus/data` | Portainer + GitHub |
| n8n | `n8n/docker-compose.yml` | `http://homelab:5678`; Redis interno sin puerto publicado | `n8n/data`, `n8n/files`; Redis efimero | Portainer + GitHub |
| Hermes Agent | `hermes/docker-compose.yml` | Gateway `http://homelab:8642`; dashboard `http://homelab:9119`; Telegram polling | `hermes/data` | Portainer + GitHub |
| Passbolt | `passbolt/docker-compose.yml` | `http://homelab:8080` | `passbolt/db`, `passbolt/gpg`, `passbolt/jwt` | Portainer + GitHub |
| Nextcloud | `nextcloud/docker-compose.yml` | `http://homelab:8082` | `nextcloud/html`, `nextcloud/db`; Redis efimero | Portainer + GitHub |

## MCP De Grafana

El repositorio incluye un wrapper para conectar Codex localmente con Grafana usando la imagen oficial `grafana/mcp-grafana`. No se despliega como servicio ni se expone a otros clientes: Codex lo arranca bajo demanda en modo `stdio`, el contenedor se une a la red Docker `server-monitoring` y habla con Grafana por `http://grafana:3000`.

Preparacion local:

```bash
cp server_monitoring/grafana/mcp-grafana.env.example server_monitoring/grafana/mcp-grafana.env
```

Despues, crear en Grafana un service account token con permisos acordes al uso previsto y guardarlo en `server_monitoring/grafana/mcp-grafana.env` como `GRAFANA_SERVICE_ACCOUNT_TOKEN`. El archivo real queda ignorado por Git. Para permitir que Codex cree o modifique dashboards, alertas y otros recursos, usar un service account con rol `Editor` o permisos equivalentes.

Registrar el MCP local en Codex:

```bash
codex mcp add grafana -- /data/homelab/scripts/mcp-grafana.sh
```

El wrapper permite operaciones de escritura; el alcance real depende de los permisos del service account configurado en Grafana.

## MCP De GitHub

El repositorio incluye un wrapper local para conectar Codex con el servidor MCP oficial de GitHub usando la imagen `ghcr.io/github/github-mcp-server`. No se despliega como servicio: Codex lo arranca bajo demanda en modo `stdio`. El token real vive solo en `github/mcp.env`, ignorado por Git.

Preparacion local:

```bash
cp github/mcp.env.example github/mcp.env
```

Despues, crear un GitHub Personal Access Token con el minimo alcance necesario y guardarlo en `github/mcp.env` como `GITHUB_PERSONAL_ACCESS_TOKEN`. Por defecto el wrapper usa `GITHUB_TOOLSETS=default,actions`; el toolset `default` incluye contexto, repositorios, issues, pull requests y usuarios, y `actions` permite consultar GitHub Actions.

Registrar el MCP local en Codex:

```bash
codex mcp add github -- /data/homelab/scripts/mcp-github.sh
```

Verificar:

```bash
codex mcp get github
```

## MCP De Home Assistant

Home Assistant incluye un servidor MCP oficial en la integracion `Model Context Protocol Server`. No se despliega como contenedor aparte: cuando la integracion esta configurada en Home Assistant, Codex puede conectarse por HTTP a `http://homelab:8123/api/mcp` usando un long-lived access token.

Preparacion local:

```bash
cp homeassistant/mcp.env.example homeassistant/mcp.env
```

Despues, en Home Assistant, anadir la integracion `Model Context Protocol Server` desde Settings -> Devices & services, crear un long-lived access token para Codex y guardarlo en `homeassistant/mcp.env` como `HOMEASSISTANT_TOKEN`. El archivo real queda ignorado por Git. Controlar que entidades puede ver o manejar el MCP desde la configuracion de entidades expuestas de Home Assistant/Assist.

Registrar el MCP HTTP en Codex:

```bash
codex mcp add homeassistant --url http://homelab:8123/api/mcp --bearer-token-env-var HOMEASSISTANT_TOKEN
```

Para usarlo, iniciar Codex con el token cargado:

```bash
/data/homelab/scripts/codex-with-homeassistant-mcp.sh
```

Verificar:

```bash
codex mcp get homeassistant
curl -i http://homelab:8123/api/mcp
```

Un `405 Method Not Allowed` en `GET /api/mcp` indica que la integracion esta configurada y el endpoint existe; un `404` indica que falta configurar la integracion en Home Assistant.

## Hermes Agent

Hermes es el mayordomo personal Telegram-first del homelab. Se despliega como stack propio desde `hermes/docker-compose.yml`, construye una imagen local basada en `nousresearch/hermes-agent:latest` con `honcho-ai` instalado, persiste todo su estado bajo `/data/homelab/hermes/data` y expone solo LAN/Tailscale:

- Gateway/API: `http://homelab:8642`
- Dashboard: `http://homelab:9119`
- Telegram: polling mediante `TELEGRAM_BOT_TOKEN`

Estado actual: Hermes usa OpenAI Codex con `gpt-5.5` como modelo principal y Groq `llama-3.3-70b-versatile` como fallback. Telegram queda limitado a toolsets ligeros (`todo`, `memory`, `homeassistant`, `messaging`) para evitar payloads demasiado grandes en conversaciones normales.

Honcho funciona como memoria externa dentro del mismo stack de Hermes. El stack levanta `honcho-api`, `honcho-deriver`, `honcho-db` con pgvector y `honcho-redis`; la API queda ligada a `127.0.0.1:8000` para debug local y Hermes accede por la red interna en `http://honcho-api:8000`. Hermes tiene `memory.provider=honcho`, workspace `homelab`, usuario `Sergio`, AI peer `Jared`, modo `hybrid` y escritura `async`. La configuracion inicial usa Groq como endpoint OpenAI-compatible para las tareas LLM y `HONCHO_EMBED_MESSAGES=false` para no necesitar embeddings de pago en v1. Si se quiere memoria semantica completa, anadir despues embeddings locales mediante Ollama/LiteLLM o un proveedor externo barato.

MCPs activos en Hermes: `homeassistant_mcp` apunta a `http://host.docker.internal:8123/api/mcp` y `n8n` apunta a `http://host.docker.internal:5678/mcp-server/http`. Sus tokens viven en el `.env` persistente ignorado de Hermes. Telegram tiene permitidos `todo`, `memory`, `homeassistant`, `messaging`, `homeassistant_mcp` y `n8n`.

Para inspeccionar lo que Honcho esta recibiendo y guardando:

```bash
scripts/honcho-inspect.sh
```

Preparacion local:

```bash
cp hermes/.env.example hermes/.env
openssl rand -hex 32
```

Guardar el valor generado como `HERMES_API_SERVER_KEY`. El contenedor puede arrancar sin API key de OpenAI/OpenRouter; el modelo, Telegram, Home Assistant y Grafana se pueden configurar despues desde Hermes/dashboard/CLI o, si se prefiere, rellenando `hermes/.env` antes del despliegue.

El contenedor no monta `/var/run/docker.sock` y no ve `/data/homelab` directamente. Su scope de ficheros inicial es su propio workspace persistente bajo `hermes/data`. Las plantillas iniciales de identidad, memoria y MCP viven en `hermes/bootstrap/`; despues del primer arranque se copian a `hermes/data` y se ajustan desde el dashboard si Hermes cambia su formato.

Reglas de seguridad del mayordomo:

- Puede consultar estado, resumir contexto, revisar salud del homelab y gestionar listas de bajo riesgo.
- Debe pedir confirmacion antes de enviar mensajes externos, publicar en LinkedIn, reiniciar servicios, mover/borrar archivos, cambiar automatizaciones o desplegar stacks.
- Nunca debe tocar Passbolt, AdGuard/DNS, exposicion publica, reglas de red, Portainer con escritura o borrado masivo sin una instruccion directa explicita.

## Comprobaciones De Servicios

El stack de monitoring monta sus rutas persistentes de forma explicita bajo `/data/homelab/server_monitoring` para evitar variables heredadas antiguas en Portainer.

El stack de monitoring incluye Blackbox Exporter para comprobar servicios desde Prometheus. El exporter no publica puerto al host; Prometheus lo consulta dentro de la red `server-monitoring` en `blackbox-exporter:9115`. Para comprobar servicios de otros stacks, el contenedor tambien se une a las redes externas `adguard_default`, `n8n_default`, `passbolt_default`, `nextcloud_default` y `portainer_default`.

Targets actuales del job `service-health`:

| Servicio | Target |
| --- | --- |
| Home Assistant | `http://host.docker.internal:8123` |
| Grafana | `http://grafana:3000/api/health` |
| Prometheus | `http://prometheus:9090/-/ready` |
| AdGuard Home | `http://adguard:3000` |
| n8n | `http://n8n:5678` |
| Passbolt | `http://passbolt` |
| Nextcloud | `http://nextcloud/status.php` |
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

Para operaciones Git desde el host, el remoto local `origin` debe usar SSH para evitar prompts de usuario/password en entornos no interactivos:

```bash
git remote set-url origin git@github.com:sermaal11/homelab.git
```

Portainer se actualiza desde el host:

```bash
git pull origin main
docker compose --env-file portainer/.env -f portainer/docker-compose.yml up -d
```

## Variables Por Servicio

| Servicio | Variables principales |
| --- | --- |
| Home Assistant | `TZ`, `HOMEASSISTANT_CONFIG_DIR` |
| AdGuard Home | `ADGUARD_DNS_PORT`, `ADGUARD_WEB_PORT`, `ADGUARD_SETUP_PORT`, `ADGUARD_WORK_DIR`, `ADGUARD_CONF_DIR` |
| Monitoring | `PROMETHEUS_PORT`, `NODE_EXPORTER_PORT`, `GRAFANA_PORT`, `PROMETHEUS_DATA_DIR`, `GRAFANA_DATA_DIR`, `BLACKBOX_CONFIG_FILE` |
| Grafana MCP | `GRAFANA_URL`, `GRAFANA_SERVICE_ACCOUNT_TOKEN`, `GRAFANA_MCP_IMAGE`, `GRAFANA_MCP_NETWORK` |
| n8n | `N8N_PORT`, `N8N_HOST`, `N8N_PROTOCOL`, `WEBHOOK_URL`, `GENERIC_TIMEZONE`, `N8N_DATA_DIR`, `N8N_FILES_DIR`, `N8N_ENCRYPTION_KEY`, `N8N_SECURE_COOKIE` |
| Hermes Agent | `HERMES_GATEWAY_PORT`, `HERMES_DASHBOARD_PORT`, `HERMES_DATA_DIR`, `HERMES_API_SERVER_KEY`; opcionales `OPENROUTER_API_KEY`, `OPENAI_API_KEY`, `GROQ_API_KEY`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_ALLOWED_USERS`, `TELEGRAM_HOME_CHANNEL`, `HOMEASSISTANT_TOKEN`, `GRAFANA_URL`, `GRAFANA_SERVICE_ACCOUNT_TOKEN`; Honcho con `HONCHO_*` |
| Nextcloud | `NEXTCLOUD_HTTP_PORT`, `NEXTCLOUD_TRUSTED_DOMAINS`, `NEXTCLOUD_OVERWRITEHOST`, `NEXTCLOUD_OVERWRITEPROTOCOL`, `NEXTCLOUD_DB_NAME`, `NEXTCLOUD_DB_USER`, `NEXTCLOUD_DB_PASSWORD`, `NEXTCLOUD_HTML_DIR`, `NEXTCLOUD_DB_DIR` |
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
| n8n UI usa HTTP local y `N8N_SECURE_COOKIE=false` | La UI sigue restringida a LAN/Tailscale; solo `/webhook` se publica via Tailscale Funnel HTTPS en `8443` para integraciones externas | No exponer la UI completa sin HTTPS/cookies seguras y autenticacion fuerte |
| Hermes expone gateway/dashboard en LAN | Necesario para Telegram gateway y administracion inicial | No publicar por Funnel/Internet; usar `TELEGRAM_ALLOWED_USERS`; no montar Docker socket; mantener tokens en `hermes/.env` |
| Passbolt usa HTTP local | Instalacion local/Tailscale inicial | Antes de Funnel, cambiar `PASSBOLT_BASE_URL` a URL publica HTTPS y configurar SMTP real |

## Operacion

- `/data/docker` fue retirado; no debe reaparecer en nuevos compose.
- AdGuard es dependencia DNS. Si se para y Portainer necesita clonar GitHub, puede requerir DNS externo temporal en Tailscale y reinicio de Portainer para refrescar DNS de Docker.
- La red `server-monitoring` es externa porque existia antes del stack de monitoring.
- El stack `server_monitoring` agrupa compose, configs y datos persistentes de Grafana y Prometheus bajo `server_monitoring/`.
- El stack `server_monitoring` se despliega desde Portainer/GitHub usando `server_monitoring/docker-compose.yml`.
- Blackbox Exporter se ejecuta dentro de `server-monitoring`, usa redes externas de los stacks comprobados cuando aplica, comprueba Home Assistant mediante `host.docker.internal`, comprueba Nextcloud con `/status.php` para evitar redirects al host LAN, y no expone puerto al host.
- n8n se despliega desde Portainer/GitHub usando `n8n/docker-compose.yml`. La UI sigue accesible localmente en `http://homelab:5678`; los webhooks entrantes usan `WEBHOOK_URL=https://homelab.tail5e76d5.ts.net:8443/` y se publican por Tailscale Funnel en la ruta `/webhook`, que se enruta a `http://localhost:5678`.
- n8n queda intencionadamente vacio de workflows y Data Tables despues de retirar la automatizacion anterior de LinkedIn. El stack conserva Redis interno sin puerto publicado y se mantienen las credenciales existentes de Redis, Groq y Telegram por si se reutilizan en futuros flujos.
- Queda como idea futura desarrollar un nuevo flujo de posts para LinkedIn desde cero, con un enfoque mas simple y menos centrado en ingenieria que el pipeline anterior.
- Hermes se despliega desde Portainer/GitHub usando `hermes/docker-compose.yml`, queda accesible localmente en `http://homelab:8642` y `http://homelab:9119`, persiste en `/data/homelab/hermes/data`, puede usar Telegram polling y no monta Docker socket. El despliegue inicial solo requiere `HERMES_API_SERVER_KEY`; modelo, Telegram, Home Assistant y Grafana pueden configurarse dentro de Hermes despues del primer arranque.
- Passbolt no tiene SMTP por ahora; el primer admin se creo por CLI. SMTP se configurara cuando se exponga con Tailscale Funnel o dominio publico.
- Nextcloud esta desplegado desde Portainer/GitHub usando `nextcloud/docker-compose.yml`, accesible en `http://homelab:8082`, con MariaDB persistente, Redis efimero y datos bajo `/data/homelab/nextcloud`. La instalacion inicial se completo en la UI, `occ status` reporta `installed: true`, `maintenance: false`, `needsDbUpgrade: false`, el modo de trabajos en segundo plano esta en `cron`, y se valido una subida real con `occ files:scan --all` sin errores.

## Validacion

Validar todos los compose:

```bash
docker compose --env-file portainer/.env -f portainer/docker-compose.yml config
docker compose --env-file homeassistant/.env -f homeassistant/docker-compose.yml config
docker compose --env-file adguard/.env -f adguard/docker-compose.yml config
docker compose -p server_monitoring --env-file server_monitoring/.env -f server_monitoring/docker-compose.yml config
docker compose --env-file n8n/.env -f n8n/docker-compose.yml config
docker compose --env-file hermes/.env -f hermes/docker-compose.yml config
docker compose --env-file nextcloud/.env -f nextcloud/docker-compose.yml config
docker compose --env-file passbolt/.env -f passbolt/docker-compose.yml config
```

Grafana MCP:

```bash
docker network inspect server-monitoring
test -n "$(grep '^GRAFANA_SERVICE_ACCOUNT_TOKEN=' server_monitoring/grafana/mcp-grafana.env | cut -d= -f2-)"
codex mcp get grafana
```

Home Assistant MCP:

```bash
test -n "$(grep '^HOMEASSISTANT_TOKEN=' homeassistant/mcp.env | cut -d= -f2-)"
codex mcp get homeassistant
curl -i http://homelab:8123/api/mcp
```

Home Assistant:

```bash
docker run --rm -v "$PWD/homeassistant:/config" ghcr.io/home-assistant/home-assistant:stable python -m homeassistant --script check_config --config /config
```

Hermes Agent:

```bash
test -n "$(grep '^HERMES_API_SERVER_KEY=' hermes/.env | cut -d= -f2-)"
docker compose --env-file hermes/.env -f hermes/docker-compose.yml ps
docker compose --env-file hermes/.env -f hermes/docker-compose.yml logs -f
docker exec hermes sh -lc 'cd /opt/hermes && . .venv/bin/activate && ./hermes status'
docker compose --env-file hermes/.env -f hermes/docker-compose.yml config
```

Prometheus:

```bash
docker run --rm --entrypoint promtool -v "$PWD/server_monitoring/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml" prom/prometheus:latest check config /etc/prometheus/prometheus.yml
docker run --rm --entrypoint blackbox_exporter -v "$PWD/server_monitoring/prometheus/blackbox.yml:/etc/blackbox_exporter/config.yml" prom/blackbox-exporter:latest --config.check --config.file=/etc/blackbox_exporter/config.yml
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
├── homeassistant/
├── n8n/
├── passbolt/
├── portainer/
└── server_monitoring/
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
