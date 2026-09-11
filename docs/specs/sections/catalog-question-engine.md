# Catalogue et Question/Rule Engine — contrat P06

Autorité : Phase 06 et addendum « Catalogue métier, services et 6 000 questions » du Gold Master V4 FINAL. Portée fonctionnelle directe : MAT-FUNC-008, 010 et 040 à 044; invariants transverses : MAT-FUNC-024, 027, 055 à 061. Le gate est une bibliothèque complète importée, administrable, publiable, simulable et restaurable sans changement de code.

Le lot W1 couvert par la migration catalogue core livre uniquement hiérarchie, versions, staging, gouvernance et protocole de release. Il ne livre ni l’import de la baseline, ni questionnaires/règles, ni assistant IA : ces lots ultérieurs sont indispensables avant le gate P06. Les états W1 réellement exécutables sont `DRAFT`, `IN_REVIEW`, `APPROVED`, `SCHEDULED`, `PUBLISHING`, `PUBLISHED`, `FAILED`, `DEAD_LETTER`, `CANCELLED` et `RETIRED`; `PAUSED`, restauration métier et archivage complet seront ajoutés par migrations additives dédiées avant le gate. Aucun résultat W1 seul ne peut déclarer P06 GREEN.

## Définition des fonctions P06

- `MAT-FUNC-008` — Assistant besoin : transforme un texte Client borné en candidats de services publiés, restitue score et justification, pose les questions discriminantes manquantes, et exige confirmation humaine; il ne crée ni besoin ni RFQ silencieusement.
- `MAT-FUNC-010` — Besoin multi-services : compose un bundle versionné pouvant couvrir plusieurs services et bibliothèques, conserve chaque release source, détecte incompatibilités/doublons, et construit un questionnaire fusionné avec provenance et déduplication explicites.
- `MAT-FUNC-040` — Modèles : clone un questionnaire/service modèle dans une nouvelle identité de brouillon avec lien de provenance; aucune édition du clone ne modifie le modèle ou les usages historiques.
- `MAT-FUNC-041` — Qualité assistée : l’IA signale ambiguïtés, contradictions, doublons et questions portant sur une donnée fiable déjà connue. Chaque suggestion est explicable, révisable et sans publication automatique.
- `MAT-FUNC-042` — Similarité : calcule des candidats de questions similaires avec version d’algorithme, score et raisons; fusion, rejet ou conservation est une décision humaine auditée, sans suppression physique d’une question utilisée.
- `MAT-FUNC-044` — Abandon confidentiel : enregistre motif et étape sous accès restreint, applique minimisation/rétention versionnées, ne place jamais texte libre ou réponses dans logs/Outbox, et ne transforme l’abandon en opportunité sans base légale/consentement.

Chaque fonction expose FR/AR, applique RLS et idempotence, et possède une preuve E2E nominale, une preuve DENY d’autorisation, une preuve de rejouabilité et une preuve de non-régression historique.

## Baseline déterministe et source

La source canonique d’import est `catalogue/Matricia_Catalogue_Metier_V1`. Son manifeste V1 annonce et les fichiers livrés contiennent :

| Objet | Volume initial obligatoire |
|---|---:|
| Bibliothèques actives | 10 |
| Grandes catégories | 40 |
| Sous-catégories | 80 |
| Services actifs | 200 |
| Liens service–sous-catégorie | 212 |
| Questions RFQ | 5 000, soit 25 par service |
| Questions diagnostic | 700, soit 70 par bibliothèque |
| Questions qualification Provider | 300, soit 30 par bibliothèque |
| Questions totales | 6 000 |

La bibliothèque `OPS` est un modèle optionnel non actif et n’entre pas dans ces comptes. La copie sous `matricia_gold_v2` n’est pas une seconde autorité et ne doit pas être importée en parallèle. Un registre de sources conserve pour chaque fichier : chemin canonique, SHA-256, taille, nombre de lignes, version du générateur, date d’import et identifiant du batch.

