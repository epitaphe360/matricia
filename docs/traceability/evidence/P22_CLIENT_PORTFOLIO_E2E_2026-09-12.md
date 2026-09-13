# P22 — preuve Portefeuille Client

## Périmètre

- MAT-FUNC-011 : projets versionnés, tâches, progression et rattachement site.
- MAT-FUNC-012 : budgets annuels et allocations en unités mineures exactes.
- MAT-FUNC-021 : calendrier consolidé des événements, tâches et jalons.
- MAT-FUNC-051 : sites Client visibles et sélectionnables dans le portefeuille.
- MAT-FUNC-053 : centres de coûts et allocations liées aux budgets/projets.

## Invariants vérifiés

- La projection catalogue utilise uniquement la version publiée liée par la contrainte `catalog_libraries_published_fk`.
- Toute ligne versionnée hors des organisations actives de l’utilisateur provoque un refus fail-closed.
- Les montants sont convertis et affichés par chaînes/`BigInt`, sans calcul financier flottant.
- Les mutations passent par les RPC idempotentes existantes, auditées et reliées à l’Event Outbox.
- L’organisation étrangère provisionnée n’apparaît jamais dans la page Client.

## Gates

- Tests Web : **124 fichiers, 468 tests PASS**.
- ESLint Portefeuille : **PASS**.
- TypeScript Web : **PASS**.
- E2E authentifiés : **4/4 PASS** — FR/AR, RTL, mobile 360 × 800 et desktop 1280 × 900.
- Axe WCAG 2 A/AA et 2.1 A/AA : aucune violation.
- Clavier et absence de débordement horizontal : PASS.

Commande E2E : `node tests/e2e/helpers/p22-client-portfolio-run.mjs`.

Le runner refuse toute cible autre que development/staging concordante, utilise des states authentifiés liés à un manifeste frais, neutralise les fixtures dans `finally` et conserve la preuve distante immuable. Aucun secret ni environnement de production n’est exposé ou modifié.
