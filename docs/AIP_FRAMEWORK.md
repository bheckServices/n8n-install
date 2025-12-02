AgenticFlywheel Framework - Agent Implementation Packet (AIP) Specification

Purpose
- Provide a lightweight, self-contained, repeatable structure for large multi-phase changes driven by agentic collaboration between AI agents and humans.
- Minimize cross-linking and context hunting: all needed artifacts live under one folder per feature.
- Enable self-sustaining development momentum where better docs lead to better AI results, which lead to better docs.

Name
- Agent Implementation Packet (AIP)
- Example path: docs/Agent Implementation Packets/<Feature_Slug>/

Core Principles
- Self-contained: Everything required to plan, implement, verify, and track lives in the packet folder.
- Single source of truth: CHECKLIST.yaml is canonical for task status; CHECKLIST.md mirrors it for human scanning.
- Re-issuable prompt: AGENT_PROMPT.txt allows new agent sessions to bootstrap without relying on prior chat history.
- Self-maintaining: Documentation is updated as part of the implementation process, creating flywheel momentum.
- Parity: Packets should capture any environment parity needs (e.g., local Postgres == prod Databricks).
- Privacy & security: Document constraints explicitly (e.g., FERPA/COPPA, PII redaction, retention).
- Complete features: AIPs drive implementation of complete, production-ready features, not prototypes.

Minimum Required Sections (Quality Bar)
Every AIP MUST include the following content. Use the templates in `docs/templates/AIP/`:
- README.md
  - Executive Summary (what changes and why)
  - Goals and Non‑Goals (scoping guardrails)
  - Signals & Flags Summary (runtime flags, defaults, core computations in one glance)
  - Scope (Backend, Frontend, Docs)
  - Outcomes, Success Criteria, Rollout Plan, Acceptance
- CONTRACTS.md
  - Signals & Semantics (exact formulas/algorithms)
  - Buckets/Thresholds & Copy expectations (if any UI surfaces a score)
  - Event & API contracts (fields, optional/fallbacks)
  - Docs Contract (what global docs say after this AIP lands)
- BACKEND_IMPLEMENTATION.md
  - File‑by‑file touchpoints (paths + functions/methods)
  - Flags, feature gates, and pseudocode for non‑trivial logic
  - Data persistence semantics (exact columns and values)
- ORCHESTRATION_AND_UI.md
  - Frontend file‑by‑file tasks (components, utils, constants)
  - Copy/threshold updates and fallbacks
- OBSERVABILITY.md
  - New/updated metrics (names, labels, semantics)
  - Dashboards and validation panels; flicker/stability definitions when applicable
- RUNBOOK.md
  - Flags and defaults; local validation steps; flip/rollback; example queries
- RISKS.md
  - Top risks and mitigations; test coverage calls; back‑compat considerations
- DATA_MODEL.sql
  - DDL diffs (if needed) or explicit “No schema changes” note

Standard Packet Contents
- README.md: Objective, scope, constraints, outcomes
- CHECKLIST.yaml: Canonical phases/tasks, env defaults, acceptance
- CHECKLIST.md: Human-friendly checklist and notes
- AGENT_PROMPT.txt: Restartable instructions for agents
- CONTEXT.md: Decisions, constraints, environment defaults, acceptance goals
- CONTRACTS.md: API/events/DB contracts & compatibility
- DATA_MODEL.sql: DDL and retention notes for all stores
- BACKEND_IMPLEMENTATION.md: File-level guidance and flags
- ORCHESTRATION_AND_UI.md: Flows and UI changes
- OBSERVABILITY.md: Metrics/logs and quick checks
- RUNBOOK.md: Commands and acceptance
- RISKS.md: Risks and mitigations

