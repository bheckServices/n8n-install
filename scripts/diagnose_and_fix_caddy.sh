#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Caddy Cloudflare Tunnel Diagnostics${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Get project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

CADDYFILE="$PROJECT_ROOT/Caddyfile"

echo -e "${YELLOW}Project Root: $PROJECT_ROOT${NC}"
echo ""

# Check if Caddyfile exists
if [ ! -f "$CADDYFILE" ]; then
    echo -e "${RED}✗ Caddyfile not found at: $CADDYFILE${NC}"
    exit 1
fi

ISSUES_FOUND=0

echo -e "${YELLOW}[1/5] Checking auto_https setting...${NC}"
if grep -q "auto_https off" "$CADDYFILE"; then
    echo -e "${GREEN}  ✓ auto_https is disabled${NC}"
else
    echo -e "${RED}  ✗ auto_https is NOT disabled${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
fi

echo -e "${YELLOW}[2/5] Checking hostname prefixes...${NC}"
UNPREFIXED=$(grep -cE "^[[:space:]]*\{\\$.*HOSTNAME\}" "$CADDYFILE" || true)
if [ "$UNPREFIXED" -gt 0 ]; then
    echo -e "${RED}  ✗ Found $UNPREFIXED hostnames without http:// prefix${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ All hostnames properly prefixed${NC}"
fi

echo -e "${YELLOW}[3/5] Checking for Let's Encrypt email...${NC}"
if grep -q "email.*LETSENCRYPT_EMAIL" "$CADDYFILE"; then
    echo -e "${RED}  ✗ Let's Encrypt email configuration found${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No Let's Encrypt email configuration${NC}"
fi

echo -e "${YELLOW}[4/5] Checking for HSTS headers...${NC}"
if grep -q "Strict-Transport-Security" "$CADDYFILE"; then
    echo -e "${RED}  ✗ HSTS headers found${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No HSTS headers${NC}"
fi

echo -e "${YELLOW}[5/5] Checking Caddy container logs...${NC}"
if docker logs n8nInstall_caddy --tail 10 2>&1 | grep -qi "acme\|certificate\|NXDOMAIN"; then
    echo -e "${RED}  ✗ Found Let's Encrypt errors in logs${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No Let's Encrypt errors in recent logs${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Diagnostic Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if [ "$ISSUES_FOUND" -eq 0 ]; then
    echo -e "${GREEN}✓ Caddyfile is correctly configured!${NC}"
    echo -e "${GREEN}✓ No issues detected${NC}"
    echo ""
    exit 0
fi

echo -e "${RED}✗ Found $ISSUES_FOUND issue(s)${NC}"
echo ""
echo -e "${YELLOW}Applying automatic fix...${NC}"
echo ""

# Backup
BACKUP_FILE="$CADDYFILE.bak.$(date +%Y%m%d-%H%M%S)"
cp "$CADDYFILE" "$BACKUP_FILE"
echo -e "${GREEN}  ✓ Backup created: $BACKUP_FILE${NC}"

# Fix 1: Ensure auto_https off in global block
echo -e "${YELLOW}  [1/4] Setting auto_https off...${NC}"
if grep -q "auto_https off" "$CADDYFILE"; then
    echo -e "${GREEN}    ✓ Already set${NC}"
else
    # Add auto_https off to global block
    sed -i '1s/^/{\n    auto_https off\n    admin off\n}\n\n/' "$CADDYFILE"
    echo -e "${GREEN}    ✓ Added auto_https off${NC}"
fi

# Fix 2: Add http:// prefix to all hostnames
echo -e "${YELLOW}  [2/4] Adding http:// prefixes...${NC}"
sed -i 's/^{\$\(.*HOSTNAME\)}/http:\/\/{\$\1}/g' "$CADDYFILE"
echo -e "${GREEN}    ✓ Hostnames prefixed${NC}"

# Fix 3: Remove Let's Encrypt email
echo -e "${YELLOW}  [3/4] Removing Let's Encrypt email...${NC}"
sed -i '/email.*LETSENCRYPT_EMAIL/d' "$CADDYFILE"
echo -e "${GREEN}    ✓ Let's Encrypt email removed${NC}"

# Fix 4: Remove HSTS headers
echo -e "${YELLOW}  [4/4] Removing HSTS headers...${NC}"
sed -i '/Strict-Transport-Security/d' "$CADDYFILE"
echo -e "${GREEN}    ✓ HSTS headers removed${NC}"

echo ""
echo -e "${GREEN}✓ Caddyfile fixed successfully!${NC}"
echo ""

# Restart Caddy
echo -e "${YELLOW}Restarting Caddy container...${NC}"
cd "$PROJECT_ROOT"
if docker compose -p localai restart caddy; then
    echo -e "${GREEN}✓ Caddy restarted successfully${NC}"
else
    echo -e "${RED}✗ Failed to restart Caddy${NC}"
    echo -e "${YELLOW}Try manually: cd $PROJECT_ROOT && docker compose -p localai restart caddy${NC}"
    exit 1
fi

echo ""
echo -e "${YELLOW}Waiting 5 seconds for Caddy to start...${NC}"
sleep 5

echo ""
echo -e "${YELLOW}Checking new logs...${NC}"
docker logs n8nInstall_caddy --tail 20

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Fix Complete${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo -e "${GREEN}✓ Caddy is now configured for HTTP-only mode${NC}"
echo -e "${GREEN}✓ Cloudflare Tunnel should handle all HTTPS${NC}"
echo ""
echo -e "${YELLOW}Test your services:${NC}"
echo "  - https://searxng.verifymyllcname.com"
echo "  - Check other service hostnames in your .env file"
echo ""