Les fichiers actuels sont français. Leur statut `ACTIVE` ne vaut pas autorisation de publication applicative : tout contenu exigeant l’arabe reste non publiable tant que sa traduction et sa revue ne sont pas validées.

## Agrégats et identité stable

- `CatalogRelease` représente un snapshot cohérent et reproductible du catalogue.
- `Library`, `Category`, `Subcategory`, `Service`, `Questionnaire`, `Section`, `Question` et `Rule` possèdent une identité UUID stable et une clé métier unique immuable.
- Chaque agrégat éditable sépare la table d’identité de sa table de versions. Une version publiée est immuable; toute correction crée une nouvelle version.
- Les pointeurs `current_draft_version_id` et `current_published_version_id` sont contrôlés transactionnellement. Un pointeur publié ne référence jamais une version non publiée.
- Tout diagnostic, RFQ, qualification, devis, contrat, checklist ou mission référence explicitement les UUID de versions utilisés, jamais uniquement l’identité courante.
- Un service a exactement une sous-catégorie principale publiée et zéro ou plusieurs liens secondaires. Un lien secondaire ne duplique pas le service dans l’expérience Client.
- Les rangs sont des entiers positifs uniques dans leur parent et leur version. Les réordonnancements utilisent une mutation atomique avec contrôle de version optimiste.
- Les codes, slugs et clés sont normalisés, non réutilisables après publication et uniques dans leur portée définie.
- Les montants éventuels sont en unités mineures ou `numeric` exact; aucun `float` n’est accepté. Les règles fiscales et financières référencent un moteur versionné externe au catalogue.

## Modèle logique minimal

Le schéma SQL peut adapter les noms physiques, mais doit représenter explicitement :

| Domaine | Entités requises |
|---|---|
| Release | `catalog_releases`, `catalog_source_files`, `catalog_import_batches`, `catalog_import_rows`, `catalog_import_errors` |
| Hiérarchie | `catalog_libraries` + versions, `catalog_categories` + versions, `catalog_subcategories` + versions |
| Services | `catalog_services` + versions, `catalog_service_subcategory_links`, dépendances et références historiques |
| Questionnaires | `questionnaires` + versions, `questionnaire_sections` + versions, associations questionnaire–question versionnées |
| Questions | `questions` + `question_versions`, associations question–service versionnées |
| Règles | `rule_sets` + versions, `rule_versions`, dépendances entre questions et actions |
| Gouvernance | `catalog_change_requests`, `catalog_approvals`, journal de comparaison avant/après |
| Simulation | `questionnaire_simulations` avec entrée/hash/résultat/versions, sans réponse métier persistée ni statistique produit |

Les tables de versions contiennent `version`, `status`, `change_reason`, `created_by`, `created_at`, et les dates/acteurs propres aux revues et publications. Les relations publiées ciblent des versions précises ou un `CatalogRelease`; aucune jointure historique ne résout implicitement « la dernière version ».

## États et transitions

### Contenu versionné

`DRAFT → LOCAL_TEST → FRANCHISE_REVIEW → CENTRAL_REVIEW si sensible → APPROVED → SCHEDULED → PUBLISHED → SUPERSEDED | ARCHIVED`

- Une transition est autorisée par commande serveur, jamais par mise à jour directe.
- Une publication rend la version immuable et remplace atomiquement la version publiée précédente par `SUPERSEDED`.
- Une date de publication peut être immédiate ou planifiée. Le worker de publication est idempotent.
- Le rollback ne réécrit pas l’histoire : il republie une version antérieure comme nouvelle décision de release, avec motif et audit.
- `PAUSED` masque une identité aux nouveaux parcours sans invalider les parcours attachés à une version historique.
- Un brouillon jamais publié et jamais référencé peut être supprimé par son auteur selon permission. Tout contenu publié ou référencé est uniquement archivable.
- L’archivage d’un service avec mission active est refusé; une extinction datée ou une migration contrôlée est exigée. Les contrats récurrents restent attachés à leur version.

