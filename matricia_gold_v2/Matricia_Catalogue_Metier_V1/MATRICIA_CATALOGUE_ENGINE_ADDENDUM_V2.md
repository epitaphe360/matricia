# ADDENDUM GOLD MASTER — CATALOGUE MÉTIER, SERVICES ET 6 000 QUESTIONS

Cet addendum est **normatif**. Il remplace toute instruction antérieure qui demandait seulement à Codex « d’inventer au moins 900 questions » ou « 15 services par bibliothèque ». Codex doit utiliser la base déterministe fournie par `matricia_catalog_build.py`, l’importer, la traduire en arabe, la tester, puis permettre aux franchisés de la faire évoluer sans modifier le code.

## 1. Résultat obligatoire

La V1 démarre avec :

- 10 bibliothèques actives ;
- 40 grandes catégories ;
- 80 sous-catégories ;
- 200 services actifs ;
- 5 000 questions de cadrage permettant de rendre les demandes chiffrables, soit 25 par service ;
- 700 questions de diagnostic client, soit 70 par bibliothèque ;
- 300 questions de qualification fournisseur, soit 30 par bibliothèque ;
- 6 000 questions au total avant toute création supplémentaire par les franchisés ;
- 212 liens service–sous-catégorie, car certains services peuvent être classés dans plusieurs sous-catégories ;
- une bibliothèque supplémentaire « Opérations, productivité et transformation » fournie comme modèle optionnel mais non activée dans les dix bibliothèques initiales.

Le validateur de release échoue si ces minimums ne sont pas atteints, si un identifiant est dupliqué, si un lien pointe vers un service absent, si une traduction obligatoire manque ou si un placeholder apparaît.

## 2. Bibliothèques initiales

1. `IT` — Informatique, cybersécurité et data.
2. `COM` — Communication, marketing et création.
3. `ACC` — Comptabilité, fiscalité et finance.
4. `LEGAL` — Juridique, conformité et gouvernance.
5. `HR` — Ressources humaines et formation.
6. `INS` — Assurance et gestion des risques.
7. `LOG` — Achats, logistique et supply chain.
8. `BTP` — BTP, immobilier et maintenance.
9. `QHSE` — Qualité, HSE et certifications.
10. `SALES` — Commercial, vente et expérience client.

La liste est une configuration initiale, pas une limite structurelle. Un Super Admin peut créer une onzième bibliothèque et lui affecter un franchisé sans migration du code.

## 3. Hiérarchie de contenu

```text
BIBLIOTHÈQUE
  └── GRANDE CATÉGORIE
       └── SOUS-CATÉGORIE
            └── SERVICE
                 ├── QUESTIONS DIAGNOSTIC
                 ├── QUESTIONS POUR PRÉPARER LE DEVIS/RFQ
                 ├── QUESTIONS DE QUALIFICATION FOURNISSEUR
                 ├── DOCUMENTS REQUIS
                 ├── LIVRABLES
                 ├── PREUVES
                 ├── CRITÈRES D’ACCEPTATION
                 ├── RÈGLES DE MATCHING
                 ├── CLAUSES ET INCIDENTS
                 ├── AVANTAGES/BOXES/CRÉDITS
                 └── ACHATS EN VOLUME/SKU ÉVENTUELS
```

Un service possède une sous-catégorie principale et peut avoir plusieurs sous-catégories secondaires. L’interface client n’affiche pas de doublon : un même service garde un ID unique.

## 4. Objet Bibliothèque

Champs minimums :

```text
id uuid
code text unique
slug text unique
name_fr text
name_ar text
description_fr text
description_ar text
icon_key text
cover_asset_id uuid nullable
status enum(DRAFT, IN_REVIEW, ACTIVE, PAUSED, ARCHIVED)
current_version_id uuid
franchise_id uuid nullable
sort_order integer
published_at timestamptz nullable
created_by uuid
created_at timestamptz
updated_at timestamptz
archived_at timestamptz nullable
```

Actions franchisé autorisées dans sa bibliothèque : modifier les contenus non sensibles, proposer une nouvelle version, gérer l’ordre d’affichage, catégories, sous-catégories, services et questionnaires.

Actions réservées au central : affecter/changer le franchisé, modifier les règles économiques, publier un changement sensible, suspendre la bibliothèque, modifier les droits globaux.

