---
name: matricia-library-catalog
description: Work on Matricia libraries, categories, subcategories, services and catalogue publication/versioning.
---
# Library catalogue
- **Scope:** 10 libraries, 40 macro categories, 80 subcategories, 200 services, links and versioned CRUD/import/export.
- **Invariants:** used records are archived, never physically deleted; sensitive changes need central approval; published snapshots stay reproducible; Arabic is required before production.
- **Targeted context:** filter catalogue by library/service; do not load 6,000 questions for service metadata work. Note `services.category_code` maps to subcategory while `macro_category_code` maps to macro category.
- **Checks:** manifest counts, uniqueness, referential integrity, version/publish/archive/simulation, import validation, permissions and performance.
- **Ownership:** coordinate catalogue files, importer and schema; one writer per source or migration.
- **Handoff:** report subset loaded, counts, versions, files/tests/evidence and content-review risks.
