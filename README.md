# Matricia V1

Plateforme multi-tenant de diagnostic, conformité et mise en relation de services professionnels. Le périmètre et les règles d’autorité sont définis par le Gold Master V4 FINAL et `AGENTS.md`.

## Prérequis

- Node.js 22.13 ou supérieur
- Corepack avec pnpm 10.17.1
- Supabase CLI (installé dans le workspace)
- Docker Desktop pour les resets et tests PostgreSQL locaux

## Installation et développement

```powershell
corepack pnpm install
corepack pnpm dev
```

L’application web est dans `apps/web`, le processeur asynchrone dans `apps/worker`, les modules partagés dans `packages` et les migrations dans `supabase`.

## Gates courants

```powershell
corepack pnpm lint
corepack pnpm typecheck
corepack pnpm test
corepack pnpm build
corepack pnpm verify:phase00
corepack pnpm no-placeholders
```

Les tests SQL/RLS exigent une instance PostgreSQL Supabase locale ou development/staging explicitement autorisée. Aucun environnement de production ne doit être modifié sans autorisation explicite.

## Configuration

Copier les noms requis depuis `.env.example` vers `.env.local`. Ne jamais committer, afficher ou journaliser les valeurs de `.env.local`. L’état vérifié des phases se trouve dans `docs/progress/PROJECT_STATE.md`.
