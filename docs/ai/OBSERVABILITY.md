# Observability

**Scope:** Logging strategy, monitoring setup, health checks, status reporting, and Grafana dashboards.

---

## 🎯 Observability Goals

1. **Quick Diagnosis** - Identify issues in <5 minutes
2. **Proactive Alerting** - Know about problems before users report them
3. **Performance Tracking** - Monitor resource usage and bottlenecks
4. **Audit Trail** - Log access and changes for security/compliance

---

## 📊 Monitoring Stack (Profile: `monitoring`)

### Components

When the `monitoring` profile is enabled:

```yaml
# docker-compose.yml
services:
  prometheus:      # Time-series metrics database
  grafana:         # Visualization and dashboards
  cadvisor:        # Container metrics collector
  node-exporter:   # Host system metrics
```

**Data flow:**
```
node-exporter  →  Prometheus  →  Grafana
cadvisor       ↗             ↘  Dashboards
                              Alerts
```

### Setup

```bash
# Enable monitoring profile
# Edit .env:
COMPOSE_PROFILES=["n8n","monitoring"]

# Start services
docker compose -p localai up -d

# Access Grafana
https://${GRAFANA_HOSTNAME}
# Login: ${GRAFANA_USER} / ${GRAFANA_PASSWORD}
```

### Default Dashboards

Grafana comes with preconfigured dashboards:

1. **Docker Host & Container Overview** - CPU, memory, disk, network per container
2. **n8n Workflow Metrics** - Execution times, success/failure rates (if n8n metrics enabled)
3. **PostgreSQL Metrics** - Connections, query performance, database size
4. **System Resources** - Node-level CPU, memory, disk I/O

**Accessing dashboards:**
- Grafana UI → Dashboards → Browse
- Look for "n8n-install" folder

---

## 📝 Logging Strategy

### Log Levels

**Standard levels across all services:**
- `ERROR` - Service failures, exceptions
- `WARN` - Potential issues, degraded performance
- `INFO` - Normal operations, startup/shutdown
- `DEBUG` - Detailed troubleshooting info

### Log Locations

**Container logs (via Docker):**
```bash
# View specific service logs
docker logs n8nInstall_n8n

# Follow logs in real-time
docker compose -p localai logs -f n8n

# Last 200 lines
docker compose -p localai logs --tail=200 n8n

# Since timestamp
docker compose -p localai logs --since 2h n8n

# Multiple services
docker compose -p localai logs -f n8n postgres redis
```

**Persistent logs (optional):**
```yaml
# Add to docker-compose.yml if needed
services:
  n8n:
    volumes:
      - ./logs/n8n:/var/log/n8n  # Persist logs to host
```

### Log Rotation

**Docker's default log rotation:**
```yaml
services:
  n8n:
    logging:
      driver: "json-file"
      options:
        max-size: "10m"      # Max file size: 10MB
        max-file: "3"        # Keep 3 files (30MB total)
```

**Benefits:**
- Prevents disk space exhaustion
- Automatic cleanup of old logs
- No manual rotation needed

---

## 🏥 Health Checks

### Built-in Docker Healthchecks

**View health status:**
```bash
# All services
docker compose -p localai ps

# Specific service health
docker inspect n8nInstall_n8n --format='{{.State.Health.Status}}'
# Output: healthy, unhealthy, or starting
```

### Manual Health Checks

**Per-service validation:**

#### n8n
```bash
# Check web UI responds
curl -k -I https://${N8N_HOSTNAME}
# Expected: 200 or 401 (if auth enabled)

# Check n8n healthcheck endpoint
docker exec n8nInstall_n8n wget -qO- http://localhost:5678/healthz
```

#### Postgres
```bash
# Check database is ready
docker exec n8nInstall_postgres pg_isready -U n8n
# Expected: accepting connections

# Check specific database exists
docker exec n8nInstall_postgres psql -U n8n -lqt | cut -d \| -f 1 | grep -qw n8n
```

#### Redis
```bash
# Check Redis responds
docker exec n8nInstall_redis redis-cli ping
# Expected: PONG
```

#### Caddy
```bash
# Check Caddy config is valid
docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile

# Check certificates
docker exec n8nInstall_caddy caddy list-certificates
```

