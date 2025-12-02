#!/usr/bin/env bash
set -euo pipefail

# Script: restore_config.sh
# Purpose: Restore configuration from backup
# Usage: bash scripts/restore_config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
BACKUP_DIR="${PROJECT_ROOT}/backups"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n-install Config Restore${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if backup directory exists
if [[ ! -d "${BACKUP_DIR}" ]]; then
    echo -e "${RED}✗ Backup directory not found: ${BACKUP_DIR}${NC}"
    echo "  Run 'bash scripts/backup_config.sh' to create a backup first."
    exit 1
fi

# List available backups
BACKUPS=($(ls -1t "${BACKUP_DIR}"/config-backup-*.tar.gz 2>/dev/null))

if [[ ${#BACKUPS[@]} -eq 0 ]]; then
    echo -e "${RED}✗ No backups found in ${BACKUP_DIR}${NC}"
    echo "  Run 'bash scripts/backup_config.sh' to create a backup first."
    exit 1
fi

echo -e "${YELLOW}Available backups:${NC}"
echo ""

# Display backups with numbers
for i in "${!BACKUPS[@]}"; do
    backup_file=$(basename "${BACKUPS[$i]}")
    backup_size=$(du -h "${BACKUPS[$i]}" | cut -f1)
    backup_date=$(echo "$backup_file" | sed 's/config-backup-\(.*\)\.tar\.gz/\1/' | sed 's/-/ /g' | sed 's/\([0-9]\{4\} [0-9]\{2\} [0-9]\{2\}\) \([0-9]\{6\}\)/\1 \2/')
    echo "  $((i+1)). $backup_file ($backup_size)"
done

echo ""
read -p "Select backup to restore [1-${#BACKUPS[@]}] or 'q' to quit: " choice

if [[ "$choice" == "q" ]]; then
    echo "Restore cancelled."
    exit 0
fi

# Validate choice
if ! [[ "$choice" =~ ^[0-9]+$ ]] || [[ $choice -lt 1 ]] || [[ $choice -gt ${#BACKUPS[@]} ]]; then
    echo -e "${RED}✗ Invalid choice${NC}"
    exit 1
fi

# Get selected backup
SELECTED_BACKUP="${BACKUPS[$((choice-1))]}"
echo ""
echo -e "${YELLOW}Selected backup: $(basename "$SELECTED_BACKUP")${NC}"
echo ""

# Confirm restoration
echo -e "${RED}WARNING: This will overwrite existing configuration files!${NC}"
read -p "Are you sure you want to continue? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    echo "Restore cancelled."
    exit 0
fi

echo ""
echo -e "${YELLOW}Creating safety backup of current config...${NC}"

# Create safety backup before restoring
SAFETY_BACKUP_DIR="${BACKUP_DIR}/pre-restore"
mkdir -p "${SAFETY_BACKUP_DIR}"
SAFETY_BACKUP_FILE="${SAFETY_BACKUP_DIR}/config-before-restore-$(date +%Y-%m-%d-%H%M%S).tar.gz"

cd "${PROJECT_ROOT}"
tar czf "${SAFETY_BACKUP_FILE}" .env docker-compose.yml Caddyfile postgres/init-databases.sql 2>/dev/null || true

if [[ -f "${SAFETY_BACKUP_FILE}" ]]; then
    echo -e "${GREEN}✓ Safety backup created: ${SAFETY_BACKUP_FILE}${NC}"
else
    echo -e "${YELLOW}  (some files may not exist)${NC}"
fi

echo ""
echo -e "${YELLOW}Restoring configuration...${NC}"

# Extract backup
cd "${PROJECT_ROOT}"
tar xzf "${SELECTED_BACKUP}"

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Configuration restored successfully${NC}"
    echo ""
    echo "Restored files:"
    tar tzf "${SELECTED_BACKUP}" | sed 's/^/  /'
    echo ""
    echo -e "${BLUE}Next steps:${NC}"
    echo "  1. Restart services: docker compose -p localai down && docker compose -p localai up -d"
    echo "  2. Verify status: bash scripts/status_report.sh"
    echo ""
else
    echo -e "${RED}✗ Restore failed${NC}"
    echo "  Your original config was backed up to: ${SAFETY_BACKUP_FILE}"
    exit 1
fi