### Import

`RECEIVED → VALIDATING → INVALID | READY → IMPORTING → IMPORTED | FAILED`

Une relance avec le même hash de bundle et la même clé idempotente retourne le même résultat. Un contenu différent avec la même clé est refusé. Un batch invalide ne modifie aucune table publiée.

### CatalogRelease et orchestration

`DRAFT → IN_REVIEW → APPROVED → SCHEDULED → PUBLISHING → PUBLISHED → RETIRED | ARCHIVED`, avec `PUBLISHING → FAILED → PUBLISHING` jusqu’à `DEAD_LETTER` selon la politique de retry versionnée.

- `IN_REVIEW → DRAFT` sur rejet motivé; `SCHEDULED | FAILED → CANCELLED` sur annulation humaine avant prise d’un lease; un échec worker sous lease valide produit `FAILED` et `next_attempt_at`, puis un nouveau claim automatique; la tentative maximale produit `DEAD_LETTER`, terminal et sans prochain essai. `PUBLISHED → RETIRED` lors d’une supersession; restaurer un historique crée une nouvelle release de rollback planifiée et publiée par le worker.
- Une release porte une audience versionnée au schéma fermé : `{"kind":"PUBLIC"}` sans champ parasite, ou `{"kind":"ORGANIZATIONS","organization_ids":[...]}` avec UUID d’organisations actives, triés et dédupliqués côté serveur. Cette forme canonique alimente stockage et hash d’idempotence. `effective_from` UTC est obligatoire et `effective_until` optionnel; les comparaisons utilisent l’instant serveur.
- Une contrainte empêche deux publications actives ou planifiées qui se chevauchent pour une bibliothèque et une audience : `PUBLIC` intersecte toute audience, et deux audiences `ORGANIZATIONS` intersectent si leurs ensembles partagent au moins une organisation, uniquement pendant le chevauchement de leurs fenêtres effectives. Le worker prend un lease atomique, vérifie `row_version`, base, audience et snapshot, puis publie dans une transaction.
- Chaque tentative conserve numéro, worker, lease et erreur neutre. Un worker peut réclamer atomiquement un `PUBLISHING` dont le lease est expiré; un ancien token ne peut ensuite ni terminer ni déclarer un échec. Backoff exponentiel borné, maximum de tentatives et délai sont des politiques versionnées; l’épuisement produit audit, Outbox et dead-letter explicite. Une annulation est refusée après le commit de publication; une compensation crée une nouvelle release.
- Une répétition de completion avec le dernier token restitue le même résultat lorsque la release est encore `PUBLISHED` ou déjà `RETIRED` par supersession/rollback, sans nouvel audit ni événement.
- `PAUSED` est un état de visibilité d’identité, distinct de la release : `PUBLISHED ↔ PAUSED`, avec motif, acteur, instant et reprise explicite. Restaurer un contenu archivé crée une nouvelle version en `DRAFT`; annuler une soumission la replace en `DRAFT` sans effacer ses décisions.

## Import staging et validation

