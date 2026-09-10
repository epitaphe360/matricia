---
name: matricia-franchise-finance
description: Implement versioned franchise fees, profit allocation, statements and immutable distributions.
---
# Franchise finance
- **Scope:** distributable-profit basis, entry fees, allocations, statements, payouts and corrections.
- **Invariants:** exact money, append-only ledger, derived balances, idempotent transactions, audit/outbox. IT: zero entry fee and 50% Hatim Ahmitech / 50% Jalil-NEOXA / 0% Asma-Matricia. Other rules are versioned Gold Master rules.
- **Targeted context:** load only applicable franchise agreement/rule version, period, ledger and events.
- **Checks:** allocation totals, negative/zero cases, effective dates, correction entries, duplicate requests, access isolation, reconciliation and unit/integration/RLS/security tests.
- **Ownership:** financial engine, rule config and migrations each have one named writer.
- **Handoff:** report rule/basis versions, postings, files/tests/evidence, approvals and fiscal/legal risks.
