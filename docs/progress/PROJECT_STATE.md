# Matricia — Project State

Dernière mise à jour : 2026-09-12 15:50 America/Toronto

Phase de contrôle active : **PHASE 01 — contrats atomiques en cours**

Travaux engagés : **PHASES 01, 03, 05 et 06 — en cours; PHASES 02 et 04 signées GREEN**

## État prouvé

- Gold Master V4 FINAL et `AGENTS.md` sont les autorités actives.
- PHASE 00 est GREEN au commit `32cfd89` après visa indépendant : inventaire, 63 agents, index des 76 exigences, plans, Marketing et context-pack ciblé sont conformes.
- Inventaire PHASE 00, ExecPlan P00–P19, index de contexte, architecture, threat model et carte d’ownership sont présents.
- Les 57 agents du corps principal et les 6 agents obligatoires Marketing possèdent 63 configurations TOML projet.
- Catalogue validé : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions.
- Les sept registres bootstrap ont des références nominales cohérentes; P01 reste ouverte car ils ne couvrent pas encore atomiquement les 76 exigences.
- Traçabilité enregistrée pour MAT-FUNC-001..068 et MARKETING-001..008. Aucune exigence n’est déclarée `VERIFIED` sans preuve.
- Monorepo pnpm, Next.js App Router, worker et packages TypeScript strict sont opérationnels.
- PHASE 02 est GREEN au commit `d92d8f0` après réaudit indépendant : installation figée, frontières de modules, lint, typecheck, 74 tests, build, logger expurgé, Worker et Design A sont conformes sans finding P0/P1/P2.
- PHASE 04 est GREEN après visa indépendant : connexion OTP PKCE, invitations courriel, rôles cumulables, sessions, mot de passe facultatif, MFA TOTP et saga d'audit Auth sont implémentés en FR/AR RTL.
- `.env.local` est ignoré par Git; aucune valeur secrète n’est consignée.

## Supabase development/staging

Projet distant Matricia contrôlé en environnement applicatif `development`; la CLI Supabase est liée au projet vérifié. Après dry-run propre, les migrations `20260912013000`, `13100`, `13200`, `13300`, `13400`, `13600`, `13700`, `13900`, `14000`, `14100` et `14200` sont confirmées appliquées avec succès à distance. Les statuts déjà confirmés de `12800` et `12900` restent acquis; aucun statut supplémentaire n'est revendiqué ici.

1. extensions et référentiels versionnés;
2. identité, organisations, memberships et RBAC;
3. idempotence, audit et Event Outbox;
4. ledger financier immuable et équilibré;
5. ledger de crédits immuable;
6. rôles et règles économiques de référence;
7. support pgTAP de test;
8. RPC financières/crédits atomiques;
9. scellement sérialisé de la chaîne d’audit;
10. claim Outbox `SKIP LOCKED`, retry et dead-letter;
11. durcissement des invariants et privilèges;
12. hash canonique serveur pour l’idempotence;
13. restriction d’accès runtime au schéma d’extensions.
14. workflows identité P04 : profil, OTP limité, ICE, rattachement, invitations, sessions;
15. sonde readiness DB/Outbox à privilège minimal;
16. rechargement explicite du schéma API;
17. correction additive de la sonde sur le schéma Outbox immuable.
18. révocation complète des ACL runtime dangereuses, grants minimaux et readiness hors dead-letter.
19. demandes idempotentes de rôles cumulables, interdiction des rôles plateforme, approbation centrale des rôles `OWNER` transverses et refus de l'auto-approbation.
20. refus explicite et idempotent d'invitation, statut `DECLINED`, blocage de l'auto-invitation et du contournement des rôles `OWNER` transverses.
21. onboarding Client versionné, décision centrale et essai initial de 30 jours;
22. documents de conformité privés, questions/réponses, gates de soumission et transitions;
23. scan documentaire serveur, matrice versionnée, anomalies ciblées et RPC minimale du worker.
24. catalogue W1 : hiérarchie et versions immuables, releases gouvernées,
    audiences/fenêtres canoniques, attestation AR, worker à lease/retry/dead-letter,
    audit, Outbox et RLS restrictive.
25. persistance Question/Rule Engine : questionnaires/règles versionnés, snapshots,
    réponses validées, calculs décimaux exacts, idempotence, audit et Outbox;
26. API Client catalogue : lectures RPC authentifiées, snapshot de release exact,
    visibilité fail-closed et pagination keyset;
27. compatibilité additive des anciens writers de versions catalogue;
28. snapshots catalogue historiques explicites préservés avec FK intra-bibliothèque;
29. lifecycle catalogue durci par capabilities transactionnelles à usage unique,
    MFA fail-closed, items scellés et récupération rollback contrôlée.
30. import baseline transactionnel et idempotent, commandes de hiérarchie/services,
    compatibilités legacy fail-closed et contrat strict des questions publiables.
31. commandes Question Builder : création, nouvelle version de brouillon, duplication,
    archivage/restauration, scope GLOBAL central AAL2, audit et Event Outbox;
32. interface Question Builder réelle : création DRAFT bilingue FR/AR et RTL par
    service, sensibilité, exigences devis, identité idempotente persistée et retours accessibles;
33. commandes Rule Builder : création et nouvelle version DRAFT immuable,
    concurrence optimiste, hash canonique serveur, MFA sensible, audit et Event Outbox;
34. interface Rule Builder FR/AR RTL : prédicat booléen déterministe, action typée,
    priorité, sensibilité, confirmation et identité idempotente persistée;
35. création Questionnaire Builder : version DRAFT bilingue liée à une release
    éditable, première section immuable, idempotence, MFA sensible, audit et Outbox.
36. composition Questionnaire Builder : sections suivantes ordonnées, ajout de
    questions et règles approuvées/publiées, concurrence optimiste, snapshot
    canonique, MFA sensible, audit et Outbox.
37. gate de charge catalogue GET-only, borné et fail-closed avec scénarios 6k/50k
    et sortie de métriques nettoyée; harness local 6/6 vert, exécution distante à prouver.
38. RFQ et matching explicable : demandes versionnées, éligibilité, invitations,
    sélection idempotente, audit, Outbox et RLS restrictive;
39. devis et comparaison : révisions exactes, comparaison normalisée sans float,
    sélection d'une version précise, audit et isolation inter-tenant;
40. contrats et missions : snapshots contractuels, signatures, jalons, livrables,
    acceptation et transitions gouvernées;
41. qualification Sous-traitant : capacités, preuves, décisions versionnées et
    contrôle d'éligibilité;
42. facturation Sous-traitant : factures, événements payables, règlements et
    rapprochements adossés aux écritures immuables;
