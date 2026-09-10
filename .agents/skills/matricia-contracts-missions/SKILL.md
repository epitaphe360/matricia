---
name: matricia-contracts-missions
description: Implement versioned contracts, signatures, missions, milestones, deliverables and acceptance.
---
# Contracts and missions
- **Scope:** contract generation/versioning, signature, mission execution, milestones, evidence and acceptance.
- **Invariants:** signed contract versions are immutable; transitions require authorized actors; economic rights derive from the applicable contract/rules; evidence and sensitive actions are audited.
- **Targeted context:** load accepted quote snapshot, contract clauses/version, mission state machine and related actors only.
- **Checks:** draft/sent/signed/active/completed/cancelled paths, signature replay, milestone acceptance/rejection, document access, audit/outbox, RLS and E2E.
- **Ownership:** one writer per contract template, state machine, migration and shared event.
- **Handoff:** report versions/transitions, files/tests/evidence, security notes and legal external-pending items.
