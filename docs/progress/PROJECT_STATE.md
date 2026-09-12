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
