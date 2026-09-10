---
name: matricia-volume-procurement
description: Implement aggregated purchasing, commitments, consumption and supplier allocation for volume services.
---
# Volume procurement
- **Scope:** volume offers, commitments, pooled demand, allocation, consumption, settlement and expiry.
- **Invariants:** only eligible services participate; tenant details remain private across buyers; commitments and consumption are append-only economic events; money and quantities use exact types.
- **Targeted context:** load selected service, volume rule version, participants' authorized aggregates and ledger contracts only.
- **Checks:** thresholds, over/under-consumption, concurrency, expiry/cancellation, allocation totals, idempotence, RLS, audit/outbox and financial/E2E tests.
- **Ownership:** aggregation logic, ledger integration and migrations require sole writers.
- **Handoff:** report rule version, aggregate-safe evidence, files/tests and open supplier/economic risks.
