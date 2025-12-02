# Infrastructure

**Scope:** Docker Compose technical details, service dependencies, healthchecks, and volume management.

---

## 🎯 Overview

This document covers the **technical implementation details** of the Docker Compose infrastructure. For architecture patterns and design decisions, see [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md).

---

## 📋 Docker Compose Structure

### Project Configuration

```yaml
# docker-compose.yml (top-level)
version: "3.8"  # or latest

name: localai  # Project name (used in: docker compose -p localai)

networks:
  n8nInstall_network:
    driver: bridge
    name: n8nInstall_network

volumes:
  # Named volumes for persistent data
  n8nInstall_postgres_data:
  n8nInstall_n8n_storage:
  n8nInstall_caddy_data:
  n8nInstall_redis_data:
  # ... (one per service needing persistence)
```

### Service Template

```yaml
service-name:
  profiles: ["profile-name"]              # Optional: profile-based activation
  container_name: n8nInstall_service-name # Required: consistent naming
  image: vendor/image:version             # Required: pinned version
  restart: unless-stopped                 # Required: auto-restart policy

  networks:
    - n8nInstall_network                  # Required: isolated network

  environment:                            # Required: config via env vars
    - VAR_NAME=${VAR_NAME}
    - VAR_WITH_DEFAULT=${VAR:-default}

  volumes:                                # Optional: data persistence
    - service_data:/data

  depends_on:                             # Optional: startup order
    dependency:
      condition: service_healthy

  healthcheck:                            # Recommended: for dependencies
    test: ["CMD-SHELL", "command"]
    interval: 30s
    timeout: 10s
    retries: 5
    start_period: 40s

  # NO ports: section (except Caddy)
```

---

## 🏥 Healthcheck Patterns

### Purpose

Healthchecks enable:
1. **Ordered startup** - Services wait for dependencies to be healthy
2. **Auto-recovery** - Docker restarts unhealthy containers
3. **Status visibility** - `docker ps` shows health status

### Common Healthcheck Patterns

#### HTTP-based Services

```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 5
  start_period: 40s  # Grace period for slow startup
```

#### Database Services (Postgres)

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
  interval: 10s
  timeout: 5s
  retries: 5
```

#### Redis/Valkey

```yaml
healthcheck:
  test: ["CMD", "redis-cli", "ping"]
  interval: 10s
  timeout: 5s
  retries: 5
```

#### Custom Script-based

```yaml
healthcheck:
  test: ["CMD-SHELL", "/usr/local/bin/healthcheck.sh"]
  interval: 30s
  timeout: 10s
  retries: 3
```

### Healthcheck Best Practices

1. **Use meaningful tests** - Check actual service readiness, not just process existence
2. **Set realistic intervals** - Balance responsiveness vs overhead (30s is common)
3. **Allow startup time** - Use `start_period` for slow-starting services
4. **Keep tests lightweight** - Healthchecks run frequently, avoid heavy operations
5. **Return proper exit codes** - 0 = healthy, 1 = unhealthy

**Example of dependency chain:**
```yaml
services:
  postgres:
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U n8n"]

  redis:
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]

  n8n:
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    # n8n waits until both postgres and redis are healthy
```

---

## 🔗 Service Dependencies

### Dependency Types

Docker Compose supports three dependency conditions:

```yaml
depends_on:
  service1:
    condition: service_started    # Default: service has started (may not be ready)
  service2:
    condition: service_healthy    # Service is healthy (requires healthcheck)
  service3:
    condition: service_completed_successfully  # For one-off tasks
```

### Dependency Graph (n8n-install)

```
Core Layer (no dependencies):
├─ postgres (healthcheck: pg_isready)
├─ redis (healthcheck: redis-cli ping)
└─ caddy (healthcheck: wget /health)

Application Layer:
├─ n8n → postgres (healthy), redis (healthy)
├─ n8n-worker → postgres (healthy), redis (healthy)
├─ n8n-import → n8n (started)
├─ flowise → (no dependencies)
└─ langfuse-web → postgres (healthy), clickhouse (healthy)

