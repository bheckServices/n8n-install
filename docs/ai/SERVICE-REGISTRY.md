# Service Registry

**Complete catalog of all services, their purposes, dependencies, and configuration.**

---

## 🎯 Core Services (Always Active)

### Postgres
- **Profile:** None (always active)
- **Purpose:** Primary database for n8n, Langfuse, and other services
- **Image:** `postgres:16-alpine`
- **Internal Port:** 5432
- **External Access:** Via pgAdmin (if enabled)
- **Dependencies:** None
- **Key Env Vars:**
  - `POSTGRES_USER` - Database superuser
  - `POSTGRES_PASSWORD` - Superuser password
  - `POSTGRES_DB` - Default database (n8n)
- **Volumes:** `n8nInstall_postgres_data`
- **Healthcheck:** `pg_isready -U ${POSTGRES_USER}`

### Redis (or Valkey)
- **Profile:** None (always active)
- **Purpose:** Queue backend for n8n, caching
- **Image:** `redis:7-alpine` or `valkey/valkey:latest`
- **Internal Port:** 6379
- **External Access:** None
- **Dependencies:** None
- **Key Env Vars:**
  - `REDIS_PASSWORD` - Auth password
- **Volumes:** `n8nInstall_redis_data`
- **Healthcheck:** `redis-cli ping`

### Caddy
- **Profile:** None (always active)
- **Purpose:** Reverse proxy, HTTPS termination, Let's Encrypt automation
- **Image:** `caddy:latest`
- **External Ports:** 80, 443
- **Dependencies:** None (but required by other services for auth)
- **Key Env Vars:**
  - `LETSENCRYPT_EMAIL` - Email for Let's Encrypt
  - `*_HOSTNAME` - Hostnames for each service
  - `*_PASSWORD_HASH` - Bcrypt hashes for Basic Auth
- **Volumes:** `n8nInstall_caddy_data` (certificates)
- **Healthcheck:** `wget -qO- http://localhost:2019/health`

---

## 📦 Optional Services (Profile-Based)

### n8n (Profile: `n8n`)
- **Purpose:** Workflow automation platform (main app + workers)
- **Images:**
  - `n8nio/n8n:latest` - Main app and workers
- **Services:**
  - `n8n` - Web UI and API
  - `n8n-worker` - Workflow executor (scalable)
  - `n8n-import` - CLI for importing workflows
- **External Access:** `https://${N8N_HOSTNAME}`
- **Dependencies:**
  - `postgres` (healthy)
  - `redis` (healthy)
- **Key Env Vars:**
  - `N8N_HOSTNAME` - Public hostname
  - `N8N_BASIC_AUTH_USER` / `N8N_BASIC_AUTH_PASSWORD` - Caddy auth
  - `N8N_ENCRYPTION_KEY` - Data encryption
  - `N8N_WORKER_COUNT` - Number of workers
  - `DB_POSTGRESDB_PASSWORD` - Postgres connection
- **Volumes:** `n8nInstall_n8n_storage`, `./shared` (bind mount)

### Flowise (Profile: `flowise`)
- **Purpose:** AI agent builder / LLM orchestration
- **Image:** `flowiseai/flowise:latest`
- **External Access:** `https://${FLOWISE_HOSTNAME}`
- **Dependencies:** None
- **Key Env Vars:**
  - `FLOWISE_HOSTNAME` - Public hostname
  - `FLOWISE_API_KEY` - API authentication
- **Volumes:** `n8nInstall_flowise_data`

### Monitoring Stack (Profile: `monitoring`)
- **Purpose:** Metrics, dashboards, alerting
- **Services:**
  - `prometheus` - Time-series database
  - `grafana` - Visualization and dashboards
  - `cadvisor` - Container metrics
  - `node-exporter` - Host system metrics
- **External Access:**
  - Grafana: `https://${GRAFANA_HOSTNAME}`
  - Prometheus: Internal only
- **Dependencies:**
  - `grafana` depends on `prometheus`
- **Key Env Vars:**
  - `GRAFANA_HOSTNAME` - Public hostname
  - `GRAFANA_USER` / `GRAFANA_PASSWORD` - Caddy + Grafana auth
- **Volumes:**
  - `n8nInstall_prometheus_data`
  - `n8nInstall_grafana_data`

### Langfuse (Profile: `langfuse`)
- **Purpose:** LLM observability and analytics
- **Services:**
  - `langfuse-web` - Web UI
  - `langfuse-worker` - Background processor
  - `clickhouse` - Analytics database
  - `minio` - Object storage
- **External Access:** `https://${LANGFUSE_HOSTNAME}`
- **Dependencies:**
  - `langfuse-web` depends on `postgres`, `clickhouse`, `minio`
- **Key Env Vars:**
  - `LANGFUSE_HOSTNAME` - Public hostname
  - `NEXTAUTH_SECRET` - Session encryption
  - `SALT` - Password hashing
- **Volumes:**
  - `n8nInstall_clickhouse_data`
  - `n8nInstall_minio_data`

