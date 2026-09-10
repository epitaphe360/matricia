# Matricia — Project State

Dernière mise à jour : 2026-09-10 13:35 America/Toronto  
Phase de contrôle active : **PHASE 00 — gate automatisé vert, signature indépendante en attente**  
Travaux engagés : **PHASES 01, 02 et 03 — en cours, non signées**

## État prouvé

- Autorité : Gold Master V4 FINAL et règles permanentes `AGENTS.md` présents à la racine.
- Catalogue validé par `pnpm catalog:validate` : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions, sans chargement intégral hors validation.
- Registres Phase 00 initialisés : écrans, formulaires, permissions, API/commandes, événements, notifications et state machines.
- Traçabilité initialisée pour `MAT-FUNC-001` à `MAT-FUNC-068`; aucune fonction n’est encore déclarée livrée sans preuve.
- Monorepo pnpm, Next.js App Router, worker et packages modulaires TypeScript strict créés.
- Direction visuelle Version A amorcée sur le tableau de bord; ce premier écran n’est pas une preuve de couverture V1.
- `.env.local` reste ignoré par Git; aucune valeur secrète n’est consignée dans les sources ou ce journal.

## Supabase development/staging

Projet distant contrôlé : **Matricia**, état `ACTIVE_HEALTHY`, environnement applicatif `development`.

Dix migrations sont présentes localement et appliquées à distance :

1. extensions et référentiels versionnés;
2. identité, organisations, memberships et RBAC;
3. idempotence, audit et Event Outbox;
4. ledger financier immuable et équilibré;
5. ledger de crédits immuable;
6. rôles et règles économiques de référence;
7. pgTAP pour les tests de base.
8. RPC financières et crédits atomiques, idempotentes, auditées et couplées à l’Outbox.
9. scellement automatique et sérialisé de la chaîne d’audit par organisation.
10. protocole Outbox avec claim `SKIP LOCKED`, retry borné, dead-letter et payload immuable.

Preuves :

- `supabase migration list` : versions locales/distantes `20260910000100` à `20260910001000` alignées;
- `supabase db lint --level warning` : aucune erreur de schéma;
- `pnpm test:db` : 5 fichiers, 38 assertions vertes couvrant présence/RLS, isolation inter-tenant, immutabilité, idempotence, audit, Outbox, concurrence de claim et refus d’accès non autorisé.

Le reset Supabase local ne peut pas être exécuté sur cet hôte tant que Docker Desktop n’est pas disponible. Les migrations et tests transactionnels ont donc été validés directement sur development/staging via le pooler IPv4. Aucun test n’a conservé de donnée de scénario.

## Gates exécutés

- `pnpm verify:phase00` : vert — catalogue, 7 registres, traçabilité 68/68.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- `pnpm test` : vert — 2 tests unitaires initiaux.
- `pnpm build` : vert — routes `/`, `/_not-found`, `/api/health`.
- `pnpm no-placeholders` : vert sur code applicatif, worker, packages, migrations et tests.

## Éléments encore ouverts

- Audit indépendant Phase 00 non signé : les runtimes des agents relecteurs ont rencontré une erreur d’infrastructure avant lecture des fichiers; aucune signature n’est simulée.
- Spécifications atomiques à compléter pour les premières phases avant gate Phase 01.
- Gate Phase 03 incomplet : revue sécurité indépendante, tests négatifs supplémentaires, primitives transactionnelles d’écriture et preuve de reconstruction propre restent nécessaires.
- Les parcours `MAT-FUNC-001` à `MAT-FUNC-068`, E2E, accessibilité, sécurité complète et Marketing Autopilot restent à implémenter et prouver progressivement.
- Vercel et Railway ne sont pas configurés; aucun déploiement n’est tenté.
- Production : aucune modification effectuée ou autorisée.

## Prochaine exécution

1. Obtenir la revue indépendante Phase 00 et corriger ses écarts.
2. Compléter les specs atomiques identité/RBAC et base financière.
3. Renforcer les RPC transactionnelles idempotentes avec audit/outbox atomiques.
4. Rejouer lint, types, tests SQL/RLS et audit sécurité avant fermeture des phases.