## 5. Objets Catégorie et Sous-catégorie

Chaque objet est versionné et possède : code, nom FR/AR, description FR/AR, ordre, statut, bibliothèque, parent, icône et règles de visibilité.

Le franchisé peut :

- ajouter une catégorie ou sous-catégorie ;
- renommer ;
- déplacer ;
- réordonner par glisser-déposer ;
- fusionner après simulation des impacts ;
- archiver ;
- restaurer une version ;
- importer/exporter.

Une catégorie utilisée historiquement ne peut pas être supprimée physiquement.

## 6. Objet Service

Champs minimums :

```text
id uuid
library_id uuid
primary_subcategory_id uuid
code text unique
slug text
name_fr text
name_ar text
short_description_fr text
short_description_ar text
long_description_fr text
long_description_ar text
service_type enum
status enum(DRAFT, IN_REVIEW, ACTIVE, PAUSED, ARCHIVED)
current_version_id uuid
unit_label_fr text
unit_label_ar text
credit_eligible boolean
volume_eligible boolean
recurring_eligible boolean
trial_eligible boolean
rfq_required boolean
fixed_fulfillment_allowed boolean
base_currency text
sort_order integer
created_by uuid
published_at timestamptz nullable
archived_at timestamptz nullable
```

Chaque version de service stocke aussi :

- livrables standards ;
- exclusions standards ;
- critères de réception ;
- preuves obligatoires ;
- nombre/règles de correction ;
- documents client nécessaires ;
- documents fournisseur nécessaires ;
- règles de qualification ;
- règles de matching ;
- modèle de devis ;
- champs `required_for_quote` ;
- SLA par défaut ;
- clauses de bibliothèque/service ;
- règles d’incident ;
- disponibilité dans les plans et Boxes ;
- coût en crédits ;
- coûts fournisseurs ;
- SKU et contrats volume éventuels.

## 7. Contrôle total du nombre de services

Aucun nombre de services n’est codé en dur. Le franchisé autorisé dispose de :

- `+ Nouveau service` ;
- `Dupliquer ce service` ;
- `Importer des services` ;
- `Modifier` ;
- `Déplacer` ;
- `Mettre en pause` ;
- `Archiver` ;
- `Proposer la publication` ;
- `Comparer les versions` ;
- `Restaurer une version`.

Le franchisé peut passer de 20 à 50 services ou revenir à 18 services actifs. Les anciens diagnostics, demandes, devis, contrats et factures continuent à référencer la version historique.

### Suppression

- Service jamais publié et jamais référencé : suppression physique autorisée pour son auteur.
- Service publié ou utilisé : uniquement archivage.
- Archivage avec missions actives : interdit ; proposer une date de fin et conserver l’accès aux dossiers en cours.
- Service avec contrats récurrents : migration ou extinction contrôlée obligatoire.

## 8. Objet Question

Une question ne se résume pas à un texte. Elle contient :

```text
id uuid
question_key text unique
scope enum(GLOBAL, LIBRARY, CATEGORY, SUBCATEGORY, SERVICE)
phase enum(PROFILE, COMPLIANCE, DIAGNOSTIC, RFQ, PROVIDER_QUALIFICATION,
           QUOTE, DELIVERY, ACCEPTANCE, INCIDENT, FOLLOW_UP)
library_id uuid nullable
service_id uuid nullable
section_id uuid
current_version_id uuid
status enum(DRAFT, IN_REVIEW, ACTIVE, PAUSED, ARCHIVED)
created_by uuid
```

Chaque version contient :

```text
label_fr text
label_ar text
help_fr text
help_ar text
why_we_ask_fr text
why_we_ask_ar text
answer_type enum
required boolean
required_for_quote boolean
required_for_publication boolean
data_key text
options jsonb
validation_schema jsonb
visibility_rule jsonb
default_value jsonb nullable
prefill_source jsonb nullable
sensitivity enum(PUBLIC, BUSINESS, CONFIDENTIAL, RESTRICTED)
weight numeric
max_score numeric
anomaly_links jsonb
risk_links jsonb
recommendation_links jsonb
opportunity_links jsonb
document_requirement_links jsonb
sort_order integer
change_reason text
```

