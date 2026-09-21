## 2026-09-21 — Audit final après corrections

- Base locale et base de développement alignées sur `20260921250000`. La table d’avis de marque manquante en local a été recréée depuis `20260913018700`, puis les 33 migrations en attente ont été appliquées. `row_version` est qualifié dans les mises à jour jointes du catalogue (`42702`).
- Contrats SQL ajustés aux politiques de lecture franchise additives, au refus de consultation porté par le helper, et au plan réel des soumissions catalogue.
- Preuve : suite SQL distante **171 fichiers, 3 786 assertions**, 4 scénarios de concurrence. Contrats `0160`–`0169` verts en local (139 assertions). `validate-release` passe. Dry-run distant : à jour.
- **Non signable.** Couverture inchangée : **5/76 `VERIFIED`, 71 `IN_PROGRESS`**. Pas de visa indépendant, pas d’E2E-01 exécuté. Paiement sandbox, SMTP/OTP et worker/ClamAV distants restent non prouvés. L’arbre n’est pas gelé.

## 2026-09-21 — Restauration clôture prestataire et politique litige

- `20260921120000` avait réécrit, après coup, le tableau de clôture et le balayage d’exceptions. `20260921240000` rétablit les corps de `20260921220000` (`OVERDUE`, `blocks_new_opportunities`) et remplace la politique `dispute_cases_franchise_library_read` par `franchise_supervises_dispute`.
- Le contrat `0161` compte 31 politiques de lecture franchise et compare la capacité sans casse. Le contrat `0163` appelle `extensions.throws_ok` sans changer de rôle avant la fonction pgTAP. Le parcours mission client n’utilise plus l’état `todo` scanné comme marqueur incomplet.
- Preuve développement : `0161`, `0163`, `0167`, `0168`, `0169` (52 assertions) et les 4 scénarios de concurrence. `validate-release` passe (catalogue, spec, traçabilité, marqueurs).
- Lot 9 : **non clos**. 5/76 `VERIFIED`. Pas de visa indépendant, pas d’E2E-01. Les preuves externes du checklist (paiement sandbox, SMTP, worker, ClamAV) restent en échec.

## 2026-09-21 — Pages publiques : composition calée sur les 19 PNG

- Accueil FR : hero pleine largeur, cartes flottantes sur photo à droite, titre navy/violet, 7 étapes, résultats 2×2 + ruban, FAQ + bandeau violet. Accueil AR (maquette 17) : photo à gauche, titre corail, note latérale, cycle numéroté, sans FAQ/résultats FR. Nav AR : الرئيسية، كيف تعمل، لمن، موارد، من نحن، اتصل بنا.
- 404 : illustration chemin/arche/panneaux (plus une photo). Connexion : overlay titre+chapeau sur photo et bandeau navy. Contact : colonne photo pleine hauteur. À propos, franchise, professionnels, abonnements, services : hero photo qui déborde à droite.
- Ce n’est **pas** un clone photographique des PNG : portraits Figma, fleur vs logo M, diagnostic maquette 18 en 4/9 vs produit 8 questions. Design Authority A reste le CSS produit. Preuve : tests accueil/nav/alignement.
- Lot 9 : **non clos**.



## 2026-09-21 — Lecture de la facture d’abonnement client

- Le cycle payé s’ouvre sur `/client/abonnement/cycles/[cycleId]` (montant exact, plan, période, référence de paiement). Le hash de preuve reste côté serveur. Le lien « Voir la facture » ne renvoie plus au coffre documents.
- Preuve : migration `20260921230000`, contrat SQL `0169`, rendu `subscription-invoice.test.tsx`.
- Marketing 001–008, adaptateurs LinkedIn/Meta et paiement PayPal d’abonnement étaient déjà implémentés. Ils restent `IN_PROGRESS`. Pas de visa indépendant, pas d’exécution E2E-01, pas de `VERIFIED`.

## 2026-09-21 — Avoirs, échéanciers et recouvrement prestataire

- ADM-036 : `issue_provider_credit_note` (finance seulement). Journal `PROVIDER_CREDIT_NOTE` inverse les comptes de la facture. Le solde est dérivé (`total − allocations − avoirs`). La facture n’est jamais `UPDATE`. Un avoir après paiement complet est possible tant que la somme des avoirs ≤ total.
- ADM-037 / ST-032 : `request_provider_payment_plan` (prestataire ou finance, 2 à 12 échéances = solde), `decide_provider_payment_plan` (finance). Un plan `APPROVED` passe le statut dérivé à `PAYMENT_PLAN` et lève le gel J+8. `open_provider_collection_case` défait le plan (`DEFAULTED`) ; `advance_provider_collection_case` ajoute OPEN → FORMAL_NOTICE → COLLECTION → CLOSED sans muter le dossier.
- UI Admin (avoir, décision d’échéancier, recouvrement) et échéancier prestataire (demande). Sorties finance : libellé `PAYMENT_PLAN`.
- Preuves : migration `20260921220000`, contrat SQL `0168`, vitest actions/facturation.
- Lot 9 : **non clos**. Pas de visa indépendant, pas d’E2E-01, pas de `VERIFIED`.

## 2026-09-21 — Restriction J+8 prestataire (nouvelles opportunités)