43. litiges et réaffectation : preuves, médiation, décision et transfert contrôlé;
44. achats groupés : pools, engagements, consommation et allocation fournisseur;
45. gouvernance et finance franchise : territoires, mandats, exception IT,
    allocations et distributions immuables;
46. abonnements : plans versionnés, cycles, essais et transitions idempotentes;
47. command center Administration : supervision, approbations et commandes
    opérationnelles à privilège minimal.
48. diagnostics/opportunités : résultats et scores exacts, snapshots, anomalies,
    recommandations, recomputation et transitions contrôlées vers RFQ;
49. Boxes/crédits : avantages versionnés, wallets sûrs, lots FIFO expirables,
    réservation/libération/consommation et suppression de l'auto-attribution;
50. notifications : templates FR/AR versionnés, préférences immédiat/digest,
    alertes critiques obligatoires, inbox, déduplication, retry et dead-letter.
51. Marketing Autopilot : consentements append-only, Brand Kit et contenus FR/AR
    versionnés, approbation humaine, orchestration Outbox, fréquence, attribution et KPI;
52. CRM/performance franchise : pipeline, activités immuables, objectifs et snapshots
    KPI versionnés, scores exacts et alertes explicables sans sanction automatique;
53. moteur fiscal Maroc : catégories FR/AR, règles datées/versionnées sans taux
    hardcodé, validation/approbation, calcul exact et raccord facturation compatible.
54. moteur Question/Rule avancé : AST AND/OR/NOT borné, quinze opérateurs,
    détection des cycles, actions typées, scoring exact et simulation reproductible.
55. durcissements indépendamment réaudités : AUTOPILOT et consentement owner-only,
    PII CRM isolées, ownership CRM intra-tenant, KPI bornés/uniques et réponses
    numériques canoniques évaluées de manière identique aux raccourcis.
56. sessions questionnaires : snapshot immuable, reprise, soumission reproductible,
    abandon/expiration, réponses privées et évaluation par le moteur avancé;
57. portefeuille Client : projets, tâches, budgets annuels exacts, centres de coûts,
    allocations tenant-bound et calendrier central;
58. Provider : feedback réellement anonymisé, réputation versionnée à six dimensions,
    badges sous décision humaine et favoris revalidés;
59. récompenses/parrainage/ROI : règles et plafonds versionnés, ledger crédits,
    double contrôle AAL2, preuves durables, baselines approuvées et calculs exacts.
60. IA assistée et qualité : analyses bornées et déterministes, revue humaine,
    qualité/similarité bilingue, provenance, minimisation PII et rétention contrôlée;
61. solutions et benchmark : bundles inter-bibliothèques versionnés selon les
    niveaux `ESSENTIAL`, `STANDARD` et `ADVANCED`, benchmarks anonymisés sous
    politique de confidentialité et registre de métriques faisant autorité;
62. RFQ récurrentes : clonage avec provenance immuable, plans mensuels,
    trimestriels ou annuels, snapshots publiés et génération bornée sans
    invitation ni dépense autonome;
63. digest franchise : synthèse FR/AR configurable sans PII, agrégats CRM/KPI,
    jobs idempotents avec lease, retry/dead-letter et notification versionnée;
64. durcissements P1/P2 issus de l'audit : budget de confidentialité benchmark
    scellé contre les oracles par différence, autorisations par rôle et ACL à
    privilège minimal, révocation fail-closed, verrous de concurrence partagés,
    entrées d'assistance minimisées et absence d'expiration artificielle pour une
    entrée vide.
65. durcissements finaux `11900`–`12400` : valeur benchmark liée exactement à
    sa preuve, sa version de registre et sa politique source; scope exact par
    franchise dans les organisations multi-franchises; purge automatique bornée
    des entrées d'assistance avec minimisation CIN/passeport; scope canonique
    d'idempotence du digest et corrélation d'audit non-PII stable au replay.
66. durcissements `12500`–`12600` : cycle autonome et borné de purge des entrées
    d'assistance, contrôle strict des leases, retry/dead-letter et minimisation PII;
    sélection du scheduler digest bornée avant composition, dernière configuration
    seulement, ordre déterministe et absence de famine entre lots.

Preuves actuelles :

- 123 migrations locales/distantes `20260910000100`..`20260912012600` appliquées sur development, avec `20260912012300` intentionnellement absente;
- lint SQL public/private sans erreur de schéma lors du dernier contrôle distant;
- `pnpm test:db` vert le 2026-09-12 pour les fichiers `0001`..`0092` : 92 fichiers, 2 397 assertions et quatre scénarios à deux connexions couvrant Outbox, journal, crédits et chaîne audit;
- tests négatifs RLS inter-tenant, immutabilité, équilibre/devise, crédits, idempotence, audit et Outbox.

Docker local reste indisponible sur cet hôte; la reconstruction propre doit être prouvée par le job CI Supabase avant signature P03.
Le workflow GitHub Actions contient bien un job de replay Supabase vierge, mais les
deux jobs du dernier run n'ont reçu aucun runner : GitHub les refuse actuellement
avec l'annotation `account is locked due to a billing issue`. Cette contrainte de
compte externe empêche la preuve CI tant qu'elle n'est pas levée; elle ne vaut pas
échec des migrations locales ou development.

## Gates exécutés les 2026-09-11 et 2026-09-12

- `pnpm verify:phase00` : vert — catalogue 10/200/6000, 7 registres bootstrap, 68 fonctions, 8 exigences Marketing conformes à l’addendum et 63 agents.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- Tests Web : vert — 76 fichiers, 313 tests.
- Tests Worker : vert — 11 fichiers, 54 tests; typecheck strict vert.
- `pnpm test:db` : vert pour `0001`..`0092` — 92 fichiers et 2 397 assertions, plus quatre scénarios génériques à deux connexions. Sessions, portefeuille Client, réputation Provider, rewards/referral/ROI, IA assistée/qualité, bundles/benchmarks, RFQ récurrentes et digest franchise sont appliqués, durcis et couverts sur Supabase development.
- E2E catalogue authentifié réel : 4/4 en FR/AR à 360 px, navigation clavier,
  axe, recherche discriminante et RPC de publication/lecture réelles; crash/reaper
  `SCHEDULED` et `PUBLISHING` prouvés, zéro résidu actif ou artefact local.
- E2E P05 authentifiés : 28/28 exactement, zéro skip/flaky/unexpected, FR/AR, 360 px et desktop; cleanup distant vérifié et preuve sanitizée persistée.
- E2E des nouvelles routes Marketing, CRM franchise et Fiscalité : 12/12
  scénarios anonymes réels, FR/AR, mobile 360 px et desktop, RTL/LTR, clavier,
  absence d’overflow et axe; les ALLOW/DENY authentifiés restent à prouver avec
  des fixtures dédiées Franchise Manager et administrateur fiscal AAL2.
