# Inventaire PHASE 00

Date de contrôle : 2026-09-11. Autorité : Gold Master V4 FINAL.

## État observé

- 233 fichiers suivis par Git avant remédiation.
- Racine applicative : `apps/web` et `apps/worker`.
- Architecture partagée : 10 packages sous `packages/`.
- Base : 13 migrations additives et 6 suites SQL sous `supabase/`.
- Catalogue : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions; validation agrégée seulement.
- Skills projet actifs : 23 sous `.agents/skills/`; le dossier `skills/` racine est conservé pour compatibilité du package.
- Spécifications et mémoire : `docs/`, `specs/`, `PLANS.md`, `AGENTS.md` et le Gold Master.
- Configurations d’agents : 57 fichiers TOML sous `.codex/agents/`.
- Secrets locaux : `.env.local` présent, ignoré par Git et exclu de l’inventaire de valeurs.

## Décisions

| Chemin | Décision | Motif |
|---|---|---|
| `Matricia_GOLD_MASTER_PROMPT_UNIQUE_CODEX_V4_FINAL_2026-09-10.md` | KEEP / autorité | Source unique |
| `matricia_gold_v2/` | KEEP / référence historique | Ne prévaut jamais sur V4 |
| `catalogue/Matricia_Catalogue_Metier_V1/` | KEEP | Source catalogue canonique |
| `.agents/skills/` | KEEP / actif | Skills ciblés des agents |
| `skills/` | KEEP / compatibilité | Aucun déplacement destructif |
| `specs/` | KEEP / entrée package | Les specs exécutables vivent sous `docs/specs/` |
| `apps/`, `packages/`, `supabase/` | KEEP / actif | Socle V1 |
| artefacts `.next/`, `node_modules/` | REGENERATE | Sorties locales non sources |

Aucun fichier n’est supprimé ni remplacé silencieusement. Tout conflit futur doit privilégier la version finale la plus récente après comparaison et être journalisé.
