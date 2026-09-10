---
name: matricia-client-compliance
description: Implement Client onboarding, company profile, compliance intake and trial activation workflows.
---
# Client compliance
- **Scope:** onboarding, organization data, documents, compliance questionnaires, anomalies, result and trial start.
- **Invariants:** server-validated data; sensitive documents tenant-isolated; submitted answers retain questionnaire/rule versions; trial begins only on the defined validated transition.
- **Targeted context:** load only Client screens, relevant catalogue subset, forms, transitions and compliance requirements.
- **Checks:** draft/resume/submit/reject/correct paths, required fields, upload security, audit/outbox, FR/AR RTL, 360 px and accessibility; unit/integration/RLS/E2E.
- **Ownership:** declare form, route, domain and migration owners before editing.
- **Handoff:** include requirement coverage, states, files, tests/evidence and unresolved regulatory review.
