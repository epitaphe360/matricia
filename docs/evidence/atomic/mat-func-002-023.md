# Preuve atomique candidate — MAT-FUNC-002 à MAT-FUNC-023

Date du relevé : 2026-09-13. Autorité : Gold Master V4 FINAL, lignes 2312 à
2333. Ce relevé ne modifie ni `REQUIREMENTS_COVERAGE.md`, ni la matrice
d'implémentation, ni `PROJECT_STATE.md`.

## Méthode et gates

- Contexte chargé : définitions MAT-FUNC-002–023, matrice V1, spécifications
  ciblées et fichiers des domaines Diagnostics, Assistance, Actions, Messagerie,
  Catalogue, Portefeuille, RFQ/Devis, Réputation, Qualification et Missions.
- Le catalogue des 6 000 questions n'a pas été chargé.
- Gate SQL/RLS exécuté : **22 fichiers, 680 assertions PASS**, plus **4/4**
  scénarios de concurrence (Outbox, journal financier, crédits et audit).
- Gate Web consolidé de la même révision : **126 fichiers, 480 tests PASS**;
  lint, TypeScript strict et build PASS.
- Preuves E2E existantes : P21 Diagnostics **4/4**, P22 Portefeuille **4/4**,
  Actions universelles **8/8**, P23 Provider Quotes **4/4** et parcours critiques
  authentifiés **20/20**. Les runners bornent development/staging, protègent les
  états d'authentification et neutralisent leurs fixtures.

`CANDIDATE` signifie que la chaîne technique est réunie dans ce rapport et peut
être soumise au visa indépendant puis à la mise à jour du registre partagé. Ce
mot ne signifie pas que le registre a déjà été promu à `VERIFIED`.

## Chaîne de preuve par fonction