- `pnpm build` : vert — routes identité, organisation, invitations, rôles, sécurité et santé compilées.
- `pnpm release:validate` : vert — uniquement gates structurels et absence de placeholders dans le périmètre contrôlé; ce n’est pas une signature de release.

## Audits et écarts

- Les réaudits P00/P01 ont identifié puis fait corriger les métriques d’inventaire, la force des validateurs, le signoff positif et le context-pack structuré. Le réaudit final indépendant au commit `32cfd89` est PASS; P00 est fermée GREEN.
- Le second réaudit P03 a détecté des droits `TRUNCATE` runtime hérités, un seed absent et la prise en compte des dead-letters en readiness. La migration additive 018, le test ACL et `supabase/seed.sql` corrigent ces écarts; seul le replay CI vierge et le nouveau visa restent requis.
- Les réaudits P02 ont imposé redaction PII, readiness réelle, Worker exécutable, TypeScript renforcé et palette navy/bleu vif. Ces écarts sont corrigés et le visa indépendant final au commit `d92d8f0` est PASS; P02 est fermée GREEN.
- Le réaudit indépendant du lot Marketing/CRM/Fiscalité/Rule Engine a fermé 7/7
  findings : trois P1 d’autorisation/isolation/évaluation canonique et quatre P2
  d’intégrité KPI, ownership CRM, accessibilité et localisation FR/AR.
- Le signoff sécurité indépendant du lot backend `09000`–`09900` est GREEN :
  confidentialité feedback/Outbox historique, preuves réputation, audience/wallet,
  double contrôle Referral, baseline durable, portefeuille et anti-oracles sont fermés,
  sans finding P0/P1/P2 ouvert.
- Le lot backend `10000`–`12600` intègre les durcissements P1/P2 d'audit sur
  la confidentialité des benchmarks, les autorisations de l'assistance et du digest,
  la minimisation PII, la concurrence des publications/générations et les ACL des
  helpers. Les compléments `11900`–`12400` lient la valeur à sa provenance
  benchmark, ferment le scope exact franchise et l'idempotence du digest, et
  automatisent la purge PII avec corrélation d'audit stable. Les tests
  `12500` et `12600` ajoutent l'exécution autonome de purge avec lease/retry et le
  bornage du scheduler digest avant composition. Les tests `0074`..`0092`
  couvrent ces correctifs dans le gate DB vert.
- P01 ne couvre pas encore les contrats atomiques de toutes les phases.
- P04 est GREEN : OTP, organisations, invitations courriel, rôles, sessions, mot de passe facultatif, MFA TOTP, AAL2 et saga d'audit Auth durable ont passé le visa indépendant sans P0/P1/P2.
- P05 dispose des migrations appliquées `024`, `026` et `029`–`03550` : profils, documents privés, questionnaires, matrice/anomalies, scan serveur, activation et essai 30 jours. Interfaces, Worker, concurrence et E2E authentifiés sont prouvés. ClamAV staging réel et replay vierge restent requis; P05 demeure `IN_PROGRESS`.
- P06 est en cours : catalogue W1, persistance Question/Rule W2, API Client,
  lifecycle immuable et E2E authentifié sont appliqués/verts. Le baseline development
  est importé et vérifié : 10 bibliothèques, 40 catégories, 80 sous-catégories,
  200 services, 212 liens, 220 questionnaires et 6 000 questions; releases et
  traductions restent volontairement `DRAFT/PENDING`. La suite globale atteint
  41 fichiers/981 assertions et les concurrences hiérarchie/services sont vertes.
  Les commandes serveur du Question Builder sont appliquées et testées; l’interface
  de création de questions DRAFT est livrée en FR/AR RTL avec contrat strict. La
  création et le versionnage DRAFT des règles sont appliqués avec hash canonique,
  MFA sensible, audit et Outbox. L’interface Rule Builder booléenne est branchée
  sur la commande réelle. La création de questionnaires, les sections suivantes
  et l’ajout gouverné de questions/règles aux snapshots sont appliqués et testés.
  Le gate de charge 6k/50k est implémenté et testé localement, mais sa preuve
  distante reste requise. Les opérateurs avancés, la validation/simulation, les
  sessions et les fondations IA assistée de qualité/similarité sont appliqués et
  couverts en base; leur intégration complète aux parcours et le visa indépendant
  restent requis avant GREEN.
- Les fondations et interfaces P07–P18 progressent en lots indépendants : RFQ/devis,
  contrats/missions Client et Sous-traitant, qualification/facturation Provider,
  litiges/réaffectation, achats groupés, franchise, abonnements, administration,
  diagnostics/opportunités, Boxes/crédits, Notifications, Marketing Autopilot,
  CRM/performance franchise et moteur fiscal Maroc sont branchés côté données et
  disposent maintenant de routes Web FR/AR pour les trois derniers domaines. Les
  fondations de bundles `ESSENTIAL`/`STANDARD`/`ADVANCED`, benchmark anonymisé,
  clonage/récurrence RFQ et digest franchise sont également appliquées et testées.
  Les E2E multi-rôles,
  audits indépendants et la traçabilité atomique restent requis avant GREEN.
- La couverture MAT-FUNC-001..068 et MARKETING-001..008 reste partielle : les
  fondations de plusieurs domaines sont présentes, mais la traçabilité atomique,
  les parcours E2E et les audits indépendants restent requis avant de déclarer
  chaque exigence `VERIFIED`.
- Le registre atomique strict compte actuellement 1 exigence `PROVEN`, 67
  `PARTIAL`, 0 `MISSING` et 0 `BLOCKED`; il contient exactement 68 IDs uniques.
- Vercel et Railway ne sont pas configurés. Aucune production n’a été modifiée ou autorisée.

## Prochaine exécution

1. Intégrer et valider les interfaces Client RFQ/devis, qualification et facturation Sous-traitant, contrats/missions, litiges et command center.
2. Intégrer aux parcours P06/P07/P10 l'IA assistée, les opérateurs avancés, la
   validation/simulation, les sessions, les bundles/benchmarks, la récurrence RFQ
   et le digest franchise; prouver les E2E associés et la charge distante 6k/50k.
3. Compléter la traçabilité atomique P01 et les parcours E2E/RLS des fondations P07–P17.
4. Obtenir un replay DB vierge CI et prouver ClamAV réel en staging.
5. Continuer P07..P19 selon `PLANS.md`, sans sauter de gate.

## Checkpoint UI 2026-09-12

- Assistance diagnostique bornee, decisions de solutions, benchmarks anonymises,
  RFQ recurrentes et digest franchise disposent maintenant de routes Web FR/AR,
  RTL, responsive 360 px et d''actions branchees sur les RPC finales.
- Les decisions humaines restent obligatoires; aucune invitation, depense ou action
  metier critique autonome n''est declenchee par ces interfaces.
