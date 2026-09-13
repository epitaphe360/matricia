# V4.1 migration report

Date: 2026-09-13
Environment: Supabase development only
Strategy: additive migrations, no reset, no production operation.

## Applied sequence

- 16300: financial boundaries, procurement roots and versioned bank accounts.
- 16400 and 16401: provider-neutral electronic signature and attestation hardening.
- 16500 and 16501: privacy/CNDP registers and scoped read policies.
- 16600 and 16601: FinOps, treasury, actual margins and provider invoice reconciliation.
- 16700: procurement/AP, outbound payments, own-payment events and direct-payment evidence.
- 16800: third parties, continuity, secure export, jobs and dead letters.
- 16900 and 16901: legal/governance/marketing/catalogue controls and exact content binding.
- 17000: Admin V4.1 operational overview.

Migrations 16300 to 16600 were initially persisted by an unsafe transactional validator
that contained internal transaction controls. Their remote history was reconciled with
the exact applied versions; no schema object, migration or data was deleted. The validator
now rejects explicit BEGIN, COMMIT and ROLLBACK before execution.

Final linked dry-run: upToDate=true, no migration, seed or role pending.

## Verification

- Transactional validation with rollback: PASS.
- PostgreSQL/RLS regression: 116 files, 2915 assertions, 4 concurrency scenarios PASS.
- V4.1 focused SQL/RLS: 5 files, 166 assertions, 4 concurrency scenarios PASS.
- No reset, destructive migration or production deployment was executed.
