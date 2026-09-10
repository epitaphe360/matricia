# Architecture cible Matricia V1

## Principes

Monorepo `pnpm`, monolithe modulaire, Next.js App Router/React/TypeScript strict et Supabase PostgreSQL/Auth/Storage privé. Le web est destiné à Vercel ; le worker exécute outbox, jobs, cron et automatisations. La logique métier critique reste hors UI.

## Structure

```text
apps/{web,worker}
packages/{domain,application,contracts,infrastructure,ui,forms,workflows,config,observability,testkit}
supabase/{migrations,functions,seed}
tests/{e2e,security,performance}
docs/
artifacts/
```

## Frontières

- `domain` : entités, value objects, invariants, transitions, événements ; aucune dépendance React/Next/Supabase.
- `application` : commandes, requêtes, autorisation, transactions et ports.
- `contracts` : Zod, DTO, erreurs stables, événements et API.
- `infrastructure` : Supabase, stockage, email, paiements, IA, PDF et observabilité.
- `ui/forms/workflows` : présentation, formulaires dynamiques et machines d’état, sans calcul financier critique.
- Toute mutation sensible passe par un use case serveur transactionnel ; l’état, l’audit et `event_outbox` sont écrits atomiquement.

## Données et sécurité

- UUID, UTC `timestamptz`, devise ISO 4217, montants `bigint` en unités mineures, taux exacts/points de base ; aucun float financier.
- RLS restrictive et deny-by-default. Scopes organisation, bibliothèque et franchise dérivés côté serveur ; aucune donnée inter-tenant.
- Ledgers financiers/crédits append-only ; devis, contrats, questionnaires, règles, factures, services et SKU versionnés/immuables après publication ou signature.
- Toute mutation critique est idempotente, auditée et produit un événement Outbox ; webhooks signés, dédupliqués et rejouables avec dead-letter queue.
- TVA/fiscalité Maroc via règles datées, administrables et versionnées ; aucun taux hardcodé.
- Secrets validés dans le module de configuration, jamais loggés/committés ; `.env.local` reste hors Git.

## Qualité et expérience

Design Authority Version A — Moderne & Professionnelle, design system partagé, FR/AR RTL, accessibilité et parcours critiques à 360 px. Vitest, tests intégration, SQL/RLS, Playwright E2E, accessibilité, sécurité et performance sont obligatoires. Les ADR enregistrent les choix non imposés par le Gold Master.
