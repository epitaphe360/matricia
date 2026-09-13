# V4.1 finance reconciliation report

Date: 2026-09-13

## Cash boundaries

- Flow A, Client to Provider: evidence only; Matricia never holds or books the principal.
- Flow B, Client to Matricia: subscriptions, credits and Boxes use Matricia own-payment
  events, refunds, chargebacks and balanced journals.
- Flow C, Provider to Matricia: eligible commission invoices, confirmed receipts and
  atomic allocations are isolated from both other flows.

## Implemented controls

- Procurement request, approval, PO, quantified receipt, supplier invoice, AP,
  outbound payment and reconciliation.
- Three-way PO/receipt/invoice matching and AP over-allocation prevention under locks.
- Versioned beneficiary bank coordinates with AAL2, four-eyes and cooling period.
- Exact bigint/numeric money only; Morocco tax rules remain versioned and administrable.
- AI usage/cost ledger, provider invoice reconciliation, budgets, treasury forecasts and
  FORECAST/ACTUAL Box benefit margins.
- Immutable ledgers, durable idempotency, audit and Outbox on sensitive mutations.

Evidence: SQL/RLS suites 0108, 0111, 0112 and 0115 PASS; the complete database gate
passes 2915 assertions and 4 concurrency scenarios.
