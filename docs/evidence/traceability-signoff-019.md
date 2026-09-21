# Signoff indépendant — MAT-FUNC-019

Date : 2026-09-15  
Autorité : `Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md`  
Auditeur : `requirements_traceability_auditor`  
Mode : revue indépendante; aucune modification du code produit audité.

## Verdict

| Exigence | Verdict | Motif du signoff |
|---|---|---|
| MAT-FUNC-019 | VERIFIED | Trois prestataires équivalents sont évalués par le moteur réel sur trois demandes indépendantes et reçoivent déterministiquement une invitation chacun avant toute répétition; les décisions sont versionnées, explicables, idempotentes, auditées, outboxées et isolées par tenant. |

## Traçabilité atomique

- Contrat Gold Master : rotation équitable empêchant la monopolisation lorsque les candidats sont équivalents.
- Implémentation : `supabase/migrations/20260912005900_rfq_matching_foundation.sql`; `supabase/migrations/20260912014800_rfq_fair_rotation_recurring_scheduler.sql`; `supabase/migrations/20260912015400_rfq_versioned_provider_eligibility.sql`; `apps/web/modules/client/data/rfq/server-repository.ts`; `apps/web/modules/client/screens/demandes/request-id/matching-history.tsx`.
- Tests : `supabase/tests/0043_p07_rfq_matching_foundation.test.sql`; `supabase/tests/0098_rfq_fair_rotation_recurring_scheduler.test.sql`; `supabase/tests/0155_matching_rotation_behavioral.test.sql`; `apps/web/modules/client/screens/demandes/request-id/matching-history.test.tsx`; `tests/e2e/final-core-product.spec.ts`.
- Preuves : `docs/evidence/0155-matching-rotation-behavioral-run.json`; `docs/evidence/final-core-product-run.json`.

## Invariants vérifiés

- Trois candidats sont équivalents après retrait de la seule composante de rotation.
- Le premier run attribue une rotation identique aux trois candidats.
- Chaque invitation alimente l'historique de 90 jours utilisé par le run suivant.
- Les invitations successives suivent A, puis B, puis C avec une cible de panel égale à un.
- Aucun prestataire ne reçoit une deuxième invitation tant qu'un candidat équivalent reste non invité.
- Chaque run évalue les trois candidats et chaque RFQ utilise la politique `FAIR-ROTATION-90D-V2`.
- Le replay d'un matching retourne la réponse mise en cache sans créer de run supplémentaire.
- Les trois décisions de matching et les trois attributions RFQ produisent exactement un audit et un événement Outbox chacune.
- Un tenant étranger ne peut ni lancer le matching, ni lire runs, candidats, RFQ ou invitations; le Client propriétaire lit ses trois runs et RFQ.
- Le parcours E2E expose plusieurs runs, leur politique et leurs explications au Client propriétaire, avec refus cross-tenant.

## Exécutions retenues

- SQL comportemental ciblé : `0155_matching_rotation_behavioral.test.sql` — PASS, 1 fichier, 26 assertions; environnement `development`; rapport généré après le test; quatre scénarios de concurrence de la suite PASS. Le fichier exécute `finish()` puis `rollback`.
- E2E authentifié : `node tests/e2e/helpers/final-core-product-run.mjs` — PASS, 3 scénarios attendus, 0 inattendu, 0 ignoré, cleanup `verified`.

## Limite du visa

Ce visa porte uniquement sur MAT-FUNC-019. Il ne constitue pas un signoff global de release et ne change pas le statut de MAT-FUNC-020.