Monitoring Layer:
├─ grafana → prometheus (started)
├─ prometheus → (no dependencies)
├─ cadvisor → (no dependencies)
└─ node-exporter → (no dependencies)

Admin Tools:
└─ pgadmin → (no dependencies, can access postgres via network)
```

### Circular Dependencies (Avoid)

**❌ WRONG:**
```yaml
# This will fail!
service-a:
  depends_on:
    service-b:
      condition: service_started

service-b:
  depends_on:
    service-a:
      condition: service_started
```

**✅ CORRECT:** Use healthchecks or remove unnecessary dependencies:
```yaml
# Both services start independently
service-a:
  # No depends_on

service-b:
  # No depends_on

# Services discover each other via network after both are running
```

---

## 💾 Volume Management

### Named Volumes (Preferred)

**Definition:**
```yaml
volumes:
  n8nInstall_postgres_data:
    name: n8nInstall_postgres_data  # Explicit naming
```

**Usage:**
```yaml
services:
  postgres:
    volumes:
      - n8nInstall_postgres_data:/var/lib/postgresql/data
```

**Benefits:**
- Managed by Docker (lifecycle, backups)
- Survive container deletion
- Work across platforms (Windows, Linux, macOS)
- Better performance on macOS/Windows than bind mounts

**Operations:**
```bash
# List volumes
docker volume ls | grep n8nInstall

# Inspect volume
docker volume inspect n8nInstall_postgres_data

# Backup volume
docker run --rm \
  -v n8nInstall_postgres_data:/data \
  -v $(pwd):/backup \
  alpine tar czf /backup/postgres-data.tar.gz /data

# Restore volume
docker run --rm \
  -v n8nInstall_postgres_data:/data \
  -v $(pwd):/backup \
  alpine tar xzf /backup/postgres-data.tar.gz -C /

# Remove volume (destructive!)
docker volume rm n8nInstall_postgres_data
```

### Bind Mounts (When Needed)

**Usage:**
```yaml
services:
  n8n:
    volumes:
      - ./shared:/data/shared  # Host path : Container path
      - ./postgres/init-databases.sql:/docker-entrypoint-initdb.d/init.sql:ro  # Read-only
```

**When to use:**
- Configuration files that need manual editing (Caddyfile, init scripts)
- Shared data between host and container (n8n `/data/shared`)
- Development/debugging (mount source code)

**Cautions:**
- Permissions can be tricky (especially on Linux)
- Performance overhead on macOS/Windows
- Tight coupling to host filesystem

### tmpfs Mounts (Temporary Data)

**Usage:**
```yaml
services:
  service-name:
    tmpfs:
      - /tmp
      - /var/run
```

**When to use:**
- Temporary files that don't need persistence
- Security: data cleared on container stop
- Performance: RAM is faster than disk

---

## 🌐 Network Configuration

### Bridge Network (Default)

```yaml
networks:
  n8nInstall_network:
    driver: bridge
    name: n8nInstall_network
```

**Characteristics:**
- Containers can communicate via container name (DNS resolution)
- Isolated from host network by default
- No direct access from host (except via exposed ports)

**DNS resolution example:**
```bash
# From n8n container
ping n8nInstall_postgres  # Resolves to Postgres container IP
```

### Network Inspection

```bash
# List all containers on network
docker network inspect n8nInstall_network

# Check which networks a container is on
docker inspect n8nInstall_n8n --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}'

