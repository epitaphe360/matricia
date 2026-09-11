# P04 — preuve intermédiaire identité

État : `IN_PROGRESS`, aucune revendication `VERIFIED`.

- OTP demandé côté serveur, création implicite interdite et quota identifiant/IP audité.
- Organisation unique détectée par ICE normalisé; un doublon crée une demande de rattachement explicite.
- Membership unique et rôles cumulables; demandes de rôles additionnels, invitations, décisions, audit et Event Outbox transactionnels.
- Les rôles plateforme sont inaccessibles par le workflow organisation; un rôle `OWNER` transverse exige une approbation centrale et l'auto-approbation est interdite.
- Sessions propres listables et révocables sans exposition de l’adresse IP.
- Interfaces FR/AR : connexion, passeport organisation et sécurité des sessions.
- Supabase development : migrations 014 et 019 appliquées; tests P04 identité/rôles de 53 assertions verts.
- Gates actuels : 24 tests Web, 176 assertions SQL et quatre courses concurrentes vertes; lint PostgreSQL public/private sans erreur.

Restent avant visa : MFA/mot de passe facultatif, invitations utilisateur bout en bout, E2E navigateur FR/AR/360/accessibilité et audit sécurité indépendant.
