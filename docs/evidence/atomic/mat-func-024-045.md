# Audit atomique MAT-FUNC-024 à MAT-FUNC-045

Date : 2026-09-13  
Autorité : Gold Master V4 FINAL, lignes 2334–2355.  
Périmètre : preuves ciblées contrats/missions, Provider, finance, litiges, volume, franchise et moteurs connexes. Le catalogue des 6 000 questions n'a pas été chargé.

## Règle de décision

`VERIFIED_CANDIDATE` exige simultanément un contrat métier explicite, une implémentation reliée, des tests unitaires et SQL/RLS positifs et négatifs, un E2E de mutation FR/AR à 360 px, une preuve d'exécution et un audit indépendant. Une route qui s'ouvre, un test d'existence de table ou une preuve transversale ne suffit pas. Ce document ne modifie aucun registre de statut.

## Résultat

- Candidats `VERIFIED_CANDIDATE` immédiatement promouvables : **0/22**.
- Exigences avec implémentation réelle mais preuve atomique incomplète : **22/22**.
- Correction livrée dans ce lot : snapshot immuable de checklist de service lors de la création d'une mission (`15900`, test `0104`) et suppression de la coercition `Number` du montant d'avenant.
- La migration 159 est appliquée en development et 0104 est vert; la promotion reste interdite avant E2E métier FR/AR et visa atomique complet par exigence.

## Matrice de preuves

| ID | Contrat et implémentation | Tests/preuves présents | Verdict et preuve exacte manquante |
|---|---|---|---|
| MAT-FUNC-024 | Checklist versionnée par service : `06100_contracts_missions_core.sql`; snapshot automatique additif `15900_contract_mission_checklist_snapshot.sql`. | `0045_p08_contracts_missions_core.test.sql`; `0104_contract_mission_checklist_snapshot.test.sql`. | `PARTIAL` — appliquer 159/0104 puis prouver en E2E FR/AR que la checklist figée est affichée et exécutée sans mutation du modèle historique; audit indépendant requis. |
| MAT-FUNC-025 | Réception critère par critère : `accept_delivery`, `acceptance_checklists`, actions Client et panneaux missions. | SQL `0045`; `apps/web/app/[locale]/client/missions/actions.test.ts`; route/a11y seulement dans `v1-critical-flows.spec.ts`. | `PARTIAL` — E2E de soumission, décision de chaque critère, rejet, correction puis acceptation complète; DENY d'un autre tenant et visa atomique manquent. |
| MAT-FUNC-026 | Avenant prix/délai/périmètre : `create_contract_amendment`, `change_requests`, `contract_amendments`, action Client. Montant corrigé en texte exact dans ce lot. | SQL `0045`; tests modèle/action Client. | `PARTIAL` — cycle demande → signatures → activation d'une nouvelle version contractuelle et E2E FR/AR manquent; l'activation d'avenant n'est pas implémentée par une commande dédiée. |
| MAT-FUNC-027 | Versions/immutabilité des contrats, devis, livraisons, ledgers, catalogues et règles. | SQL `0003`, `0044`, `0045`, `0060` et durcissements associés. | `PARTIAL` — inventaire exhaustif de tous les objets critiques, tests de mutation interdite par objet et signoff transversal indépendant manquent. |
| MAT-FUNC-028 | Documents privés/versionnés : migrations `02900` à `03400`, stockage privé et soumissions Client. | SQL `0020`, `0022`; E2E `p05-client-compliance.spec.ts`. | `PARTIAL` — réutilisation contrôlée du même document entre conformité, demande, contrat et mission, avec RLS et E2E, manque. |
| MAT-FUNC-029 | Expiration et restrictions ciblées : Provider qualification `06200`, notifications `07500`. | SQL `0046`, `0056`; UI qualification/notifications. | `PARTIAL` — scheduler de rappels, suspension limitée au service/document concerné, reprise après renouvellement et E2E temporel manquent. |
| MAT-FUNC-030 | Ledgers financiers/crédits séparés : migrations `00400`, `00500`, billing `06300`, crédits `07300`. | SQL `0003`, `0004`, `0047`, `0055`, tests de concurrence du runner DB. | `PARTIAL` — écran consolidé multi-rôles avec séparation explicite des sous-ledgers et E2E d'autorisation manque. |
| MAT-FUNC-031 | Événements payables et commissions exactes : `06300`, moteur fiscal `08000`. | SQL `0047`, `0060`; UI facturation Provider. | `PARTIAL` — aucun accrual estimé avant fait générateur/facturation avec rapprochement vers le montant officiel n'est prouvé. |
| MAT-FUNC-032 | Paiements, allocations et rapprochement : `06300_provider_billing_reconciliation.sql`. | SQL `0047`; tests modèle/actions facturation. | `PARTIAL` — E2E plusieurs paiements contre plusieurs factures, paiement partiel, trop-perçu/remboursement et concurrence manque. |
| MAT-FUNC-033 | Wallet et ledger crédits : `00500`, `07300`, correctif RLS `07700`. | SQL `0003`, `0055`, `0057`; UI `client/credits`. | `PARTIAL` — achat/webhook réel ou simulateur contractuel puis émission/consommation/expiration en E2E FR/AR manque. |
| MAT-FUNC-034 | Récompenses et règles versionnées : `09300`, `09500`, `09700`. | SQL `0067`, `0069`, `0071`. | `PARTIAL` — UI d'administration/versionnement, décision humaine et E2E d'émission dans le ledger manquent. |
| MAT-FUNC-035 | Parrainage et conversion traçable : `09300`, `09500`, `09700`, anti-oracle `09900`. | SQL `0067`, `0069`, `0071`, `0073`. | `PARTIAL` — création/partage du lien, parcours destinataire, conversion et anti-fraude E2E manquent. |
| MAT-FUNC-036 | CRM franchisé : `07900`, durcissements `08700`/`08900`; UI performance/relances. | SQL `0059`, `0063`; tests actions/modèles franchise. | `PARTIAL` — mutations prospects/clients/providers et isolation entre deux franchises en E2E manquent. |
| MAT-FUNC-037 | Pipeline franchisé à neuf étapes : `07900`. | SQL `0059`, `0063`. | `PARTIAL` — UI pipeline dédiée, transitions autorisées/interdites, concurrence et E2E manquent. |
| MAT-FUNC-038 | Relances planifiées : `14100_franchise_followup_scheduler.sql`, worker `franchise-followups.ts`, UI `franchise/relances`. | Tests unitaires repository/actions disponibles. | `PARTIAL` — test SQL dédié lease/retry/dead-letter et E2E d'une relance arrivée à échéance manquent. |
| MAT-FUNC-039 | Modèles FR/AR versionnés : `07500`, correctif variables `07600`. | SQL `0056`; tests messages FR/AR. | `PARTIAL` — couverture de tous événements obligatoires, rendu, envoi demo/réel et E2E de livraison manquent. |
| MAT-FUNC-040 | Duplication/versionnement de questions : `05100`; tables clauses/checklists côté contrats. | SQL `0039`, `0045`. | `PARTIAL` — clonage atomique de questionnaires complets, clauses et checklists avec provenance/version et E2E manque. |
| MAT-FUNC-041 | Suggestions de qualité explicables et revues humaines : `10000`, `10500`, `11500`, `11700`. | SQL `0074`, `0079`, `0084`, `0086`; E2E P21 de consultation. | `PARTIAL` — UI de revue/décision, scénarios adversariaux et E2E de mutation manquent. |
| MAT-FUNC-042 | Détection déterministe de similarité questions/services/anomalies : `10000`, `10700`. | SQL `0074`, `0079`, `0084`. | `PARTIAL` — seuils administrables exposés, revue humaine et E2E sur les trois types manquent. |
| MAT-FUNC-043 | Simulation sans effet de bord : `08400`, correctif canonique `08800`. | SQL `0061`; P21 confirme explicitement qu'aucune mutation sandbox n'est exécutée. | `PARTIAL` — UI sandbox reliée, comparaison déterministe attendue/réelle et preuve E2E d'absence de statistiques réelles manquent. |
| MAT-FUNC-044 | Sessions/abandons : `09000`, analytics `14200_questionnaire_abandonment_analytics.sql`. | SQL `0064` pour sessions. | `PARTIAL` — test SQL dédié des agrégats section/question, seuils de confidentialité, UI et E2E manquent. |
| MAT-FUNC-045 | Benchmark anonymisé : `10100`, confidentialité `10400`, compatibilité `10900`, verrouillage `11100`, registre `11600`, preuve-valeur `11900`. | SQL `0075`, `0078`, `0081`, `0085`, `0088`. | `PARTIAL` — UI, E2E de seuil minimal/cellule scellée et signoff indépendant atomique manquent. |

