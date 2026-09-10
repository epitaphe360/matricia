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

## Plan global V1

- P00–P03 : mémoire projet, spécifications atomiques, socle monorepo, base/RLS/outbox/audit/ledgers.
- P04–P10 : identité, client, catalogue, diagnostics, abonnements, fournisseurs et franchises.
- P11–P17 : RFQ/devis, contrats/missions, litiges, fiscalité/facturation, finance, achats groupés et administration.
- P18–P19 : contenu/seeds, Marketing Autopilot, hardening, audits, clean clone et staging.
- Production : explicitement exclue sans autorisation utilisateur et gates de production.

La carte détaillée et les gates sont dans `docs/specs/sections/phase-map.md`.
