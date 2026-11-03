# Audit indépendant Franchisé — base fusionnée

Date : 3 novembre 2026. Source examinée : `df67da4`, fusion des lots Client et Sous-traitant dans `codex/bootstrap-foundation`. Branche de revue indépendante : `codex/franchise-audit-20261103`. Ce document décrit les constats **avant** les nouvelles corrections ; il ne constitue pas leur recette finale.

Audit en lecture seule du produit. Les seuls fichiers écrits sur cette branche sont ce rapport et ses preuves. Aucun changement de donnée distante, de permission, de facteur MFA, de politique RLS ou de journal financier. Aucune nouvelle pile Docker. Aucune personne réelle contactée.

## Méthode et preuve exécutée

Instructions lues : `AGENTS.md`, instructions Next de `apps/web/AGENTS.md`, Gold Master V4 FINAL, en particulier décisions prioritaires et §§ 8.4, 16.1–16.13, 20, parcours et critères V1 ; skills `matricia-franchise-governance` et `matricia-franchise-finance`.

Commande réellement exécutée sur la base :

```sh
PATH=/workspace/.cache/corepack/bin:$PATH COREPACK_HOME=/workspace/.cache/corepack \
  corepack pnpm --filter @matricia/web exec vitest run modules/franchise --maxWorkers=2
```

Résultat : **45 fichiers, 195 tests réussis**, durée 19,67 s. [Journal](evidence/independent-baseline-web.log). Les dépendances sont celles déjà installées pour la même base produit ; aucun secret n'a été ajouté. Ces tests existants ne reproduisent pas les défauts financiers ci-dessous. Ils ne sont pas une preuve de disponibilité de Supabase hébergé, de Vercel, de l'email ou d'un fournisseur de signature.

Lectures/recherches effectuées avec `rg`, `sed` et analyse ciblée des fonctions SQL effectives et de leurs remplacements ultérieurs. [Reçu des vérifications statiques](evidence/independent-static-findings.json) avec empreinte de migration. **Ces vérifications sont statiques** : les scénarios SQL attendus restent à exécuter dans une base TEST par le chantier d'intégration. Aucun résultat de test SQL ou de navigateur distant n'est inventé dans cet audit.

## Constats à corriger et contre-tests requis

| ID | Priorité | Cause localisée et comportement | Contre-test d'acceptation demandé |
|---|---|---|---|
| FA01 | P1 | `data/spaces/context.ts:17` et `data/library/workspace.ts:151` ignorent `auth.getUser().error` ; avec `user:null`, une erreur Auth 503 devient une déconnexion. | 401/session absente → connexion ; 503 → incident reprenable sans requête métier ni faux « aucun mandat ». FR/AR. |
| FA02 | P1 | `data/operations/repository.ts:57–60` retourne un objet `empty` pour identifiant invalide ou utilisateur absent, et ignore Auth.error. L'appelant l'enveloppe comme succès dans `screens/library/page-helper.ts`. | Identifiant invalide, session absente et Auth 503 doivent rester distincts d'un vrai résultat vide ; vérifier les cartes et compteurs. |
| FA03 | P1 | `data/operations/repository.ts:77–79` charge documents et missions sans filtre bibliothèque ; les autres requêtes ont des limites fixes 50/100/200. RLS borne les droits, mais un même acteur autorisé sur deux bibliothèques peut mélanger leurs missions dans la sélection A. L'UI pagine ensuite seulement les lignes tronquées. | Deux mandats de la même organisation, documents/mission A et B ; sélection A ne contient pas B. Tester plus que les limites, recherche, détail ancien, pagination ou état partiel explicite. Ce constat **ne démontre pas une fuite inter-tenant**. |
| FA04 | P1 | `20260912006800_franchise_finance.sql:51`, `close_franchise_profit_period` calcule `ver := prior.version + 1`, puis inclut cette version dans le hash **avant** `begin_contract_command`. Le même appel après succès possède un autre hash. La sérialisation ne suffit pas à assurer le rejeu. | Même clé/requête → réponse identique, une clôture/allocation/audit/outbox. Autre clé de correction → nouvelle version avec delta, historique immuable. Anciennes clôtures ne doivent pas être réécrites. |
| FA05 | P1 | Même migration, `post_franchise_pnl_entry:48` accepte montant, effet, catégorie et référence libres après un contrôle du journal POSTED/organisation/devise. Aucun reçu natif n'est lu, aucun montant HT n'est dérivé des écritures, aucune politique de coût n'est contrôlée ; effet REVENUE et catégorie coût sont indépendamment acceptés. `record_franchise_distribution_payout:54` vérifie le solde **avant** le rejeu et ne lie pas le montant à un paiement canonique unique. | Refuser faux revenu, TVA, créance non encaissée, mauvaise catégorie, coût central sans règle approuvée et double source/journal sous autre clé. Rejouer un versement intégral après solde zéro doit rendre la réponse initiale. Source réelle admissible + montant/devise exacts + classification indépendante ; aucun solde/journal injecté pour faire passer. |
| FA06 | P1 | `screens/network/actions.ts:70–102` enregistre un prospect puis une activité « Invitation envoyée » ; l'activité utilise une nouvelle date/clé à chaque reprise. `save_franchise_prospect` n'émet que `FranchiseProspectSavedV1` ; le dispatcher worker classe cet événement en observabilité terminale. Pas d'envoi/lien signé de 30 jours trouvé pour ce parcours. `invite-form.tsx:30` affiche pourtant l'envoi réussi. | Invitation persistée avec cible, lien/expiration, anti-spam/déduplication et outbox durable. Distinguer demande, attente, échec et envoi confirmé. Perte de réponse/rejeu ne duplique ni dossier ni activité. TEST uniquement, aucune vraie adresse. |
| FA07 | P2 | `question-editor-actions.ts:9` transforme toute erreur de lecture du détail en FORBIDDEN ; `rule-editor-actions.ts` et `composition-actions.ts` font de même pour tous les échecs workspace. La messagerie utilise aussi un booléen de disponibilité de contexte. | 42501 → refus ; panne technique/invalid response → indisponibilité et reprise ; aucun faux refus de droits. Éviter d'exposer les détails sensibles. |
| FA08 | P1 de complétude | Gold §§16.7/16.12 non prouvé intégralement : `screens/performance/actions.ts:10` envoie une seule métrique saisie numérateur/dénominateur et une empreinte du formulaire ; `record_franchise_performance_snapshot` calcule le score global sur les seules mesures fournies, et qualité absente devient zéro. Les recherches ciblées ne trouvent pas de déclencheur worker/cron pour des audits mensuels/trimestriels ou un moteur indépendant complet à six axes. | Calcul depuis faits autorisés et versionnés, couverture et absence de mesure explicites, six axes lorsque les sources existent, rapport périodique immuable et rejouable avec drill-down. Pas de sanction automatique ni de score global rassurant à partir d'un axe favorable. |

