# Rapport d'acceptation

État : les corrections P0 intégrées et les gates automatisés exécutables sont verts. Le produit n'est pas déclaré « 100 % » en raison des résidus P1/P2 documentés dans `PROGRESS.md`.

| Scénario | Commande / preuve | Résultat |
|---|---|---|
| Inventaire du HEAD | `git status`, `git branch --show-current`, `git rev-parse --short HEAD`, inventaire des routes/actions | Base `0bfd967`, branche dédiée, changements utilisateur préservés |
| Tests workspace | `corepack pnpm test` | PASS — Web 182 fichiers / 755 tests ; Worker 54 ; packages 101 ; total 910 |
| TypeScript strict | `corepack pnpm typecheck` | PASS |
| Lint | `corepack pnpm lint` | PASS |
| Build production local | `corepack pnpm build` | PASS, sans déploiement |
| SQL/RLS/intégration/concurrence | `corepack pnpm test:db` | PASS — 149 fichiers, 3 488 assertions, 4 scénarios de concurrence |
| Migrations Supabase development | `supabase db push --linked --dry-run` | PASS — `upToDate: true`, aucune migration/seed/rôle en attente |
| Parcours publics FR/AR | Playwright public | PASS — 10/10, mobile 360 px et desktop, captures dans les artefacts |
| Parcours connectés multi-rôle | `node tests/e2e/helpers/v1-critical-flows-run.mjs` | PASS — 24/24, fixtures neutralisées |
| Isolation et autorisations | SQL/RLS + requêtes négatives E2E | PASS sur les scénarios automatisés couverts |
| Gate structurel / catalogue | `corepack pnpm release:validate` + `corepack pnpm no-placeholders` | PASS — 10 bibliothèques, 200 services, 6 000 questions, aucun marqueur incomplet ; P01 ouverte et traçabilité 1/76 VERIFIED signalées |
| Revue visuelle authentifiée exhaustive | 390/768/1440, zoom 200 %, tous modules | Partielle ; à compléter manuellement |

Les avertissements `grant_pg_net_access` / `grant_pg_cron_access` observés pendant certains fixtures sont des grants déjà absents, pas des échecs ; toutes les assertions correspondantes passent.