| ID | Contrat contrôlé | Implémentation et SQL/RLS | Tests et preuve de parcours | Verdict honnête / blocage |
|---|---|---|---|---|
| MAT-FUNC-002 | Score global, sous-scores, anomalies et évolution. | `apps/web/app/[locale]/client/diagnostics/**`, `apps/web/modules/shared/lib/diagnostics-opportunities/**`, migrations `07200`, `11900`. | SQL `0054`; tests Web Diagnostics; P21 4/4 FR/AR 360/desktop, axe, clavier et isolation. | **CANDIDATE** — soumettre au visa atomique indépendant. |
| MAT-FUNC-003 | Assistance contextuelle bornée, révisable, sans sanction ni transaction critique autonome. | UI `client/diagnostics/assistance`, modules Assistance; migrations `10000`, `10500`, `10700`, `11200`, `11500`, `11700`, `11800`, `12100`, `12400`, `12500`, `13400`. | SQL `0074`, `0079`, `0082`, `0084`; P21; tests de rôle, PII, rétention, audit et décision humaine. | **CANDIDATE** — visa indépendant de la chaîne complète encore requis. |
| MAT-FUNC-004 | Un changement de profil produit une réévaluation versionnée et une suggestion soumise à décision humaine. | Migrations `10000`, `10500`, `11500`; UI Assistance/Diagnostics. | SQL `0074`, `0079`, `0084`; P21 expose la réévaluation et l'historique. | **CANDIDATE** — le visa doit confirmer le déclencheur profil de bout en bout. |
| MAT-FUNC-005 | Questions expirantes et revalidation légère sans perdre les versions de réponses. | Question engine persistant `03700`, Diagnostics `07200`, UI Questionnaires/Diagnostics. | SQL `0025`, `0054`, `0094`; P21 couvre reprise, expiration visible et évolution. | **CANDIDATE** — visa indépendant du scénario temporel requis. |
| MAT-FUNC-006 | File de tâches/actions utilisateur consolidée, sans sanction automatique. | `apps/web/app/[locale]/actions`, `apps/web/modules/shared/lib/action-center/**`, files administratives `07100`. | SQL `0053`; tests Web Action Center; E2E Actions 8/8 Client/Admin, FR/AR, 360/desktop. | **PARTIAL** — manque la preuve E2E Provider et Franchise d'une même file universelle. |
| MAT-FUNC-007 | Messagerie conversationnelle liée à un objet métier et isolée entre participants. | `apps/web/app/[locale]/messagerie/**`, `apps/web/modules/shared/lib/internal-messaging/**`, migration `14000`. | Notifications : SQL `0056` et Actions E2E; aucune preuve SQL dédiée ni E2E de création/lecture/envoi d'un fil métier n'a été trouvée. | **BLOCKED** — ajouter test SQL ALLOW/DENY/idempotence/audit/Outbox et E2E conversation réelle. |
| MAT-FUNC-008 | Texte borné → candidats services/questions justifiés → confirmation humaine, sans création silencieuse. | Contrat détaillé `docs/specs/sections/catalog-question-engine.md`; moteur Assistance `10000`, `10500`, `10700`, `11200`; UI Assistance. | SQL `0074`, `0079`, `0082`, `0084`; P21 authentifié et adversarial. | **CANDIDATE** — visa atomique final requis. |
| MAT-FUNC-009 | Trois solutions ESSENTIAL/STANDARD/ADVANCED versionnées pour une anomalie. | `apps/web/app/[locale]/client/diagnostics/solutions`, `apps/web/modules/shared/lib/solution-insights/**`, migrations `10100`, `11600`. | SQL `0075`, `0085`; P21 compare les trois niveaux en FR/AR. | **CANDIDATE** — visa de cohérence anomalie→trois solutions requis. |
| MAT-FUNC-010 | Bundle multi-bibliothèques versionné, provenance conservée, doublons/incompatibilités refusés. | Contrat détaillé `catalog-question-engine.md`; migrations `10100`, `11600`; UI Solutions. | SQL `0075`, `0085`; P21 rend composition/provenance sans charger les 6 000 questions. | **CANDIDATE** — visa atomique final requis. |
| MAT-FUNC-011 | Projet avec versions, tâches, contrats rattachés et progression. | `apps/web/app/[locale]/client/portefeuille`, `apps/web/modules/client/data/portfolio/**`, migrations `09100`, `09600`. | SQL `0065`, `0070`; P22 4/4 FR/AR 360/desktop avec isolation tenant. | **CANDIDATE** — soumettre au visa atomique indépendant. |
| MAT-FUNC-012 | Budget annuel ventilé année/bibliothèque/site/projet en unités mineures exactes. | Portefeuille Client, migrations `09100`, `09600`; calculs Web par chaînes/`BigInt`. | SQL `0065`, `0070`; tests Web Portefeuille; P22 4/4. | **CANDIDATE** — visa exact-money et concurrence final requis. |
| MAT-FUNC-013 | Comparaison normalisée de plusieurs devis autorisés pour une même RFQ. | Route `client/demandes/[requestId]/comparaison`, modules Client RFQ, migrations `06000`, `15600`, `15700`. | SQL `0044`, `0101`, `0102`; P23 prouve le devis Provider, pas la comparaison Client multi-provider. | **BLOCKED** — E2E Client avec au moins deux devis comparables et un devis étranger DENY manquant. |
| MAT-FUNC-014 | Score de complétude et blocage serveur de chaque champ obligatoire avant soumission. | `sous-traitant/devis/quote-panel.tsx`, schémas/actions Provider Quotes, RPC `06000`/`15600`. | SQL `0044`, `0101`; tests Web Provider; P23 remplit et soumet un devis exact. | **PARTIAL** — manque la matrice E2E négative omettant chaque champ obligatoire. |
| MAT-FUNC-015 | Classement personnel et axes d'amélioration anonymisés pour un Provider non retenu. | UI/répertoire Provider Reputation; migrations `09200`, `09400`, `09800`. | SQL `0066`, `0068`, `0072` (confidentialité et Outbox expurgée). | **BLOCKED** — aucun E2E destinataire avec offre retenue non identifiable. |
| MAT-FUNC-016 | Réputation versionnée sur six dimensions, explicable et sous gouvernance. | `apps/web/app/[locale]/sous-traitant/reputation`, `apps/web/modules/provider/data/reputation/**`, migrations `09200`, `09400`, `09800`. | SQL `0066`, `0068`, `0072`; tests Web du modèle/repository. | **BLOCKED** — alimentation bout en bout et E2E Provider FR/AR manquants. |
| MAT-FUNC-017 | Badges calculés selon politique versionnée, publiés/révoqués par décision humaine. | UI Reputation; migration `09200`. | SQL `0066`; tests Web de projection. | **BLOCKED** — recalcul événementiel et parcours E2E décision→publication/révocation manquants. |
| MAT-FUNC-018 | Matching déterministe/explicable avec politique et historique figés. | RFQ Client, migration `05900`; durcissement d'éligibilité `13000`. | SQL `0043`; tests de profil/capacité et raisons d'inclusion/exclusion. | **BLOCKED** — E2E RFQ réelle montrant shortlist, version de politique et explications manquant. |
| MAT-FUNC-019 | Rotation équitable évitant la monopolisation entre candidats équivalents. | Composante rotation et snapshot candidat dans `05900`. | SQL `0043` vérifie la composante, sans série temporelle concurrente. | **BLOCKED** — test multi-runs/concurrence et E2E d'équité temporelle manquants. |
| MAT-FUNC-020 | Capacité Provider versionnée AVAILABLE/LIMITED/FULL/PAUSED. | UI/Repository Qualification; migrations `06200`, `13000`. | SQL `0046`; le parcours critique vérifie seulement accès/isolation de la route. | **BLOCKED** — E2E transition des quatre états et impact matching manquant. |
| MAT-FUNC-021 | Calendrier Client consolidant échéances, tâches et jalons autorisés. | Portefeuille Client, migrations `09100`, `09600`. | SQL `0065`, `0070`; P22 4/4 vérifie événements typés et isolation. | **CANDIDATE** — visa atomique des projections automatiques requis. |
| MAT-FUNC-022 | Jalons de mission versionnés et validables selon rôles/états. | UI Missions Client/Provider, `apps/web/modules/shared/lib/contracts-missions/**`, migration `06100`. | SQL `0045`; tests Web contrats/missions; parcours critique vérifie accès/isolation. | **BLOCKED** — E2E création→validation de jalon et concurrence de transition manquants. |
| MAT-FUNC-023 | Preuves obligatoires par service avant soumission/livraison. | Missions Provider, `delivery_proofs` et RPC de `06100`. | SQL `0045` prouve `DELIVERY_PROOF_REQUIRED`, immutabilité, audit/Outbox. | **BLOCKED** — stockage/scan réel et E2E upload→scan CLEAN→soumission manquants. |

## Candidats et bloqueurs

Les candidats honnêtes à un visa atomique sont : **MAT-FUNC-002, 003, 004,
005, 008, 009, 010, 011, 012 et 021**. Ils ne doivent être promus dans le
registre partagé qu'après relecture indépendante de ce rapport et des preuves
référencées.

Les douze autres IDs restent `PARTIAL` ou `BLOCKED` pour des manques observables,
principalement des parcours E2E métier négatifs ou multi-acteurs. Aucun manque ne
justifie d'assouplir la RLS, de créer une migration non réservée ou de simuler une
preuve documentaire. Aucun environnement de production n'a été lu ou modifié.