1. Enregistrer le batch, le manifeste et le hash de chaque source avant parsing.
2. Charger chaque ligne en staging avec fichier, numéro de ligne, payload brut borné et hash canonique.
3. Valider types, tailles, encodage UTF-8, JSON embarqué, enums, clés, unicité et références sans mutation du catalogue.
4. Produire un rapport déterministe ligne par ligne; aucune valeur invalide n’est silencieusement corrigée.
5. Vérifier les comptes réels des fichiers, sans faire confiance aux seuls compteurs du manifeste.
6. Vérifier 25 RFQ par service, 70 diagnostic et 30 qualification par bibliothèque, les 212 liens, les liens primaires et l’absence d’orphelins.
7. Rejeter doublons, cycles, références manquantes, rangs incohérents, schémas JSON invalides, branches mortes démontrables, clés de données incompatibles et marqueurs incomplets.
8. Créer les identités/versions en transaction, sans écraser une version publiée, puis figer un release candidat.
9. Exiger les champs FR/AR et une attestation arabe immuable (`reviewer_user_id`, instant, hash de preuve, version), créée par une commande centrale MFA auditée et jamais par `UPDATE` direct. Juridique, fiscalité, assurance, HSE et contenu réglementaire portent `EXPERT_REVIEW_REQUIRED` jusqu’à décision compétente.
10. Publier la baseline sous la clé stable `MATRICIA_GOLD_MASTER_BASELINE_V1` seulement après toutes les validations et approbations.

Le reset de démonstration cible exclusivement les données marquées démonstration et ne supprime jamais configuration ou historique de production.

## Contrat Question

Une question définit au minimum : clé stable, portée `GLOBAL | LIBRARY | CATEGORY | SUBCATEGORY | SERVICE`, phase, bibliothèque/service optionnels selon portée, section, statut et version courante. Sa version contient :

- `label_fr`, `label_ar`, `help_fr`, `help_ar`, `why_we_ask_fr`, `why_we_ask_ar`;
- type de réponse, caractère obligatoire, `required_for_quote`, `required_for_publication` et `data_key`;
- options et schéma de validation JSON versionnés;
- règle de visibilité, valeur par défaut et source de préremplissage;
- sensibilité `PUBLIC | BUSINESS | CONFIDENTIAL | RESTRICTED`;
- poids et score maximal exacts, liens vers anomalies, risques, recommandations, opportunités et documents;
- ordre, motif de changement et `template_key` pour les modèles partagés.

Types minimums : `YES_NO`, `SINGLE_CHOICE`, `MULTIPLE_CHOICE`, `SHORT_TEXT`, `LONG_TEXT`, `INTEGER`, `DECIMAL`, `PERCENTAGE`, `MONEY`, `CURRENCY`, `DATE`, `DATE_RANGE`, `TIME`, `EMAIL`, `PHONE`, `URL`, `ADDRESS`, `GEO_AREA`, `RATING_5`, `RATING_10`, `QUANTITY`, `UNIT_VALUE`, `FILE`, `MULTI_FILE`, `IMAGE`, `TABLE`, `REPEATER`, `CONTACT`, `ORGANIZATION`, `PRODUCT_LIST`, `SITE_LIST`, `MILESTONE_LIST` et `BUDGET_BREAKDOWN`.

Les types structurés possèdent un schéma borné et versionné. `TABLE` et `REPEATER` fixent colonnes/enfants, types, lignes minimales/maximales et validations. `MONEY` associe montant exact et devise; il n’embarque aucune règle fiscale.

Une question utilisée n’est jamais supprimée physiquement. Dupliquer crée une nouvelle identité et conserve `source_question_id`; modifier une question publiée crée une nouvelle version; lier/délier un service crée une nouvelle version de l’association.

## Contrat Rule Builder

Une règle est un AST JSON validé par schéma et compilé en représentation interne déterministe. Les opérateurs autorisés sont : égal, différent, supérieur, inférieur, dans liste, contient, vide, non vide, regex contrôlée, date avant/après et changement depuis la réponse précédente. Les groupes `AND`, `OR`, `NOT` sont imbriqués avec profondeur, nombre de nœuds, taille de chaînes et coût regex bornés par politique versionnée.

Actions autorisées : afficher/masquer question ou section, rendre obligatoire/facultatif, calculer score, créer anomalie/risque/recommandation/opportunité, associer un niveau de solution, demander un document, exiger un contrôle humain, bloquer publication ou envoi RFQ, suggérer un service complémentaire, lancer un diagnostic enfant et fixer la validité d’une réponse.

