#!/usr/bin/env bash
# Bash script to check Cloudflare Tunnel status (for Linux/WSL with Docker access)
# Usage: bash scripts/check_tunnel.sh

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}==================================${NC}"
echo -e "${CYAN}Cloudflare Tunnel Status Check${NC}"
echo -e "${CYAN}==================================${NC}"
echo ""

# Check if cloudflared container exists
echo -e "${YELLOW}[1/5] Checking Cloudflare Tunnel container...${NC}"
docker ps -a --filter "name=n8nInstall_cloudflared" --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"
echo ""

# Check Caddy container
echo -e "${YELLOW}[2/5] Checking Caddy reverse proxy...${NC}"
docker ps -a --filter "name=n8nInstall_caddy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
echo ""

# Check SearXNG container
echo -e "${YELLOW}[3/5] Checking SearXNG container...${NC}"
docker ps -a --filter "name=n8nInstall_searxng" --format "table {{.Names}}\t{{.Status}}"
echo ""

# Check tunnel logs (last 30 lines)
echo -e "${YELLOW}[4/5] Cloudflare Tunnel Logs (last 30 lines):${NC}"
docker logs n8nInstall_cloudflared --tail 30 2>&1 || echo -e "${RED}Failed to get logs${NC}"
echo ""

# Check Caddy logs for errors
echo -e "${YELLOW}[5/5] Caddy Logs (last 20 lines):${NC}"
docker logs n8nInstall_caddy --tail 20 2>&1 || echo -e "${RED}Failed to get logs${NC}"
echo ""

echo -e "${CYAN}==================================${NC}"
echo -e "${CYAN}Status Check Complete${NC}"
echo -e "${CYAN}==================================${NC}"
echo ""
echo -e "${GREEN}To test connectivity:${NC}"
echo -e "  ${WHITE}1. Check if tunnel shows 'connected' in logs above${NC}"
echo -e "  ${WHITE}2. Visit: https://searxng.verifymyllcname.com${NC}"
echo -e "  ${WHITE}3. Check Cloudflare Dashboard for tunnel health${NC}"
echo ""
