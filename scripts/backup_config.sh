#!/usr/bin/env bash
set -euo pipefail

# Script: backup_config.sh
# Purpose: Backup configuration files before updates or changes
# Usage: bash scripts/backup_config.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="${SCRIPT_DIR}/.."
BACKUP_DIR="${PROJECT_ROOT}/backups"
TIMESTAMP=$(date +%Y-%m-%d-%H%M%S)
BACKUP_FILE="config-backup-${TIMESTAMP}.tar.gz"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  n8n-install Config Backup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Create backup directory
mkdir -p "${BACKUP_DIR}"

echo -e "${YELLOW}Backing up configuration files...${NC}"
echo ""

# Files to backup
FILES_TO_BACKUP=(
    ".env"
    "docker-compose.yml"
    "Caddyfile"
    "postgres/init-databases.sql"
)

# Check which files exist
EXISTING_FILES=()
for file in "${FILES_TO_BACKUP[@]}"; do
    if [[ -f "${PROJECT_ROOT}/${file}" ]]; then
        EXISTING_FILES+=("${file}")
        echo "  ✓ ${file}"
    else
        echo "  - ${file} (not found, skipping)"
    fi
done

echo ""

if [[ ${#EXISTING_FILES[@]} -eq 0 ]]; then
    echo -e "${YELLOW}No configuration files found to backup.${NC}"
    exit 0
fi

# Create backup archive
cd "${PROJECT_ROOT}"
tar czf "${BACKUP_DIR}/${BACKUP_FILE}" "${EXISTING_FILES[@]}" 2>/dev/null

if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓ Backup created successfully:${NC}"
    echo "  ${BACKUP_DIR}/${BACKUP_FILE}"
    echo ""
    echo "  Size: $(du -h "${BACKUP_DIR}/${BACKUP_FILE}" | cut -f1)"
    echo ""
else
    echo -e "${YELLOW}Warning: Backup creation may have failed. Check ${BACKUP_DIR}/${BACKUP_FILE}${NC}"
    exit 1
fi

# List existing backups
echo -e "${BLUE}Existing backups:${NC}"
ls -lh "${BACKUP_DIR}" | grep "config-backup" | awk '{print "  " $9 " (" $5 ")"}'
echo ""

# Cleanup old backups (keep last 10)
BACKUP_COUNT=$(ls -1 "${BACKUP_DIR}"/config-backup-*.tar.gz 2>/dev/null | wc -l)
if [[ $BACKUP_COUNT -gt 10 ]]; then
    echo -e "${YELLOW}Cleaning up old backups (keeping last 10)...${NC}"
    ls -1t "${BACKUP_DIR}"/config-backup-*.tar.gz | tail -n +11 | xargs rm -f
    echo -e "${GREEN}✓ Cleanup complete${NC}"
    echo ""
fi

echo -e "${GREEN}Backup complete!${NC}"
echo ""
echo "To restore this backup later, run:"
echo "  bash scripts/restore_config.sh"