# Test connectivity between containers
docker exec n8nInstall_n8n ping -c 1 n8nInstall_postgres
```

### Network Isolation Benefits

1. **Security** - Services can't access other Docker containers outside this network
2. **Naming** - Consistent container names without conflicts
3. **Portability** - Network config travels with docker-compose.yml

---

## 🔄 Restart Policies

### Policy Options

```yaml
restart: "no"              # Never restart (default)
restart: always            # Always restart, even after reboot
restart: on-failure        # Restart only if exits with non-zero code
restart: unless-stopped    # Restart unless manually stopped (RECOMMENDED)
```

### Recommended Policy: `unless-stopped`

**Rationale:**
- Survives host reboots (services auto-start)
- Respects manual stops (doesn't restart if you `docker stop`)
- Balances automation and control

**Example:**
```yaml
services:
  postgres:
    restart: unless-stopped
    # If container crashes → restarts automatically
    # If you run `docker stop n8nInstall_postgres` → stays stopped
    # If host reboots → starts automatically
```

### Restart Backoff

Docker automatically implements exponential backoff:
- First restart: immediate
- Second restart: wait a few seconds
- Subsequent restarts: wait longer each time (up to a limit)

**View restart count:**
```bash
docker inspect n8nInstall_n8n --format='{{.RestartCount}}'
```

---

## 📦 Image Management

### Version Pinning

**✅ RECOMMENDED:**
```yaml
image: n8nio/n8n:1.20.0  # Pin specific version
```

**⚠️ CAUTION:**
```yaml
image: n8nio/n8n:latest  # May break on updates
```

**Rationale:**
- Predictable behavior (version won't change unexpectedly)
- Controlled updates (test new versions before deploying)
- Rollback capability (can revert to previous version)

### Image Update Strategy

```bash
# 1. Check current version
docker compose -p localai images

# 2. Update docker-compose.yml with new version
# Edit: n8nio/n8n:1.20.0 → n8nio/n8n:1.21.0

# 3. Pull new image
docker compose -p localai pull n8n

# 4. Recreate container with new image
docker compose -p localai up -d --no-deps --force-recreate n8n

# 5. Verify service works
docker logs n8nInstall_n8n --tail=50
```

### Image Cleanup

```bash
# Remove unused images
docker image prune -a

# Remove specific old version
docker rmi n8nio/n8n:1.19.0
```

---

## 🛠️ Resource Management

### CPU Limits

```yaml
services:
  ollama:
    deploy:
      resources:
        limits:
          cpus: '4.0'      # Max 4 CPU cores
        reservations:
          cpus: '2.0'      # Reserve 2 cores minimum
```

### Memory Limits

```yaml
services:
  postgres:
    deploy:
      resources:
        limits:
          memory: 2G       # Max 2GB RAM
        reservations:
          memory: 512M     # Reserve 512MB minimum
```

### GPU Passthrough (Ollama)

```yaml
services:
  ollama-nvidia:
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
```

**Check GPU availability:**
```bash
# Inside container
docker exec n8nInstall_ollama-nvidia nvidia-smi
```

---

## 🔍 Logging Configuration

### Log Drivers

```yaml
services:
  n8n:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"      # Max log file size
        max-file: "3"        # Keep 3 rotated files
```

**Rationale:** Prevents logs from consuming unlimited disk space.

### Viewing Logs

```bash
# Tail logs
docker compose -p localai logs -f --tail=200 n8n

# All services logs
docker compose -p localai logs -f

# Since timestamp
docker compose -p localai logs --since 2h

# Save logs to file
docker compose -p localai logs n8n > n8n-logs.txt
```

---

## ✅ Infrastructure Validation Checklist

After changes to docker-compose.yml:

- [ ] YAML syntax valid: `docker compose -p localai config > /dev/null`
- [ ] All services have `n8nInstall_` prefix
- [ ] No ports exposed (except Caddy: 80, 443)
- [ ] All services use `n8nInstall_network`
- [ ] Healthchecks defined for dependency services
- [ ] Restart policy: `unless-stopped`
- [ ] Image versions pinned (not `:latest`)
- [ ] Environment variables use `.env` references
- [ ] Volumes use named volumes (or justified bind mounts)

---

## 🔗 Related Documentation

- [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md) - Architecture patterns and design
- [CONFIGURATION-MANAGEMENT.md](./CONFIGURATION-MANAGEMENT.md) - Environment variables
- [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md) - Service catalog

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
