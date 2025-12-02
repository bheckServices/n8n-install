# Updating n8n-install

**Safe update procedures that preserve your data and custom configurations.**

---

## 🔄 Quick Update (Recommended)

**Use this when you have existing data and want to keep it:**

```bash
cd ~/path/to/n8n-install
bash scripts/safe_update.sh
```

This script will:
- ✅ Backup your `.env`, `Caddyfile`, and `docker-compose.yml`
- ✅ Stash your local changes
- ✅ Pull latest code from git
- ✅ Restore your custom configuration
- ✅ Validate Caddyfile for Cloudflare Tunnel compatibility
- ✅ **Preserve ALL Docker volumes** (databases, workflows, files)

---

## 📋 What Gets Updated vs Preserved

### Updated (Safe to Replace)
- ✅ Scripts in `scripts/`
- ✅ Documentation in `docs/`
- ✅ Base templates
- ✅ Docker image versions (in docker-compose.yml)

### Preserved (Never Lost)
- ✅ Your `.env` file (secrets, passwords, API keys)
- ✅ Your custom Caddyfile modifications
- ✅ Your custom docker-compose.yml modifications
- ✅ **ALL Docker volumes:**
  - n8n workflows and credentials
  - PostgreSQL databases
  - Redis/Valkey data
  - Supabase data
  - All other service data

---

## 🛠️ Manual Update (Advanced)

If you prefer manual control:

### Step 1: Backup
```bash
# Create backup directory
mkdir -p backups/manual-$(date +%Y%m%d)

# Backup critical files
cp .env backups/manual-$(date +%Y%m%d)/
cp Caddyfile backups/manual-$(date +%Y%m%d)/
cp docker-compose.yml backups/manual-$(date +%Y%m%d)/
```

### Step 2: Update Code
```bash
# Stash local changes
git stash

# Pull updates
git pull

# Restore your changes
git stash pop
```

### Step 3: Resolve Conflicts (if any)

If `git stash pop` shows conflicts:

```bash
# View conflicted files
git status

# Edit each conflicted file
# Look for conflict markers: <<<<<<<, =======, >>>>>>>
# Keep your custom values

# After resolving:
git add <file>
git stash drop
```

### Step 4: Restore .env
```bash
# Always restore your .env (contains secrets)
cp backups/manual-$(date +%Y%m%d)/.env .env
```

### Step 5: Validate Configuration
```bash
# Check Caddyfile is correct for Cloudflare Tunnel
bash scripts/validate_caddy_config.sh

# Fix if needed
bash scripts/validate_caddy_config.sh --fix
```

### Step 6: Apply Updates
```bash
# Recreate services with new configuration
docker compose -p localai up -d

# Check everything is running
bash scripts/status_report.sh
```

---

## 🔧 Handling Specific Updates

### Caddyfile Updates

**If Caddyfile changed upstream:**

1. **Check what changed:**
   ```bash
   git diff origin/main Caddyfile
   ```

2. **Three options:**

   **A) Keep your version (recommended if using Cloudflare Tunnel):**
   ```bash
   git checkout --ours Caddyfile
   ```

   **B) Use new version (if you want new features):**
   ```bash
   git checkout --theirs Caddyfile
   # Then re-apply Cloudflare Tunnel fixes:
   bash scripts/validate_caddy_config.sh --fix
   ```

   **C) Manually merge:**
   ```bash
   # Edit Caddyfile manually
   # Keep your custom blocks
   # Add new service blocks from upstream
   ```

### docker-compose.yml Updates

**If docker-compose.yml changed:**

1. **Check what changed:**
   ```bash
   git diff origin/main docker-compose.yml
   ```

2. **Safe merge strategy:**
   ```bash
   # Keep new service definitions
   # Keep your port modifications (80 only, not 443)
   # Keep your environment variables
   ```

3. **Verify ports:**
   ```bash
   grep -A 3 "caddy:" docker-compose.yml | grep ports
   # Should show only:
   #   - "80:80"
   # NOT 443 or 7687
   ```