Le compilateur refuse : opérateur/action inconnu, type incompatible, référence absente ou hors release, cycle direct ou indirect, auto-référence, branche inaccessible démontrable, valeur non bornée, regex dangereuse, score hors bornes et action financière/fiscale encodée directement. Les graphes de dépendances sont calculés et stockés par version.

Les politiques suivantes sont configurables et versionnées, jamais hardcodées dans l’UI : profondeur et taille maximales d’AST, limites de regex, bornes de score, durées de validité, seuils de complétude et classification des changements sensibles.

## Évaluation, complétude et simulation

- L’évaluation reçoit exclusivement : release/version de questionnaire, réponses typées, contexte autorisé et instant d’évaluation explicite.
- Une entrée canonique produit toujours le même résultat et le même hash avec la même version de moteur.
- Le résultat liste questions visibles, requises, préremplies, manquantes, erreurs, complétude exacte, scores, anomalies et actions proposées, avec trace explicable des règles déclenchées.
- Une valeur préremplie indique source, version, fraîcheur et permission; une donnée expirée ou non autorisée n’est pas réutilisée.
- L’envoi RFQ est refusé si une question visible `required_for_quote` manque ou échoue à sa validation.
- L’autosave utilise version optimiste, idempotence et résolution explicite des conflits; il ne change pas la version du questionnaire en cours.
- Une simulation utilise un namespace isolé, ne publie aucun événement métier aval, ne crée ni statistiques réelles, ni anomalie Client, ni opportunité. Elle conserve seulement les versions, l’entrée de test bornée, le hash et le résultat nécessaires à la preuve.
- La comparaison de versions expose le diff structurel, textuel, règles, scoring, traductions et impacts historiques sans muter les objets comparés.

### Sessions, réponses et soumission

- Une `QuestionnaireSession` fixe organisation, acteur autorisé, contexte, release, versions de questionnaire/questions/règles, locale, audience et échéance. Elle suit `DRAFT → IN_PROGRESS → READY → SUBMITTED | ABANDONED | EXPIRED`; une soumission est immuable et toute correction crée une révision liée.
- Chaque réponse possède question-version, valeur typée, provenance (`USER`, préremplissage autorisé, import), sensibilité, `row_version` et hash. L’autosave transactionnel reçoit session/version attendue, lot ordonné et clé idempotente; il retourne version serveur, champs acceptés et conflits sans écrasement silencieux.
- Un conflit restitue uniquement les métadonnées et valeurs que l’acteur peut lire. La résolution explicite (`KEEP_SERVER`, `APPLY_CLIENT`, `MERGE` pour types compatibles) produit une nouvelle révision auditée.
- `submit_questionnaire_session` réévalue sur le snapshot fixé, refuse erreurs/questions requises manquantes, fige un manifeste de réponses et son hash, puis émet un seul événement sans payload confidentiel. Retry identique restitue la même soumission.

### Sémantique normative du moteur

- `UNKNOWN` est distinct de `NULL`: `NULL` est une réponse explicite autorisée par le schéma; `UNKNOWN` signifie absente/inaccessible/expirée. Une comparaison avec `UNKNOWN` produit `UNKNOWN`; seul `IS_UNKNOWN` la teste. Dans une condition de visibilité, `UNKNOWN` vaut non-déclenché et figure dans la trace.
- Aucune coercition implicite entre texte, booléen, date et nombre. Les seules coercitions déclarées dans le schéma versionné sont appliquées avant validation et tracées; échec de coercition produit une erreur, jamais une valeur par défaut.
- `DECIMAL`, `PERCENTAGE`, scores et unités utilisent `numeric` avec précision/échelle versionnées. L’arrondi explicite est `HALF_UP`, `HALF_EVEN`, `FLOOR` ou `CEILING` et s’applique au nœud déclaré; aucune valeur financière n’utilise `float`.
- Dates sont ISO `YYYY-MM-DD`; instants sont UTC; temps locaux exigent timezone IANA et règle DST versionnée. Un instant d’évaluation explicite interdit toute dépendance à `now()` dans le moteur pur.
- Les actions sont ordonnées par priorité stable : sécurité/blocage, requiredness, visibilité, validation, scoring, puis recommandations/opportunités. À priorité égale, ordre canonique `rule_key`, `action_index`; les conflits incompatibles échouent en validation.
- La canonicalisation trie les clés JSON, normalise Unicode NFC, conserve l’ordre des tableaux sémantiques, normalise nombres sans notation flottante et exclut métadonnées non sémantiques. Le hash SHA-256 couvre entrée canonique, release, versions, politique, moteur et instant.
- Le runtime est pur, borné par nombre de nœuds/opérations/temps/mémoire configurables, sans réseau ni SQL par règle. Une évaluation interrompue ne produit aucune action partielle et retourne une erreur neutre corrélée.

