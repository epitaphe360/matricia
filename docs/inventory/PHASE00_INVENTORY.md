# Inventaire reproductible PHASE 00

Autorité : Gold Master V4 FINAL. Baseline auditée : commit `d9e28f7`.

## Commandes de reproduction

```powershell
$files = git ls-tree -r --name-only d9e28f7
$files.Count
($files | Where-Object { $_ -like 'apps/*' }).Count
($files | Where-Object { $_ -like 'apps/web/*' }).Count
($files | Where-Object { $_ -like 'apps/worker/*' }).Count
($files | Where-Object { $_ -like 'packages/*' }).Count
($files | Where-Object { $_ -like '.codex/agents/*.toml' }).Count
($files | Where-Object { $_ -like '.agents/skills/*/SKILL.md' }).Count
($files | Where-Object { $_ -like 'supabase/migrations/*.sql' }).Count
($files | Where-Object { $_ -like 'supabase/tests/*.sql' }).Count
git check-ignore -v .env.local
```

## État versionné de la baseline

- 300 fichiers Git.
- 63 configurations TOML : 57 agents principaux et 6 agents Marketing obligatoires.
- 23 skills projet actifs sous `.agents/skills/`.
- 13 migrations et 6 suites SQL.
- 95 fichiers sous `apps/` : 92 Web et 3 Worker; 23 sous `packages/`.
- Catalogue validé : 10 bibliothèques, 200 services et 6 000 questions.
- `.env.local` ignoré et non suivi; aucune valeur n’est inventoriée.

Les dossiers locaux vides `skills/` et `specs/` ne figurent pas dans Git et ne sont pas des sources actives. Les chemins canoniques sont `.agents/skills/` et `docs/specs/`.

## Décisions keep/replace

| Chemin versionné | Décision | Motif |
|---|---|---|
| Gold Master V4 FINAL, `AGENTS.md`, `PLANS.md` | KEEP / autorité | Mémoire permanente |
| `matricia_gold_v2/` | KEEP / archive | Ne prévaut jamais sur V4 |
| `catalogue/Matricia_Catalogue_Metier_V1/` | KEEP / canonique | Source catalogue |
| `.agents/skills/`, `.codex/agents/` | KEEP / actif | Contexte et rôles ciblés |
| `apps/`, `packages/`, `supabase/` | KEEP / actif | Produit, domaines et données |
| `docs/`, `scripts/`, `.github/` | KEEP / actif | Contrats, gates et CI |
| `.next/`, `node_modules/` | REGENERATE / non versionné | Sorties locales |

Aucun conflit de nom ni remplacement destructif n’a été observé dans la remédiation. Toute collision future doit être comparée, attribuée à un propriétaire et journalisée avant écriture.