---

## 🚨 Status Reporter Script

**Location:** `scripts/status_report.sh`

### Purpose

Interactive menu-driven tool to quickly check system health and gather diagnostics.

### Usage

```bash
# Run status reporter
bash scripts/status_report.sh

# Menu options:
# 1. All Services Overview
# 2. n8n Detailed Status
# 3. Database Status
# 4. Network Status
# 5. Resource Usage
# 6. Recent Errors (last 1 hour)
# 7. Generate Full Diagnostic Report
# 8. Exit
```

### Features

**Option 1: All Services Overview**
- Lists all n8nInstall containers
- Shows status (Up/Exited/Restarting)
- Shows health status (if healthcheck defined)
- Shows uptime

**Option 2: n8n Detailed Status**
- n8n version
- Worker count and status
- Queue status (Redis connection)
- Database connection
- Recent errors from logs

**Option 3: Database Status**
- Postgres version
- Database size
- Connection count
- List of databases
- Table counts (n8n, langfuse)

**Option 4: Network Status**
- Network exists: n8nInstall_network
- Containers on network
- DNS resolution test (ping between services)
- External connectivity (ping 8.8.8.8)

**Option 5: Resource Usage**
- CPU usage per container
- Memory usage per container
- Disk usage per volume
- Network I/O

**Option 6: Recent Errors**
- Scans all container logs for ERROR/FATAL/WARN
- Groups by service
- Shows last 50 error lines

**Option 7: Generate Full Diagnostic Report**
- Combines all above checks
- Saves to `diagnostic-report-YYYY-MM-DD-HHMMSS.txt`
- Useful for troubleshooting or support requests

---

## 📈 Metrics Collection

### n8n Metrics (Optional)

Enable n8n Prometheus metrics:

```bash
# Add to .env
N8N_METRICS=true
N8N_METRICS_PREFIX=n8n_

# n8n exposes metrics at http://localhost:5678/metrics
```

**Available metrics:**
- `n8n_workflow_executions_total` - Total workflow runs
- `n8n_workflow_execution_duration_seconds` - Execution time
- `n8n_workflow_execution_status` - Success/failure counts

**Scrape with Prometheus:**
```yaml
# prometheus.yml (in Prometheus container)
scrape_configs:
  - job_name: 'n8n'
    static_configs:
      - targets: ['n8nInstall_n8n:5678']
```

### Container Metrics (cAdvisor)

cAdvisor automatically collects:
- CPU usage (cores, percentage)
- Memory usage (bytes, limits)
- Network I/O (bytes sent/received)
- Disk I/O (read/write operations)

**Access cAdvisor:**
```bash
# View raw metrics
curl http://<server-ip>:8080/metrics

# Or use Grafana dashboards (preferred)
```

### System Metrics (node-exporter)

node-exporter collects host-level metrics:
- CPU load average
- Disk space available
- Memory usage (total, available, cached)
- Network traffic

---

## 🔔 Alerting (Grafana)

### Setting Up Alerts

**Example: Alert on high memory usage**

1. **Create alert in Grafana:**
   - Navigate to dashboard
   - Edit panel (e.g., "Container Memory Usage")
   - Add alert rule:
     ```
     WHEN max() OF query(A, 5m, now) > 80%
     FOR 5m
     ```

2. **Configure notification channel:**
   - Grafana → Alerting → Notification channels
   - Add email, Slack, webhook, etc.

3. **Test alert:**
   - Trigger condition (run memory-heavy workflow)
   - Verify notification received

### Recommended Alerts

**Critical:**
- Container down (any n8nInstall service stopped)
- Postgres connection failure
- Disk space <10% remaining

**Warning:**
- Memory usage >80% for >5 minutes
- CPU usage >90% for >10 minutes
- n8n workflow failure rate >20%

---

## 🔍 Troubleshooting Workflows

### Issue: Service Not Responding

**Steps:**
```bash
# 1. Check container status
docker compose -p localai ps <service>

# 2. Check logs for errors
docker compose -p localai logs --tail=100 <service> | grep -i error

# 3. Check healthcheck status
docker inspect n8nInstall_<service> --format='{{.State.Health.Status}}'

# 4. Restart service
docker compose -p localai up -d --force-recreate <service>

# 5. Verify recovery
bash scripts/status_report.sh
```

