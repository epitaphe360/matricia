# Matricia — Project State

Dernière mise à jour : 2026-09-11 08:00 America/Toronto

Phase de contrôle active : **PHASE 01 — contrats atomiques en cours**

Travaux engagés : **PHASES 01 à 04 — en cours, non signées**

## État prouvé

- Gold Master V4 FINAL et `AGENTS.md` sont les autorités actives.
- PHASE 00 est GREEN au commit `32cfd89` après visa indépendant : inventaire, 63 agents, index des 76 exigences, plans, Marketing et context-pack ciblé sont conformes.
- Inventaire PHASE 00, ExecPlan P00–P19, index de contexte, architecture, threat model et carte d’ownership sont présents.
- Les 57 agents du corps principal et les 6 agents obligatoires Marketing possèdent 63 configurations TOML projet.
- Catalogue validé : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions.
- Les sept registres bootstrap ont des références nominales cohérentes; P01 reste ouverte car ils ne couvrent pas encore atomiquement les 76 exigences.
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
- `pnpm test:db` vert le 2026-09-11 : 9 fichiers, 111 assertions et quatre scénarios réels à deux connexions (Outbox, journal, crédits, chaîne audit);
- tests négatifs RLS inter-tenant, immutabilité, équilibre/devise, crédits, idempotence, audit et Outbox.

Docker local reste indisponible sur cet hôte; la reconstruction propre doit être prouvée par le job CI Supabase avant signature P03.

## Gates exécutés le 2026-09-11

- `pnpm verify:phase00` : vert — catalogue 10/200/6000, 7 registres bootstrap, 68 fonctions, 8 exigences Marketing conformes à l’addendum et 63 agents.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- `pnpm test` : vert — 14 tests (3 Web, 2 domaine, 6 observabilité, 3 design system).
- `pnpm test:db` : vert — 111 assertions et 4 scénarios de concurrence.
- `pnpm build` : vert — routes OTP/callback/tableau de bord/health compilées.
- `pnpm release:validate` : vert — uniquement gates structurels et absence de placeholders dans le périmètre contrôlé; ce n’est pas une signature de release.

## Audits et écarts

- Les réaudits P00/P01 ont identifié puis fait corriger les métriques d’inventaire, la force des validateurs, le signoff positif et le context-pack structuré. Le réaudit final indépendant au commit `32cfd89` est PASS; P00 est fermée GREEN.
- Le réaudit P03 n’a trouvé aucun P0/P1. Les matrices RLS, preuves audit/Outbox et courses journal/crédits/audit sont désormais étendues; le replay DB vierge CI et le nouveau visa restent requis.
- Les écarts P02 sont corrigés localement : CI hermétique, 10 packages contrôlés, frontières modulaires, observabilité structurée, tokens Design Authority A et headers de sécurité. Le nouveau visa reste requis. Les écarts P04 restent ouverts.
- P01 ne couvre pas encore les contrats atomiques de toutes les phases.
- P04 ne couvre pas encore invitations complètes, rattachement/fusion ICE, gestion/revocation des sessions, mot de passe facultatif, MFA et limitation applicative.
- MAT-FUNC-001..068 et MARKETING-001..008 restent à implémenter et prouver progressivement.
- Vercel et Railway ne sont pas configurés. Aucune production n’a été modifiée ou autorisée.

## Prochaine exécution

1. Enregistrer/pousser le visa P00 et obtenir les réaudits indépendants P02/P03.
2. Obtenir un replay DB vierge CI et fermer les risques P02/P03 restants.
3. Étendre les contrats atomiques P01 au fil des domaines.
4. Terminer P04 identité/organisations avec mutations serveur, ICE, invitations, sessions et tests complets.
5. Continuer P05..P19 selon `PLANS.md`, sans sauter de gate.
