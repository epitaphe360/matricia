# Signoff indépendant — MAT-FUNC-007, MAT-FUNC-013 et MAT-FUNC-018

Date : 2026-09-15  
Autorité : `Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md`  
Auditeur : `requirements_traceability_auditor`  
Mode : revue indépendante; aucune modification du code audité.

## Verdict

| Exigence | Verdict | Motif du signoff |
|---|---|---|
| MAT-FUNC-007 | VERIFIED | Messagerie liée à une RFQ, ouverture et envoi Client/Provider, lecture Inbox, idempotence, audit, Outbox, immutabilité et isolation RPC/RLS sont prouvés; le parcours navigateur participant/tenant étranger est PASS. |
| MAT-FUNC-013 | VERIFIED | La commande réelle normalise deux devis en unités mineures, produit des rangs déterministes et un snapshot versionné immuable; idempotence, audit, Outbox, isolation RPC/RLS et rendu navigateur multi-devis sont prouvés. |
| MAT-FUNC-018 | VERIFIED | Le matching réel applique une politique versionnée, conserve le run et les explications d'inclusion/exclusion, est idempotent, audité et outboxé; l'historique explicable est visible au Client et refusé au tenant étranger. |

## Traçabilité atomique

### MAT-FUNC-007 — Inbox universelle

- Contrat Gold Master : messagerie liée aux objets métier.
- Implémentation : `supabase/migrations/20260912014000_internal_object_messaging.sql`; `apps/web/modules/shared/lib/internal-messaging/server-repository.ts`; `apps/web/app/[locale]/messagerie/page.tsx`; `apps/web/app/[locale]/messagerie/actions.ts`.
- Tests : `supabase/tests/0154_messaging_comparison_functional.test.sql`; `tests/e2e/final-core-product.spec.ts`.
- Preuves : `docs/evidence/0154-messaging-comparison-functional-run.json`; `docs/evidence/final-core-product-run.json`.
- Invariants vérifiés : participants bornés à la RFQ, ALLOW Client/Provider, DENY tenant étranger aux couches RPC et RLS, replay sans doublon, un audit et un événement Outbox par effet, messages immuables.

### MAT-FUNC-013 — Comparateur intelligent

- Contrat Gold Master : comparaison normalisée de devis.
- Implémentation : `supabase/migrations/20260912006000_quotes_comparison.sql`; `apps/web/modules/client/data/rfq/server-repository.ts`; `apps/web/app/[locale]/client/demandes/[requestId]/comparaison/page.tsx`; `apps/web/modules/client/screens/demandes/comparison-panel.tsx`.
- Tests : `supabase/tests/0044_p07_quotes_comparison.test.sql`; `supabase/tests/0154_messaging_comparison_functional.test.sql`; `apps/web/modules/client/data/rfq/repository.test.ts`; `tests/e2e/final-core-product.spec.ts`.
- Preuves : `docs/evidence/0154-messaging-comparison-functional-run.json`; `docs/evidence/final-core-product-run.json`.
- Invariants vérifiés : deux devis soumis, montants exacts en unités mineures, rangs déterministes, versions figées, snapshot immuable, replay sans doublon, audit/Outbox uniques et DENY tenant étranger.

### MAT-FUNC-018 — Matching évolutif

- Contrat Gold Master : règles explicables et historisées.
- Implémentation : `supabase/migrations/20260912005900_rfq_matching_foundation.sql`; `supabase/migrations/20260912015400_rfq_versioned_provider_eligibility.sql`; `apps/web/modules/client/data/rfq/server-repository.ts`; `apps/web/modules/client/screens/demandes/request-id/matching-history.tsx`.
- Tests : `supabase/tests/0043_p07_rfq_matching_foundation.test.sql`; `supabase/tests/0100_admin_revocation_and_rfq_versioned_eligibility.test.sql`; `apps/web/modules/client/data/rfq/repository.test.ts`; `apps/web/modules/client/screens/demandes/request-id/matching-history.test.tsx`; `tests/e2e/final-core-product.spec.ts`.
- Preuves : `docs/evidence/final-core-product-run.json`; baseline SQL référencée dans `docs/progress/PROJECT_STATE.md`.
- Invariants vérifiés : politique versionnée, filtres éliminatoires et raisons explicites, historique immuable, idempotence, audit/Outbox, projection Client sans identité ni score opaque et DENY tenant étranger.

## Exécutions retenues

- SQL fonctionnel ciblé : `0154_messaging_comparison_functional.test.sql` — PASS, 1 fichier, 33 assertions; environnement `development`; quatre scénarios de concurrence de la suite PASS. Le fichier SQL exécute `finish()` puis `rollback`.
- E2E authentifié : `node tests/e2e/helpers/final-core-product-run.mjs` — PASS, 3 scénarios attendus, 0 inattendu, 0 ignoré, cleanup `verified`.
- Tests Web ciblés de la revue précédente : 5 fichiers, 21 tests PASS, couvrant repository RFQ, projection/historique de matching et contrats UI associés.

## Limites du présent visa

Ce visa ne couvre pas MAT-FUNC-019 : l'affichage de plusieurs runs ne prouve pas encore l'équité comportementale temporelle. Il ne couvre pas MAT-FUNC-020 : le parcours E2E des quatre transitions de capacité reste absent. Aucun signoff global de release n'est déduit de ces trois verdicts atomiques.
