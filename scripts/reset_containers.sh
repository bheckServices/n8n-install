#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

log_info "Container Reset Script"
log_info "====================="
log_warning "This script will stop and remove all containers for the 'localai' project."
log_warning "Volumes will be PRESERVED - your data will NOT be deleted."
log_info ""

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

cd "$PROJECT_ROOT"

# Function to get all profiles from docker-compose.yml
get_all_profiles() {
    local compose_file="$1"
    if [ ! -f "$compose_file" ]; then
        return
    fi

    # Extract profile names using grep and sed
    grep -E '^\s+profiles:' "$compose_file" | \
        sed 's/.*profiles:\s*\["\(.*\)"\].*/\1/' | \
        sed 's/,/\n/g' | \
        sed 's/"//g' | \
        sort -u
}

log_info "Building docker compose command with all profiles..."

# Base command
CMD="docker compose -p localai"

# Get all profiles from main docker-compose.yml
PROFILES=$(get_all_profiles "docker-compose.yml")
for profile in $PROFILES; do
    CMD="$CMD --profile $profile"
done

# Add compose files
CMD="$CMD -f docker-compose.yml"

# Check if Supabase compose file exists
SUPABASE_COMPOSE="supabase/docker/docker-compose.yml"
if [ -f "$SUPABASE_COMPOSE" ]; then
    log_info "Found Supabase compose file, including it..."
    CMD="$CMD -f $SUPABASE_COMPOSE"
fi

# Check if Dify compose file exists
DIFY_COMPOSE="dify/docker/docker-compose.yaml"
if [ -f "$DIFY_COMPOSE" ]; then
    log_info "Found Dify compose file, including it..."
    CMD="$CMD -f $DIFY_COMPOSE"
fi

# Add down command (without -v to preserve volumes)
CMD="$CMD down"

log_info "Command to execute:"
log_info "$CMD"
log_info ""

read -p "Do you want to proceed with container reset? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    log_info "Container reset cancelled."
    exit 0
fi

log_info "Stopping and removing all containers..."
eval "$CMD"

log_success "Container reset completed!"
log_info ""
log_info "All containers have been removed."
log_info "Volumes have been PRESERVED - your data is safe."
log_info ""
log_info "To restart services, run:"
log_info "  bash ./scripts/06_run_services.sh"