- Les montants de solutions restent en unites mineures exactes et sont affiches avec
  `BigInt`, sans conversion flottante.
- Gate Web apres integration : lint vert, TypeScript strict vert, build Next.js vert,
  94 fichiers de tests et 365 tests verts.
- Restent requis avant GREEN : E2E authentifie multi-role FR/AR a 360 px, audit
  independant, charge distante 6k/50k et preuves SQL/RLS contractuelles associees.

## Checkpoint local intégré 2026-09-12

- Le lot fonctionnel Web V1 raccorde désormais les parcours RFQ/devis et comparaison,
  contrats/missions et réceptions, qualification/facturation/réputation Sous-traitant,
  litiges/réaffectation, achats groupés Client/Admin, abonnements et paiement de
  démonstration, diagnostics/opportunités et assistance, portefeuille et crédits,
  récompenses/parrainage/ROI, notifications, ainsi que gouvernance et finance
  franchise. La navigation partagée n'expose que les routes fonctionnelles selon
  l'espace et le rôle, avec libellés FR/AR et direction RTL.
- Les décisions sensibles restent humaines et autorisées côté serveur : versions,
  signatures, avenants, jalons, preuves, réception et acceptation sont conservés
  dans les snapshots contractuels; les écritures financières et de crédits passent
  par les RPC/ledgers immuables, avec montants exacts en unités mineures.
- La règle franchise IT est exposée sans droit d'entrée et avec distribution 50 %
  Hatim Ahmitech / 50 % Jalil-NEOXA / 0 % Mme Asma-Matricia. Les autres franchises
  utilisent la règle versionnée 50 % / 25 % / 25 % sur base distribuable.
- Les migrations `20260912012700` à `20260912013400` sont présentes localement :
  autorisation RPC Question/Rule, portée des références documentaires, lecture des
  récurrences, éligibilité Provider à la réaffectation, activation de paiement,
  consommation des avantages après livraison, agrégats Admin des achats groupés et
  alignement des rôles RPC d'assistance. Seules `12800` et `12900` sont confirmées
  appliquées à distance. `13000`–`13400` sont désormais également confirmées
  appliquées sur Supabase Matricia development après dry-run propre et liaison CLI
  vérifiée; aucun déploiement de production n'a été tenté. Le statut distant de
  `12700` n'est pas revendiqué dans ce checkpoint.
- Le paiement de démonstration dispose d'intentions et d'un webhook idempotent; le
  secret local reste exclusivement dans `.env.local`, ignoré par Git. L'assistance
  minimise les PII avant RPC et conserve provenance, version et revue humaine.
- Les tests globaux, SQL/RLS et E2E sont volontairement différés à la fin du cycle
  de développement demandé. Le présent checkpoint ne déclare donc aucun nouveau
  module GREEN ni aucune exigence supplémentaire `VERIFIED`; les résultats de tests
  antérieurs consignés ci-dessus restent historiques et ne valent pas visa de ce lot.
- Prochaine action : confirmer séparément le statut distant de `12700`, puis exécuter
  les gates globaux, E2E multi-rôles FR/AR/RTL et audits indépendants.

## Checkpoint local d'intégration 2026-09-12

- Le module Catalogue/Publications expose l'historique des releases versionnées et
  le rollback gouverné, avec contrôle AAL2 pour l'action sensible, audit serveur,
  libellés FR/AR et RTL. La navigation partagée publie son lien uniquement pour les
  rôles plateforme `SUPER_ADMIN`, `MATRICIA_ADMIN` et `LIBRARY_MANAGER`, alignés sur
  l'autorisation du dépôt serveur.
- Le module CRM/Performance Franchise expose les activités et événements de pipeline
  immuables ainsi que les snapshots KPI versionnés. Les montants et valeurs `bigint`
  ou `numeric` restent des chaînes exactes; les objectifs et alertes demeurent en
  lecture seule tant qu'aucune RPC de mutation autorisée n'existe.
- Contrôle d'intégration Web : `pnpm --filter @matricia/web typecheck` vert et
  `pnpm --filter @matricia/web lint` vert. L'horodatage des expirations de crédits est
  isolé dans un module `server-only` pour préserver la pureté du rendu React.
- Aucun test global, SQL/RLS ou E2E n'a été lancé dans ce checkpoint, conformément au
  différé de fin de développement. Aucun changement de production ou secret n'est inclus.

## Checkpoint local Public et SEO 2026-09-12

- Les routes publiques FR/AR réelles couvrent désormais l'accueil, Services,
  Franchise, À propos et Contact sous un layout commun. Header, footer, navigation
  clavier, reflow 360 px, direction RTL et bascule de langue sont partagés; Contact
  propose uniquement des CTA fonctionnels vers Services et Connexion, sans faux
  formulaire ni collecte publique de données personnelles.
- Le proxy évite le refresh Supabase uniquement pour les chemins publics allowlistés.
  Connexion conserve le contrôle de session; Catalogue authentifié, Client,
  Sous-traitant, Franchise métier, Administration, Notifications, Organisation et
  Sécurité restent fail-closed. Le chemin public `/franchise` n'ouvre aucune de ses
  sous-routes métier.
- Aucune RPC catalogue exécutable par `anon` n'existe : la vitrine utilise donc une
  projection statique bornée au manifeste vérifié `1.0.0`, soit 10 bibliothèques et
  200 services. Les 6 000 questions et tous les brouillons restent exclus.
- Chaque route publique possède ses métadonnées FR/AR, canonical, hreflang, Open
  Graph et Twitter. `robots.txt` utilise une allowlist publique et interdit les
  espaces privés/auth; le sitemap contient exactement 10 URL localisées. Connexion
  est `noindex`; le manifeste et la carte sociale sont présents.
- Le même lot finalise l'évolution versionnée des diagnostics et l'historique des
  allocations de facturation Sous-traitant. Les montants et reliquats restent des
  chaînes entières exactes, sans conversion flottante ni mutation de ledger.
- Gates d'intégration : `pnpm --filter @matricia/web typecheck` vert,
  `pnpm --filter @matricia/web lint` vert et `git diff --check` vert. Aucun E2E n'a
  été lancé; la revue visuelle réelle à 360 px et la validation crawler de la carte
  sociale restent à effectuer en fin de développement.

## Checkpoint local Administration V1 2026-09-12

- La navigation partagée expose désormais, uniquement selon les rôles plateforme
  autorisés par chaque dépôt serveur, les consoles Clients/Conformité,
  Sous-traitants/Facturation, Finance, Gouvernance Franchise/Litiges et
  Notifications/Audit/Outbox.