### Issue: High CPU/Memory Usage

**Steps:**
```bash
# 1. Identify culprit
docker stats --no-stream | grep n8nInstall

# 2. Check service logs
docker logs n8nInstall_<service> --tail=200

# 3. If n8n: Check workflow executions
# Access n8n UI → Executions → Filter by "running"

# 4. If Postgres: Check active queries
docker exec n8nInstall_postgres psql -U n8n -c "SELECT pid, query, state FROM pg_stat_activity WHERE state != 'idle';"

# 5. Adjust resources if needed (docker-compose.yml)
# Add memory limits or increase worker count
```

### Issue: Network Connectivity Problems

**Steps:**
```bash
# 1. Verify network exists
docker network inspect n8nInstall_network

# 2. Check all containers are on network
docker network inspect n8nInstall_network --format='{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'

# 3. Test DNS resolution between containers
docker exec n8nInstall_n8n ping -c 1 n8nInstall_postgres

# 4. Check external connectivity
docker exec n8nInstall_n8n ping -c 1 8.8.8.8

# 5. Restart networking stack
docker compose -p localai down && docker compose -p localai up -d
```

---

## 📊 Performance Monitoring

### Key Metrics to Track

**n8n Performance:**
- Average workflow execution time
- Queue depth (pending workflows in Redis)
- Worker utilization (active vs idle workers)
- Webhook response time

**Database Performance:**
- Query duration (slow queries >1s)
- Connection pool usage
- Database size growth rate
- Cache hit ratio

**System Performance:**
- CPU usage (per container and host)
- Memory usage (per container and host)
- Disk I/O (read/write throughput)
- Network bandwidth (ingress/egress)

### Baseline Metrics

**Establish baselines for normal operation:**
```bash
# Capture baseline during low-load period
docker stats --no-stream > baseline-metrics.txt

# Compare during high-load
docker stats --no-stream > high-load-metrics.txt
diff baseline-metrics.txt high-load-metrics.txt
```

---

## 🛠️ Log Analysis Tools

### Quick Log Searches

```bash
# Find all errors in last 24 hours
docker compose -p localai logs --since 24h | grep -i error

# Count errors per service
for service in n8n postgres redis caddy; do
    echo "$service: $(docker logs n8nInstall_$service 2>&1 | grep -ci error)"
done

# Find specific pattern (e.g., authentication failures)
docker logs n8nInstall_caddy | grep " 401 "

# Extract timestamps of service restarts
docker inspect n8nInstall_n8n --format='{{.State.StartedAt}}'
```

### Centralized Logging (Optional)

**For production environments, consider:**
- **Loki** - Log aggregation (integrates with Grafana)
- **ELK Stack** - Elasticsearch, Logstash, Kibana
- **Graylog** - Open-source log management

**Example: Adding Loki:**
```yaml
# docker-compose.yml
services:
  loki:
    profiles: ["monitoring"]
    image: grafana/loki:latest
    # ... configuration ...

  # Update other services to use Loki log driver
  n8n:
    logging:
      driver: loki
      options:
        loki-url: "http://n8nInstall_loki:3100/loki/api/v1/push"
```

---

## ✅ Observability Checklist

**Before going to production:**

- [ ] Monitoring profile enabled (`monitoring` in COMPOSE_PROFILES)
- [ ] Grafana dashboards configured and accessible
- [ ] Critical alerts configured (service down, disk space, memory)
- [ ] Notification channels set up (email/Slack)
- [ ] Log rotation configured (max-size, max-file)
- [ ] Healthchecks defined for all critical services
- [ ] Status reporter script tested and working
- [ ] Baseline metrics captured for normal operation
- [ ] Incident response plan documented (see [ERROR-HANDLING.md](./ERROR-HANDLING.md))

---

## 🔗 Related Documentation

- [ERROR-HANDLING.md](./ERROR-HANDLING.md) - Debugging and recovery procedures
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Common issues and solutions
- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) - Healthcheck configuration

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
