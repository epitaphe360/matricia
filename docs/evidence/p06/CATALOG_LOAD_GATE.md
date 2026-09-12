# P06 — gate de charge catalogue 6k/50k

Ce gate reproductible lit uniquement la colonne de keyset d'une vue Supabase dédiée. Il n'écrit aucune donnée, borne chaque page à 1 000 lignes, s'arrête à 50 000 lignes et refuse toute cible qui n'est pas déclarée `development` ou `staging` et vérifiée par son project ref.

## Préconditions

- La vue RLS `catalog_questions_perf` expose uniquement une clé stable `id`, sans texte de question ni contenu métier.
- La clé publique utilisée possède seulement le droit `SELECT` sur cette vue dans l'environnement non productif.
- `MATRICIA_PERF_EXPECTED_PROJECT_REF` est renseigné séparément et correspond exactement au host de `SUPABASE_URL`.
- Si le project ref de production est connu localement, renseigner aussi `MATRICIA_PRODUCTION_PROJECT_REF`; le gate le refusera même si l'environnement est mal étiqueté.

Les valeurs restent dans l'environnement local/CI et ne doivent jamais être committées ni copiées dans une preuve.

## Exécution

```powershell
$env:MATRICIA_PERF_ENV = 'staging'
$env:MATRICIA_PERF_EXPECTED_PROJECT_REF = '<project-ref-staging>'
$env:MATRICIA_PRODUCTION_PROJECT_REF = '<project-ref-production>'
$env:SUPABASE_URL = 'https://<project-ref-staging>.supabase.co'
$env:SUPABASE_ANON_KEY = '<clé publique restreinte>'
$env:MATRICIA_PERF_RESOURCE = 'catalog_questions_perf'
node scripts/performance/catalog-load-gate.mjs
```

Le résultat JSON standard ne contient ni URL, ni project ref, ni clé, ni identifiant lu, ni contenu de question. Il contient seulement les volumes, nombre de pages, latences, débit et verdict. Le code de sortie est non nul si les 6 000 ou 50 000 lignes ne sont pas disponibles, si le p95 dépasse 1 500 ms, ou si une protection échoue.

Variables optionnelles :

- `MATRICIA_PERF_KEY_COLUMN` (défaut `id`)
- `MATRICIA_PERF_PAGE_SIZE` (défaut `500`, maximum `1000`)
- `MATRICIA_PERF_SIZES` (défaut `6000,50000`, maximum absolu `50000`)
- `MATRICIA_PERF_TIMEOUT_MS` (défaut `15000`, maximum `120000`)
- `MATRICIA_PERF_MAX_P95_MS` (défaut `1500`)

## Tests locaux sans réseau

```powershell
node --test scripts/performance/catalog-load-gate.test.mjs
```

Les tests simulent PostgREST et prouvent le refus production, la vérification exacte de cible, les bornes, les GET keyset, l'absence de secrets dans le résumé et l'échec fermé sur réponse invalide/incomplète.

