---
name: matricia-provider-qualification
description: Implement Sous-traitant onboarding, capabilities, evidence and qualification decisions.
---
# Provider qualification
- **Scope:** provider profile, capabilities, service coverage, documents, qualification questionnaire and status.
- **Invariants:** evidence is versioned; qualification is explainable and auditable; client data is not exposed; sanctions or critical decisions are never autonomously imposed by AI.
- **Targeted context:** load provider requirements, qualification questions for relevant libraries only, states, RLS and review contracts.
- **Checks:** draft/submitted/under-review/approved/rejected/suspended transitions, expiry, resubmission, access boundaries, audit/notifications and unit/integration/RLS/E2E tests.
- **Ownership:** one writer per provider contract, migration and shared file.
- **Handoff:** report decisions, transitions, evidence, tests, security notes and open review items.
