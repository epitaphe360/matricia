# Matricia — Project State

Dernière mise à jour : 2026-09-11 07:22 America/Toronto

Phase de contrôle active : **PHASE 00 — gate automatisé vert, nouvel audit indépendant requis**

Travaux engagés : **PHASES 01 à 04 — en cours, non signées**

## État prouvé

- Gold Master V4 FINAL et `AGENTS.md` sont les autorités actives.
- Inventaire PHASE 00, ExecPlan P00–P19, index de contexte, architecture, threat model et carte d’ownership sont présents.
- Les 57 agents obligatoires du Gold Master possèdent une configuration TOML projet.
- Catalogue validé : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions.
- Les sept registres sont validés sémantiquement : références écrans/formulaires/permissions/API/événements/notifications/state machines et preuves existantes.
- Traçabilité enregistrée pour MAT-FUNC-001..068 et MARKETING-001..008. Aucune exigence n’est déclarée `VERIFIED` sans preuve.
- Monorepo pnpm, Next.js App Router, worker et packages TypeScript strict sont opérationnels.
- Connexion OTP PKCE initiale, renouvellement SSR, protection du tableau de bord et localisation FR/AR RTL sont implémentés; P04 reste partielle.
- `.env.local` est ignoré par Git; aucune valeur secrète n’est consignée.

## Supabase development/staging

Projet distant Matricia contrôlé en environnement applicatif `development`. Treize migrations additives sont présentes localement et appliquées à distance :

1. extensions et référentiels versionnés;
2. identité, organisations, memberships et RBAC;
3. idempotence, audit et Event Outbox;
4. ledger financier immuable et équilibré;
5. ledger de crédits immuable;
6. rôles et règles économiques de référence;
7. support pgTAP de test;
8. RPC financières/crédits atomiques;
9. scellement sérialisé de la chaîne d’audit;
10. claim Outbox `SKIP LOCKED`, retry et dead-letter;
11. durcissement des invariants et privilèges;
12. hash canonique serveur pour l’idempotence;
13. restriction d’accès runtime au schéma d’extensions.

Preuves actuelles :

- migrations locales/distantes 20260910000100..20260910001300 alignées lors du dernier contrôle distant;
- lint SQL public/private sans erreur de schéma lors du dernier contrôle distant;
- `pnpm test:db` vert le 2026-09-11 : 6 fichiers, 61 assertions et un scénario réel Outbox à deux connexions;
- tests négatifs RLS inter-tenant, immutabilité, équilibre/devise, crédits, idempotence, audit et Outbox.

Docker local reste indisponible sur cet hôte; la reconstruction propre doit être prouvée par le job CI Supabase avant signature P03.

## Gates exécutés le 2026-09-11

- `pnpm verify:phase00` : vert — catalogue 10/200/6000, 7 registres, 68 fonctions, 8 exigences Marketing et 57 agents.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- `pnpm test` : vert — 5 tests (3 Web, 2 domaine).
- `pnpm test:db` : vert — 61 assertions et 1 scénario de concurrence.
- `pnpm build` : vert — routes OTP/callback/tableau de bord/health compilées.
- `pnpm release:validate` : vert — gates structurels et absence de placeholders dans le périmètre contrôlé.

## Audits et écarts

- L’audit indépendant initial P00 a échoué sur inventaire, agents, plans, contexte, registres et Marketing. Ces écarts sont corrigés localement; la relecture indépendante reste obligatoire.
- L’audit DB initial P03 a signalé idempotence contrôlée client, privilèges audit/outbox, contraintes financières/crédits, parser TAP et scénarios négatifs. Les migrations 01100..01300 et les tests 0006/concurrence remédient ces findings; une relecture indépendante reste obligatoire.
- P01 ne couvre pas encore les contrats atomiques de toutes les phases.
- P04 ne couvre pas encore invitations complètes, rattachement/fusion ICE, gestion/revocation des sessions, mot de passe facultatif, MFA et limitation applicative.
- MAT-FUNC-001..068 et MARKETING-001..008 restent à implémenter et prouver progressivement.
- Vercel et Railway ne sont pas configurés. Aucune production n’a été modifiée ou autorisée.

## Prochaine exécution

1. Committer et pousser la remédiation P00 puis obtenir les audits indépendants P00/P03.
2. Corriger tout finding avant signature.
3. Terminer P04 identité/organisations avec tests unitaires, intégration, RLS, E2E et sécurité.
4. Continuer P05..P19 selon `PLANS.md`, sans sauter de gate.
