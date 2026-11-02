# Sous-traitant — état vérifiable de la réalisation

Source explicite : Client `7e01276818e8af11cf18f616615721f1662951fe`, conservé dans `codex/provider-completion-20261102`. Aucun déploiement ni fusion en production. Le présent rapport distingue implémentation, tests locaux et recette hébergée ; il ne certifie pas une livraison commerciale complète.

Candidat de recette navigateur : `8941517a6beacfac1fd0b785035ce9ec15d877dc`, arbre `apps/web` `e709d635bfc02c3297ec356689b24364243a67ea`. Les correctifs de tests ou de documentation postérieurs ne changent pas à eux seuls le produit exécuté par cette recette.

## Périmètre et preuves

Les identifiants E/D ci-dessous appartiennent à l'analyse approfondie du parcours Sous-traitant, après les corrections Client. Ils ne remplacent pas les identifiants M01–M30 de l'audit initial. « Implémenté » ne signifie pas que toutes les intégrations externes ont été certifiées. Les décomptes recouvrants ne sont jamais additionnés.

| ID | Cause / comportement corrigé | Preuve locale disponible et limite |
|---|---|---|
| E01 | FormData de récurrence ONE_TIME conservé | Tests formulaires/devis ; [Devis](QUOTES.md) |
| E02 | Catégorie fiscale issue du snapshot approuvé | Commandes et tests devis ; pas de tarif fiscal inventé |
| E03 | Version documentaire courante applicable au service exact | Migration38300, SQL0345 44 assertions ; renouvellement B ne qualifie pas A |
| E04 | Questionnaire Provider, sauvegarde, conditions et dépôt | Engine partagé38100, navigateur natif avec reprise hors ligne et texte libre arabe ; revue indépendante38400, SQL0357 40 assertions |
| E05 | Identité légale commune et décision indépendante |43000, SQL0350 28 assertions ; identité native revue après vrais fichiers TEST |
| E06 | Upload rejouable après perte de réponse |38000, chemin/réservation/hash stables, SQL0345 |
| E07 | Lecture distincte des droits de mutation | RLS/rôles SQL et 20 frontières navigateur natives, dont AAL1 refusé |
| E08 | Conditions, motifs et expiration visibles | Projection qualification et composants FR/AR ; statut demandé localisé |
| E09 | Capacité service/globale avec fenêtres effectives | SQL0345 et déclarations natives persistées |
| E10 | Filtres documentaires avant pagination, historique | DAL/coffre et SQL0345 ; pièces privées natives vérifiées |
| E11 | Invitations/devis paginés et détail direct |39100, SQL0346 41 assertions et tests DAL |
| E12 | Échec de chargement distinct d'un formulaire vide | États explicites, erreurs/prefill bloqués, tests de pages FR/AR |
| E13 | PDF réel du brouillon et autorisation du dossier | Route privée/PDF et vrai PDF dans la recette navigateur8941517, tiers refusé |
| E14 | Complétude fondée sur obligations et scans/revues | SQL0345, ancres et revue documentaire native TEST |
| E15 | Options HT facultatives et pièces liées à une version |39000, SQL0346, comparatif ; option acceptée par nouvelle version fiscalisée |
| E16 | Révision volontaire et historique immuable |39200, SQL0346, révision Client→brouillonV2Provider caché→republication et V1 immuable réussis sur8941517 |
| E17 | Rayon et taille déclarés, sans qualification automatique |38200, SQL0345, commandes natives de capacité/périmètre |
| D01 | Déclaration de paiement puis confirmation Client et revue Finance |40000/40500/40600, SQL0347/0352 et UI ; aucun paiement auto-validé par le Provider |
| D02 | Échéancier approuvé lié aux échéances réelles |40500, contre-tests financiers et refus échéance impayée |
| D03 | Pré-relevé, contradiction, exceptions et clôture durable |40100–40950, SQL0347 56 assertions au checkpoint40940 ; délais réels conservés |
| D04 | RejetV1, correctionV2 et rejeu exact du reçu |41700/41800, SQL0348 102 assertions au checkpoint41830 |
| D05 | Jalons corrigés avec décisions historiques |41400, SQL0348 ; la recette native navigateur reste à finir |
| D06 | Contrat complet avant signature et historique | Contrat natif généré après sélectionV2, PDF FR/AR et création de mission réussis ; signature DEV-mock SIMPLE, externe non certifiée |
| D07 | ADD/REPLACE/REMOVE signés, préparés et exécutés |41950/41960, SQL0355 170,0355b27,0355c18 ; legacy0354 129, chaque transaction annulée |
| D08 | Encaissement des missions livrées/terminées |40000+, contre-tests financiers et confirmation Client séparée |
| D09 | Technicien affecté, lecture séparée de l'exécution |41500/41820/41950, rôles composites et révocation SQL ; recette navigateur préparée |
| D10 | Preuves et commentaires de réception accessibles sous droits | Versions privées propres, commentaires immuables, tests route/UI et SQL0348 |
| D11 | Histoire financière paginée et anciennes devises | DAL, tests anciennes factures hors première page et devises exactes |
| D12 | Relations missions/contrats paginées |41300/41830, recherche native SQL ; détail direct sous RLS |
| D13 | Messagerie native après contrat, tenant et pièces |42000–42040, SQL0349 68 assertions ; Client-only rôle Provider refusé |
| D14 | Preuves contradictoires document/message/livraison canoniques |44100/44200/44400, SQL0351 intégré79 assertions, dont affectation/révocation Technician |
| D15 | Jours ouvrables et calendrier figé de procédure |44000, vendredi→mardi, fermeture et DST ; ancien délai non réécrit |
| D16 | Devise réelle, unités mineures exactes | Finance/DAL/UI, TND/KWD/JPY, pas de taux ou arrondi flottant |
| D17 | Langue conserve chemin et organisation | Composants de navigation FR/AR, recette responsive de40 pages |
| D18 | Équipe et erreurs de lecture bornées au tenant | DAL paginé/RLS, sans faux zéro ni membre étranger |
| D19 | États métier FR/AR et RTL | Copies partagées, NOT_REQUESTED contextualisé et options approuvées traduites ; texte libre conservé |

