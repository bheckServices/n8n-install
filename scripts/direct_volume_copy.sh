#!/bin/bash

set -e

echo "==================================================================="
echo "Direct Volume Copy Script"
echo "==================================================================="
echo ""
echo "This will copy data from old volumes to new n8nInstall_ prefixed volumes."
echo ""

# Stop services manually first
echo "Step 1: Stop all containers first with:"
echo "  docker stop \$(docker ps -q --filter name=n8nInstall)"
echo ""
read -p "Have you stopped the containers? (yes/no): " stopped

if [[ "$stopped" != "yes" ]]; then
    echo "Please stop containers first, then run this script again."
    exit 1
fi

echo ""
echo "Step 2: Copying volumes..."
echo ""

# Copy n8n storage
echo "Copying n8n storage..."
docker run --rm \
    -v localai_n8n_storage:/old:ro \
    -v localai_n8nInstall_n8n_storage:/new \
    alpine:latest \
    sh -c "cp -av /old/. /new/" 2>&1 | tail -5

echo "✓ n8n storage copied"
echo ""

# Copy postgres data from langfuse volume
echo "Copying Postgres data (from langfuse_postgres_data)..."
if docker volume inspect localai_langfuse_postgres_data >/dev/null 2>&1; then
    docker run --rm \
        -v localai_langfuse_postgres_data:/old:ro \
        -v localai_n8nInstall_postgres_data:/new \
        alpine:latest \
        sh -c "cp -av /old/. /new/" 2>&1 | tail -5
    echo "✓ Postgres data copied"
else
    echo "⚠ localai_langfuse_postgres_data not found - skipping"
fi
echo ""

# Copy other volumes
declare -a VOLUMES=(
    "valkey-data"
    "caddy-data"
    "caddy-config"
    "grafana"
    "open-webui"
    "portainer_data"
    "prometheus_data"
    "qdrant_storage"
    "weaviate_data"
)

for vol in "${VOLUMES[@]}"; do
    old_vol="localai_${vol}"
    new_vol="localai_n8nInstall_${vol}"

    if docker volume inspect "$old_vol" >/dev/null 2>&1; then
        echo "Copying $vol..."
        docker run --rm \
            -v "$old_vol:/old:ro" \
            -v "$new_vol:/new" \
            alpine:latest \
            sh -c "cp -av /old/. /new/" 2>&1 | tail -3
        echo "✓ $vol copied"
    else
        echo "⊘ $vol not found - skipping"
    fi
done

echo ""
echo "==================================================================="
echo "Volume copy completed!"
echo "==================================================================="
echo ""
echo "Next steps:"
echo "1. Start your services: bash ./scripts/06_run_services.sh"
echo "2. Verify your data is back"
echo ""