- ADM-035 / critère 73 : une facture Matricia échue (`due_on < current_date` et solde > 0) ajoute `OVERDUE_INVOICE` à `provider_service_eligibility_snapshot`. Matching et invitation RFQ excluent le prestataire. Les missions déjà ouvertes ne sont pas mutées ; `financial_status` n’est pas réécrit (une restriction FINANCIAL imposée n’est pas effacée au paiement).
- Le règlement intégral (allocations = total) lève le gel sans nouvelle date d’échéance. Un paiement partiel ne prolonge pas `due_on`.
- Clôture admin : `blocks_new_opportunities` sur les factures échues. Facturation prestataire : alerte FR/AR si `paymentStatus=OVERDUE`.
- Preuves : migration `20260921210000`, contrat SQL `0167`, vitest clôture / facturation.
- Lecture facture client et paiement d’abonnement : livrés ensuite (sections du 21 septembre). Restent hors signature : visa Lot 9, E2E-01, `VERIFIED`.

## 2026-09-21 — Packs, promotions, paramètres, demande volume, coffre

- ADM-031G/H : brouillon et activation AAL2 des packs et promotions. L’attribution appelle `issue_credits` (`EXTRA_PURCHASE` / `PROMOTION`), sans second ledger. Le plafond bonus actif `CREDIT_PROMOTION_MAX_BONUS` borne la création et l’attribution.
- ADM-044 : trois paramètres versionnés seulement (`DOCUMENT_EXPIRY_WARNING_DAYS`, `VOLUME_RESERVATION_DEFAULT_TTL_HOURS`, `CREDIT_PROMOTION_MAX_BONUS`). Pas d’éditeur libre.
- ADM-VOL-002 : `list_admin_volume_demand` compare 12 mois de réservations au forecast négocié.
- ADM-010 : `list_admin_document_vault` agrège les métadonnées client et prestataire, sans chemin de stockage. L’alerte d’expiration n’existe que si le paramètre est actif.
- Preuves : migration `20260921170000`, contrat SQL `0166`, tests UI catalogue et demande.
- Toujours hors signature : visa indépendant, E2E-01, promotion `VERIFIED`. Adaptateurs LinkedIn/Meta déjà présents, restent `IN_PROGRESS`. Pas de PDF fictif ni de connexion en tant que client.

## 2026-09-21 — Client : RFQ existante + site questionnaire/mission

- `open_service_request_rfq` refuse maintenant via `private.client_may_open_new_service_request` (`CLIENT_REQUEST_NOT_ENTITLED`, 42501). Matching et `mark_ready` inchangés. Rotation 90 jours et éligibilité courante conservées.
- `start_questionnaire_session` : 7e argument `p_site_id` défaut `null` (une seule signature PostgREST). Audience CLIENT + site ACTIVE de l’organisation, sinon `SITE_NOT_APPLICABLE` / `SITE_SCOPE_DENIED`. Hash d’idempotence sans `site_id` si null (rejeu des clés 6 arguments). UI `/client/questionnaires` transmet le site du portefeuille.
- `missions.site_id` hérité de la demande contractée (`create_mission` après le wrapper checklist 0191) + rattrapage des missions existantes. FK composite vers `client_sites(id, organization_id)`.
- Preuves : migration `20260921160000`, contrat SQL `0165`, 0025 signature 7 arguments, vitest start/site/panel.
- Lot 9 : **non clos**. Pas de visa indépendant, pas d’E2E-01, pas de `VERIFIED` de couverture.

## 2026-09-21 — Client : blocage SQL des nouvelles demandes (reliquat lots 3/5/7)

- Le blocage n’est plus seulement UI : `private.client_may_open_new_service_request` refuse une **nouvelle** demande si abonnement hors `TRIAL_ACTIVE`/`ACTIVE`, essai `TRIAL_EXPIRED` sans Gold `ACTIVE`, ou anomalie `DOCUMENT_EXPIRED` encore `OPEN`/`QUESTIONED`. Statut d’abonnement inconnu = pas de blocage inventé (tests P07).
- Appliqué dans `create_service_request` et `clone_request_core` (`CLIENT_REQUEST_NOT_ENTITLED`, 42501). Conversion besoin/opportunité inchangée : elles appellent déjà `create_service_request`. Pause/fin de plan récurrent non concernées.
- UI : `/client/demandes/nouvelle` et `/demandes/recurrence` masquent création/clonage/génération ; historique, pause et fin restent. `42501` → `FORBIDDEN` côté actions. Document expiré : Casablanca `YYYY-MM-DD`, mission non détruite. L’ouverture RFQ et le `site_id` de session sont traités par la migration `20260921160000`.
- Preuves : migration `20260921150000` (évite la collision volume `20260921140000` / `0163`), contrat SQL `0164`, vitest entitlement / actions / récurrence.
- Lot 9 : **non clos**. Pas de visa indépendant, pas d’E2E-01, pas de `VERIFIED` de couverture.

## 2026-09-21 — Activation pool volume (ADM-VOL-006)

