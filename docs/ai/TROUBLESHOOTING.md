# Troubleshooting

**Quick reference guide for common issues and their solutions.**

---

## 🔍 Quick Diagnostics

**First steps for any issue:**

```bash
# 1. Run status reporter
bash scripts/status_report.sh

# 2. Check recent logs
docker compose -p localai logs --tail=100 --since 30m

# 3. Verify containers running
docker compose -p localai ps
```

---

## 🐛 Common Issues & Solutions

### Issue: Cloudflare Tunnel Not Working / Let's Encrypt Certificate Errors

**Symptoms:**
- Caddy logs show "DNS problem: NXDOMAIN" errors
- Let's Encrypt certificate acquisition failing
- Services not accessible through Cloudflare Tunnel
- Tunnel connected but routes return 404/502

**Root Cause:** Caddy is trying to get Let's Encrypt certificates while Cloudflare Tunnel should handle HTTPS.

**Solution - Configure HTTP-Only Mode:**

1. **Update Caddyfile global options:**
```caddyfile
{
    auto_https off
    admin off
}
```

2. **Prefix all hostnames with `http://`:**
```caddyfile
# Before:
{$N8N_HOSTNAME} {
    reverse_proxy n8n:5678
}

# After:
http://{$N8N_HOSTNAME} {
    reverse_proxy n8n:5678
}
```

3. **Update docker-compose.yml ports:**
```yaml
caddy:
  ports:
    - "80:80"
    # Remove port 443:443
```

4. **Verify Cloudflare Tunnel routes:**
- Go to Cloudflare Zero Trust Dashboard → Networks → Tunnels
- Ensure routes point to `http://caddy:80` (not `https://`)
- Hostname example: `searxng.verifymyllcname.com` → Service: `http://caddy:80`

5. **Restart services:**
```bash
docker compose -p localai down
docker volume rm n8nInstall_caddy-data n8nInstall_caddy-config
docker compose -p localai up -d
```

6. **Verify logs are clean:**
```bash
docker logs n8nInstall_caddy --tail 50
docker logs n8nInstall_cloudflared --tail 50
```

**Expected Result:**
- ✅ No Let's Encrypt errors in Caddy logs
- ✅ Cloudflare Tunnel shows "Registered tunnel connection"
- ✅ Services accessible via `https://yourservice.yourdomain.com` (HTTPS handled by Cloudflare)
- ✅ Caddy serves HTTP-only on port 80

---

### Issue: n8n Password Doesn't Work

**Symptoms:** Can't log in to n8n with credentials from final report.

**Solution:**
```bash
# Check credentials in .env
source .env
echo "User: ${N8N_BASIC_AUTH_USER}"
echo "Pass: ${N8N_BASIC_AUTH_PASSWORD}"

# Regenerate if needed
bash scripts/03_generate_secrets.sh

# Reload Caddy
docker compose -p localai up -d --force-recreate caddy

# Test with curl
curl -k -u "${N8N_BASIC_AUTH_USER}:${N8N_BASIC_AUTH_PASSWORD}" https://${N8N_HOSTNAME}
```

---

### Issue: n8n Database Missing in Postgres

**Symptoms:** n8n shows "database does not exist" error.

**Solution:**
```bash
# Check if database exists
docker exec n8nInstall_postgres psql -U n8n -lqt | cut -d \| -f 1 | grep -w n8n

# If missing, create it
docker exec n8nInstall_postgres psql -U n8n -c "CREATE DATABASE n8n;"

# Restart n8n
docker compose -p localai up -d --force-recreate n8n n8n-worker
```

---

### Issue: Caddy Not Getting Certificates

**Symptoms:** HTTPS not working, certificate errors in browser.

**Possible Causes & Solutions:**

**1. DNS not configured:**
```bash
# Verify DNS resolution
nslookup ${N8N_HOSTNAME}
# Should return your server's IP

# If not: Configure DNS A record: *.yourdomain.com → <server-ip>
# Wait for propagation (up to 48 hours)
```

**2. Ports 80/443 blocked:**
```bash
# Test from external machine
curl -v http://<server-ip>:80
curl -v https://<server-ip>:443

# If timeout: Open firewall ports
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

**3. Invalid email:**
```bash
# Check LETSENCRYPT_EMAIL in .env
grep LETSENCRYPT_EMAIL .env

