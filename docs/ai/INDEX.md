# AI Development Documentation Index

**Purpose:** Central hub for AI-assisted development of the n8n-install Docker infrastructure project.

## 🎯 Quick Start

**New to this project?** Start here:
1. Read [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md) to understand the profile-based system
2. Review [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for common issues and fixes
3. Check [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md) for service catalog

**Fixing an issue?** Use the [AIP Framework](#aip-framework) to document your work.

**Making changes?** Follow [CODING-STANDARD.md](./CODING-STANDARD.md) and [TESTING-STANDARDS.md](./TESTING-STANDARDS.md).

---

## 📚 Documentation Categories

### Core Standards
- [CODING-STANDARD.md](./CODING-STANDARD.md) - Bash scripting patterns, Docker Compose conventions, naming standards
- [TESTING-STANDARDS.md](./TESTING-STANDARDS.md) - Manual testing procedures, validation workflows, smoke tests
- [SECURITY.md](./SECURITY.md) - Secret handling, authentication, .env protection, compliance

### Architecture & Platform
- [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md) - Profile system, network isolation, container naming, reverse proxy
- [INFRASTRUCTURE.md](./INFRASTRUCTURE.md) - Docker Compose structure, service dependencies, healthchecks, volumes
- [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md) - Complete catalog of all services with purposes and dependencies

### Operations & Reliability
- [CONFIGURATION-MANAGEMENT.md](./CONFIGURATION-MANAGEMENT.md) - Environment variables, profiles, secret generation
- [OBSERVABILITY.md](./OBSERVABILITY.md) - Logging, monitoring, Grafana, health checks, status reporting
- [ERROR-HANDLING.md](./ERROR-HANDLING.md) - Failure modes, recovery procedures, debugging strategies
- [DEPLOYMENT.md](./DEPLOYMENT.md) - Installation flow, updates, rollback, backup/restore
- [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) - Issue-specific runbooks and solutions

---

## 🤖 AIP Framework

**Agent Implementation Packets (AIPs)** are structured workflows for fixing issues and adding features.

### Documentation
- [AIP Framework Specification](../AIP_FRAMEWORK.md) - Complete methodology and process

### Templates

**Full AIP Templates** (for complex changes):
- [templates/AIP/README.md](../templates/AIP/README.md) - Main AIP document
- [templates/AIP/CHECKLIST.yaml](../templates/AIP/CHECKLIST.yaml) - Task tracking
- [templates/AIP/CONTRACTS.md](../templates/AIP/CONTRACTS.md) - Service contracts and interfaces
- [templates/AIP/DEPENDENCIES.md](../templates/AIP/DEPENDENCIES.md) - Dependency mapping
- [templates/AIP/TESTING.md](../templates/AIP/TESTING.md) - Test strategy
- [templates/AIP/SECURITY.md](../templates/AIP/SECURITY.md) - Security considerations
- [templates/AIP/ROLLBACK.md](../templates/AIP/ROLLBACK.md) - Rollback procedures
- [templates/AIP/METRICS.md](../templates/AIP/METRICS.md) - Success metrics

**Lightweight Templates** (for quick fixes):
- [templates/aip-lite/README.md](../templates/aip-lite/README.md) - Simplified AIP
- [templates/aip-lite/CHECKLIST.yaml](../templates/aip-lite/CHECKLIST.yaml) - Essential tasks only

### Feature Registry
- [features/REGISTRY.yaml](../features/REGISTRY.yaml) - Central registry of all features/fixes
- [features/REGISTRY.schema.json](../features/REGISTRY.schema.json) - Schema validation

**When to use AIPs:**
- ✅ Fixing recurring issues (n8n password, missing databases, config misalignment)
- ✅ Adding new services (pgAdmin, monitoring tools, etc.)
- ✅ Updating core scripts (install.sh, update.sh, etc.)
- ✅ Infrastructure changes (networking, security, profiles)

**When to use lightweight vs full:**
- **Lightweight:** Bug fixes, config tweaks, single-service changes (<2 hours)
- **Full:** New services, multi-service changes, architecture updates (>2 hours)

---

## 🛠 Utility Scripts

Located in `scripts/`:
- **status_report.sh** - Interactive service health checker with numbered menu
- **backup_config.sh** - Backup .env and configs before updates
- **restore_config.sh** - Restore configs after failed updates
- **validate_install.sh** - Post-install validation checks

---

## 🔄 Workflow: Fixing an Issue

1. **Encounter Issue** → Run `scripts/status_report.sh` to gather diagnostics
2. **Create AIP** → Use `templates/aip-lite/` for quick fixes, `templates/AIP/` for complex changes
3. **Document Root Cause** → Add to [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
4. **Implement Fix** → Follow [CODING-STANDARD.md](./CODING-STANDARD.md)
5. **Test** → Use [TESTING-STANDARDS.md](./TESTING-STANDARDS.md) validation procedures
6. **Update Registry** → Add to [features/REGISTRY.yaml](../features/REGISTRY.yaml)
7. **Close AIP** → Mark complete, archive learnings

---

## 📖 Reading Guide by Role

### For Operators/Maintainers
1. [TROUBLESHOOTING.md](./TROUBLESHOOTING.md)
2. [OBSERVABILITY.md](./OBSERVABILITY.md)
3. [DEPLOYMENT.md](./DEPLOYMENT.md)
4. [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md)

### For Developers/Contributors
1. [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md)
2. [CODING-STANDARD.md](./CODING-STANDARD.md)
3. [SECURITY.md](./SECURITY.md)
4. [AIP Framework](../AIP_FRAMEWORK.md)

### For First-Time Users
1. [PLATFORM-ARCHITECTURE.md](./PLATFORM-ARCHITECTURE.md)
2. [SERVICE-REGISTRY.md](./SERVICE-REGISTRY.md)
3. [TESTING-STANDARDS.md](./TESTING-STANDARDS.md)

---

## 🔗 External Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Caddy Documentation](https://caddyserver.com/docs/)
- [n8n Documentation](https://docs.n8n.io/)
- [Bash Scripting Guide](https://www.gnu.org/software/bash/manual/)

---

**Last Updated:** 2025-12-01
**Maintained By:** Project maintainers and AI agents