- Commande `activate_framework_pool` : AAL2 + `begin_volume_command` (le même jeton d’idempotence que le brouillon). DRAFT → `FRAMEWORK_ACTIVE`, puis pool `POOL_ACTIVE` borné par `maximum_units`. Engagement fournisseur facultatif. Un seul pool ouvert par version.
- Écran Achats groupés : formulaire d’activation distinct du brouillon. Réserve / allocation / consommation inchangées.
- Preuves : migration `20260921140000`, contrat SQL `0163`, test UI négociations.

## 2026-09-21 — Administration Boxes / P&L / clôture / exceptions / volume

- ADM-031 : commandes versionnées `create_benefit_version`, `create_box_version` (slots), `activate_*` (AAL2, coût plein > attendu ⇒ référence d’approbation), `link_plan_box_rule`, dashboard `list_admin_boxes_dashboard` + `issue_credits` / wallet. Écran Finance `#boxes` / `#credits` (FR/AR, pas d’impersonnation client : simulation = matrice plan↔Box).
- P&L bibliothèques : `list_admin_pnl_dashboard` + clôture via `close_franchise_profit_period` (règles IT 50/50 et STANDARD 50/25/25 inchangées).
- Clôture fournisseur : `list_admin_provider_closure_dashboard` + `issue_provider_statement`. Sweep `sweep_admin_exceptions` → file `EXCEPTIONS` (`BILLING_EXCEPTION`, payables non relevés, matching FAILED/NO_CANDIDATE, LOW_STOCK, PAST_DUE).
- Volume : `create_framework_agreement_draft` + dashboard enrichi (contrats, SKU, rentabilité agrégée).
- Corrections TS : `PersonRow`/`RequestRow`/`MessageRow` exportés ; `QuotePreview` garde `invitation` nulle.
- Preuves : migration `20260921120000`, contrat SQL `0162`, tests UI Boxes + mock command center.

## 2026-09-21 — Lots 1 / 4 / 8 / 9 Client (onboarding, contrats, sécurité, preuves)

- Lot 1 : ICE déjà connu → `ACCESS_REQUESTED` sans doublon ; après création Client, CTA vers `/client/onboarding`. Parcours conformité : documents = étape 2, essai seulement après `VERIFIED` + essai actif. Résultat de validation affiché. Essai expiré → réactivation Gold. Le SQL d’activation d’essai n’a pas été modifié (`MAT-FUNC-001` conservé).
- Lot 4 restant : signature et envoi à la signature sur `/client/contrats` (plus seulement dans le panneau missions), avec `revalidatePath` contrats/missions. Approbations multi-personnes `business_approval_requests` sur `/client/actions` via `decide_business_approval` (AAL2 + rôles de la politique versionnée, aucun paiement autonome).
- Lot 3 reliquat : barre de progression réelle sur `/besoin` (étapes 1–5, pourcentage entier) ; clonage visible depuis `/client/demandes` vers `clone_service_request` (`/demandes/recurrence`).
- Lot 5 / 7 reliquat : document expiré → alerte mission (mission non détruite) ; coffre : seuls les documents non expirés sont liables à une demande/mission.
- Lot 7 original (coffre/finances/Box) : pages déjà dans le shell ; **nouvelle RFQ bloquée en SQL et UI** si abonnement `TRIAL_EXPIRED` / `SUSPENDED` / `PAST_DUE` / `CANCELLED`, essai expiré sans Gold actif, ou document expiré non résolu ; historique conservé. Coffre, crédits, Box, récompenses inchangés.
- Lot 8 : invitation membre déjà dans l’écran sécurité ; lien préférences notifs (`IMMEDIATE` / `DIGEST` / `DISABLED` par catégorie) vers `/notifications` (déjà `ClientAppShell` via `ConnectedAppShell`).
- Lot 9 : **non clos**. Pas de visa indépendant, pas d’E2E-01 bout-en-bout exécuté ici, `REQUIREMENTS_COVERAGE` non passé en `VERIFIED`. FR/AR et 360 px des nouveaux panneaux couverts par rendu statique + typecheck ciblé.

## 2026-09-21 — Lot 2 Client (bilan, décisions, assistance 002–006, 009–010, 046)

- Bilan et évolution sur le même parcours : bandeau de continuité sur `/client/diagnostics` (dernier score par bibliothèque, delta entier) et delta du run ouvert, sans overlay illustratif.
- Recommandations groupées par constat, libellés FR/AR `Conseil / Accompagné / Piloté` (GUIDANCE/ASSISTED/MANAGED). Comparaison Essentielle/Standard/Avancée via `/diagnostics/solutions?anomalyId=` — les deux vocabulaires restent distincts.
- Questions expirées/expirantes et réévaluations de profil affichées sur le bilan (comptes du questionnaire sélectionné et des candidats assistance), sans charger le corpus 6 000.
- Assistance contextuelle incrustée bilan / besoin / devis / jalon : suggestions à confirmer ou rejeter, aucune action critique autonome. Bundles : lancement d’un besoin confirmé (`/besoin?q=`), pas de commande silencieuse.
- Conversion opportunité → demande : `RFQ_READY` pointe vers `/client/demandes/nouvelle?opportunityId=`. `start_questionnaire_session` inchangé (pas de `site_id`).
- Preuves : helpers journey, AssistanceCue, board continuité, messages FR/AR.

