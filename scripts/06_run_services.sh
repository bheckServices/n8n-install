#!/bin/bash

set -e

# Source the utilities file
source "$(dirname "$0")/utils.sh"

# Define paths
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
PROJECT_ROOT="$( cd "$SCRIPT_DIR/.." &> /dev/null && pwd )"

# Change to project root directory
cd "$PROJECT_ROOT"

# 1. Check for .env file
if [ ! -f "$PROJECT_ROOT/.env" ]; then
  log_error ".env file not found in project root: $PROJECT_ROOT/.env" >&2
  exit 1
fi

# 2. Check for docker-compose.yml file
if [ ! -f "$PROJECT_ROOT/docker-compose.yml" ]; then
  log_error "docker-compose.yml file not found in project root: $PROJECT_ROOT/docker-compose.yml" >&2
  exit 1
fi

# 3. Check for Caddyfile (optional but recommended for reverse proxy)
if [ ! -f "$PROJECT_ROOT/Caddyfile" ]; then
  log_warning "Caddyfile not found in project root: $PROJECT_ROOT/Caddyfile. Reverse proxy might not work as expected." >&2
  exit 1
fi

# 4. Check if Docker daemon is running
if ! docker info > /dev/null 2>&1; then
  log_error "Docker daemon is not running. Please start Docker and try again." >&2
  exit 1
fi

# 5. Check if start_services.py exists and is executable
if [ ! -f "$PROJECT_ROOT/start_services.py" ]; then
  log_error "start_services.py file not found in project root: $PROJECT_ROOT/start_services.py" >&2
  exit 1
fi

if [ ! -x "$PROJECT_ROOT/start_services.py" ]; then
  log_warning "start_services.py is not executable. Making it executable..."
  chmod +x "$PROJECT_ROOT/start_services.py"
fi

log_info "Launching services using start_services.py..."
# Execute start_services.py (we're already in PROJECT_ROOT from cd above)
"$PROJECT_ROOT/start_services.py"

exit 0 