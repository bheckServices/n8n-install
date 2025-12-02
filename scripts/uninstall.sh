#!/usr/bin/env bash
set -euo pipefail

# Script: uninstall.sh
# Purpose: Completely remove all n8n-install services, containers, volumes, networks, and optionally config files
# Usage: sudo bash ./scripts/uninstall.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}========================================${NC}"
echo -e "${RED}  n8n-install UNINSTALL${NC}"
echo -e "${RED}========================================${NC}"
echo ""
echo -e "${YELLOW}WARNING: This will remove ALL n8n-install services and data!${NC}"
echo ""
echo "This script will:"
echo "  1. Stop all n8nInstall containers"
echo "  2. Remove all n8nInstall containers"
echo "  3. Remove all n8nInstall volumes (DATA LOSS!)"
echo "  4. Remove n8nInstall network"
echo "  5. Optionally remove configuration files"
echo "  6. Optionally remove cloned repositories (Supabase)"
echo ""

# Confirmation
read -p "Are you ABSOLUTELY SURE you want to continue? (type 'yes' to confirm): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Uninstall cancelled."
    exit 0
fi

echo ""
read -p "Remove configuration files (.env, backups)? (yes/no): " remove_config
read -p "Remove cloned repositories (supabase/)? (yes/no): " remove_repos

echo ""
echo -e "${BLUE}Starting uninstall process...${NC}"
echo ""

# Step 1: Stop all services
echo -e "${YELLOW}[1/7] Stopping all n8nInstall services...${NC}"
cd "$PROJECT_ROOT"

if docker compose -p localai ps -q > /dev/null 2>&1; then
    echo "  Stopping Docker Compose project 'localai'..."
    docker compose -p localai down 2>/dev/null || true
    echo -e "${GREEN}  ✓ Docker Compose services stopped${NC}"
else
    echo "  No Docker Compose services found"
fi

# Step 2: Remove all n8nInstall containers (including orphaned ones)
echo ""
echo -e "${YELLOW}[2/7] Removing all n8nInstall containers...${NC}"

CONTAINERS=$(docker ps -aq --filter "name=n8nInstall_" 2>/dev/null || true)
if [[ -n "$CONTAINERS" ]]; then
    echo "  Found containers to remove:"
    docker ps -a --filter "name=n8nInstall_" --format "    - {{.Names}} ({{.Status}})"
    echo "  Removing containers..."
    docker rm -f $CONTAINERS 2>/dev/null || true
    echo -e "${GREEN}  ✓ Containers removed${NC}"
else
    echo "  No n8nInstall containers found"
fi

# Step 3: Remove all n8nInstall volumes
echo ""
echo -e "${YELLOW}[3/7] Removing all n8nInstall volumes...${NC}"
echo -e "${RED}  WARNING: This will delete ALL data (databases, files, etc.)${NC}"

VOLUMES=$(docker volume ls --filter "name=n8nInstall_" -q 2>/dev/null || true)
if [[ -n "$VOLUMES" ]]; then
    echo "  Found volumes to remove:"
    docker volume ls --filter "name=n8nInstall_" --format "    - {{.Name}}"

    read -p "  Confirm volume deletion? (type 'DELETE' to confirm): " confirm_volumes

    if [[ "$confirm_volumes" == "DELETE" ]]; then
        echo "  Removing volumes..."
        docker volume rm $VOLUMES 2>/dev/null || true
        echo -e "${GREEN}  ✓ Volumes removed${NC}"
    else
        echo -e "${YELLOW}  ⚠ Volumes NOT removed (user cancelled)${NC}"
    fi
else
    echo "  No n8nInstall volumes found"
fi

# Step 4: Remove n8nInstall network
echo ""
echo -e "${YELLOW}[4/7] Removing n8nInstall network...${NC}"

if docker network inspect n8nInstall_network > /dev/null 2>&1; then
    docker network rm n8nInstall_network 2>/dev/null || true
    echo -e "${GREEN}  ✓ Network removed${NC}"
else
    echo "  Network not found"
fi

# Also remove old network name if exists
if docker network inspect n8n_network > /dev/null 2>&1; then
    docker network rm n8n_network 2>/dev/null || true
    echo -e "${GREEN}  ✓ Old network (n8n_network) removed${NC}"