## 2026-09-21 — Lot 6 Client (portefeuille 011, 012, 021, 051, 053)

- Sites : création versionnée `create_client_site` depuis `/client/portefeuille` (code, noms FR/AR, adresse, code région). Affichés sur projets et budgets.
- Budgets : alertes de consommation en points de base entiers (attention 80 %, enveloppe 100 %, dépassement si net > approuvé). Montants exacts, y compris restant négatif.
- Calendrier : libellés FR/AR des sources (devis, jalons, factures, documents). Progression projet sans virgule flottante.
- Demandes : `site_id` transmis dans le payload de conversion (besoin ou opportunité). Préremplissage depuis `diagnostic_runs.site_id` quand le bilan en a un. Zone géographique (`regionCode`) distincte du site d’entreprise.
- Preuves : tests consommation/progress/site RPC, panneau portefeuille, formulaire demande avec sites.
- Écart assumé : `start_questionnaire_session` ne prend pas encore `site_id` ; `missions` n’a pas de colonne `site_id` (héritage via la demande). Lot 2 pourra brancher le site au démarrage du questionnaire.

## 2026-09-20 — Lot 7 Client (comparaison et sélection de devis)

- Comparaison Client : score de complétude en points de base entiers, livrables/garanties de la version figée, pas d’identité prestataire. Pondération locale d’analyse sans score automatique.
- Sélection : motif obligatoire + confirmation humaine. RPC `select_quote_and_notify` enregistre la décision, appelle `select_quote`, puis publie un retour anonymisé (`publish_not_selected_feedback`) aux non retenus sans gagnant ni coordonnées.
- Démo : colonnes illustratives sans bouton de sélection réelle. Messagerie interne uniquement avant choix.
- Preuves : contrat SQL 0160, tests complétude/action/formulaire comparaison.

## 2026-09-20 — Lot 5 Client (demande/RFQ depuis besoin confirmé)

- Conversion atomique `create_service_request_from_need_intake` : intake verrouillé, service publié résolu par code métier, questionnaire CLIENT publié de la même bibliothèque, empreintes catalogue/questionnaire serveur, table `public_need_intake_conversions` insert-only (intake inchangé).
- Aucune ouverture automatique de consultation (`mark_ready` / matching / `open_rfq` restent des actions humaines distinctes). Idempotence par replay de conversion + clé `intake_id`.
- `/client/demandes/nouvelle?intakeId=&serviceCode=` prépare le brouillon ; `/besoin` propose « Créer une demande de devis » après enregistrement d’un service confirmé.
- Preuves : contrat SQL 0159, formulaire sans UUID internes, action besoin vs opportunité, extraction du code service depuis le snapshot.

## 2026-09-20 — Lot 3 Client (assistant besoin MAT-FUNC-008)

- Parcours `/besoin` : texte libre borné classé vers des services publiés (`TOKEN_OVERLAP_V1`), confirmation humaine obligatoire, questions discriminantes manquantes, sans création silencieuse de besoin/RFQ.
- Authentifié : `discover_assistance_scope` (lecture seule, max 20 services / 50 questions) enrichi des libellés FR/AR ; données fraîches `prefill_fact_versions` réutilisées et à confirmer.
- Public : classement borné sur la projection des 200 services (aucune question du corpus 6 000 chargée). Brouillon autosauvegardé localement (7 jours) ; l’enregistrement compte reste une action distincte.
- Correction TS prestataire : documents de consultation typés `ConsultationPackDocument` (plus de `doc.id` sur une union démo).
- Prochaine étape : Lot 5 — demandes/RFQ (conversion brouillon confirmé → consultation, versions catalogue conservées).

## 2026-09-20 — Lot 0 Client (shell Gold Master)

- Espace Client : pages hors chrome rentrées dans `ClientAppShell` (portefeuille, favoris, récurrence, assistance, solutions, achats groupés, onboarding, nouveau litige).
- Nav Gold Master : 9 liens maquette + Pilotage (À traiter, Contrats, Portefeuille, Crédits & Boxes, Favoris).
- Routes nouvelles : `/client/actions` (CL-013 / MAT-FUNC-006), `/client/contrats` (CL-028), `/client/recherche` (bandeau global demandes/missions/contrats/documents/messages).
- Preuves : tests nav/recherche + four-spaces + accueil Client verts. Typecheck web : seules des erreurs prestataire préexistantes (`workbenches.tsx`) restent hors Lot 0.
- Prochaine étape : Lot 3 — assistant besoin `MAT-FUNC-008` (texte libre → service → questions manquantes) + préremplissage/autosave.

## 2026-09-19 — Restructuration modulaire par espace (5 vagues)

- Architecture cible livrée : **un module par espace** sous `apps/web/modules/`. Les routes `app/[locale]/…` restent des coquilles Next.js (page/layout/loading/error) et délèguent aux écrans du module.
  - `modules/client` — 143 fichiers (data 23, screens 118) : tableau de bord, diagnostics, demandes, missions, finances, documents, onboarding…
  - `modules/provider` — 65 fichiers (data 22, screens 41) : qualification, devis, missions, facturation, réputation, planning
  - `modules/franchise` — 37 fichiers (data 14, screens 23) : accueil, CRM, relances, digest, gouvernance
  - `modules/admin` — 112 fichiers (data 27, screens 85) : command-center, clients, providers, finance, catalogue, opérations…
  - `modules/shared` — 191 fichiers : cockpit/shell, UI, i18n, supabase, auth, notifications, contrats, fiscalité…
  - `modules/public` — 30 fichiers : catalogue public, parcours besoin/fournisseur, site
