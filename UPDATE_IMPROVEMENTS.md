# Update Script Improvements

## What Was Fixed

### 1. **Fixed Infinite Loop in `start_services.py`**
- **Problem:** The `get_all_profiles()` function was incorrectly extracting profiles, causing infinite repetition during `docker compose down`
- **Solution:** Removed the buggy profile extraction loop and simplified to use `--remove-orphans` flag
- **Location:** `start_services.py` lines 171-202

### 2. **Added Automatic Caddy Fix to Update Process**
- **Problem:** After updates, Caddy would try to get Let's Encrypt certificates, causing HTTPS failures
- **Solution:** Update script now automatically runs `diagnose_and_fix_caddy.sh` after starting services
- **Location:** `scripts/apply_update.sh` lines 87-97

### 3. **Added Error Handling for Docker Compose Down**
- **Problem:** If `docker compose down` failed, update would hang
- **Solution:** Added try/except with fallback to direct `docker stop` commands
- **Location:** `start_services.py` lines 195-202

### 4. **Created Emergency Scripts**
- **`emergency_stop.sh`** - Quick stop all containers
- **`direct_volume_copy.sh`** - Manual volume recovery without docker compose
- **`reset_containers.sh`** - Clean container reset while preserving data

## Update Process Flow (New)

```
1. Pull latest git changes
2. Update system packages (apt-get)
3. Regenerate .env file (preserve existing values)
4. Run service selection wizard
5. Configure services
6. Pull latest Docker images
7. Stop existing containers (with fallback)
8. Start services
9. **NEW:** Diagnose and fix Caddy configuration
10. Display final report with credentials
```

## Volume Recovery Process

### Root Cause of Volume Loss
In commit `654e5d6`, all volumes were renamed from:
- `localai_n8n_storage` → `localai_n8nInstall_n8n_storage`
- `localai_postgres_data` → `localai_n8nInstall_postgres_data`
- etc.

When update runs, Docker Compose creates new empty volumes with new names. Old data remains in old volume names.

### Recovery Steps
1. Stop all containers: `bash ./scripts/emergency_stop.sh`
2. Copy volumes: `bash ./scripts/direct_volume_copy.sh`
3. Restart: `bash ./scripts/06_run_services.sh`

## Testing the Fixed Update

```bash
# Full update (now includes Caddy fix)
sudo bash ./scripts/update.sh

# The update will:
# ✓ Stop containers cleanly (no loop)
# ✓ Start services
# ✓ Fix Caddy configuration automatically
# ✓ Show credentials report
```

## Manual Caddy Fix (if needed)

```bash
bash ./scripts/diagnose_and_fix_caddy.sh
```

This will:
- Check Caddyfile configuration
- Add `auto_https off`
- Prefix all hostnames with `http://`
- Remove Let's Encrypt email
- Remove HSTS headers
- Restart Caddy container
- Show logs

## Key Files Modified

| File | Changes |
|------|---------|
| `start_services.py` | Fixed infinite loop, added error handling |
| `scripts/apply_update.sh` | Added automatic Caddy fix step |
| `scripts/recover_volumes.sh` | Added volume mappings for all services |
| `scripts/direct_volume_copy.sh` | Created for manual recovery |
| `scripts/emergency_stop.sh` | Created for quick emergency stops |
| `scripts/reset_containers.sh` | Created for clean resets |

## Prevention for Future Updates

To prevent volume loss in future updates:
1. **Never run `docker system prune --volumes`** unless intentional
2. **Always check volume list** before and after updates
3. **Use `reset_containers.sh`** instead of manual `docker compose down`
4. **Backup important volumes** before major updates

## Backup Recommendation

Add to cron for automatic backups:
```bash
# Backup n8n and postgres volumes daily
0 2 * * * docker run --rm -v localai_n8nInstall_n8n_storage:/data -v /backup:/backup alpine tar czf /backup/n8n-$(date +\%Y\%m\%d).tar.gz -C /data .
0 2 * * * docker run --rm -v localai_n8nInstall_postgres_data:/data -v /backup:/backup alpine tar czf /backup/postgres-$(date +\%Y\%m\%d).tar.gz -C /data .
```