Les propriétaires d'implémentation ont reçu les causes et contre-tests : contexte/root, éditorial, opérations/finance. Ils doivent rapporter les nouvelles migrations/tests et leurs résultats ; ce rapport ne déclare pas ces corrections déjà validées.

### Précautions spécifiques à FA05

`matricia_own_revenue_payments` contient des paiements natifs liés à `financial_journal_id`, mais ce lien seul ne prouve pas qu'un montant est un revenu HT définitivement acquis et attribuable à la bibliothèque. Les financements et consommations de crédits ont déjà un domaine séparé (`credit_economic_*`) et des allocations réservées ; leur réattribution par le P&L historique créerait un risque de double comptage.

Le garde-fou `private.assert_credit_economic_profit_close_ready_v1`, ajouté par `20261031268033`, bloque explicitement une clôture de bénéfice lorsque coûts de fulfillment et frais PSP ne sont pas rapprochés. Il faut **le conserver**. Aucun coût manquant ne doit être supposé nul pour obtenir un profit distribuable. Les méthodes de saisie/revue centrale ne doivent pas remplacer la preuve native d'encaissement, ni la règle de coût versionnée.

## Couverture des exigences et état de la base

Les lignes « mécanisme présent » décrivent une lecture du code et les tests existants cités, **pas une recette hébergée complète**.

