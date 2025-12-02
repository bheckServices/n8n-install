# Deployment

**Scope:** Installation flow, update strategy, rollback procedures, backup/restore for n8n-install.

---

## 🎯 Deployment Philosophy

1. **Idempotent Operations** - Scripts are safe to re-run
2. **Backup Before Change** - Always backup config/data before updates
3. **Fast Rollback** - Quick recovery from failed deployments
4. **Minimal Downtime** - Rolling updates where possible
5. **Validate Before Deploy** - Test on non-production first

---

## 🚀 Initial Installation

### Prerequisites

**System Requirements:**
- Ubuntu 24.04 LTS (or compatible Linux)
- 4GB RAM minimum (8GB+ recommended for multiple services)
- 2 CPU cores minimum
- 20GB disk space (more for data volumes)
- Docker Engine 24.x+
- Docker Compose v2+

**Network Requirements:**
- Ports 80 and 443 open to internet (for Caddy/HTTPS)
- (Optional) DNS configured: `*.yourdomain.com → <server-ip>`
- (Optional) Valid email for Let's Encrypt

### Installation Steps

```bash
# 1. Clone repository
git clone <your-fork-url> /opt/n8n-install
cd /opt/n8n-install

# 2. Run install script
sudo bash ./scripts/install.sh

# The script will:
# - Check prerequisites (Docker, Docker Compose)
# - Copy .env.example → .env
# - Generate secrets (passwords, keys, hashes)
# - Run wizard to select services
# - Start Docker Compose services
# - Display final report with URLs and credentials

# 3. Save the final report output (contains passwords!)

# 4. Access services
# Navigate to URLs shown in final report
# Use credentials from report to log in
```

### Post-Install Validation

```bash
# Run status reporter
bash scripts/status_report.sh

# Select option 1 (All Services Overview)
# All services should show "Up" and "healthy"

# Validate install script
bash scripts/validate_install.sh

# Expected: All checks pass
```

---

## 🔄 Updates

### Update Strategy

**When to update:**
- Security patches (high priority)
- New service versions (test first)
- Upstream fork updates (quarterly or as needed)
- Configuration changes (manual, controlled)

**Update approach:**
- **Pull updates** - Get latest from upstream fork
- **Test locally** - Verify on dev/test instance
- **Backup production** - Before applying to production
- **Apply updates** - Run update script
- **Validate** - Ensure services still work
- **Rollback if needed** - Restore from backup

### Update Procedure

```bash
# 1. BACKUP FIRST!
bash scripts/backup_config.sh
# Creates timestamped backup in ./backups/

# 2. Pull latest changes from fork
git fetch upstream  # Or origin if using your own fork
git pull upstream main

# 3. Review changes
git log HEAD@{1}..HEAD --oneline
git diff HEAD@{1} HEAD -- .env.example docker-compose.yml

# 4. Check for breaking changes in CHANGELOG (if exists)

# 5. Run update script
sudo bash scripts/update.sh

# The script will:
# - Pull latest Docker images
# - Restart services with new images
# - Apply any configuration changes

# 6. Validate services
bash scripts/status_report.sh

# 7. Test critical workflows
# - Access n8n UI
# - Run a test workflow
# - Check Grafana dashboards (if monitoring enabled)
```

### Safe Update Workflow

**For mission-critical deployments:**

```bash
# 1. Snapshot VM (if using cloud provider)
# AWS: Create AMI
# DigitalOcean: Create snapshot
# VirtualBox: Take snapshot

# 2. Test on staging environment first
# Clone VM or use separate test instance
# Run update procedure
# Validate for 24-48 hours

# 3. If staging successful, update production
# During low-traffic window
# Have rollback plan ready

# 4. Monitor closely after update
# Watch logs: docker compose -p localai logs -f
# Check Grafana dashboards
# Run status reporter every 15 minutes for first hour
```

---

## 🔙 Rollback Procedures

