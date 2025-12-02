#!/usr/bin/env bash
set -euo pipefail

# Script: validate_install.sh
# Purpose: Post-install validation checks
# Usage: bash scripts/validate_install.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
WARNINGS=0

function check_passed() {
    echo -e "${GREEN}✓${NC} $1"
    ((PASSED++))
}

function check_failed() {
    echo -e "${RED}✗${NC} $1"
    ((FAILED++))
}

function check_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((WARNINGS++))
}

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n-install Validation${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Load .env
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    source "${PROJECT_ROOT}/.env"
    check_passed ".env file exists"
else
    check_failed ".env file not found"
    echo -e "${RED}Installation appears incomplete. Run scripts/install.sh first.${NC}"
    exit 1
fi

echo ""
echo -e "${BLUE}=== Docker Checks ===${NC}"

# Docker running
if docker info > /dev/null 2>&1; then
    check_passed "Docker is running"
else
    check_failed "Docker is not running"
fi

# Docker Compose version
if docker compose version > /dev/null 2>&1; then
    check_passed "Docker Compose v2 is available"
else
    check_failed "Docker Compose v2 not found"
fi

echo ""
echo -e "${BLUE}=== Container Checks ===${NC}"

# All containers have prefix
UNPREFIXED=$(docker ps -a --format '{{.Names}}' | grep -v "^n8nInstall_" | grep -v "^$" || true)
if [[ -z "$UNPREFIXED" ]]; then
    check_passed "All containers have n8nInstall_ prefix"
else
    check_warning "Some containers without prefix found (may be unrelated)"
fi

# Core services running
for service in postgres redis caddy; do
    if docker ps --filter "name=n8nInstall_${service}" --format "{{.Names}}" | grep -q "n8nInstall_${service}"; then
        if docker inspect "n8nInstall_${service}" --format='{{.State.Status}}' | grep -q "running"; then
            check_passed "Core service running: ${service}"
        else
            check_failed "Core service not running: ${service}"
        fi
    else
        check_failed "Core service not found: ${service}"
    fi
done

# Check for Exited/Restarting containers
EXITED=$(docker ps -a --filter "name=n8nInstall_" --filter "status=exited" --format "{{.Names}}" || true)
if [[ -z "$EXITED" ]]; then
    check_passed "No exited containers"
else
    check_failed "Exited containers found: $EXITED"
fi

RESTARTING=$(docker ps --filter "name=n8nInstall_" --filter "status=restarting" --format "{{.Names}}" || true)
if [[ -z "$RESTARTING" ]]; then
    check_passed "No restarting containers"
else
    check_failed "Restarting containers found: $RESTARTING"
fi

echo ""
echo -e "${BLUE}=== Network Checks ===${NC}"

# Network exists
if docker network inspect n8nInstall_network > /dev/null 2>&1; then
    check_passed "n8nInstall_network exists"
else
    check_failed "n8nInstall_network not found"
fi

# Containers on network
NETWORK_COUNT=$(docker network inspect n8nInstall_network --format='{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' 2>/dev/null | wc -l)
if [[ $NETWORK_COUNT -gt 0 ]]; then
    check_passed "Containers on network: $NETWORK_COUNT"
else
    check_failed "No containers on n8nInstall_network"
fi

echo ""
echo -e "${BLUE}=== Volume Checks ===${NC}"

# Volumes have prefix
UNPREFIXED_VOLS=$(docker volume ls --format '{{.Name}}' | grep -v "^n8nInstall_" | grep -v "^$" || true)
if [[ -z "$UNPREFIXED_VOLS" ]]; then
    check_passed "All volumes have n8nInstall_ prefix"
else
    check_warning "Some volumes without prefix found (may be unrelated)"
fi

# Core volumes exist
for volume in postgres_data redis_data caddy_data n8n_storage; do
    if docker volume ls --format '{{.Name}}' | grep -q "n8nInstall_${volume}"; then
        check_passed "Volume exists: n8nInstall_${volume}"
    else
        check_warning "Volume not found: n8nInstall_${volume} (may not be needed)"
    fi
done

echo ""
echo -e "${BLUE}=== Configuration Checks ===${NC}"

# Check required env vars
REQUIRED_VARS=(
    "COMPOSE_PROFILES"
    "LETSENCRYPT_EMAIL"
    "POSTGRES_PASSWORD"
)

for var in "${REQUIRED_VARS[@]}"; do
    if [[ -n "${!var:-}" ]]; then
        check_passed "Required var set: $var"
    else
        check_failed "Required var missing: $var"
    fi
done

# Check for empty vars
EMPTY_VARS=$(grep "^[A-Z_]*=$" "${PROJECT_ROOT}/.env" || true)
if [[ -z "$EMPTY_VARS" ]]; then
    check_passed "No empty environment variables"
else
    check_warning "Some variables may be empty (check .env)"
fi

# .env permissions
ENV_PERMS=$(stat -c "%a" "${PROJECT_ROOT}/.env" 2>/dev/null || stat -f "%Lp" "${PROJECT_ROOT}/.env" 2>/dev/null || echo "unknown")
if [[ "$ENV_PERMS" == "600" ]] || [[ "$ENV_PERMS" == "400" ]]; then
    check_passed ".env has restrictive permissions: $ENV_PERMS"
else
    check_warning ".env permissions: $ENV_PERMS (should be 600)"
fi

echo ""
echo -e "${BLUE}=== Service Health Checks ===${NC}"

# Postgres
if docker exec n8nInstall_postgres pg_isready -U "${POSTGRES_USER:-n8n}" > /dev/null 2>&1; then
    check_passed "Postgres is accepting connections"
else
    check_failed "Postgres is not accepting connections"
fi

# Check n8n database exists
if docker exec n8nInstall_postgres psql -U "${POSTGRES_USER:-n8n}" -lqt 2>/dev/null | cut -d \| -f 1 | grep -qw "${POSTGRES_DB:-n8n}"; then
    check_passed "n8n database exists"
else
    check_failed "n8n database does not exist"
fi

# Redis
if docker exec n8nInstall_redis redis-cli ping > /dev/null 2>&1; then
    check_passed "Redis is responding"
else
    check_failed "Redis is not responding"
fi

# Caddy config
if docker exec n8nInstall_caddy caddy validate --config /etc/caddy/Caddyfile > /dev/null 2>&1; then
    check_passed "Caddy config is valid"
else
    check_failed "Caddy config has errors"
fi

echo ""
echo -e "${BLUE}=== Port Exposure Check ===${NC}"

# Only Caddy should expose ports
EXPOSED_SERVICES=$(docker compose -p localai config 2>/dev/null | grep -B5 "ports:" | grep "container_name:" | grep -v "caddy" || true)
if [[ -z "$EXPOSED_SERVICES" ]]; then
    check_passed "Only Caddy exposes ports (as expected)"
else
    check_warning "Services other than Caddy may expose ports"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Validation Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${GREEN}Passed:  $PASSED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"
echo -e "${RED}Failed:  $FAILED${NC}"
echo ""

if [[ $FAILED -eq 0 ]]; then
    echo -e "${GREEN}✓ Installation validation successful!${NC}"
    echo ""
    echo "Next steps:"
    echo "  - Access services via URLs in final report"
    echo "  - Check status: bash scripts/status_report.sh"
    exit 0
else
    echo -e "${RED}✗ Validation failed with $FAILED error(s)${NC}"
    echo ""
    echo "Troubleshooting:"
    echo "  - Review errors above"
    echo "  - Check logs: docker compose -p localai logs"
    echo "  - See docs/ai/TROUBLESHOOTING.md"
    exit 1
fi