| Exigence / parcours | Mécanisme présent sur la base | Écart ou preuve finale à fournir |
|---|---|---|
| Organisation commune et six rôles Franchisé | Contexte d'organisation, rôles OWNER/MANAGER/EXPERT/PROVIDER_MANAGER/ACCOUNTING/VIEWER ; affectations par mandat ajoutées sans remplacer les rôles historiques. | FA01, FA03 ; recette rôles composites, révoqués et deux mandats. |
| Mandat, territoire, dates effectives, exclusivité | Gouvernance versionnée, approbation indépendante, prédicats d'accès aux bibliothèques et affectations exactes. | Recette native début/expiration/rejet/révocation et sélection. Ne pas créer un mandat fictif pour masquer l'absence. |
| Signature et activation | Migration40980 distingue `CONTRACTUAL` de `NON_CONTRACTUAL_DEMO`, réserve la simulation à DEVELOPMENT/STAGING, exige mandat/hash exacts, identité email et preuve effective pour activation contractuelle. Source-binding/politique renforcés par58110/59100. | Fournisseur juridique et niveaux approuvés restent externes. Ne pas présenter le mock SIMPLE comme une signature réelle. |
| Séparation données/mutations | RLS et RPC ciblés, droits de lecture séparés ; aucune extension demandée dans cet audit. | Rejouer contre-tests inter-organisation, inter-bibliothèque, technicien/client simple et révocation immédiate. |
| Catalogue services | Création, brouillon, duplication, classement et commandes gouvernées présents ; pages serveur bornées. | Vérifier archive identité vs état de version, recherche/filtre après mutation, dossier hors première page, publication FR/AR. |
| Questions/questionnaires | Banque ciblée, composition, sections, obligatoire/optionnel, historique et soumission/revue centrale. | FA07 ; reprise panne/conflit, archives et références dans une composition figée. |
| Règles et simulation (`MAT-FUNC-008/010/040–044`) | Contrôles visuels AST/actions/dépendances, banque paginée, sandbox et revue. | Vérifier dépendances seules et cibles des actions, cycles et références étrangères ; aucune charge de 6 000 questions globale. Les audits qualité/abandons complets ne sont pas certifiés par ces 195 tests. |
| Publication centrale et indépendance | `central-review-actions` exige revue humaine/traductions explicites ; tests empêchent une approbation déduite du bouton seul. | Rejouer proposition → refus/correction → revue indépendante → publication, sans auto-approbation ni changement d'une version publiée. |
| CRM/pipeline (`MAT-FUNC-036/037`) | Prospects/types CLIENT/PROVIDER, activités, transitions versionnées, liens vers organisation et dossier fournisseur. | FA03, FA06 ; test de rejeu d'une transition après succès (état courant change avant hash/validation). |
| Invitations et origine (`MAT-FUNC-035/036`) | Écran destinataire, import CSV, prospect et origine métier. | FA06 : ne pas confondre création du prospect et invitation effectivement envoyée/acceptée. |
| Relances/digest (`MAT-FUNC-038/063/064`) | Politiques et jobs de relance, fréquence/destinataire/langue/timezone et consommateurs ; accès par mandat. | Tester panne, lease/retry, idempotence et accès révoqué, sans notification réelle. |
| Réseau/qualification/capacité | RPC de dossier fournisseur avec qualification/capacité service dans la bibliothèque mandatée et document lié au service. | FA03 ; le franchisé ne peut certifier une pièce ni une qualification par une simple case UI. Revue indépendante exigée. |
| Dossiers/devis/missions | Lectures métier sous RLS et synthèse opérationnelle. | FA03 ; cohérence requête/détail et absence de mélange entre les bibliothèques autorisées. |
| Coffre/export (`MAT-FUNC-028`) | Référence documentaire privée, téléchargement contrôlé, export de relevé et audit d'accès. CSV exact ; pas de cellule utilisateur libre dans `statementCsv`. | Recette bytes/hash/scanner réel TEST, refus hors service et liens périmés. Pas de preuve d'un scanner hébergé disponible. |
| Messagerie (`MAT-FUNC-067`) | Conversations deux parties `FRANCHISE_RFQ`, ancienne conversation Client/Provider privée ; RPC d'inbox/thread vérifie le mandat et participant FRANCHISE. | FA07 ; recette après changement d'état de dossier, contexte interdit, pagination, pièce privée et contact avant sélection. Le formulaire Franchisé direct est textuel ; les pièces ne sont pas certifiées par cet audit. |
| Marketing V1 et sélection | `/franchise/marketing` possède déjà un sélecteur d'organisation et des états contextualisés ; pas de correction arbitraire de l'ancien M25. Consentement, marque, clés sociales et outbox séparés. | Recette sélection/mandat réel et lien de régularisation si absent ; panne provider/expiration consentement/anti-doublon et tracking sans fausse conversion. |
| Finance IT/standard | Contraintes IT : Hatim 0 droit d'entrée ; 50/50/0 sur bénéfice distribuable. Standard : règle 50/25/25 versionnée. Sommes exactes, ledgers immuables, allocations avec delta et accès par livre. | FA04/FA05 ; prouver le calcul depuis revenu encaissé HT/coûts autorisés, pas seulement les pourcentages affichés. |
| Frais d'entrée standard | Modes UPFRONT/INSTALLMENT/REVENUE_WITHHOLDING, échéance maximum six mois et exemption IT en contrainte. | Réception réelle des règlements/retenues et restriction gouvernée ; aucun KPI frais ne doit créer une dette IT. |
| Qualité/performance/favoritisme (`MAT-FUNC-068`) | Compteurs réels de supervision, mesures/alertes/snapshots ; états santé et plans documentés ; contrôle gouverné pour sanctions et versions. | FA08 : six axes mesurés, source probante, rapport mensuel/trimestriel et révisions ; score/flag ne résilie jamais. |
| FR/AR/RTL/mobile/accessibilité (`MAT-FUNC-054/059/061`) | Copie des pages et composants FR/AR ; textes libres gardés ; design partagé ; document locale corrigé par lot précédent. | Recette Franchisé aux largeurs 375/390/768/1440, clavier/tactile, menu/overlay, focus, RTL et contraste. L'ancienne matrice Sous-traitant ne certifie pas ces parcours. |
| Résilience et production | Erreurs explicites et garde-fous de signature/finance existants, pas d'overlay inventant une bibliothèque vide (`canApplyFranchiseSpaceDemo()` retourne false). | FA01/02/03/04/05/06/07 ; vérifier outbox/crons externes et reprise réelle. Zéro fictif et mock de réussite interdits. |

