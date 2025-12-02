# Coding Standards

**Scope:** Bash scripting, Docker Compose, configuration files, and documentation for the n8n-install project.

---

## 🎯 Principles

1. **Consistency Over Cleverness** - Readable code beats clever one-liners
2. **Fail Fast & Loud** - Exit on errors with clear messages (`set -euo pipefail`)
3. **Self-Documenting** - Code should explain what; comments explain why
4. **Idempotent Operations** - Scripts should be safe to re-run
5. **Namespace Everything** - Use `n8nInstall_` prefix for containers, networks, volumes

---

## 🐚 Bash Scripting Standards

### Script Headers

Every script must start with:

```bash
#!/usr/bin/env bash
set -euo pipefail  # Exit on error, undefined vars, pipe failures

# Script: <name>
# Purpose: <one-line description>
# Usage: <command with args>
```

### Variable Naming

```bash
# Constants: UPPER_SNAKE_CASE
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_ROOT="${SCRIPT_DIR}/.."

# Environment vars (from .env): UPPER_SNAKE_CASE
N8N_HOSTNAME="${N8N_HOSTNAME:-n8n.localhost}"

# Local vars: lower_snake_case
local service_name="postgres"
local retry_count=5

# Avoid single-letter vars except:
# - Loop counters: i, j, k
# - Common patterns: n (count), f (file), d (directory)
```

### Function Standards

```bash
# Function names: verb_noun format, lowercase with underscores
function check_docker_running() {
    # Document complex functions with block comments
    # Args: none
    # Returns: 0 if running, 1 otherwise

    if ! docker info > /dev/null 2>&1; then
        echo "ERROR: Docker is not running" >&2
        return 1
    fi
    return 0
}

# Helper function pattern
function is_profile_active() {
    local profile_name="$1"
    grep -q "\"${profile_name}\"" <<< "${COMPOSE_PROFILES:-}" || \
    grep -q "${profile_name}" <<< "${COMPOSE_PROFILES:-}"
}
```

### Error Handling

```bash
# Use trap for cleanup
function cleanup() {
    rm -f /tmp/install-*.tmp
}
trap cleanup EXIT

# Check prerequisites
function require_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        echo "ERROR: Required command '$cmd' not found" >&2
        exit 1
    fi
}

# Validate inputs
function validate_hostname() {
    local hostname="$1"
    if [[ ! "$hostname" =~ ^[a-zA-Z0-9.-]+$ ]]; then
        echo "ERROR: Invalid hostname: $hostname" >&2
        return 1
    fi
}

# Meaningful exit codes
# 0: Success
# 1: General error
# 2: Misuse (invalid args)
# 3: External dependency failure (Docker, network)
```

### User Interaction

```bash
# Use whiptail for menus (consistent with wizard.sh)
function select_from_list() {
    local title="$1"
    shift
    local options=("$@")

    whiptail --title "$title" \
             --menu "Choose an option:" 15 60 5 \
             "${options[@]}" \
             3>&1 1>&2 2>&3
}

# Colored output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}✓ Service started successfully${NC}"
echo -e "${RED}✗ Service failed to start${NC}"
echo -e "${YELLOW}⚠ Warning: Configuration may need review${NC}"
```

### Command Execution

```bash
# Always quote variables
docker exec "${container_name}" command

# Use arrays for complex commands
local docker_cmd=(
    docker compose
    -p localai
    up -d
    --no-deps
    --force-recreate
    "${service_name}"
)
"${docker_cmd[@]}"

# Check command success explicitly when needed
if docker compose ps -q postgres > /dev/null; then
    echo "Postgres is running"
fi
```

---

## 🐳 Docker Compose Standards

### Service Definition Template

```yaml
service-name:
  profiles: ["profile-name"]  # Always use profiles except core services
  container_name: n8nInstall_service-name  # Namespace prefix
  image: vendor/image:tag  # Pin specific versions
  restart: unless-stopped  # Standard restart policy

  networks:
    - n8nInstall_network  # Use shared network

  environment:
    - VAR_NAME=${VAR_NAME}  # Reference .env vars
    - VAR_WITH_DEFAULT=${VAR_NAME:-default_value}

  volumes:
    - service_name_data:/data  # Named volumes (preferred)
    - ./local/path:/container/path  # Bind mounts when needed

  depends_on:
    dependency:
      condition: service_healthy  # Use healthcheck conditions

  healthcheck:
    test: ["CMD-SHELL", "wget -qO- http://localhost:8080/health || exit 1"]
    interval: 30s
    timeout: 10s
    retries: 5
    start_period: 40s

  # NO ports: section - use Caddy for external access
```

### Naming Conventions

- **Container names:** `n8nInstall_<service>`
- **Volume names:** `n8nInstall_<service>_<purpose>` (e.g., `n8nInstall_postgres_data`)
- **Network name:** `n8nInstall_network`
- **Profile names:** lowercase, hyphenated (e.g., `gpu-nvidia`, `monitoring`)

