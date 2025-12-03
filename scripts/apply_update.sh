#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Set the compose command explicitly to use docker compose subcommand
COMPOSE_CMD="docker compose"

# Navigate to the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Project root directory (one level up from scripts)
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"
# Path to the 06_run_services.sh script (Corrected from original update.sh which had 04)
RUN_SERVICES_SCRIPT="$SCRIPT_DIR/06_run_services.sh"
# Compose files (Not strictly needed here unless used directly, but good for context)
# MAIN_COMPOSE_FILE="$PROJECT_ROOT/docker-compose.yml"
# SUPABASE_COMPOSE_FILE="$PROJECT_ROOT/supabase/docker/docker-compose.yml"
ENV_FILE="$PROJECT_ROOT/.env"

# Check if run services script exists
if [ ! -f "$RUN_SERVICES_SCRIPT" ]; then
    log_error "$RUN_SERVICES_SCRIPT not found."
    exit 1
fi

cd "$PROJECT_ROOT"

# --- Call 03_generate_secrets.sh in update mode --- 
log_info "Ensuring .env file is up-to-date with all variables..."
bash "$SCRIPT_DIR/03_generate_secrets.sh" --update || {
    log_error "Failed to update .env configuration via 03_generate_secrets.sh. Update process cannot continue."
    exit 1
}
log_success ".env file updated successfully."
# --- End of .env update by 03_generate_secrets.sh ---

# --- Run Service Selection Wizard FIRST to get updated profiles --- 
log_info "Running Service Selection Wizard to update service choices..."
bash "$SCRIPT_DIR/04_wizard.sh" || {
    log_error "Service Selection Wizard failed. Update process cannot continue."
    exit 1
}
log_success "Service selection updated."
# --- End of Service Selection Wizard ---

# --- Configure Services (prompts and .env updates) ---
log_info "Configuring services (.env updates for optional inputs)..."
bash "$SCRIPT_DIR/05_configure_services.sh" || {
    log_error "Configure Services failed. Update process cannot continue."
    exit 1
}
log_success "Service configuration completed."

# --- Stop existing containers before pulling new images ---
log_info "Stopping existing containers to prepare for update..."
if docker ps -q --filter "name=n8nInstall" | grep -q .; then
    log_info "Stopping running containers..."
    docker stop $(docker ps -q --filter "name=n8nInstall") 2>/dev/null || true
    docker stop $(docker ps -q --filter "name=supabase") 2>/dev/null || true
    log_success "Containers stopped."
else
    log_info "No running containers found, skipping stop."
fi
# --- End of container stop ---

# Pull latest versions of selected containers based on updated .env
log_info "Pulling latest versions of selected containers..."
COMPOSE_FILES_FOR_PULL=("-f" "$PROJECT_ROOT/docker-compose.yml")

# Check if Supabase directory and its docker-compose.yml exist
SUPABASE_DOCKER_DIR="$PROJECT_ROOT/supabase/docker"
SUPABASE_COMPOSE_FILE_PATH="$SUPABASE_DOCKER_DIR/docker-compose.yml"
if [ -d "$SUPABASE_DOCKER_DIR" ] && [ -f "$SUPABASE_COMPOSE_FILE_PATH" ]; then
    COMPOSE_FILES_FOR_PULL+=("-f" "$SUPABASE_COMPOSE_FILE_PATH")
fi

# Check if Dify directory and its docker-compose.yaml exist
DIFY_DOCKER_DIR="$PROJECT_ROOT/dify/docker"
DIFY_COMPOSE_FILE_PATH="$DIFY_DOCKER_DIR/docker-compose.yaml"
if [ -d "$DIFY_DOCKER_DIR" ] && [ -f "$DIFY_COMPOSE_FILE_PATH" ]; then
    COMPOSE_FILES_FOR_PULL+=("-f" "$DIFY_COMPOSE_FILE_PATH")
fi

# Use the project name "localai" for consistency.
# This command WILL respect COMPOSE_PROFILES from the .env file (updated by the wizard above).
$COMPOSE_CMD -p "localai" "${COMPOSE_FILES_FOR_PULL[@]}" pull --ignore-buildable || {
  log_error "Failed to pull Docker images for selected services. Check network connection and Docker Hub status."
  exit 1
}

log_success "Docker images pulled successfully!"

# --- Save Credentials to File ---
log_info "Saving service credentials to file..."
CREDENTIALS_FILE="$PROJECT_ROOT/credentials.log"
{
    echo "=========================================="
    echo "Service Credentials - $(date)"
    echo "=========================================="
    echo ""
    bash "$SCRIPT_DIR/07_final_report.sh" 2>&1
} > "$CREDENTIALS_FILE"

if [ -f "$CREDENTIALS_FILE" ]; then
    log_success "Credentials saved to: $CREDENTIALS_FILE"
    log_info "View anytime with: cat $CREDENTIALS_FILE"
else
    log_warning "Failed to save credentials file."
fi
# --- End of Credentials Save ---

log_info ""
log_success "Update configuration completed successfully!"
log_info ""
log_info "=========================================="
log_info "FINAL STEP: Starting all services..."
log_info "=========================================="
log_info ""

# Start services using the 06_run_services.sh script - THIS IS THE LAST STEP
bash "$RUN_SERVICES_SCRIPT" || { log_error "Failed to start services. Check logs for details."; exit 1; }

log_success "Services started successfully!"

# Wait for Caddy to fully initialize
log_info "Waiting for Caddy to initialize..."
sleep 5

# --- Fix Caddy Configuration for Cloudflare Tunnel (AFTER Caddy is running) ---
log_info "Running Caddy diagnostics and fix..."
CADDY_FIXED=false
if [ -f "$SCRIPT_DIR/diagnose_and_fix_caddy.sh" ]; then
    if bash "$SCRIPT_DIR/diagnose_and_fix_caddy.sh"; then
        CADDY_FIXED=true
        log_success "Caddy configuration verified and fixed."
    else
        log_warning "Caddy diagnostics encountered issues."
        log_info "You can manually run: bash ./scripts/diagnose_and_fix_caddy.sh"
    fi
else
    log_warning "Caddy diagnostic script not found at: $SCRIPT_DIR/diagnose_and_fix_caddy.sh"
fi
# --- End of Caddy Fix ---

# Restart services if Caddy was fixed to ensure clean state
if [ "$CADDY_FIXED" = true ]; then
    log_info ""
    log_info "=========================================="
    log_info "Restarting services with fixed Caddy config..."
    log_info "=========================================="
    log_info ""
    bash "$RUN_SERVICES_SCRIPT" || {
        log_warning "Failed to restart services after Caddy fix."
        log_info "Services may still be running with old configuration."
    }
    log_success "Services restarted with corrected configuration!"
fi

log_success "Update completed successfully!"
log_info "All services are now running with the latest updates."

exit 0 