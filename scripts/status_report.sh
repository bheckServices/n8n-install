#!/usr/bin/env bash
set -euo pipefail

# Script: status_report.sh
# Purpose: Interactive service health checker and diagnostic tool
# Usage: bash scripts/status_report.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load .env if exists
if [[ -f "${PROJECT_ROOT}/.env" ]]; then
    source "${PROJECT_ROOT}/.env"
fi

function show_menu() {
    clear
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}  n8n-install Status Reporter${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo "1. All Services Overview"
    echo "2. n8n Detailed Status"
    echo "3. Database Status"
    echo "4. Network Status"
    echo "5. Resource Usage"
    echo "6. Recent Errors (last 1 hour)"
    echo "7. Generate Full Diagnostic Report"
    echo "8. Exit"
    echo ""
    read -p "Select an option [1-8]: " choice
    echo ""
}

function all_services_overview() {
    echo -e "${BLUE}=== All Services Overview ===${NC}"
    echo ""

    # Check if Docker is running
    if ! docker info > /dev/null 2>&1; then
        echo -e "${RED}✗ Docker is not running${NC}"
        return 1
    fi

    # List all n8nInstall containers
    echo -e "${YELLOW}Container Status:${NC}"
    docker ps -a --filter "name=n8nInstall_" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}" || true

    echo ""
    echo -e "${YELLOW}Health Status:${NC}"
    for container in $(docker ps --filter "name=n8nInstall_" --format "{{.Names}}"); do
        health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
        if [[ "$health" == "healthy" ]]; then
            echo -e "${GREEN}✓${NC} $container: $health"
        elif [[ "$health" == "no healthcheck" ]]; then
            echo -e "${BLUE}○${NC} $container: $health"
        else
            echo -e "${RED}✗${NC} $container: $health"
        fi
    done

    echo ""
    read -p "Press Enter to continue..."
}

function n8n_detailed_status() {
    echo -e "${BLUE}=== n8n Detailed Status ===${NC}"
    echo ""

    if ! docker ps --filter "name=n8nInstall_n8n" --format "{{.Names}}" | grep -q "n8nInstall_n8n"; then
        echo -e "${RED}✗ n8n container is not running${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    echo -e "${YELLOW}n8n Version:${NC}"
    docker exec n8nInstall_n8n n8n --version 2>/dev/null || echo "Unable to determine version"

    echo ""
    echo -e "${YELLOW}Worker Status:${NC}"
    docker ps --filter "name=n8nInstall_n8n-worker" --format "table {{.Names}}\t{{.Status}}" || echo "No workers running"

    echo ""
    echo -e "${YELLOW}Database Connection:${NC}"
    if docker exec n8nInstall_n8n wget -qO- http://localhost:5678/healthz 2>/dev/null | grep -q "ok"; then
        echo -e "${GREEN}✓${NC} n8n healthcheck passed"
    else
        echo -e "${RED}✗${NC} n8n healthcheck failed"
    fi

    echo ""
    echo -e "${YELLOW}Recent Logs (last 20 lines):${NC}"
    docker logs n8nInstall_n8n --tail=20 2>&1 | tail -20

    echo ""
    read -p "Press Enter to continue..."
}

function database_status() {
    echo -e "${BLUE}=== Database Status ===${NC}"
    echo ""

    if ! docker ps --filter "name=n8nInstall_postgres" --format "{{.Names}}" | grep -q "n8nInstall_postgres"; then
        echo -e "${RED}✗ Postgres container is not running${NC}"
        read -p "Press Enter to continue..."
        return 1
    fi

    echo -e "${YELLOW}Postgres Version:${NC}"
    docker exec n8nInstall_postgres psql -U "${POSTGRES_USER:-n8n}" -c "SELECT version();" 2>/dev/null | grep PostgreSQL || echo "Unable to query"

    echo ""
    echo -e "${YELLOW}Databases:${NC}"
    docker exec n8nInstall_postgres psql -U "${POSTGRES_USER:-n8n}" -l 2>/dev/null || echo "Unable to list databases"

    echo ""
    echo -e "${YELLOW}Connection Count:${NC}"
    docker exec n8nInstall_postgres psql -U "${POSTGRES_USER:-n8n}" -c "SELECT count(*) as connections FROM pg_stat_activity;" 2>/dev/null || echo "Unable to query"

    echo ""
    echo -e "${YELLOW}Database Sizes:${NC}"
    docker exec n8nInstall_postgres psql -U "${POSTGRES_USER:-n8n}" -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database ORDER BY pg_database_size(datname) DESC;" 2>/dev/null || echo "Unable to query"

    echo ""
    read -p "Press Enter to continue..."
}

