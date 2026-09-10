---
name: matricia-disputes-reassignment
description: Implement disputes, evidence, mediation, decisions and controlled mission reassignment.
---
# Disputes and reassignment
- **Scope:** dispute opening, evidence, responses, mediation, resolution, appeals and reassignment.
- **Invariants:** append-only evidence/history; least-privilege visibility; no automatic punitive AI decision; reassignment preserves contract, financial and audit lineage.
- **Targeted context:** load the specific mission/contract states, dispute policy version, actors and relevant ledger events.
- **Checks:** deadlines, conflicting actors, evidence access, resolve/appeal/reopen, reassignment atomicity, notification, RLS, audit/outbox and adversarial tests.
- **Ownership:** case workflow, evidence storage, money effects and migrations have distinct sole writers.
- **Handoff:** report timeline/state, rule version, files/tests/evidence, security findings and unresolved adjudication.
