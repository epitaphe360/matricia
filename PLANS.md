# Matricia — ExecPlan permanent

Autorité : `Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md`. Toute phase suit `SPECIFY → IMPLEMENT → TEST → REVIEW → RED TEAM → FIX → RETEST → INTEGRATE → VERIFY`. Une phase reste ouverte sans audit indépendant signé et preuves enregistrées.

## Format obligatoire d’un ExecPlan

```yaml
id:
title:
status: QUEUED | IN_PROGRESS | BLOCKED | GREEN
goal:
scope:
requirements:
invariants:
ownership:
dependencies:
milestones:
decisions:
risks:
validation_commands:
evidence_paths:
progress_log:
results:
independent_signoff:
next_phase:
```

Règles : plan vivant mis à jour pendant l’exécution ; un seul propriétaire en écriture par fichier/migration ; logs volumineux sous `artifacts/` ou `docs/evidence/` ; aucun statut `GREEN` sans tests, audit et références de preuve ; `docs/progress/PROJECT_STATE.md` et `docs/progress/phase-ledger.json` sont mis à jour après chaque phase verte.

## Plan global V1 actif

```yaml
id: MAT-V1-GM4
title: Exécution intégrale Gold Master V4 FINAL
status: IN_PROGRESS
goal: Livrer et prouver MAT-FUNC-001..068 et MARKETING-001..008 sur development/staging.
scope: P00..P19; production explicitement exclue sans autorisation.
requirements: [MAT-FUNC-001..068, MARKETING-001..008]
invariants:
  - isolation multi-tenant et RLS restrictive
  - montants exacts, ledgers immuables, idempotence, audit et Event Outbox
  - contrats et règles versionnés
  - FR/AR RTL, accessibilité et responsive 360 px
ownership: docs/orchestration/file-ownership-map.csv
dependencies: [Gold Master V4 FINAL, AGENTS.md, Supabase development, catalogue canonique]
milestones:
  - P00 reconnaissance, mémoire, ownership et matrice
  - P01 contrats écrans/formulaires/permissions/API/événements/notifications/états
  - P02 monorepo, CI, design system, configuration et observabilité
  - P03 PostgreSQL, migrations, RLS, audit, Outbox et ledgers
  - P04 identité, OTP, sessions, organisation unique et rôles
  - P05 onboarding et conformité Client
  - P06 catalogue universel, questions et builders
  - P07 diagnostics et opportunités
  - P08 abonnements, paiements, Boxes et crédits
  - P09 onboarding et qualification Provider
  - P10 franchise, CRM, gouvernance et performance
  - P11 besoins, matching, RFQ et devis
  - P12 contrats, signatures, missions et livrables
  - P13 litiges, pénalités et réaffectation
  - P14 fiscalité Maroc, facturation Provider et recouvrement
  - P15 revenus franchise, allocations et P&L
  - P16 SKU, contrats-cadres et achats groupés
  - P17 administration, automatisations, notifications et reporting
  - P18 seeds dix domaines, FR/AR et Marketing Autopilot
  - P19 hardening, audits, clean clone et staging
decisions:
  - aucune fonction n’est VERIFIED sans code, tests, preuves et visa indépendant
  - toute correction de migration appliquée utilise une nouvelle migration
  - le catalogue est chargé par sous-ensemble sauf contrôle agrégé explicite
risks:
  - couverture fonctionnelle encore majoritairement planifiée
  - Docker local indisponible; reconstruction propre à prouver dans CI
  - aucune configuration de production autorisée
validation_commands:
  - pnpm verify:phase00
  - pnpm lint
  - pnpm typecheck
  - pnpm test
  - pnpm test:db
  - pnpm build
  - pnpm release:validate
evidence_paths:
  - docs/progress/PROJECT_STATE.md
  - docs/progress/phase-ledger.json
  - docs/evidence/
  - artifacts/test-results/
progress_log:
  - 2026-09-10: socle, identité OTP initiale et migrations 00100..01300 créés
  - 2026-09-11: remédiation des écarts documentaires et agents P00 engagée
results: Les résultats exacts sont consignés dans PROJECT_STATE et le phase ledger.
independent_signoff: PENDING
next_phase: Fermer P00 indépendamment, puis poursuivre P04 sans perdre les gates P01-P03.
```

La carte détaillée et les gates sont dans `docs/specs/sections/phase-map.md`.
