---
name: matricia-demo-content
description: Create deterministic Matricia demo accounts, scenarios and seeds that exercise the real domain and database.
---
# Demo content
- **Scope:** development/test seed data, demo users/organizations, scenarios and reset behavior.
- **Invariants:** demo uses the same domain, RLS and workflows as real operation; deterministic and idempotent seeds; no real personal data or production secret; clearly non-production identities.
- **Targeted context:** load only entities and workflows needed by the scenario plus seed contracts.
- **Checks:** clean reset/reseed, referential integrity, tenant separation, role coverage, localized content, scenario completion and no production execution path.
- **Ownership:** one seed owner coordinates IDs with domain/migration owners.
- **Handoff:** report scenarios/accounts by safe aliases, files/commands/tests/evidence and missing coverage.