Documentation Tasks (required)
- Every AIP MUST include a final phase in CHECKLIST.yaml named "Docs & Handoff" that:
  - Updates all packet docs (README/CONTEXT/RUNBOOK/OBSERVABILITY) to reflect reality.
  - Integrates links into relevant global docs (e.g., docs/ai/INDEX.md) if applicable.
  - Records new/changed env vars in the appropriate repo docs.
  - Captures operator notes (how to verify/rollback) and any UI screenshots if relevant.
  - Confirms parity notes (local == prod) are accurate.
  - Runs the Agent Prompt QA Checklist (docs/templates/AIP/AGENT_PROMPT_QA_CHECKLIST.md) before finalizing AGENT_PROMPT.txt

Authoring Checklist (copy into CHECKLIST.md)
- [ ] README has Exec Summary, Goals/Non‑Goals, Signals/Flags, Scope, Outcomes, Success, Rollout, Acceptance
- [ ] CONTRACTS includes formulas, buckets/thresholds, event fields, and fallbacks
- [ ] BACKEND_IMPLEMENTATION lists every file/function to touch and pseudocode for tricky bits
- [ ] ORCHESTRATION_AND_UI lists frontend files and copy changes
- [ ] OBSERVABILITY has metric names/labels and validation dashboard calls
- [ ] RUNBOOK includes flags, commands, queries, and rollback
- [ ] RISKS calls out flicker/instability, drift, and back‑compat
- [ ] AGENT_PROMPT is zero‑context and explicit (file paths, flags, acceptance)

Checklist YAML Schema (informal)
- version: integer
- feature: string (slug)
- status: pending | in_progress | completed
- constraints: [string]
- parity: { <key>: boolean }
- env_defaults: { KEY: value }
- phases: [
  { id: string, name: string, description: string, tasks: [
      { id: string, title: string, files: [string], status: pending|in_progress|completed }
    ]
  }
]
- verification: { commands: [string], acceptance: [string] }

Completion Status
- `CHECKLIST.yaml` includes a top-level `status` that tracks packet lifecycle.
- Start new packets in `pending` (or `in_progress` once execution begins).
- When every task in `phases[*].tasks` is marked `completed`, update the top-level `status` to `completed`.
- Mirror the same state at the top of `CHECKLIST.md` so humans can confirm completion quickly.

Usage
1) Scaffold a new AIP from templates (see docs/templates/AIP/ and associated prompts).
2) Fill in README.md, CONTEXT.md, DATA_MODEL.sql as needed for the initiative.
3) Populate CHECKLIST.yaml with phases/tasks, keep statuses current, and flip the top-level `status` to `completed` once every task is finished.
4) Generate AGENT_PROMPT.txt LAST by following the Authoring Guide: `docs/templates/AIP/AGENT_PROMPT_AUTHORING_GUIDE.md`. Run the Agent Prompt QA Checklist (`docs/templates/AIP/AGENT_PROMPT_QA_CHECKLIST.md`) before finalizing.

Zero‑Context Agent Prompt Guidance
- The AGENT_PROMPT.txt MUST:
  - Enumerate concrete file paths to edit and their purpose
  - List flags and defaults
  - Include step‑by‑step tasks and acceptance criteria
  - Reference packet docs by path; avoid relying on chat history
 - Be created after all packet docs are complete (README, CONTRACTS, BACKEND_IMPLEMENTATION, ORCHESTRATION_AND_UI, OBSERVABILITY, RUNBOOK, RISKS, CONTEXT, DATA_MODEL, CHECKLIST)

Validation (optional, recommended)
- CHECKLIST schema: docs/templates/AIP/CHECKLIST.schema.json
- Validate structure quickly via prompt validators or local scripts if available.

Features Registry (platform index)
- Location: docs/features/REGISTRY.yaml (+ schema at docs/features/REGISTRY.schema.json)
- Every AIP’s “Docs & Handoff” phase must add or update a registry entry for new/changed features.

Best Practices
- Keep tasks small and file-scoped where possible.
- Always include verification and acceptance for each phase.
- Prefer environment-agnostic instructions; call out provider-specific steps where needed.
- Update CHECKLIST.yaml on every material change to status.