### Ollama (Profiles: `cpu`, `gpu-nvidia`, `gpu-amd`)
- **Purpose:** Local LLM inference
- **Images:**
  - `ollama/ollama:latest` (CPU version)
  - `ollama/ollama:latest` with GPU passthrough (GPU versions)
- **External Access:** Internal only (n8n/Flowise connect via network)
- **Dependencies:** None
- **Key Env Vars:**
  - `OLLAMA_MODELS` - Model storage path
- **Volumes:** `n8nInstall_ollama_models`
- **Note:** Choose ONE of `cpu`, `gpu-nvidia`, or `gpu-amd` profiles

### pgAdmin (Profile: `pgadmin`)
- **Purpose:** Postgres web UI for administration
- **Image:** `dpage/pgadmin4:latest`
- **External Access:** `https://${PGADMIN_HOSTNAME}`
- **Dependencies:** None (connects to `postgres` via network)
- **Key Env Vars:**
  - `PGADMIN_HOSTNAME` - Public hostname
  - `PGADMIN_DEFAULT_EMAIL` - Login email
  - `PGADMIN_DEFAULT_PASSWORD` - Login password
  - `PGADMIN_BASIC_AUTH_USER` / `PGADMIN_PASSWORD_HASH` - Caddy auth
- **Volumes:** `n8nInstall_pgadmin_data`

### Cloudflare Tunnel (Profile: `cloudflare-tunnel`)
- **Purpose:** Zero-trust access via Cloudflare
- **Image:** `cloudflare/cloudflared:latest`
- **External Access:** Via Cloudflare (no direct ports)
- **Dependencies:** None
- **Key Env Vars:**
  - `CLOUDFLARE_TUNNEL_TOKEN` - Tunnel authentication
- **Volumes:** None (stateless)

---

## 🔗 Service Dependency Map

```
Caddy (no dependencies)
  ↑
  └── Provides HTTPS and Basic Auth for all services

Postgres (no dependencies)
  ↑
  ├── n8n
  ├── n8n-worker
  └── langfuse-web

Redis (no dependencies)
  ↑
  ├── n8n
  └── n8n-worker

Prometheus (no dependencies)
  ↑
  └── Grafana

ClickHouse, MinIO (no dependencies)
  ↑
  └── langfuse-web
```

---

## 📊 Resource Recommendations

| Service | Min CPU | Min RAM | Disk (Data) | Notes |
|---------|---------|---------|-------------|-------|
| Postgres | 0.5 | 512MB | 5-20GB | Grows with workflows/data |
| Redis | 0.25 | 256MB | 1GB | Mostly transient queue data |
| Caddy | 0.1 | 128MB | <100MB | Minimal resource usage |
| n8n | 0.5 | 512MB | 2-10GB | Per instance (main + workers) |
| n8n-worker | 0.5 | 512MB | - | Scales with `N8N_WORKER_COUNT` |
| Flowise | 0.5 | 512MB | 1-5GB | Depends on flow complexity |
| Grafana | 0.25 | 256MB | <1GB | Mostly config data |
| Prometheus | 0.5 | 512MB | 5-20GB | Time-series data grows over time |
| Ollama (CPU) | 2.0 | 4GB | 10-100GB | Model-dependent |
| Ollama (GPU) | 1.0 | 2GB | 10-100GB | Offloads to GPU |
| pgAdmin | 0.25 | 256MB | <500MB | UI only, no data storage |

**Total for typical setup (n8n + monitoring):**
- CPU: 3-4 cores
- RAM: 4-8GB
- Disk: 30-60GB

---

## 🛠 Service Management Commands

```bash
# Start specific service
docker compose -p localai up -d <service>

# Restart service
docker compose -p localai restart <service>

# Recreate service (fresh state)
docker compose -p localai up -d --force-recreate <service>

# Stop service
docker compose -p localai stop <service>

# View service logs
docker logs n8nInstall_<service> --tail=200

# Scale n8n workers
docker compose -p localai up -d --scale n8n-worker=3

# Check service health
docker inspect n8nInstall_<service> --format='{{.State.Health.Status}}'
```

---

## ✅ Service Validation

**Per-service healthcheck:**

```bash
# Postgres
docker exec n8nInstall_postgres pg_isready -U n8n

# Redis
docker exec n8nInstall_redis redis-cli ping

# Caddy
docker exec n8nInstall_caddy caddy list-certificates

# n8n
curl -k -I https://${N8N_HOSTNAME}

# Flowise
curl -k -I https://${FLOWISE_HOSTNAME}

# Grafana
curl -k -I https://${GRAFANA_HOSTNAME}

# pgAdmin
curl -k -I https://${PGADMIN_HOSTNAME}
```

---

## 🔗 Related Documentation

- [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md) - Profile system
- [CONFIGURATION-MANAGEMENT.md](./CONFIGURATION-MANAGEMENT.md) - Environment variables
- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) - Docker Compose details

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
