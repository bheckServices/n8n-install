# Platform Architecture

**Scope:** Profile-based service management, network isolation, container naming, and reverse proxy architecture for n8n-install.

---

## 🎯 Architecture Overview

n8n-install is a **Docker Compose-based multi-service platform** that uses:

- **Profile-based activation** - Services enabled via `COMPOSE_PROFILES`
- **Isolated networking** - All services on `n8nInstall_network`
- **Reverse proxy pattern** - Caddy handles all external HTTPS access
- **Prefixed naming** - All resources use `n8nInstall_` prefix
- **Shared secrets** - Core services (Postgres, Redis, Caddy) always included

```
┌─────────────────────────────────────────────────────────────┐
│                     External HTTPS Traffic                   │
│                    (ports 80/443 only)                       │
└──────────────────────────┬──────────────────────────────────┘
                           │
                           ▼
                  ┌────────────────┐
                  │  Caddy Proxy   │  ← Automatic HTTPS
                  │  (n8nInstall_) │  ← Basic Auth
                  └────────┬───────┘
                           │
         ┌─────────────────┼─────────────────┐
         │    n8nInstall_network (isolated)  │
         │                                    │
         │  ┌──────┐  ┌──────┐  ┌──────┐    │
         │  │ n8n  │  │Postgres│ │Redis│    │  ← Core
         │  └──────┘  └──────┘  └──────┘    │
         │                                    │
         │  ┌─────────┐  ┌────────┐         │
         │  │ Flowise │  │ Grafana│  ...    │  ← Optional (profiles)
         │  └─────────┘  └────────┘         │
         │                                    │
         └────────────────────────────────────┘
```

---

## 🔧 Profile System

### How Profiles Work

Profiles are defined in `docker-compose.yml` and activated via `COMPOSE_PROFILES` in `.env`:

```yaml
# docker-compose.yml
services:
  flowise:
    profiles: ["flowise"]  # Only starts when "flowise" profile is active
    # ...

  grafana:
    profiles: ["monitoring"]  # Only starts with "monitoring" profile
    # ...
```

```bash
# .env
COMPOSE_PROFILES=["n8n","flowise","monitoring"]
```

### Core vs Optional Services

**Core Services (no profile required):**
- `postgres` - Database for n8n, Langfuse, and other services
- `redis` (or `valkey`) - Queue backend for n8n
- `caddy` - Reverse proxy and HTTPS termination

**Optional Services (profile-based):**
- `n8n` - Workflow automation (main app + workers + import)
- `flowise` - AI agent builder
- `monitoring` - Prometheus, Grafana, cAdvisor, node-exporter
- `langfuse` - Observability (ClickHouse, MinIO, worker, web)
- `ollama` - Local LLM inference (with hardware profiles: `cpu`, `gpu-nvidia`, `gpu-amd`)
- `pgadmin` - Postgres web UI
- `cloudflare-tunnel` - Cloudflare Tunnel for zero-trust access

### Profile Activation

**At install time:**
```bash
# Wizard (scripts/04_wizard.sh) prompts user to select services
# Selected profiles are written to COMPOSE_PROFILES in .env

# Example result:
COMPOSE_PROFILES=["n8n","flowise","monitoring","pgadmin"]
```

**Manually modifying profiles:**
```bash
# Edit .env
COMPOSE_PROFILES=["n8n","flowise","pgadmin"]

# Apply changes
docker compose -p localai up -d

# Unused profile services will stop automatically
```

**Checking active profiles:**
```bash
# View current profiles
grep COMPOSE_PROFILES .env

# List running services
docker compose -p localai ps

# Check if specific profile is active (in scripts)
function is_profile_active() {
    local profile_name="$1"
    grep -q "\"${profile_name}\"" <<< "${COMPOSE_PROFILES:-}" || \
    grep -q "${profile_name}" <<< "${COMPOSE_PROFILES:-}"
}
```

---

## 🌐 Network Architecture

### Isolated Network

All services communicate via a dedicated Docker network:

```yaml
# docker-compose.yml
networks:
  n8nInstall_network:
    driver: bridge
    name: n8nInstall_network

services:
  n8n:
    networks:
      - n8nInstall_network
```

**Benefits:**
- **Isolation** - Services can't access other Docker containers on the host
- **Internal DNS** - Services resolve each other by container name (e.g., `n8nInstall_postgres`)
- **Security** - Attack surface limited to Caddy's exposed ports

