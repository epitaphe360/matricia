# Matricia — audit final de sécurité

Date : 2026-09-15  
Périmètre : code, migrations et métadonnées Supabase **development**. L'audit distant a commencé en `READ ONLY`; les migrations additives 205 et 206 ont ensuite été appliquées uniquement sur l'environnement development, sans donnée destructive ni modification de production.

## Verdict

**Aucun P0 exploitable n'a été reproduit dans le périmètre audité. La release production reste NON PRÊTE tant que les preuves P1 et validations externes ci-dessous ne sont pas closes.**

| Contrôle | Résultat | Preuve |
|---|---|---|
| Historique migrations local/distant | PASS | CLI : cible development alignée jusqu'à `20260915020600`; dry-run final `upToDate=true`. |
| RLS tables publiques | PASS | 438/438 tables avec `relrowsecurity=true`; aucune table accordée à `anon`. |
| Tables RLS sans policy | PASS deny-by-default | 21 tables; aucun grant `authenticated`; un seul grant `service_role:SELECT` sur événements paiement abonnement. |
| `SECURITY DEFINER` search path | PASS | 394/394 fonctions avec `search_path` fixé. |
| Storage | PASS structurel | 3 buckets, tous privés; 9 policies sur `storage.objects`. |
| Secrets Git | PASS après classification | `.env.local` ignoré et non suivi; les trois hits sont des fixtures factices/localhost dans CI et tests de redaction. |
| Montants/ledger | PASS structurel | `bigint`/devise, RPC, contraintes, triggers immuables, idempotence/audit/Outbox. |
| Tests SQL complets | PARTIEL FINAL | 154 fichiers et 3 590 assertions PASS après migration 207; 311/311 RPC référencées avec indice DENY; 0154/0155 ciblés et 4 concurrences PASS avec preuves machine; le replay complet Outbox reste perturbé par un worker development concurrent. |

## Findings ouverts

### SEC-P1-001 — preuve ALLOW/DENY non exhaustivement liée aux RPC

- Gravité : **P1 / High assurance gap**.
- Preuve : `RPC_SECURITY_TEST_MATRIX.md` inventorie les 311 fonctions `SECURITY DEFINER` exécutables par `authenticated`; les 311 sont référencées par un test SQL et aucune ne reste sans indice négatif détecté. La détection est volontairement conservatrice.
- Risque : une régression d'autorisation dans une RPC peu couverte pourrait échapper à la release gate.
- Remédiation : poursuivre la preuve positive atomique et les parcours multi-organisation; ne pas confondre l'indice textuel avec un visa indépendant complet.
- Statut : **OUVERT**, aucune vulnérabilité concrète reproduite.

### SEC-P1-002 — preuve de replay rejouée pendant cette passe

- Gravité : **P1 / release evidence**.
- Preuve actuelle : 154 fichiers et 3 590 assertions SQL passent. Les exécutions ciblées 0154/0155 passent chacune avec les 4 scénarios du harness; le replay complet reste à refaire sans worker development concurrent.
- Statut : **FERMÉ pour l'arbre de travail audité au moment du replay**; la suite devra être rejouée après gel du HEAD final.

### SEC-P1-003 — validations production externes absentes

- Gravité : **P1 / bloquant production**.
- Preuve : `docs/upgrades/V4_1_SECURITY_REPORT.md` marque non terminés l'exercice de restauration réel, la rotation de clés/preuve vault, le pentest indépendant et l'exercice incident.
- Risque : résilience et réponse opérationnelle non démontrées malgré des contrôles applicatifs présents.
- Remédiation : réaliser ces exercices sans exposer les secrets et enregistrer les preuves approuvées.
- Statut : **OUVERT**.

### SEC-P2-001 — vue d'audit sans `security_invoker=true` — CORRIGÉ DANS LE CODE

- Gravité : **P2 / défense en profondeur**.
- Preuve : `organization_audit_activity` est `security_barrier=true`, owner `postgres`, accordée à `authenticated`; son WHERE appelle `private.is_active_org_member(organization_id)`. `0006` et `0007` couvrent propre/tiers.
- Risque : une modification future du prédicat pourrait bénéficier des privilèges owner au lieu de la RLS de la table source.
- Remédiation : `20260915020500_security_view_event_trigger_hardening.sql` ajoute une projection privée minimale, conserve le filtre membership, puis recrée la vue avec `security_invoker=true, security_barrier=true` et les mêmes colonnes/grants.
- Preuve : `0148_security_view_event_trigger_hardening.test.sql`, ALLOW propre, DENY tiers, DENY audit brut, contrat de colonnes et reloptions; **15/15 PASS** dans une transaction development annulée.
- Statut : **CORRIGÉ, APPLIQUÉ EN DEVELOPMENT ET REJOUÉ**; production non touchée.

### SEC-P2-002 — grant inutile sur event-trigger géré — CORRIGÉ DANS LE CODE

- Gravité : **P2 / least privilege**.
- Preuve : `public.rls_auto_enable()` est `SECURITY DEFINER`, search path fixé et apparaît exécutable par `anon` et `public`. C'est une fonction `event_trigger` attachée à `ensure_rls`, non une RPC métier appelable normalement.
- Risque : surface ACL inutile et confusion d'audit; aucune exploitation directe démontrée.
- Remédiation : la même migration révoque `EXECUTE` de `PUBLIC/anon/authenticated` seulement si `ensure_rls` est actif, pointe vers `public.rls_auto_enable()` et que la fonction appartient à l'utilisateur de migration. Elle ne remplace ni ne désactive l'event trigger.
- Preuve : test des trois ACL révoquées et présence de l'event trigger actif; **PASS** dans la transaction annulée.
- Statut : **CORRIGÉ, APPLIQUÉ EN DEVELOPMENT ET REJOUÉ**; production non touchée.