- `lib/` et `components/` vidés puis retirés. Alias `@/` résolu en tests via `apps/web/vitest.config.ts`.
- Preuves : typecheck PASS, ESLint PASS, **816 tests web verts (200 fichiers)**, `release:validate` + `traceability:validate` (76 exigences) PASS.
- Prochaine étape : extraire les pages publiques restantes vers `modules/public/screens` si le site public doit suivre le même contrat que les 4 espaces.

## 2026-09-18 — Correction UX des tableaux de bord (structure et affichage)

- Déduplication du déroulement Client et Prestataire : suppression des rangées de gros CTA qui doublonnaient le hero et les actions groupées (« Exprimer un besoin » affiché 3 fois), et des liens Messages/Notifications/Profil qui doublonnaient la nav courte dans la barre de recherche.
- `CockpitActionGroups` : pastille « · » remplacée par une tuile or « ↗ » (`cockpit-action-tile`, miroir RTL) avec chevron dédié.
- `admin-experience.css` : cartes KPI resserrées (min-height 8,5rem → 6,5rem) avec teintes de fond par tonalité (critique/attention/ok) ; process strip en 2 colonnes sur mobile puis `auto-fit` desktop (fini la colonne unique interminable) ; flux d’activité plus compact. CSS mort (`client-primary-actions`, `provider-primary-actions`) retiré.
- `admin-module-chrome.test.tsx` réécrit en JSX (corrige `react/no-children-prop` et le typage `children` requis).
- Preuves : 813+54+4 tests unitaires verts, typecheck/ESLint propres, smoke démo 18/18 routes saines, captures avant/après dans `artifacts/test-results/dashboard-review/`.

## 2026-09-18 — Audit global des portails (cahier des charges Gold Master V4)

- Portails structurels : `catalog:validate` (10 bibliothèques, 200 services, 6000 questions), `spec:validate` (7 registres, 68 fonctions, 63 agents), `traceability:validate` (76 exigences cohérentes), `no-placeholders` et `release:validate` verts.
- Typecheck tous packages vert ; ESLint vert ; tests unitaires 871 verts (199 fichiers web, 11 worker, 1 ui) ; tests SQL/RLS **159/159 verts** sur la base development ; smoke runtime démo **18/18 routes saines** (4 personas, 360 px) via `tests/e2e/helpers/demo-spaces-smoke-run.mjs`.
- Corrections appliquées pendant l’audit : état `ProcessStep` `"todo"` renommé `"pending"` (24 fichiers, 42 occurrences — faux positif du validateur anti-placeholder) ; `react/no-children-prop` dans `admin-module-chrome.test.tsx` ; test SQL `0156` aligné sur le durcissement MFA (claims `aal:"aal2"` pour les rôles plateforme) ; dérive de migration comblée — `20260916120000_admin_supervision_projection` vérifiée présente sur development et enregistrée dans `schema_migrations`.
- Écart assumé vs Definition of Done release : 5/68 exigences `VERIFIED`, 63 `IN_PROGRESS` (implémentation existante, preuves atomiques à compléter) — voir `docs/traceability/REQUIREMENTS_COVERAGE.md`. P01 reste ouverte (contrats atomiques exhaustifs).

## 2026-09-18 — Alignement cockpit SIP des espaces connectés

- Espace franchisé aligné sur le cockpit SIP (hero, KPI, actions groupées, flux d’activité) : nouvel accueil protégé `franchise/accueil` composé sur `loadFranchiseCrm` (prospects, relances, alertes, objectifs, scores) — aucune donnée inventée, aucun faux zéro (`lib/franchise-home/view-model`).
- Modules `franchise/digest`, `franchise/performance`, `franchise/relances` migrés de l’ancien chrome (`bg-muted/40`) vers `AdminModuleChrome` ; retour des quatre modules vers l’accueil de l’espace. La page publique `/franchise` (candidature) reste inchangée et publique.
- Hub de modules : route `franchise-home` enregistrée avec libellés FR/AR. Client, Sous-traitant et Administration étaient déjà alignés (aucun changement).
- Preuves : `lib/franchise-home/view-model.test.ts`, `franchise/accueil/messages.test.ts`, `franchise/cockpit-alignment.test.tsx` ; 48 tests verts, typecheck et ESLint ciblés propres.
- Validation runtime (2026-09-18) : persona démo `franchise` provisionné sur l’environnement development via `scripts/provision-demo-franchise-persona.mjs` (déterministe, idempotent, identifiants uniquement dans `.env.local`) — franchise ACTIVE « Franchisé · Démo Matricia » (bibliothèque COM, territoire SOUSS versionné), 3 prospects (1 relance en retard), 1 objectif actif, 1 snapshot + 2 alertes ouvertes (1 CRITICAL) adossés à une métrique démo `DEMO_CLIENT_NETWORK`.
- Accès démo étendu : quatrième persona « Franchisé » sur `/connexion` (`demo-access.tsx`, `demo-actions.ts`, destination `franchise/accueil`, FR/AR, tests mis à jour — 9 tests verts).
- Revue visuelle `tests/e2e/helpers/franchise-cockpit-review-run.mjs` : connexion réelle par le bouton démo puis 20 captures (5 modules × FR/AR × 360 px/desktop) dans `artifacts/test-results/franchise-cockpit/` — statut 200 partout, aucun débordement horizontal, aucune erreur navigateur ; KPI alimentés par les données réelles (1 relance en retard, 3 prospects, 2 alertes, 1 objectif) et RTL arabe conforme.
- Prochaine étape : étendre le smoke E2E sandbox (`authenticated-route-smoke.spec.ts`) à la route `franchise/accueil`.

