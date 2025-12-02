Agent Prompt Authoring Guide (Generate Last)

Purpose
- Produce a zero‑context, execution‑ready AGENT_PROMPT.txt that synthesizes the entire AIP into a single, precise instruction set.

Sequence (must follow)
1) Ensure packet docs are complete: README.md, CONTRACTS.md, BACKEND_IMPLEMENTATION.md, ORCHESTRATION_AND_UI.md, OBSERVABILITY.md, RUNBOOK.md, RISKS.md, CONTEXT.md, DATA_MODEL.sql, CHECKLIST.yaml.
2) Read README.md → extract: Executive Summary, Goals, Non‑Goals, Signals & Flags (Summary), Acceptance, Rollout.
3) Read CONTRACTS.md → extract: signal formulas, thresholds/buckets, events, fallbacks, Acceptance Rules.
4) Read BACKEND_IMPLEMENTATION.md → extract: file paths + functions to edit; flags; pseudocode.
5) Read ORCHESTRATION_AND_UI.md → extract: FE files + copy/threshold changes.
6) Read RUNBOOK.md → extract: flags/defaults; commands; flip/rollback; queries.
7) Read OBSERVABILITY.md → extract: metrics names/labels; dashboards and validation panels.
8) Read CHECKLIST.yaml → list phases/tasks in order (summarize as step‑by‑step tasks).
9) Draft AGENT_PROMPT.txt using the structure below; include exact paths, flags, and acceptance. Keep concise and precise.

AGENT_PROMPT Structure (must include)
- Title line: “You are the implementation agent for: <TITLE> (<FEATURE_SLUG>)”
- Context directory path
- Intake steps (read docs list)
- Primary goals (bullets)
- Non‑Goals (bullets)
- Signals & Flags (summary of formulas and flags)
- Runtime Flags (from RUNBOOK)
- Touch points (Backend files, Frontend files) — exact paths
- Step-by-step tasks (from CHECKLIST.yaml) — summarize concisely
- Verify & Accept (Acceptance from README + Acceptance Rules from CONTRACTS)
- Validation & Observability (metrics/dashboards from OBSERVABILITY)
- Ground rules (minimize scope; update docs; compliance; no unrelated changes)

Rubric (self‑check before finalizing)
- Does it list concrete file paths and the intent for each?
- Are all flags and defaults included?
- Are formulas/thresholds summarized correctly?
- Are tasks in execution order (phases) and concise?
- Are acceptance conditions explicit and verifiable?
- Are validation commands/queries mentioned?
- Is it free of implementation detail that belongs in packet docs (keep it an instruction, not a design doc)?

Anti‑patterns
- Do not hand‑wave: “update code accordingly.” Specify files/sections.
- Do not assume prior chat context.
- Do not duplicate entire packet content; synthesize what’s necessary to execute.
- Do not omit flags, acceptance, or file paths.

Handoff
- Save AGENT_PROMPT.txt at the root of the packet.
- Update CHECKLIST to mark the task complete.

