# Safe Update Guide

## ✅ Your Update Script is Now Fixed!

The following issues have been resolved:
- ✅ Infinite loop during `docker compose down` - **FIXED**
- ✅ Caddy HTTPS issues after update - **AUTO-FIXED**
- ✅ Error handling for failed operations - **ADDED**

## How to Run a Safe Update

### Option 1: Full Safe Update (Recommended)

```bash
# Step 1: Pre-update check
bash ./scripts/pre_update_check.sh

# Step 2: Run update
sudo bash ./scripts/update.sh

# Step 3: Verify services
docker ps --filter "name=n8nInstall"
```

### Option 2: Quick Update

```bash
sudo bash ./scripts/update.sh
```

That's it! The script now:
1. Stops containers cleanly (no infinite loop)
2. Updates code and images
3. Restarts services
4. **Automatically fixes Caddy configuration**
5. Shows credentials report

## What Happens During Update

```
┌─────────────────────────────────────┐
│ 1. Git pull latest changes          │
├─────────────────────────────────────┤
│ 2. Update system packages           │
├─────────────────────────────────────┤
│ 3. Regenerate .env (keep values)    │
├─────────────────────────────────────┤
│ 4. Service selection wizard         │
├─────────────────────────────────────┤
│ 5. Configure services                │
├─────────────────────────────────────┤
│ 6. Pull latest Docker images        │
├─────────────────────────────────────┤
│ 7. Stop containers (FIXED - no loop)│
├─────────────────────────────────────┤
│ 8. Start services                   │
├─────────────────────────────────────┤
│ 9. Fix Caddy (NEW - automatic!)     │
├─────────────────────────────────────┤
│ 10. Display credentials              │
└─────────────────────────────────────┘
```

## If Something Goes Wrong

### Emergency Stop
```bash
bash ./scripts/emergency_stop.sh
```

### Manual Caddy Fix
```bash
bash ./scripts/diagnose_and_fix_caddy.sh
```

### Restart Services
```bash
bash ./scripts/06_run_services.sh
```

### Reset Containers (Keep Data)
```bash
bash ./scripts/reset_containers.sh
bash ./scripts/06_run_services.sh
```

## Volume Safety

Your volumes are **always preserved** during updates. The update script:
- ✅ Never uses `docker compose down -v` (no volume deletion)
- ✅ Never runs `docker system prune --volumes`
- ✅ Only stops/removes containers, not volumes

## Verify Update Success

```bash
# Check all containers are running
docker ps --filter "name=n8nInstall"

# Check logs for errors
docker compose -p localai logs --tail=50

# Test your main service
curl -I https://your-n8n-hostname.com
```

## Common Update Scenarios

### Scenario 1: Normal Update
```bash
sudo bash ./scripts/update.sh
# ✓ Works perfectly with new fixes
```

### Scenario 2: Update After Long Time
```bash
# Run pre-check first
bash ./scripts/pre_update_check.sh

# Then update
sudo bash ./scripts/update.sh
```

### Scenario 3: Update Failed Mid-Way
```bash
# Stop everything
bash ./scripts/emergency_stop.sh

# Restart cleanly
bash ./scripts/06_run_services.sh

# Fix Caddy if needed
bash ./scripts/diagnose_and_fix_caddy.sh
```

## Update Frequency Recommendations

- **Security updates**: Weekly
- **Feature updates**: Monthly
- **Major version updates**: When stable (wait 1-2 weeks after release)

## Pre-Update Checklist

Run this before major updates:
```bash
bash ./scripts/pre_update_check.sh
```

This checks:
- ✓ Critical volumes exist
- ✓ Disk space available
- ✓ Update fixes are present
- ✓ Caddy fix script exists

## Rollback Strategy

If update breaks something:

```bash
# 1. Stop services
bash ./scripts/emergency_stop.sh

# 2. Restore from git
git reset --hard HEAD~1

# 3. Restart with old version
bash ./scripts/06_run_services.sh
```

## Key Improvements

| Issue | Before | After |
|-------|--------|-------|
| Docker compose down | Infinite loop | Clean stop with fallback |
| Caddy HTTPS | Manual fix needed | Automatic fix |
| Error handling | Script crashes | Graceful fallback |
| Volume safety | Risk of loss | Always preserved |

## Need Help?

1. Check logs: `docker compose -p localai logs`
2. Run diagnostics: `bash ./scripts/pre_update_check.sh`
3. Emergency stop: `bash ./scripts/emergency_stop.sh`
4. Restart clean: `bash ./scripts/06_run_services.sh`

---

**Your update process is now production-ready!** 🚀