fi

# Step 5: Remove configuration files
echo ""
echo -e "${YELLOW}[5/7] Removing configuration files...${NC}"

if [[ "$remove_config" == "yes" ]]; then
    echo "  Removing .env file..."
    rm -f "$PROJECT_ROOT/.env" 2>/dev/null || true

    echo "  Removing backups directory..."
    rm -rf "$PROJECT_ROOT/backups" 2>/dev/null || true

    echo "  Removing searxng settings..."
    rm -f "$PROJECT_ROOT/searxng/settings.yml" 2>/dev/null || true

    echo -e "${GREEN}  ✓ Configuration files removed${NC}"
else
    echo -e "${YELLOW}  ⚠ Configuration files preserved${NC}"
    echo "    (You can manually delete .env and backups/ later)"
fi

# Step 6: Remove cloned repositories
echo ""
echo -e "${YELLOW}[6/7] Removing cloned repositories...${NC}"

if [[ "$remove_repos" == "yes" ]]; then
    echo "  Removing Supabase repository..."
    rm -rf "$PROJECT_ROOT/supabase" 2>/dev/null || true
    echo -e "${GREEN}  ✓ Repositories removed${NC}"
else
    echo -e "${YELLOW}  ⚠ Repositories preserved${NC}"
    echo "    (You can manually delete supabase/ later)"
fi

# Step 7: Docker system cleanup
echo ""
echo -e "${YELLOW}[7/7] Cleaning up Docker system...${NC}"

read -p "Run Docker system prune to free up space? (yes/no): " prune_docker

if [[ "$prune_docker" == "yes" ]]; then
    echo "  Removing unused Docker resources..."
    docker system prune -f 2>/dev/null || true
    echo -e "${GREEN}  ✓ Docker system cleaned${NC}"
else
    echo -e "${YELLOW}  ⚠ Docker cleanup skipped${NC}"
fi

# Final verification
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Verification${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

echo "Checking for remaining n8nInstall resources..."
echo ""

REMAINING_CONTAINERS=$(docker ps -aq --filter "name=n8nInstall_" 2>/dev/null | wc -l)
REMAINING_VOLUMES=$(docker volume ls --filter "name=n8nInstall_" -q 2>/dev/null | wc -l)
REMAINING_NETWORK=$(docker network inspect n8nInstall_network > /dev/null 2>&1 && echo "1" || echo "0")

echo "Containers: $REMAINING_CONTAINERS"
echo "Volumes: $REMAINING_VOLUMES"
echo "Network: $REMAINING_NETWORK"
echo ""

if [[ "$REMAINING_CONTAINERS" -eq 0 ]] && [[ "$REMAINING_VOLUMES" -eq 0 ]] && [[ "$REMAINING_NETWORK" -eq 0 ]]; then
    echo -e "${GREEN}✓ Uninstall complete! All n8nInstall resources removed.${NC}"
else
    echo -e "${YELLOW}⚠ Some resources may still exist. Manual cleanup may be needed.${NC}"

    if [[ "$REMAINING_CONTAINERS" -gt 0 ]]; then
        echo ""
        echo "Remaining containers:"
        docker ps -a --filter "name=n8nInstall_" --format "  - {{.Names}}"
    fi

    if [[ "$REMAINING_VOLUMES" -gt 0 ]]; then
        echo ""
        echo "Remaining volumes:"
        docker volume ls --filter "name=n8nInstall_" --format "  - {{.Name}}"
    fi
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Summary${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

if [[ "$remove_config" == "yes" ]]; then
    echo -e "${GREEN}✓ Configuration files removed${NC}"
else
    echo -e "${YELLOW}⚠ Configuration files preserved in:${NC}"
    echo "    - $PROJECT_ROOT/.env"
    echo "    - $PROJECT_ROOT/backups/"
fi

if [[ "$remove_repos" == "yes" ]]; then
    echo -e "${GREEN}✓ Cloned repositories removed${NC}"
else
    echo -e "${YELLOW}⚠ Cloned repositories preserved in:${NC}"
    echo "    - $PROJECT_ROOT/supabase/"
fi

echo ""
echo "To reinstall n8n-install, run:"
echo "  sudo bash ./scripts/install.sh"
echo ""
