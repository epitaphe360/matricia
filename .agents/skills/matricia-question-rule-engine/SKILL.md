---
name: matricia-question-rule-engine
description: Build versioned questionnaires, conditional logic, validation, scoring and financial or compliance rule evaluation.
---
# Question and rule engine
- **Scope:** templates, questions, answers, conditions, scoring, rule versions, preview and publication.
- **Invariants:** historical submissions bind immutable versions; deterministic evaluation; no fiscal/TVA rule hardcoded; sensitive rule publication is approved and audited.
- **Targeted context:** load questions only for the selected template/library/service and necessary dependencies, never the complete 6,000 by default.
- **Checks:** condition branches, requiredness, types, cycles, scoring bounds, draft/publish/archive, reproducibility, malformed input, performance and FR/AR rendering.
- **Ownership:** one writer for engine contracts and each rule migration; catalogue edits remain separately owned.
- **Handoff:** state versions, loaded subset, files, tests, evidence, edge cases and open domain validation.