function network_status() {
    echo -e "${BLUE}=== Network Status ===${NC}"
    echo ""

    echo -e "${YELLOW}n8nInstall Network:${NC}"
    if docker network inspect n8nInstall_network > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Network exists"
        echo ""
        echo -e "${YELLOW}Containers on network:${NC}"
        docker network inspect n8nInstall_network --format='{{range .Containers}}{{.Name}}{{"\n"}}{{end}}'
    else
        echo -e "${RED}✗${NC} Network does not exist"
    fi

    echo ""
    echo -e "${YELLOW}DNS Resolution Test:${NC}"
    if docker ps --filter "name=n8nInstall_n8n" --format "{{.Names}}" | grep -q "n8nInstall_n8n"; then
        if docker exec n8nInstall_n8n ping -c 1 n8nInstall_postgres > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} n8n can reach postgres"
        else
            echo -e "${RED}✗${NC} n8n cannot reach postgres"
        fi

        if docker exec n8nInstall_n8n ping -c 1 n8nInstall_redis > /dev/null 2>&1; then
            echo -e "${GREEN}✓${NC} n8n can reach redis"
        else
            echo -e "${RED}✗${NC} n8n cannot reach redis"
        fi
    fi

    echo ""
    read -p "Press Enter to continue..."
}

function resource_usage() {
    echo -e "${BLUE}=== Resource Usage ===${NC}"
    echo ""

    echo -e "${YELLOW}Container Resource Usage:${NC}"
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | grep n8nInstall || echo "No containers running"

    echo ""
    echo -e "${YELLOW}Volume Sizes:${NC}"
    docker system df -v 2>/dev/null | grep n8nInstall || echo "No volumes found"

    echo ""
    echo -e "${YELLOW}Host Disk Usage:${NC}"
    df -h | grep -E "Filesystem|/$" || df -h

    echo ""
    read -p "Press Enter to continue..."
}

function recent_errors() {
    echo -e "${BLUE}=== Recent Errors (last 1 hour) ===${NC}"
    echo ""

    for container in $(docker ps --filter "name=n8nInstall_" --format "{{.Names}}"); do
        echo -e "${YELLOW}Checking $container...${NC}"
        error_count=$(docker logs "$container" --since 1h 2>&1 | grep -ci "error\|fatal\|exception" || echo "0")
        if [[ "$error_count" -gt 0 ]]; then
            echo -e "${RED}Found $error_count error(s)${NC}"
            docker logs "$container" --since 1h 2>&1 | grep -i "error\|fatal\|exception" | tail -10
        else
            echo -e "${GREEN}No errors found${NC}"
        fi
        echo ""
    done

    read -p "Press Enter to continue..."
}

function generate_full_report() {
    local report_file="diagnostic-report-$(date +%Y-%m-%d-%H%M%S).txt"

    echo -e "${BLUE}=== Generating Full Diagnostic Report ===${NC}"
    echo ""
    echo "Report will be saved to: $report_file"
    echo ""

    {
        echo "=========================================="
        echo "  n8n-install Diagnostic Report"
        echo "  Generated: $(date)"
        echo "=========================================="
        echo ""

        echo "=== Docker Version ==="
        docker --version
        docker compose version
        echo ""

        echo "=== All Services ==="
        docker ps -a --filter "name=n8nInstall_" --format "table {{.Names}}\t{{.Status}}\t{{.RunningFor}}"
        echo ""

        echo "=== Health Status ==="
        for container in $(docker ps --filter "name=n8nInstall_" --format "{{.Names}}"); do
            health=$(docker inspect "$container" --format='{{.State.Health.Status}}' 2>/dev/null || echo "no healthcheck")
            echo "$container: $health"
        done
        echo ""

        echo "=== Resource Usage ==="
        docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}" | grep n8nInstall
        echo ""

        echo "=== Network Status ==="
        docker network inspect n8nInstall_network --format='{{range .Containers}}{{.Name}}{{"\n"}}{{end}}' 2>/dev/null || echo "Network not found"
        echo ""

        echo "=== Volume Sizes ==="
        docker volume ls --filter "name=n8nInstall_" --format "table {{.Name}}\t{{.Driver}}"
        echo ""

        echo "=== Recent Errors (last 1 hour) ==="
        for container in $(docker ps --filter "name=n8nInstall_" --format "{{.Names}}"); do
            echo "--- $container ---"
            docker logs "$container" --since 1h 2>&1 | grep -i "error\|fatal\|exception" | tail -20 || echo "No errors"
            echo ""
        done

        echo "=== Environment (sanitized) ==="
        if [[ -f "${PROJECT_ROOT}/.env" ]]; then
            grep -E "^[A-Z_]+=.+" "${PROJECT_ROOT}/.env" | sed 's/=.*/=***REDACTED***/' || echo "Unable to read .env"
        else
            echo ".env file not found"
        fi
        echo ""

        echo "=== End of Report ==="
    } > "$report_file"

    echo -e "${GREEN}✓${NC} Report saved to: $report_file"
    echo ""
    read -p "Press Enter to continue..."
}

# Main loop
while true; do
    show_menu
    case $choice in
        1) all_services_overview ;;
        2) n8n_detailed_status ;;
        3) database_status ;;
        4) network_status ;;
        5) resource_usage ;;
        6) recent_errors ;;
        7) generate_full_report ;;
        8) echo "Exiting..."; exit 0 ;;
        *) echo -e "${RED}Invalid option${NC}"; sleep 2 ;;
    esac
done
