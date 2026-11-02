# Independent native Client browser verification

Run from the repository root with Node 24, installed workspace dependencies,
Docker on `/var/run/docker.sock`, cached Supabase images and `/usr/bin/chromium`.
These are opt-in local test utilities; they never read `.env.local` credentials
or resolve a remote application database. Set `APP_ENV=development` explicitly.

The source must be an explicitly authorized **read-only isolated replay**
manifest (`matricia_replay_<uuid>`, matching label, no network and no ports).
`restore.mjs` takes that manifest as an argument; it does not find a database
by application project name. The source is only inspected and `pg_dump`ed.
Every write targets a fresh, differently labelled container on its own Docker
**internal** network, without published container ports. Host access is through
its inspected private IP and a test-only HTTP gateway bound to `127.0.0.1`.
All mutations and cleanup recheck container labels and network isolation.
Docker endpoint/context selectors are reset to the local Unix socket; proxy/CA
configuration is retained. Images must already exist (`--pull=never`).

```sh
APP_ENV=development node tests/e2e/helpers/client-isolated/provision.mjs
APP_ENV=development node tests/e2e/helpers/client-isolated/restore.mjs /absolute/authorized/held-target.json
APP_ENV=development node tests/e2e/helpers/client-isolated/services.mjs
# Keep this running in its own terminal:
APP_ENV=development node tests/e2e/helpers/client-isolated/gateway.mjs
# In another terminal, once the gateway is ready:
APP_ENV=development node tests/e2e/helpers/client-isolated/actors.mjs
APP_ENV=development node tests/e2e/helpers/client-isolated/seed-questionnaire.mjs
# Keep this running in its own terminal:
APP_ENV=development node tests/e2e/helpers/client-isolated/run-app.mjs
# Then run the assertions:
APP_ENV=development node tests/e2e/helpers/client-isolated/questionnaire-browser.mjs
APP_ENV=development node tests/e2e/helpers/client-isolated/browser.mjs
node --test tests/e2e/helpers/client-isolated/safety.test.mjs
```

Use `browser.mjs --probe` for the two modules affected by the composite-role
pagination regression. The full matrix covers nine Client pages in FR/AR at
360, 375, 390, 768 and 1440 pixels. It asserts native session access, document
overflow, technical loading failures, client/admin denial and foreign
organization denial. Screenshots and JSON record the exact code commit, source
archive hash and assertion scope. The questionnaire scenario exercises real
Server Actions, required/hidden rules, independent server rejection, native
save/reload, offline queue/reconnect, RTL and unchanged user text, keyboard
filters, draft resume and final read-only submission. A successful page request
alone is not evidence of a successful business operation.

Auth users have unique `@example.invalid` addresses. GoTrue creates native OTP
sessions, enrolls TOTP and verifies AAL2. **User JWTs are never fabricated.**
The harness creates its own temporary anon/service configuration keys. Role
bootstrap uses explicit local test SQL. `seed-questionnaire.mjs` extracts the
reviewed historical dossier/catalogue fixture from
`supabase/tests/0301_client_questionnaire_presentation.test.sql`, maps every
fixture UUID to valid random UUIDs (including UUIDs embedded in rule JSON),
and preserves existing native user/organization identities. It never executes
the SQL fixture's fabricated `auth.sessions` or JWT claims.

The dossier and document-scan rows are **historical SQL fixtures**. They do not
certify native compliance onboarding, physical file upload, real antivirus,
governed catalogue publication, electronic signature, PSP payment or the whole
purchase workflow. No real email or external integration is configured. The
canonical URL `https://matricia.test.invalid` satisfies canonical validation for
this local test only; it is not a published preview or a DNS validation.

All credentials, native sessions, dump and private state are in ignored
`work/client-browser-isolated/<run-uuid>/` with restrictive permissions. Never
commit them or print their contents. Default local app/gateway ports are
19173/19174; an occupied port must fail, not reuse another application.

After saving the nonsecret evidence, stop the two terminal processes with
Ctrl-C, then remove **only this run's** inspected containers/internal network:

```sh
APP_ENV=development node tests/e2e/helpers/client-isolated/cleanup.mjs
```

Private test files remain ignored for investigation and should be removed when
no longer needed. Cleanup never removes the source replay or shared services.
