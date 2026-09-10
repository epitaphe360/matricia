---
name: matricia-quotes-comparison
description: Implement provider quotes, revisions and normalized client comparison without using floating-point money.
---
# Quotes and comparison
- **Scope:** quote creation, line items, revisions, submission, expiry, comparison and acceptance.
- **Invariants:** money uses minor units or exact decimal; totals are server-computed; every revision is immutable/versioned; comparison preserves scope/currency/tax basis; accepted version cannot change.
- **Targeted context:** load affected RFQ, service snapshot, quote contract, fiscal rule version and permissions.
- **Checks:** arithmetic/rounding, currencies, tax versions, revision/expiry/withdrawal/acceptance states, unauthorized visibility, idempotence, audit/outbox and tests.
- **Ownership:** quote domain and financial migrations require named sole writers.
- **Handoff:** report calculation basis, versions, files/tests/evidence and unresolved fiscal review.
