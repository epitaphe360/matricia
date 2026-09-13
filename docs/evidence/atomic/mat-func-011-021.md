# Preuve atomique — MAT-FUNC-011 / MAT-FUNC-021

Date : 2026-09-13  
Périmètre : Mode Projet et calendrier central du portefeuille Client.

## Contrat livré

- `MAT-FUNC-011` : rattachement immuable d’un contrat Client à un projet unique, avec clés étrangères composites garantissant la cohérence d’organisation.
- `MAT-FUNC-021` : projection automatique des échéances RFQ, validité de devis, jalons de mission, factures et documents, en complément des tâches et événements explicites.
- Les échéances métier de type `date` conservent `occurs_on` et `all_day`; l’interface ne les reconvertit pas via le fuseau du navigateur. Les timestamps sont rendus dans `Africa/Casablanca`.
- La commande `link_contract_to_client_project` est restrictive, idempotente, auditée et publie `ClientProjectContractLinkedV1` dans l’Event Outbox.
- Le repository et l’interface n’exposent que les organisations actives de l’utilisateur; le formulaire et les libellés sont disponibles en français et arabe RTL, dans une grille fluide compatible 360 px.

## Preuves dédiées

- Migration : `supabase/migrations/20260913016100_client_project_contract_calendar_completeness.sql`.
- Correction additive post-gate : `supabase/migrations/20260913016200_client_calendar_unlinked_mission_regression.sql`, qui préserve les jalons de missions historiques non rattachées tout en enrichissant les missions rattachées avec leur projet.
- pgTAP : `supabase/tests/0106_client_project_contract_calendar_completeness.test.sql` (29 assertions : structure, RLS/ACL, immutabilité, isolation de deux tenants, rôle VIEWER refusé, confidentialité Provider, spoof refusé, dates exactes, replay, audit et Outbox).
- Régression pgTAP : `supabase/tests/0107_client_calendar_unlinked_mission_regression.test.sql` (8 assertions liées/non liées, ACL et second tenant) et assertion d’architecture actualisée dans `0065_client_projects_budgets_calendar.test.sql`.
- Unitaires : `apps/web/lib/client-portfolio/model.test.ts` et `apps/web/app/[locale]/client/portefeuille/actions.test.ts`.
- E2E authentifié : `tests/e2e/p22-client-portfolio.spec.ts`, FR/AR, RTL/LTR, 360 px, clavier et axe WCAG.

## Gates

- Vitest ciblé : **PASS — 3 fichiers / 22 tests**.
- TypeScript strict global : **PASS**.
- ESLint Web global : **PASS**.
- `git diff --check` ciblé : **PASS**.
- Audit indépendant 161 puis 162 : **PASS sans réserve P0/P1/P2** après correction de la frontière de confidentialité Provider, du fail-closed applicatif et de la régression des missions non liées.
- Supabase development : migrations 161 et 162 appliquées; dry-run final **PASS `upToDate:true`**.
- DB/RLS global : **PASS — 107 fichiers / 2 639 assertions / 4 scénarios de concurrence**.
- Régression ciblée 0065/0106/0107 : **PASS — 3 fichiers / 71 assertions / 4 scénarios de concurrence**.
- E2E P22 authentifié : **PASS — 4/4** (FR/AR × mobile 360/desktop, isolation, clavier, axe WCAG); neutralisation des fixtures **PASS**.

Statut : **VERIFIED**.