**Network resolution examples:**
```bash
# From n8n container, connect to Postgres
psql -h n8nInstall_postgres -U n8n -d n8n

# From any container, ping Redis
ping n8nInstall_redis
```

### Port Exposure Strategy

**❌ Services NEVER expose ports directly:**
```yaml
# WRONG - don't do this
services:
  flowise:
    ports:
      - "3000:3000"  # Exposes port to host
```

**✅ Only Caddy exposes ports:**
```yaml
# CORRECT - only Caddy exposes 80/443
services:
  caddy:
    ports:
      - "80:80"
      - "443:443"
    # All other services accessed via reverse proxy
```

**Rationale:**
- Single point of HTTPS termination
- Consistent authentication (Basic Auth)
- Simplified firewall rules
- Certificate management in one place

---

## 🔀 Reverse Proxy Pattern (Caddy)

### Request Flow

```
User Request (HTTPS)
  ↓
Caddy (port 443)
  ↓ Check hostname
  ↓ Apply Basic Auth (if configured)
  ↓
Internal Service (on n8nInstall_network)
  ↓
Response back through Caddy
  ↓
User (with valid HTTPS certificate)
```

### Caddyfile Structure

```caddyfile
# Service: n8n
# Profile: n8n
{$N8N_HOSTNAME} {
    basicauth {
        {$N8N_BASIC_AUTH_USER} {$N8N_BASIC_AUTH_PASSWORD_HASH}
    }
    reverse_proxy n8nInstall_n8n:5678
}

# Service: Flowise
# Profile: flowise
{$FLOWISE_HOSTNAME} {
    reverse_proxy n8nInstall_flowise:3000
}

# Service: Grafana
# Profile: monitoring
{$GRAFANA_HOSTNAME} {
    basicauth {
        {$GRAFANA_USER} {$GRAFANA_PASSWORD_HASH}
    }
    reverse_proxy n8nInstall_grafana:3000
}
```

### Hostname Management

**Pattern:** Each service gets a `_HOSTNAME` environment variable:

```bash
# .env.example
N8N_HOSTNAME=n8n.yourdomain.com
FLOWISE_HOSTNAME=flowise.yourdomain.com
GRAFANA_HOSTNAME=grafana.yourdomain.com
```

**Wildcard DNS setup (recommended):**
```
# DNS configuration
*.yourdomain.com  →  <server-ip>

# Allows services to use subdomains without individual DNS entries
```

**Local development:**
```bash
# Use .localhost domains (no DNS needed)
N8N_HOSTNAME=n8n.localhost
FLOWISE_HOSTNAME=flowise.localhost

# Caddy automatically uses self-signed certificates
```

---

## 🏷️ Naming Conventions

### Container Names

**Pattern:** `n8nInstall_<service-name>`

```yaml
services:
  postgres:
    container_name: n8nInstall_postgres

  n8n:
    container_name: n8nInstall_n8n

  flowise:
    container_name: n8nInstall_flowise
```

**Benefits:**
- Easy identification: `docker ps | grep n8nInstall`
- No conflicts with other containers
- Clear ownership of resources

### Volume Names

**Pattern:** `n8nInstall_<service>_<purpose>`

```yaml
volumes:
  n8nInstall_postgres_data:
    name: n8nInstall_postgres_data

  n8nInstall_n8n_storage:
    name: n8nInstall_n8n_storage

  n8nInstall_caddy_data:
    name: n8nInstall_caddy_data
```

### Network Name

**Pattern:** `n8nInstall_network` (singular, shared by all)

```yaml
networks:
  n8nInstall_network:
    name: n8nInstall_network
```

---

## 📦 Service Dependency Model

### Dependency Graph

```
Caddy
  └─ (no dependencies, standalone)

n8n
  ├─ depends_on: postgres (healthy)
  ├─ depends_on: redis (healthy)
  └─ depends_on: caddy (started, for bcrypt hashing during install)

Flowise
  └─ (no dependencies, standalone)

Grafana
  └─ depends_on: prometheus (started)

Langfuse-web
  ├─ depends_on: postgres (healthy)
  ├─ depends_on: clickhouse (healthy)
  └─ depends_on: minio (started)
```

### Healthcheck-Based Startup

