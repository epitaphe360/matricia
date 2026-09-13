# Preuve atomique C — MAT-FUNC-046..068 et MARKETING-001..008

Date : 2026-09-13  
Autorité : Gold Master V4 FINAL. Audit ciblé sans chargement du catalogue des 6 000 questions.

## Verdict

`VERIFIED` exige contrat + SQL/RLS + tests DB + E2E authentifié + audit indépendant. Aucun identifiant de ce lot n'est promu artificiellement : les preuves existantes sont solides mais plusieurs parcours ou visas restent manquants. La migration additive `20260913015800_marketing_v1_completeness.sql` ajoute treize enregistrements structurels explicitement absents sans prétendre achever les opérations métier; son test est `0103_marketing_v1_completeness.test.sql`.

## MAT-FUNC-046..068

| ID | Preuves présentes | Verdict atomique / reste exact |
|---|---|---|
| 046 | `07200`, `07900`, tests `0054`, `0059`, E2E P21 | PARTIAL — snapshots et parcours évolution présents; visa indépendant complet absent. |
| 047 | `09300`, `09500`, `09700`, tests `0067`, `0069`, `0071` | PARTIAL — baseline/preuve/périodes protégées; alimentation réelle et E2E ROI absents. |
| 048 | `09200`, `09400`, tests `0066`, `0068` | PARTIAL — favoris et revalidation existent; sélection/réemploi E2E absents. |
| 049 | `10200`, `10600`, `11000`, tests `0076`, `0080` | PARTIAL — clone/provenance/revalidation SQL prouvés; E2E UI absent. |
| 050 | `10200`, `10600`, `11300`, tests `0076`, `0080` | PARTIAL — cycles et génération bornée présents; scheduler et parcours utilisateur complets absents. |
| 051 | `09100`, `09600`, `07200`, tests `0065`, `0070`, `0054`, E2E P22 | PARTIAL — portefeuille/sites prouvés; propagation exhaustive missions/demandes non signée. |
| 052 | `01900`, `07100`, tests `0013`, `0053` | PARTIAL — décisions existent; workflow paramétrable multi-objet et concurrence E2E absents. |
| 053 | `09100`, `09600`, tests `0065`, `0070`, E2E P22 | PARTIAL — centres/allocations exactes présents; branchement exhaustif dépenses/factures absent. |
| 054 | design partagé, P05/P06/P18/P21/P22 à 360 px | PARTIAL — plusieurs parcours mobiles prouvés; matrice critique entière non auditée. |
| 055 | `03700`, test `0025` | PARTIAL — autosave/conflit DB; reprise réseau et concurrence UI E2E absentes. |
| 056 | états/row versions multi-domaines | PARTIAL — progressions locales; contrat transversal et E2E exhaustif absents. |
| 057 | `02400`, `03000`, `03700`, onboarding UI | PARTIAL — réemploi ponctuel; fraîcheur/vérification transversale non prouvée. |
| 058 | aides FR/AR dans formulaires critiques | PARTIAL — couverture systématique « pourquoi demandé » non auditée. |
| 059 | routes localisées, RTL, E2E bilingues | PARTIAL — couverture V1 complète et pseudo-localisation absentes. |
| 060 | textes FR/AR métier | PARTIAL — contrat technique + version client non systématiquement testé. |
| 061 | composants UI, axe/clavier sur P05/P06/P18/P21/P22 | PARTIAL — audit lecteur d'écran manuel global absent. |
| 062 | `09300`, `09500`, `09700`, tests `0067`, `0069`, `0071` | PARTIAL — calcul exact et baseline vérifiable; centre UI/E2E complet absent. |
| 063 | `07500`, test `0056`, UI notifications | PARTIAL — préférences par catégorie présentes; livraison digest/E2E bout-en-bout non signée. |
| 064 | `10300`, `10800`, `11400`, `12000`, `12200`, `12600`, tests `0077`, `0083`, `0089`, `0092` | PARTIAL — digest fortement prouvé; livraison réelle/scheduler externe et E2E absents. |
| 065 | `07100`, `13800`, tests `0053`, `0096`, command center UI | PARTIAL — files/KPI présents; ordre exécutif E2E et visa indépendant manquent. |
| 066 | `07100`, `08000`, tests `0053`, `0060` | PARTIAL — exceptions par domaines; reprise transversale et E2E manquent. |
| 067 | `05900`, tests `0043`, parcours RFQ | PARTIAL — cloisonnement des invitations; masquage contact/messagerie pré-sélection non exhaustifs. |
| 068 | `07100`, `07900`, tests `0053`, `0059`, `0063` | PARTIAL — risk flags sans sanction autonome; règles/faux positifs/E2E transversaux incomplets. |

## MARKETING-001..008

| ID | Preuves après migration 158 | Verdict atomique / reste exact |
|---|---|---|
| 001 | Brand Kits/version, assets, claims, restrictions; READY requis | PARTIAL — RPC d'édition/version et jeux de démonstration 10+20 absents. |
| 002 | contenus/versions/sources, FR/AR, quatre canaux, conformité | PARTIAL — génération déterministe « 1 service = 3 contenus » non implémentée. |
| 003 | six clés templates, versions et liens bibliothèque contraints | PARTIAL — seed/version UI des six templates et adaptation franchisée non prouvés. |
| 004 | règles versionnées par compte social, 8 posts/4 reels/jour 25, calendriers et états | PARTIAL — job mensuel et approbation globale E2E absents. |
| 005 | connexions/comptes/jobs/résultats, consentement, idempotence | PARTIAL — adaptateurs LinkedIn/Meta sandbox et failover provider absents. |
| 006 | événements immuables, leads, chemins multi-touch, valeur bigint, LAST_NON_DIRECT_CLICK | PARTIAL — ingestion publique CTA et liaison réelle diagnostic/RFQ/contrat absentes. |
| 007 | seuil de confidentialité versionné, snapshots/cibles pseudonymisés, suggestions tenant-scoped | PARTIAL — agrégateur hebdomadaire et génération depuis anomalies absents. |
| 008 | vue KPI et recommandations bornées | PARTIAL — vues/filtres complets acteur/bibliothèque/service/réseau/période et E2E absents. |

## Contrôles de sécurité

- RLS activée sur les 13 tables ajoutées; lecture via rôle tenant autorisé ou auditeur.
- Aucun droit de mutation direct à `authenticated`, `anon` ou `service_role`.
- Règles de calendrier, tendances et chemins d'attribution immuables.
- Valeurs marketing en `bigint` unités mineures; croissance en points de base, jamais float.
- Audience/tendance publiable seulement au-dessus du seuil stocké avec la version de politique; valeur initiale 10, configurable de 3 à 1 000.
- La publication existante reste conditionnée au consentement, Brand Kit READY, contrôles PASS, seuil de risque et connexion active; aucune dépense publicitaire autonome.

## Gates

- `git diff --check` : PASS.
- Test DB global incluant `0103` : PASS, 104 fichiers / 2 589 assertions / 4 scénarios de concurrence.
- Web : 126 fichiers / 480 tests, lint et typecheck PASS.
- E2E P18 FR/AR mobile : 12/12 PASS (accès anonyme/redirection); mutation marketing authentifiée reste manquante.
- Migration 158 appliquée uniquement sur Supabase development; dry-run final `upToDate: true`. Aucune production.
- Audit indépendant SQL/RLS : PASS sans P0/P1; aucune promotion fonctionnelle globale au-delà des preuves ci-dessus.
