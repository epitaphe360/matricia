---
name: matricia-domain-invariants
description: Apply Matricia-wide domain invariants when designing or reviewing cross-domain behavior; skip for isolated styling work.
---
# Domain invariants
- **Scope:** shared entities, workflows, boundaries and MAT-FUNC-001..068. Gold Master V4 FINAL is authoritative; 069..090 stay out of V1.
- **Invariants:** one organization may hold multiple roles; tenant isolation is absolute; permissions and economic rights are distinct; critical history is immutable/versioned/audited.
- **Targeted context:** load only relevant Gold Master sections, requirement IDs, domain contracts and nearby decisions. Never load all 6,000 questions unless the task requires them.
- **Checks:** map each change to requirements, states, server validation, authorization, audit/outbox and positive/negative tests. Reject placeholders.
- **Ownership:** declare exact files and shared-contract owner before editing; one writer per file.
- **Handoff:** report requirements, files read/changed, commands/tests, decisions, security notes, evidence and open risks.