- Admin Clients applique la séparation quatre-yeux aux décisions de conformité,
  revues documentaires et acceptations de réponses. Le réaudit statique des
  migrations additives locales `20260912013700` et `20260912013900` est PASS : la
  projection est minimisée, AAL2 est vérifié côté PostgreSQL et Server Actions, et
  les preuves quatre-yeux sont durables et fail-closed. Ces migrations ne sont ni
  désormais confirmées appliquées sur Supabase Matricia development après dry-run
  propre. Le présent checkpoint ne remplace pas les tests SQL/RLS de fin de cycle.
- Admin Finance conserve les montants en unités mineures exactes et les
  rapprochements idempotents. Admin Providers conserve les preuves, décisions
  versionnées et écritures financières via les RPC métier. Gouvernance expose les
  territoires, mandats, distributions et réaffectations, dont la règle IT exacte.
- Admin Operations expose en lecture seule un journal d'audit expurgé aux seuls
  rôles `SUPER_ADMIN`, `MATRICIA_ADMIN` et `READ_ONLY_AUDITOR`. Aucun payload,
  metadata, IP, user-agent ou identifiant utilisateur/organisation n'est chargé.
  Aucun retry, replay ou traitement de dead-letter n'est proposé.
- La migration 138 de projection agrégée Outbox/livraisons a été refusée par le
  contrôle de sécurité faute d'une autorisation utilisateur explicite pour
  l'élargissement `SECURITY DEFINER`; elle n'a pas été créée ni appliquée. Ces
  données restent fail-closed dans l'interface et aucune RLS n'a été assouplie.
- Les tests globaux, SQL/RLS et E2E restent volontairement différés à la fin du
  développement. Aucun changement de production, liaison distante ou secret ne
  fait partie de ce checkpoint.

## Checkpoint local Messagerie, Relances et Analytique 2026-09-12

- La messagerie interne sécurisée, les relances Franchise et l'analytique agrégée
  d'abandon des questionnaires disposent de routes FR/AR raccordées à la navigation
  selon les memberships et rôles strictement autorisés par leurs repositories/RLS.
- Les migrations `20260912014000`, `20260912014100` et `20260912014200` sont
  confirmées appliquées sur Supabase Matricia development, CLI liée, après dry-run
  propre. Les migrations `13600`, `13700` et `13900` sont également confirmées
  appliquées dans le même environnement.
- Les relances conservent consentement, heures calmes, plafonds versionnés,
  séparation de l'approbateur et traitement Worker. L'analytique reste agrégée et
  soumise au seuil de confidentialité; la messagerie demeure limitée aux
  participants autorisés des objets métier.
- Aucun test E2E ou global supplémentaire n'est exécuté dans ce lot et aucune
  production n'est modifiée.

## Checkpoint Paiements CMI/PayPal 2026-09-12

- Les migrations `20260912014300`, `20260912014400` et `20260912014500` sont
  confirmées appliquées sur Supabase Matricia development. Elles couvrent les
  intentions et webhooks CMI/PayPal, le journal financier équilibré, la correction
  d'ambiguïté du numéro de cycle et l'ACL de lecture minimale du `service_role`.
- Le test SQL/RLS `0097_real_payment_gateways.test.sql` est PASS avec 20 assertions.
  Le harness PostgreSQL confirme également les 4 scénarios de concurrence : Outbox,
  journal financier idempotent, crédits idempotents et chaîne d'audit concurrente.
- Les parcours CMI et PayPal sont raccordés à l'interface réelle. CMI utilise une
  confirmation POST signée; PayPal enchaîne approbation, capture serveur idempotente
  puis activation exclusivement après webhook `PAYMENT.CAPTURE.COMPLETED` vérifié.
  Aucun secret n'est exposé au navigateur ou aux logs.
- La migration `20260912013800_admin_operations_projection.sql` est désormais
  préparée localement pour réaudit, mais n'est pas appliquée sur l'environnement
  development ni sur aucun environnement distant.
- Aucun environnement, secret ou donnée de production n'a été lu ou modifié dans
  ce checkpoint.

## Checkpoint de clôture technique V1 — 2026-09-12

- Supabase development est synchronisé jusqu'à la migration additive `20260912015500`;
  le dry-run final retourne `upToDate=true`. Les migrations 153 à 155 refusent les
  rôles plateforme révoqués, imposent AAL2 pour la projection Operations et calculent
  l'éligibilité RFQ depuis les preuves Provider versionnées, temporelles et propres au
  service. Aucun environnement de production n'a été modifié.
- Gate PostgreSQL/RLS globale : 100 fichiers, 2 507 assertions et 4 scénarios de
  concurrence PASS. Le réaudit sécurité indépendant final ne relève aucun P0/P1/P2.
- Gates monorepo : lint PASS, TypeScript strict PASS, tests unitaires/intégration PASS
  (Web 115 fichiers/436 tests; Worker 11 fichiers/54 tests), build Next.js/Worker PASS,
  `release:validate` structurel PASS et aucun marqueur incomplet détecté.
- E2E additionnels V1 : 20/20 PASS, zéro skip, avec fixtures development neutralisées;
  FR/AR, RTL/LTR, 360 px et desktop, axe WCAG A/AA, clavier/focus, reflow, refus anon et
  séparation Client/Sous-traitant/Franchisé. Les crashes Litiges et Notifications
  découverts pendant ces E2E ont été corrigés sans élargir les droits RLS.
- Command Center localise désormais les codes métier en FR/AR, priorise la file du jour
  et conserve la revue humaine. Diagnostics raccorde Assistance et Évolution sans copie
  métier hardcodée. Le module de paiement se construit sous Turbopack avec ses imports
  TypeScript résolus depuis les sources.
- Limites de déclaration : les gates techniques de ce checkpoint sont vertes, mais la
  matrice atomique reste honnêtement à 1 `PROVEN` et 67 `PARTIAL`; le registre formel
  `REQUIREMENTS_COVERAGE.md` reste à 0/76 `VERIFIED` et P01 demeure ouverte jusqu'aux
  contrats atomiques, preuves et visas indépendants exhaustifs. Ce checkpoint ne
  revendique donc pas une V1 Gold Master terminée à 100 %.
- Risques externes restant à fermer avant release staging signée : replay vierge CI
  actuellement empêché par le runner GitHub/facturation, ClamAV réel en staging, audit
  manuel lecteur d'écran, déclencheur périodique service-role du scheduler et preuves
  atomiques/signoffs des exigences restantes. Aucun déploiement production n'est autorisé.

## Checkpoint d'intégration final — 2026-09-12

- Portfolio Client : commit `b91de14`, 468/468 tests Web et P22 4/4. Actions
  universelles : 7/7. Questionnaires/Diagnostics : 4/4.
