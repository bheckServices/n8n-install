# Testing Standards

**Scope:** Manual testing procedures, validation workflows, and smoke tests for the n8n-install infrastructure project.

---

## 🎯 Testing Philosophy

Since this is a Docker-based infrastructure installer, we use **manual testing with structured validation checklists** rather than automated unit tests.

**Goals:**
1. **Catch issues before deployment** - Validate on test VMs before production
2. **Prevent regressions** - Ensure updates don't break existing functionality
3. **Document expected behavior** - Make implicit expectations explicit
4. **Enable rollback decisions** - Quickly verify if a change is safe

---

## 🧪 Testing Pyramid (Infrastructure Edition)

```
┌─────────────────────────────┐
│  Integration Tests          │  ← Full install on clean VM
│  (End-to-End Validation)    │     Most important for infra
├─────────────────────────────┤
│  Service-Level Tests        │  ← Individual service health checks
│  (Component Validation)     │
├─────────────────────────────┤
│  Smoke Tests                │  ← Quick sanity checks after changes
│  (Fast Feedback)            │     "Does it still start?"
└─────────────────────────────┘
```

---

## ✅ Smoke Test Checklist

**When to run:** After any script change, before committing.

**Time:** ~2-5 minutes

**Prerequisites:** Existing n8n-install instance

### Script Changes

```bash
# 1. Syntax validation
bash -n scripts/<changed-script>.sh

# 2. Dry-run if possible
# (Not always applicable, but check for obvious issues)

# 3. Run status reporter to ensure services still work
bash scripts/status_report.sh
# Select option 1 (All Services Overview)

# 4. Verify core services respond
curl -k https://${N8N_HOSTNAME} -I  # Should return 200 or 401
docker compose -p localai ps  # All should show "Up" or "healthy"
```

### Docker Compose Changes

```bash
# 1. Validate YAML syntax
docker compose -p localai config > /dev/null

# 2. Check for port exposure (should be none except Caddy)
docker compose -p localai config | grep -A2 "ports:"
# Only caddy should expose 80/443

# 3. Restart affected service
docker compose -p localai up -d --no-deps --force-recreate <service>

# 4. Check service logs
docker compose -p localai logs -f --tail=50 <service>
```

### Caddyfile Changes

```bash
# 1. Validate Caddy config
docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile

# 2. Reload Caddy (graceful, no downtime)
docker exec n8nInstall_caddy caddy reload --config /etc/caddy/Caddyfile

# 3. Test HTTPS access
curl -k https://${SERVICE_HOSTNAME} -I
```

---

## 🔍 Service-Level Validation

**When to run:** After adding/modifying a service, before marking AIP complete.

**Time:** ~5-10 minutes per service

### Template: Service Health Check

For each service, verify these dimensions:

#### 1. Container Health
```bash
# Check container is running
docker compose -p localai ps <service>

# Check healthcheck status (if defined)
docker inspect n8nInstall_<service> --format='{{.State.Health.Status}}'

# Check logs for errors (last 100 lines)
docker compose -p localai logs --tail=100 <service> | grep -i error
```

#### 2. Network Connectivity
```bash
# Verify service is on correct network
docker inspect n8nInstall_<service> --format='{{range $k, $v := .NetworkSettings.Networks}}{{$k}}{{end}}'
# Should show: n8nInstall_network

# Check internal DNS resolution
docker exec n8nInstall_<service> ping -c 1 n8nInstall_postgres
docker exec n8nInstall_<service> ping -c 1 n8nInstall_redis
```

#### 3. Configuration Validation
```bash
# Verify env vars are loaded
docker exec n8nInstall_<service> env | grep <VAR_NAME>

# Check volume mounts
docker inspect n8nInstall_<service> --format='{{range .Mounts}}{{.Source}} -> {{.Destination}}{{"\n"}}{{end}}'
```

#### 4. External Access (if applicable)
```bash
# Test Caddy reverse proxy
curl -k https://${SERVICE_HOSTNAME} -I
# Expected: 200 OK or 401 Unauthorized (if basic auth enabled)

# Test basic auth (if configured)
curl -k -u "${SERVICE_USER}:${SERVICE_PASSWORD}" https://${SERVICE_HOSTNAME} -I
# Expected: 200 OK
```

