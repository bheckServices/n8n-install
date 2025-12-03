#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

log_info "Pre-Update Safety Check"
log_info "======================="
log_info ""

ISSUES=0

# Check 1: Verify volumes exist
log_info "[1/5] Checking critical volumes..."
CRITICAL_VOLUMES=(
    "localai_n8nInstall_n8n_storage"
    "localai_n8nInstall_postgres_data"
    "localai_n8nInstall_valkey-data"
)

for vol in "${CRITICAL_VOLUMES[@]}"; do
    if docker volume inspect "$vol" >/dev/null 2>&1; then
        log_success "  ✓ $vol exists"
    else
        log_warning "  ⚠ $vol NOT FOUND"
        ISSUES=$((ISSUES + 1))
    fi
done

# Check 2: List all containers
log_info ""
log_info "[2/5] Current running containers:"
docker ps --filter "name=n8nInstall" --format "  - {{.Names}} ({{.Status}})" || log_warning "No containers running"

# Check 3: Check disk space
log_info ""
log_info "[3/5] Checking disk space..."
DISK_USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')
if [ "$DISK_USAGE" -gt 90 ]; then
    log_warning "  ⚠ Disk usage is ${DISK_USAGE}% - consider cleanup"
    ISSUES=$((ISSUES + 1))
else
    log_success "  ✓ Disk usage: ${DISK_USAGE}%"
fi

# Check 4: Verify start_services.py has the fix
log_info ""
log_info "[4/5] Verifying update script fixes..."
if grep -q "remove-orphans" "../start_services.py" 2>/dev/null; then
    log_success "  ✓ Infinite loop fix present"
else
    log_error "  ✗ Infinite loop fix MISSING"
    ISSUES=$((ISSUES + 1))
fi

# Check 5: Verify Caddy fix script exists
log_info ""
log_info "[5/5] Checking Caddy fix script..."
if [ -f "$(dirname "$0")/diagnose_and_fix_caddy.sh" ]; then
    log_success "  ✓ Caddy fix script exists"
else
    log_warning "  ⚠ Caddy fix script not found"
    ISSUES=$((ISSUES + 1))
fi

log_info ""
log_info "======================="

if [ $ISSUES -eq 0 ]; then
    log_success "✓ All checks passed - safe to update!"
    log_info ""
    log_info "Run update with: sudo bash ./scripts/update.sh"
    exit 0
else
    log_warning "⚠ Found $ISSUES issue(s)"
    log_info ""
    log_info "Recommendations:"
    log_info "  1. If volumes missing, run: bash ./scripts/direct_volume_copy.sh"
    log_info "  2. If disk full, run: docker system prune (WITHOUT --volumes)"
    log_info "  3. Pull latest fixes: git pull"
    log_info ""
    read -p "Continue with update anyway? (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        log_info "Update cancelled."
        exit 1
    fi
fi
