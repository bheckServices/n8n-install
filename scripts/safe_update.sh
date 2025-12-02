#!/usr/bin/env bash
set -euo pipefail

# Script: safe_update.sh
# Purpose: Safely update n8n-install configuration files without losing data
# Usage: bash scripts/safe_update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  n8n-install Safe Update${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

cd "$PROJECT_ROOT"

# Check if git repo
if [ ! -d .git ]; then
    echo -e "${RED}✗ Not a git repository. Cannot update.${NC}"
    exit 1
fi

# Check for uncommitted changes in critical files
echo -e "${YELLOW}[1/6] Checking for local modifications...${NC}"
MODIFIED_FILES=$(git status --porcelain Caddyfile docker-compose.yml .env 2>/dev/null || true)

if [ -n "$MODIFIED_FILES" ]; then
    echo -e "${YELLOW}  Found modified files:${NC}"
    echo "$MODIFIED_FILES" | sed 's/^/    /'
    echo ""
    echo -e "${YELLOW}  These files contain your custom configuration.${NC}"
    echo ""
else
    echo -e "${GREEN}  ✓ No local modifications to critical files${NC}"
fi

# Backup current configuration
echo ""
echo -e "${YELLOW}[2/6] Creating backup...${NC}"
BACKUP_DIR="$PROJECT_ROOT/backups/update-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup critical files
for file in .env Caddyfile docker-compose.yml; do
    if [ -f "$PROJECT_ROOT/$file" ]; then
        cp "$PROJECT_ROOT/$file" "$BACKUP_DIR/"
        echo -e "${GREEN}  ✓ Backed up: $file${NC}"
    fi
done

echo -e "${GREEN}  ✓ Backup created at: $BACKUP_DIR${NC}"

# Stash changes
echo ""
echo -e "${YELLOW}[3/6] Stashing local changes...${NC}"
if git stash push -u -m "Auto-stash before update $(date +%Y%m%d-%H%M%S)"; then
    echo -e "${GREEN}  ✓ Local changes stashed${NC}"
    STASHED=true
else
    echo -e "${YELLOW}  ⚠ Nothing to stash${NC}"
    STASHED=false
fi

# Pull updates
echo ""
echo -e "${YELLOW}[4/6] Pulling latest changes from git...${NC}"
if git pull; then
    echo -e "${GREEN}  ✓ Successfully pulled updates${NC}"
else
    echo -e "${RED}  ✗ Git pull failed${NC}"
    if [ "$STASHED" = true ]; then
        echo -e "${YELLOW}  Restoring stashed changes...${NC}"
        git stash pop
    fi
    exit 1
fi

# Restore custom configurations
echo ""
echo -e "${YELLOW}[5/6] Restoring your custom configuration...${NC}"

if [ "$STASHED" = true ]; then
    echo -e "${YELLOW}  Attempting to merge stashed changes...${NC}"

    if git stash pop; then
        echo -e "${GREEN}  ✓ Changes merged automatically${NC}"
    else
        echo -e "${RED}  ✗ Merge conflicts detected!${NC}"
        echo ""
        echo -e "${YELLOW}  Conflicted files (needs manual resolution):${NC}"
        git diff --name-only --diff-filter=U | sed 's/^/    - /'
        echo ""
        echo -e "${YELLOW}  To resolve conflicts:${NC}"
        echo "    1. Edit conflicted files manually"
        echo "    2. Keep your custom sections (marked with <<<<<<< Updated)"
        echo "    3. Run: git add <file>"
        echo "    4. Run: git stash drop"
        echo ""
        echo -e "${YELLOW}  Your backup is safe at: $BACKUP_DIR${NC}"
        exit 1
    fi
fi

# Special handling for .env
if [ -f "$BACKUP_DIR/.env" ]; then
    echo ""
    echo -e "${YELLOW}  Restoring .env file from backup...${NC}"
    cp "$BACKUP_DIR/.env" "$PROJECT_ROOT/.env"
    echo -e "${GREEN}  ✓ .env restored (contains your secrets)${NC}"
fi

# Validate Caddyfile
echo ""
echo -e "${YELLOW}[6/6] Validating Caddyfile configuration...${NC}"
if [ -f "$PROJECT_ROOT/scripts/validate_caddy_config.sh" ]; then
    bash "$PROJECT_ROOT/scripts/validate_caddy_config.sh" || {
        echo ""
        echo -e "${YELLOW}  Caddyfile has configuration issues.${NC}"
        echo -e "${YELLOW}  Run this to fix: bash scripts/validate_caddy_config.sh --fix${NC}"
    }
else
    echo -e "${YELLOW}  ⚠ Validation script not found${NC}"
fi

echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}  Update Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${GREEN}✓ Update completed!${NC}"
echo ""
echo -e "${YELLOW}What was updated:${NC}"
echo "  - Code and scripts from git repository"
echo "  - Documentation files"
echo ""
echo -e "${YELLOW}What was preserved:${NC}"
echo "  - Your .env file (secrets and configuration)"
echo "  - Your custom Caddyfile changes"
echo "  - Your custom docker-compose.yml changes"
echo "  - All Docker volumes (databases, workflows, etc.)"
echo ""
echo -e "${YELLOW}Backup location:${NC}"
echo "  $BACKUP_DIR"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review changes: git log -5 --oneline"
echo "  2. Restart services: docker compose -p localai up -d"
echo "  3. Check status: bash scripts/status_report.sh"
echo ""

# Show what changed
echo -e "${BLUE}Recent commits:${NC}"
git log -5 --oneline --decorate | sed 's/^/  /'
echo ""
