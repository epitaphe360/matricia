---
name: matricia-supabase-rls
description: Design, migrate or audit Matricia PostgreSQL and Supabase authorization; use for schemas, SQL, RLS, functions, seeds and database tests.
---
# Supabase and RLS
- **Scope:** migrations, tables, constraints, indexes, SQL functions, RLS, seeds and tenant-aware data access.
- **Invariants:** RLS restrictive by default; no cross-organization access; server authorization is mandatory; SECURITY DEFINER is exceptional, fixed-search-path and tested; migrations are forward-safe.
- **Targeted context:** load only affected tables, policies, actors, transitions and MAT-FUNC IDs. Never print connection strings or keys.
- **Checks:** clean reset, migration replay, constraints/indexes, ALLOW and DENY tests for every critical permission, cross-tenant/adversarial tests, deterministic seeds.
- **Ownership:** one writer per migration; never rewrite an applied migration; production changes require explicit authorization.
- **Handoff:** name migrations/policies/functions, tests/results, target environment class, evidence and residual threats—never secret values.
