# ADR-0001 — Monolithe modulaire TypeScript

- Statut : accepté
- Date : 2026-09-10
- Autorité : Gold Master V4 FINAL

## Contexte

La V1 couvre 68 fonctions liées entre elles, avec des invariants multi-tenant, contractuels et financiers qui exigent des transactions cohérentes. Une architecture distribuée prématurée augmenterait les frontières réseau, les doubles écritures et le coût opérationnel.

## Décision

Construire un monorepo `pnpm` et un monolithe modulaire :

- `apps/web` : Next.js App Router, rendu et endpoints fins ;
- `apps/worker` : Outbox, tâches planifiées et adaptateurs asynchrones ;
- `packages/domain` : entités, value objects, invariants et événements, sans React/Next/Supabase ;
- `packages/application` : commandes, requêtes, autorisation et ports ;
- `packages/contracts` : Zod, DTO, erreurs et événements ;
- `packages/infrastructure` : Supabase, Storage, email, paiement, PDF, IA et observabilité ;
- `packages/ui`, `forms`, `workflows`, `config`, `observability`, `testkit` : responsabilités dédiées.

PostgreSQL reste la frontière transactionnelle. L’UI ne porte aucune logique métier critique et ne modifie aucune table sensible directement. Les écritures financières, pénalités, signatures et publications passent par des use cases serveur/RPC atomiques qui produisent audit et Outbox.

## Contraintes

- TypeScript strict avec dépendances dirigées `domain ← application ← infrastructure/apps`.
- Contrats explicites et statuts contrôlés ; aucun import d’infrastructure dans le domaine.
- Modules séparés par domaines métier, mais une seule base transactionnelle en V1.
- Intégrations externes derrière des ports remplaçables et des consommateurs idempotents.
- RLS restrictive constitue une seconde barrière ; elle ne remplace pas l’autorisation applicative.

## Conséquences

Avantages : transactions locales, déploiement reproductible, tests plus simples, partage de types et extraction future possible via les ports et l’Outbox. Coûts : discipline stricte sur les frontières, ownership explicite des fichiers partagés et worker dimensionné indépendamment de l’application Web.

Une extraction en service séparé ne sera envisagée qu’avec mesure de charge, exigence d’isolation ou cadence de déploiement incompatible, documentée dans un nouvel ADR.

