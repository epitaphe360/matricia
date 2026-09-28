# Rapport d’acceptation — 2026-09-28

## État

**Non prêt.** Les passes du 28 septembre corrigent des défauts prouvés dans le code, sur les pages publiques et dans trois formulaires d’administration. Elles ne couvrent pas toute la plateforme. Le détail figure dans `ISSUES.md`.

## Fait

- Contact : plus d’états d’envoi illustratifs, plus de carte « écrire directement via le formulaire ».
- Abonnements : chaque offre affiche le prix et les crédits réels de `get_public_subscription_plans`. Aucun prix inventé. Sans données, pas de cartes fictives.
- Besoin : une section visible à la fois (description, compréhension, questions, compléments, récapitulatif). La numérotation est corrigée et l’identifiant technique `TOKEN_OVERLAP_V1` n’est plus affiché.
- Navigation publique : mêmes destinations en FR et en AR.
- Home : décors retirés du hero, voile orienté selon le sens d’écriture.
- Prédiagnostic : plus de pourcentages inventés. Un seul état de reprise. Le secteur refusé par le serveur est retiré.
- Professionnels : domaines réels du catalogue, catégories repliables, exemple multi-métiers.
- Franchise publique : plus de promesse de territoire exclusif.
- Administration : plus aucun UUID, JSON ni empreinte SHA-256 à saisir dans le Command center, les box et les achats groupés. Le serveur déduit ces valeurs du dossier choisi.
- Besoin → demande : les réponses du besoin sont reprises, la complétude est calculée par le serveur, et le client ne complète que ce qui manque (nouvelle version figée avant le matching). Région officielle en liste, date limite en sélecteur, panel de 10 au minimum. L’essai de 30 jours bloque dès sa date de fin. Le diagnostic public revient directement à l’enregistrement après connexion.

## Preuve exécutée

- `pnpm --dir apps/web exec vitest run` : 269 fichiers, 1080 tests, tous verts.
- `pnpm --dir apps/web exec tsc --noEmit -p tsconfig.json` : aucune erreur dans le code source. Une erreur reste dans `.next/dev/types/validator.ts`, un fichier généré par le serveur de dev en cours d’exécution.

Non exécutés : build de production, lint global, SQL/RLS, E2E Playwright, captures du déploiement Vercel, audit indépendant.

## Reste ouvert

- Revue écran par écran des espaces Client, Prestataire et Franchisé selon le prompt maître.
- Essai navigateur du Command center avec un compte administrateur et un dossier ouvert.
- Migration `20260928120000_need_request_quote_completeness.sql` : appliquée le 2026-09-28 par l’utilisateur (éditeur SQL Supabase). Test pgTAP `0170` : pas encore exécuté.
- Régions d’intervention des prestataires : aucun écran ne les renseigne (RFQ-REGION-001).
- Matrices routes, boutons, RBAC, flux de données, FR/AR et tests : non produites. Les écrire sans inventaire réel serait fictif.
- Audit sécurité indépendant (RLS, IDOR, secrets) avant toute mise en production.

## Décision demandée

Exécuter le test pgTAP `0170` sur la base où la migration a été appliquée. Aucun commit, push ni déploiement n’a été fait.