## Gouvernance et approbation

Une classification versionnée détermine si un changement est ordinaire ou sensible. L’approbation centrale est obligatoire au minimum pour règle financière/crédit, Box, commission, pénalité, clause contractuelle, texte juridique/réglementaire obligatoire, anomalie bloquante, suspension Provider, scoring important, fusion/suppression à impact historique et engagement volume.

Une approbation enregistre auteur, examinateur distinct lorsque la politique l’exige, versions avant/après, diff canonique, motif/commentaire, décision, date et corrélation d’audit. Un auteur ne peut pas auto-approuver une élévation sensible. Les rôles centraux sensibles exigent MFA satisfait. Le rejet retourne la version en brouillon avec motif public borné sans effacer l’historique.

## Autorisation et RLS

- RLS est activée et restrictive par défaut sur toutes les tables exposées.
- Le public applicatif ne lit que les releases publiés et contenus autorisés par visibilité/plan; brouillons, staging, erreurs d’import, approbations et simulations restent privés.
- Un franchisé ne lit/modifie que les brouillons des bibliothèques couvertes par un mandat actif, une organisation `ACTIVE` et les permissions requises. Il ne peut ni modifier une autre bibliothèque, ni s’attribuer un scope. Révoquer un mandat ou une version de politique passe exclusivement par une RPC centrale MFA, idempotente, auditée et émettant un événement Outbox; les tables d’autorisation restent immuables en écriture directe.
- Le central dispose de permissions explicites, pas d’un bypass RLS implicite. Les changements sensibles passent par commandes dédiées.
- Les tables d’identité/version ne sont pas modifiables directement par `authenticated` ou `service_role`; les mutations passent par RPC à privilège minimal.
- Chaque `security definer` fixe `search_path`, vérifie `auth.uid()`, MFA si requis, permission et scope bibliothèque à l’intérieur de la transaction.
- Les lectures de questions sont paginées et filtrées côté serveur; aucune API ne retourne les 6 000 questions par défaut.
- Les champs `CONFIDENTIAL` et `RESTRICTED`, réponses et données de simulation sont filtrés par politique et ne sont jamais journalisés en clair.

Le contrat d’autorisation commun est `private.has_library_permission(p_library_id, p_permission_code, p_actor_id)`. Son implémentation dérive exclusivement des rôles, memberships, mandats de franchise et politiques actives; aucun identifiant transmis par le client ne suffit à accorder l’accès.

## Commandes RPC et API

Toute mutation reçoit `p_idempotency_key`, `p_correlation_id` et, pour un objet existant, `p_expected_row_version`. Les réponses sont des DTO bornés avec outcome explicite. Une même clé et un même payload rejouent la réponse; une même clé et un payload différent sont refusés.

RPC minimales :

