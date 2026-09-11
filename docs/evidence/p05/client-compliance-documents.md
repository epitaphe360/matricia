# P05 — Documents de conformité Client

État : `IN_PROGRESS`. Les migrations et preuves SQL décrites ci-dessous sont
appliquées et vertes sur l’environnement Supabase `development`; elles ne valent
pas signature de fin de phase ni preuve de fonctionnement d’un antivirus réel en
staging.

## Périmètre livré

- `029` : politiques et documents versionnés, bucket Storage privé, réservation et
  finalisation d’upload, revue centrale, audit et Event Outbox.
- `030`–`033` : questions/réponses de conformité, gate documentaire de soumission,
  revue des questions et transition serveur du dossier.
- `034` : scan serveur obligatoire avant `VERIFIED`, résultats de scan immuables,
  idempotence, quarantaine et autorité `service_role` uniquement.
- `035` : matrice documentaire versionnée, exigences par type d’organisation et
  bibliothèque, anomalies ciblées et traçabilité de la matrice évaluée.
- `03550` : RPC minimale de chargement d’un job de scan, réservée au
  `service_role`, sans droit `SELECT` direct sur la table documentaire.
- Worker TypeScript : téléchargement dans le bucket et le chemin exacts,
  vérification SHA-256/MIME/taille, limite 10 Mio, ClamAV TCP borné, allowlists
  réseau, retry idempotent, logs expurgés et readiness fail-closed.

## Preuves acquises

- Migrations `20260911002900` à `20260911003550` appliquées sur Supabase
  `development`; aucune production n’a été modifiée.
- `pnpm test:db` : fichiers SQL `0001` à `0023` verts, soit 23 fichiers et
  404 assertions. Le sous-ensemble documentaire P05 (`0020` à `0023`) représente
  123 assertions.
- Les tests SQL prouvent notamment ALLOW/DENY, anti-IDOR inter-tenant, ACL Storage,
  MFA central, immutabilité, idempotence, audit/Outbox, scan courant `CLEAN`,
  quarantaine, transitions et matrice/anomalies versionnées.
- Tests Web P05 ciblés : 4 fichiers, 52 tests verts. Suite Web observée :
  12 fichiers, 99 tests verts.
- Tests Worker : 11 fichiers, 54 tests verts; typecheck strict vert. Le réaudit
  indépendant final du worker ne conserve aucun finding P0/P1/P2.
- Le test `0022` prouve que la RPC `03550` est autorisée au `service_role`, refusée
  à `authenticated` et `anon`, neutre pour un document introuvable ou non finalisé,
  et limitée aux neuf champs requis.
- `node scripts/run-p05-concurrency-tests.mjs` exécuté sur Supabase `development` :
  les scénarios `p05_document_review_concurrency` et
  `p05_question_creation_concurrency` passent chacun avec deux connexions réelles.
- Runner E2E authentifié development : contrat exact de 28 scénarios, 28 réussis,
  zéro skip/flaky/unexpected, en FR/AR, mobile 360 px et desktop. Il prouve les
  frontières Client A/B, AAL1/AAL2, rôle central, Storage cross-tenant et les
  corrélations audit/Outbox des vraies commandes métier. Le cleanup est vérifié et
  la preuve sanitizée est `authenticated-e2e-last-run.json`.

## Preuves encore attendues

- Déployer et sonder un daemon ClamAV réel dans l’environnement staging autorisé;
  les tests actuels utilisent un serveur TCP contrôlé et ne prouvent pas ce raccord.
- Conserver une preuve CI de replay propre des migrations et seeds sur une base
  vierge. L’application additive sur development ne remplace pas ce replay.

## Prochaine action

Configurer ClamAV en staging sans exposer de secret, exécuter le scan réel sur un
fichier propre et un fichier de test antivirus, puis obtenir le replay CI vierge
avant toute demande de signature P05.