# Update if invalid, reload Caddy
docker compose -p localai up -d --force-recreate caddy
```

**4. Using .localhost domain (dev mode):**
```bash
# .localhost domains use self-signed certificates
# This is expected behavior for local development
# Access with: curl -k https://n8n.localhost
```

---

### Issue: Cloudflare Tunnel Not Working

**Symptoms:** Cloudflare tunnel shows disconnected, hostname mismatches.

**Solution:**
```bash
# 1. Verify cloudflare-tunnel profile is active
source .env
echo $COMPOSE_PROFILES | grep cloudflare-tunnel

# 2. Check tunnel config
docker exec n8nInstall_cloudflare-tunnel cat /etc/cloudflared/config.yml

# 3. Verify hostnames match between:
#    - .env (CLOUDFLARE_TUNNEL_HOSTNAME)
#    - Cloudflare dashboard tunnel config
#    - config.yml in container

# 4. Restart tunnel
docker compose -p localai up -d --force-recreate cloudflare-tunnel

# 5. Check logs
docker logs n8nInstall_cloudflare-tunnel --tail=100
```

---

### Issue: Service Won't Start (Exited/Restarting)

**Symptoms:** `docker compose ps` shows service as "Exited" or constantly restarting.

**Solution:**
```bash
# 1. Check logs for error
docker compose -p localai logs --tail=200 <service>

# 2. Common fixes:

# Missing env var:
grep "^<VAR_NAME>=" .env  # Ensure not empty

# Database not ready:
docker compose -p localai ps postgres  # Should show "healthy"

# Permission issue:
docker exec <service> ls -la /data  # Check ownership

# Port conflict (shouldn't happen if using Caddy correctly):
docker compose -p localai config | grep -A2 "ports:"  # Only Caddy should have ports

# 3. Recreate service
docker compose -p localai up -d --force-recreate <service>
```

---

### Issue: Update Broke Configuration

**Symptoms:** After `update.sh`, services fail to start or manual fixes were lost.

**Solution:**
```bash
# 1. Restore from backup
bash scripts/restore_config.sh

# 2. Restart services
docker compose -p localai down && docker compose -p localai up -d

# 3. Verify services work
bash scripts/status_report.sh

# 4. Document issue in AIP for future reference
```

---

### Issue: High Memory/CPU Usage

**Symptoms:** Server slow, services unresponsive.

**Solution:**
```bash
# 1. Identify culprit
docker stats --no-stream | grep n8nInstall

# 2. Service-specific checks:

# n8n: Check running workflows
# Access UI → Executions → Filter "running"
# Stop long-running workflows if needed

# Postgres: Check active queries
docker exec n8nInstall_postgres psql -U n8n -c "SELECT pid, query FROM pg_stat_activity WHERE state != 'idle';"

# 3. Add resource limits to docker-compose.yml if needed
# See INFRASTRUCTURE.md for examples
```

---

### Issue: Disk Space Full

**Symptoms:** Services crash, "no space left on device" errors.

**Solution:**
```bash
# 1. Check disk usage
df -h
docker system df

# 2. Clean Docker resources
docker system prune -a --volumes  # WARNING: Removes unused data

# 3. Check log sizes
du -sh /var/lib/docker/containers/*/*-json.log

# 4. Adjust log rotation in docker-compose.yml:
# logging:
#   options:
#     max-size: "10m"
#     max-file: "3"

# 5. Remove old backups
find ./backups -name "*.tar.gz" -mtime +30 -delete
```

---

## 📋 Diagnostic Commands Reference

```bash
# Service status
docker compose -p localai ps

# Container logs
docker logs n8nInstall_<service> --tail=200

# Follow logs
docker compose -p localai logs -f <service>

# Resource usage
docker stats --no-stream | grep n8nInstall

# Network connectivity
docker exec n8nInstall_n8n ping -c 1 n8nInstall_postgres

# Database check
docker exec n8nInstall_postgres pg_isready -U n8n
docker exec n8nInstall_postgres psql -U n8n -l

# Redis check
docker exec n8nInstall_redis redis-cli ping

# Caddy config validation
docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile

# Caddy certificates
docker exec n8nInstall_caddy caddy list-certificates

# Volume inspection
docker volume ls | grep n8nInstall
docker volume inspect n8nInstall_<volume>

# Network inspection
docker network inspect n8nInstall_network
```

---

## 🔗 Related Documentation

- [ERROR-HANDLING.md](./ERROR-HANDLING.md) - Detailed recovery procedures
- [OBSERVABILITY.md](./OBSERVABILITY.md) - Monitoring and diagnostics
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Backup and rollback

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