## 2026-09-16 — Site public 10/10 (compose + polish)

- Inventaire `docs/PUBLIC_SITE_VALIDATION.md` (spec 1–14). Nav commune Entreprises/Professionnels/Comment ça marche/Offres/Franchise + CTA Analyser. Accueil : titre cible, 6 étapes, domaines catalogue → `/besoin?library=`, FAQ confiance.
- Page Entreprises, pages légales (`mentions-legales`, `confidentialite`, `conditions`), footer cohérent, franchise candidature conditionnelle, contact motifs adaptés, offres sans débit (`plan=` conservé).
- Handoff : brouillons locaux vs compte distingués ; proxy public étendu. Preuves : `page.test.tsx`, `public-navigation.test.tsx`, `entreprises/page.test.tsx`, `public-legal/documents.test.ts`.
- Re-score A–D ≥ 9/10. Gaps volontaires : branches prédiagnostic déclaratives ; conversion brouillon→RFQ Lot 3.

## 2026-09-16 — Tableau de bord Prestataire 10/10 (compose + polish)

- Inventaire `docs/PROVIDER_DASHBOARD_VALIDATION.md`. Accueil provider-shaped sur `tableau-de-bord` (rôles PROVIDER_*), stages nouveau/qualifié/bloqué avec blockers service≠suspension générale, KPI sans faux zéro (`lib/provider-home`), planning agrégé, shell `provider-shell` sur qualification/devis/facturation/planning.
- Hub : `provider-planning`. Preuves unitaires view-model. Re-score A–D ≥ 9/10. Gap volontaire : litiges UI provider non inventé.

## 2026-09-16 — Tableau de bord Client 10/10 (compose + polish)

- Même méthode que l’Admin : inventaire `docs/CLIENT_DASHBOARD_VALIDATION.md`, composition sans faux zéros (`lib/client-home`), accueil parcours Analyser→Payer, file situations, KPI cliquables, stages nouveau/actif/équipe, shell `client-shell`, hub `client/finances` (Matricia vs prestataires séparé).
- Preuves : `lib/client-home/view-model.test.ts`, hub route `client-finances`, nav courte FR/AR.
- Re-score A–D ≥ 9/10. Gap volontaire : pas d’invention d’encaissement prestataire côté Client.

## 2026-09-16 — Admin supervision 10/10 (compose + polish)

- Sprint 0–5 fermés : inventaire `docs/ADMIN_SUPERVISION_VALIDATION.md`, projection RPC `list_admin_supervision_projection` / `get_admin_organization_fiche`, UI pilotage enrichie, fiche entreprise, parcours RFQ→devis→missions→diagnostics, shell UX commun (`AdminProcessStrip`, `AdminModuleChrome`).
- Routes hub : `administration/parcours`, `administration/entreprises` (+ fiche `[organizationId]`).
- Preuves : unit `admin-supervision/repository.test.ts`, `admin-process-strip.test.tsx`, SQL `0156_admin_supervision_projection.test.sql`, smoke routes protégées étendues.
- Re-score A/B/C/D ≥ 9/10 (détail dans la matrice de validation). Aucun workflow fictif ajouté ; lecture Admin only via security definer.
- Prochaine étape : appliquer la migration `20260916120000` sur l’environnement de développement, puis smoke Admin démo runtime.

## 2026-09-14 — Refonte publique, aperçu local

- Direction visuelle reprise suite au rejet utilisateur : blanc/bleu électrique, photographie illustrative originale, titre client/talents/réussite partagée, cartes flottantes et mouvement désactivable. La direction sombre à anneaux a été remplacée.
- Accueil : studio interactif de trois projets illustratifs, liens vers les expertises complémentaires, parcours de confiance, entrées Client/Sous-traitant et Franchise.
- Catalogue public : projection des 200 services du CSV de référence (aucune question chargée), recherche multi-mots insensible aux accents, filtre bibliothèque, état vide, 200 fiches avec métadonnées et sitemap. Ce catalogue de référence statique ne remplace pas la publication organisationnelle.
- FR/AR et RTL pour l'interface ; les noms/descriptions de services issus du catalogue source restent en français, signalés et balisés lang=fr.
- Preuves : 4 E2E desktop/360 px FR/AR verts avec axe WCAG A/AA, studio, pause des animations, filtrage, fiches et recherche vide. ESLint ciblé vert. Captures dans artifacts/test-results/playwright/public-experience-*.
- Pas de changement base de données, ni déploiement de cette refonte. Validation visuelle utilisateur encore attendue ; aucune note de satisfaction ou validation globale V1 inférée.
- Visuel et prompt : docs/progress/public-experience-visual.md.

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
- Les migrations 187–192 ont été appliquées manuellement sur Supabase development,
  puis inscrites dans l'historique CLI. Le correctif additif 193 normalise la portée
  d'idempotence des revues Marketing et a été appliqué automatiquement.
