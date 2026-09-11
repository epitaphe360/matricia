# Inventaire reproductible PHASE 00

Autorité : Gold Master V4 FINAL. Baseline auditée : commit `c7095510bc3143d54ace67549747be0e1fb461ea`.

## Commandes de reproduction

```powershell
git ls-tree -r --name-only c7095510bc3143d54ace67549747be0e1fb461ea
git ls-tree -r --name-only c7095510bc3143d54ace67549747be0e1fb461ea .codex/agents
git ls-tree -r --name-only c7095510bc3143d54ace67549747be0e1fb461ea .agents/skills
git check-ignore -v .env.local
```

## État versionné de la baseline

- 294 fichiers Git.
- 57 configurations TOML du corps principal; la remédiation suivante ajoute les 6 agents obligatoires Marketing, soit 63.
- 23 skills projet actifs sous `.agents/skills/`.
- 13 migrations et 6 suites SQL.
- 97 fichiers sources/configuration sous `apps/` hors sorties générées; 23 sous `packages/` hors dépendances.
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