## Vérifications et réserves actuelles

- Toutes les preuves SQL citées sont liées aux fichiers et hashes de leur reçu. Les reçus transactionnels indiquent `commitSent:false`, empreintes identiques et rollback. Ce ne sont pas des replays neufs de tout le dépôt.
- Le build complet local du candidat précédent `e929f99` a réussi avec TypeScript actif. Le candidat8941517 a ensuite réussi son build complet avec TypeScript actif ; ses preuves sont dans evidence/browser/candidate-two/. La migration corrective38410 de la file Admin impose un dernier contrôle consolidé.
- Recette réelle déjà exécutée au checkpoint précédent : quinze identités GoTrue OTP/TOTP AAL2, dossiers TEST distincts, identité/pièces/questionnaire/capacité ; 40 pages FR/AR aux largeurs375/390/768/1440 et8 menus sans débordement, erreur JS ou sens RTL incorrect.
- Axe :64 scans sans violation automatique, mais64 résultats `color-contrast` incomplets. Cela ne vaut pas contrôle manuel complet ni certification WCAG.
- Les tests globaux initiaux :2939 réussis,8 échecs et1 skip opt-in. Les8 échecs correspondent à quatre délais PDF et quatre attentes lues pendant l’intégration (navigation, pagination, multi-select). Les groupes PDF/options16 et navigation/pages15 ont ensuite réussi séparément, sans relâcher de délai ; la confirmation globale finale hors PDF passe2922 tests avec1skip opt-in, les25 PDF passent séparément (groupe30 avec5 contrôles MFA recouvrants). Types, lint, worker104 et son build passent.
- Les régressions et contre-revues sont détaillées dans [revue indépendante](independent-review.md), [Finance](FINANCE.md), [autorité économique](DISPUTE_ECONOMICS.md), [moteur signé](SIGNED-SCOPE.md), [Devis](QUOTES.md), [Entrée](entry.md), [communication](CONTEXT-COMMUNICATION.md).

## Conditions externes de clôture

1. Fournisseur et niveaux de signature approuvés (DR-001), accords/clauses économiques et mandat de collecte s'il s'applique. Le DEV-mock SIMPLE n'est pas une signature juridique de production.
2. Éditeur légal et coordonnées complètes, CNDP/politiques applicables, conditions commerciales, tarification et traductions approuvées manquantes. Aucun contenu n'est inventé.
3. Recette hébergée autorisée : Supabase/Vercel/worker, email, scanner réel et paiements sandbox, puis sauvegarde/restauration et exploitation. Les tests locaux ne prouvent pas ces connexions distantes.
4. Création de PR : branche poussable, mais l'accès GitHub GraphQL avait été refusé. Aucun lien de PR créée n'est revendiqué sans retour réel du service.
