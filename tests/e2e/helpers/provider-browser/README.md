# Independent Provider browser acceptance

Status: **partially executed on e929; business completion blocked on a reproduced qualification reviewer defect**. Initial harness base was integration commit
`b0be5966c67923cdeb36e049e280ad0f08e3573b`. Immutable first-candidate receipts are in
`docs/provider-completion/evidence/browser/candidate-one/`: 18 native entry steps,
40 FR/AR responsive pages, 64 axe scans with zero violations but unresolved contrast
incompletes, 8 menu cases and 20 real-role security checks. These are partial
receipts, not full Provider acceptance. Quotes, contracts, delivery, finance and
messaging remain unexecuted until their native prerequisites pass. The
orchestrator must signal each new candidate before schema upgrade or rebuild.

Run from `/workspace/provider-browser` with Node 24, installed workspace
modules, `/usr/bin/chromium`, cached Supabase images and local Docker socket.
All changes belong to `tests/e2e/helpers/provider-browser/**`; the orchestrator's
`provider-isolated/transaction.mjs` and Client target e3 are separate.

## Target and source guards

The target uses `matricia.provider-browser-test=<uuid>`, its own Docker internal
network, no published container ports and loopback app/gateway **19273/19274**.
`loadOwnState` verifies exact names, labels, current worktree path, internal
network and every child container before access. It rejects the Client e3 target,
shared Supabase project, remote database and arbitrary source manifests. Docker
selectors are pinned to `/var/run/docker.sock`; proxy/CA settings remain inherited.

The source must be the explicitly coordinated retained canonical **458-migration
setup source**, labelled `matricia.isolated-replay=<uuid>`, network none, no ports.
It is read/pg_dump only. Restore recreates the fresh owned target from template0,
then verifies every baseline object definition, owner and ACL against the source.
The 458 migration files must exactly match the beginning of the candidate's
migration list. `apply-candidate.mjs` applies only the remaining reviewed files
and records their hashes. This setup is not a green SQL replay receipt.

Candidate-sensitive commands require a full `--candidate=<40-character commit>`.
The current app/packages/migrations must match that commit and be clean; helper
commits may differ. The app will not run against another schema pin. Stages that
create containers, restore/apply SQL or build also require `--coordinated`.
These commands are prepared for the orchestrator's coordinated start:

```sh
APP_ENV=development node tests/e2e/helpers/provider-browser/provision.mjs --coordinated
APP_ENV=development node tests/e2e/helpers/provider-browser/restore.mjs /absolute/canonical/source-target.json --coordinated
APP_ENV=development node tests/e2e/helpers/provider-browser/apply-candidate.mjs --coordinated --candidate=<integrated-sha>
APP_ENV=development node tests/e2e/helpers/provider-browser/services.mjs --coordinated
# Keep gateway running in its own terminal:
APP_ENV=development node tests/e2e/helpers/provider-browser/gateway.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/actors.mjs
# Keep the pinned optimized app running in another terminal:
APP_ENV=development node tests/e2e/helpers/provider-browser/run-app.mjs --coordinated --production --candidate=<integrated-sha>
APP_ENV=development node tests/e2e/helpers/provider-browser/entry-browser.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/finish-identity.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/seed-catalogue.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/questionnaire-browser.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/qualification-review.mjs
```

Do not rerun a fresh-cohort stage over a partially completed native cohort. Keep
its receipts and original idempotency identities, diagnose the native error and
resume that operation. `refresh-sessions.mjs` refreshes the same users through
GoTrue; it never fabricates a USER JWT or replaces an actor to bypass a refusal.

## Native entry and identity

`actors.mjs` creates fifteen distinct GoTrue users, consumes native magic-link
OTP, enrolls TOTP and verifies AAL2. Provider, competitor and Client organizations
are created through the native organization command. Manager, Accounting,
assigned/unassigned Technicians, Viewer, Sales and a composite Technician/Viewer accept native invitations.
The five distinct staff actors receive explicit local TEST roles only; governed
staff onboarding and real email delivery are not certified. The Provider's lack
of Client roles and trials is checked from its actual rows.

`entry-browser.mjs` uses keyboard to save the full declared common legal profile,
touch to submit the activity profile, and real file inputs to upload three
synthetic PDFs. Each contains `TEST ONLY / NON CONTRACTUEL / NOT AN OFFICIAL
DOCUMENT`. The script verifies persisted profile data and exact submitted files;
it records them as submitted, without claiming verification. Arabic keeps the
original entered text and tenant.

`finish-identity.mjs` permits the DEMO scanner port only for those exact known PDF
bytes: object path, size and SHA256 must match the native upload receipt. A
separate real AAL2 compliance user reviews the documents through their native
command. The Provider submits the exact profile via keyboard. The same independent
reviewer decides the company and uses the actual Admin identity UI to attest the
current profile/documents. The plain Provider self-review is refused. No external
registry, official legal identity or production antivirus is certified.

## Remaining fixture prerequisites and business acceptance

`seed-catalogue.mjs` extracts only the reviewed published catalogue/questionnaire blocks from0338/0345 and maps all IDs to the native TEST cohort. Authentication, Provider profile/qualification, ledgers and guard changes are rejected from that extraction. This is historical TEST reference data, with source/SQL hashes; its governance is not claimed as a native publication. `questionnaire-browser.mjs` then requests two services and declares capacity/region/modes/radius through the real UI, starts the Provider questionnaire, tests conditional requirements and server refusal, offline/reconnect, RTL/free text, exact draft resume and final read-only submission. These two scripts have passed on e929; their receipts do not certify independent human qualification, which remains blocked by the documented reviewer RLS defect.

