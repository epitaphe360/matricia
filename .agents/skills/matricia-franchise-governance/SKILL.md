---
name: matricia-franchise-governance
description: Implement franchise territories, mandates, approvals and governance rules, including the IT exception.
---
# Franchise governance
- **Scope:** franchise identity, library mandate, territory, approvals, entry fees and governance configuration.
- **Invariants:** IT franchise is Hatim Ahmitech with zero entry fee; IT distributable profit is 50% Hatim / 50% Jalil-NEOXA / 0% Asma-Matricia. Other franchises follow versioned Gold Master rules, defaulting to 50/25/25 when applicable.
- **Targeted context:** load only relevant franchise clauses, rule versions, actors and economic events.
- **Checks:** authority boundaries, effective dates, approval workflow, immutable historical application, RLS, audit and financial tests.
- **Ownership:** financial rules and migrations each have one writer; no production rule change without explicit authorization.
- **Handoff:** identify rule version, files, tests, evidence, approvals and legal/external pending items.
