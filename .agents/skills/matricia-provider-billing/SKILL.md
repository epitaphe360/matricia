---
name: matricia-provider-billing
description: Implement provider invoices, payable events, settlements and reconciliation with immutable financial records.
---
# Provider billing
- **Scope:** invoicing, payable calculation, settlement status, payment-provider events and reconciliation.
- **Invariants:** no float; ledgers are append-only; balances are derived; sensitive mutations are transactional, idempotent, audited and emit through Event Outbox; fiscal rules are dated/versioned.
- **Targeted context:** load applicable contract/mission snapshot, ledger accounts, fiscal version and provider adapter only.
- **Checks:** duplicate/out-of-order webhooks, partial/refund/failure paths, rounding, reconciliation, authorization, ledger balance, audit/outbox and integration/security tests.
- **Ownership:** one writer per ledger/migration/provider adapter; production payment actions require explicit authorization.
- **Handoff:** report idempotency keys structurally (never values), postings, versions, tests/evidence and reconciliation risks.
