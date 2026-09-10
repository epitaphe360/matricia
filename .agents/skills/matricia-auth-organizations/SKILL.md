---
name: matricia-auth-organizations
description: Build or review authentication, memberships, organization identity and multi-role access in Matricia.
---
# Auth and organizations
- **Scope:** login/OTP, sessions, profiles, organizations, memberships, invitations and role switching.
- **Invariants:** a single organization passport supports multiple roles; membership is explicit and revocable; tenant context comes from verified identity, never client input alone; enumeration and privilege escalation are prevented.
- **Targeted context:** load auth screens/contracts, membership tables, RLS policies and MAT-FUNC-001 plus directly related requirements.
- **Checks:** valid/invalid/expired auth, invite lifecycle, role accumulation/switching, revoked access, cross-tenant ALLOW/DENY, audit and session security.
- **Ownership:** coordinate auth contracts and membership migrations with their sole owners.
- **Handoff:** record flows/states, files/migrations, tests, security findings, evidence and open risks.
