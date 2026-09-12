# Matricia — Project State

Dernière mise à jour : 2026-09-11 21:48 America/Toronto

Phase de contrôle active : **PHASE 01 — contrats atomiques en cours**

Travaux engagés : **PHASES 01, 03, 05 et 06 — en cours; PHASES 02 et 04 signées GREEN**

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

Projet distant Matricia contrôlé en environnement applicatif `development`. Les 55 migrations additives jusqu’à `20260911005400` sont appliquées à distance.

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
21. onboarding Client versionné, décision centrale et essai initial de 30 jours;
22. documents de conformité privés, questions/réponses, gates de soumission et transitions;
23. scan documentaire serveur, matrice versionnée, anomalies ciblées et RPC minimale du worker.
24. catalogue W1 : hiérarchie et versions immuables, releases gouvernées,
    audiences/fenêtres canoniques, attestation AR, worker à lease/retry/dead-letter,
    audit, Outbox et RLS restrictive.
25. persistance Question/Rule Engine : questionnaires/règles versionnés, snapshots,
    réponses validées, calculs décimaux exacts, idempotence, audit et Outbox;
26. API Client catalogue : lectures RPC authentifiées, snapshot de release exact,
    visibilité fail-closed et pagination keyset;
27. compatibilité additive des anciens writers de versions catalogue;
28. snapshots catalogue historiques explicites préservés avec FK intra-bibliothèque;
29. lifecycle catalogue durci par capabilities transactionnelles à usage unique,
    MFA fail-closed, items scellés et récupération rollback contrôlée.
30. import baseline transactionnel et idempotent, commandes de hiérarchie/services,
    compatibilités legacy fail-closed et contrat strict des questions publiables.
31. commandes Question Builder : création, nouvelle version de brouillon, duplication,
    archivage/restauration, scope GLOBAL central AAL2, audit et Event Outbox.

Preuves actuelles :

- migrations locales/distantes `20260910000100`..`20260911005400` appliquées sur development;
- lint SQL public/private sans erreur de schéma lors du dernier contrôle distant;
- `pnpm test:db` vert le 2026-09-11 pour les fichiers `0001`..`0023` : 23 fichiers et 404 assertions; les quatre scénarios historiques à deux connexions couvrent Outbox, journal, crédits et chaîne audit;
- tests négatifs RLS inter-tenant, immutabilité, équilibre/devise, crédits, idempotence, audit et Outbox.

Docker local reste indisponible sur cet hôte; la reconstruction propre doit être prouvée par le job CI Supabase avant signature P03.
Le workflow GitHub Actions contient bien un job de replay Supabase vierge, mais les
deux jobs du dernier run n'ont reçu aucun runner : GitHub les refuse actuellement
avec l'annotation `account is locked due to a billing issue`. Cette contrainte de
compte externe empêche la preuve CI tant qu'elle n'est pas levée; elle ne vaut pas
échec des migrations locales ou development.

## Gates exécutés le 2026-09-11

- `pnpm verify:phase00` : vert — catalogue 10/200/6000, 7 registres bootstrap, 68 fonctions, 8 exigences Marketing conformes à l’addendum et 63 agents.
- `pnpm lint` : vert.
- `pnpm typecheck` : vert.
- Tests Web : vert — 19 fichiers, 141 tests.
- Tests Worker : vert — 11 fichiers, 54 tests; typecheck strict vert.
- `pnpm test:db` : vert pour `0001`..`0039` — 39 fichiers et 954 assertions, plus quatre scénarios génériques à deux connexions. Les scénarios P06 dédiés de révocation concurrente hiérarchie et de commandes services passent aussi sur Supabase development.
- E2E catalogue authentifié réel : 4/4 en FR/AR à 360 px, navigation clavier,
  axe, recherche discriminante et RPC de publication/lecture réelles; crash/reaper
  `SCHEDULED` et `PUBLISHING` prouvés, zéro résidu actif ou artefact local.
- E2E P05 authentifiés : 28/28 exactement, zéro skip/flaky/unexpected, FR/AR, 360 px et desktop; cleanup distant vérifié et preuve sanitizée persistée.
- `pnpm build` : vert — routes identité, organisation, invitations, rôles, sécurité et santé compilées.
- `pnpm release:validate` : vert — uniquement gates structurels et absence de placeholders dans le périmètre contrôlé; ce n’est pas une signature de release.

## Audits et écarts

- Les réaudits P00/P01 ont identifié puis fait corriger les métriques d’inventaire, la force des validateurs, le signoff positif et le context-pack structuré. Le réaudit final indépendant au commit `32cfd89` est PASS; P00 est fermée GREEN.
- Le second réaudit P03 a détecté des droits `TRUNCATE` runtime hérités, un seed absent et la prise en compte des dead-letters en readiness. La migration additive 018, le test ACL et `supabase/seed.sql` corrigent ces écarts; seul le replay CI vierge et le nouveau visa restent requis.
- Les réaudits P02 ont imposé redaction PII, readiness réelle, Worker exécutable, TypeScript renforcé et palette navy/bleu vif. Ces écarts sont corrigés et le visa indépendant final au commit `d92d8f0` est PASS; P02 est fermée GREEN.
- P01 ne couvre pas encore les contrats atomiques de toutes les phases.
- P04 est GREEN : OTP, organisations, invitations courriel, rôles, sessions, mot de passe facultatif, MFA TOTP, AAL2 et saga d'audit Auth durable ont passé le visa indépendant sans P0/P1/P2.
- P05 dispose des migrations appliquées `024`, `026` et `029`–`03550` : profils, documents privés, questionnaires, matrice/anomalies, scan serveur, activation et essai 30 jours. Interfaces, Worker, concurrence et E2E authentifiés sont prouvés. ClamAV staging réel et replay vierge restent requis; P05 demeure `IN_PROGRESS`.
- P06 est en cours : catalogue W1, persistance Question/Rule W2, API Client,
  lifecycle immuable et E2E authentifié sont appliqués/verts. Le baseline development
  est importé et vérifié : 10 bibliothèques, 40 catégories, 80 sous-catégories,
  200 services, 212 liens, 220 questionnaires et 6 000 questions; releases et
  traductions restent volontairement `DRAFT/PENDING`. La suite globale atteint
  39 fichiers/954 assertions et les concurrences hiérarchie/services sont vertes.
  Les commandes serveur du Question Builder sont appliquées et testées; l’interface
  Builder, les commandes Rule Builder, la qualité/similarité IA, les sessions et la charge 6k/50k
  restent requis avant GREEN et visa indépendant.
- MAT-FUNC-001..068 et MARKETING-001..008 restent à implémenter et prouver progressivement.
- Vercel et Railway ne sont pas configurés. Aucune production n’a été modifiée ou autorisée.

## Prochaine exécution

1. Implémenter le parcours Builder P06 et les commandes de questionnaires/règles.
2. Prouver qualité/similarité, sessions et charge catalogue 6k/50k.
3. Obtenir un replay DB vierge CI et prouver ClamAV réel en staging.
4. Étendre les contrats atomiques P01 au fil des domaines.
5. Continuer P07..P19 selon `PLANS.md`, sans sauter de gate.
