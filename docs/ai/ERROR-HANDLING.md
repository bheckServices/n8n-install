# Error Handling

**Scope:** Failure modes, recovery procedures, debugging strategies, and incident response for n8n-install.

---

## 🎯 Error Handling Philosophy

1. **Fail Fast** - Detect issues early in scripts (`set -euo pipefail`)
2. **Clear Messages** - Every error includes actionable guidance
3. **Graceful Degradation** - Core services continue if optional services fail
4. **Recovery-First** - Prioritize getting back online over root cause analysis
5. **Document Everything** - Create AIPs for recurring issues

---

## 🚨 Common Failure Modes

### 1. Container Won't Start

**Symptoms:**
- `docker compose ps` shows "Exited" or "Restarting"
- Service not accessible via URL

**Diagnosis:**
```bash
# Check exit status
docker compose -p localai ps <service>

# View logs for error messages
docker compose -p localai logs --tail=100 <service>

# Check healthcheck failure reason
docker inspect n8nInstall_<service> --format='{{.State.Health.Log}}'
```

**Common Causes & Fixes:**

| Cause | Error Pattern | Fix |
|-------|---------------|-----|
| Missing env var | `required variable not set` | Check `.env` for empty values |
| Database not ready | `connection refused` | Verify `depends_on` with healthcheck |
| Port conflict | `address already in use` | Check no ports exposed (except Caddy) |
| Volume permission | `permission denied` | Check volume ownership: `docker exec <service> ls -la /data` |
| Out of memory | `OOMKilled` | Increase Docker memory limit or add resource limits |

**Recovery Steps:**
```bash
# 1. Fix underlying issue (env var, permissions, etc.)

# 2. Remove failed container
docker compose -p localai rm -f <service>

# 3. Recreate with fresh state
docker compose -p localai up -d --force-recreate <service>

# 4. Monitor logs
docker compose -p localai logs -f <service>
```

---

### 2. Database Connection Failures

**Symptoms:**
- n8n shows "Database connection error"
- Services can't connect to Postgres

**Diagnosis:**
```bash
# Check Postgres is running and healthy
docker compose -p localai ps postgres
docker exec n8nInstall_postgres pg_isready -U n8n

# Test connection from n8n container
docker exec n8nInstall_n8n psql -h n8nInstall_postgres -U n8n -d n8n -c "\l"

# Check for connection limit issues
docker exec n8nInstall_postgres psql -U n8n -c "SELECT count(*) FROM pg_stat_activity;"
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Postgres not started | `docker compose -p localai up -d postgres` |
| Wrong credentials | Verify `POSTGRES_PASSWORD` in `.env` matches n8n's `DB_POSTGRESDB_PASSWORD` |
| Database doesn't exist | Run `postgres/init-databases.sql` or create manually |
| Too many connections | Increase `max_connections` in Postgres config |
| Network issue | Verify both containers on `n8nInstall_network` |

**Recovery Steps:**
```bash
# 1. Ensure Postgres is healthy
docker compose -p localai up -d postgres
sleep 10  # Wait for healthcheck

# 2. Verify database exists
docker exec n8nInstall_postgres psql -U n8n -lqt | cut -d \| -f 1 | grep -w n8n

# 3. If missing, create database
docker exec n8nInstall_postgres psql -U n8n -c "CREATE DATABASE n8n;"

# 4. Restart dependent services
docker compose -p localai up -d n8n n8n-worker
```

---

### 3. Caddy Certificate Issues

**Symptoms:**
- HTTPS not working (browser shows "Connection refused")
- Certificate errors (invalid certificate)
- Caddy logs show "failed to obtain certificate"

**Diagnosis:**
```bash
# Check Caddy status
docker logs n8nInstall_caddy --tail=100 | grep -i certif

# List obtained certificates
docker exec n8nInstall_caddy caddy list-certificates

# Validate Caddy config
docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile
```

**Common Causes & Fixes:**

| Cause | Error Pattern | Fix |
|-------|---------------|-----|
| DNS not configured | `no such host` | Configure DNS A record: `*.yourdomain.com → <server-ip>` |
| Ports 80/443 blocked | `connection timeout` | Open firewall ports 80 and 443 |
| Invalid email | `invalid email address` | Set valid `LETSENCRYPT_EMAIL` in `.env` |
| Rate limit hit | `too many certificates already issued` | Wait 1 week or use staging: `acme_ca https://acme-staging-v02.api.letsencrypt.org/directory` |
| Domain not reachable | `challenge failed` | Ensure server is publicly accessible on port 80 |