## Conclusions limitées

La fusion est une vraie base à conserver ; l'existence de 195 tests verts ne ferme pas les écarts repérés. Les causes partagées sont l'erreur Auth ignorée, les projections tronquées ou insuffisamment contextualisées, les contrôles de rejeu trop tardifs et la confusion entre événement enregistré et action effectivement accomplie.

La sécurité du mandat/signature et plusieurs contrôles RLS sont présents ; aucun contournement ne doit être utilisé pour rendre les écrans verts. La base ne peut pas être déclarée « Franchisé 100 % » avant contre-tests exécutés, revue indépendante des nouvelles corrections, parcours natifs et preuves d'intégrations autorisées. Les six contrôles GitHub de la capture relèvent d'une enquête CI séparée ; leur cause n'est pas déduite de la durée ni du succès Vercel.

## Contre-revue des corrections — première passe

Source d'intégration lue : `50e0e96`, puis nouveaux lots jusqu'à `8c0c5d06` ; les deux ajustements locaux de `page-helper.ts` et du test de recherche sont signalés dans l'état de travail du propriétaire. La revue porte sur le code effectif, pas uniquement ses descriptions. Les migrations en cours ne sont pas considérées appliquées en hébergement.

Contrôles indépendants réellement exécutés dans le worktree d'intégration :

```sh
corepack pnpm --filter @matricia/web exec vitest run \
  modules/franchise/data/spaces/context.test.ts \
  modules/franchise/data/library/workspace-access.test.ts \
  modules/franchise/screens/access-readiness.test.tsx \
  modules/franchise/ui/franchise-context-navigation.test.tsx \
  'app/[locale]/franchise/recherche/page.test.tsx' \
  modules/franchise/screens/library/actions.test.ts --maxWorkers=2

corepack pnpm --filter @matricia/web exec vitest run \
  modules/franchise/data/network/invitation-token.test.ts \
  modules/franchise/data/network/invitation-consumer.test.ts \
  modules/franchise/screens/network/recipient-actions.test.ts \
  modules/franchise/screens/network/invitation-status-action.test.ts \
  modules/franchise/screens/network/actions.test.ts --maxWorkers=2
```

Même préfixe PATH/COREPACK_HOME que la commande de base. Résultats : **123 tests / six fichiers** et **31 tests / cinq fichiers**, tous réussis. [UI](evidence/independent-corrective-ui.log), [invitations](evidence/independent-invitations.log). Ces groupes sont inclus dans les futurs totaux globaux et ne doivent pas y être ajoutés une deuxième fois. Aucun `tsc` global, Docker ou test SQL supplémentaire n'a été lancé par l'auditeur pendant cette passe.

### Corrections confirmées à la lecture et par les tests ciblés