### Port Management

**NEVER expose ports directly** - use Caddy reverse proxy:

```yaml
# ❌ WRONG - exposes port
ports:
  - "8080:8080"

# ✅ CORRECT - no ports, use Caddy
# (Caddy handles HTTPS and routing)
```

### Environment Variable Patterns

```yaml
# Secrets: _PASSWORD, _KEY, _SECRET suffix
- POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
- JWT_SECRET=${JWT_SECRET}

# Hostnames: _HOSTNAME suffix
- N8N_HOSTNAME=${N8N_HOSTNAME}

# Password hashes: _PASSWORD_HASH suffix
- N8N_BASIC_AUTH_PASSWORD_HASH=${N8N_BASIC_AUTH_PASSWORD_HASH}

# Defaults: Use ${VAR:-default}
- WORKER_COUNT=${N8N_WORKER_COUNT:-1}
```

---

## 🌐 Caddyfile Standards

### Service Block Template

```caddyfile
# Service: <service-name>
# Profile: <profile-name>
{$SERVICE_HOSTNAME} {
    # Basic auth if sensitive service
    basicauth {
        {$SERVICE_BASIC_AUTH_USER} {$SERVICE_BASIC_AUTH_PASSWORD_HASH}
    }

    reverse_proxy n8nInstall_service-name:internal-port {
        # Add headers for WebSocket support if needed
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

### Conventions

- **One service per block**
- **Comment service name and profile** at top of block
- **Use env vars for hostnames** (`{$VAR}` syntax)
- **Basic auth for admin interfaces** (Grafana, pgAdmin, etc.)
- **No basic auth for public APIs** (unless explicitly required)

---

## 📝 Configuration File Standards

### .env.example Structure

Organize by purpose with clear sections:

```bash
# ============================================================================
# Core Infrastructure
# ============================================================================
COMPOSE_PROFILES=["n8n"]
LETSENCRYPT_EMAIL=you@example.com

# ============================================================================
# Service: PostgreSQL
# ============================================================================
POSTGRES_USER=n8n
POSTGRES_PASSWORD=  # Generated by install script
POSTGRES_DB=n8n

# ============================================================================
# Service: n8n (Profile: n8n)
# ============================================================================
N8N_HOSTNAME=n8n.yourdomain.com
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=  # Generated by install script
N8N_BASIC_AUTH_PASSWORD_HASH=  # Generated by install script
```

### Secret Generation Patterns

In `scripts/03_generate_secrets.sh`, use standardized generation:

```bash
# VARS_TO_GENERATE map format:
# "VAR_NAME:type" where type is:
#   - password:length (random alphanumeric)
#   - jwt (base64 random)
#   - api_key (hex random)
#   - encryption_key (base64 32-byte)
#   - basic_auth (generates password + bcrypt hash)

VARS_TO_GENERATE=(
    "POSTGRES_PASSWORD:password:32"
    "N8N_ENCRYPTION_KEY:encryption_key"
    "FLOWISE_API_KEY:api_key"
    "N8N_BASIC_AUTH_PASSWORD:basic_auth"  # Also generates _HASH variant
)
```

---

## 📖 Documentation Standards

### README Structure

```markdown
# Service/Feature Name

Brief description (1-2 sentences)

## Quick Start
[Minimal steps to get running]

## Configuration
[Variables and their purposes]

## Usage
[Common operations]

## Troubleshooting
[Known issues and solutions]
```

### Inline Comments

```bash
# WHY comment: Explain non-obvious decisions
# Bcrypt hashing requires Caddy container to be running
docker compose up -d caddy

# WHAT comment: Only for complex regex or obscure syntax
# Extract domain from email (everything after @)
domain="${email##*@}"
```

### Code Examples in Docs

Always show full context:

````markdown
```bash
# From project root directory
cd /path/to/n8n-install

# Run with sudo if needed
sudo bash ./scripts/install.sh
```
````

---

## ✅ Pre-Commit Checklist

Before committing changes:

- [ ] Scripts have `#!/usr/bin/env bash` and `set -euo pipefail`
- [ ] All variables are quoted: `"${var}"`
- [ ] Functions have clear names and purpose comments
- [ ] Docker services have `n8nInstall_` prefix
- [ ] No ports exposed (unless core infrastructure)
- [ ] Healthchecks defined for dependencies
- [ ] Secrets use standardized suffixes
- [ ] Changes documented in relevant AIP
- [ ] .env.example updated if new vars added

---

## 🔗 Related Documentation

- [TESTING-STANDARDS.md](./TESTING-STANDARDS.md) - How to validate your changes
- [SECURITY.md](./SECURITY.md) - Security requirements
- [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md) - System design patterns

---

**Maintained By:** Project maintainers and AI agents
**Last Updated:** 2025-12-01