### SEC-P2-003 — configuration Auth locale minimale, configuration hébergée non prouvée

- Gravité : **P2 / configuration**.
- Preuve : `supabase/config.toml` active rotation refresh token mais garde longueur mot de passe minimale 6, exigences vides et captcha commenté. Les réglages Auth hébergés ne sont pas contenus dans les migrations auditées.
- Risque : si le mot de passe est activé en production, politique faible; quotas/captcha et allow-list redirect peuvent diverger du dépôt.
- Remédiation : capturer sans valeur sensible les paramètres hébergés : signup, OTP quotas, captcha, password policy, Site URL et redirect allow-list de production.
- Statut : **OUVERT**.

### SEC-P3-001 — validation des index par plans de charge

- Gravité : **P3 / performance-disponibilité**.
- Preuve : 23 tables n'ont qu'un index apparent; aucun `EXPLAIN (ANALYZE, BUFFERS)` de charge n'a été exécuté en lecture seule dans cette passe.
- Risque : files admin/marketing/restore susceptibles de ralentir avec le volume, sans fuite de données directe.
- Remédiation : mesurer sur dataset représentatif et ajouter uniquement les index justifiés.

## Contrôles positifs observés

- Auth/session : redirection `next` validée côté serveur dans le code; OTP limité; rotation refresh token; erreurs publiques anti-enumération.
- Autorisation : helpers membership/roles à `auth.uid()`, révocation et scope organisation/franchise/bibliothèque; aucune confiance dans `organizationId` seul.
- Finance : montants exacts, contraintes d'équilibre, ledgers append-only, fonctions transactionnelles, clés idempotentes serveur et Outbox.
- Webhooks/workers : secrets serveur requis, comparaison constante via `timingSafeEqual`, validation Zod, signature/replay/idempotence et résultats SQL contrôlés; les erreurs internes ne sont pas renvoyées brutes.
- Upload : buckets privés, réservation serveur, MIME/extension/signature/taille, quarantaine/scan et liaison objet; preuves de livraison avec scan fiable.
- Vie privée : références sujet hachées, audit minimisé, consentements/rétention/version et gate CNDP.
- Marketing : consentement, autorisation de marque, kill switch, leases, quotas et publication journalisée.
- Secrets : `apps/web/modules/shared/lib/supabase/admin.ts` centralise le client service-role côté serveur; aucun usage client détecté. `.env.local` est ignoré.

## Menaces et état de preuve

| Menace | Contrôle | État |
|---|---|---|
| Tenant escape / IDOR | RLS + RPC recalculant membership; tests propres/tiers | Couvert sur domaines critiques, exhaustivité RPC ouverte SEC-P1-001. |
| Rôle forgé / escalade | rôles DB, membership active et révocation; AAL2/four-eyes sur sensible | Couvert par migrations/tests spécialisés. |
| Provider voyant concurrent | scope RFQ/quote/provider + tests négatifs | Couvert par tests existants; à rejouer au gate final. |
| Franchise hors bibliothèque | `franchise_id/library_id`, mandat et helpers | Couvert par tests digest/CRM/gouvernance. |
| Double paiement/webhook | événement fournisseur unique, état antérieur, montant serveur, idempotence | Couvert structurellement et tests sandbox existants. |
| Double ledger/crédit | contraintes, commande canonique, verrou/concurrence | Couvert structurellement et 4 scénarios documentés. |
| Document direct/URL | Storage privé, policy objet, signed URL, scan | Couvert structurellement; validation E2E finale requise. |
| Secret/log | env serveur, logger redaction, scan Git | PASS statique; rotation production externe requise. |
| Worker/internal API | secret >=32, constant-time, service RPC à lease | Couvert code/tests unitaires; config production non auditée. |
| XSS/injection | Zod, SQL paramétré/RPC, contenu borné | Contrôles présents; pentest externe ouvert. |

## Commandes exécutées et résultats

- Après application additive des migrations 205–206 en development, `supabase migration list --linked` et `supabase db push --linked --dry-run` : PASS, local=distant et aucune migration restante à appliquer.
- `corepack pnpm test:db` : 154 fichiers/3 590 assertions PASS; replay final concurrence Outbox perturbé par un consommateur development concurrent; ciblages 0154/0155 avec 4/4 concurrences PASS.
- Requêtes catalogues PostgreSQL dans transaction `SET TRANSACTION READ ONLY` : PASS; statistiques RLS/ACL/fonctions/triggers/index/Storage ci-dessus.
- `node scripts/audit-rpc-security.mjs` : PASS; 311 signatures rapprochées des tests dans `docs/RPC_SECURITY_TEST_MATRIX.md`.
- Scan `git check-ignore`/`git ls-files`/patterns credentials : PASS; `.env.local` ignoré, uniquement fixtures factices classées.
- Inspection initiale des migrations/tests : PASS; elle a conduit aux deux renforcements additifs SQL ci-dessous, sans modification d'une migration déjà appliquée.
- Migrations `20260915020500` et `20260915020600` appliquées uniquement sur Supabase development après dry-run; suite complète post-application PASS, dont le durcissement de vue et l'archivage privé des preuves de paiement. Aucune production modifiée.

## Décision de release sécurité

- Development/staging : **conditionnellement acceptable** pour poursuivre tests et corrections.
- Production : **NON PRÊTE** tant que SEC-P1-001 et SEC-P1-003 ne sont pas fermés ou formellement acceptés par les propriétaires habilités; SEC-P1-002 devra rester verte sur le HEAD final.
