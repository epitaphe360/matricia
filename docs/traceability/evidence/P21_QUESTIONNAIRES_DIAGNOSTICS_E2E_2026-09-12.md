# P21 — preuve E2E Questionnaires et Diagnostics

## Périmètre vérifié

- Routes Client réelles : questionnaires, diagnostics, assistance contextuelle, solutions/benchmarks et évolution.
- Locales : français et arabe avec direction RTL native.
- Affichages : mobile 360 × 800 et desktop 1280 × 900.
- Contrôles : authentification Client, titres accessibles, navigation clavier, absence de débordement horizontal, WCAG 2 A/AA et 2.1 A/AA via axe.
- Isolation : le nom de l’organisation étrangère provisionnée n’apparaît sur aucune surface vérifiée.

## Exécution

Commande : `node tests/e2e/helpers/p21-questionnaire-diagnostics-run.mjs`

Résultat : **PASS — 4/4 tests**.

- FR mobile 360 : PASS
- AR RTL mobile 360 : PASS
- FR desktop : PASS
- AR RTL desktop : PASS

Le runner refuse toute cible autre que development/staging concordante, lie cryptographiquement le state Playwright au manifeste frais, utilise des fixtures temporaires et les neutralise dans un bloc `finally`. La preuve distante immuable requise a été conservée. Aucun secret n’est imprimé.

## Fonctions étayées

Cette preuve renforce MAT-FUNC-002, 003, 004, 005, 008, 009, 010, 041, 042, 044, 045 et 046 au niveau parcours UI authentifié. La simulation pure MAT-FUNC-043 et les baselines MAT-FUNC-047 conservent leurs preuves SQL/unitaires existantes ; leur mutation n’est pas simulée dans ce parcours Client en lecture/navigation.

## Limite restante

Ce test vérifie l’intégration et les frontières visibles avec des comptes réels, mais ne remplace pas les tests SQL/RLS, concurrence, déterminisme et rétention déjà dédiés à chaque moteur.
