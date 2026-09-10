---
name: matricia-rfq-matching
description: Implement client RFQs, requirement capture, provider eligibility and explainable matching.
---
# RFQ and matching
- **Scope:** RFQ drafts/submission, service questions, eligibility filters, shortlist and invitations.
- **Invariants:** RFQs retain questionnaire/catalogue versions; matching is deterministic or explainable; hidden provider/client data remains isolated; invitation authorization is server-side.
- **Targeted context:** load only RFQ questions for selected services plus matching constraints and actor permissions.
- **Checks:** incomplete/valid submission, eligibility include/exclude, no-candidate path, duplicate invitation idempotence, RLS, audit/outbox, notifications and E2E.
- **Ownership:** isolate RFQ, matching and notification file owners; one writer per migration.
- **Handoff:** report criteria, versions, candidates only as safe test identifiers, files/tests/evidence and fairness risks.
