# Catalogue métier Matricia V1 — base Gold Master

Ce dossier remplace l'exigence vague « créer au moins 900 questions » par une base déterministe et importable.

## Contenu validé

- Bibliothèques : **10**
- Grandes catégories : **40**
- Sous-catégories : **80**
- Services actifs : **200**
- Questions de cadrage RFQ/devis : **5000**
- Questions de diagnostic : **700**
- Questions de qualification sous-traitant : **300**
- Total questions : **6000**

Chaque service contient exactement 25 questions de cadrage pour rendre une demande chiffrable. Chaque bibliothèque contient 70 questions de diagnostic et 30 questions de qualification fournisseur.

## Gouvernance franchisé

Le franchisé peut :

- créer, dupliquer, modifier, réordonner, désactiver ou archiver une question ;
- créer, modifier, déplacer, désactiver ou archiver un service ;
- ajouter ou retirer des catégories ;
- importer/exporter CSV/JSON ;
- prévisualiser et simuler un questionnaire ;
- publier une nouvelle version selon ses permissions.

Une question ou un service déjà utilisé n'est jamais supprimé physiquement : il est archivé et sa version historique reste attachée aux diagnostics, demandes, devis et contrats existants. Les changements financiers, juridiques, bloquants ou contractuels exigent une approbation centrale Matricia.

## Fichiers

- `libraries.csv`
- `categories.csv`
- `subcategories.csv`
- `services.csv`
- `service_subcategory_links.csv`
- `questions_rfq.csv`
- `questions_diagnostic.csv`
- `questions_provider_qualification.csv`
- `questions_all.jsonl`
- `catalog_manifest.json`
- `optional_library_operations.json` (bibliothèque supplémentaire proposée mais non activée dans les dix de base)

## Important

Cette base est très étendue, mais aucun catalogue fini ne peut anticiper toutes les variantes futures de chaque métier. Le moteur CRUD/versionné est donc obligatoire. Avant production, les contenus juridiques, fiscaux, assurance, HSE et réglementaires doivent être revus par les experts du domaine concerné.