**Recovery Steps:**

**If using .localhost (dev):**
```bash
# No action needed - Caddy uses self-signed certs
# Access with: curl -k https://n8n.localhost
```

**If using real domain:**
```bash
# 1. Verify DNS is configured
nslookup ${N8N_HOSTNAME}
# Should resolve to your server's IP

# 2. Check ports are open
curl -v http://<server-ip>:80
curl -v https://<server-ip>:443

# 3. Reload Caddy to retry certificate
docker exec n8nInstall_caddy caddy reload --config /etc/caddy/Caddyfile

# 4. If still failing, check Caddy logs for specific error
docker logs n8nInstall_caddy --tail=200 | grep -A5 -B5 -i error
```

---

### 4. n8n Password Authentication Failures

**Symptoms:**
- Can't log in to n8n with provided credentials
- "Invalid credentials" error

**Diagnosis:**
```bash
# Check what credentials are configured
source .env
echo "Username: ${N8N_BASIC_AUTH_USER}"
echo "Password: ${N8N_BASIC_AUTH_PASSWORD}"
echo "Hash: ${N8N_BASIC_AUTH_PASSWORD_HASH:0:20}..."  # First 20 chars

# Verify Caddy is using the hash
docker exec n8nInstall_caddy cat /etc/caddy/Caddyfile | grep -A3 "${N8N_HOSTNAME}"
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Wrong password | Use password from `.env`, not a remembered one |
| Hash mismatch | Regenerate hash: `bash scripts/03_generate_secrets.sh` |
| Two-layer auth confusion | First prompt is Caddy Basic Auth, second is n8n login (if configured) |
| Password contains special chars | Escape special chars in URL if accessing via curl |
| .env not loaded | Restart Caddy: `docker compose -p localai up -d --force-recreate caddy` |

**Recovery Steps:**
```bash
# 1. Regenerate password and hash
bash scripts/03_generate_secrets.sh

# 2. Reload Caddy with new credentials
docker compose -p localai up -d --force-recreate caddy

# 3. Test with new password
curl -k -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" https://${N8N_HOSTNAME}

# 4. If still failing, temporarily disable Basic Auth for debugging
# Edit Caddyfile, comment out basicauth block, reload Caddy
```

---

### 5. Service Config Misalignment (Cloudflare, Caddy, etc.)

**Symptoms:**
- Cloudflare tunnel not connecting
- Hostname mismatch errors in logs
- Service accessible internally but not externally

**Diagnosis:**
```bash
# Check active profiles vs configured services
source .env
echo "Active profiles: ${COMPOSE_PROFILES}"
docker compose -p localai config --services

# Check hostname variables
grep "_HOSTNAME" .env

# Check Caddy config matches .env
docker exec n8nInstall_caddy cat /etc/caddy/Caddyfile | grep -E "\{\$.*_HOSTNAME\}"
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| Profile not active | Add profile to `COMPOSE_PROFILES` in `.env` |
| Hostname not set | Add `SERVICE_HOSTNAME` to `.env` |
| Caddyfile missing service block | Add block for new service (see [CODING-STANDARD.md](./CODING-STANDARD.md)) |
| Cloudflare tunnel config outdated | Regenerate tunnel config or update manually |
| Service name mismatch | Ensure reverse_proxy uses `n8nInstall_<service>:<port>` |

**Recovery Steps:**
```bash
# 1. Backup config
bash scripts/backup_config.sh

# 2. Fix .env (add missing hostname/profile)
nano .env

# 3. If Caddyfile needs update, edit and validate
docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile

# 4. Reload services
docker compose -p localai up -d

# 5. Check service is accessible
curl -k -I https://${SERVICE_HOSTNAME}
```

---

### 6. Update Breaks Configuration

**Symptoms:**
- After running `update.sh`, services fail to start
- Manual fixes were overwritten

**Diagnosis:**
```bash
# Check what changed
git diff HEAD@{1} HEAD

# Compare .env backups
diff .env.backup .env

# Check if update pulled new images
docker images | grep n8nInstall
```

**Common Causes & Fixes:**

| Cause | Fix |
|-------|-----|
| .env overwritten | Restore from backup: `bash scripts/restore_config.sh` |
| Breaking config changes | Review git log, update .env to match new schema |
| Image incompatibility | Revert to previous image version in docker-compose.yml |
| Migration needed | Check service docs for migration steps (e.g., database schema changes) |

