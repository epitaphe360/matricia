# V4.1 security report

Date: 2026-09-13

## Technical verdict

GO for development/staging. No open Critical or High finding in the reviewed V4.1 code.
Production remains forbidden without explicit authorization and the external evidence
listed below.

## Controls verified

- Restrictive RLS and explicit ACLs cover all new exposed tables.
- Cross-tenant ALLOW/DENY tests cover finance, privacy, export and operational jobs.
- AAL2, four-eyes and cooling-period controls protect sensitive bank, payment, export
  and governance operations.
- Financial, signature, evidence, job-attempt and publication histories are immutable.
- Sensitive mutations are idempotent, audited and emit Event Outbox records.
- Recursive payload redaction, anti-replay hashes, bounded retries and controlled DLQ
  reprocessing are implemented.
- .env.local is ignored and untracked; the non-test secret pattern scan passed.
- Next.js was upgraded from 16.2.6 to 16.3.3 after the dependency audit detected
  Critical/High advisories. Final production dependency audit: no known vulnerabilities.

## External evidence

- Real production restore exercise: REQUIRED_NOT_COMPLETED.
- Production key rotation and provider vault evidence: REQUIRED_NOT_COMPLETED.
- Independent production penetration test and operational incident drill:
  REQUIRED_NOT_COMPLETED.
- No claim of production security certification is made.
