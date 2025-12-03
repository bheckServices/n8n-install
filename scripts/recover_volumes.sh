#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

log_info "Volume Recovery Script"
log_info "====================="
log_info "This script will migrate data from old volume names to new n8nInstall_ prefixed volumes."
log_info ""

# Define volume mappings (old_name -> new_name)
declare -A VOLUME_MAP=(
    ["localai_n8n_storage"]="localai_n8nInstall_n8n_storage"
    ["localai_postgres_data"]="localai_n8nInstall_postgres_data"
    ["localai_langfuse_postgres_data"]="localai_n8nInstall_postgres_data"
    ["localai_valkey-data"]="localai_n8nInstall_valkey-data"
    ["localai_caddy-data"]="localai_n8nInstall_caddy-data"
    ["localai_caddy-config"]="localai_n8nInstall_caddy-config"
    ["localai_flowise"]="localai_n8nInstall_flowise"
    ["localai_grafana"]="localai_n8nInstall_grafana"
    ["localai_ollama_storage"]="localai_n8nInstall_ollama_storage"
    ["localai_open-webui"]="localai_n8nInstall_open-webui"
    ["localai_portainer_data"]="localai_n8nInstall_portainer_data"
    ["localai_prometheus_data"]="localai_n8nInstall_prometheus_data"
    ["localai_qdrant_storage"]="localai_n8nInstall_qdrant_storage"
    ["localai_weaviate_data"]="localai_n8nInstall_weaviate_data"
    ["localai_paddle_cache"]="localai_n8nInstall_paddle_cache"
    ["localai_paddleocr_cache"]="localai_n8nInstall_paddleocr_cache"
    ["localai_paddlex_data"]="localai_n8nInstall_paddlex_data"
    ["localai_postgresus_data"]="localai_n8nInstall_postgresus_data"
    ["localai_postiz-config"]="localai_n8nInstall_postiz-config"
    ["localai_postiz-uploads"]="localai_n8nInstall_postiz-uploads"
)

# Check which old volumes exist
log_info "Checking for old volumes..."
FOUND_VOLUMES=()
for old_vol in "${!VOLUME_MAP[@]}"; do
    if docker volume inspect "$old_vol" >/dev/null 2>&1; then
        FOUND_VOLUMES+=("$old_vol")
        log_success "Found: $old_vol"
    fi
done

if [ ${#FOUND_VOLUMES[@]} -eq 0 ]; then
    log_warning "No old volumes found to migrate."
    log_info "Your volumes may have been deleted, or you may need to check volume names manually."
    log_info "Run: docker volume ls"
    exit 0
fi

log_info ""
log_info "Found ${#FOUND_VOLUMES[@]} old volume(s) that can be migrated."
log_warning "This will copy data from old volumes to new volumes."
log_warning "The old volumes will NOT be deleted automatically."
echo ""
read -p "Do you want to proceed with migration? (yes/no): " confirm

if [[ "$confirm" != "yes" ]]; then
    log_info "Migration cancelled."
    exit 0
fi

# Stop all services first
log_info "Stopping all services..."
cd "$(dirname "$0")/.."
docker compose -p localai down || true

# Migrate each volume
for old_vol in "${FOUND_VOLUMES[@]}"; do
    new_vol="${VOLUME_MAP[$old_vol]}"

    log_info "Migrating: $old_vol -> $new_vol"

    # Check if new volume exists
    if ! docker volume inspect "$new_vol" >/dev/null 2>&1; then
        log_info "Creating new volume: $new_vol"
        docker volume create "$new_vol"
    fi

    # Use a temporary container to copy data
    log_info "Copying data..."
    docker run --rm \
        -v "$old_vol:/old:ro" \
        -v "$new_vol:/new" \
        alpine:latest \
        sh -c "cp -a /old/. /new/"

    if [ $? -eq 0 ]; then
        log_success "Successfully migrated: $old_vol -> $new_vol"
    else
        log_error "Failed to migrate: $old_vol"
    fi
done

log_success "Volume migration completed!"
log_info ""
log_info "Old volumes have been preserved. You can delete them manually after verifying the migration:"
for old_vol in "${FOUND_VOLUMES[@]}"; do
    echo "  docker volume rm $old_vol"
done
log_info ""
log_info "Now restart your services with: bash ./scripts/06_run_services.sh"