### Quick Rollback (Config Changes)

**Use when:** Update broke config but images are fine.

```bash
# 1. Stop services
docker compose -p localai down

# 2. Restore config from backup
bash scripts/restore_config.sh

# Prompts for backup file to restore
# Select most recent pre-update backup

# 3. Restart services with restored config
docker compose -p localai up -d

# 4. Validate
bash scripts/status_report.sh
```

### Image Rollback

**Use when:** New Docker image version has bugs.

```bash
# 1. Find previous working version
docker images | grep n8nio/n8n
# Example output:
# n8nio/n8n  1.21.0  <image-id>  2 days ago
# n8nio/n8n  1.20.0  <image-id>  1 week ago

# 2. Edit docker-compose.yml
# Change: image: n8nio/n8n:1.21.0
# To:     image: n8nio/n8n:1.20.0

# 3. Recreate services with old image
docker compose -p localai up -d --force-recreate n8n n8n-worker

# 4. Validate
docker logs n8nInstall_n8n --tail=50
bash scripts/status_report.sh
```

### Full System Rollback (VM Snapshot)

**Use when:** Major issues, data corruption, or panic situation.

```bash
# Cloud Provider Method:
# 1. Navigate to snapshots/backups in provider UI
# 2. Restore from snapshot taken before update
# 3. Start restored VM
# 4. Validate services

# Git-Based Config Rollback:
git log --oneline  # Find commit hash before update
git checkout <commit-hash> -- .env docker-compose.yml Caddyfile
docker compose -p localai down && docker compose -p localai up -d
```

---

## 💾 Backup & Restore

### Backup Strategy

**What to backup:**
- ✅ Configuration files (.env, docker-compose.yml, Caddyfile)
- ✅ Docker volumes (n8nInstall_* volumes with persistent data)
- ✅ (Optional) Git repository state

**What NOT to backup:**
- ❌ Docker images (can be re-pulled)
- ❌ Container state (ephemeral)
- ❌ Logs (rotate regularly, archive separately if needed)

### Automated Config Backup

**Script:** `scripts/backup_config.sh`

```bash
# Run backup
bash scripts/backup_config.sh

# Creates:
# ./backups/config-backup-YYYY-MM-DD-HHMMSS.tar.gz
# Contains: .env, docker-compose.yml, Caddyfile, scripts/

# List backups
ls -lh backups/

# Restore from backup
bash scripts/restore_config.sh
# Interactive prompt to select backup file
```

### Manual Volume Backup

**Backup all data volumes:**

```bash
# Create backup directory
mkdir -p backups/volumes

# Backup each volume
for vol in $(docker volume ls --filter "name=n8nInstall_" -q); do
    echo "Backing up $vol..."
    docker run --rm \
        -v $vol:/data \
        -v $(pwd)/backups/volumes:/backup \
        alpine tar czf /backup/${vol}-$(date +%F).tar.gz /data
done

# List backups
ls -lh backups/volumes/
```

**Restore specific volume:**

```bash
# Stop services using the volume
docker compose -p localai down

# Restore volume
docker run --rm \
    -v n8nInstall_postgres_data:/data \
    -v $(pwd)/backups/volumes:/backup \
    alpine sh -c "rm -rf /data/* && tar xzf /backup/n8nInstall_postgres_data-2025-12-01.tar.gz -C /"

# Restart services
docker compose -p localai up -d
```

### Backup Schedule (Recommended)

**Production environments:**
```bash
# Add to crontab (sudo crontab -e)

# Daily config backup at 2 AM
0 2 * * * cd /opt/n8n-install && bash scripts/backup_config.sh

# Weekly full volume backup at 3 AM Sunday
0 3 * * 0 cd /opt/n8n-install && bash scripts/backup_volumes.sh  # Create this script

# Clean old backups (keep last 30 days)
0 4 * * * find /opt/n8n-install/backups -name "*.tar.gz" -mtime +30 -delete
```