**Recovery Steps:**
```bash
# 1. Stop all services
docker compose -p localai down

# 2. Restore from backup
bash scripts/restore_config.sh

# 3. Restart with restored config
docker compose -p localai up -d

# 4. Verify services work
bash scripts/status_report.sh

# 5. Document issue in AIP for future reference
```

---

## 🛠️ Debugging Strategies

### Layered Debugging Approach

```
1. Container Level
   ↓ docker compose ps
   ↓ docker logs

2. Network Level
   ↓ docker network inspect
   ↓ ping between containers

3. Application Level
   ↓ Service-specific logs
   ↓ Database queries, API tests

4. Configuration Level
   ↓ .env variables
   ↓ Caddyfile syntax
```

### Debug Checklist

**When debugging any issue:**

- [ ] Run `bash scripts/status_report.sh` to gather baseline info
- [ ] Check container status: `docker compose -p localai ps`
- [ ] Review recent logs: `docker compose -p localai logs --since 30m`
- [ ] Verify .env has all required variables: `grep "^[A-Z_]*=$" .env`
- [ ] Test network connectivity: `docker exec n8nInstall_n8n ping n8nInstall_postgres`
- [ ] Check for recent system changes (updates, config edits)
- [ ] Search existing AIPs for similar issues: `grep -r "<error-keyword>" docs/Agent\ Implementation\ Packets/`

---

## 🔄 Recovery Procedures

### Quick Recovery (Get Services Back Online)

**Goal:** Restore service ASAP, debug later.

```bash
# 1. Backup current state (in case it's needed later)
bash scripts/backup_config.sh

# 2. Restart all services (often fixes transient issues)
docker compose -p localai restart

# 3. If still failing, recreate all services
docker compose -p localai down && docker compose -p localai up -d

# 4. Check status
bash scripts/status_report.sh

# 5. If specific service still failing, recreate just that one
docker compose -p localai up -d --force-recreate <service>
```

### Full Recovery (Clean Slate)

**WARNING:** This destroys all data. Only use in dev/test or if backups exist.

```bash
# 1. Stop all services
docker compose -p localai down

# 2. Backup data volumes (if needed)
for vol in $(docker volume ls --filter "name=n8nInstall_" -q); do
    docker run --rm -v $vol:/data -v $(pwd)/backups:/backup alpine \
        tar czf /backup/${vol}.tar.gz /data
done

# 3. Remove all containers, volumes, networks
docker compose -p localai down -v
docker rm -f $(docker ps -a --filter "name=n8nInstall_" -q) 2>/dev/null
docker volume rm $(docker volume ls --filter "name=n8nInstall_" -q) 2>/dev/null
docker network rm n8nInstall_network 2>/dev/null

# 4. Reinstall from scratch
bash scripts/install.sh

# 5. Restore data if needed
for vol in backups/*.tar.gz; do
    vol_name=$(basename $vol .tar.gz)
    docker run --rm -v $vol_name:/data -v $(pwd)/backups:/backup alpine \
        tar xzf /backup/$(basename $vol) -C /
done
```

---

## 📋 Incident Response Plan

### Phase 1: Detection (0-5 minutes)

- [ ] Alert received (monitoring, user report, status check)
- [ ] Classify severity:
  - **P1 Critical:** All services down, data loss risk
  - **P2 High:** Single service down, user impact
  - **P3 Medium:** Degraded performance
  - **P4 Low:** Minor issue, no user impact

### Phase 2: Containment (5-15 minutes)

- [ ] Run `bash scripts/status_report.sh` → Save output
- [ ] Backup current state: `bash scripts/backup_config.sh`
- [ ] If P1: Consider failover/rollback immediately
- [ ] If P2/P3: Attempt quick recovery steps
- [ ] Document timeline and actions taken

### Phase 3: Resolution (15-60 minutes)

- [ ] Follow appropriate recovery procedure (see above)
- [ ] Verify services restored: `bash scripts/status_report.sh`
- [ ] Test critical workflows (e.g., run test n8n workflow)
- [ ] Monitor for recurrence (next 30 minutes)

### Phase 4: Post-Incident (After resolution)

- [ ] Create AIP documenting issue, root cause, and fix
- [ ] Update [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) with new runbook
- [ ] Add regression test to `scripts/validate_install.sh`
- [ ] Review monitoring/alerts (did they detect the issue?)
- [ ] Communicate resolution to stakeholders

---

## 🔗 Related Documentation

- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Issue-specific runbooks
- [OBSERVABILITY.md](./OBSERVABILITY.md) - Monitoring and diagnostics
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Backup and rollback procedures

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