- L'incident Auth 503 reste un incident sans requête métier ; une session absente ou invalide conduit à la connexion. Les pages de barrage maintiennent le cadre de navigation et ne fabriquent plus de succès vide ou de formulaire métier lorsque le mandat manque.
- Le lien profond, l'organisation, le mandat explicite, la recherche et le changement de langue utilisent le même contexte ; `safeReturnPath` borne la destination. Aucun élargissement de permission n'est requis pour ce comportement.
- La projection éditoriale conserve les protections effectives de la dernière fonction40950 : lecteur de bibliothèque ciblé, audience, validation et sécurité. L'archive de l'identité doit prévaloir sur une ancienne version publiée. Les erreurs de lecture et de validation restent distinctes des refus.
- Le nouveau parcours d'acquisition45300 est distinct d'une invitation de membre ou d'un contrat de franchise : token HMAC avec clé serveur, empreinte privée, expiration, destinataire email vérifié, organisation et rôle autorisés. Le batch est atomique et rejouable ; la demande outbox n'embarque ni token ni adresse email. Le consommateur appelle réellement l'adaptateur avec une clé fournisseur stable, puis ne confirme SENT qu'après acceptation par le fournisseur. Le mode DEMO est explicite et interdit en production. Il n'ajoute ni membre, ni rôle, ni qualification, ni droit économique. Aucun SMTP réel n'est certifié par les tests contractuels ci-dessus.
- La nouvelle réconciliation45220 dérive les montants depuis des écritures EXPENSE réelles, séparément des actifs de taxe récupérable, et les rattache à une capture/une réception Client canonique ; proposition et décision indépendantes, captures figées et droits bornés. Les proportions sont calculées en décimaux exacts avec arrondi cumulatif ; aucune saisie de montant libre dans la commande de rapprochement. Un coût absent ou égal à zéro non prouvé reste bloquant.

### Problèmes supplémentaires trouvés dans cette passe

| ID | Risque précis | Correctif demandé / reçu, validation restante |
|---|---|---|
| FA09 — P1 | Deux clôtures sur des intervalles différents mais se chevauchant ne retrouvaient pas la même clôture précédente : mêmes revenus pouvaient produire deux accruals complets. Le verrou initial ne portait que sur `(book,start,end)`. | Patch `82d0eeae` / migration452120 : verrou commun du livre et refus du chevauchement d'un intervalle différent. Une correction de l'intervalle identique reste versionnée. Lecture favorable ; contre-tests SQL natifs et course concurrente à confirmer par l'intégrateur. |
| FA10 — P1 | `auth.jwt()->>'aal' <> 'aal2'` vaut NULL si la claim manque ; `IF NOT access()` ne dénie pas non plus si `access()` vaut NULL. Un rôle Finance valide pouvait ainsi passer les nouveaux points d'entrée avec une claim AAL absente. | `26109cf4` normalise les six gardes historiques ; `3debfc73` emploie `IS DISTINCT FROM TRUE` dans les rapprochements. Les contre-tests doivent couvrir claim absente et JSON-null, pas seulement AAL1. Les remplacements initiaux produisaient les tokens invalides `truethen`/`trueor`, signalés avant rejeu SQL ; résultat final exigé après réparation syntaxique. |
| FA11 — P1 | Après clôture, un remboursement/litige natif peut rendre les revenus inadmissibles alors que l'accrual historique reste positif. Le versement utilisait uniquement ce solde et un journal de règlement, sans revalider les sources. | `a0283770` ajoute une revalidation des périodes avant tout nouveau versement, après le retour d'un rejeu historique exact. Contre-test indispensable : clôture positive → remboursement vérifié → nouveau versement refusé, sans réécriture de l'ancienne clôture. |
| FA12 — P1 | La catégorie `APPROVED_SHARED_CENTRAL_COST` du chemin P&L historique restait un texte libre sans règle d'allocation centrale contractuellement approuvée. Un effet COST pouvait aussi utiliser une catégorie de revenu. | `178a4d6d` / migration452130 : exclusion par défaut des coûts centraux et couplage effet/catégorie. Lecture favorable ; contre-tests SQL requis. Ne pas inventer une politique permettant de fermer le test. |
| FA13 — P2 fiabilité | Le verrou de livre ajouté à l'écriture d'allocation ne supprime pas le verrou de financement déjà pris par son appelant68031:76. Un rapprochement prenait livre puis financement alors qu'une consommation pouvait tenir financement puis attendre livre : cycle de deadlock. | Signalé au propriétaire ; utiliser un ordre cohérent sur tous les appelants ou une acquisition non bloquante avec erreur55P03 reprenable. L'atomicité évite un ledger partiel, mais ne suffit pas à revendiquer une exploitation fiable. |

Course liée à FA11 : le reçu adverse peut exister dans `private.verified_payment_dispatch_inbox_v1` avant son import dans `credit_pack_payment_adjustments_v1`. Les protections de clôture et de versement doivent inclure cette source et ses écrivains, pas uniquement la table d'ajustements finale. Une signature de paiement correctement vérifiée mais non encore dispatchée ne doit pas laisser une fenêtre de distribution admissible. Ce point a été transmis au propriétaire financier.

Cette passe est une **contre-revue intermédiaire**. Les tests SQL réellement exécutés par le chantier d'intégration, la recette native, la matrice visuelle et le nouveau moteur de performance45400 restent à examiner avant conclusion finale. Les 123/31 tests UI/contrats ne sont pas présentés comme une preuve monétaire ou de disponibilité externe.