---

## 🧪 Pre-Production Validation

### Validation Checklist

Before deploying to production:

- [ ] **Clean install tested** - Full install on fresh VM succeeds
- [ ] **Services start** - All selected services show "healthy"
- [ ] **HTTPS works** - Certificates obtained (if using real domain)
- [ ] **Authentication works** - Can log in to all protected services
- [ ] **Workflows execute** - n8n test workflow runs successfully
- [ ] **Database accessible** - Can query Postgres, data persists
- [ ] **Backups work** - Backup and restore tested
- [ ] **Monitoring active** - Grafana dashboards show data (if enabled)
- [ ] **Documentation updated** - Any new services documented
- [ ] **Secrets secured** - .env has restrictive permissions, not in Git

### Smoke Test Script

```bash
# Create: scripts/smoke_test.sh

#!/usr/bin/env bash
set -euo pipefail

echo "Running smoke tests..."

# Test 1: All services up
echo "✓ Checking services..."
docker compose -p localai ps | grep -q "Up" || exit 1

# Test 2: n8n accessible
echo "✓ Testing n8n..."
curl -k -I https://${N8N_HOSTNAME} | grep -q "200\|401" || exit 1

# Test 3: Database responsive
echo "✓ Testing database..."
docker exec n8nInstall_postgres pg_isready -U n8n || exit 1

# Test 4: Redis responsive
echo "✓ Testing Redis..."
docker exec n8nInstall_redis redis-cli ping | grep -q "PONG" || exit 1

echo "✅ All smoke tests passed!"
```

---

## 🌐 Production Deployment Best Practices

### DNS Configuration

**Before installation:**
```bash
# Set up wildcard DNS record
*.yourdomain.com  A  <server-public-ip>

# Or individual records
n8n.yourdomain.com      A  <server-ip>
flowise.yourdomain.com  A  <server-ip>
grafana.yourdomain.com  A  <server-ip>

# Verify DNS propagation (may take up to 48 hours)
nslookup n8n.yourdomain.com
```

### Firewall Configuration

```bash
# Allow HTTP (for Let's Encrypt challenge)
sudo ufw allow 80/tcp

# Allow HTTPS
sudo ufw allow 443/tcp

# Allow SSH (be careful!)
sudo ufw allow 22/tcp

# Enable firewall
sudo ufw enable

# Check status
sudo ufw status
```

### Resource Limits (Production)

**Edit docker-compose.yml for production workloads:**

```yaml
services:
  n8n:
    deploy:
      resources:
        limits:
          cpus: '2.0'
          memory: 2G
        reservations:
          cpus: '1.0'
          memory: 1G

  postgres:
    deploy:
      resources:
        limits:
          memory: 4G
        reservations:
          memory: 2G
```

---

## 📊 Deployment Validation

### Post-Deployment Checks

**Run immediately after deployment:**

```bash
# 1. Service health
bash scripts/status_report.sh

# 2. Certificate status (if using real domain)
docker exec n8nInstall_caddy caddy list-certificates

# 3. Resource usage
docker stats --no-stream | grep n8nInstall

# 4. Disk space
df -h

# 5. Volume sizes
docker system df -v | grep n8nInstall

# 6. Network connectivity
docker exec n8nInstall_n8n ping -c 1 n8nInstall_postgres
```

### Monitoring Setup

**Configure alerts in Grafana:**
- Service down (any container exited)
- High memory usage (>80% for >5 min)
- Disk space low (<10% free)
- n8n workflow failures (>10% failure rate)

---

## 🔗 Related Documentation

- [ERROR-HANDLING.md](./ERROR-HANDLING.md) - Recovery procedures
- [TESTING-STANDARDS.md](./TESTING-STANDARDS.md) - Validation workflows
- [SECURITY.md](./SECURITY.md) - Production security checklist

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
