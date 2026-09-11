# P04 — identité et sécurité du compte

État au 2026-09-11 : **GREEN**, visa final indépendant sans P0/P1/P2.

- Invitations par courriel neutres, idempotentes, limitées à 20/h par acteur et organisation; identité canonique liée seulement à l'acceptation.
- Rôles cumulables avec décision séparée, interdiction de l'auto-approbation et contrôle central AAL2 des rôles `OWNER` transverses.
- Mot de passe facultatif selon politique versionnée et MFA TOTP avec rotation; les rôles plateforme sont fail-closed sans politique active.
- Mutations Supabase Auth sensibles enveloppées par une saga durable `PENDING`/`COMPLETED`, audit et Outbox à corrélation stable et complétion idempotente.
- Migrations development appliquées jusqu'à `20260911002800`.
- Gates : 47/47 tests Web, 19 fichiers SQL/281 assertions, 4 scénarios DB de concurrence, 58 E2E verts (2 live conditionnels ignorés), lint/typecheck/build verts.
