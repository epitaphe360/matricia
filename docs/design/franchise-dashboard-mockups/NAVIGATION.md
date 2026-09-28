# Navigation complète — espace Franchisé

Les chemins ci-dessous décrivent les destinations fonctionnelles attendues. Le préfixe `/{locale}` vaut `/fr` ou `/ar`.

Références maquettes (PNG dans ce dossier) :

| Route | Maquette |
|-------|----------|
| Accueil | `00`, mobile `22`, AR `21` |
| File de travail | `04` |
| Bibliothèque | `05` |
| Services / constructeur | `01`, `06` |
| Questionnaires / constructeur / aperçu | `02`, `07`, `08` |
| Règles / simulation | `03`, `09` |
| Validations | `10` |
| Fournisseurs / dossier | `11`, `12` |
| Demandes / matching | `13`, `14` |
| Qualité | `15` |
| Performance | `16` |
| Relances / pipeline | `17` |
| Gouvernance | `18` |
| Documents | `19` |
| Messages | `20` |

## Accueil

- Accueil : `/{locale}/franchise/accueil` (alias racine : `/{locale}/franchise`)
- File de travail : `/{locale}/franchise/actions`
- Activité récente : `/{locale}/franchise/activite`

## Ma bibliothèque

- Vue de la bibliothèque mandatée : `/{locale}/franchise/bibliotheque`
- Catégories et sous-catégories : `/{locale}/franchise/bibliotheque/categories`
- Version publiée : `/{locale}/franchise/bibliotheque/version`
- Historique immuable : `/{locale}/franchise/bibliotheque/historique`

## Services

- Liste : `/{locale}/franchise/services`
- Nouveau brouillon : `/{locale}/franchise/services/nouveau`
- Détail : `/{locale}/franchise/services/[serviceId]`
- Version et provenance : `/{locale}/franchise/services/[serviceId]/versions`
- Simulation : `/{locale}/franchise/services/[serviceId]/simulation`
- Soumission à Matricia : `/{locale}/franchise/services/[serviceId]/validation`

## Questions et questionnaires

- Questionnaires : `/{locale}/franchise/questionnaires`
- Nouveau questionnaire : `/{locale}/franchise/questionnaires/nouveau`
- Constructeur : `/{locale}/franchise/questionnaires/[questionnaireId]`
- Questions : `/{locale}/franchise/questions`
- Aperçu Client : `/{locale}/franchise/questionnaires/[questionnaireId]/apercu`
- Test des branches : `/{locale}/franchise/questionnaires/[questionnaireId]/simulation`
- Versions : `/{locale}/franchise/questionnaires/[questionnaireId]/versions`
- Soumission : `/{locale}/franchise/questionnaires/[questionnaireId]/validation`

## Règles

- Liste : `/{locale}/franchise/regles`
- Nouvelle règle : `/{locale}/franchise/regles/nouvelle`
- Constructeur : `/{locale}/franchise/regles/[ruleId]`
- Simulation sans effet : `/{locale}/franchise/regles/[ruleId]/simulation`
- Versions et conflits : `/{locale}/franchise/regles/[ruleId]/versions`
- Soumission : `/{locale}/franchise/regles/[ruleId]/validation`

## Validations

- Brouillons à soumettre : `/{locale}/franchise/validations/brouillons`
- Soumissions en cours : `/{locale}/franchise/validations/en-cours`
- Corrections demandées : `/{locale}/franchise/validations/corrections`
- Éléments approuvés : `/{locale}/franchise/validations/approuves`
- Publications : `/{locale}/franchise/validations/publications`
- Historique : `/{locale}/franchise/validations/historique`

## Fournisseurs

- Réseau limité à la bibliothèque : `/{locale}/franchise/fournisseurs`
- Dossier : `/{locale}/franchise/fournisseurs/[providerId]`
- Qualification par service : `/{locale}/franchise/fournisseurs/[providerId]/qualification`
- Capacité et disponibilité : `/{locale}/franchise/fournisseurs/[providerId]/capacite`
- Documents : `/{locale}/franchise/fournisseurs/[providerId]/documents`

## Demandes

- Demandes du périmètre : `/{locale}/franchise/demandes`
- Détail : `/{locale}/franchise/demandes/[requestId]`
- Matching : `/{locale}/franchise/demandes/[requestId]/matching`
- Consultation : `/{locale}/franchise/demandes/[requestId]/consultation`
- Suivi : `/{locale}/franchise/demandes/[requestId]/suivi`

## Qualité

- Tableau qualité : `/{locale}/franchise/qualite`
- Revues : `/{locale}/franchise/qualite/revues`
- Non-conformités : `/{locale}/franchise/qualite/non-conformites`
- Plans correctifs : `/{locale}/franchise/qualite/actions`

## Performance

- Vue d’ensemble : `/{locale}/franchise/performance`
- Indicateurs : `/{locale}/franchise/performance/indicateurs`
- Services et fournisseurs : `/{locale}/franchise/performance/reseau`
- Tendances : `/{locale}/franchise/performance/tendances`

## Relances

- Relances dues : `/{locale}/franchise/relances`
- Pipeline : `/{locale}/franchise/relances/pipeline`
- Résumé quotidien : `/{locale}/franchise/digest`
- Historique : `/{locale}/franchise/relances/historique`

## Documents et messages

- Documents : `/{locale}/franchise/documents`
- Renouvellements : `/{locale}/franchise/documents/renouvellements`
- Messages : `/{locale}/franchise/messages`
- Notifications : `/{locale}/franchise/notifications`

## Gouvernance

- Mandat actif : `/{locale}/franchise/gouvernance`
- Périmètre et bibliothèque : `/{locale}/franchise/gouvernance/perimetre`
- Approbations : `/{locale}/franchise/gouvernance/approbations`
- Historique : `/{locale}/franchise/gouvernance/historique`

## Contrôles obligatoires

- Aucun `libraryId`, `serviceId`, `providerId` ou `requestId` transmis par l’interface ne constitue une autorisation.
- Toutes les lectures et mutations sont revalidées côté serveur et par RLS contre la bibliothèque du mandat actif.
- Une URL directe vers une autre bibliothèque doit retourner un refus sans révéler son existence.
- Les compteurs, recherches, exports, documents et caches utilisent le même périmètre.