### .env Updates

**Never replace .env automatically!**

If `.env.example` adds new variables:

1. **Check what's new:**
   ```bash
   diff .env .env.example
   ```

2. **Add new variables to your .env:**
   ```bash
   # Copy new lines from .env.example
   # Keep your existing values
   ```

3. **Regenerate only new secrets:**
   ```bash
   # Edit scripts/03_generate_secrets.sh
   # Comment out existing secrets
   # Run to generate only new ones
   bash scripts/03_generate_secrets.sh
   ```

---

## ⚠️ Troubleshooting Updates

### Issue: Merge Conflicts in Caddyfile

**Symptoms:** `git stash pop` fails with conflicts in Caddyfile

**Solution:**
```bash
# Use your Cloudflare Tunnel version
git checkout --ours Caddyfile
git add Caddyfile

# Or use new version and re-fix
git checkout --theirs Caddyfile
bash scripts/validate_caddy_config.sh --fix
git add Caddyfile

# Finish merge
git stash drop
```

### Issue: Services Won't Start After Update

**Symptoms:** `docker compose up -d` fails or services crash

**Solution:**
```bash
# Restore from backup
cp backups/update-YYYYMMDD-HHMMSS/docker-compose.yml ./

# Check docker-compose.yml syntax
docker compose config

# Check logs
docker compose -p localai logs --tail=50

# Restart fresh
docker compose -p localai down
docker compose -p localai up -d
```

### Issue: Lost Custom Configuration

**Symptoms:** Your Caddyfile or docker-compose.yml changes are gone

**Solution:**
```bash
# Backups are in backups/ directory
ls -lt backups/

# Restore from most recent backup
cp backups/update-YYYYMMDD-HHMMSS/Caddyfile ./
cp backups/update-YYYYMMDD-HHMMSS/docker-compose.yml ./

# Restart services
docker compose -p localai up -d
```

---

## 📊 Update Checklist

After any update, verify:

- [ ] All containers running: `docker compose -p localai ps`
- [ ] No errors in logs: `docker compose -p localai logs --tail=100`
- [ ] Services accessible via Cloudflare Tunnel
- [ ] Caddy using HTTP-only mode: `docker logs n8nInstall_caddy | grep -i "auto_https"`
- [ ] No Let's Encrypt errors: `docker logs n8nInstall_caddy | grep -i "acme"`
- [ ] Tunnel connected: `docker logs n8nInstall_cloudflared | grep -i "registered"`
- [ ] n8n workflows still present: Visit n8n dashboard
- [ ] Databases intact: Check service-specific data

---

## 🆘 Emergency Rollback

If update breaks everything:

```bash
# Stop all services
docker compose -p localai down

# Restore backup
BACKUP_DIR=$(ls -dt backups/update-* | head -1)
cp $BACKUP_DIR/.env ./
cp $BACKUP_DIR/Caddyfile ./
cp $BACKUP_DIR/docker-compose.yml ./

# Rollback git
git reset --hard HEAD~1

# Restart
docker compose -p localai up -d
```

**Your data volumes are NEVER deleted during updates!**

---

## 📝 Best Practices

1. **Always backup before updates:** `bash scripts/safe_update.sh` does this automatically
2. **Read the changelog:** `git log -10 --oneline` to see what changed
3. **Test in staging first:** If you have a test environment
4. **Update during low-traffic times:** To minimize disruption
5. **Keep backups for 30 days:** Old backups in `backups/` directory
6. **Document custom changes:** Add comments in Caddyfile explaining your modifications

---

## 🔄 Update Frequency

**Recommended:**
- **Security patches:** Immediately
- **New features:** Monthly
- **Docker images:** Weekly (rebuild containers)

**Commands:**
```bash
# Pull latest code
bash scripts/safe_update.sh

# Pull latest Docker images
docker compose -p localai pull

# Recreate containers with new images
docker compose -p localai up -d
```