- Tests development : 0133 PASS (33), 0134 PASS (61), 0135 PASS (34), 0136 PASS
  (33), 0137 PASS (64), 0138 PASS (8), plus 4 scénarios de concurrence. Les E2E
  authentifiés sans skip et la configuration des fournisseurs externes restent les
  seules preuves opérationnelles de ce checkpoint; aucune production n'a été touchée.

## Checkpoint accès de validation multi-espaces — 2026-09-13

- La connexion par mot de passe optionnelle complète désormais l'OTP principal en
  FR/AR, avec erreurs non énumérantes et redirection vers le tableau de bord.
- Quatre identités isolées ont été créées et authentifiées sur Supabase development
  pour les espaces Administration, Client, Sous-traitant et Franchisé. Les rôles
  attendus ont été vérifiés; les secrets temporaires ont été remis uniquement via le
  presse-papiers local et ne sont ni loggés, ni documentés, ni commités.
- Le hub récupère les rôles plateforme par le RPC de sécurité borné au compte, sans
  ouvrir de lecture directe sur la table centrale. Les actions Admin sensibles restent
  soumises à AAL2/MFA.
- Gates : Web 150 fichiers/623 tests PASS; TypeScript strict PASS; lint sans erreur;
  build production PASS. GitHub et le déploiement Vercel autorisé ont été mis à jour
  au commit `67835bc`.

## Checkpoint E2E authentifié sans skip — 2026-09-13

- Le gate P05 authentifié a été rejoué sur Supabase development avec deux tenants,
  une identité centrale AAL2, la même identité AAL1 et une identité sans rôle.
- Résultat Playwright : 28/28 PASS, zéro skip, zéro flaky et zéro échec, en FR/AR,
  sur Chromium 360 px et desktop. Les refus anonymes, l'isolation inter-tenant et
  l'obligation MFA centrale sont prouvés.
- Toutes les fixtures Auth, données et stockage ont été neutralisées; les preuves
  d'audit immuables sont conservées et le rapport expurgé est enregistré sous
  `docs/evidence/p05/authenticated-e2e-last-run.json`.

## Checkpoint configuration Vercel et diagnostic runtime — 2026-09-14

- Le périmètre Vercel Matricia a été corrigé localement puis les variables Production
  manquantes ont été créées sans écraser les secrets existants : environnement,
  référence Supabase, chiffrement, webhook interne, signature CTA, paiement DEMO et
  garde-fous Marketing sandbox. Aucun secret n'a été affiché ou commité.
- Le déploiement Production `c3e9ea8` est READY; accueil, connexion et health répondent
  HTTP 200. Web : 150 fichiers/624 tests PASS, TypeScript strict et build PASS.
- Le diagnostic readiness distingue maintenant PostgreSQL `up` du backlog Outbox
  `down` (`OUTBOX_BACKLOG`) au lieu de signaler faussement la base indisponible.
- Blocages externes vérifiés : le jeton Supabase Management fourni retourne HTTP 403
  et ne voit pas le projet, empêchant la configuration Auth URL/SMTP; le worker
  Railway/ClamAV n'est pas configuré, donc 542 événements Outbox restent en attente.

## Checkpoint Railway Worker/ClamAV et Outbox — 2026-09-14

- Le projet Railway `Matricia` et ses services production `matricia-worker` et
  `clamav` ont été créés après autorisation explicite. ClamAV utilise l'image
  officielle épinglée `clamav/clamav:1.4.6-debian13-slim` et reste accessible
  uniquement sur le réseau privé Railway.
- Le worker est configuré avec build/start ciblés, healthcheck `/health`, secrets
  injectés sans affichage, Supabase service role, dispatch HTTPS borné à
  `matricia.vercel.app` et liaison ClamAV privée.
- Un récepteur Outbox interne authentifié, validé et borné à 128 Kio est déployé
  sur Vercel. Tests ciblés 3/3 PASS, TypeScript strict Worker/Web PASS et build
  Next.js production PASS.
- Déploiements Railway Worker et ClamAV : `SUCCESS`. Le backlog Outbox est passé
  de 542 à 0 et `https://matricia.vercel.app/api/readiness` répond HTTP 200 avec
  PostgreSQL et Outbox `up`. Aucun secret n'est documenté ou commité.

## Checkpoint design premium public — 2026-09-14

- La Home et les parcours publics diagnostic, besoin, fournisseur, connexion,
  contact, franchise et à-propos utilisent désormais le système visuel premium
  centralisé et la signature Réponse → Priorité → Action, sans réintroduire de
  catalogue public ni changer une règle métier.
