# Refonte sans catalogue — état de travail

## Terminé avec preuve

- Audit ciblé et carte de routes : `AUDIT.md`.
- Baseline locale : `apps/web` build, lint ciblé et E2E public du commit `028312a` étaient verts avant la nouvelle refonte.

## En cours

- Lot 2 : Home diagnostic-first, prédiagnostic public déterministe, besoin précis et conservation locale limitée.
- Mapping non permanent des anciennes URLs `/services` et `/services/[code]` vers des entrées guidées.

## Bloqué

- Aucun blocage technique à ce stade. La persistance authentifiée du prédiagnostic exige de raccorder une mutation serveur idempotente aux tables existantes après le premier vertical public.

## Prochaine action exacte

- Livrer `/[locale]/diagnostic` et `/[locale]/besoin`, puis raccorder le retour OTP et les entrées publiques sans catalogue.
# Progression — refonte des parcours sans catalogue

## Terminé avec preuve

- Lot 1 : audit ciblé et carte des routes dans `AUDIT.md`.
- Lot 2 : Home guidée, prédiagnostic déterministe de sept questions, bilan sans score, raccourci de besoin, entrée fournisseur et redirections des anciennes routes publiques.
- Authentification : l’OTP conserve une destination locale validée ; le navigateur conserve uniquement le brouillon public non sensible, expirant après sept jours et effaçable.
- Qualité du lot public : `corepack pnpm --filter @matricia/web typecheck`, `corepack pnpm --filter @matricia/web lint` et `corepack pnpm exec playwright test tests/e2e/refonte-sans-catalogue-public.spec.ts --workers=2 --reporter=dot` passent le 2026-09-14 (4 tests).

## En cours

- Lot 3 : rattachement serveur idempotent du brouillon après authentification, préremplissage de la demande et validation progressive.
- Lot 4 : réutilisation du contexte d’activité dans la qualification fournisseur et hiérarchisation des consultations réellement accessibles.

## Bloqué

- Aucun blocage technique pour le lot public. Les mutations Supabase additives seront préparées puis appliquées uniquement à un environnement non-production autorisé.

## Prochaine action exacte

Créer le contrat serveur et la migration additive de rattachement des brouillons publics, avec tests d’idempotence et RLS.