The seven acceptance groups and every required assertion are enumerated in
`plan.mjs`. Entry success alone does not certify questionnaire, quote, contract,
delivery, finance or messaging. Before `FIXTURE_READY`, the preparation must
supply canonical linked records and persist actual operation receipts for:

| Domain | Required prerequisite and action |
|---|---|
| Questionnaire/qualification | A reviewed published TEST catalogue subset and Provider questionnaire for requested services; actual conditional answers, offline/reconnect and read-only submission; independent service decision, current certificates, partner-contract state and declared capacity. |
| Consultation/quotes | Same-tenant Client request/RFQ; a native invitation to the Provider; actual one-time and recurring quote drafts with governed tax/minor amounts, option and clean private attachment; Client revision request and Provider replacement version. |
| Contracts/delivery | Reviewed DEMO signature policies and real DEMO callback; canonical contract, mission, deliverable/checklist/milestone; native assignment of only the assigned Technician; rejected first delivery then corrected version and independent Client acceptance. |
| Finance | Canonical billable source and period, native draft/issuance/closure commands, dated plan request and separate staff review. Historical TEST commercial source facts must carry provenance; no direct ledger or balance mutation, fabricated payment success, forced clock or current-state rewrite. |
| Messaging | The actual RFQ/mission dossier thread linking these two parties; native messages and private attachment upload/scan; post-selection access and competitor refusal. |

The fixture may bootstrap a small historical published catalogue, signed historical
counterparty facts or governed-policy prerequisites only when the manifest labels
those facts **HISTORICAL_SQL_TEST_PRECONDITION** and hashes the reviewed source.
It must not certify those preconditions as natively onboarded. Authentication,
new Provider identity, current decisions and business mutations under acceptance
use actual native commands. Do not use direct auth.users/session inserts,
fabricated USER claims, trigger disabling, eligibility overrides, direct VERIFIED
writes or direct financial ledger writes to make a workflow pass.

A completed `fixtures.safe.json` must identify the candidate app tree, Provider
and Client organizations and canonical `rfqId`, `invitationId`, `oneTimeQuoteId`,
`recurringQuoteId`, `contractId`, `missionId`, `deliverableId`, `milestoneId`,
`deliveryProofId`, `invoiceId`, `threadId`, plus provenance and the actual phase
receipts. Its scope is `ISOLATED_TEST_NATIVE_PROVIDER_FIXTURE`. These records must
exist and agree with the native reads before setting the run state FIXTURE_READY;
there is no supplied fake-ID example and no automatic empty-data success.

After business flows and fixture verification:

```sh
APP_ENV=development node tests/e2e/helpers/provider-browser/boundaries.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/matrix.mjs --candidate=<integrated-sha>
```

The matrix covers FR/AR at 375/390/768/1440, real dossier routes, context retention,
RTL/overflow, keyboard/touch account controls and captures. Ten critical module
families plus their detail routes receive axe scans with account menu closed/open
using WCAG2 A/AA and WCAG2.1 A/AA, without excluded rules. Indeterminate contrast
results remain indeterminate; computed opacity/filter/background/occlusion and
rendered contrast require a separate review. No full manual WCAG certification
is claimed. Boundaries exercise Viewer mutation/representative denial, foreign
Provider isolation, unassigned Technician delivery and assignment refusal.
Further workflow-specific assigned success and Finance/Sales refusals belong to
their native business flow receipts, not a page-200 check.

Only nonsecret receipts and inspected captures go to
`docs/provider-completion/evidence/browser/`, with SHA256 manifests. Sessions,
TOTP/OTP, cookies, headers, keys, database dumps and private state stay ignored
under `work/provider-browser-isolated/<uuid>/`. Stop app/gateway after capture;
`cleanup.mjs` removes only this run's rechecked labelled target/network. It never
removes the canonical source or the old Client target.

`qualification-review.mjs` follows the intentional partnership workflow: actual private test PDF upload, native scan lease/completion, independent document review and administrative UI decision. The PDF is explicitly `NON_CONTRACTUAL_DEMO`; the legal signature is a historical TEST precondition, never a legal execution certified by this acceptance. It revalidates the current identity after the company decision, then independently approves service A and requests information for B through the actual Admin UI. No `SIGNED`, qualification or balance state is written directly in SQL.

## Resume after the qualification fix

Preserve the original actors, submitted answers, uploaded bytes and decision
checkpoint. Upgrade only to the orchestrator's exact integrated candidate with
`upgrade-candidate.mjs --coordinated --candidate=<sha>`; existing applied migration
hashes are immutable. If the reviewed new files are interleaved with old files,
use the explicit `--allow-reviewed-interleaved-delta` flag and retain its receipt.
This forward upgrade does not replace a fresh full SQL replay receipt.

After the complete production-mode rebuild, execute in order:

```sh
APP_ENV=development node tests/e2e/helpers/provider-browser/qualification-review.mjs --resume-qualification
APP_ENV=development node tests/e2e/helpers/provider-browser/complete-quote-rfq.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/quote-browser.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/quote-revision-browser.mjs
APP_ENV=development node tests/e2e/helpers/provider-browser/native-contract-mission.mjs
```

The updated reviewer flow explicitly selects the original submitted questionnaire,
checks its frozen answer display and context hash, then makes an independent human
decision. The revision stage uses the actual counterparty Client command and
Provider keyboard/touch UI, verifies immutable published history and denies access
to the private replacement before republication. Contract selection requires the
exact newly republished version rather than silently retaining the first version.
These continuation scripts are prepared; only their own successful native receipts
can establish that they executed. Never rerun them over a failed native checkpoint
without investigating the stored state and the exact failed operation.
