#!/bin/bash

echo "==================================================================="
echo "Emergency Stop - All Containers"
echo "==================================================================="
echo ""

# Stop all running containers
echo "Stopping all running containers..."
docker stop $(docker ps -q) 2>/dev/null || echo "No containers to stop"

echo ""
echo "All containers stopped."
echo ""
echo "To restart services, run: bash ./scripts/06_run_services.sh"