- Provider Quotes : 21 tests PASS; devise persistée, sélection multi-organisation
  explicite et fiscalité autoritative. La migration additive
  `20260912015600_quote_tax_authority_hardening.sql` est appliquée uniquement sur
  Supabase development. Le visa indépendant de la migration 156 est PASS sans
  finding P0/P1/P2; l'autorité runtime est prouvée par 19/19 assertions incluant
  les appels directs au RPC public sous rôle authentifié.
- Gate DB globale : 101 fichiers, 2 526 assertions et 4 scénarios de concurrence
  PASS. E2E critiques : 20/20 PASS; le runner isole, protège et nettoie ses états
  authentifiés.
- Typecheck et lint Web PASS. Le dry-run Supabase final retourne
  `upToDate=true`. Le lint DB global ne remonte pour la migration 156 aucune
  nouvelle anomalie; ses alertes restantes sont des dettes historiques hors 156.
- Aucun environnement de production n'a été modifié. La couverture atomique reste
  honnêtement à 1 `PROVEN` et 67 `PARTIAL`; ce checkpoint ne revendique pas une
  V1 terminée à 100 %.

## Checkpoint final de vérification V1 — 2026-09-13

- Les lots consolidés correspondent aux commits `b9d8e69`, `7ba354b`, `59e7491`
  et `d6c6cd5`. Les Actions universelles sont PASS sur 8/8 parcours E2E et le lot
  Provider Quotes P23 est PASS sur 4/4 parcours FR/AR, 360 px et desktop.
- La migration additive
  `20260912015700_provider_quote_exact_amount_projection.sql` projette les montants
  `bigint` en `TEXT` sans conversion flottante. Elle est appliquée uniquement sur
  Supabase development; le dry-run lié final retourne `upToDate=true` sans migration,
  seed ni rôle en attente. Le test DB `0102` est PASS sur 9/9 assertions et les 4
  scénarios de concurrence sont PASS.
- Gate global consolidé : Web 126 fichiers/480 tests PASS; Worker 11 fichiers/54
  tests PASS; lint, TypeScript strict, build, `release:validate`,
  `traceability:validate`, `spec:validate` et `git diff --check` PASS.
- Le P1 qui masquait la soumission d'un devis `DRAFT`/`REVISED` lorsque sa règle
  fiscale historique n'était plus active est fermé et audité sans finding P0/P1/P2.
  La création d'une nouvelle révision reste fail-closed sans règle fiscale active.
- La couverture formelle reste honnêtement à 1/76 exigences `VERIFIED` et 1/68
  fonctions MAT prouvées. Ce checkpoint confirme les gates exécutés, mais ne
  revendique pas une V1 Gold Master terminée à 100 %.
- Aucun environnement, secret ou donnée de production n'a été lu ou modifié; aucun
  déploiement production n'est autorisé par ce checkpoint.

## Checkpoint V4.1 incremental upgrade - 2026-09-13

- Baseline V4 preserved on branch `upgrade/v4.1`; implementation used only additive
  migrations 16300 through 17000 plus corrective 16901. Supabase development is
  synchronized and the final linked dry-run returns `upToDate=true`.
- P0: cash flows A/B/C, electronic signature, privacy/CNDP, procurement/AP, AI FinOps,
  actual Box margins, bank-account antifraud and Matricia own payments are implemented.
- P1: treasury, suppliers, third parties, contract lifecycle, probative communications,
  dispute governance, security/resilience, restore evidence, jobs/DLQ, organization exit,
  catalogue findings, franchise controls, marketing safety and Admin V4.1 are implemented.
- Gates: DB/RLS 116 files and 2915 assertions PASS; 4 concurrency scenarios PASS;
  Web 128 files/489 tests PASS; Worker 11 files/54 tests PASS; 20/20 V4.1 E2E PASS;
  lint, strict TypeScript, build and structural validators PASS.
- Next.js is 16.3.3; the final production dependency audit reports no known
  vulnerabilities. `.env.local` remains ignored and untracked.
- Technical development/staging status is GREEN. Catalogue human review, CNDP/legal
  formalities, real provider certification, production restore/security drills and
  production authorization remain `REQUIRED_NOT_COMPLETED`. No production change occurred.

## Checkpoint V4.1 admin-managed external validation - 2026-09-13

- Migration additive `20260913017100_v41_admin_external_validations.sql` appliquée sur
  Supabase development/staging; dry-run final `upToDate=true`.
- Le tableau de bord Admin V4.1 permet désormais la saisie et la validation des neuf
  familles de preuves externes : CNDP, signature, trois revues catalogue, restauration,
  test d'intrusion et autorisation Production.
- Commandes AAL2 idempotentes, validation à quatre yeux, concurrence optimiste,
  RLS restrictive, preuves/décisions immuables, audit et Event Outbox sont actifs.
- Gates : DB/RLS 117 fichiers et 2931 assertions PASS; 4 scénarios de concurrence
  PASS; Web 128 fichiers/490 tests PASS; lint, TypeScript strict et build PASS;
  E2E V4.1 21 scénarios sur desktop et 360 px, soit 42/42 PASS.
- Les preuves restent non approuvées tant qu'elles ne sont pas réellement saisies et
  validées par deux administrateurs distincts. Aucun déploiement Production n'a eu lieu.

## Checkpoint MAT-FUNC-026 — activation complète des avenants — 2026-09-13

- Migrations additives `20260913017200` et corrective de compatibilité `17201`
  appliquées uniquement sur Supabase development/staging; dry-run final
  `upToDate=true`.
- Un avenant passe désormais de DRAFT à PENDING_SIGNATURE, exige les signatures AAL2
  distinctes Client et Sous-traitant, puis crée une nouvelle version contractuelle
  immutable. Parties, clauses et items sont snapshotés; les deltas ADD/REPLACE/REMOVE
  sont appliqués sans modifier l'historique; la mission active est rattachée à la
  nouvelle version.
- Interfaces FR/AR et responsive ajoutées aux espaces Client et Sous-traitant.
  Mutations idempotentes, RLS restrictive, concurrence, audit et Event Outbox actifs.
- Gates : DB/RLS 118 fichiers, 2946 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict, build et absence de placeholders PASS.
- Aucun environnement de production n'a été modifié. Prochain lot : coffre documentaire
  transversal et réutilisation contrôlée conformité/RFQ/contrat/mission.

## Checkpoint MAT-FUNC-012/021/025 — coffre documentaire transversal — 2026-09-13

- Migration additive `20260913017300_secure_client_document_reuse.sql` appliquée
  uniquement sur Supabase development/staging; dry-run final `upToDate=true`.
- Les documents Client vérifiés, scannés CLEAN et non expirés peuvent être liés
  sans copie binaire à une demande, une version contractuelle ou une mission de la
  même organisation. Les liaisons et révocations sont immuables, AAL2,
  idempotentes, auditées et publiées via Event Outbox.