#### 5. Functional Validation
```bash
# Service-specific checks:

# n8n: Can access workflows page
curl -k -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" \
  https://${N8N_HOSTNAME}/workflows -I

# Postgres: Can connect and list databases
docker exec n8nInstall_postgres psql -U n8n -c "\l"

# Redis/Valkey: Can ping
docker exec n8nInstall_redis redis-cli ping

# Caddy: Can fetch certificate info
docker exec n8nInstall_caddy caddy list-certificates
```

---

## 🚀 Integration Test (Full Install)

**When to run:** Before major releases, after significant changes, before production deployment.

**Time:** ~20-30 minutes

**Prerequisites:** Clean Ubuntu 24.04 LTS VM (4GB RAM, 2 CPU minimum)

### Test Environment Setup

```bash
# Use a VM snapshot or cloud instance
# Recommended: DigitalOcean droplet, AWS EC2 t3.medium, or local VirtualBox VM

# 1. Clone repository
git clone <your-fork> /opt/n8n-install
cd /opt/n8n-install

# 2. Verify clean state
docker ps -a  # Should be empty or unrelated
docker volume ls  # Note existing volumes
docker network ls  # Note existing networks
```

### Installation Test

```bash
# Run install script
sudo bash ./scripts/install.sh

# Follow wizard prompts:
# - Enter domain name (use test domain or .localhost for local testing)
# - Enter email (use valid email for Let's Encrypt)
# - Select services to install (test common combinations):
#   - Minimal: n8n only
#   - Standard: n8n + flowise + monitoring
#   - Full: All services

# Expected: Script completes without errors
# Expected: Final report shows all selected services with URLs and credentials
```

### Post-Install Validation Checklist

- [ ] All selected services show "Up" status: `docker compose -p localai ps`
- [ ] All containers have `n8nInstall_` prefix: `docker ps --format '{{.Names}}'`
- [ ] Network exists: `docker network inspect n8nInstall_network`
- [ ] Volumes created with prefix: `docker volume ls | grep n8nInstall`
- [ ] .env file exists with no empty required variables: `grep "^[A-Z_]*=$" .env`
- [ ] Caddy obtained certificates (if using real domain): `docker logs n8nInstall_caddy | grep -i certificate`
- [ ] Services accessible via HTTPS:
  - n8n: `curl -k https://${N8N_HOSTNAME} -I`
  - Flowise (if selected): `curl -k https://${FLOWISE_HOSTNAME} -I`
  - Grafana (if monitoring selected): `curl -k https://${GRAFANA_HOSTNAME} -I`

### Functional Validation

#### n8n Workflow Test
```bash
# 1. Access n8n web UI
# 2. Log in with credentials from final report
# 3. Create a simple workflow:
#    - Add "Schedule Trigger" node (every 1 minute)
#    - Add "Code" node with: return [{json: {message: "Hello"}}];
#    - Add "HTTP Request" node (GET https://httpbin.org/get)
# 4. Activate workflow
# 5. Wait 1 minute, check executions
# Expected: Workflow runs successfully
```

#### Database Test
```bash
# Check n8n database exists
docker exec n8nInstall_postgres psql -U n8n -c "\l" | grep n8n

# Check tables were created
docker exec n8nInstall_postgres psql -U n8n -d n8n -c "\dt"

# Expected: Multiple n8n tables (workflow_entity, execution_entity, etc.)
```

#### Redis Queue Test
```bash
# Check Redis connection
docker exec n8nInstall_redis redis-cli ping

# Check n8n is using queue mode
docker logs n8nInstall_n8n | grep -i queue

# Expected: Logs mention "queue mode" or "bull queue"
```

---

## 🔄 Update & Rollback Testing

**When to run:** Before deploying update.sh changes to production.

### Update Test

