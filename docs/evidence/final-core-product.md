# Preuve E2E — noyau produit final

Date : 2026-09-15  
Environnement autorisé : local ou sandbox `TEST` uniquement.

## Scénarios ajoutés

| Exigence | Scénario | Preuve attendue | État lors de la création |
|---|---|---|---|
| MAT-FUNC-007 | Participant Client lit un fil lié à un dossier ; Client étranger tente le deep-link. | Sujet/message visibles en ALLOW, absents en DENY. | PROVISIONNÉ — exécution par le runner sandbox autonome ci-dessous. |
| MAT-FUNC-013 | Client ouvre une comparaison contenant au moins deux devis ; devis étranger absent ; Client étranger refusé. | Deux cartes `Offre`, marqueur étranger absent, deep-link étranger sans page de comparaison. | PROVISIONNÉ — exécution par le runner sandbox autonome ci-dessous. |
| MAT-FUNC-018 | Client consulte la version de politique et les raisons de shortlist. | Version et explications visibles dans le détail de demande. | PASS E2E — parcours authentifié exécuté, preuve machine sanitizée et nettoyage vérifié. |
| MAT-FUNC-019 | Client consulte au moins deux runs immuables. | Deux éléments portant `data-matching-run-id`. | VERIFIED — E2E authentifié et preuve SQL comportementale A → B → C, anti-monopole, RLS, audit et Outbox signés indépendamment. |
| MAT-FUNC-020 | Provider traverse AVAILABLE, LIMITED, FULL puis PAUSED dans l'UI. | Retour serveur positif après chaque transition. | E2E IMPLÉMENTÉ, DERNIER RUN FAIL — la fixture est neutralisée; deux défauts produit ont été corrigés (rotation des clés d'idempotence et catalogue incomplet), mais le parcours complet n'est pas encore vert. |

## Contrat de fixture

`tests/e2e/helpers/final-core-product-run.mjs` réutilise le provisionneur sécurisé existant. Il refuse un environnement autre que le development/sandbox autorisé, crée des identités et organisations isolées, ajoute les seules données métier nécessaires, lance les assertions avec deux sessions Client réelles, puis neutralise les données et états d'authentification dans un bloc de nettoyage garanti.

`tests/e2e/helpers/final-core-product-fixture.ts` refuse tout manifeste qui n'est pas `schemaVersion: 1`, `environment: TEST`, non expiré, composé de UUID valides et d'états Playwright existants. Le manifeste éphémère est produit par le runner et n'embarque aucun secret.

## Exécution

Commande ciblée :

```text
node tests/e2e/helpers/final-core-product-run.mjs
```

La spec directe échoue explicitement sans manifeste frais : aucun scénario n'est ignoré silencieusement. Le runner autonome a terminé 3/3 scénarios historiques : MAT-FUNC-007, 013, 018 et 019 sont couverts avec refus cross-tenant et nettoyage vérifié. Le quatrième scénario MAT-FUNC-020 est écrit et provisionné, mais son dernier run reste FAIL dans `final-core-product-020-last-run.json`; il n'est donc pas compté comme PASS.