- `create_catalog_library`, `save_catalog_library_draft`, `submit_catalog_change`, `decide_catalog_change`;
- `create_catalog_category`, `save_catalog_category_draft`, `create_catalog_subcategory`, `save_catalog_subcategory_draft`;
- `create_catalog_service`, `save_catalog_service_draft`, `duplicate_catalog_service`, `archive_catalog_service`, `restore_catalog_service`, `simulate_catalog_service_impact`;
- `create_questionnaire`, `save_questionnaire_draft`, `create_question`, `save_question_draft`, `duplicate_question`, `archive_question`, `restore_question`;
- `validate_rule_set`, `simulate_questionnaire`, `schedule_catalog_release`, `cancel_catalog_release`, `rollback_catalog_release`;
- worker `claim_catalog_release`, `complete_catalog_release_publish`, `fail_catalog_release_publish`, exécutables uniquement par `service_role` avec lease borné; aucune publication ou déclaration d’échec humaine directe;
- gouvernance `attest_catalog_ar_translation`, `revoke_catalog_library_mandate` et `revoke_catalog_permission_policy`, réservées à une autorité centrale MFA et soumises à version attendue, idempotence, audit et Outbox. La révocation d’une politique globale produit une preuve de portée `PLATFORM` avec `organization_id = NULL`; aucun tenant d’audit n’est fourni par l’appelant;
- `begin_catalog_import`, `validate_catalog_import`, `commit_catalog_import`, `get_catalog_import_report`.

Les routes `/catalog/*` normatives du Gold Master sont des façades HTTP/Server Actions sur ces commandes : bibliothèques, catégories, sous-catégories, services, questions, import/export, validation/simulation, approbation/rejet et manifeste. Les listes exigent curseur, limite bornée, tri stable et filtres; l’export est asynchrone au-delà d’une limite configurable.

Les mutations sensibles écrivent dans la même transaction : changement métier, `audit_events`, `event_outbox` et résultat d’idempotence. Événements minimums : `CatalogImportValidatedV1`, `CatalogImportCommittedV1`, `CatalogChangeSubmittedV1`, `CatalogChangeApprovedV1`, `CatalogReleasePublishedV1`, `CatalogReleaseRolledBackV1`, `CatalogContentArchivedV1`, `QuestionnaireVersionPublishedV1`. Les événements ne contiennent ni réponse sensible, ni payload source intégral.

## FR/AR, accessibilité et contenu

- Tous noms, descriptions, labels, aides, raisons, options et messages publiés possèdent FR et AR validés.
- Le Builder permet saisie parallèle FR/AR, signale les traductions manquantes et interdit la publication incomplète.
- L’aperçu Client utilise `lang`, RTL natif, `dir="auto"` pour contenu libre, libellés associés, erreurs annoncées, navigation clavier, focus visible et reflow à 360 px.
- Les textes techniques peuvent avoir une version Client simplifiée sans perdre la version experte.
- Les contenus juridique, fiscal, assurance, HSE et réglementaire affichent leur état de revue; aucun texte généré n’est présenté comme validé avant revue experte.

## Recherche et performance

- Index B-tree sur codes, statuts, parentés, version publiée, release, bibliothèque/service, phase et rang.
- Index de recherche textuelle FR et AR adaptés à la configuration linguistique retenue; le choix de configuration est versionné et testé.
- Pagination keyset à tri stable pour services/questions; limites par défaut et maximales sont configurables.
- Le navigateur ne reçoit que le sous-ensemble bibliothèque/service/section requis. Prévisualisation et RFQ chargent progressivement les questions visibles/manquantes.
- Les budgets de performance sont mesurés sur 6 000 puis 50 000 questions avec données déterministes. Les seuils de latence, mémoire et taille de réponse sont configurables dans la politique de performance et bloquent la release lorsqu’ils sont dépassés.
- Les requêtes critiques possèdent plans examinés et tests évitant N+1, scan complet non filtré et chargement JSON excessif.

## Matrice de tests obligatoire