## Invariants contrôlés

- Montants en unités mineures exactes; aucune nouvelle coercition flottante.
- Snapshots contractuels, checklists, preuves, ledgers et règles historiques immuables.
- RLS restrictive et lecture réservée aux parties de la mission; aucune écriture directe depuis `authenticated`.
- Toute création sensible reste transactionnelle, idempotente, auditée et reliée à l'Event Outbox.
- FR/AR et contenu bilingue conservés dans le snapshot de checklist.
- Aucune opération production et aucun secret consulté ou affiché.

## Gates à enregistrer après exécution

| Gate | Résultat |
|---|---|
| Tests Web | PASS — 126 fichiers, 480 tests |
| TypeScript Web | PASS |
| Lint Web | PASS |
| Migration 159 appliquée en development après 158 | PASS |
| SQL 0104 | PASS — 20 assertions; replay global 104 fichiers/2 589 assertions |
| E2E métier MAT-FUNC-024..026 | BLOCKED — scénario authentifié de mutation non encore créé |
| Audit indépendant | PASS migration/test; aucune promotion fonctionnelle globale |

## Risques et prochaine action

La migration 159 rend la checklist obligatoire pour toute nouvelle mission; les services sans template publié échouent volontairement avec `MISSION_CHECKLIST_TEMPLATE_REQUIRED`. Avant promotion MAT-FUNC-024, fournir au moins un template versionné par service V1, exposer le snapshot en lecture dans l'UI mission, exécuter un E2E FR/AR 360 px et obtenir un visa indépendant. Les autres lignes restent bloquées par la preuve exacte indiquée ci-dessus.
