---
name: matricia-marketing-autopilot
description: Implement consent-aware marketing automation, campaign orchestration, content approval and performance feedback.
---
# Marketing autopilot
- **Scope:** audience rules, campaigns, content generation, approval, scheduling, dispatch events, attribution and opt-out.
- **Invariants:** consent, suppression and tenant isolation are enforced server-side; generated content requires configured approval; sends are idempotent/audited/outboxed; no autonomous spend or production launch without authorization.
- **Targeted context:** load only campaign, channel adapter, audience aggregates, consent policy and relevant requirements. Never expose contact lists or credentials.
- **Checks:** consent/opt-out, audience boundaries, duplicate dispatch, approval/schedule/cancel/failure states, rate limits, localization, audit and integration/security tests using non-production adapters.
- **Ownership:** separate campaign domain, provider adapter and shared event owners; one writer per file.
- **Handoff:** report campaign state, safe aggregate metrics, files/tests/evidence, provider limitations and privacy risks.