- L'interface Client FR/AR `/client/documents` permet de créer et révoquer les
  liaisons; elle est responsive, accessible au clavier et exposée uniquement aux
  rôles Client Owner/Admin.
- Gates : DB/RLS 119 fichiers, 2 961 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict, build et synchronisation Supabase PASS.
- Aucun environnement de production n'a été modifié. Prochain lot : audit ciblé
  puis fermeture des écarts UI encore réels dans CRM, récompenses, IA et règles.

## Checkpoint Admin incitations — récompenses, badges et parrainage — 2026-09-13

- Migration additive `20260913017400_admin_badge_policy_versions.sql` appliquée
  uniquement sur Supabase development/staging. Les politiques de badges sont
  désormais créées en versions immuables avec AAL2, idempotence, audit et Outbox.
- La route FR/AR `/administration/incitations` administre les versions de règles
  de récompense/parrainage, les politiques de badges, les évaluations sur snapshots
  de réputation et les décisions humaines publication/révocation.
- Les crédits restent attribués exclusivement par le moteur et le ledger immuable;
  l'interface ne modifie aucun solde directement.
- Gates : DB/RLS 120 fichiers, 2 968 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict et build PASS. Aucun environnement de production modifié.

## Checkpoint clonage gouverné avec provenance — 2026-09-13

- Migration additive `20260913017500_content_clone_provenance.sql` appliquée
  uniquement sur Supabase development/staging; historique synchronisé.
- L'administration peut cloner questionnaires, ensembles de clauses et checklists
  de service sans altérer les sources. Chaque clone conserve une provenance immutable,
  crée une nouvelle identité/version brouillon et émet audit plus Event Outbox.
- L'interface FR/AR `/administration/clonage` expose les trois opérations avec motif,
  idempotence, autorisation restrictive et validation des identifiants.
- Gates : DB/RLS 121 fichiers, 2 979 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict et build PASS. Aucun environnement de production modifié.

## Checkpoint autosauvegarde questionnaire résiliente — 2026-09-13

- L'autosauvegarde Client conserve le délai de 800 ms, renouvelle les identités de
  commande et synchronise désormais les versions optimistes renvoyées par le serveur.
- Une saisie effectuée hors ligne reste dans l'onglet, passe en file d'attente et est
  renvoyée automatiquement au retour du réseau; un conflit propose explicitement de
  recharger la version serveur sans écrasement silencieux.
- Messages FR/AR, états accessibles et commandes tactiles 44 px minimum sont fournis.
- Gates : Web 128 fichiers/491 tests PASS; lint, TypeScript strict et build PASS.

## Checkpoint centres de coûts transversaux — 2026-09-13

- Migration additive `20260913017600_typed_cost_center_financial_links.sql`
  appliquée uniquement sur Supabase development/staging.
- Les allocations relient désormais un centre de coûts aux projets, tâches, contrats,
  missions, jalons, factures Provider côté Client, documents et RFQ. Chaque référence
  est validée dans le tenant; une facture ne peut pas être surallouée.
- L'interface Portefeuille FR/AR expose le type et l'identifiant de la source; les
  montants restent en unités mineures côté serveur, avec idempotence, audit et Outbox.
- Gates : DB/RLS 122 fichiers, 2 989 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict et build PASS. Aucun environnement de production modifié.

## Checkpoint moteur transversal anti-abus — 2026-09-13

- Migration additive `20260913017700_transversal_abuse_detection.sql` appliquée
  uniquement sur Supabase development/staging.
- Les règles anti-abus sont versionnées par type d'événement; les signaux ne conservent
  que des empreintes et un contexte expurgé. Le moteur applique fenêtre, vélocité et
  seuils ALLOW/REVIEW/BLOCK puis ouvre une file de revue humaine.
- L'interface FR/AR `/administration/anti-abus` permet de créer les versions et de
  statuer avec AAL2, preuve, RLS restrictive, historique immutable, audit et Outbox.
- Le Command Center existant couvre déjà les approbations multi-objets transversales
  avec ressource typée, double contrôle et nombre d'approbations configurable.
- Gates : DB/RLS 123 fichiers, 3 001 assertions et 4 scénarios de concurrence PASS;
  lint, TypeScript strict et build PASS. Aucun environnement de production modifié.

## Checkpoint préremplissage transversal et fraîcheur — 2026-09-13

- Migration additive `20260913017800_versioned_prefill_freshness.sql` appliquée
  uniquement sur Supabase development/staging.
- Cinq politiques de fraîcheur versionnées couvrent profil, organisation, site,
  réponse antérieure et document. Les faits sont versionnés et immutables.
- Les questionnaires proposent désormais les valeurs fraîches compatibles par
  `data_key`, tenant, acteur et sensibilité; toute suggestion doit être confirmée
  avant d'être persistée ou comptée comme réponse.
- Gates ciblés : 10 assertions SQL/RLS PASS; Web 128 fichiers/491 tests PASS;
  lint, TypeScript strict et build PASS. Aucun environnement de production modifié.

## Checkpoint livrables scannés et Marketing Autopilot exécutable — 2026-09-13

- Les migrations additives `20260913017900_delivery_proof_trusted_scan.sql` et
  `20260913018000_marketing_publication_worker.sql` sont appliquées uniquement
  sur Supabase development/staging.
- Les preuves de livrable conservent désormais leur empreinte SHA-256 réelle,
  reçoivent un verdict immuable d'un scanner `service_role`, et aucun livrable
  ne peut être accepté ou rejeté tant que les preuves de sa version courante ne
  sont pas toutes `CLEAN`. L'UI Client expose ce blocage en FR/AR.
- Le Marketing Autopilot dispose d'un worker protégé par `CRON_SECRET`, d'un
  mode sandbox sans réseau et d'adaptateurs réels LinkedIn et Meta
  Facebook/Instagram/Reels. Les credentials ne transitent que par une référence
  `env://`; consentement, autorisation de marque, kill-switch et contenu sont
  revérifiés au claim puis avant journalisation. Retry borné, idempotence, audit
  et Event Outbox sont actifs.
- Gates : DB/RLS 126 fichiers, 3 030 assertions et 4 scénarios de concurrence
  PASS; monorepo 129 fichiers Web/495 tests, 11 fichiers Worker/54 tests et
  packages partagés PASS; lint, TypeScript strict et builds PASS; aucun
  placeholder applicatif; catalogue 10 bibliothèques/200 services/6 000
  questions valide.
- E2E authentifiés development : V1 critique 20 PASS, questionnaires/diagnostics
  4 PASS, portefeuille 4 PASS, Action Center 8 PASS, devis Provider 4 PASS,
  catalogue 5 PASS avec 1 scénario explicitement ignoré par le runner. Tous les
  jeux de données temporaires ont été neutralisés.
