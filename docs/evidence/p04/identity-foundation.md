# P04 — preuve intermédiaire identité

État : `IN_PROGRESS`, aucune revendication `VERIFIED`.

- OTP demandé côté serveur, création implicite interdite et quota identifiant/IP audité.
- Organisation unique détectée par ICE normalisé; un doublon crée une demande de rattachement explicite.
- Membership unique et rôles cumulables; demandes de rôles additionnels, invitations, décisions, audit et Event Outbox transactionnels.
- Les rôles plateforme sont inaccessibles par le workflow organisation; un rôle `OWNER` transverse exige une approbation centrale et l'auto-approbation est interdite.
- Sessions propres listables et révocables sans exposition de l’adresse IP.
- Interfaces FR/AR : connexion, passeport organisation et sécurité des sessions.
- Invitations multi-rôles FR/AR : création, listing RLS, acceptation et refus explicite; auto-invitation et rôle `OWNER` transverse direct interdits.
- Supabase development : migrations 014, 019 et 020 appliquées; tests P04 identité/rôles/invitations de 69 assertions verts.
- Gates actuels : 33 tests Web, 192 assertions SQL, quatre courses concurrentes et 36 E2E Chromium mobile/desktop verts; lint PostgreSQL public/private sans erreur.
- E2E prouvés : anti-énumération compte existant/inconnu, FR/AR RTL, clavier, Axe WCAG 2.1 A/AA, largeur 360 px, callback invalide et barrières anonymes.

Restent avant visa : MFA/mot de passe facultatif, invitation ergonomique par courriel sans fuite d'existence, interface de demandes de rôles additionnels et audit sécurité indépendant.
