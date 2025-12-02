#!/usr/bin/env bash
set -euo pipefail

# Script: validate_caddy_config.sh
# Purpose: Validate and fix Caddyfile configuration for Cloudflare Tunnel compatibility
# Usage: bash scripts/validate_caddy_config.sh [--fix]

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CADDYFILE="$PROJECT_ROOT/Caddyfile"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

FIX_MODE=false
if [[ "${1:-}" == "--fix" ]]; then
    FIX_MODE=true
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Caddy Configuration Validator${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if Caddyfile exists
if [ ! -f "$CADDYFILE" ]; then
    echo -e "${RED}✗ Caddyfile not found at: $CADDYFILE${NC}"
    exit 1
fi

ISSUES_FOUND=0

# Check 1: auto_https setting
echo -e "${YELLOW}[1/5] Checking auto_https setting...${NC}"
if grep -q "auto_https off" "$CADDYFILE"; then
    echo -e "${GREEN}  ✓ auto_https is disabled (correct for Cloudflare Tunnel)${NC}"
else
    echo -e "${RED}  ✗ auto_https is NOT disabled${NC}"
    echo -e "    ${YELLOW}Expected: auto_https off${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

# Check 2: http:// prefix on hostnames
echo -e "${YELLOW}[2/5] Checking hostname prefixes...${NC}"
HTTP_PREFIXED=$(grep -c "^http://{" "$CADDYFILE" || true)
UNPREFIXED=$(grep -c "^{\\$.*HOSTNAME}" "$CADDYFILE" || true)

if [ "$UNPREFIXED" -gt 0 ]; then
    echo -e "${RED}  ✗ Found $UNPREFIXED hostnames without http:// prefix${NC}"
    echo -e "    ${YELLOW}All hostnames should use: http://{\$SERVICE_HOSTNAME}${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ All hostnames properly prefixed with http://${NC}"
fi

# Check 3: LETSENCRYPT_EMAIL in global block
echo -e "${YELLOW}[3/5] Checking for Let's Encrypt email...${NC}"
if grep -q "email.*LETSENCRYPT_EMAIL" "$CADDYFILE"; then
    echo -e "${RED}  ✗ Let's Encrypt email configuration found${NC}"
    echo -e "    ${YELLOW}Should be removed when using Cloudflare Tunnel${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No Let's Encrypt email configuration${NC}"
fi

# Check 4: HSTS headers (should be removed for HTTP-only)
echo -e "${YELLOW}[4/5] Checking for HSTS headers...${NC}"
if grep -q "Strict-Transport-Security" "$CADDYFILE"; then
    echo -e "${YELLOW}  ⚠ HSTS headers found (not harmful but unnecessary for HTTP-only)${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No HSTS headers${NC}"
fi

# Check 5: upgrade-insecure-requests in CSP
echo -e "${YELLOW}[5/5] Checking Content-Security-Policy...${NC}"
if grep -q "upgrade-insecure-requests" "$CADDYFILE"; then
    echo -e "${YELLOW}  ⚠ CSP contains 'upgrade-insecure-requests' (should be removed for HTTP-only)${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ CSP does not force HTTPS upgrades${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✓ Caddyfile is correctly configured for Cloudflare Tunnel!${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Found $ISSUES_FOUND configuration issue(s)${NC}"
    echo ""

    if [ "$FIX_MODE" = false ]; then
        echo -e "${YELLOW}To automatically fix these issues, run:${NC}"
        echo -e "  ${BLUE}bash scripts/validate_caddy_config.sh --fix${NC}"
        echo ""
        exit 1
    fi

    # Fix mode enabled
    echo -e "${YELLOW}Applying fixes...${NC}"
    echo ""

    # Create backup
    BACKUP_FILE="$CADDYFILE.bak.$(date +%Y%m%d-%H%M%S)"
    cp "$CADDYFILE" "$BACKUP_FILE"
    echo -e "${GREEN}  ✓ Backup created: $BACKUP_FILE${NC}"

    # Ask for confirmation
    echo ""
    echo -e "${YELLOW}This will modify your Caddyfile to:${NC}"
    echo "  - Set auto_https off"
    echo "  - Add http:// prefix to all hostnames"
    echo "  - Remove Let's Encrypt email configuration"
    echo "  - Remove HSTS headers"
    echo "  - Remove upgrade-insecure-requests from CSP"
    echo ""
    read -p "Continue with automatic fix? (yes/no): " confirm

    if [[ "$confirm" != "yes" ]]; then
        echo -e "${YELLOW}Fix cancelled. Backup preserved at: $BACKUP_FILE${NC}"
        exit 1
    fi

    echo ""
    echo -e "${YELLOW}Applying fixes...${NC}"

    # Create a reference to the correct Caddyfile from docs
    TEMPLATE_FILE="$PROJECT_ROOT/docs/templates/Caddyfile.cloudflare-tunnel"

    if [ -f "$TEMPLATE_FILE" ]; then
        echo -e "${GREEN}  ✓ Using template: $TEMPLATE_FILE${NC}"
        cp "$TEMPLATE_FILE" "$CADDYFILE"
    else
        echo -e "${RED}  ✗ Template not found. Manual fixes required.${NC}"
        echo -e "    ${YELLOW}Please see: docs/ai/TROUBLESHOOTING.md${NC}"
        exit 1
    fi

    echo ""
    echo -e "${GREEN}✓ Caddyfile fixed successfully!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Review changes: diff $BACKUP_FILE $CADDYFILE"
    echo "  2. Restart Caddy: docker compose -p localai up -d --force-recreate caddy"
    echo "  3. Check logs: docker logs n8nInstall_caddy --tail 50"
    echo ""
fi
