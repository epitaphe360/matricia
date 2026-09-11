# P05 — fondation onboarding et conformité Client

État : `IN_PROGRESS`. Cette preuve ne revendique ni la fin de P05 ni un statut
`VERIFIED` pour une exigence MAT-FUNC.

## Couverture livrée

- Dossier de conformité par organisation et machine d’état serveur explicite.
- Profil société en versions immuables, avec snapshot du passeport organisation.
- ICE réutilisé depuis `organization_identifiers`; IF et RC normalisés restent
  `UNVERIFIED` tant qu’aucun registre autorisé ou contrôle manuel ne les valide.
- Sauvegarde, soumission et décision centrale transactionnelles et idempotentes.
- `CLIENT_OWNER`/`CLIENT_ADMIN` préparent et soumettent; seuls
  `SUPER_ADMIN`, `MATRICIA_ADMIN` et `COMPLIANCE_MANAGER` décident.
- Une décision `VERIFIED` active l’organisation et crée atomiquement un essai
  `TRIAL_ACTIVE` de 30 jours. Aucune carte ni donnée de paiement n’est demandée.
- RLS restrictive, versions immuables, audit et Event Outbox pour chaque mutation.
- Parcours de correction après rejet sans réécriture de la version précédente.

## Artefacts et invariants

- Migration : `supabase/migrations/20260911002400_client_onboarding.sql`.
- Tests : `supabase/tests/0017_p05_client_onboarding.test.sql`.
- Une organisation possède au plus un dossier et un essai initial.
- `trial_ends_at = trial_started_at + interval '30 days'` est une contrainte SQL.
- Le profil courant référence une version existante par FK différée.
- Les profils bruts ne sont pas exposés au rôle `READ_ONLY_AUDITOR`.
- Les mutations directes sont interdites aux rôles runtime.

## Validation prévue

```text
pnpm db:push:dev
pnpm db:test
pnpm db:lint
```

Le test pgTAP contient 37 assertions ALLOW/DENY couvrant versionnage,
idempotence, isolation inter-tenant, soumission, validation centrale, création
atomique de l’essai, durée de 30 jours, rejet/correction, audit et Outbox.

## Limites honnêtes avant gate P05

- Matrice documentaire, stockage privé, versions de documents et politiques
  Storage restent à implémenter.
- Anomalies administratives, questions/réponses et moteur de comparaison restent
  à implémenter; les états correspondants sont réservés dans la machine d’état.
- Aucun registre marocain externe n’est appelé et aucune vérification officielle
  n’est simulée.
- Les interfaces FR/AR RTL, tests E2E, accessibilité et audit indépendant restent
  nécessaires avant de fermer la phase.