- Aucun environnement de production n'a été modifié. Les activations live des
  providers sociaux restent désactivées jusqu'à configuration des credentials
  acquis et autorisation opérationnelle explicite.

## Checkpoint calendrier Marketing et intégrité sandbox — 2026-09-13

- Les migrations additives `20260913018100_marketing_calendar_scheduler.sql` et
  `20260913018200_marketing_scheduling_sandbox_integrity.sql` sont appliquées
  uniquement sur Supabase development; le dry-run final confirme la cible à jour.
- Le calendrier M+1 est généré de façon idempotente le 25 pour les règles actives.
  En mode AUTOPILOT, seuls les contenus approuvés, non expirés, consentis et sans
  exception bloquante sont planifiés; ASSISTED reste soumis à validation humaine.
- La planification manuelle rattache chaque publication au calendrier versionné
  obligatoire et sérialise la limite hebdomadaire. Le mode sandbox produit
  `SANDBOXED` et ne crée plus aucune preuve de publication réelle.
- Les endpoints cron protégés par `CRON_SECRET` acceptent GET/POST; la
  configuration Vercel programme le calendrier mensuel et le worker de publication.
- Gates : DB/RLS 128 fichiers, 3 051 assertions et 4 scénarios de concurrence PASS;
  Web 130 fichiers/502 tests PASS; lint, TypeScript strict et build PASS.
  Aucun environnement de production n'a été modifié.

## Checkpoint gouvernance Marketing et reprise worker — 2026-09-13

- Les migrations additives `20260913018300_marketing_schedule_rule_commands.sql`
  et `20260913018400_marketing_worker_lease_policy_hardening.sql` sont appliquées
  uniquement sur Supabase development; replay local complet 001–184 PASS.
- Les règles de calendrier sont versionnées, validées par timezone IANA et créneaux
  stricts, activées par verrou optimiste et protégées par idempotence, audit et Outbox.
  L'approbation globale ASSISTED est réservée au rôle `CLIENT_OWNER`.
- Le worker récupère les claims expirés avec une lease de cinq minutes. Les blocages
  de politique créent une exception dédupliquée, un audit et un événement Outbox.
  Les dix familles de conformité sont obligatoires et les scopes sociaux sont bornés
  au provider et au canal avant toute publication.
- L'interface Marketing FR/AR RTL expose comptes sociaux, versions de règles,
  calendrier, publications et exceptions, avec création, activation et approbation
  globale branchées aux commandes serveur.
- Gates : DB/RLS 130 fichiers, 3 079 assertions et 4 scénarios de concurrence PASS;
  Web 130 fichiers/507 tests PASS; lint, TypeScript strict et build PASS.
  Aucun environnement de production n'a été modifié.

## Checkpoint intégrité at-most-once Marketing — 2026-09-13

- Migration additive `20260913018500_marketing_publication_attempt_integrity.sql`
  appliquée uniquement sur Supabase development; le dry-run final confirme la cible
  distante à jour.
- Chaque claim est lié à une lease et à une clé fournisseur SHA-256 unique par
  tentative. Les attempts sont immuables; les anciens RPC sans lease échouent fermés.
  Seul `PROVIDER_HTTP_429` autorise un retry borné avec une nouvelle clé. Toute
  réponse réseau, timeout ou 5xx ambiguë exige une réconciliation probante avant
  publication, échec ou remise en file.
- Les quotas sont sérialisés par organisation et provider. Les preuves de consentement,
  d'autorisation, de conformité, de contenu et de sécurité sont figées au claim.
  Timeout, quota, policy, pénurie calendrier et réconciliation sont audités et émis
  par Event Outbox; les workers exécutent les balayages timeout et pénurie.
- Gates : replay local migrations 001–185 PASS; DB/RLS 131 fichiers, 3 110 assertions
  et 4 scénarios de concurrence PASS; Web 132 fichiers/521 tests PASS; lint,
  TypeScript strict et build PASS; E2E authentifiés FR/AR à 360 px et desktop 24/24
  PASS avec fixtures development neutralisées. Audit indépendant : MERGEABLE,
  aucun P0/P1 bloquant dans ce périmètre.
- Aucun environnement de production n'a été modifié. La publication live reste
  désactivée jusqu'à l'injection KMS/Vault des credentials acquis et aux essais
  fournisseurs; le `container_id` Meta ambigu requiert une revue/réconciliation
  humaine et n'est jamais republié automatiquement.

## Checkpoint MARKETING-007 — tendances hebdomadaires — 2026-09-13

- Migration additive `20260913018600_marketing_weekly_trends.sql` appliquée
  uniquement sur Supabase development; le dry-run final confirme la cible à jour.
- L'agrégateur hebdomadaire calcule les volumes et croissances en anomalies
  distinctes, applique avant agrégation le consentement Marketing Analytics, les
  seuils de confidentialité et de croissance versionnés, puis crée les snapshots
  et suggestions sans exposer de PII.
- Le worker est protégé par `CRON_SECRET`, paginé à 500 groupes et reprend après
  interruption grâce à un checkpoint privé durable, un verrou advisory et un
  verrou de ligne. Les mutations sont idempotentes, auditées et émises via Outbox.
- Gates : DB/RLS 132 fichiers, 3 150 assertions et 4 scénarios de concurrence
  PASS; Web 133 fichiers/526 tests PASS; lint, TypeScript strict et build PASS. Réaudit indépendant :
  GO/MERGEABLE, 0 P0 et 0 P1. `MARKETING-007` reste `IN_PROGRESS` jusqu'à l'E2E
  authentifié et à la preuve d'exécution planifiée.
- L'audit atomique consolidé confirme honnêtement 1/76 exigence `VERIFIED`; les
  autres exigences disposent d'implémentations partielles mais attendent encore
  leur preuve atomique et leur visa indépendant. Aucun environnement de production
  n'a été modifié.

## Checkpoint V4.1 — compléments 187–192 — 2026-09-13

- Six migrations additives couvrent Marketing/CTA et approbations, preuves Client/
  Provider, notifications et schedulers, réputation/badges/checklists, ainsi que le
  centre financier/coûts/économies/ROI. Aucun reset ni changement production.
- Gates locales finales : Web 149 fichiers/621 tests PASS; TypeScript strict PASS;
  lint PASS; aucun marqueur incomplet. SQL 0133/0135 PASS (64 assertions), 0134
  PASS (61), 0136 PASS (33 + 4 concurrences) et 0137 PASS (64) sur bases fraîches.
- Le dry-run Supabase lié confirme uniquement les migrations 187–192 en attente.
  Leur application development a été refusée par le garde d'autorisation de l'hôte;
  elle reste donc à exécuter, suivie du SQL/RLS distant et des E2E authentifiés sans
  skip. Aucun statut global 100 % ou VERIFIED n'est revendiqué avant ces preuves.
