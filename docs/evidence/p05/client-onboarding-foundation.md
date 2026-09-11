# P05 — Fondation onboarding et conformité Client

État : `IN_PROGRESS`. Cette preuve ne revendique ni la fermeture de P05 ni un
statut `VERIFIED` pour une exigence MAT-FUNC.

## Couverture livrée

- Dossier de conformité par organisation et machine d’état serveur explicite.
- Profil société en versions immuables avec snapshot du passeport organisation.
- ICE réutilisé depuis `organization_identifiers`; IF et RC normalisés restent
  `UNVERIFIED` tant qu’aucun registre autorisé ou contrôle manuel ne les valide.
- Sauvegarde, soumission, revue documentaire et décision centrale
  transactionnelles, idempotentes, auditées et reliées à l’Event Outbox.
- `CLIENT_OWNER`/`CLIENT_ADMIN` préparent et soumettent; seuls les rôles centraux
  autorisés décident, avec MFA fail-closed pour les actions sensibles.
- Une décision `VERIFIED` active l’organisation et crée atomiquement un essai
  `TRIAL_ACTIVE` de 30 jours, sans carte ni donnée de paiement.
- Documents et politiques versionnés, Storage privé, questions/réponses,
  matrice documentaire et anomalies administratives sont désormais présents.
- Interfaces Client et Compliance FR/AR RTL présentes avec actions serveur et
  formulaires testés unitairement; leur parcours authentifié complet reste à prouver.

## Artefacts et invariants

- Migrations : `20260911002400`, `02600`, puis `02900` à `03550`.
- Tests SQL P05 : `0017`, `0020`, `0021`, `0022` et `0023`, soit 160 assertions.
- Une organisation possède au plus un dossier et un essai initial;
  `trial_ends_at = trial_started_at + interval '30 days'` est contraint en SQL.
- Le profil courant référence une version existante; les versions, décisions,
  scans et preuves ne sont pas réécrits.
- RLS restrictive et anti-IDOR inter-tenant; les mutations directes sont refusées
  aux rôles runtime et le scanner n’obtient qu’une RPC minimale.

## Validation acquise

- Les migrations P05 jusqu’à `03550` sont appliquées sur Supabase `development`.
- Tests SQL `0001`–`0023` : 23 fichiers et 404 assertions verts.
- Tests Web P05 ciblés : 4 fichiers et 52 tests verts; suite Web complète observée :
  99 tests verts.
- Worker de scan : 54 tests et typecheck strict verts; audit indépendant final
  sans finding P0/P1/P2.
- Concurrence Supabase development : les deux scénarios P05 dédiés passent avec
  deux connexions réelles (revues documentaires sérialisées et question active
  unique).
- E2E authentifiés development : 28/28 exactement, zéro skip/flaky/unexpected,
  FR/AR, 360 px et desktop; AAL2/AAL1, rôle, multi-tenant, Storage, audit/Outbox et
  cleanup sont prouvés. La preuve persistée est sanitizée et ne contient aucun
  cookie, token ou secret.

## Limites honnêtes avant gate P05

- Aucun registre marocain externe n’est appelé et aucune vérification officielle
  n’est simulée.
- Le raccord à un ClamAV réel en staging n’est pas encore prouvé.
- Accessibilité automatisée, responsive 360 px et RTL sont couverts par les E2E
  authentifiés et anonymes; un audit manuel lecteur d’écran reste requis au gate.
- Le replay CI sur base vierge reste requis avant fermeture de la phase.