## 9. Types de questions

Supporter au minimum :

```text
YES_NO
SINGLE_CHOICE
MULTIPLE_CHOICE
SHORT_TEXT
LONG_TEXT
INTEGER
DECIMAL
PERCENTAGE
MONEY
CURRENCY
DATE
DATE_RANGE
TIME
EMAIL
PHONE
URL
ADDRESS
GEO_AREA
RATING_5
RATING_10
QUANTITY
UNIT_VALUE
FILE
MULTI_FILE
IMAGE
TABLE
REPEATER
CONTACT
ORGANIZATION
PRODUCT_LIST
SITE_LIST
MILESTONE_LIST
BUDGET_BREAKDOWN
```

Les types structurés utilisent un schéma JSON versionné. Par exemple `TABLE` doit définir colonnes, types, validations, minimum et maximum de lignes.

## 10. Les 25 questions RFQ par service

Chaque service initial reçoit :

### Questions universelles

1. objectif métier ;
2. situation actuelle ;
3. périmètre quantitatif ;
4. sites/localisation ;
5. parties prenantes ;
6. livrables ;
7. documents/données disponibles ;
8. dépendances/intégrations ;
9. contraintes réglementaires, sécurité ou confidentialité ;
10. calendrier et jalons ;
11. budget ;
12. critères d’acceptation ;
13. support/formation/maintenance ;
14. modalités de paiement souhaitées ;
15. contraintes particulières.

### Questions propres au service

16 à 20 : cinq dimensions métier propres au service, inscrites dans le blueprint.

### Questions propres au type de prestation

21 à 25 : cinq questions adaptées à l’archétype Audit, Implémentation, Logiciel, Création, Service récurrent, Juridique, Finance, RH, Assurance, Achats, Construction, Formation ou Étude.

Le formulaire final ne doit pas systématiquement montrer 25 questions d’un seul coup. Le moteur :

- préremplit les données connues ;
- masque les questions non pertinentes ;
- affiche les sections progressivement ;
- autorise le franchisé à rendre une question facultative ou conditionnelle ;
- calcule la complétude ;
- interdit l’envoi si un champ bloquant manque.

## 11. Questions diagnostic et qualification

Chaque bibliothèque initiale possède :

- 10 questions de maturité transversales ;
- 3 questions de diagnostic par service, soit 60 ;
- total diagnostic : 70 ;
- 10 questions de qualification fournisseur transversales ;
- 1 question structurée de compétence/références/capacité par service, soit 20 ;
- total qualification : 30.

La base peut être enrichie sans limite. Le franchisé peut ajouter un diagnostic spécialisé ou un questionnaire distinct par secteur, taille, type juridique, site ou plan d’abonnement.

## 12. CRUD Questions par le franchisé

Écrans :

```text
FR-Q-001 Liste des questionnaires
FR-Q-002 Constructeur de questionnaire
FR-Q-003 Banque de questions
FR-Q-004 Éditeur de question
FR-Q-005 Éditeur d’options
FR-Q-006 Rule Builder
FR-Q-007 Scoring/anomalies/recommandations
FR-Q-008 Prévisualisation client
FR-Q-009 Simulation complète
FR-Q-010 Comparaison de versions
FR-Q-011 Import/export
FR-Q-012 Historique et audit
```

Actions :

- créer ;
- modifier ;
- dupliquer ;
- réordonner ;
- déplacer de section ;
- lier/délier à plusieurs services ;
- convertir en question globale ;
- rendre conditionnelle ;
- ajouter une option ;
- modifier la validation ;
- ajouter une traduction ;
- mettre en pause ;
- archiver ;
- restaurer ;
- tester ;
- soumettre pour approbation ;
- publier selon permission.

Une question utilisée n’est jamais supprimée physiquement. Une nouvelle version est créée à chaque modification publiée.

## 13. Rule Builder

Opérateurs : égal, différent, supérieur, inférieur, dans liste, contient, vide, non vide, correspondance regex contrôlée, date avant/après, changement depuis réponse précédente.

Groupes : `AND`, `OR`, `NOT`, groupes imbriqués.

Actions :