| Axe | Preuves minimales |
|---|---|
| Import | replay idempotent; compteurs recalculés; hashes; JSON/CSV invalide rapporté par ligne; transaction annulée si invalide |
| Intégrité | unicité; références; 10/40/80/200/212/5000/700/300; 25/70/30; liens primaire/secondaire |
| Versions | V1 historique inchangée après V2; publication atomique; supersession; rollback; parcours en cours figé |
| Archivage | suppression brouillon inutilisé autorisée; publié/utilisé archivé; mission active et récurrence bloquent l’archivage immédiat |
| Gouvernance | changement ordinaire autorisé selon permission; sensible envoyé au central; auto-approbation refusée; MFA central requis |
| RLS | ALLOW bibliothèque mandatée; DENY autre bibliothèque/tenant; DENY écriture directe; contenu non publié invisible |
| Questions | types et schémas structurés; requiredness; options; duplication; ordre; lien multi-service; suppression utilisée refusée |
| Règles | AND/OR/NOT; chaque opérateur/action; références absentes; cycles; branches mortes; regex bornée; score exact |
| Simulation | déterminisme/hash; résultat explicable; aucune statistique, anomalie, opportunité ou Outbox métier créée |
| RFQ | préremplissage; visibilité conditionnelle; progression; blocage si question pertinente obligatoire manque |
| I18n/a11y | exhaustivité FR/AR; RTL; clavier; lecteur d’écran; contraste; reflow 360 px |
| Performance | pagination 6 000; charge 50 000; recherche FR/AR; plans SQL; taille de réponse bornée |
| Régression | ancien diagnostic, RFQ, devis et contrat inchangés après nouvelle publication |

### Preuves de traçabilité par fonction

| Fonction | Preuves bloquantes du gate |
|---|---|
| MAT-FUNC-008 | texte ambigu puis questions manquantes; candidats justifiés; confirmation avant création; prompt adversarial sans fuite |
| MAT-FUNC-010 | bundle de deux bibliothèques; provenance des releases; déduplication déterministe; incompatibilité refusée |
| MAT-FUNC-040 | clone indépendant et traçable; historique du modèle inchangé; scope bibliothèque refusé hors mandat |
| MAT-FUNC-041 | ambiguïté/doublon/donnée connue détectés; suggestion rejetable; aucune publication automatique |
| MAT-FUNC-042 | candidats stables à version d’algorithme constante; revue humaine; question utilisée jamais supprimée |
| MAT-FUNC-044 | abandon/reprise; motif confidentiel invisible hors rôle; absence de payload sensible dans audit/Outbox |
| Sessions | autosave idempotent; conflit optimiste; réponse versionnée; soumission rejouée; ancien parcours figé |
| Release | audience/temps; collision de planification; lease concurrent; retry/failure/cancel; supersession et rollback reproductibles |
| Moteur | NULL/UNKNOWN, coercions, précision/arrondi, timezone/DST, priorité d’actions, canonicalisation/hash et limites runtime |

Chaque permission critique a au moins un test ALLOW et DENY. Les tests SQL/RLS, unitaires moteur, intégration import/publication, E2E Builder/aperçu, accessibilité, performance et audit sécurité sont exécutés par des propriétaires distincts du code audité.

## Gate P06

P06 devient GREEN seulement si une bibliothèque choisie par fixture de gate, sans traitement codé pour son code, accomplit : import validé → édition franchisée → validation locale → soumission → approbation centrale si sensible → publication planifiée ou immédiate → navigation Client → questionnaire RFQ ciblé → simulation déterministe → publication V2 → preuve qu’un parcours V1 reste inchangé → rollback audité.

Le gate exige aussi les volumes du manifeste réellement importés, une recherche paginée, les tests RLS cross-library, FR/AR RTL, accessibilité 360 px, performance 6 000/50 000, audit et Outbox sans doublon. Aucun bouton inactif, contenu incomplet ou règle fictive n’est accepté.
