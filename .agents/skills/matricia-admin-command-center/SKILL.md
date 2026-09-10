---
name: matricia-admin-command-center
description: Build central administration, approvals, supervision and operational controls with least privilege.
---
# Admin command center
- **Scope:** admin dashboards, review queues, approvals, configuration, support and emergency controls.
- **Invariants:** admin is not an RLS bypass by default; elevated actions are explicit, least-privilege, reasoned and audited; impersonation/support access is controlled; production mutations require authorization.
- **Targeted context:** load only the queue/resource, permission policy, audit event and metrics required by the task.
- **Checks:** admin role boundaries, four-eyes flows where required, deny tests, stale/concurrent decisions, audit completeness, redaction, accessibility and security/E2E.
- **Ownership:** separate admin UI, privileged server action and policy/migration owners.
- **Handoff:** report privileges used, decisions, files/tests/evidence and remaining abuse cases.