- afficher/masquer question ou section ;
- rendre obligatoire/facultatif ;
- calculer score ;
- créer anomalie/risque ;
- créer recommandation ;
- créer opportunité ;
- associer un niveau de solution ;
- demander un document ;
- exiger contrôle humain ;
- bloquer la publication ou l’envoi RFQ ;
- suggérer un service complémentaire ;
- lancer un diagnostic enfant ;
- définir la durée de validité de la réponse.

Le moteur refuse les cycles infinis, références absentes et branches mortes. Les familles standardisées utilisent `template_key` afin que les répétitions volontaires (objectif, calendrier, budget, réception, etc.) soient reconnues comme des modèles partagés et non comme des doublons accidentels.

## 14. Gouvernance et approbations

Le franchisé peut publier directement les changements ordinaires si son contrat/permission l’autorise. Approbation centrale obligatoire pour :

- règle financière ou crédit ;
- avantage Box ;
- commission ;
- pénalité ;
- clause contractuelle ;
- texte juridique/réglementaire présenté comme obligatoire ;
- anomalie bloquant un client ;
- règle pouvant suspendre un sous-traitant ;
- modification importante du scoring ;
- suppression/fusion ayant un impact historique ;
- contrat-cadre ou engagement de volume.

Chaque approbation possède auteur, examinateur, comparaison avant/après, commentaire, date et preuve d’audit.

## 15. Cycle de publication

```text
DRAFT
→ LOCAL_TEST
→ FRANCHISE_REVIEW
→ CENTRAL_REVIEW si nécessaire
→ APPROVED
→ SCHEDULED
→ PUBLISHED
→ SUPERSEDED ou ARCHIVED
```

Un questionnaire déjà commencé reste attaché à sa version. La publication d’une V2 n’altère jamais un diagnostic V1 en cours ou terminé.

## 16. Import automatique

Codex doit :

1. extraire `matricia_catalog_build.py` depuis le prompt ou utiliser le fichier livré ;
2. exécuter le script ;
3. vérifier le manifeste ;
4. générer les traductions arabes par lots et les auditer ;
5. charger les CSV/JSONL dans des tables de staging ;
6. exécuter des contrôles de doublons et de références ;
7. publier une version `MATRICIA_GOLD_MASTER_BASELINE_V1` ;
8. conserver la source et le hash de chaque fichier ;
9. rendre l’opération idempotente ;
10. permettre un reset complet des données de démonstration sans supprimer les configurations de production.

## 17. Traductions FR/AR

La source fournie est française. Avant release :

- chaque bibliothèque, catégorie, sous-catégorie, service, question, aide, option, anomalie, risque et recommandation possède une version arabe ;
- un agent traduction produit les textes ;
- un second agent vérifie sens, terminologie, RTL et absence de texte français résiduel ;
- le validateur bloque si un champ arabe obligatoire est vide ;
- les contenus juridiques/fiscaux/HSE/assurance sont marqués `EXPERT_REVIEW_REQUIRED` jusqu’à validation métier.

## 18. APIs/commandes minimales

```text
POST   /catalog/libraries
PATCH  /catalog/libraries/:id
POST   /catalog/libraries/:id/publish
POST   /catalog/categories
PATCH  /catalog/categories/:id
POST   /catalog/subcategories
PATCH  /catalog/subcategories/:id
POST   /catalog/services
PATCH  /catalog/services/:id
POST   /catalog/services/:id/duplicate
POST   /catalog/services/:id/archive
POST   /catalog/services/:id/restore
POST   /catalog/services/:id/publish
GET    /catalog/services/:id/impact
POST   /catalog/questions
PATCH  /catalog/questions/:id
POST   /catalog/questions/:id/duplicate
POST   /catalog/questions/:id/archive
POST   /catalog/questions/:id/publish
POST   /catalog/questions/bulk-import
GET    /catalog/questions/export
POST   /catalog/questionnaires/:id/simulate
POST   /catalog/questionnaires/:id/validate
POST   /catalog/change-requests/:id/approve
POST   /catalog/change-requests/:id/reject
POST   /catalog/baseline/import
GET    /catalog/baseline/manifest
```

Toutes les mutations utilisent validation serveur, permissions, audit et idempotence lorsque nécessaire.

## 19. Écrans administrateur central

