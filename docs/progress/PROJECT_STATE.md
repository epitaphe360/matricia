# Matricia — Project State

Dernière mise à jour : 2026-09-11 09:37 America/Toronto

Phase de contrôle active : **PHASE 01 — contrats atomiques en cours**

Travaux engagés : **PHASES 01, 03 et 05 — en cours; PHASES 02 et 04 signées GREEN**

## État prouvé

- Gold Master V4 FINAL et `AGENTS.md` sont les autorités actives.
- PHASE 00 est GREEN au commit `32cfd89` après visa indépendant : inventaire, 63 agents, index des 76 exigences, plans, Marketing et context-pack ciblé sont conformes.
- Inventaire PHASE 00, ExecPlan P00–P19, index de contexte, architecture, threat model et carte d’ownership sont présents.
- Les 57 agents du corps principal et les 6 agents obligatoires Marketing possèdent 63 configurations TOML projet.
- Catalogue validé : 10 bibliothèques, 40 catégories, 80 sous-catégories, 200 services, 212 liaisons et 6 000 questions.
- Les sept registres bootstrap ont des références nominales cohérentes; P01 reste ouverte car ils ne couvrent pas encore atomiquement les 76 exigences.
- Traçabilité enregistrée pour MAT-FUNC-001..068 et MARKETING-001..008. Aucune exigence n’est déclarée `VERIFIED` sans preuve.
- Monorepo pnpm, Next.js App Router, worker et packages TypeScript strict sont opérationnels.
- PHASE 02 est GREEN au commit `d92d8f0` après réaudit indépendant : installation figée, frontières de modules, lint, typecheck, 74 tests, build, logger expurgé, Worker et Design A sont conformes sans finding P0/P1/P2.
- PHASE 04 est GREEN après visa indépendant : connexion OTP PKCE, invitations courriel, rôles cumulables, sessions, mot de passe facultatif, MFA TOTP et saga d'audit Auth sont implémentés en FR/AR RTL.
- `.env.local` est ignoré par Git; aucune valeur secrète n’est consignée.

## Supabase development/staging

Projet distant Matricia contrôlé en environnement applicatif `development`. Vingt-huit migrations additives sont présentes localement et appliquées à distance. Les migrations 021–028 couvrent invitations courriel, sécurité de compte/MFA, onboarding Client, conformité vérifiée, essai 30 jours et saga d'audit Auth durable.

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
14. workflows identité P04 : profil, OTP limité, ICE, rattachement, invitations, sessions;
15. sonde readiness DB/Outbox à privilège minimal;
16. rechargement explicite du schéma API;
17. correction additive de la sonde sur le schéma Outbox immuable.
18. révocation complète des ACL runtime dangereuses, grants minimaux et readiness hors dead-letter.
19. demandes idempotentes de rôles cumulables, interdiction des rôles plateforme, approbation centrale des rôles `OWNER` transverses et refus de l'auto-approbation.
20. refus explicite et idempotent d'invitation, statut `DECLINED`, blocage de l'auto-invitation et du contournement des rôles `OWNER` transverses.

Preuves actuelles :

- migrations locales/distantes 20260910000100..20260911002800 appliquées sur development;
- lint SQL public/private sans erreur de schéma lors du dernier contrôle distant;
- `pnpm test:db` vert le 2026-09-11 : 19 fichiers, 281 assertions et quatre scénarios réels à deux connexions (Outbox, journal, crédits, chaîne audit);
- tests négatifs RLS inter-tenant, immutabilité, équilibre/devise, crédits, idempotence, audit et Outbox.

Docker local reste indisponible sur cet hôte; la reconstruction propre doit être prouvée par le job CI Supabase avant signature P03.

## Gates exécutés le 2026-09-11

- `pnpm verify:phase00` : vert — catalogue 10/200/6000, 7 registres bootstrap, 68 fonctions, 8 exigences Marketing conformes à l’addendum et 63 agents.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- `pnpm test` : vert — 97 tests (47 Web, 6 Worker, 2 domaine, 38 observabilité, 4 design system).
- `pnpm test:db` : vert — 281 assertions et 4 scénarios de concurrence.
- `pnpm test:e2e` : vert — 58 tests Chromium mobile 360 px et desktop; 2 scénarios live conditionnels ignorés.
- `pnpm build` : vert — routes identité, organisation, invitations, rôles, sécurité et santé compilées.
- `pnpm release:validate` : vert — uniquement gates structurels et absence de placeholders dans le périmètre contrôlé; ce n’est pas une signature de release.

## Audits et écarts

- Les réaudits P00/P01 ont identifié puis fait corriger les métriques d’inventaire, la force des validateurs, le signoff positif et le context-pack structuré. Le réaudit final indépendant au commit `32cfd89` est PASS; P00 est fermée GREEN.
- Le second réaudit P03 a détecté des droits `TRUNCATE` runtime hérités, un seed absent et la prise en compte des dead-letters en readiness. La migration additive 018, le test ACL et `supabase/seed.sql` corrigent ces écarts; seul le replay CI vierge et le nouveau visa restent requis.
- Les réaudits P02 ont imposé redaction PII, readiness réelle, Worker exécutable, TypeScript renforcé et palette navy/bleu vif. Ces écarts sont corrigés et le visa indépendant final au commit `d92d8f0` est PASS; P02 est fermée GREEN.
- P01 ne couvre pas encore les contrats atomiques de toutes les phases.
- P04 est GREEN : OTP, organisations, invitations courriel, rôles, sessions, mot de passe facultatif, MFA TOTP, AAL2 et saga d'audit Auth durable ont passé le visa indépendant sans P0/P1/P2.
- P05 dispose d'une fondation SQL appliquée : profils versionnés, conformité, preuves vérifiées, activation et essai 30 jours. Storage documentaire, questionnaires/anomalies, UI et E2E restent à livrer.
- MAT-FUNC-001..068 et MARKETING-001..008 restent à implémenter et prouver progressivement.
- Vercel et Railway ne sont pas configurés. Aucune production n’a été modifiée ou autorisée.

## Prochaine exécution

1. Enregistrer et pousser le lot P04 GREEN et la fondation P05 durcie.
2. Obtenir un replay DB vierge CI et fermer le dernier risque P03.
3. Étendre les contrats atomiques P01 au fil des domaines.
4. Continuer P05 avec Storage, UI, questionnaires et E2E.
5. Continuer P06..P19 selon `PLANS.md`, sans sauter de gate.