```yaml
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 10s
      timeout: 5s
      retries: 5

  n8n:
    depends_on:
      postgres:
        condition: service_healthy  # Waits for postgres healthcheck
      redis:
        condition: service_healthy
```

**Best practice:** Always define healthchecks for services that other services depend on.

---

## 🔄 n8n Queue Architecture

n8n runs in **queue mode** with Redis as the message broker:

```
┌──────────┐
│ n8n      │  ← Main web UI and API
│ (main)   │  ← Queues workflows to Redis
└────┬─────┘
     │
     ▼
┌──────────┐
│  Redis   │  ← Queue backend (or Valkey)
│ (queue)  │
└────┬─────┘
     │
     ▼
┌──────────────────────────┐
│  n8n-worker (scaled)     │  ← Executes workflows
│  Instances: N8N_WORKER_  │     from queue
│             COUNT         │
└──────────────────────────┘
```

**Configuration:**
```yaml
# docker-compose.yml
services:
  n8n:
    environment:
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=n8nInstall_redis

  n8n-worker:
    environment:
      - EXECUTIONS_MODE=queue
      - QUEUE_BULL_REDIS_HOST=n8nInstall_redis
```

**Scaling workers:**
```bash
# Set in .env
N8N_WORKER_COUNT=3

# Apply
docker compose -p localai up -d --scale n8n-worker=3
```

---

## 💾 Data Persistence

### Volume Strategy

**Named volumes (preferred):**
- Managed by Docker
- Survive container recreation
- Easy backup: `docker run --rm -v n8nInstall_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres.tar.gz /data`

**Bind mounts (when needed):**
- Direct host filesystem access
- Example: `./shared:/data/shared` for n8n custom scripts

### Volume Mapping

| Service | Volume | Purpose | Type |
|---------|--------|---------|------|
| Postgres | `n8nInstall_postgres_data` | Database files | Named |
| n8n | `n8nInstall_n8n_storage` | Workflow data, credentials | Named |
| Caddy | `n8nInstall_caddy_data` | TLS certificates | Named |
| Redis | `n8nInstall_redis_data` | Queue persistence | Named |
| n8n | `./shared:/data/shared` | Shared scripts/files | Bind |

---

## 🔐 Secret Propagation

Secrets are generated once and shared across services:

```bash
# .env (generated by scripts/03_generate_secrets.sh)
POSTGRES_PASSWORD=<generated>
N8N_ENCRYPTION_KEY=<generated>

# Used by multiple services:
# - Postgres container
# - n8n (connects to Postgres)
# - Langfuse (connects to Postgres)
```

**Pattern:** Core services generate secrets; dependent services consume them.

---

## 📊 Architecture Patterns

### Multi-Tenant Services

Some services support multiple databases/users:

```sql
-- postgres/init-databases.sql
CREATE DATABASE n8n;
CREATE DATABASE langfuse;

-- Services connect to their respective databases
-- n8n → n8n database
-- Langfuse → langfuse database
```

### Optional Hardware Profiles (Ollama)

Mutually exclusive profiles for GPU support:

```yaml
services:
  ollama-cpu:
    profiles: ["cpu"]
    # No GPU passthrough

  ollama-nvidia:
    profiles: ["gpu-nvidia"]
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Usage:**
```bash
# Choose one profile in wizard
COMPOSE_PROFILES=["n8n","cpu"]  # OR ["n8n","gpu-nvidia"] OR ["n8n","gpu-amd"]
```

---

## ✅ Architecture Validation

**Check compliance with architecture principles:**

```bash
# 1. All containers have prefix
docker ps --format '{{.Names}}' | grep -v "^n8nInstall_" && echo "FAIL: Unprefixed containers found"

# 2. All containers on correct network
docker network inspect n8nInstall_network --format '{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'

# 3. No services expose ports (except Caddy)
docker compose -p localai config | grep -A2 "ports:" | grep -v "caddy" && echo "FAIL: Non-Caddy ports exposed"

# 4. All volumes have prefix
docker volume ls --format '{{.Name}}' | grep "^n8nInstall_"
```

---

## 🔗 Related Documentation

- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) - Docker Compose technical details
- [CONFIGURATION-MANAGEMENT.md](./CONFIGURATION-MANAGEMENT.md) - Profile and env var management
- [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md) - Complete service catalog

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