```text
ADM-CAT-001 Vue globale des 10 bibliothèques
ADM-CAT-002 Santé du catalogue
ADM-CAT-003 Changements en attente
ADM-CAT-004 Comparaison avant/après
ADM-CAT-005 Contrôle des traductions
ADM-CAT-006 Doublons et incohérences
ADM-CAT-007 Services sans fournisseur
ADM-CAT-008 Services sans questionnaire complet
ADM-CAT-009 Questions sans action/règle
ADM-CAT-010 Publication et rollback
ADM-CAT-011 Import/export
ADM-CAT-012 Audit catalogue
```

Indicateurs : nombre de services actifs, questions, diagnostics, formulaires incomplets, services sans sous-traitant, taux de conversion par question, taux d’abandon, questions jamais affichées, doublons, traductions manquantes et contenu à revoir.

## 20. Expérience client

Le client ne navigue pas dans une liste plate de 200 services et ne répond pas à 6 000 questions.

Matricia :

- utilise son Passeport entreprise ;
- pose d’abord les questions globales ;
- affiche une bibliothèque adaptée ;
- utilise les règles conditionnelles ;
- ne pose que les questions pertinentes ;
- sauvegarde automatiquement ;
- indique la progression ;
- explique pourquoi une question est demandée ;
- préremplit les réponses connues ;
- transforme les résultats en anomalies, recommandations et opportunités ;
- au clic « Demander des devis », affiche uniquement les questions RFQ encore manquantes pour le service choisi.

## 21. Recherche, filtres et performance

Le catalogue doit permettre recherche plein texte et filtres par : bibliothèque, catégorie, sous-catégorie, service, type, statut, auteur, traduction, plan, crédit, volume, date et version.

Index obligatoires sur codes, statuts, relations, version courante et recherche textuelle. Les 6 000 instances de questions ne doivent pas être chargées dans le navigateur. Utiliser pagination/virtualisation et requêtes ciblées.

## 22. Tests obligatoires

- Import initial idempotent.
- Comptages exacts du manifeste.
- Aucun identifiant dupliqué.
- Aucun service sans catégorie/sous-catégorie.
- Aucune sous-catégorie sans service primaire ou secondaire.
- 25 questions RFQ par service initial.
- 70 questions diagnostic et 30 qualification par bibliothèque.
- Création d’un nouveau service par franchisé.
- Ajout, modification, duplication et archivage d’une question.
- Blocage de suppression d’une question utilisée.
- Version historique conservée après publication V2.
- Changement sensible envoyé au central.
- RLS : un franchisé ne modifie pas une autre bibliothèque.
- Super Admin voit et restaure une version.
- Arabe complet et affichage RTL.
- Simulation sans effet sur les statistiques réelles.
- Import CSV invalide rejeté ligne par ligne avec rapport.
- Formulaire RFQ bloqué tant que les questions obligatoires pertinentes ne sont pas complètes.
- Ancien devis/contrat inchangé après modification du service.
- Performance acceptable avec 6 000 questions et croissance à 50 000.

## 23. Definition of Done spécifique

Le module Catalogue n’est terminé que lorsque :

1. les 10 bibliothèques et 200 services sont visibles et navigables ;
2. les 6 000 questions sont importées ;
3. les formulaires RFQ sont réellement générés par service ;
4. le franchisé peut ajouter, modifier, dupliquer, réordonner, désactiver et archiver ;
5. le franchisé peut changer le nombre de services actifs ;
6. le versionnage et l’audit fonctionnent ;
7. la validation centrale fonctionne pour les changements sensibles ;
8. toutes les traductions FR/AR requises sont présentes ;
9. les tests de sécurité, RLS, performance et E2E passent ;
10. aucun `TODO`, `TO_DEFINE`, écran vide ou bouton inactif n’existe.

## 24. Limite honnête et mécanisme d’extension

Les 6 000 questions constituent une base de production très large et bien supérieure au minimum demandé. Elles ne peuvent pas représenter littéralement toutes les questions imaginables dans toutes les futures variantes de mission. La couverture réellement complète repose donc sur deux éléments réunis :

1. une base initiale étendue, structurée et importée automatiquement ;
2. un moteur sans limite permettant au franchisé d’ajouter, corriger, retirer, versionner et tester les contenus de son domaine.

Codex ne doit jamais remplacer cette base par du contenu générique improvisé sans traçabilité.
