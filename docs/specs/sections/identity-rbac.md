# Identité, organisations et RBAC — contrat P04

Portée : MAT-FUNC-001, 028, 051 et 052. Une personne authentifiée peut appartenir à plusieurs organisations; une entreprise correspond à une organisation unique cumulant les rôles Client, Provider et Franchisé.

## Contrats atomiques

1. L’OTP courriel à six chiffres utilise PKCE, expiration et tentative bornées; les réponses ne permettent pas l’énumération de comptes.
2. Toute route privée renouvelle la session côté serveur et redirige une session absente ou révoquée.
3. ICE est l’identifiant prioritaire de détection de doublon. Un doublon ouvre un rattachement ou une fusion contrôlée, jamais une seconde organisation silencieuse.
4. Membership et rôles ont des états explicites; activation, suspension et révocation sont transactionnelles, idempotentes, auditées et publient via l’Outbox.
5. La sélection d’organisation et de rôle n’élargit jamais les droits: le serveur et la RLS recalculent le scope.
6. Chaque lecture/mutation multi-tenant possède un test ALLOW dans l’organisation active et DENY depuis une autre organisation.
7. Les sessions actives sont consultables et révocables; les opérations sensibles exigent une authentification récente.
8. Tous les écrans couvrent loading, empty, success, error et forbidden en FR/AR RTL, clavier et 360 px.

## Preuves de sortie

- Tests unitaires OTP et contrats; intégration invitation/rattachement/changement de rôle/sessions.
- Tests SQL/RLS inter-tenant et privilèges; E2E FR/AR des parcours heureux et refusés.
- Audit indépendant sécurité, accessibilité et traçabilité avant statut GREEN.
