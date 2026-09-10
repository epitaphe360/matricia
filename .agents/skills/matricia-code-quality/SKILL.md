---
name: matricia-code-quality
description: Implement or review Matricia TypeScript architecture, contracts, modules and quality gates; skip for purely business copy changes.
---
# Code quality
- **Scope:** TypeScript, module boundaries, API contracts, error handling and maintainability.
- **Invariants:** strict TypeScript; domain logic stays outside UI; explicit contracts and stable errors; no TODO/FIXME/TBD, fake workflow, dead button or silent failure.
- **Targeted context:** read the affected domain skill, package scripts, nearest tests and owning module only.
- **Checks:** format, lint, typecheck, unit/integration tests and build; cover loading, empty, success, error and forbidden states where relevant.
- **Ownership:** edit only declared module/files; coordinate generated/shared files with their sole writer.
- **Handoff:** list contract changes, commands and results, evidence, regressions considered and unresolved risks.
