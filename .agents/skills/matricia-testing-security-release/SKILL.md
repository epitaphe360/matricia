---
name: matricia-testing-security-release
description: Independently verify Matricia quality, security, traceability and release gates; use for phase sign-off and red-team review.
---
# Testing, security and release
- **Scope:** unit, integration, DB/RLS, E2E, accessibility, security, performance, traceability, clean-clone and release evidence.
- **Invariants:** reviewer is independent from audited code; every critical permission has ALLOW and DENY; every sensitive mutation proves idempotence/audit/outbox; no placeholder or secret; no unsigned gate.
- **Targeted context:** load phase requirements, changed files, threat model, test matrix and evidence—not unrelated implementation history.
- **Checks:** run documented gates, adversarial cross-tenant/financial tests, failure paths, migration replay, deterministic seed, build and release validators; record exact results.
- **Ownership:** auditors do not modify audited code during sign-off; fixes return to owning writer, then are independently retested.
- **Handoff:** provide verdict, requirement/test mapping, commands/results, evidence paths, findings by severity and explicit blockers.
