---
name: matricia-diagnostics-opportunities
description: Implement diagnostic runs, health scores, anomalies, recommendations and conversion into opportunities.
---
# Diagnostics and opportunities
- **Scope:** diagnostic lifecycle, snapshots, scoring, anomalies, risks, recommendations and opportunity creation.
- **Invariants:** results are reproducible from versioned inputs/rules; explanations accompany scores; AI suggestions cannot autonomously sanction or transact; tenant isolation is absolute.
- **Targeted context:** load the diagnostic template and relevant library/service subset, scoring contracts, transitions and MAT-FUNC-002..004 as needed.
- **Checks:** start/resume/complete/recompute/version transitions, deterministic scores, boundary cases, opportunity linkage, audit/outbox and unit/integration/RLS/E2E.
- **Ownership:** declare owners for scoring engine, persistence, screens and migrations.
- **Handoff:** report input/rule versions, outcomes, files/tests/evidence and model or content risks.