- Les parcours FR/AR conservent route, paramètres et brouillons; les contrôles
  radio, champs libres et menu mobile ont été renforcés pour le clavier et les
  technologies d'assistance.
- Gates : lint et TypeScript strict PASS; build Next.js PASS; Web 151 fichiers/
  627 tests PASS; UI 4/4 PASS; E2E public ciblé 26/26 PASS. Les captures réelles
  avant/après et le rapport sont dans `docs/design-premium/`.
- Les espaces authentifiés n'ont pas été inspectés visuellement pendant cette
  passe faute de compte de test explicitement autorisé. Aucun déploiement ni
  changement de base ou de production n'a été effectué.

## Correctif inscription publique — 2026-09-14

- L'en-tête, la connexion et l'entrée fournisseur exposent maintenant une
  inscription explicite Client ou Sous-traitant. Le mode inscription autorise
  la création Auth par OTP; le mode connexion continue d'interdire toute
  création implicite afin d'éviter l'énumération et les comptes accidentels.
- Après validation du courriel, le nouveau compte reprend sur le passeport
  organisation avec le rôle Client ou Provider prérempli, sans accorder de rôle
  plateforme ni contourner les contrôles d'organisation.
- Gates : lint et TypeScript strict PASS; Web 151 fichiers/629 tests PASS;
  build Next.js PASS; E2E design et inscription 24/24 PASS.

## Checkpoint corrections publiques et espaces connectés — 2026-09-15

- Les parcours publics diagnostic, besoin précis, fournisseur, abonnements, contact et authentification sont raccordés jusqu'au dossier autorisé, avec reprise FR/AR et écritures serveur idempotentes.
- Les espaces Client et Sous-traitant ont reçu les corrections P0 : contexte d'organisation serveur, diagnostics et demandes sans identifiants techniques, devis multiligne exact, qualification documentaire privée et facturation métier. Navigation, Franchise et Administration ont été harmonisées sans affaiblir RLS, AAL2, approbations ou règles financières.
- Migrations additives `194` à `199` et `202` à `206` appliquées sur Supabase development ; dry-run distant final `upToDate: true`.
- Gates : workspace 910 tests PASS, TypeScript strict PASS, lint PASS, build PASS ; Playwright public final 34/34 PASS ; E2E cœur authentifié ciblé 2/2 PASS ; SQL 149 fichiers / 3 488 assertions / 4 scénarios de concurrence PASS ; catalogue 10/200/6000 et absence de placeholders validés.
- Les résidus (primitive documentaire de preuve de paiement, quelques statuts avancés, revue visuelle authentifiée exhaustive et traçabilité Gold Master `1/76 VERIFIED` avec P01 ouverte) sont explicitement consignés dans `docs/corrections-public-dashboards/PROGRESS.md`. Aucun déploiement production n'a été effectué pendant cette passe.

## Checkpoint audit final et fermeture P1 ciblée — 2026-09-15

- Le déploiement observé a été réconcilié avec `codex/bootstrap-foundation` au SHA `b4050fc3`; la branche d'audit part exactement de ce point. Les onze matrices et rapports demandés sont maintenus sous `docs/`.
- Home, navigation, diagnostic, besoin précis, services et entrée Prestataire utilisent le catalogue canonique 10/200 sans charger les 6 000 questions. Brouillons, reprise OTP, validation serveur, FR/AR, clavier et responsive 360–1440 ont été renforcés.
- Qualification Prestataire, capacité `PAUSED`, explications de matching et historique Client sont raccordés. La preuve de paiement Prestataire est désormais archivée dans un objet privé, immuable et tenant-safe avant liaison transactionnelle au ledger.
- Le formulaire Contact déclenche désormais une notification support idempotente lorsqu'elle est configurée, sans perdre la demande ni annoncer faussement une livraison; Railway utilise `/readiness` au lieu du simple liveness `/health`.
- Migrations additives `205` à `207` appliquées uniquement sur Supabase development; dry-run final `upToDate=true`. La 207 impose un verdict antivirus immuable CLEAN avant toute écriture comptable de paiement prestataire. Aucune production n'a été modifiée.
- Gates : build PASS; TypeScript et lint PASS; 910 tests unitaires/intégration PASS; 154 fichiers SQL / 3 590 assertions PASS et 311/311 RPC avec indice DENY; 0154/0155 ciblés et 4 concurrences PASS avec preuves machine, tandis que le replay complet Outbox reste à refaire sans worker development concurrent. E2E publics 34/34 PASS, smoke routes 8/8, E2E authentifiés 3/3 couvrant MAT-FUNC-007/013/018/019 avec fixtures entièrement neutralisées. Traçabilité indépendante actuelle : 5/68 MAT-FUNC V1 VERIFIED.
- Release non signable à ce checkpoint : P01 et traçabilité `5/76 VERIFIED` (5/68 MAT-FUNC V1), MAT-FUNC-020 E2E rouge, smoke authentifié 16 scénarios non exécuté, 336 validations runtime des matrices, paramètres Auth hébergés et intégrations externes réelles (signature, paiements sandbox, SMTP, scanner/social) restent à prouver. Ces points sont consignés dans `docs/RELEASE_CHECKLIST.md` et `docs/DECISIONS_REQUIRED.md`.