```bash
# 1. Backup current state
bash ./scripts/backup_config.sh

# 2. Note current image versions
docker compose -p localai images > /tmp/versions-before.txt

# 3. Run update script
sudo bash ./scripts/update.sh

# 4. Compare image versions
docker compose -p localai images > /tmp/versions-after.txt
diff /tmp/versions-before.txt /tmp/versions-after.txt

# 5. Validate services still work
bash ./scripts/status_report.sh

# 6. Check for data loss
# - n8n: Access workflows, verify existing workflows are present
# - Postgres: docker exec n8nInstall_postgres psql -U n8n -d n8n -c "SELECT COUNT(*) FROM workflow_entity;"
```

### Rollback Test

```bash
# Simulate failed update
docker compose -p localai down

# Restore from backup
bash ./scripts/restore_config.sh

# Restart services
docker compose -p localai up -d

# Validate restoration
bash ./scripts/status_report.sh
# Expected: All services return to previous working state
```

---

## 🐛 Regression Testing (Issue Tracking)

**When to run:** After fixing a bug, to ensure it doesn't recur.

### Regression Test Template

For each fixed issue (documented in an AIP):

1. **Reproduce Original Issue** (before fix)
   - Document exact steps in AIP's TESTING.md
   - Capture error messages/logs

2. **Apply Fix**
   - Implement solution per AIP

3. **Verify Fix**
   - Re-run reproduction steps
   - Confirm error no longer occurs

4. **Add to Regression Suite**
   - Add check to `scripts/validate_install.sh`
   - Example:
     ```bash
     # Regression: n8n database missing (AIP-001)
     if ! docker exec n8nInstall_postgres psql -U n8n -lqt | cut -d \| -f 1 | grep -qw n8n; then
         echo "FAIL: n8n database does not exist"
         exit 1
     fi
     ```

---

## 📊 Test Reporting

### Manual Test Report Template

Create in AIP's TESTING.md or separate test log:

```markdown
## Test Report: <AIP-XXX> - <Feature/Fix Name>

**Date:** YYYY-MM-DD
**Tester:** <your-name>
**Environment:** Ubuntu 24.04 LTS / Docker 24.x.x / Clean VM

### Smoke Tests
- [ ] Script syntax valid
- [ ] Services restart without errors
- [ ] Status reporter shows all green

### Service-Level Tests
- [ ] Container health: OK
- [ ] Network connectivity: OK
- [ ] Configuration loaded: OK
- [ ] External access: OK
- [ ] Functional validation: OK

### Integration Tests
- [ ] Clean install: OK
- [ ] All services start: OK
- [ ] No port conflicts: OK
- [ ] Certificates obtained: OK
- [ ] n8n workflow execution: OK

### Regression Tests
- [ ] <Previous issue #1>: Fixed
- [ ] <Previous issue #2>: Fixed

### Issues Found
- None / <list any issues>

### Conclusion
Ready for production / Needs fixes
```

---

## 🛠 Utility: Test Environment Reset

```bash
# WARNING: Destroys all data - use only in test environments

# Stop all services
docker compose -p localai down -v

# Remove containers
docker rm -f $(docker ps -a --filter "name=n8nInstall_" -q) 2>/dev/null

# Remove volumes
docker volume rm $(docker volume ls --filter "name=n8nInstall_" -q) 2>/dev/null

# Remove network
docker network rm n8nInstall_network 2>/dev/null

# Clean .env
rm -f .env

# Start fresh
sudo bash ./scripts/install.sh
```

---

## 📋 Definition of Done

A change is considered **tested and ready** when:

✅ **Smoke tests pass** - Basic sanity checks complete
✅ **Service-level tests pass** - Affected services validated
✅ **Integration test passes** - Full install works on clean VM
✅ **Regression tests pass** - Previous bugs don't reappear
✅ **Documentation updated** - Changes reflected in docs/AIP
✅ **Backup/restore tested** - Can recover from failure

---

## 🔗 Related Documentation

- [CODING-STANDARD.md](./CODING-STANDARD.md) - Code quality requirements
- [ERROR-HANDLING.md](./ERROR-HANDLING.md) - Debugging failed tests
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Production deployment validation

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
